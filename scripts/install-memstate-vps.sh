#!/usr/bin/env bash
# Install memstate-mcp MCP config for Claude Code on Nexus VPS
# Run from the repo root on the VPS itself, or adapt as a remote deploy step.
set -euo pipefail

CONFIG_SRC="02-CONTAINERS/ai-mcp-servers/mcp-config.json"
CONFIG_DEST="$HOME/.claude/claude_desktop_config.json"

mkdir -p "$HOME/.claude"

if [ -f "$CONFIG_DEST" ]; then
  echo "Existing MCP config found at $CONFIG_DEST — merging not performed."
  echo "Manually add the memlord and memstate entries from $CONFIG_SRC"
  exit 0
fi

cp "$CONFIG_SRC" "$CONFIG_DEST"
echo "✓ MCP config installed at $CONFIG_DEST"
echo "⚠  Edit $CONFIG_DEST and replace YOUR_MEMSTATE_API_KEY_HERE with your key from https://memstate.ai/dashboard"
