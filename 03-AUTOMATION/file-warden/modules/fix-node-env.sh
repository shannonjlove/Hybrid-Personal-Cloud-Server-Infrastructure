#!/usr/bin/env bash
# File Warden — Node.js Environment Repair Module
# Resolves Node.js/npm version conflicts on Ubuntu/Debian (NodeSource).
# Standalone or invoked by: file-warden.sh fix-node
#
# Usage: sudo fix-node-env.sh [--log FILE]
set -Eeuo pipefail

LOG_FILE="/var/log/sjl-file-warden.log"

# ── Argument parsing ───────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --log) LOG_FILE="$2"; shift 2 ;;
    --help|-h)
      echo "Usage: sudo $0 [--log FILE]"
      echo "Repairs Node.js/npm version conflicts on Ubuntu/Debian (NodeSource)."
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

log() {
  local ts
  ts="$(date '+%Y-%m-%d %H:%M:%S')"
  echo "$ts [fix-node-env] $*" | tee -a "$LOG_FILE"
}

die() {
  log "ERROR: $*"
  echo "ERROR: $*" >&2
  exit 1
}

# ── Root check ─────────────────────────────────────────────────────────────────
[[ "${EUID}" -ne 0 ]] && die "Run as root: sudo bash $0"

log "=== Node.js Environment Repair ==="

# ── Version manager detection ──────────────────────────────────────────────────
# If nvm/volta/fnm manages Node, system package repair is not applicable.
if [[ -d "${HOME}/.nvm" ]] || command -v nvm >/dev/null 2>&1; then
  log "nvm detected. System npm conflict resolution skipped."
  log "Use 'nvm install --lts && nvm use --lts' to manage Node versions."
  exit 0
fi

if command -v volta >/dev/null 2>&1; then
  log "volta detected. System npm conflict resolution skipped."
  log "Use 'volta install node' to manage Node versions."
  exit 0
fi

if command -v fnm >/dev/null 2>&1; then
  log "fnm detected. System npm conflict resolution skipped."
  log "Use 'fnm install --lts && fnm use lts-latest' to manage Node versions."
  exit 0
fi

# ── Verify Node.js is present ──────────────────────────────────────────────────
node_version="$(node --version 2>/dev/null || echo "none")"
if [[ "$node_version" == "none" ]]; then
  die "Node.js not found. Install from NodeSource first: curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -"
fi
log "Node.js version: $node_version"

# Verify NodeSource repo is configured
if ! apt-cache policy nodejs 2>/dev/null | grep -q "nodesource"; then
  log "WARNING: NodeSource repo not detected. NodeSource provides the correct npm version."
  log "Re-add it with: curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -"
fi

# ── Remove conflicting system npm ─────────────────────────────────────────────
if dpkg -l 2>/dev/null | grep -q '^ii  npm '; then
  log "Removing conflicting system npm package..."
  apt-get remove --purge -y npm
  log "System npm removed."
else
  log "No conflicting system npm package found."
fi

# ── Clean up broken dependencies and cache ────────────────────────────────────
log "Cleaning up broken dependencies..."
apt-get autoremove -y
apt-get autoclean -y

# Clear npm cache if npm exists (may be stale from previous install)
if command -v npm >/dev/null 2>&1; then
  log "Clearing npm cache..."
  npm cache clean --force 2>/dev/null || true
fi

# ── Reinstall npm from NodeSource ─────────────────────────────────────────────
log "Updating package lists..."
apt-get update -qq

log "Installing npm from NodeSource repository..."
apt-get install -y npm

# ── Verification ──────────────────────────────────────────────────────────────
log "=== Verification ==="
node_ver="$(node --version 2>/dev/null || echo "MISSING")"
npm_ver="$(npm --version 2>/dev/null || echo "MISSING")"
log "  node: $node_ver"
log "  npm:  $npm_ver"

if [[ "$node_ver" == "MISSING" || "$npm_ver" == "MISSING" ]]; then
  die "Repair incomplete — node or npm still missing. Check NodeSource repo configuration."
fi

# Sanity check: npm should work
if npm --version >/dev/null 2>&1; then
  log "npm is functional."
else
  die "npm installed but not functional. Check PATH: $(echo "$PATH")"
fi

log "=== Repair complete. node=$node_ver  npm=v$npm_ver ==="
echo "Node.js and npm are ready. Re-run any previously failed apt-get install commands."
