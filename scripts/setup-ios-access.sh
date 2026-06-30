#!/usr/bin/env bash
# Sets up server-side Working Copy iOS access and shared AI environment.
# Run once on the server after cloning the repo.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
QUADLET_DIR="${HOME}/.config/containers/systemd"
AI_KEYS_DIR="${HOME}/.config/ai-keys"
WEBDAV_CONFIG_DIR="${HOME}/.config/webdav"
WEBDAV_USER="workingcopy"
WEBDAV_PASS="${WEBDAV_PASSWORD:?Set WEBDAV_PASSWORD env var}"

# --- SSH: Working Copy public key -------------------------------------------
echo "==> Installing Working Copy SSH public key"
AUTHORIZED_KEYS="${HOME}/.ssh/authorized_keys"
mkdir -p "${HOME}/.ssh"
chmod 700 "${HOME}/.ssh"
touch "$AUTHORIZED_KEYS"
chmod 600 "$AUTHORIZED_KEYS"

WC_KEY_FILE="$REPO_DIR/04-SECURITY/ssh/authorized_keys"
while IFS= read -r key; do
    [[ -z "$key" || "$key" == \#* ]] && continue
    if ! grep -qF "${key##* }" "$AUTHORIZED_KEYS" 2>/dev/null; then
        echo "$key" >> "$AUTHORIZED_KEYS"
        echo "    Added: ${key##* }"
    else
        echo "    Already present: ${key##* }"
    fi
done < "$WC_KEY_FILE"

# --- Shared AI env file ------------------------------------------------------
echo "==> Initialising shared AI env at $AI_KEYS_DIR"
mkdir -p "$AI_KEYS_DIR"
chmod 700 "$AI_KEYS_DIR"

if [ ! -f "$AI_KEYS_DIR/shared.env" ]; then
    cp "$REPO_DIR/shared.env.template" "$AI_KEYS_DIR/shared.env"
    chmod 600 "$AI_KEYS_DIR/shared.env"
    echo "    Created shared.env from template — fill in your keys"
else
    echo "    shared.env already exists — not overwritten"
fi

# --- WebDAV credentials ------------------------------------------------------
echo "==> Writing WebDAV credentials"
mkdir -p "$WEBDAV_CONFIG_DIR"
cp "$REPO_DIR/02-CONTAINERS/webdav/webdav.conf" "$WEBDAV_CONFIG_DIR/"

if command -v htpasswd &>/dev/null; then
    htpasswd -Bbn "$WEBDAV_USER" "$WEBDAV_PASS" > "$WEBDAV_CONFIG_DIR/.htpasswd"
else
    podman run --rm httpd:alpine htpasswd -Bbn "$WEBDAV_USER" "$WEBDAV_PASS" \
        > "$WEBDAV_CONFIG_DIR/.htpasswd"
fi
chmod 600 "$WEBDAV_CONFIG_DIR/.htpasswd"
echo "    htpasswd written for user: $WEBDAV_USER"

# --- Quadlets ----------------------------------------------------------------
echo "==> Installing Podman quadlets"
mkdir -p "$QUADLET_DIR"
sed "s|%E/webdav|$WEBDAV_CONFIG_DIR|g" \
    "$REPO_DIR/02-CONTAINERS/webdav/webdav.container" \
    > "$QUADLET_DIR/webdav.container"
systemctl --user daemon-reload
systemctl --user enable --now webdav.service
echo "    webdav.service started"

# --- Done --------------------------------------------------------------------
echo ""
echo "======================================================"
echo " Working Copy WebDAV"
echo "   URL:  http://$(hostname -I | awk '{print $1}'):8181/"
echo "   Over Tailscale: http://$(hostname):8181/"
echo "   User: $WEBDAV_USER"
echo "   Pass: (value of WEBDAV_PASSWORD)"
echo ""
echo " Shared AI env: $AI_KEYS_DIR/shared.env"
echo "   Fill in API keys, then reload dependent services."
echo "======================================================"
