#!/usr/bin/env bash
# Add the Cloudflare MCP server to Claude Code on all servers where it runs.
# Run from any machine with SSH access (or directly on the VPS).
set -euo pipefail

MCP_CMD='claude mcp add cloudflare --transport http https://mcp.cloudflare.com/mcp'

VPS_HOST="${VPS_HOST:-72.61.74.250}"
VPS_USER="${VPS_USER:-root}"

ORACLE_HOST="${ORACLE_HOST:-100.67.229.94}"   # prefer Tailscale
ORACLE_USER="${ORACLE_USER:-ubuntu}"

WEBTOP_CONTAINER="${WEBTOP_CONTAINER:-webtop}"   # Podman container name

echo "=== Installing Cloudflare MCP server ==="

# ── VPS (Nexus) ───────────────────────────────────────────────────────────────
echo ""
echo "→ VPS ($VPS_USER@$VPS_HOST)"
ssh "$VPS_USER@$VPS_HOST" "$MCP_CMD" && echo "  ✓ VPS done" || echo "  ✗ VPS failed — is Claude Code installed?"

# ── Oracle (sOs) ──────────────────────────────────────────────────────────────
echo ""
echo "→ Oracle ($ORACLE_USER@$ORACLE_HOST)"
ssh "$ORACLE_USER@$ORACLE_HOST" "$MCP_CMD" && echo "  ✓ Oracle done" || echo "  ✗ Oracle failed — is Claude Code installed?"

# ── WebTop (docker exec) ──────────────────────────────────────────────────────
echo ""
echo "→ WebTop (podman exec $WEBTOP_CONTAINER)"
podman exec -u abc "$WEBTOP_CONTAINER" bash -c "$MCP_CMD" \
  && echo "  ✓ WebTop done" \
  || echo "  ✗ WebTop failed — Claude Code may not be installed in the container yet"

echo ""
echo "=== Done ==="
echo "Verify with: claude mcp list"
