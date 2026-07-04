#!/usr/bin/env bash
# =============================================================================
# WebTop Claude Code Bootstrap
# Run once inside the WebTop terminal to install Claude Code and apply MCP
# configuration pointing at the SJL Unified Cloud MCP gateway.
# =============================================================================
set -Eeuo pipefail

CLAUDE_MCP_TEMPLATE="${HOME}/.claude-code-mcp-template.json"
CLAUDE_SETTINGS_DIR="${HOME}/.claude"
CLAUDE_SETTINGS="${CLAUDE_SETTINGS_DIR}/settings.json"
HOSTINGER_KEY="${HOME}/.ssh/sjl_hostinger"
HOSTINGER_HOST="shannonjlove.cloud"
HOSTINGER_USER="root"

# ---------- Install Claude Code (npm-based) -----------------------------------
if ! command -v claude >/dev/null 2>&1; then
    echo "Installing Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_22.x | sudo bash -
    sudo apt-get install -y nodejs

    echo "Installing Claude Code..."
    sudo npm install -g @anthropic-ai/claude-code
fi

echo "Claude Code version: $(claude --version 2>/dev/null || echo 'unknown')"

# ---------- Apply MCP configuration ------------------------------------------
mkdir -p "$CLAUDE_SETTINGS_DIR"

if [[ -f "$CLAUDE_MCP_TEMPLATE" ]]; then
    cp "$CLAUDE_MCP_TEMPLATE" "${CLAUDE_SETTINGS_DIR}/mcp-servers.json"
    echo "MCP server configuration applied from template."
else
    echo "WARNING: MCP template not found at ${CLAUDE_MCP_TEMPLATE}. Configure manually."
fi

# ---------- Configure SSH for Hostinger VPS ----------------------------------
if [[ -f "$HOSTINGER_KEY" ]]; then
    chmod 600 "$HOSTINGER_KEY"

    cat >> "${HOME}/.ssh/config" <<EOF

Host hostinger-sjl
    HostName ${HOSTINGER_HOST}
    User ${HOSTINGER_USER}
    IdentityFile ${HOSTINGER_KEY}
    ServerAliveInterval 60
EOF

    echo "SSH config written for Host alias 'hostinger-sjl'."
    echo "Test connection: ssh hostinger-sjl hostname"
else
    echo "WARNING: SSH key not found at ${HOSTINGER_KEY}."
    echo "Mount the key via the docker-compose volume (SSH_KEY_PATH env var) and re-run."
fi

# ---------- Verify MCP endpoint availability ---------------------------------
echo ""
echo "Checking MCP gateway on ${HOSTINGER_HOST}:8797..."
if curl -sf --max-time 5 "http://${HOSTINGER_HOST}:8797/mcp" \
       -H "Content-Type: application/json" \
       -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"webtop-setup","version":"1.0"}}}' \
       | python3 -c "import json,sys; d=json.load(sys.stdin); print('MCP tools available' if 'result' in d else 'MCP error: ' + str(d))" 2>/dev/null; then
    echo ""
    echo "If the gateway reports readonly=true, run the repair script:"
    echo "  ssh hostinger-sjl 'sudo bash /path/to/guarded-repair-v1.7.sh'"
else
    echo "Could not reach ${HOSTINGER_HOST}:8797 — check that the VPS is up and the port is open."
fi

echo ""
echo "Setup complete. Open Claude Code: claude"
echo "Verify MCP: claude mcp list"
