#!/usr/bin/env bash
# Installs and enables rclone VFS mount systemd services for Jellyfin/Stash media access.
# Run as root on the VPS after deploying rclone.conf to /etc/rclone/rclone.conf.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYSTEMD_DIR="/etc/systemd/system"
RCLONE_CONF_SRC="${RCLONE_CONF_SRC:-}"  # optional: path to rclone.conf to install
MOUNT_BASE="/mnt/sjl-cloud"
LOG_DIR="/var/log/rclone"

log() { printf '[%s] %s\n' "$(date -u +%H:%M:%SZ)" "$*"; }

if [[ "$EUID" -ne 0 ]]; then
  echo "ERROR: must run as root" >&2; exit 1
fi

log "Creating mount points and log dir..."
mkdir -p \
  "$MOUNT_BASE/idrive-primary" \
  "$MOUNT_BASE/pcloud-sjl" \
  "$MOUNT_BASE/dropbox-sjl" \
  "$LOG_DIR"

# Install rclone.conf if provided
if [[ -n "$RCLONE_CONF_SRC" && -f "$RCLONE_CONF_SRC" ]]; then
  log "Installing rclone config to /etc/rclone/rclone.conf..."
  mkdir -p /etc/rclone
  install -m 600 "$RCLONE_CONF_SRC" /etc/rclone/rclone.conf
fi

if [[ ! -f /etc/rclone/rclone.conf ]]; then
  echo "WARN: /etc/rclone/rclone.conf not found — set RCLONE_CONF_SRC= or create it manually" >&2
fi

# Verify fuse3
if ! command -v fusermount3 &>/dev/null; then
  log "Installing fuse3..."
  apt-get install -y fuse3
fi

# Ensure /etc/fuse.conf has user_allow_other
if ! grep -q '^user_allow_other' /etc/fuse.conf 2>/dev/null; then
  log "Enabling user_allow_other in /etc/fuse.conf..."
  echo 'user_allow_other' >> /etc/fuse.conf
fi

# Install systemd units
for svc in \
  220000_2026-07-01__SJL-JELLYFIN__rclone-idrive-e2-vfs.service \
  220001_2026-07-01__SJL-JELLYFIN__rclone-pcloud-sjl-vfs.service \
  220002_2026-07-01__SJL-JELLYFIN__rclone-dropbox-sjl-vfs.service; do
  log "Installing $svc..."
  install -m 644 "$SCRIPT_DIR/$svc" "$SYSTEMD_DIR/$svc"
done

log "Reloading systemd daemon..."
systemctl daemon-reload

log "Enabling and starting VFS mount services..."
for svc in \
  220000_2026-07-01__SJL-JELLYFIN__rclone-idrive-e2-vfs.service \
  220001_2026-07-01__SJL-JELLYFIN__rclone-pcloud-sjl-vfs.service \
  220002_2026-07-01__SJL-JELLYFIN__rclone-dropbox-sjl-vfs.service; do
  systemctl enable --now "$svc" && log "  OK: $svc" || log "  WARN: $svc failed to start — check /var/log/rclone/"
done

log ""
log "=== Mount status ==="
for mnt in idrive-primary pcloud-sjl dropbox-sjl; do
  if mountpoint -q "$MOUNT_BASE/$mnt"; then
    log "  MOUNTED: $MOUNT_BASE/$mnt"
  else
    log "  NOT MOUNTED: $MOUNT_BASE/$mnt"
  fi
done

log ""
log "Mount paths for Jellyfin/Stash docker-compose volumes:"
log "  - $MOUNT_BASE/idrive-primary:/media/idrive-primary:ro"
log "  - $MOUNT_BASE/pcloud-sjl:/media/pcloud-sjl:ro"
log "  - $MOUNT_BASE/dropbox-sjl:/media/dropbox-sjl:ro"
