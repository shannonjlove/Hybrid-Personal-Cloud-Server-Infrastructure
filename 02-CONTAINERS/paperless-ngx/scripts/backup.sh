#!/usr/bin/env bash
# =============================================================================
# Paperless-NGX Backup (Podman)
# Exports documents + database dump to /opt/paperless/export/
# Schedule: 0 3 * * * root /path/to/backup.sh >> /var/log/paperless-backup.log 2>&1
# =============================================================================
set -euo pipefail

EXPORT_ROOT="/opt/paperless/export"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M")
BACKUP_DIR="${EXPORT_ROOT}/${TIMESTAMP}"

echo "[${TIMESTAMP}] Starting Paperless backup..."

if ! podman container inspect paperless &>/dev/null; then
  echo "ERROR: paperless container is not running. Aborting."
  exit 1
fi

mkdir -p "${BACKUP_DIR}"

# ── 1. Export all documents via Paperless management command ──────────────────
echo "==> Exporting documents..."
podman exec paperless \
  python manage.py document_exporter /usr/src/paperless/export/"${TIMESTAMP}"

# ── 2. Dump PostgreSQL ────────────────────────────────────────────────────────
echo "==> Dumping PostgreSQL..."
podman exec paperless-db \
  pg_dump -U paperless paperless \
  > "${BACKUP_DIR}/paperless_db_${TIMESTAMP}.sql"

# ── 3. Compress ───────────────────────────────────────────────────────────────
echo "==> Compressing..."
tar -czf "${EXPORT_ROOT}/paperless_backup_${TIMESTAMP}.tar.gz" \
  -C "${EXPORT_ROOT}" "${TIMESTAMP}"
rm -rf "${BACKUP_DIR}"

# ── 4. Prune old backups (keep 14) ────────────────────────────────────────────
echo "==> Pruning backups older than 14..."
ls -t "${EXPORT_ROOT}"/paperless_backup_*.tar.gz 2>/dev/null \
  | tail -n +15 \
  | xargs -r rm --

echo "[${TIMESTAMP}] Backup complete: ${EXPORT_ROOT}/paperless_backup_${TIMESTAMP}.tar.gz"
ls -lh "${EXPORT_ROOT}/paperless_backup_${TIMESTAMP}.tar.gz"
