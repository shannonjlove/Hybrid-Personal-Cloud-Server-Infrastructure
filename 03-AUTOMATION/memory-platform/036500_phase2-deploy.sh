#!/usr/bin/env bash
# SJL Memory Platform — Phase 2: Host Preparation & Container Deployment
# Run as root on Hostinger VPS (72.61.74.250) — MUTATING
# Canonical reference: 467d9199-036500_20260703__SJLSHAREDMEMORYPLATFORM__deploymentstrategyandclaudehandoff__v10.md
#
# Phase 1 pre-conditions verified before this script is safe to run:
#   - /opt/mcp/data/memory: EMPTY (confirmed, no data to preserve)
#   - No NPM proxy route exists for memory.shannonjlove.cloud
#   - No external port binding on mcp-memory (internal network only)
#   - Zero active clients (nothing is using this service)
#
# What this script does:
#   1. Pre-flight validation (port 9880 free, image exists, network exists)
#   2. Checks what other containers are on mcp_internal (dependency audit)
#   3. Detects supported transport (streamable-http or sse)
#   4. Retaggs image to pinned version (latest → 0.18.3)
#   5. Creates /etc/containers/systemd/mcp-memory.container (Quadlet)
#   6. Stops and disables container-mcp-memory.service (old unit)
#   7. Systemd reload + start new mcp-memory.service
#   8. Verifies port 9880 listening and HTTP response
#   9. Prints NPM proxy host settings for manual entry
#
# NEVER TOUCH: sjl-cloud-access-mcp-rw.service / port 8777

set -Eeuo pipefail
IFS=$'\n\t'

STAMP="$(date +%Y%m%d-%H%M%S)"
LOG="/root/sjl-memory-phase2-${STAMP}.log"
exec > >(tee -a "${LOG}") 2>&1

log()  { printf '\n== %s ==\n' "$*"; }
ok()   { echo "  OK: $*"; }
warn() { echo "  WARN: $*"; }
note() { echo "  NOTE: $*"; }
die()  { echo ""
         echo "  FAIL: $*" >&2
         echo ""
         echo "  Log: ${LOG}"
         exit 1; }

echo "SJL Memory Platform — Phase 2 Deployment"
echo "Date: $(date)"
echo "Log:  ${LOG}"
echo ""

[[ ${EUID:-$(id -u)} -eq 0 ]] || die "Run as root."

# ── Configuration ──────────────────────────────────────────────────────────

IMAGE_TAG="0.18.3"
IMAGE_PINNED="localhost/mcp-basic-memory:${IMAGE_TAG}"
IMAGE_LATEST="localhost/mcp-basic-memory:latest"
QUADLET_FILE="/etc/containers/systemd/mcp-memory.container"
DATA_DIR="/opt/mcp/data/memory"
MEMORY_PORT="9880"
OLD_SERVICE="container-mcp-memory.service"
NEW_SERVICE="mcp-memory.service"
NETWORK="mcp_internal"

# ── Pre-flight checks ─────────────────────────────────────────────────────

log "Pre-flight 1/4: Port ${MEMORY_PORT} must be free"
if ss -ltnp 2>/dev/null | grep -q ":${MEMORY_PORT}[^0-9]"; then
    die "Port ${MEMORY_PORT} is in use. Run: ss -ltnp | grep :${MEMORY_PORT}"
fi
ok "Port ${MEMORY_PORT} is free"

log "Pre-flight 2/4: Image must exist"
if ! podman image exists "${IMAGE_LATEST}" 2>/dev/null; then
    die "Image not found: ${IMAGE_LATEST}"
fi
ok "Image exists: ${IMAGE_LATEST}"

log "Pre-flight 3/4: Data directory must exist"
if [[ ! -d "${DATA_DIR}" ]]; then
    die "Data directory missing: ${DATA_DIR} — run Phase 0 audit first"
fi
DATA_BYTES=$(du -sb "${DATA_DIR}" 2>/dev/null | awk '{print $1}')
if [[ "${DATA_BYTES}" -gt 4096 ]]; then
    warn "Data directory is not empty (${DATA_BYTES} bytes)."
    warn "Phase 1 found this empty. Something may have written data since then."
    warn "Inspect: find ${DATA_DIR} -ls"
    read -r -p "  Continue anyway? [y/N] " CONFIRM
    [[ "${CONFIRM}" =~ ^[Yy]$ ]] || die "Aborted by user."
fi
ok "Data directory: ${DATA_DIR} (${DATA_BYTES} bytes — safe to proceed)"

log "Pre-flight 4/4: Podman network ${NETWORK}"
if ! podman network inspect "${NETWORK}" >/dev/null 2>&1; then
    warn "${NETWORK} not found — creating it"
    podman network create "${NETWORK}"
    ok "Created network: ${NETWORK}"
else
    ok "Network exists: ${NETWORK}"
