#!/usr/bin/env bash
# Deploy existing OCI credentials from Nexus VPS to Oracle sOs and WebTop.
# Run this script ON the Nexus VPS as root — the credentials already live at
# /root/.oci/ and this script copies them to the other hosts.
#
# Usage (from repo root on Nexus VPS):
#   bash scripts/setup-oci-keys.sh
set -euo pipefail

OCI_DIR="/root/.oci"
KEY_FILE="${OCI_DIR}/oci_api_key.pem"
CONFIG_FILE="${OCI_DIR}/config"

ORACLE_HOST="${ORACLE_HOST:-100.67.229.94}"   # Tailscale
ORACLE_USER="${ORACLE_USER:-ubuntu}"
WEBTOP_CONTAINER="${WEBTOP_CONTAINER:-webtop}"

# ── Sanity check ──────────────────────────────────────────────────────────────
if [ ! -f "$KEY_FILE" ] || [ ! -f "$CONFIG_FILE" ]; then
  echo "✗ OCI config not found at $OCI_DIR — run this from the Nexus VPS as root."
  exit 1
fi

echo "Using existing OCI config:"
grep -v key_file "$CONFIG_FILE"
echo "key_file=$KEY_FILE"
echo ""

# ── Oracle sOs ────────────────────────────────────────────────────────────────
echo "→ Deploying to Oracle ($ORACLE_USER@$ORACLE_HOST)..."
ssh "$ORACLE_USER@$ORACLE_HOST" "mkdir -p ~/.oci && chmod 700 ~/.oci"
scp "$KEY_FILE"  "$ORACLE_USER@$ORACLE_HOST:~/.oci/oci_api_key.pem"

# Write config with corrected key_file path for ubuntu's home
ssh "$ORACLE_USER@$ORACLE_HOST" "cat > ~/.oci/config" <<EOF
[DEFAULT]
user=ocid1.user.oc1..aaaaaaaaen5tpfgxukg6npplcsk4kuiquvhjvqub2ojbxnwceczgqhn7buzq
fingerprint=gvEnNdwSx/0PYzo9MnbCM+bRiC46U8cQyCVlChGflvY
tenancy=ocid1.tenancy.oc1..aaaaaaaa7mkd2g7upfobixslaiz3ldrfpuyqtizuf25sy3pnw6ejaz7nnqda
region=us-ashburn-1
key_file=/home/ubuntu/.oci/oci_api_key.pem
EOF
ssh "$ORACLE_USER@$ORACLE_HOST" "chmod 600 ~/.oci/oci_api_key.pem ~/.oci/config"
echo "  ✓ Oracle done"

# ── WebTop container ──────────────────────────────────────────────────────────
echo ""
echo "→ Deploying to WebTop (podman container: $WEBTOP_CONTAINER)..."
podman exec "$WEBTOP_CONTAINER" mkdir -p /config/.oci
podman cp "$KEY_FILE"   "$WEBTOP_CONTAINER:/config/.oci/oci_api_key.pem"

podman exec "$WEBTOP_CONTAINER" bash -c "cat > /config/.oci/config" <<EOF
[DEFAULT]
user=ocid1.user.oc1..aaaaaaaaen5tpfgxukg6npplcsk4kuiquvhjvqub2ojbxnwceczgqhn7buzq
fingerprint=gvEnNdwSx/0PYzo9MnbCM+bRiC46U8cQyCVlChGflvY
tenancy=ocid1.tenancy.oc1..aaaaaaaa7mkd2g7upfobixslaiz3ldrfpuyqtizuf25sy3pnw6ejaz7nnqda
region=us-ashburn-1
key_file=/config/.oci/oci_api_key.pem
EOF
podman exec "$WEBTOP_CONTAINER" chmod 600 /config/.oci/oci_api_key.pem /config/.oci/config
echo "  ✓ WebTop done"

# ── Verify ────────────────────────────────────────────────────────────────────
echo ""
echo "→ Verifying Oracle connection..."
ssh "$ORACLE_USER@$ORACLE_HOST" \
  "oci iam region list --output table 2>/dev/null | head -5 || echo '  oci CLI not installed — install with: pip install oci-cli'"

echo ""
echo "✓ OCI credentials deployed to Oracle and WebTop."
echo "  mcp-server-oci will use them automatically on next Claude session."
