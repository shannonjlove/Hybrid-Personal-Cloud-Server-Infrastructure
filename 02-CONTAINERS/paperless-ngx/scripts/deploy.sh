#!/usr/bin/env bash
# =============================================================================
# Paperless-NGX — Podman Quadlet Deployment
# Run as root on the Hostinger VPS (nexus.shannonjlove.cloud)
# Ubuntu 24.04 · Podman 4.x · systemd
# =============================================================================
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
QUADLET_SRC="${REPO_DIR}/paperless-ngx/quadlets"
ENV_EXAMPLE="${REPO_DIR}/paperless-ngx/.env.example"
DATA_ROOT="/opt/paperless"
SYSTEMD_QUADLET_DIR="/etc/containers/systemd"
ENV_DEST="/etc/paperless/paperless.env"

# ── 1. Check prerequisites ────────────────────────────────────────────────────

if [[ $EUID -ne 0 ]]; then
  echo "ERROR: Run as root (sudo $0)"
  exit 1
fi

echo "==> Checking Podman..."
if ! command -v podman &>/dev/null; then
  echo "  Installing podman..."
  apt-get update -qq
  apt-get install -y podman
fi
podman --version

echo "==> Checking systemd quadlet support..."
# Quadlet support requires podman >= 4.4 and systemd >= 252
if ! podman system info 2>/dev/null | grep -q "quadlet"; then
  # Try the newer approach — quadlet is built into podman 4.4+
  if ! /usr/lib/podman/quadlet --help &>/dev/null 2>&1 \
     && ! podman --version | awk '{split($3,v,"."); if(v[1]<4 || (v[1]==4 && v[2]<4)) exit 1}'; then
    echo "WARNING: Could not verify quadlet support. Proceeding anyway."
    echo "  Requires: podman >= 4.4"
  fi
fi

# ── 2. Create data directories ────────────────────────────────────────────────

echo "==> Creating Paperless data directories at ${DATA_ROOT}..."
mkdir -p \
  "${DATA_ROOT}/data" \
  "${DATA_ROOT}/media/documents/originals" \
  "${DATA_ROOT}/media/documents/thumbnails" \
  "${DATA_ROOT}/media/trash" \
  "${DATA_ROOT}/export" \
  "${DATA_ROOT}/consume/inbox" \
  "${DATA_ROOT}/consume/projects" \
  "${DATA_ROOT}/consume/areas" \
  "${DATA_ROOT}/consume/resources" \
  "${DATA_ROOT}/consume/archive"

# Consume subdirs auto-become tags via PAPERLESS_CONSUMER_SUBDIRS_AS_TAGS
echo "  Consume subdirs (will be auto-tagged): $(ls "${DATA_ROOT}/consume/")"
chown -R 1000:1000 "${DATA_ROOT}"
chmod -R 750 "${DATA_ROOT}"

# ── 3. Install env file ───────────────────────────────────────────────────────

mkdir -p /etc/paperless

if [ ! -f "${ENV_DEST}" ]; then
  echo "==> No env file found at ${ENV_DEST}"
  echo "  Creating from example — you MUST edit it before services start."
  cp "${ENV_EXAMPLE}" "${ENV_DEST}"
  chmod 640 "${ENV_DEST}"
  chown root:root "${ENV_DEST}"
  echo ""
  echo "  *** STOP — edit ${ENV_DEST} now, then re-run this script ***"
  echo "  Replace every CHANGE_ME value with real secrets."
  exit 1
fi

if grep -q "CHANGE_ME" "${ENV_DEST}"; then
  echo "ERROR: ${ENV_DEST} still contains CHANGE_ME placeholders."
  echo "  Fill in real values, then re-run."
  exit 1
fi

echo "==> Env file OK: ${ENV_DEST}"

# ── 4. Install quadlet unit files ─────────────────────────────────────────────

echo "==> Installing quadlet unit files to ${SYSTEMD_QUADLET_DIR}..."
mkdir -p "${SYSTEMD_QUADLET_DIR}"

cp "${QUADLET_SRC}/"*.network  "${SYSTEMD_QUADLET_DIR}/"
cp "${QUADLET_SRC}/"*.volume   "${SYSTEMD_QUADLET_DIR}/"
cp "${QUADLET_SRC}/"*.container "${SYSTEMD_QUADLET_DIR}/"

echo "  Installed:"
ls -1 "${SYSTEMD_QUADLET_DIR}"/paperless*

# ── 5. Reload systemd (generates service units from quadlets) ─────────────────

echo "==> Reloading systemd daemon (generates .service units from quadlets)..."
systemctl daemon-reload

# Verify generation
echo "  Generated units:"
systemctl list-unit-files 'paperless*.service' --no-legend | head -20

# ── 6. Pull container images ──────────────────────────────────────────────────

echo "==> Pulling container images (this may take a few minutes)..."
podman pull docker.io/valkey/valkey:8
podman pull docker.io/postgres:16-alpine
podman pull docker.io/gotenberg/gotenberg:8
podman pull ghcr.io/paperless-ngx/tika:latest
podman pull ghcr.io/paperless-ngx/paperless-ngx:latest

# ── 7. Enable and start services ──────────────────────────────────────────────

echo "==> Enabling and starting Paperless services..."
# Start in dependency order
systemctl enable --now paperless-broker.service
systemctl enable --now paperless-db.service
systemctl enable --now paperless-gotenberg.service
systemctl enable --now paperless-tika.service

echo "  Waiting 15s for dependencies to initialise..."
sleep 15

systemctl enable --now paperless.service

# ── 8. Firewall — block port 8000 from public internet ────────────────────────

echo "==> Configuring firewall (ufw)..."
if command -v ufw &>/dev/null; then
  # Allow from Docker bridge only (Traefik uses host.docker.internal → 172.17.0.1)
  ufw deny 8000 2>/dev/null || true
  echo "  Port 8000 blocked. Traefik reaches Paperless via host.docker.internal."
else
  echo "  WARN: ufw not found. Manually block port 8000 in Hostinger firewall group."
fi

# ── 9. Status check ───────────────────────────────────────────────────────────

echo ""
echo "==> Service status:"
systemctl status paperless.service --no-pager -l || true

echo ""
echo "==> Done! Next steps:"
echo "    1. Create admin user:  scripts/create-superuser.sh"
echo "    2. Add DNS A record:   paperless.shannonjlove.cloud → 72.61.74.250"
echo "    3. Restart Traefik:    docker compose restart traefik  (picks up dynamic config)"
echo "    4. Seed PARA tags:     scripts/seed-para-tags.sh  (after adding API token to env)"
echo "    5. Open:               https://paperless.shannonjlove.cloud"
echo ""
echo "    Logs: journalctl -u paperless.service -f"
