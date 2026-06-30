#!/usr/bin/env bash
# Runs at WebTop container start via /config/custom-cont-init.d/
# Clones mcp-server-oci into the persistent /config volume and keeps it updated.
# Requires install-uv.sh to have run first (uv must be on PATH).
set -euo pipefail

INSTALL_DIR="/config/mcp-server-oci"
UV="/config/.local/bin/uv"
export HOME=/config

if [ -d "$INSTALL_DIR/.git" ]; then
  echo "[init] Updating mcp-server-oci..."
  git -C "$INSTALL_DIR" pull --quiet --ff-only
else
  echo "[init] Cloning mcp-server-oci..."
  git clone --depth 1 https://github.com/jopsis/mcp-server-oci.git "$INSTALL_DIR"
fi

echo "[init] Syncing mcp-server-oci dependencies..."
"$UV" --directory "$INSTALL_DIR" sync --quiet
echo "[init] mcp-server-oci ready at $INSTALL_DIR"
echo "[init] NOTE: OCI config must exist at /config/.oci/config before use."