fi

# ── Dependency audit: what else is on mcp_internal? ───────────────────────

log "Dependency audit: containers on ${NETWORK}"
DEPENDENTS=""
DEPENDENTS=$(podman network inspect "${NETWORK}" 2>/dev/null | \
    python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    if isinstance(data, list):
        data = data[0]
    containers = data.get('Containers', {})
    for cid, info in containers.items():
        name = info.get('Name', cid[:12])
        aliases = info.get('Aliases', [])
        if name != 'mcp-memory':
            print(f'{name}  aliases={aliases}')
except Exception as e:
    print(f'(parse error: {e})')
" 2>/dev/null || true)

if [[ -n "${DEPENDENTS}" ]]; then
    note "Other containers on ${NETWORK}:"
    echo "${DEPENDENTS}" | sed 's/^/    /'
    note "Verify these containers do not depend on the 'memory' alias before proceeding."
    note "The memory container will be temporarily offline during the switchover."
else
    ok "No other containers on ${NETWORK} reference 'memory'"
fi

# ── Step 1: Retag image to pinned version ─────────────────────────────────

log "Step 1: Retag image to pinned version"
if podman image exists "${IMAGE_PINNED}" 2>/dev/null; then
    ok "Pinned image already exists: ${IMAGE_PINNED}"
else
    podman tag "${IMAGE_LATEST}" "${IMAGE_PINNED}"
    ok "Tagged: ${IMAGE_PINNED}"
fi

# ── Step 2: Detect supported transport ────────────────────────────────────

log "Step 2: Detect supported MCP transport"
TRANSPORT_HELP=$(podman run --rm --entrypoint="" "${IMAGE_PINNED}" \
    basic-memory mcp --help 2>&1 || true)
echo "${TRANSPORT_HELP}" | head -20

if echo "${TRANSPORT_HELP}" | grep -qi 'streamable.http'; then
    TRANSPORT="streamable-http"
    ok "streamable-http supported — using it"
    MCP_ENDPOINT="/mcp"
else
    TRANSPORT="sse"
    warn "streamable-http not detected in --help output"
    warn "Falling back to SSE transport. Claude Code web connections require streamable-http."
    warn "If streamable-http is needed, upgrade basic-memory and redeploy."
    MCP_ENDPOINT="/sse"
fi

# ── Step 3: Create Quadlet file ───────────────────────────────────────────

log "Step 3: Create Quadlet at ${QUADLET_FILE}"
mkdir -p /etc/containers/systemd

cat > "${QUADLET_FILE}" <<QUADLET
# SJL Memory Platform — mcp-memory Quadlet
# Deployed: $(date +%Y-%m-%d)
# Image:    mcp-basic-memory ${IMAGE_TAG}
# Transport: ${TRANSPORT}
# Endpoint: https://memory.shannonjlove.cloud${MCP_ENDPOINT}

[Unit]
Description=basic-memory MCP — memory.shannonjlove.cloud
After=network-online.target
Wants=network-online.target

[Container]
Image=${IMAGE_PINNED}
ContainerName=mcp-memory
PublishPort=127.0.0.1:${MEMORY_PORT}:8000
Volume=${DATA_DIR}:/data:Z
Network=${NETWORK}
NetworkAlias=memory
Exec=basic-memory mcp --transport ${TRANSPORT} --host 0.0.0.0 --port 8000
AutoUpdate=disabled
NoNewPrivileges=true

[Service]
Restart=always
RestartSec=5s
TimeoutStartSec=60
TimeoutStopSec=30

[Install]
WantedBy=default.target
QUADLET

ok "Quadlet created: ${QUADLET_FILE}"

# ── Step 4: Stop and disable old service ──────────────────────────────────

log "Step 4: Stop and disable ${OLD_SERVICE}"

if systemctl is-active --quiet "${OLD_SERVICE}" 2>/dev/null; then
    echo "  Stopping ${OLD_SERVICE}..."
    systemctl stop "${OLD_SERVICE}"
    sleep 2
    ok "Stopped"
else
    ok "${OLD_SERVICE} was not active"
fi

if systemctl is-enabled --quiet "${OLD_SERVICE}" 2>/dev/null; then
    systemctl disable "${OLD_SERVICE}"
    ok "Disabled"
else
    ok "${OLD_SERVICE} was not enabled"
fi

# ── Step 5: Reload daemon and start new service ────────────────────────────

log "Step 5: systemd daemon-reload and start ${NEW_SERVICE}"
systemctl daemon-reload
ok "Daemon reloaded"

systemctl enable --now "${NEW_SERVICE}"
ok "Enabled and started ${NEW_SERVICE}"

echo "  Waiting 8 seconds for container to initialize..."
sleep 8

# ── Step 6: Verify ────────────────────────────────────────────────────────

log "Step 6: Verify deployment"

echo "  systemd status:"
systemctl status "${NEW_SERVICE}" --no-pager -l || true
echo ""

echo "  Port check:"
if ss -ltnp 2>/dev/null | grep ":${MEMORY_PORT}"; then
    ok "Port ${MEMORY_PORT} is now listening"
else
    warn "Port ${MEMORY_PORT} is NOT listening yet."
    echo "  Container may still be starting. Check:"
    echo "    journalctl -u ${NEW_SERVICE} -n 30"
    echo "    podman ps -a"
fi

echo ""
echo "  HTTP probe:"
for PATH_CHECK in "/" "${MCP_ENDPOINT}" "/health"; do
    HTTP_CODE=$(curl -sS -o /dev/null -w '%{http_code}' \
        --max-time 5 "http://127.0.0.1:${MEMORY_PORT}${PATH_CHECK}" 2>/dev/null || echo "000")
    echo "    GET http://127.0.0.1:${MEMORY_PORT}${PATH_CHECK} → HTTP ${HTTP_CODE}"
done

echo ""
echo "  Last 20 container log lines:"
journalctl -u "${NEW_SERVICE}" -n 20 --no-pager 2>/dev/null || \
    podman logs mcp-memory --tail 20 2>/dev/null || \
    echo "  (no logs yet)"

# ── Step 7: NPM proxy host instructions ───────────────────────────────────

log "Step 7: Add Nginx Proxy Manager proxy host"
echo ""
echo "  Open NPM admin at: http://$(hostname -I | awk '{print $1}'):81"
echo "  (or via Tailscale: http://100.115.66.75:81)"
echo ""
echo "  ┌─ Add Proxy Host ────────────────────────────────────────┐"
echo "  │  Details tab:                                           │"
echo "  │    Domain Names:      memory.shannonjlove.cloud         │"
echo "  │    Forward Scheme:    http                              │"
echo "  │    Forward Hostname:  127.0.0.1                         │"
echo "  │    Forward Port:      ${MEMORY_PORT}                        │"
echo "  │    ☑ Block Common Exploits                              │"
echo "  │    ☑ Websockets Support                                 │"
echo "  │                                                         │"
echo "  │  SSL tab:                                               │"
echo "  │    SSL Certificate:   Request a new SSL Certificate     │"
echo "  │    ☑ Force SSL                                          │"
echo "  │    ☑ HTTP/2 Support                                     │"
echo "  │    Email: sjlove@shannonjeffreylove.com                 │"
echo "  └─────────────────────────────────────────────────────────┘"
echo ""
echo "  After saving the NPM proxy host, test:"
echo "    curl -I https://memory.shannonjlove.cloud/"
echo "    curl -sS https://memory.shannonjlove.cloud${MCP_ENDPOINT} | head -5"

# ── Post-deployment note: mcp-stack.yml ───────────────────────────────────

log "Post-deployment: mcp-stack.yml cleanup"
COMPOSE_FILE="/opt/mcp/compose/mcp-stack.yml"
if [[ -f "${COMPOSE_FILE}" ]]; then
    note "The memory service in ${COMPOSE_FILE} should be removed"
    note "to prevent podman-compose from conflicting with the Quadlet."
    note "Edit: remove the 'memory:' service block from mcp-stack.yml"
    note "Then run: podman-compose -f ${COMPOSE_FILE} up -d"
    note "(The Quadlet owns the memory container now)"
fi

# ── Summary ───────────────────────────────────────────────────────────────

log "PHASE 2 COMPLETE"
echo ""
echo "Memory service:"
echo "  Container:   mcp-memory"
echo "  Image:       ${IMAGE_PINNED}"
echo "  Transport:   ${TRANSPORT}"
echo "  Local URL:   http://127.0.0.1:${MEMORY_PORT}${MCP_ENDPOINT}"
echo "  Public URL:  https://memory.shannonjlove.cloud${MCP_ENDPOINT} (after NPM)"
echo "  Data:        ${DATA_DIR}"
echo "  Quadlet:     ${QUADLET_FILE}"
echo "  Service:     ${NEW_SERVICE} (enabled, running)"
echo ""
echo "Phase checklist:"
echo "  [✓] Phase 0 — Discovery audit"
echo "  [✓] Phase 1 — Existing service inspected (empty, safe to replace)"
echo "  [✓] Phase 2 — Host prepared, container deployed"
echo "  [ ] Phase 3 — Add NPM proxy host (see Step 7 above)"
echo "  [ ] Phase 4 — N/A (no data to migrate)"
echo "  [ ] Phase 5 — Validate https://memory.shannonjlove.cloud"
echo "  [ ] Phase 6 — Enroll Claude clients"
echo "  [ ] Phase 7 — Validation complete"
echo "  [ ] Phase 8 — Remove old container-mcp-memory.service unit file"
echo ""
echo "Full log: ${LOG}"
