#!/usr/bin/env bash
# Stops and optionally disables all rclone VFS mount systemd services.
# Safe to run before Docker stack shutdown or rclone config changes.
set -Eeuo pipefail

MOUNT_BASE="/mnt/sjl-cloud"
DRY_RUN=false
DISABLE=false

for arg in "$@"; do
  case "$arg" in
    --dry-run)  DRY_RUN=true ;;
    --disable)  DISABLE=true ;;
    *) echo "Unknown arg: $arg" >&2; exit 1 ;;
  esac
done

log() { printf '[%s] %s\n' "$(date -u +%H:%M:%SZ)" "$*"; }

if [[ "$EUID" -ne 0 ]]; then
  echo "ERROR: must run as root" >&2; exit 1
fi

SERVICES=(
  "220000_2026-07-01__SJL-JELLYFIN__rclone-idrive-e2-vfs.service"
  "220001_2026-07-01__SJL-JELLYFIN__rclone-pcloud-sjl-vfs.service"
  "220002_2026-07-01__SJL-JELLYFIN__rclone-dropbox-sjl-vfs.service"
)

MOUNTS=(
  "$MOUNT_BASE/idrive-primary"
  "$MOUNT_BASE/pcloud-sjl"
  "$MOUNT_BASE/dropbox-sjl"
)

log "DRY_RUN=$DRY_RUN  DISABLE=$DISABLE"

for svc in "${SERVICES[@]}"; do
  if systemctl is-active --quiet "$svc" 2>/dev/null; then
    log "Stopping $svc..."
    [[ "$DRY_RUN" == false ]] && systemctl stop "$svc" && log "  OK"
  else
    log "  already stopped: $svc"
  fi
  if [[ "$DISABLE" == true ]]; then
    log "Disabling $svc..."
    [[ "$DRY_RUN" == false ]] && systemctl disable "$svc" && log "  OK"
  fi
done

# Force-unmount anything still mounted
for mnt in "${MOUNTS[@]}"; do
  if mountpoint -q "$mnt" 2>/dev/null; then
    log "Force-unmounting $mnt..."
    if [[ "$DRY_RUN" == false ]]; then
      fusermount3 -uz "$mnt" 2>/dev/null || umount -l "$mnt" 2>/dev/null || \
        log "  WARN: could not unmount $mnt — may need manual: umount -l $mnt"
    fi
  fi
done

log "=== Mount status ==="
for mnt in "${MOUNTS[@]}"; do
  if mountpoint -q "$mnt" 2>/dev/null; then
    log "  STILL MOUNTED: $mnt"
  else
    log "  CLEAR: $mnt"
  fi
done
