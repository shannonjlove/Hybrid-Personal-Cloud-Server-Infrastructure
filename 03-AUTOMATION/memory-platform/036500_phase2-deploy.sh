#!/usr/bin/env bash
# SJL Memory Platform — Phase 2: Host Preparation & Container Deployment
# Run as root on Hostinger VPS (72.61.74.250) — MUTATING, idempotent
# Canonical reference: 467d9199-036500_20260703__SJLSHAREDMEMORYPLATFORM__deploymentstrategyandclaudehandoff__v10.md
#
# Phase 1 pre-conditions (verified before this script is safe to run):
#   - /opt/mcp/data/memory: EMPTY (confirmed, no data to preserve)
#   - No NPM proxy route for memory.shannonjlove.cloud
#   - mcp-memory had no host port binding (internal network only)
#   - Zero active clients
#
# NEVER TOUCH: sjl-cloud-access-mcp-rw.service / port 8777

set -uo pipefail
IFS=$'\n\t'

STAMP="$(date +%Y%m%d-%H%M%S)"
LOG="/root/sjl-memory-phase2-${STAMP}.log"
exec > >(tee -a "${LOG}") 2>&1

log()  { printf '\n== %s ==\n' "$*"; }
ok()   { echo "  OK: $*"; }
warn() { echo "  WARN: $*"; }
note() { echo "  NOTE: $*"; }
fail() { echo ""; echo "  FAIL: $*" >&2; echo "  Log: ${LOG}"; exit 1; }

echo "SJL Memory Platform — Phase 2 Deployment"
echo "Date: $(date)"
echo "Log:  ${LOG}"
echo ""

[[ ${EUID:-$(id -u)} -eq 0 ]] || fail "Run as root."

# ── Configuration ─────────────────────────────────────────────────────────────

IMAGE_TAG="0.18.3"
IMAGE_PINNED="localhost/mcp-basic-memory:${IMAGE_TAG}"
IMAGE_LATEST="localhost/mcp-basic-memory:latest"
QUADLET_FILE="/etc/containers/systemd/mcp-memory.container"
DATA_DIR="/opt/mcp/data/memory"
MEMORY_PORT="9880"
OLD_SERVICE="container-mcp-memory.service"
NEW_SERVICE="mcp-memory.service"
NETWORK="mcp_internal"
QUADLET_GENERATOR="/usr/lib/systemd/system-generators/podman-system-generator"

# ── Pre-flight ────────────────────────────────────────────────────────────────

log "Pre-flight 1/4: Port ${MEMORY_PORT} must be free"
if ss -ltnp 2>/dev/null | grep -q ":${MEMORY_PORT}[^0-9]"; then
    # Port in use — is it our own service already running?
    if podman ps --format '{{.Names}}' 2>/dev/null | grep -q '^mcp-memory$'; then
        warn "Port ${MEMORY_PORT} is in use by mcp-memory already — will restart it"
    else
        fail "Port ${MEMORY_PORT} is in use by another process. Run: ss -ltnp | grep :${MEMORY_PORT}"
    fi
else
    ok "Port ${MEMORY_PORT} is free"
fi

log "Pre-flight 2/4: Image must exist"
podman image exists "${IMAGE_LATEST}" 2>/dev/null || fail "Image not found: ${IMAGE_LATEST}"
ok "Image exists: ${IMAGE_LATEST}"

log "Pre-flight 3/4: Data directory must exist"
[[ -d "${DATA_DIR}" ]] || fail "Data directory missing: ${DATA_DIR}"
DATA_BYTES=$(du -sb "${DATA_DIR}" 2>/dev/null | awk '{print $1}')
ok "Data directory: ${DATA_DIR} (${DATA_BYTES} bytes)"

log "Pre-flight 4/4: Podman network ${NETWORK}"
if ! podman network inspect "${NETWORK}" >/dev/null 2>&1; then
    warn "${NETWORK} not found — creating it"
    podman network create "${NETWORK}"
fi
ok "Network: ${NETWORK}"

# ── Dependency audit ──────────────────────────────────────────────────────────

