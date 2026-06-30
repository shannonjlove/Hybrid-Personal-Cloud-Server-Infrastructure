#!/usr/bin/env bash
# =============================================================================
# install-memory-tools.sh
# Installs claude-memory and ai-memory on the current host.
# Run on: Hostinger VPS, Oracle sOs, or WebTop.
#
# Usage:
#   bash scripts/install-memory-tools.sh
#
# What it does:
#   1. Installs ai-memory binary via curl installer (or cargo)
#   2. Installs claude-memory Python MCP server to ~/.local/lib/claude-memory/
#   3. Creates memory directories
#   4. Writes ~/.claude/settings.json with correct absolute paths
# =============================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLAUDE_DIR="${HOME}/.claude"
MEMORY_DIR="${CLAUDE_DIR}/memories"
AI_MEMORY_DB="${CLAUDE_DIR}/ai-memory.db"
CLAUDE_MEMORY_LIB="${HOME}/.local/lib/claude-memory"

echo "==> Creating memory directories..."
mkdir -p "${MEMORY_DIR}" "${CLAUDE_MEMORY_LIB}"

# -----------------------------------------------------------------------------
# 1. Install ai-memory binary
# -----------------------------------------------------------------------------
echo "==> Installing ai-memory..."
if command -v ai-memory &>/dev/null; then
  echo "    ai-memory already installed: $(ai-memory --version 2>/dev/null || echo 'version unknown')"
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
cp "${REPO_ROOT}/02-CONTAINERS/ai-mcp-servers/claude-memory/server.py" \
   "${CLAUDE_MEMORY_LIB}/server.py"

if command -v pip3 &>/dev/null; then
  pip3 install --quiet --user "mcp[cli]>=1.0.0"
elif command -v pip &>/dev/null; then
  pip install --quiet --user "mcp[cli]>=1.0.0"
else
  echo "    WARNING: pip not found. Install Python mcp package manually:"
  echo "      pip3 install 'mcp[cli]>=1.0.0'"
fi

# -----------------------------------------------------------------------------
# 3. Write Claude Code project settings with resolved absolute paths
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
# 4. Start Docker services (HTTP daemon mode for other agents)
# -----------------------------------------------------------------------------
echo "==> Starting memory Docker services..."

ARCH="$(uname -m)"
COMPOSE_BASE="-f ${REPO_ROOT}/02-CONTAINERS/ai-mcp-servers/docker-compose.yml"

if [[ "${ARCH}" == "aarch64" || "${ARCH}" == "arm64" ]]; then
  COMPOSE_OVERRIDE="-f ${REPO_ROOT}/01-DEPLOYMENT/oracle/memory-compose.override.yml"
  echo "    Detected ARM64 — using Oracle override"
else
  COMPOSE_OVERRIDE="-f ${REPO_ROOT}/01-DEPLOYMENT/hostinger/memory-compose.override.yml"
  echo "    Detected x86_64 — using Hostinger override"
fi

if command -v docker &>/dev/null; then
  docker compose ${COMPOSE_BASE} ${COMPOSE_OVERRIDE} up -d --build
  echo "    Docker services started."
  echo "    ai-memory HTTP daemon: http://127.0.0.1:9077"
else
  echo "    WARNING: docker not found — skipping container startup."
  echo "    To start manually:"
  echo "      docker compose ${COMPOSE_BASE} ${COMPOSE_OVERRIDE} up -d --build"
fi

# -----------------------------------------------------------------------------
# Done
# -----------------------------------------------------------------------------
echo ""
echo "==> Memory tools installed successfully."
echo ""
echo "    Claude Code MCP servers:"
echo "      claude-memory  → ${CLAUDE_MEMORY_LIB}/server.py"
echo "      ai-memory      → $(command -v ai-memory 2>/dev/null || echo 'not in PATH — check install')"
echo ""
echo "    Memory storage:"
echo "      Claude memory files : ${MEMORY_DIR}"
echo "      ai-memory database  : ${AI_MEMORY_DB}"
echo ""
echo "    HTTP daemon (other agents):"
echo "      ai-memory serve     : http://127.0.0.1:9077"
echo ""
echo "    Reload Claude Code to pick up the new MCP servers."
