#!/usr/bin/env bash
# Replicates the SJL IDrive E2 S3 folder hierarchy (empty) to Dropbox and pCloud destinations.
# No file contents are copied. Safe to rerun (idempotent). Supports --dry-run.
set -Eeuo pipefail

# ── Configuration ─────────────────────────────────────────────────────────────
SOURCE_REMOTE="${SOURCE_REMOTE:-idrive-primary}"
DEST_ROOT="${DEST_ROOT:-SJL-MIGRATION-STAGING}"
EXPORT_DIR="${EXPORT_DIR:-/srv/sjl/200000_PROJECTS/210000_cloud-migration/211000_source-manifests}"
LOG_DIR="${LOG_DIR:-/srv/sjl/200000_PROJECTS/210000_cloud-migration/213000_logs}"
CA_CERT="${CA_CERT:-}"   # e.g. /root/.ccr/ca-bundle.crt
DRY_RUN=false
RUN_DATE="$(date -u +%Y-%m-%d)"
RUN_TS="$(date -u +%Y%m%dT%H%M%SZ)"
RUN_ID="hierarchy-clone-${RUN_TS}"

# Destinations — set to empty string to skip
DEST_DROPBOX_SJL="${DEST_DROPBOX_SJL:-dropbox-sjl}"
DEST_DROPBOX_FCPX="${DEST_DROPBOX_FCPX:-dropbox-fcpx}"
DEST_PCLOUD="${DEST_PCLOUD:-pcloud-sjl}"

# ── Argument parsing ──────────────────────────────────────────────────────────
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --skip-dropbox-fcpx) DEST_DROPBOX_FCPX="" ;;
    --skip-dropbox-sjl)  DEST_DROPBOX_SJL="" ;;
    --skip-pcloud)       DEST_PCLOUD="" ;;
    *) echo "Unknown arg: $arg" >&2; exit 1 ;;
  esac
done

# ── Helpers ───────────────────────────────────────────────────────────────────
log() { printf '[%s] %s\n' "$(date -u +%H:%M:%SZ)" "$*"; }
rclone_cmd() {
  local args=()
  [[ -n "$CA_CERT" ]] && args+=(--ca-cert "$CA_CERT")
  env -u AWS_CA_BUNDLE rclone "${args[@]}" "$@"
}

# ── Setup ─────────────────────────────────────────────────────────────────────
mkdir -p "$EXPORT_DIR" "$LOG_DIR"
MANIFEST="$EXPORT_DIR/${RUN_DATE}__SJL-S3-HIERARCHY__${RUN_ID}.txt"
LOG_FILE="$LOG_DIR/${RUN_DATE}__${RUN_ID}.log"
exec > >(tee -a "$LOG_FILE") 2>&1

log "RUN_ID:        $RUN_ID"
log "DRY_RUN:       $DRY_RUN"
log "SOURCE:        ${SOURCE_REMOTE}:"
log "DEST_ROOT:     $DEST_ROOT"
log "MANIFEST:      $MANIFEST"
log "CA_CERT:       ${CA_CERT:-(none)}"

# ── Step 1: Enumerate all S3 buckets ─────────────────────────────────────────
log "Enumerating S3 buckets..."
mapfile -t BUCKETS < <(rclone_cmd lsd "${SOURCE_REMOTE}:" 2>/dev/null | awk '{print $NF}')
log "Buckets found: ${#BUCKETS[@]}"
printf '  %s\n' "${BUCKETS[@]}"

# ── Step 2: Build full directory manifest ────────────────────────────────────
log "Building directory manifest..."
TOTAL_DIRS=0
> "$MANIFEST"

for bucket in "${BUCKETS[@]}"; do
  # Top-level bucket itself
  echo "$bucket" >> "$MANIFEST"
  (( TOTAL_DIRS++ )) || true

  # All subdirectories within the bucket
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    # lsd output: "  size  date  time  count  path"
    dirpath="$(echo "$line" | awk '{print $NF}')"
    [[ -z "$dirpath" ]] && continue
    echo "${bucket}/${dirpath}" >> "$MANIFEST"
    (( TOTAL_DIRS++ )) || true
  done < <(rclone_cmd lsd "${SOURCE_REMOTE}:${bucket}" --recursive 2>/dev/null || true)
done

# Sort and deduplicate
sort -u -o "$MANIFEST" "$MANIFEST"
TOTAL_DIRS="$(wc -l < "$MANIFEST")"
log "Total unique directories in manifest: $TOTAL_DIRS"

# ── Step 3: Replicate hierarchy to each destination ──────────────────────────
replicate_to() {
  local remote_name="$1"
  local remote="${remote_name}:"
  local created=0 skipped=0 failed=0

  log "--- Replicating to ${remote_name} (root: ${DEST_ROOT}) ---"

  # Verify destination is reachable
  if ! rclone_cmd lsd "${remote}" --max-depth 1 &>/dev/null; then
    log "ERROR: Cannot reach ${remote_name} — skipping"
    return 1
  fi

  # Create staging root
  if [[ "$DRY_RUN" == true ]]; then
    log "DRY-RUN: would mkdir ${remote}${DEST_ROOT}"
  else
    rclone_cmd mkdir "${remote}${DEST_ROOT}" 2>/dev/null || true
  fi

  while IFS= read -r dirpath; do
    [[ -z "$dirpath" ]] && continue
    target="${remote}${DEST_ROOT}/${dirpath}"

    if [[ "$DRY_RUN" == true ]]; then
      echo "  DRY-RUN mkdir: $target"
      (( created++ )) || true
    else
      if rclone_cmd mkdir "$target" 2>/dev/null; then
        (( created++ )) || true
      else
        log "WARN: failed to create $target"
        (( failed++ )) || true
      fi
    fi
  done < "$MANIFEST"

  log "  created=${created}  skipped=${skipped}  failed=${failed}"

  # Copy manifest to destination _SYSTEM folder
  if [[ "$DRY_RUN" != true ]]; then
    rclone_cmd copyto "$MANIFEST" \
      "${remote}${DEST_ROOT}/_SYSTEM/${RUN_DATE}-source-hierarchy.txt" 2>/dev/null || \
      log "WARN: could not copy manifest to ${remote_name}"
  fi
}

[[ -n "$DEST_DROPBOX_SJL"  ]] && replicate_to "$DEST_DROPBOX_SJL"
[[ -n "$DEST_DROPBOX_FCPX" ]] && replicate_to "$DEST_DROPBOX_FCPX"
[[ -n "$DEST_PCLOUD"       ]] && replicate_to "$DEST_PCLOUD"

# ── Step 4: Summary ──────────────────────────────────────────────────────────
log "=== COMPLETE ==="
log "Manifest: $MANIFEST"
log "Log:      $LOG_FILE"
[[ "$DRY_RUN" == true ]] && log "DRY-RUN: no writes were performed"