log "Dependency audit: containers on ${NETWORK}"
podman network inspect "${NETWORK}" 2>/dev/null | \
    python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    if isinstance(data, list): data = data[0]
    for cid, info in data.get('Containers', {}).items():
        name = info.get('Name', cid[:12])
        if name != 'mcp-memory':
            print(f'  other container on {\"'\"$NETWORK\"'\"}: {name}')
except: pass
" 2>/dev/null || true
ok "Dependency audit done"

# ── Step 1: Retag image ───────────────────────────────────────────────────────

log "Step 1: Retag to pinned version"
if podman image exists "${IMAGE_PINNED}" 2>/dev/null; then
    ok "Already tagged: ${IMAGE_PINNED}"
else
    podman tag "${IMAGE_LATEST}" "${IMAGE_PINNED}"
    ok "Tagged: ${IMAGE_PINNED}"
fi

# ── Step 2: Detect transport ──────────────────────────────────────────────────

log "Step 2: Detect supported MCP transport"
TRANSPORT_HELP=$(podman run --rm --entrypoint="" "${IMAGE_PINNED}" \
    basic-memory mcp --help 2>&1 || true)

if echo "${TRANSPORT_HELP}" | grep -qi 'streamable.http'; then
    TRANSPORT="streamable-http"
    MCP_ENDPOINT="/mcp"
    ok "Transport: streamable-http"
else
    TRANSPORT="sse"
    MCP_ENDPOINT="/sse"
    warn "streamable-http not detected — falling back to SSE"
fi

# ── Step 3: Create Quadlet ────────────────────────────────────────────────────

log "Step 3: Create Quadlet at ${QUADLET_FILE}"
mkdir -p /etc/containers/systemd

cat > "${QUADLET_FILE}" <<QUADLET
# SJL Memory Platform — mcp-memory Quadlet
# Deployed: $(date +%Y-%m-%d)
# Image:     mcp-basic-memory ${IMAGE_TAG}
# Transport: ${TRANSPORT}

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

ok "Quadlet written: ${QUADLET_FILE}"

# ── Step 4: Stop old service ──────────────────────────────────────────────────

log "Step 4: Stop and disable ${OLD_SERVICE}"
if systemctl is-active --quiet "${OLD_SERVICE}" 2>/dev/null; then
    systemctl stop "${OLD_SERVICE}"
    sleep 2
    ok "Stopped ${OLD_SERVICE}"
else
    ok "${OLD_SERVICE} not active"
fi
if systemctl is-enabled --quiet "${OLD_SERVICE}" 2>/dev/null; then
    systemctl disable "${OLD_SERVICE}" 2>/dev/null || true
    ok "Disabled ${OLD_SERVICE}"
fi
# Remove the old generate-systemd unit file so it can't conflict
OLD_UNIT_FILE="/etc/systemd/system/${OLD_SERVICE}"
if [[ -f "${OLD_UNIT_FILE}" ]]; then
    rm -f "${OLD_UNIT_FILE}"
    ok "Removed old unit file: ${OLD_UNIT_FILE}"
fi

# ── Step 5: Start new service (Quadlet-aware) ─────────────────────────────────

log "Step 5: Load Quadlet and start ${NEW_SERVICE}"

# First reload: Quadlet generator runs as part of daemon-reload
systemctl daemon-reload
ok "daemon-reload (pass 1)"

# Quadlet units live in /run/systemd/generator — verify generator ran
GENERATED=$(find /run/systemd/generator* -name "${NEW_SERVICE}" 2>/dev/null | head -1)

if [[ -z "${GENERATED}" ]]; then
    warn "Quadlet generator did not produce ${NEW_SERVICE} — triggering manually"
    if [[ -x "${QUADLET_GENERATOR}" ]]; then
        "${QUADLET_GENERATOR}" \
            /run/systemd/generator \
            /run/systemd/generator \
            /run/systemd/generator 2>/dev/null || true
        systemctl daemon-reload
        ok "daemon-reload (pass 2 after manual generator)"
        GENERATED=$(find /run/systemd/generator* -name "${NEW_SERVICE}" 2>/dev/null | head -1)
    else
        warn "Generator not found at ${QUADLET_GENERATOR}"
    fi
fi

if [[ -n "${GENERATED}" ]]; then
    ok "Quadlet unit found: ${GENERATED}"
else
    warn "Quadlet unit still not found — attempting direct start anyway"
fi

# With Quadlet, use 'start' not 'enable --now'
# The [Install] WantedBy= symlink is created by the generator automatically
systemctl start "${NEW_SERVICE}" 2>&1 || {
    echo ""
    echo "  start failed — recent journal:"
    journalctl -u "${NEW_SERVICE}" -n 20 --no-pager 2>/dev/null || true
    fail "${NEW_SERVICE} failed to start. See journal above and ${LOG}"
}
ok "Started ${NEW_SERVICE}"

# Ensure it survives reboots (Quadlet creates WantedBy symlink, but verify)
WANTS_DIR="/run/systemd/generator/default.target.wants"
if [[ ! -L "${WANTS_DIR}/${NEW_SERVICE}" ]]; then
    mkdir -p "${WANTS_DIR}"
    ln -sf "${GENERATED:-${QUADLET_FILE}}" "${WANTS_DIR}/${NEW_SERVICE}" 2>/dev/null || true
fi

# ── Step 6: Verify ────────────────────────────────────────────────────────────

log "Step 6: Verify deployment"

echo "  Waiting 8s for container to initialize..."
sleep 8

echo ""
echo "  systemd status:"
systemctl status "${NEW_SERVICE}" --no-pager -l 2>/dev/null || true

echo ""
echo "  Container state:"
podman ps --filter name=mcp-memory --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' 2>/dev/null || true

echo ""
echo "  Port check:"
if ss -ltnp 2>/dev/null | grep ":${MEMORY_PORT}"; then
    ok "Port ${MEMORY_PORT} is listening"
else
    echo "  Port ${MEMORY_PORT} not yet listening — recent logs:"
    journalctl -u "${NEW_SERVICE}" -n 30 --no-pager 2>/dev/null || true
    podman logs mcp-memory --tail 20 2>/dev/null || true
    fail "Container not listening on ${MEMORY_PORT}. See above."
fi

echo ""
echo "  HTTP probe:"
for P in "/" "${MCP_ENDPOINT}" "/health"; do
    CODE=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 5 \
        "http://127.0.0.1:${MEMORY_PORT}${P}" 2>/dev/null || echo "000")
    echo "    GET http://127.0.0.1:${MEMORY_PORT}${P} → HTTP ${CODE}"
