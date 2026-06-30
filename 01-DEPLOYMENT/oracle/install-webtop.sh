#!/usr/bin/env bash
# =============================================================================
# Oracle VPS (sOs) – WebTop + tag bootstrap installer
# Run as ubuntu on 150.136.77.26 (or via Tailscale 100.67.229.94)
#
# Usage:
#   ssh ubuntu@150.136.77.26 'bash -s' < install-webtop.sh
#   # or from a local clone:
#   ./install-webtop.sh
# =============================================================================

set -euo pipefail

REPO_DIR="$HOME/Hybrid-Personal-Cloud-Server-Infrastructure"
REPO_URL="git@github.com:shannonjlove/Hybrid-Personal-Cloud-Server-Infrastructure.git"
WEBTOP_DIR="$REPO_DIR/02-CONTAINERS/webtop"
DESKTOP_DIR="$HOME/webtop-home"

echo "==> [1/6] Updating system packages"
sudo apt-get update -qq
sudo apt-get upgrade -y -qq

echo "==> [2/6] Installing Docker + Docker Compose"
if ! command -v docker &>/dev/null; then
  curl -fsSL https://get.docker.com | sudo sh
  sudo usermod -aG docker "$USER"
  echo "     Docker installed. You may need to re-login for group membership."
fi

if ! docker compose version &>/dev/null 2>&1; then
  sudo apt-get install -y -qq docker-compose-plugin
fi

echo "==> [3/6] Cloning infrastructure repo (if not present)"
if [[ ! -d "$REPO_DIR" ]]; then
  git clone "$REPO_URL" "$REPO_DIR"
else
  echo "     Repo already present at $REPO_DIR, pulling latest"
  git -C "$REPO_DIR" pull --ff-only
fi

echo "==> [4/6] Creating WebTop desktop volume directory"
mkdir -p "$DESKTOP_DIR"

echo "==> [5/6] Writing .env for WebTop (edit before deploying)"
ENV_FILE="$WEBTOP_DIR/.env"
if [[ ! -f "$ENV_FILE" ]]; then
  cat > "$ENV_FILE" << 'ENV'
# WebTop environment — fill in before first run
TZ=America/Los_Angeles

# Generate with: echo $(htpasswd -nB admin) | sed -e 's/\$/\$\$/g'
WEBTOP_AUTH_USERS=admin:$$2y$$05$$REPLACEME
ENV
  echo "     Created $ENV_FILE — update WEBTOP_AUTH_USERS before starting"
else
  echo "     .env already exists, skipping"
fi

echo "==> [6/6] Starting WebTop"
cd "$WEBTOP_DIR"
docker compose up -d

echo ""
echo "================================================================="
echo " WebTop is up."
echo " Local:   http://localhost:3000"
echo " Remote:  https://desktop.shannonjlove.cloud"
echo ""
echo " The 'tag' command will be installed inside the container on"
echo " first boot (via custom-cont-init.d/10-install-tag.sh)."
echo " jdberry/tag source will be cloned to /opt/jdberry-tag."
echo "================================================================="
