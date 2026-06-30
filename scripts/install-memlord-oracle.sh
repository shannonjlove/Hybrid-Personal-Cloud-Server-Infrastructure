#!/usr/bin/env bash
# Deploy memlord to Oracle sOs (150.136.77.26 / Tailscale 100.67.229.94)
# Run from the repo root on your local machine.
set -euo pipefail

ORACLE_HOST="${ORACLE_HOST:-100.67.229.94}"   # prefer Tailscale
ORACLE_USER="${ORACLE_USER:-ubuntu}"
REMOTE_DIR="~/memlord"
COMPOSE_SRC="02-CONTAINERS/memlord/docker-compose.oracle.yml"
ENV_SRC="02-CONTAINERS/memlord/.env.example"

echo "→ Deploying memlord to Oracle sOs ($ORACLE_USER@$ORACLE_HOST)"

# Create remote directory
ssh "$ORACLE_USER@$ORACLE_HOST" "mkdir -p $REMOTE_DIR"

# Copy compose file
scp "$COMPOSE_SRC" "$ORACLE_USER@$ORACLE_HOST:$REMOTE_DIR/docker-compose.yml"

# Copy env template only if no .env exists yet
ssh "$ORACLE_USER@$ORACLE_HOST" "
  if [ ! -f $REMOTE_DIR/.env ]; then
    echo '.env not found — copying example template'
  fi
"
scp -n "$ENV_SRC" "$ORACLE_USER@$ORACLE_HOST:$REMOTE_DIR/.env" 2>/dev/null || \
  echo "  .env already exists on remote — skipping to preserve existing secrets"

echo ""
echo "⚠  Before starting, SSH in and edit the .env file:"
echo "   ssh $ORACLE_USER@$ORACLE_HOST"
echo "   nano $REMOTE_DIR/.env"
echo ""
echo "→ Then start the stack:"
echo "   ssh $ORACLE_USER@$ORACLE_HOST 'cd $REMOTE_DIR && docker compose up -d'"
echo ""

# Install memstate-mcp config for Claude Code on Oracle
echo "→ Installing memstate-mcp MCP config for Claude Code on Oracle..."
ssh "$ORACLE_USER@$ORACLE_HOST" "mkdir -p ~/.claude"
scp "02-CONTAINERS/ai-mcp-servers/mcp-config.json" \
    "$ORACLE_USER@$ORACLE_HOST:~/.claude/claude_desktop_config.json"

echo "✓ Done. Update MEMSTATE_API_KEY in ~/.claude/claude_desktop_config.json on Oracle."
