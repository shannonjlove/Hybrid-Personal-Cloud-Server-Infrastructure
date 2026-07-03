#!/usr/bin/env bash
# SJL Credential Store — Memory Server Setup
# Run as root on memory.shannonjlove.cloud
# Creates the authoritative GNU Stow package tree

set -Eeuo pipefail
IFS=$'\n\t'

STOW_ROOT="/etc/sjl-credentials/stow"

log() { printf '\n== %s ==\n' "$*"; }
die() { echo "ERROR: $*" >&2; exit 1; }

[[ ${EUID:-$(id -u)} -eq 0 ]] || die "Run as root."

log "Creating stow package tree at ${STOW_ROOT}"

# Package: Oracle Cloud credentials
mkdir -p "${STOW_ROOT}/oci/opt/secrets/oci"

# Package: Google Cloud credentials
mkdir -p "${STOW_ROOT}/gcp/opt/secrets/sjl-unified-mcp"

# Package: SJL Unified MCP runtime environment
mkdir -p "${STOW_ROOT}/sjl-unified-mcp-env/etc/sjl-unified-mcp"

# Package: SJL write-gate token
mkdir -p "${STOW_ROOT}/sjl-write-token/root"

# Lock down the tree — only root should access these
chmod 0700 /etc/sjl-credentials "${STOW_ROOT}"
find "${STOW_ROOT}" -type d -exec chmod 0700 {} \;

log "Stow tree ready"
cat <<INSTRUCTIONS

--- NEXT STEPS: populate the tree from the source server (Hostinger VPS) ---

Run the following from the VPS (root@72.61.74.250), adapting SSH identity as needed:

  scp /opt/secrets/oci/config \\
      root@memory.shannonjlove.cloud:${STOW_ROOT}/oci/opt/secrets/oci/config

  scp /opt/secrets/oci/oci_api_key.pem \\
      root@memory.shannonjlove.cloud:${STOW_ROOT}/oci/opt/secrets/oci/oci_api_key.pem

  scp /opt/secrets/sjl-unified-mcp/google-service-account.json \\
      root@memory.shannonjlove.cloud:${STOW_ROOT}/gcp/opt/secrets/sjl-unified-mcp/google-service-account.json

  scp /etc/sjl-unified-mcp/runtime.env \\
      root@memory.shannonjlove.cloud:${STOW_ROOT}/sjl-unified-mcp-env/etc/sjl-unified-mcp/runtime.env

  scp /root/.sjl-unified-mcp-write-token \\
      root@memory.shannonjlove.cloud:${STOW_ROOT}/sjl-write-token/root/.sjl-unified-mcp-write-token

After copying, set permissions on the memory server:
  chmod 0600 ${STOW_ROOT}/oci/opt/secrets/oci/config
  chmod 0600 ${STOW_ROOT}/oci/opt/secrets/oci/oci_api_key.pem
  chmod 0600 ${STOW_ROOT}/gcp/opt/secrets/sjl-unified-mcp/google-service-account.json
  chmod 0600 ${STOW_ROOT}/sjl-unified-mcp-env/etc/sjl-unified-mcp/runtime.env
  chmod 0600 ${STOW_ROOT}/sjl-write-token/root/.sjl-unified-mcp-write-token

Then run sjl-stow-client-setup.sh on each client server.

INSTRUCTIONS
