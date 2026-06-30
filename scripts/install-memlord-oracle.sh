#!/usr/bin/env bash
# Deploy memlord to Oracle sOs via Podman Quadlets.
# Run from the repo root on your local machine.
set -euo pipefail

ORACLE_HOST="${ORACLE_HOST:-100.67.229.94}"   # prefer Tailscale
ORACLE_USER="${ORACLE_USER:-ubuntu}"

echo "→ Deploying memlord quadlets to Oracle sOs ($ORACLE_USER@$ORACLE_HOST)"

# Copy quadlet files
scp quadlets/oracle/*.container \
    quadlets/oracle/*.volume \
    quadlets/oracle/*.network \
    "$ORACLE_USER@$ORACLE_HOST:/tmp/"

ssh "$ORACLE_USER@$ORACLE_HOST" "sudo mv /tmp/*.container /tmp/*.volume /tmp/*.network /etc/containers/systemd/ 2>/dev/null || true"

# Copy env template only if no env file exists yet
ssh "$ORACLE_USER@$ORACLE_HOST" \
  "[ -f /etc/containers/systemd/memlord.env ] && echo '  .env already exists — skipping' || true"
scp quadlets/oracle/memlord.env.example "$ORACLE_USER@$ORACLE_HOST:/tmp/memlord.env.example"
ssh "$ORACLE_USER@$ORACLE_HOST" "
  sudo bash -c '
    if [ ! -f /etc/containers/systemd/memlord.env ]; then
      cp /tmp/memlord.env.example /etc/containers/systemd/memlord.env
      chmod 600 /etc/containers/systemd/memlord.env
      echo \"  Env template installed. Edit /etc/containers/systemd/memlord.env before starting.\"
    fi
  '
"

echo ""
echo "⚠  Before starting, fill in secrets on Oracle:"
echo "   ssh $ORACLE_USER@$ORACLE_HOST"
echo "   sudo nano /etc/containers/systemd/memlord.env"
echo ""
echo "→ Then activate:"
echo "   sudo systemctl daemon-reload"
echo "   sudo systemctl enable --now memlord-db.service memlord.service"
echo ""

# Install MCP config for Claude Code on Oracle
echo "→ Installing MCP config for Claude Code on Oracle..."
ssh "$ORACLE_USER@$ORACLE_HOST" "mkdir -p ~/.claude"
scp "02-CONTAINERS/ai-mcp-servers/mcp-config.json" \
    "$ORACLE_USER@$ORACLE_HOST:~/.claude/claude_desktop_config.json"

echo "✓ Done. Update MEMSTATE_API_KEY in ~/.claude/claude_desktop_config.json on Oracle."
echo "  Also run: claude mcp add cloudflare --transport http https://mcp.cloudflare.com/mcp"
