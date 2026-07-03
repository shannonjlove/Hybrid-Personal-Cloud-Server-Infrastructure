#!/usr/bin/env bash
# SJL Credential Stow — Local VPS Setup
# Run as root on the Hostinger VPS (72.61.74.250)
#
# PURPOSE:
#   Creates a single authoritative GNU Stow source tree at /etc/sjl-credentials/stow/
#   and symlinks every credential to its expected path.
#   Everything stays LOCAL on the VPS — no sshfs, no remote mounts.
#
# The memory.shannonjlove.cloud service (memory-app container) is NOT a credential
# store. It is the operational knowledge layer. Credentials stay here, in
# root-protected files on the VPS filesystem.
#
# USAGE: bash sjl-stow-vps-setup.sh

set -Eeuo pipefail
IFS=$'\n\t'

STOW_ROOT="/etc/sjl-credentials/stow"

# Credential packages and the files within each
declare -A PKG_FILES=(
  ["oci"]="opt/secrets/oci/config opt/secrets/oci/oci_api_key.pem"
  ["gcp"]="opt/secrets/sjl-unified-mcp/google-service-account.json"
  ["sjl-unified-mcp-env"]="etc/sjl-unified-mcp/runtime.env"
  ["sjl-write-token"]="root/.sjl-unified-mcp-write-token"
)

log()  { printf '\n== %s ==\n' "$*"; }
die()  { echo "ERROR: $*" >&2; exit 1; }
info() { echo "  $*"; }

[[ ${EUID:-$(id -u)} -eq 0 ]] || die "Run as root."

# ── Phase 1: Install stow ──────────────────────────────────────────────────

log "Phase 1 — Install GNU Stow"
apt-get install -y --no-install-recommends stow 2>/dev/null \
  || die "Could not install stow. Install manually then rerun."

# ── Phase 2: Create stow tree ─────────────────────────────────────────────

log "Phase 2 — Create stow source tree at ${STOW_ROOT}"

mkdir -p "${STOW_ROOT}/oci/opt/secrets/oci"
mkdir -p "${STOW_ROOT}/gcp/opt/secrets/sjl-unified-mcp"
mkdir -p "${STOW_ROOT}/sjl-unified-mcp-env/etc/sjl-unified-mcp"
mkdir -p "${STOW_ROOT}/sjl-write-token/root"

chmod 0700 /etc/sjl-credentials "${STOW_ROOT}"
find "${STOW_ROOT}" -type d -exec chmod 0700 {} \;

# ── Phase 3: Adopt existing credential files into the stow tree ────────────

log "Phase 3 — Adopting existing credential files"

# stow --adopt moves real files INTO the stow tree and replaces them with symlinks.
# This is the correct migration for existing files already at their expected paths.

STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="/root/sjl-creds-pre-stow-${STAMP}"
mkdir -p "${BACKUP}"

# Backup first
for f in \
  /opt/secrets/oci/config \
  /opt/secrets/oci/oci_api_key.pem \
  /opt/secrets/sjl-unified-mcp/google-service-account.json \
  /etc/sjl-unified-mcp/runtime.env \
  /root/.sjl-unified-mcp-write-token; do
  if [[ -f "${f}" && ! -L "${f}" ]]; then
    mkdir -p "${BACKUP}/$(dirname "${f}")"
    cp -a "${f}" "${BACKUP}/${f}"
    info "Backed up: ${f}"
  fi
done
info "Backup at: ${BACKUP}"

# Stop services to release file handles (NEVER touch 8777)
for svc in sjl-unified-mcp.service sjl-cloud-access-mcp.service; do
  if systemctl is-active --quiet "${svc}" 2>/dev/null; then
    systemctl stop "${svc}"
    info "Stopped: ${svc}"
  fi
done

# Adopt: moves existing files into the stow tree, creates symlinks
stow --dir="${STOW_ROOT}" --target=/ --adopt --verbose \
  oci gcp sjl-unified-mcp-env sjl-write-token

# After adoption, files live in the stow tree. Set correct permissions.
[[ -f "${STOW_ROOT}/oci/opt/secrets/oci/config" ]]        && chmod 0600 "${STOW_ROOT}/oci/opt/secrets/oci/config"
[[ -f "${STOW_ROOT}/oci/opt/secrets/oci/oci_api_key.pem" ]] && chmod 0600 "${STOW_ROOT}/oci/opt/secrets/oci/oci_api_key.pem"
[[ -f "${STOW_ROOT}/gcp/opt/secrets/sjl-unified-mcp/google-service-account.json" ]] && \
  chmod 0600 "${STOW_ROOT}/gcp/opt/secrets/sjl-unified-mcp/google-service-account.json"
[[ -f "${STOW_ROOT}/sjl-unified-mcp-env/etc/sjl-unified-mcp/runtime.env" ]] && \
  chmod 0600 "${STOW_ROOT}/sjl-unified-mcp-env/etc/sjl-unified-mcp/runtime.env"
[[ -f "${STOW_ROOT}/sjl-write-token/root/.sjl-unified-mcp-write-token" ]] && \
  chmod 0600 "${STOW_ROOT}/sjl-write-token/root/.sjl-unified-mcp-write-token"

# ── Phase 4: Restart services ─────────────────────────────────────────────

log "Phase 4 — Restart services"
for svc in sjl-unified-mcp.service sjl-cloud-access-mcp.service; do
  if systemctl is-enabled --quiet "${svc}" 2>/dev/null; then
    systemctl start "${svc}"
    sleep 1
    systemctl is-active --quiet "${svc}" \
      && info "${svc}: active" \
      || info "WARNING: ${svc} not running — check: journalctl -u ${svc} -n 30"
  fi
done

# ── Phase 5: Validate ─────────────────────────────────────────────────────

log "Phase 5 — Validation"

ALL_OK=true
for f in \
  /opt/secrets/oci/config \
  /opt/secrets/oci/oci_api_key.pem \
  /opt/secrets/sjl-unified-mcp/google-service-account.json \
  /etc/sjl-unified-mcp/runtime.env \
  /root/.sjl-unified-mcp-write-token; do
  if [[ -L "${f}" && -e "${f}" ]]; then
    target="$(readlink "${f}")"
    info "OK  ${f} → ${target}"
  else
    info "FAIL ${f} (not a valid symlink)"
    ALL_OK=false
  fi
done

echo ""
if [[ "${ALL_OK}" == "true" ]]; then
  echo "All credential symlinks verified. Stow migration complete."
  echo "Authoritative source: ${STOW_ROOT}"
  echo ""
  echo "To add a new credential: place it in the stow tree, then run:"
  echo "  stow --dir=${STOW_ROOT} --target=/ PACKAGE-NAME"
  echo ""
  echo "To rotate a credential: replace the file in ${STOW_ROOT}, restart affected services."
else
  echo "WARNING: Some symlinks missing or broken."
  echo "Restore from backup: cp -a ${BACKUP}/. /"
  exit 1
fi
