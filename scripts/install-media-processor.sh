#!/usr/bin/env bash
# Install mcp-media-processor on VPS and Oracle.
# Installs FFmpeg + ImageMagick system dependencies and registers the MCP server
# with Claude Code on each host.
set -euo pipefail

VPS_HOST="${VPS_HOST:-72.61.74.250}"
VPS_USER="${VPS_USER:-root}"

ORACLE_HOST="${ORACLE_HOST:-100.67.229.94}"
ORACLE_USER="${ORACLE_USER:-ubuntu}"

MCP_CMD='claude mcp add mediaProcessor -- npx -y mcp-media-processor@latest'

install_deps() {
  local user=$1 host=$2
  echo "  → Installing FFmpeg + ImageMagick on $user@$host"
  ssh "$user@$host" "
    if ! command -v ffmpeg &>/dev/null || ! command -v convert &>/dev/null; then
      apt-get update -qq && apt-get install -y --no-install-recommends ffmpeg imagemagick
    else
      echo '  deps already installed'
    fi
  "
}

register_mcp() {
  local user=$1 host=$2
  echo "  → Registering mediaProcessor MCP on $user@$host"
  ssh "$user@$host" "$MCP_CMD" && echo "  ✓ done" || echo "  ✗ failed — is Claude Code installed?"
}

echo "=== Installing mcp-media-processor ==="

echo ""
echo "── VPS (Nexus) ──────────────────────"
install_deps "$VPS_USER" "$VPS_HOST"
register_mcp  "$VPS_USER" "$VPS_HOST"

echo ""
echo "── Oracle (sOs) ─────────────────────"
install_deps "$ORACLE_USER" "$ORACLE_HOST"
register_mcp  "$ORACLE_USER" "$ORACLE_HOST"

echo ""
echo "── WebTop ───────────────────────────"
echo "  FFmpeg + ImageMagick are installed inside WebTop by"
echo "  init/install-media-tools.sh on container start."
echo "  MCP entry is already in mcp-config.json."

echo ""
echo "=== Done ==="
