#!/usr/bin/env bash
# =============================================================================
# Master Podman Quadlet Deployment — Nexus VPS
# Installs ALL service quadlets and starts them via systemd.
# Run as root on nexus.shannonjlove.cloud (Ubuntu 24.04)
# =============================================================================
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "ERROR: Run as root (sudo $0)"
  exit 1
fi

REPO="$(cd "$(dirname "$0")/.." && pwd)"
DEST="/etc/containers/systemd"

echo "==> Checking Podman..."
command -v podman &>/dev/null || { apt-get update -qq && apt-get install -y podman; }
podman --version

mkdir -p "$DEST"

# ── Helper ────────────────────────────────────────────────────────────────────

install_quadlets() {
  local dir="$1"
  local label="$2"
  if [ -d "$dir" ]; then
    echo "  Installing $label quadlets..."
    cp "$dir"/*.network  "$DEST/" 2>/dev/null || true
    cp "$dir"/*.volume   "$DEST/" 2>/dev/null || true
    cp "$dir"/*.container "$DEST/" 2>/dev/null || true
  fi
}

check_env() {
  local file="$1"
  local label="$2"
  if [ ! -f "$file" ]; then
    echo "  WARN: $file missing — copy the .env.example and fill in values before starting $label"
  elif grep -q "CHANGE_ME" "$file"; then
    echo "  WARN: $file still has CHANGE_ME placeholders — fill in real values before starting $label"
  else
    echo "  OK: $file"
  fi
}

# ── 1. Install all quadlet files ──────────────────────────────────────────────

echo ""
echo "==> Installing quadlet unit files to $DEST..."
install_quadlets "$REPO/02-CONTAINERS/nginx-proxy-manager/quadlets" "NPM"
install_quadlets "$REPO/02-CONTAINERS/bookstack/quadlets"           "BookStack"
install_quadlets "$REPO/02-CONTAINERS/photoprism/quadlets"          "PhotoPrism"
install_quadlets "$REPO/02-CONTAINERS/paperless-ngx/quadlets"       "Paperless-NGX"

echo ""
echo "==> Installed files:"
ls -1 "$DEST"/

# ── 2. Check env files ────────────────────────────────────────────────────────

echo ""
echo "==> Checking env files..."
check_env "/etc/bookstack/bookstack.env"    "BookStack"
check_env "/etc/photoprism/photoprism.env"  "PhotoPrism"
check_env "/etc/paperless/paperless.env"    "Paperless-NGX"

# ── 3. Create data directories ────────────────────────────────────────────────

echo ""
echo "==> Creating data directories..."
mkdir -p /opt/photoprism/originals
chown -R 1000:1000 /opt/photoprism
mkdir -p /opt/paperless/{data,media/documents/originals,media/documents/thumbnails,media/trash,export}
mkdir -p /opt/paperless/consume/{inbox,projects,areas,resources,archive}
chown -R 1000:1000 /opt/paperless

# ── 4. Reload systemd ─────────────────────────────────────────────────────────

echo ""
echo "==> Reloading systemd (generates .service units from quadlets)..."
systemctl daemon-reload

echo ""
echo "==> Generated units:"
systemctl list-unit-files 'nginx-proxy-manager.service' 'bookstack*.service' \
  'photoprism.service' 'paperless*.service' --no-legend 2>/dev/null || true

# ── 5. Pull images ────────────────────────────────────────────────────────────

echo ""
echo "==> Pulling images..."
podman pull docker.io/jc21/nginx-proxy-manager:latest
podman pull docker.io/mariadb:lts
podman pull docker.io/linuxserver/bookstack:latest
podman pull docker.io/photoprism/photoprism:latest
podman pull docker.io/valkey/valkey:8
podman pull docker.io/postgres:16-alpine
podman pull docker.io/gotenberg/gotenberg:8
podman pull ghcr.io/paperless-ngx/tika:latest
podman pull ghcr.io/paperless-ngx/paperless-ngx:latest

# ── 6. Start services ─────────────────────────────────────────────────────────

echo ""
echo "==> Starting services..."

# NPM first — it's the gateway
systemctl enable --now nginx-proxy-manager.service
echo "  NPM started. Admin UI: http://$(hostname -I | awk '{print $1}'):81"

# BookStack
systemctl enable --now bookstack-db.service
sleep 10
systemctl enable --now bookstack.service

# PhotoPrism
systemctl enable --now photoprism.service

# Paperless (deps first)
systemctl enable --now paperless-broker.service paperless-db.service
sleep 15
systemctl enable --now paperless-gotenberg.service paperless-tika.service
sleep 5
systemctl enable --now paperless.service

# ── 7. Status ─────────────────────────────────────────────────────────────────

echo ""
echo "==> Service status:"
for svc in nginx-proxy-manager bookstack photoprism paperless; do
  echo -n "  $svc: "
  systemctl is-active "${svc}.service" 2>/dev/null || echo "inactive"
done

echo ""
echo "==> Done! Next steps:"
echo "    1. Open NPM admin: http://<tailscale-ip>:81"
echo "       Login: admin@example.com / changeme  → change immediately"
echo "    2. Add proxy hosts (all with SSL → Let's Encrypt):"
echo "       paperless.shannonjlove.cloud → http://paperless:8000"
echo "       docs.shannonjlove.cloud      → http://bookstack:6875"
echo "       photos.shannonjlove.cloud    → http://photoprism:2342"
echo "    3. Create Paperless admin user:"
echo "       02-CONTAINERS/paperless-ngx/scripts/create-superuser.sh"
echo ""
echo "    Logs: journalctl -u <service>.service -f"
