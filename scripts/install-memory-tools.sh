#!/usr/bin/env bash
# =============================================================================
# install-memory-tools.sh
# Installs claude-memory and ai-memory on the current host using Podman Quadlets.
# Run on: Hostinger VPS (Nexus), Oracle sOs, or WebTop.
#
# Usage:
#   bash scripts/install-memory-tools.sh
#
# What it does:
#   1. Installs ai-memory binary via curl installer (or cargo)
#   2. Installs claude-memory Python MCP server to ~/.local/lib/claude-memory/
#   3. Creates memory data directories
#   4. Builds Podman images from source
#   5. Installs Quadlet unit files to /etc/containers/systemd/
#   6. Reloads systemd and starts services
#   7. Writes ~/.claude/settings.json with correct absolute paths
# =============================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLAUDE_DIR="${HOME}/.claude"
MEMORY_DIR="${CLAUDE_DIR}/memories"
AI_MEMORY_DB="${CLAUDE_DIR}/ai-memory.db"
CLAUDE_MEMORY_LIB="${HOME}/.local/lib/claude-memory"
QUADLET_DIR="/etc/containers/systemd"

ARCH="$(uname -m)"
if [[ "${ARCH}" == "aarch64" || "${ARCH}" == "arm64" ]]; then
  ENV_DIR="${REPO_ROOT}/01-DEPLOYMENT/oracle"
  echo "==> Detected ARM64 — Oracle sOs profile"
else
  ENV_DIR="${REPO_ROOT}/01-DEPLOYMENT/hostinger"
  echo "==> Detected x86_64 — Nexus/WebTop profile"
fi

# -----------------------------------------------------------------------------
# 1. Install ai-memory binary (stdio MCP for Claude Code)
# -----------------------------------------------------------------------------
echo "==> Installing ai-memory binary..."
if command -v ai-memory &>/dev/null; then
  echo "    Already installed: $(ai-memory --version 2>/dev/null || echo 'version unknown')"
else
  if command -v cargo &>/dev/null; then
    echo "    Building from source via cargo..."
    cargo install ai-memory --locked 2>/dev/null || \
      cargo install --git https://github.com/alphaonedev/ai-memory-mcp.git
  else
    echo "    Downloading via install script..."
    curl -fsSL https://raw.githubusercontent.com/alphaonedev/ai-memory-mcp/main/install.sh | sh
  fi
fi

# -----------------------------------------------------------------------------
# 2. Install claude-memory Python MCP server
# -----------------------------------------------------------------------------
echo "==> Installing claude-memory MCP server..."
mkdir -p "${CLAUDE_MEMORY_LIB}" "${MEMORY_DIR}"
cp "${REPO_ROOT}/02-CONTAINERS/ai-mcp-servers/claude-memory/server.py" \
   "${CLAUDE_MEMORY_LIB}/server.py"

if command -v pip3 &>/dev/null; then
  pip3 install --quiet --user "mcp[cli]>=1.0.0"
else
  echo "    WARNING: pip3 not found. Run: pip3 install 'mcp[cli]>=1.0.0'"
fi

# -----------------------------------------------------------------------------
# 3. Build Podman images from source
# -----------------------------------------------------------------------------
echo "==> Building Podman images..."
podman build \
  -t localhost/claude-memory:latest \
  "${REPO_ROOT}/02-CONTAINERS/ai-mcp-servers/claude-memory"

podman build \
  -t localhost/ai-memory:latest \
  "${REPO_ROOT}/02-CONTAINERS/ai-mcp-servers/ai-memory"

# -----------------------------------------------------------------------------
# 4. Create host data directories
# -----------------------------------------------------------------------------
echo "==> Creating data directories..."
mkdir -p /opt/claude-memory/memories /opt/ai-memory/data

# -----------------------------------------------------------------------------
# 5. Install Quadlet unit files
# -----------------------------------------------------------------------------
echo "==> Installing Quadlet unit files to ${QUADLET_DIR}..."
mkdir -p "${QUADLET_DIR}"
cp "${ENV_DIR}/quadlets/claude-memory.container" "${QUADLET_DIR}/claude-memory.container"
cp "${ENV_DIR}/quadlets/ai-memory.container"     "${QUADLET_DIR}/ai-memory.container"

# -----------------------------------------------------------------------------
# 6. Reload systemd and start services
# -----------------------------------------------------------------------------
echo "==> Reloading systemd and starting services..."
systemctl daemon-reload
systemctl enable --now claude-memory.service
systemctl enable --now ai-memory.service

echo "    claude-memory: $(systemctl is-active claude-memory.service)"
echo "    ai-memory:     $(systemctl is-active ai-memory.service)"

# -----------------------------------------------------------------------------
# 7. Write Claude Code project MCP settings with resolved absolute paths
# -----------------------------------------------------------------------------
echo "==> Writing .claude/settings.json..."
mkdir -p "${REPO_ROOT}/.claude"
cat > "${REPO_ROOT}/.claude/settings.json" <<EOF
{
  "mcpServers": {
    "claude-memory": {
      "command": "python3",
      "args": ["${CLAUDE_MEMORY_LIB}/server.py"],
      "env": {
        "MEMORY_ROOT": "${MEMORY_DIR}"
      }
    },
    "ai-memory": {
      "command": "ai-memory",
      "args": ["mcp", "--tier", "semantic"],
      "env": {
        "AI_MEMORY_DB": "${AI_MEMORY_DB}"
      }
    }
  }
}
EOF

# -----------------------------------------------------------------------------
# Done
# -----------------------------------------------------------------------------
echo ""
echo "==> Memory tools installed successfully."
echo ""
echo "    Claude Code MCP servers (stdio):"
echo "      claude-memory → ${CLAUDE_MEMORY_LIB}/server.py"
echo "      ai-memory     → $(command -v ai-memory 2>/dev/null || echo 'not in PATH')"
echo ""
echo "    Podman services (HTTP daemon / other agents):"
echo "      claude-memory.service  — podman logs claude-memory"
echo "      ai-memory.service      — http://127.0.0.1:9077"
echo ""
echo "    Storage:"
echo "      Claude memory files : ${MEMORY_DIR}"
echo "      ai-memory database  : ${AI_MEMORY_DB}"
echo "      Podman volumes      : /opt/claude-memory/  /opt/ai-memory/"
echo ""
echo "    Reload Claude Code to activate the new MCP servers."
