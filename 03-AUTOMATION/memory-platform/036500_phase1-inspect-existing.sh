#!/usr/bin/env bash
# SJL Memory Platform — Phase 1 Existing Service Inspection
# Run as root on Hostinger VPS (72.61.74.250) — READ ONLY, no changes
# Canonical reference: 467d9199-036500_20260703__SJLSHAREDMEMORYPLATFORM__deploymentstrategyandclaudehandoff__v10.md
# Prerequisite: Phase 0 audit complete, existing mcp-memory container confirmed

set -uo pipefail

OUT="/root/sjl-memory-phase1-$(date +%Y%m%d-%H%M%S)"
mkdir -p "${OUT}"

log()  { printf '\n==============================\n%s\n==============================\n' "$*" | tee -a "${OUT}/inspect.log"; }
run()  { echo "$ $*" | tee -a "${OUT}/inspect.log"; "$@" 2>&1 | tee -a "${OUT}/inspect.log" || true; echo ""; }
note() { echo "NOTE: $*" | tee -a "${OUT}/inspect.log"; }

log "SJL Memory Platform — Phase 1 Existing Service Inspection"
echo "Output directory: ${OUT}"
echo "Date: $(date)" | tee -a "${OUT}/inspect.log"
echo ""

# ── 1.1 Container full detail ──────────────────────────────────────────────

log "1.1 — podman inspect mcp-memory (full JSON)"
run podman inspect mcp-memory | tee "${OUT}/mcp-memory-inspect.json"

log "1.1 — Container image details"
run podman inspect mcp-memory --format '{{.Image}}'
run podman inspect mcp-memory --format '{{.ImageName}}'
run podman inspect mcp-memory --format '{{.Config.Image}}'

log "1.1 — Image history (mcp-basic-memory:latest)"
run podman image history localhost/mcp-basic-memory:latest || \
  run podman image history mcp-basic-memory:latest || true

log "1.1 — Image inspect (labels, creation date, entrypoint)"
run podman image inspect localhost/mcp-basic-memory:latest 2>/dev/null | \
  python3 -c "
import sys, json
d = json.load(sys.stdin)[0]
print('Created:', d.get('Created','?'))
print('Labels:', json.dumps(d.get('Labels',{}), indent=2))
print('Entrypoint:', d.get('Config',{}).get('Entrypoint','?'))
print('Cmd:', d.get('Config',{}).get('Cmd','?'))
print('WorkingDir:', d.get('Config',{}).get('WorkingDir','?'))
print('ExposedPorts:', list(d.get('Config',{}).get('ExposedPorts',{}).keys()))
print('Env:', d.get('Config',{}).get('Env','?'))
" 2>/dev/null || true

# ── 1.2 Container mounts and environment ──────────────────────────────────

log "1.2 — Container mounts"
run podman inspect mcp-memory --format '{{json .Mounts}}' | python3 -m json.tool 2>/dev/null || true

log "1.2 — Container environment variables (REDACTED for secrets)"
podman inspect mcp-memory --format '{{json .Config.Env}}' 2>/dev/null | \
  python3 -c "
import sys, json, re
envs = json.loads(sys.stdin.read())
secret_keys = re.compile(r'(TOKEN|KEY|SECRET|PASSWORD|PASS|AUTH|CRED)', re.I)
for e in envs:
    k = e.split('=',1)[0]
    if secret_keys.search(k):
        print(f'{k}=***REDACTED***')
    else:
        print(e)
" 2>/dev/null | tee -a "${OUT}/inspect.log" || true

log "1.2 — Container port bindings"
run podman inspect mcp-memory --format '{{json .NetworkSettings.Ports}}' | python3 -m json.tool 2>/dev/null || true

# ── 1.3 Systemd unit ──────────────────────────────────────────────────────

log "1.3 — Systemd unit definition (container-mcp-memory.service)"
run systemctl cat container-mcp-memory.service 2>/dev/null || \
  find /etc/systemd /usr/lib/systemd /run/systemd \
       /root/.config/systemd /home -maxdepth 6 \
       -name '*mcp-memory*' -o -name '*memory*container*' 2>/dev/null | head -20

