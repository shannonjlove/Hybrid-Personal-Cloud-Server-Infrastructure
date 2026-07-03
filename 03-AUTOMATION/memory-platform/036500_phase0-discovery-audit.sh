#!/usr/bin/env bash
# SJL Shared Memory Platform — Phase 0 Discovery Audit
# Run as root on Hostinger VPS (72.61.74.250) — READ ONLY, no changes
# Canonical reference: 467d9199-036500_20260703__SJLSHAREDMEMORYPLATFORM__deploymentstrategyandclaudehandoff__v10.md

set -uo pipefail

OUT="/root/sjl-memory-audit-$(date +%Y%m%d-%H%M%S)"
mkdir -p "${OUT}"

log()  { printf '\n==============================\n%s\n==============================\n' "$*" | tee -a "${OUT}/audit.log"; }
run()  { echo "$ $*" | tee -a "${OUT}/audit.log"; "$@" 2>&1 | tee -a "${OUT}/audit.log" || true; echo ""; }
note() { echo "NOTE: $*" | tee -a "${OUT}/audit.log"; }

log "SJL Memory Platform — Phase 0 Discovery Audit"
echo "Output directory: ${OUT}"
echo "Date: $(date)" | tee -a "${OUT}/audit.log"
echo ""

# ── 4.1 Existing containers ────────────────────────────────────────────────

log "4.1 — Memory-related containers (rootful podman)"
run podman ps -a --format '{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' \
  | grep -Ei 'memory|mcp.memory|memory.platform|memory.app' || echo "(none found)"

log "4.1 — Memory-related containers (rootless sjl user)"
run sudo -iu sjl podman ps -a --format '{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' \
  | grep -Ei 'memory|mcp.memory|memory.platform|memory.app' || echo "(none found)"

log "4.1 — ALL containers (rootful — for full picture)"
run podman ps -a --format '{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'

log "4.1 — ALL containers (rootless sjl)"
run sudo -iu sjl podman ps -a --format '{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'

# ── 4.2 Quadlets and systemd units ────────────────────────────────────────

log "4.2 — Memory-related Quadlet files"
run find /etc/containers/systemd \
  /usr/share/containers/systemd \
  /root/.config/containers/systemd \
  -maxdepth 2 -type f \
  \( -iname '*memory*' -o -iname '*mcp*memory*' \) \
  -print 2>/dev/null || echo "(none found)"

log "4.2 — Memory-related systemd units (list-unit-files)"
run systemctl list-unit-files | grep -Ei 'memory|mcp-memory' || echo "(none found)"

log "4.2 — Memory-related systemd units (list-units --all)"
run systemctl list-units --all | grep -Ei 'memory|mcp-memory' || echo "(none found)"

log "4.2 — ALL Quadlet files (full inventory)"
run find /etc/containers/systemd \
  /usr/share/containers/systemd \
  /root/.config/containers/systemd \
  -maxdepth 3 -type f 2>/dev/null || echo "(none found)"

# ── 4.3 Storage paths ─────────────────────────────────────────────────────

log "4.3 — Memory-related storage under /srv /opt /var/lib"
run find /srv /opt /var/lib \
  -maxdepth 4 \
  \( -iname '*memory*' -o -iname '*mcp-memory*' \) \
  -print 2>/dev/null || echo "(none found)"

log "4.3 — /srv/sjl directory tree (if exists)"
if [[ -d /srv/sjl ]]; then
  run find /srv/sjl -maxdepth 5 -print 2>/dev/null
else
  note "/srv/sjl does not exist yet"
fi

# ── 4.4 Port 9880 listeners ────────────────────────────────────────────────

log "4.4 — Port 9880 listeners"
run ss -lntup | grep ':9880' || echo "(port 9880 is free)"

log "4.4 — All MCP-range listeners (ports 8700-8900)"
run ss -ltnp | grep -E ':(87[0-9]{2}|88[0-9]{2})' | sort || echo "(none)"

log "4.4 — All listening ports (full)"
run ss -ltnp | sort

# ── 4.5 Podman networks and volumes ───────────────────────────────────────

log "4.5 — Podman networks (rootful)"
run podman network ls

log "4.5 — Podman volumes (rootful)"
run podman volume ls

log "4.5 — Memory-related volumes (rootful)"
run podman volume ls --format '{{.Name}}' | grep -Ei 'memory|mcp' || echo "(none)"

log "4.5 — Podman networks (rootless sjl)"
run sudo -iu sjl podman network ls

log "4.5 — Podman volumes (rootless sjl)"
run sudo -iu sjl podman volume ls

log "4.5 — Memory-related volumes (rootless sjl)"
run sudo -iu sjl podman volume ls --format '{{.Name}}' | grep -Ei 'memory|mcp' || echo "(none)"

# ── 4.6 Nginx Proxy Manager config ────────────────────────────────────────

log "4.6 — Nginx Proxy Manager — find proxy host config for memory.shannonjlove.cloud"
run find /srv /opt /var/lib /root -maxdepth 8 \
  -path '*/nginx-proxy-manager*' -o -path '*/npm*' 2>/dev/null \
  | head -30 || echo "(no NPM config paths found)"

# Try to find NPM sqlite DB
run find / -maxdepth 10 -name 'database.sqlite' 2>/dev/null | head -5 || true

# ── DNS verification ───────────────────────────────────────────────────────

log "DNS — memory.shannonjlove.cloud resolution"
run host memory.shannonjlove.cloud || run dig +short memory.shannonjlove.cloud || echo "(dig/host not available)"

note "DNS check: no explicit 'memory' A record found via Hostinger API."
note "Domain resolves via wildcard * → 72.61.74.250."
note "An explicit A record for 'memory' should be added for clarity."

# ── Existing memory application images ────────────────────────────────────

log "Existing memory-related images (rootful)"
run podman images | grep -Ei 'memory|mcp.memory' || echo "(none)"

log "Existing memory-related images (rootless sjl)"
run sudo -iu sjl podman images | grep -Ei 'memory|mcp.memory' || echo "(none)"

# ── Docker (if present) ───────────────────────────────────────────────────

log "Docker containers (if docker is present)"
if command -v docker >/dev/null 2>&1; then
  run docker ps -a --format '{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' \
    | grep -Ei 'memory|npm|nginx.proxy' || echo "(none memory-related)"
  run docker network ls
  run docker volume ls | grep -Ei 'memory|npm' || echo "(none)"
else
  note "Docker not installed on this VPS"
fi

# ── Summary ───────────────────────────────────────────────────────────────

log "AUDIT COMPLETE"
echo ""
echo "Full output saved to: ${OUT}/audit.log"
echo ""
echo "Next steps:"
echo "  1. Review ${OUT}/audit.log for existing memory deployments"
echo "  2. If an existing memory container is found: DO NOT deploy until reviewed"
echo "  3. Report findings back to Claude Code for Phase 1 decision"
echo ""
echo "Send the audit.log contents to Claude Code."
