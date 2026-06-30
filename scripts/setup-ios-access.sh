#!/usr/bin/env bash
# Sets up server-side access for Working Copy iOS app.
# Run once on the server after deploying the WebDAV container.
set -euo pipefail

WEBDAV_USER="workingcopy"
WEBDAV_PASS="${WEBDAV_PASSWORD:?Set WEBDAV_PASSWORD env var}"
DATA_DIR="${WEBDAV_DATA_DIR:-/opt/webdav-data}"
HTPASSWD_FILE="$(dirname "$0")/../02-CONTAINERS/webdav/.htpasswd"

echo "==> Creating WebDAV data directory at $DATA_DIR"
mkdir -p "$DATA_DIR"

echo "==> Writing htpasswd file"
if command -v htpasswd &>/dev/null; then
    htpasswd -Bbn "$WEBDAV_USER" "$WEBDAV_PASS" > "$HTPASSWD_FILE"
else
    docker run --rm httpd:alpine htpasswd -Bbn "$WEBDAV_USER" "$WEBDAV_PASS" > "$HTPASSWD_FILE"
fi
echo "    Credentials written for user: $WEBDAV_USER"

echo "==> Setting up SSH authorized_keys for Working Copy"
AUTHORIZED_KEYS="$HOME/.ssh/authorized_keys"
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
touch "$AUTHORIZED_KEYS"
chmod 600 "$AUTHORIZED_KEYS"

if [ -n "${WORKING_COPY_SSH_PUBKEY:-}" ]; then
    if ! grep -qF "WorkingCopy@iPhone" "$AUTHORIZED_KEYS" 2>/dev/null; then
        echo "$WORKING_COPY_SSH_PUBKEY" >> "$AUTHORIZED_KEYS"
        echo "    Added Working Copy public key to authorized_keys"
    else
        echo "    Working Copy key already present"
    fi
else
    echo "    WORKING_COPY_SSH_PUBKEY not set — skipping SSH key install"
    echo "    Export it and re-run, or add manually:"
    echo "    export WORKING_COPY_SSH_PUBKEY='ssh-rsa AAAA... WorkingCopy@iPhone-30062026'"
fi

echo ""
echo "Done. Start the WebDAV container with:"
echo "  docker compose up -d webdav"
echo ""
echo "Working Copy connection details:"
echo "  URL:      http://<server-tailscale-ip>:8181/"
echo "  Username: $WEBDAV_USER"
echo "  Password: (the value of WEBDAV_PASSWORD you set)"