log "1.3 — Systemd status"
run systemctl status container-mcp-memory.service --no-pager -l

log "1.3 — Last 50 journal lines"
run journalctl -u container-mcp-memory.service -n 50 --no-pager

# ── 1.4 Storage inventory ─────────────────────────────────────────────────

log "1.4 — /opt/memory.shannonjlove.cloud contents"
if [[ -d /opt/memory.shannonjlove.cloud ]]; then
  run find /opt/memory.shannonjlove.cloud -maxdepth 6 -ls 2>/dev/null | head -80
  run du -sh /opt/memory.shannonjlove.cloud 2>/dev/null
else
  note "/opt/memory.shannonjlove.cloud does not exist"
fi

log "1.4 — /opt/mcp/data/memory contents"
if [[ -d /opt/mcp/data/memory ]]; then
  run find /opt/mcp/data/memory -maxdepth 6 -ls 2>/dev/null | head -80
  run du -sh /opt/mcp/data/memory 2>/dev/null
else
  note "/opt/mcp/data/memory does not exist"
fi

log "1.4 — /opt/mcp/repos/basic-memory contents"
if [[ -d /opt/mcp/repos/basic-memory ]]; then
  run find /opt/mcp/repos/basic-memory -maxdepth 6 -ls 2>/dev/null | head -80
  run du -sh /opt/mcp/repos/basic-memory 2>/dev/null
  # Check for git history
  if [[ -d /opt/mcp/repos/basic-memory/.git ]]; then
    run git -C /opt/mcp/repos/basic-memory log --oneline -10 2>/dev/null || true
  fi
else
  note "/opt/mcp/repos/basic-memory does not exist"
fi

log "1.4 — Database files (SQLite) in memory storage paths"
find /opt/memory.shannonjlove.cloud /opt/mcp/data/memory /opt/mcp/repos/basic-memory \
  -maxdepth 8 -name '*.db' -o -name '*.sqlite' -o -name '*.sqlite3' 2>/dev/null \
  | while read -r f; do
    echo "Found DB: $f  ($(du -sh "$f" 2>/dev/null | cut -f1) )"
  done | tee -a "${OUT}/inspect.log" || true

log "1.4 — Any SQLite database: record count probe"
find /opt/memory.shannonjlove.cloud /opt/mcp/data/memory /opt/mcp/repos/basic-memory \
  -maxdepth 8 \( -name '*.db' -o -name '*.sqlite' -o -name '*.sqlite3' \) 2>/dev/null \
  | head -5 \
  | while read -r dbfile; do
    echo "--- $dbfile ---"
    sqlite3 "${dbfile}" ".tables" 2>/dev/null || echo "(sqlite3 not available or unreadable)"
    sqlite3 "${dbfile}" "SELECT COUNT(*) || ' rows in entities' FROM entities;" 2>/dev/null || true
    sqlite3 "${dbfile}" "SELECT COUNT(*) || ' rows in relations' FROM relations;" 2>/dev/null || true
    sqlite3 "${dbfile}" "SELECT COUNT(*) || ' rows in observations' FROM observations;" 2>/dev/null || true
  done | tee -a "${OUT}/inspect.log" || true

# ── 1.5 Health and reachability ───────────────────────────────────────────

log "1.5 — Port binding check (what port is mcp-memory on?)"
run ss -ltnp | grep -E ':(9880|8880|8799|8800|3000|7700)' || echo "(no binding on common memory ports)"
run ss -ltnp | sort

log "1.5 — HTTP health check — try common ports"
for port in 9880 8880 8799 3000 7700 8000; do
  resp=$(curl -sS --max-time 3 "http://127.0.0.1:${port}/" 2>&1 | head -5) && \
    echo "Port ${port}: ${resp:0:200}" || echo "Port ${port}: no response"
done | tee -a "${OUT}/inspect.log"

