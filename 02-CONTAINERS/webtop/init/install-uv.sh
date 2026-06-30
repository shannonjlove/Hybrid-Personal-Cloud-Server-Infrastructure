#!/usr/bin/env bash
# Runs at WebTop container start via /config/custom-cont-init.d/
# Installs uv (and uvx) for the abc user so mcp-ollama can run via Claude Desktop.
set -euo pipefail

UV_BIN="/config/.local/bin/uv"

if [ -f "$UV_BIN" ]; then
  exit 0
fi

echo "[init] Installing uv for mcp-ollama support..."

# Install uv into the persistent /config volume so it survives container rebuilds
export HOME=/config
curl -fsSL https://astral.sh/uv/install.sh | sh

# Symlink into a PATH location accessible to the desktop session
mkdir -p /config/.local/bin
ln -sf /config/.local/bin/uv /usr/local/bin/uv
ln -sf /config/.local/bin/uvx /usr/local/bin/uvx

echo "[init] uv installed: $(uv --version)"
