#!/usr/bin/env bash
# WebTop custom-cont-init.d script — runs once on container first boot
# Installs mcp-server-oci inside the desktop environment and writes
# the Claude Desktop config so the MCP server is available immediately.
set -euo pipefail

MCP_INSTALL="/config/mcp-server-oci"
VENV="$MCP_INSTALL/.venv"
CLAUDE_CONFIG="/config/.config/Claude/claude_desktop_config.json"
REPO_URL="https://github.com/jopsis/mcp-server-oci"

# Already installed — update only
if [[ -d "$MCP_INSTALL/.git" ]]; then
  git -C "$MCP_INSTALL" pull --ff-only
else
  git clone "$REPO_URL" "$MCP_INSTALL"
fi

python3 -m venv "$VENV"
"$VENV/bin/pip" install --quiet --upgrade pip
"$VENV/bin/pip" install --quiet \
  "git+https://github.com/modelcontextprotocol/python-sdk.git"
"$VENV/bin/pip" install --quiet \
  "oci>=2.0.0" "fastapi>=0.100.0" "uvicorn>=0.22.0" \
  "click>=8.1.0" "pydantic>=2.0.0" "loguru>=0.7.0"
"$VENV/bin/pip" install --quiet -e "$MCP_INSTALL"

# Write Claude Desktop config
mkdir -p "$(dirname "$CLAUDE_CONFIG")"
cat > "$CLAUDE_CONFIG" <<EOF
{
  "mcpServers": {
    "mcp-server-oci": {
      "command": "$VENV/bin/python",
      "args": ["-m", "mcp_server_oci.mcp_server", "--profile", "DEFAULT"],
      "env": {
        "PYTHONPATH": "$MCP_INSTALL",
        "FASTMCP_LOG_LEVEL": "INFO",
        "OCI_CONFIG_FILE": "/config/.oci/config"
      }
    }
  }
}
EOF

echo "[mcp-oci] Installation complete. Claude Desktop config written to $CLAUDE_CONFIG"