log "1.5 — HTTP health check — /health and /sse on reachable ports"
for port in 9880 8880 8799 3000 7700 8000; do
  for path in /health /sse /mcp /api; do
    code=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 3 "http://127.0.0.1:${port}${path}" 2>/dev/null) && \
      echo "http://127.0.0.1:${port}${path} → HTTP ${code}"
  done
done | tee -a "${OUT}/inspect.log" || true

# ── 1.6 NPM proxy route ───────────────────────────────────────────────────

log "1.6 — Nginx Proxy Manager: find memory.shannonjlove.cloud route"
NPM_DB=$(find / -maxdepth 12 -name 'database.sqlite' 2>/dev/null | grep -i nginx | head -3)
if [[ -n "${NPM_DB}" ]]; then
  echo "NPM database: ${NPM_DB}" | tee -a "${OUT}/inspect.log"
  for db in ${NPM_DB}; do
    echo "--- Proxy hosts in ${db} ---"
    sqlite3 "${db}" \
      "SELECT domain_names, forward_host, forward_port, enabled FROM proxy_host;" \
      2>/dev/null | grep -Ei 'memory|cloud' || \
      sqlite3 "${db}" "SELECT domain_names, forward_host, forward_port, enabled FROM proxy_host;" 2>/dev/null | head -20
  done
else
  note "NPM database not found locally (likely inside Docker container)"
  # Try via Docker exec
  NPM_CONTAINER=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -Ei 'nginx.proxy|npm' | head -1)
  if [[ -n "${NPM_CONTAINER}" ]]; then
    run docker exec "${NPM_CONTAINER}" sqlite3 /data/database.sqlite \
      "SELECT domain_names, forward_host, forward_port, enabled FROM proxy_host;" 2>/dev/null || true
  else
    note "No NPM Docker container found"
  fi
fi

log "1.6 — Nginx Proxy Manager: all proxy hosts (via Docker exec)"
NPM_CONTAINER=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -Ei 'nginx.proxy|npm' | head -1)
if [[ -n "${NPM_CONTAINER}" ]]; then
  echo "NPM container: ${NPM_CONTAINER}" | tee -a "${OUT}/inspect.log"
  run docker exec "${NPM_CONTAINER}" sqlite3 /data/database.sqlite \
    "SELECT id, domain_names, forward_host, forward_port, enabled FROM proxy_host;" 2>/dev/null || true
fi

# ── 1.7 basic-memory version ──────────────────────────────────────────────

log "1.7 — basic-memory version (inside container)"
run podman exec mcp-memory basic-memory --version 2>/dev/null || \
  run podman exec mcp-memory python3 -c "import basic_memory; print(basic_memory.__version__)" 2>/dev/null || \
  run podman exec mcp-memory pip show basic-memory 2>/dev/null || \
  run podman exec mcp-memory cat /app/pyproject.toml 2>/dev/null || \
  run podman exec mcp-memory pip list 2>/dev/null | grep -i 'memory\|basic' || true

log "1.7 — basic-memory config inside container"
run podman exec mcp-memory cat /root/.basic-memory/config.yaml 2>/dev/null || \
  run podman exec mcp-memory cat /app/config.yaml 2>/dev/null || \
  run podman exec mcp-memory find / -maxdepth 8 -name 'config.yaml' 2>/dev/null | head -5 || true

log "1.7 — Process list inside container"
run podman exec mcp-memory ps aux 2>/dev/null || true

# ── Summary ───────────────────────────────────────────────────────────────

log "PHASE 1 INSPECTION COMPLETE"
echo ""
echo "Full output saved to: ${OUT}/inspect.log"
echo "Container JSON saved to: ${OUT}/mcp-memory-inspect.json"
echo ""
echo "Send BOTH files to Claude Code for Phase 1 analysis and decision."
echo ""
echo "Key questions this answers:"
echo "  1. What port is mcp-memory actually bound to?"
echo "  2. What database type and how many records?"
echo "  3. Is there an NPM proxy route already configured?"
echo "  4. What version of basic-memory?"
echo "  5. Is this service authoritative or experimental?"
