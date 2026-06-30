#!/usr/bin/env bash
# Bootstrap iOS Working Copy access and shared AI env on a new machine.
# Runs stow-deploy, then generates runtime secrets not stored in git.
#
# Usage:
#   WEBDAV_PASSWORD=secret ./scripts/setup-ios-access.sh [vps|oracle|webtop]
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WEBDAV_PASS="${WEBDAV_PASSWORD:?Set WEBDAV_PASSWORD env var}"
WEBDAV_USER="workingcopy"
ENTITY="${1:-}"

# 1. Lay down symlinks via stow
echo "==> Running stow-deploy"
bash "$REPO_DIR/scripts/stow-deploy.sh" $ENTITY

# 2. Shared AI env — create from template if missing
AI_KEYS_DIR="${HOME}/.config/ai-keys"
if [ ! -f "$AI_KEYS_DIR/shared.env" ]; then
    cp "$AI_KEYS_DIR/shared.env.template" "$AI_KEYS_DIR/shared.env"
    chmod 600 "$AI_KEYS_DIR/shared.env"
    echo "==> Created shared.env — fill in your API keys"
else
    echo "==> shared.env already exists"
fi

# 3. Generate WebDAV htpasswd (runtime secret, not in git)
WEBDAV_CONFIG="${HOME}/.config/webdav"
mkdir -p "$WEBDAV_CONFIG"
if command -v htpasswd &>/dev/null; then
    htpasswd -Bbn "$WEBDAV_USER" "$WEBDAV_PASS" > "$WEBDAV_CONFIG/.htpasswd"
else
    podman run --rm httpd:alpine htpasswd -Bbn "$WEBDAV_USER" "$WEBDAV_PASS" \
        > "$WEBDAV_CONFIG/.htpasswd"
fi
chmod 600 "$WEBDAV_CONFIG/.htpasswd"
echo "==> htpasswd written for user: $WEBDAV_USER"

# 4. Start WebDAV quadlet (VPS only)
if systemctl --user list-unit-files webdav.service &>/dev/null 2>&1; then
    systemctl --user daemon-reload
    systemctl --user enable --now webdav.service
    echo "==> webdav.service started"
fi

echo ""
echo "======================================================"
echo " Working Copy WebDAV"
echo "   LAN:       http://$(hostname -I | awk '{print $1}'):8181/"
echo "   Tailscale: http://$(hostname -s):8181/"
echo "   User: $WEBDAV_USER  |  Pass: \$WEBDAV_PASSWORD"
echo ""
echo " Shared AI env: $AI_KEYS_DIR/shared.env"
echo "======================================================"
