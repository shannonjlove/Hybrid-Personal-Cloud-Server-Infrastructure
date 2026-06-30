#!/usr/bin/env bash
# Sets up server-side access for Working Copy iOS app.
# Deploys Podman quadlet files and generates WebDAV credentials.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
QUADLET_DIR="${HOME}/.config/containers/systemd"
CONFIG_DIR="${HOME}/.config/webdav"
WEBDAV_USER="workingcopy"
WEBDAV_PASS="${WEBDAV_PASSWORD:?Set WEBDAV_PASSWORD env var}"

echo "==> Installing quadlet files"
mkdir -p "$QUADLET_DIR"
cp "$REPO_DIR/02-CONTAINERS/webdav/webdav.container" "$QUADLET_DIR/"
cp "$REPO_DIR/02-CONTAINERS/webdav/webdav-data.volume" "$QUADLET_DIR/"
systemctl --user daemon-reload
echo "    Quadlets installed"

echo "==> Writing WebDAV config and credentials"
mkdir -p "$CONFIG_DIR"
cp "$REPO_DIR/02-CONTAINERS/webdav/webdav.conf" "$CONFIG_DIR/"

if command -v htpasswd &>/dev/null; then
    htpasswd -Bbn "$WEBDAV_USER" "$WEBDAV_PASS" > "$CONFIG_DIR/.htpasswd"
else
    podman run --rm httpd:alpine htpasswd -Bbn "$WEBDAV_USER" "$WEBDAV_PASS" > "$CONFIG_DIR/.htpasswd"
fi
echo "    Credentials written for user: $WEBDAV_USER"

echo "==> Updating webdav.container to use config dir"
sed -i "s|%E/webdav|$CONFIG_DIR|g" "$QUADLET_DIR/webdav.container"
systemctl --user daemon-reload

echo "==> Setting up SSH for Working Copy"
AUTHORIZED_KEYS="$HOME/.ssh/authorized_keys"
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
touch "$AUTHORIZED_KEYS"
chmod 600 "$AUTHORIZED_KEYS"

if [ -n "${WORKING_COPY_SSH_PUBKEY:-}" ]; then
    if ! grep -qF "WorkingCopy@iPhone" "$AUTHORIZED_KEYS" 2>/dev/null; then
        echo "$WORKING_COPY_SSH_PUBKEY" >> "$AUTHORIZED_KEYS"
        echo "    Working Copy SSH key added"
    else
        echo "    Working Copy key already present"
    fi
else
    echo "    WORKING_COPY_SSH_PUBKEY not set — add it manually:"
    echo "    export WORKING_COPY_SSH_PUBKEY='ssh-rsa AAAA... WorkingCopy@iPhone-30062026'"
    echo "    Then re-run this script"
fi

echo "==> Starting webdav service"
systemctl --user enable --now webdav.service

echo ""
echo "Done. Working Copy connection details:"
echo "  URL:      http://$(hostname -I | awk '{print $1}'):8181/"
echo "  Username: $WEBDAV_USER"
echo "  Password: (value of WEBDAV_PASSWORD)"
echo ""
echo "Over Tailscale: http://$(hostname):8181/"
