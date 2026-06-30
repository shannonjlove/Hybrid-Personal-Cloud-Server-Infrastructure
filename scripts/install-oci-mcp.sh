#!/usr/bin/env bash
# Install mcp-server-oci on VPS (Nexus) and Oracle (sOs).
# Clones the repo to /opt/mcp-server-oci, installs deps with uv,
# and registers it with Claude Code.
set -euo pipefail

VPS_HOST="${VPS_HOST:-72.61.74.250}"
VPS_USER="${VPS_USER:-root}"

ORACLE_HOST="${ORACLE_HOST:-100.67.229.94}"
ORACLE_USER="${ORACLE_USER:-ubuntu}"

INSTALL_DIR="/opt/mcp-server-oci"
REPO_URL="https://github.com/jopsis/mcp-server-oci.git"

install_on() {
  local user=$1 host=$2
  echo ""
  echo "── $user@$host ──────────────────────"

  ssh "$user@$host" "
    set -euo pipefail
    if [ -d '$INSTALL_DIR/.git' ]; then
      echo '  Updating existing clone...'
      git -C '$INSTALL_DIR' pull --quiet --ff-only
    else
      echo '  Cloning mcp-server-oci...'
      git clone --depth 1 '$REPO_URL' '$INSTALL_DIR'
    fi

    echo '  Syncing dependencies with uv...'
    uv --directory '$INSTALL_DIR' sync --quiet

    echo '  Registering with Claude Code...'
    claude mcp add mcp-server-oci -- uv --directory '$INSTALL_DIR' run python -m mcp_server_oci.mcp_server \
      && echo '  ✓ Registered' \
      || echo '  ✗ Registration failed — is Claude Code installed?'
  "

  echo ""
  echo "  ⚠  OCI credentials must be configured at ~/.oci/config on $host"
  echo "     Run: oci setup config"
}

echo "=== Installing mcp-server-oci ==="
install_on "$VPS_USER" "$VPS_HOST"
install_on "$ORACLE_USER" "$ORACLE_HOST"
echo ""
echo "=== WebTop ==="
echo "  Handled by init/install-oci-mcp.sh (runs on container start)."
echo "  Set up OCI credentials at /config/.oci/config inside WebTop."
echo ""
echo "=== Done ==="
