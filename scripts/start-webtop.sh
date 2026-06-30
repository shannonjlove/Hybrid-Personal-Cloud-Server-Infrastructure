#!/usr/bin/env bash
# Deploy and start the WebTop container on Nexus VPS, then inject OCI credentials.
# Run ON the Nexus VPS as root from the repo root:
#   bash scripts/start-webtop.sh
#
# After the first run, just use: systemctl start webtop.service
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VPS_QUADLET_DIR="/etc/containers/systemd"
INFRA_DIR="/etc/infra/webtop"
INIT_DIR="${INFRA_DIR}/init"

OCI_DIR="/root/.oci"
KEY_FILE="${OCI_DIR}/oci_api_key.pem"
CONFIG_FILE="${OCI_DIR}/config"
WEBTOP_CONTAINER="${WEBTOP_CONTAINER:-webtop}"

# ── Sanity checks ─────────────────────────────────────────────────────────────
if [ "$(id -u)" != "0" ]; then
  echo "✗ Must run as root."
  exit 1
fi

if [ ! -d "$REPO_ROOT/quadlets/webtop" ]; then
  echo "✗ quadlets/webtop/ not found — run from the repo root."
  exit 1
fi

echo "=== WebTop Deployment ==="
echo ""

# ── Install quadlet unit files ─────────────────────────────────────────────────
echo "→ Installing quadlet unit files to $VPS_QUADLET_DIR..."
cp "$REPO_ROOT/quadlets/webtop/webtop.network"      "$VPS_QUADLET_DIR/"
cp "$REPO_ROOT/quadlets/webtop/webtop.container"    "$VPS_QUADLET_DIR/"
cp "$REPO_ROOT/quadlets/webtop/ollama.container"    "$VPS_QUADLET_DIR/"
cp "$REPO_ROOT/quadlets/webtop/webtop-data.volume"  "$VPS_QUADLET_DIR/"
cp "$REPO_ROOT/quadlets/webtop/ollama-data.volume"  "$VPS_QUADLET_DIR/"
echo "  ✓ Quadlet files installed"

# ── Create webtop.env if missing ───────────────────────────────────────────────
ENV_FILE="${VPS_QUADLET_DIR}/webtop.env"
if [ ! -f "$ENV_FILE" ]; then
  echo ""
  echo "→ Creating $ENV_FILE from example..."
  cp "$REPO_ROOT/quadlets/webtop/webtop.env.example" "$ENV_FILE"
  echo ""
  echo "  ⚠  IMPORTANT: Edit $ENV_FILE and set a real WEBTOP_BASIC_AUTH value."
  echo "     Generate one with:  htpasswd -nb youruser yourpassword"
  echo "     Then re-run this script (or just: systemctl daemon-reload && systemctl start webtop.service)"
  echo ""
  read -r -p "  Press Enter after editing the file, or Ctrl-C to abort and edit first..."
else
  echo "  ✓ $ENV_FILE already exists — skipping"
fi

# ── Install config and init scripts ───────────────────────────────────────────
echo ""
echo "→ Installing config files to $INFRA_DIR..."
mkdir -p "$INIT_DIR"
cp "$REPO_ROOT/02-CONTAINERS/webtop/mcp-config.json"         "$INFRA_DIR/mcp-config.json"
cp "$REPO_ROOT/02-CONTAINERS/webtop/init/install-uv.sh"      "$INIT_DIR/install-uv.sh"
cp "$REPO_ROOT/02-CONTAINERS/webtop/init/install-media-tools.sh" "$INIT_DIR/install-media-tools.sh"
cp "$REPO_ROOT/02-CONTAINERS/webtop/init/install-oci-mcp.sh" "$INIT_DIR/install-oci-mcp.sh"
chmod +x "$INIT_DIR"/*.sh
echo "  ✓ Config files installed"

# ── Enable podman socket (required for Traefik to discover the container) ──────
echo ""
echo "→ Ensuring podman.socket is enabled..."
systemctl enable --now podman.socket 2>/dev/null || true
echo "  ✓ podman.socket ready"

# ── Reload systemd and start services ─────────────────────────────────────────
echo ""
echo "→ Reloading systemd daemon..."
systemctl daemon-reload
echo "  ✓ daemon reloaded"

echo ""
echo "→ Starting webtop-network.service..."
systemctl enable --now webtop-network.service
systemctl start webtop-network.service 2>/dev/null || true

echo ""
echo "→ Starting ollama.service..."
systemctl enable --now ollama.service
systemctl start ollama.service 2>/dev/null || true

echo ""
echo "→ Starting webtop.service..."
systemctl enable --now webtop.service
systemctl start webtop.service

# ── Wait for container to be running ──────────────────────────────────────────
echo ""
echo "→ Waiting for WebTop container to be running..."
for i in $(seq 1 30); do
  if podman inspect "$WEBTOP_CONTAINER" --format '{{.State.Status}}' 2>/dev/null | grep -q "running"; then
    echo "  ✓ Container is running"
    break
  fi
  if [ "$i" -eq 30 ]; then
    echo "  ✗ Container did not start within 60s. Check: journalctl -u webtop.service"
    exit 1
  fi
  echo "  ... waiting ($i/30)"
  sleep 2
done

# ── Deploy OCI credentials to WebTop ──────────────────────────────────────────
if [ ! -f "$KEY_FILE" ] || [ ! -f "$CONFIG_FILE" ]; then
  echo ""
  echo "  ⚠  OCI credentials not found at $OCI_DIR — skipping credential injection."
  echo "     Run scripts/setup-oci-keys.sh after configuring OCI credentials."
else
  echo ""
  echo "→ Injecting OCI credentials into WebTop container..."
  podman exec "$WEBTOP_CONTAINER" mkdir -p /config/.oci

  podman cp "$KEY_FILE" "$WEBTOP_CONTAINER:/config/.oci/oci_api_key.pem"

  podman exec "$WEBTOP_CONTAINER" bash -c "cat > /config/.oci/config" <<EOF
[DEFAULT]
user=ocid1.user.oc1..aaaaaaaaen5tpfgxukg6npplcsk4kuiquvhjvqub2ojbxnwceczgqhn7buzq
fingerprint=gvEnNdwSx/0PYzo9MnbCM+bRiC46U8cQyCVlChGflvY
tenancy=ocid1.tenancy.oc1..aaaaaaaa7mkd2g7upfobixslaiz3ldrfpuyqtizuf25sy3pnw6ejaz7nnqda
region=us-ashburn-1
key_file=/config/.oci/oci_api_key.pem
EOF
  podman exec "$WEBTOP_CONTAINER" chmod 600 /config/.oci/oci_api_key.pem /config/.oci/config
  echo "  ✓ OCI credentials injected"
fi

# ── Summary ────────────────────────────────────────────────────────────────────
echo ""
echo "=== WebTop deployment complete ==="
echo ""
echo "  Desktop:  https://desktop.shannonjlove.cloud"
echo "  Status:   systemctl status webtop.service"
echo "  Logs:     journalctl -u webtop.service -f"
echo "  Shell:    podman exec -it webtop bash"
echo ""
echo "  ⚠  First start downloads the image (~1.5GB) and runs init scripts."
echo "     Init scripts install uv, ffmpeg/imagemagick, and mcp-server-oci."
echo "     This may take several minutes."
echo ""
echo "  ⚠  Set your MEMSTATE_API_KEY in $INFRA_DIR/mcp-config.json"
echo "     (get it from https://memstate.ai/dashboard)"