done

# ── Step 7: NPM proxy host instructions ──────────────────────────────────────

log "Step 7: Nginx Proxy Manager — add proxy host"
echo ""
echo "  Open: http://100.115.66.75:81  (NPM admin)"
echo ""
echo "  ┌─ Add Proxy Host ─────────────────────────────────────────┐"
echo "  │  Details:                                                │"
echo "  │    Domain Names:     memory.shannonjlove.cloud           │"
echo "  │    Forward Scheme:   http                                │"
echo "  │    Forward Hostname: 127.0.0.1                           │"
echo "  │    Forward Port:     ${MEMORY_PORT}                          │"
echo "  │    ☑ Block Common Exploits                               │"
echo "  │    ☑ Websockets Support                                  │"
echo "  │  SSL:                                                    │"
echo "  │    Request a new SSL Certificate (Let's Encrypt)         │"
echo "  │    ☑ Force SSL   ☑ HTTP/2 Support                        │"
echo "  │    Email: sjlove@shannonjeffreylove.com                  │"
echo "  └──────────────────────────────────────────────────────────┘"
echo ""
echo "  After saving, test:"
echo "    curl -I https://memory.shannonjlove.cloud/"

# ── Step 8: mcp-stack.yml cleanup note ───────────────────────────────────────

log "Step 8: Cleanup note"
COMPOSE_FILE="/opt/mcp/compose/mcp-stack.yml"
if [[ -f "${COMPOSE_FILE}" ]]; then
    note "Remove the 'memory:' service block from ${COMPOSE_FILE}"
    note "to prevent podman-compose conflicts with this Quadlet."
fi

# ── Summary ───────────────────────────────────────────────────────────────────

log "PHASE 2 COMPLETE"
echo ""
echo "  Container:  mcp-memory"
echo "  Image:      ${IMAGE_PINNED}"
echo "  Transport:  ${TRANSPORT}"
echo "  Local:      http://127.0.0.1:${MEMORY_PORT}${MCP_ENDPOINT}"
echo "  Public:     https://memory.shannonjlove.cloud${MCP_ENDPOINT}  (after NPM)"
echo "  Data:       ${DATA_DIR}"
echo "  Quadlet:    ${QUADLET_FILE}"
echo "  Service:    ${NEW_SERVICE}"
echo ""
echo "  Next: add NPM proxy host (Step 7 above)"
echo "  Log:  ${LOG}"
