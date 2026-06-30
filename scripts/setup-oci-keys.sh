#!/usr/bin/env bash
# Set up OCI API credentials and deploy to all servers.
#
# BEFORE RUNNING:
#   1. Log into https://cloud.oracle.com
#   2. Top-right avatar → User Settings → copy your User OCID
#   3. Top-right avatar → Tenancy → copy your Tenancy OCID
#   4. Run this script — it prints a public key
#   5. In OCI console: User Settings → API Keys → Add API Key → paste the key
#   6. Copy the fingerprint shown after upload and set OCI_FINGERPRINT below
#   7. Re-run with all vars set to deploy
#
# Usage:
#   OCI_USER_OCID="ocid1.user.oc1..aaa..." \
#   OCI_TENANCY_OCID="ocid1.tenancy.oc1..aaa..." \
#   OCI_FINGERPRINT="xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx" \
#   OCI_REGION="us-ashburn-1" \
#   bash scripts/setup-oci-keys.sh

set -euo pipefail

KEY_DIR="${HOME}/.oci"
KEY_FILE="${KEY_DIR}/oci_api_key.pem"
PUB_FILE="${KEY_DIR}/oci_api_key_public.pem"
CONFIG_FILE="${KEY_DIR}/config"

VPS_HOST="${VPS_HOST:-72.61.74.250}"
VPS_USER="${VPS_USER:-root}"
ORACLE_HOST="${ORACLE_HOST:-100.67.229.94}"
ORACLE_USER="${ORACLE_USER:-ubuntu}"

OCI_USER_OCID="${OCI_USER_OCID:-}"
OCI_TENANCY_OCID="${OCI_TENANCY_OCID:-}"
OCI_FINGERPRINT="${OCI_FINGERPRINT:-}"
OCI_REGION="${OCI_REGION:-us-ashburn-1}"

# ── Step 1: Generate key pair ─────────────────────────────────────────────────
mkdir -p "$KEY_DIR"
chmod 700 "$KEY_DIR"

if [ ! -f "$KEY_FILE" ]; then
  echo "Generating OCI API key pair (RSA 4096)..."
  openssl genrsa -out "$KEY_FILE" 4096
  openssl rsa -pubout -in "$KEY_FILE" -out "$PUB_FILE"
  chmod 600 "$KEY_FILE"
  echo "Keys written to $KEY_DIR"
else
  echo "Key already exists at $KEY_FILE — reusing."
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║  PASTE THIS PUBLIC KEY INTO THE OCI CONSOLE (API Keys section)  ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""
cat "$PUB_FILE"
echo ""

# ── Step 2: Check if we have all vars to build the config ─────────────────────
if [ -z "$OCI_USER_OCID" ] || [ -z "$OCI_TENANCY_OCID" ] || [ -z "$OCI_FINGERPRINT" ]; then
  echo "═══════════════════════════════════════════════════════════════════"
  echo "  NEXT STEPS:"
  echo ""
  echo "  1. Go to: https://cloud.oracle.com → top-right avatar"
  echo "     → User Settings → API Keys → Add API Key"
  echo "     → Paste Public Key → paste the key above → Add"
  echo ""
  echo "  2. Copy the Fingerprint shown after the key is added."
  echo ""
  echo "  3. Get your User OCID:"
  echo "     Profile → User Settings → copy OCID (starts with ocid1.user...)"
  echo ""
  echo "  4. Get your Tenancy OCID:"
  echo "     Profile → Tenancy → copy OCID (starts with ocid1.tenancy...)"
  echo ""
  echo "  5. Re-run with all variables set:"
  echo "     OCI_USER_OCID='ocid1.user.oc1...' \\"
  echo "     OCI_TENANCY_OCID='ocid1.tenancy.oc1...' \\"
  echo "     OCI_FINGERPRINT='xx:xx:xx:...' \\"
  echo "     OCI_REGION='us-ashburn-1' \\"
  echo "     bash scripts/setup-oci-keys.sh"
  echo "═══════════════════════════════════════════════════════════════════"
  exit 0
fi

# ── Step 3: Write ~/.oci/config locally ───────────────────────────────────────
cat > "$CONFIG_FILE" <<EOF
[DEFAULT]
user=${OCI_USER_OCID}
fingerprint=${OCI_FINGERPRINT}
tenancy=${OCI_TENANCY_OCID}
region=${OCI_REGION}
key_file=${KEY_FILE}
EOF
chmod 600 "$CONFIG_FILE"
echo "✓ Local OCI config written to $CONFIG_FILE"

# ── Step 4: Deploy to VPS ─────────────────────────────────────────────────────
echo ""
echo "→ Deploying to VPS ($VPS_USER@$VPS_HOST)..."
ssh "$VPS_USER@$VPS_HOST" "mkdir -p ~/.oci && chmod 700 ~/.oci"
scp "$KEY_FILE"    "$VPS_USER@$VPS_HOST:~/.oci/oci_api_key.pem"
scp "$PUB_FILE"    "$VPS_USER@$VPS_HOST:~/.oci/oci_api_key_public.pem"
scp "$CONFIG_FILE" "$VPS_USER@$VPS_HOST:~/.oci/config"
ssh "$VPS_USER@$VPS_HOST" "chmod 600 ~/.oci/oci_api_key.pem ~/.oci/config"
echo "  ✓ VPS done"

# ── Step 5: Deploy to Oracle ──────────────────────────────────────────────────
echo ""
echo "→ Deploying to Oracle ($ORACLE_USER@$ORACLE_HOST)..."
ssh "$ORACLE_USER@$ORACLE_HOST" "mkdir -p ~/.oci && chmod 700 ~/.oci"
scp "$KEY_FILE"    "$ORACLE_USER@$ORACLE_HOST:~/.oci/oci_api_key.pem"
scp "$PUB_FILE"    "$ORACLE_USER@$ORACLE_HOST:~/.oci/oci_api_key_public.pem"
# Update key_file path for the oracle user's home dir
sed "s|${KEY_FILE}|~/.oci/oci_api_key.pem|" "$CONFIG_FILE" | \
  ssh "$ORACLE_USER@$ORACLE_HOST" "cat > ~/.oci/config && chmod 600 ~/.oci/config"
echo "  ✓ Oracle done"

# ── Step 6: Note for WebTop ───────────────────────────────────────────────────
echo ""
echo "→ WebTop: copy credentials into the running container:"
echo "   podman cp ~/.oci/oci_api_key.pem webtop:/config/.oci/oci_api_key.pem"
echo "   podman cp ~/.oci/config           webtop:/config/.oci/config"
echo "   podman exec webtop chmod 600 /config/.oci/oci_api_key.pem /config/.oci/config"
echo "   # Update key_file path in the container's config:"
echo "   podman exec webtop sed -i 's|key_file=.*|key_file=/config/.oci/oci_api_key.pem|' /config/.oci/config"

echo ""
echo "✓ All done. Verify with: oci iam user get --user-id $OCI_USER_OCID"
