#!/usr/bin/env bash
# Deploy mcp-server-oci on Hostinger Nexus (Docker host)
# Run from /opt/infrastructure or wherever the repo is cloned
set -euo pipefail

COMPOSE_DIR="$(cd "$(dirname "$0")/../../02-CONTAINERS/ai-mcp-servers" && pwd)"
OCI_CONFIG_SRC="${OCI_CONFIG_SRC:-$HOME/.oci}"

info()  { echo "[INFO]  $*"; }
error() { echo "[ERROR] $*" >&2; exit 1; }

command -v docker &>/dev/null || error "Docker not found"
docker compose version &>/dev/null || error "Docker Compose plugin not found"

# Validate OCI credentials are present on host before mounting
if [[ ! -f "$OCI_CONFIG_SRC/config" ]]; then
  echo ""
  echo "OCI credentials not found at $OCI_CONFIG_SRC"
  echo "Run:  oci setup config"
  echo "Then re-run this script."
  echo ""
  echo "Or set OCI_CONFIG_SRC=/path/to/your/.oci before running."
  exit 1
fi

info "Building and starting mcp-server-oci container"
docker compose -f "$COMPOSE_DIR/docker-compose.yml" \
  build --no-cache mcp-server-oci

docker compose -f "$COMPOSE_DIR/docker-compose.yml" \
  up -d mcp-server-oci

info "Container started. Checking health..."
sleep 3
docker compose -f "$COMPOSE_DIR/docker-compose.yml" ps mcp-server-oci

info "Done. MCP server is running as stdio process (spawned on demand by Claude)."
echo ""
echo "To add to Claude Code, update ~/.claude/claude.json:"
cat <<'EOF'
{
  "mcpServers": {
    "mcp-server-oci": {
      "command": "docker",
      "args": [
        "exec", "-i", "mcp-server-oci",
        "python", "-m", "mcp_server_oci.mcp_server", "--profile", "DEFAULT"
      ],
      "env": {
        "FASTMCP_LOG_LEVEL": "INFO"
      }
    }
  }
}
EOF
