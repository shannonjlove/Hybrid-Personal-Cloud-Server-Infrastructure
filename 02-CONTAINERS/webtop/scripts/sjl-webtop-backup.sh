#!/bin/bash
set -euo pipefail

# Source directory: matches the Quadlet bind-mount on the Oracle host
SOURCE_DIR="/srv/sjl/300000_AREAS/390000_oracle-webtop/config"

# Backup destination
BACKUP_BASE="/srv/sjl/500000_ARCHIVES/590000_oracle-webtop-backups"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="${BACKUP_BASE}/webtop-config-${TIMESTAMP}.tar.gz"
BACKUP_TMP="${BACKUP_FILE}.tmp"

# Keep this many days of backups; older files are pruned
RETENTION_DAYS=7

mkdir -p "${BACKUP_BASE}"

if [ ! -d "${SOURCE_DIR}" ]; then
    echo "[$(date -u +%FT%TZ)] Source directory ${SOURCE_DIR} not found — skipping backup."
    exit 0
fi

echo "[$(date -u +%FT%TZ)] Starting backup of ${SOURCE_DIR} → ${BACKUP_FILE}"

# Write to a .tmp file first; rename only after a successful tar + verify.
# This ensures no partial archive is ever left with a final filename.
tar \
    --warning=no-file-changed \
    --exclude='.cache' \
    --exclude='.thumbnails' \
    --exclude='__pycache__' \
    -czf "${BACKUP_TMP}" \
    -C "$(dirname "${SOURCE_DIR}")" \
    "$(basename "${SOURCE_DIR}")"

# Integrity check before promoting the temp file
if ! tar -tzf "${BACKUP_TMP}" > /dev/null 2>&1; then
    echo "[$(date -u +%FT%TZ)] Verification failed — removing ${BACKUP_TMP}" >&2
    rm -f "${BACKUP_TMP}"
    exit 1
fi

mv "${BACKUP_TMP}" "${BACKUP_FILE}"

BACKUP_SIZE=$(du -sh "${BACKUP_FILE}" | cut -f1)
echo "[$(date -u +%FT%TZ)] Backup successful: ${BACKUP_FILE} (${BACKUP_SIZE})"

# Prune archives older than RETENTION_DAYS
find "${BACKUP_BASE}" -name "webtop-config-*.tar.gz" -mtime "+${RETENTION_DAYS}" -delete
echo "[$(date -u +%FT%TZ)] Pruned archives older than ${RETENTION_DAYS} days."

exit 0
