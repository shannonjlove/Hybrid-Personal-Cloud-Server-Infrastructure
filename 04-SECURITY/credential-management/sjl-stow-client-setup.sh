#!/usr/bin/env bash
# SJL Credential Store — Client Server Setup
# Run as root on any client server (Hostinger VPS, Oracle instance, etc.)
# Mounts memory.shannonjlove.cloud via sshfs over Tailscale,
# then uses GNU Stow to create symlinks at expected credential paths.
#
# PREREQUISITES:
#   1. Tailscale is active and memory.shannonjlove.cloud is reachable
#   2. The memory server's stow tree has been populated
#      (run sjl-stow-memory-server-setup.sh first)
#   3. SSH key for root@memory.shannonjlove.cloud is in SSH_KEY
#
# USAGE:
#   MEMORY_HOST=memory.shannonjlove.cloud \
#   SSH_KEY=/root/.ssh/id_ed25519 \
#   bash sjl-stow-client-setup.sh

set -Eeuo pipefail
IFS=$'\n\t'

MEMORY_HOST="${MEMORY_HOST:-memory.shannonjlove.cloud}"
MEMORY_PATH="/etc/sjl-credentials/stow"
MOUNT_POINT="/mnt/sjl-creds"
SSH_KEY="${SSH_KEY:-/root/.ssh/id_ed25519}"
SSH_USER="${SSH_USER:-root}"

# Packages to stow — one per credential domain
STOW_PACKAGES=(oci gcp sjl-unified-mcp-env sjl-write-token)

# Credential paths that will become symlinks (for pre-flight check and backup)
CRED_FILES=(
  /opt/secrets/oci/config
  /opt/secrets/oci/oci_api_key.pem
  /opt/secrets/sjl-unified-mcp/google-service-account.json
  /etc/sjl-unified-mcp/runtime.env
  /root/.sjl-unified-mcp-write-token
)

log()  { printf '\n== %s ==\n' "$*"; }
die()  { echo "ERROR: $*" >&2; exit 1; }
info() { echo "  $*"; }

[[ ${EUID:-$(id -u)} -eq 0 ]] || die "Run as root."

# ── Phase 1: Preflight ─────────────────────────────────────────────────────

log "Phase 1 — Preflight checks"

command -v ssh      >/dev/null 2>&1 || die "ssh not found"
[[ -f "${SSH_KEY}" ]]               || die "SSH key not found: ${SSH_KEY}"

info "Testing SSH to ${MEMORY_HOST}..."
ssh -o StrictHostKeyChecking=accept-new \
    -o ConnectTimeout=10 \
    -o BatchMode=yes \
    -i "${SSH_KEY}" \
    "${SSH_USER}@${MEMORY_HOST}" \
    "test -d '${MEMORY_PATH}'" \
  || die "Cannot reach ${MEMORY_HOST} or stow tree missing at ${MEMORY_PATH}. Run the memory server setup script first."

info "Memory server reachable and stow tree confirmed."

# Verify each stow package exists on memory server
for pkg in "${STOW_PACKAGES[@]}"; do
  ssh -o BatchMode=yes -i "${SSH_KEY}" "${SSH_USER}@${MEMORY_HOST}" \
    "test -d '${MEMORY_PATH}/${pkg}'" \
    || die "Stow package '${pkg}' not found on memory server. Populate the stow tree first."
  info "Package confirmed: ${pkg}"
done

# ── Phase 2: Install dependencies ─────────────────────────────────────────

log "Phase 2 — Installing stow and sshfs"
apt-get install -y --no-install-recommends stow sshfs fuse3 2>/dev/null \
  || yum install -y stow fuse-sshfs 2>/dev/null \
  || die "Could not install stow/sshfs. Install them manually then rerun."

# ── Phase 3: Create systemd mount unit ────────────────────────────────────

log "Phase 3 — Systemd sshfs mount"

mkdir -p "${MOUNT_POINT}"
chmod 0700 "${MOUNT_POINT}"

# Derive unit name from mount path (systemd path escaping)
UNIT_NAME="$(systemd-escape --path "${MOUNT_POINT}").mount"
UNIT_FILE="/etc/systemd/system/${UNIT_NAME}"

info "Mount unit: ${UNIT_FILE}"

cat > "${UNIT_FILE}" <<EOF
[Unit]
Description=SJL Credential Store — ${MEMORY_HOST}
After=network-online.target tailscaled.service
Wants=network-online.target

[Mount]
What=${SSH_USER}@${MEMORY_HOST}:${MEMORY_PATH}
Where=${MOUNT_POINT}
Type=fuse.sshfs
Options=IdentityFile=${SSH_KEY},allow_other,ro,reconnect,ServerAliveInterval=15,ServerAliveCountMax=3,StrictHostKeyChecking=no,uid=0,gid=0,umask=0133,_netdev
TimeoutSec=30

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable "${UNIT_NAME}"
systemctl start  "${UNIT_NAME}"

sleep 2
mountpoint -q "${MOUNT_POINT}" \
  || die "sshfs mount failed. Check: systemctl status '${UNIT_NAME}' and journalctl -u '${UNIT_NAME}'"
info "Mount active at ${MOUNT_POINT}"

# ── Phase 4: Backup existing credential files ──────────────────────────────

log "Phase 4 — Backing up existing credential files"

STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="/root/sjl-creds-pre-stow-${STAMP}"
mkdir -p "${BACKUP}"

for f in "${CRED_FILES[@]}"; do
  if [[ -e "${f}" ]]; then
    mkdir -p "${BACKUP}/$(dirname "${f}")"
    cp -a "${f}" "${BACKUP}/${f}"
    info "Backed up: ${f}"
  fi
done
info "Backup location: ${BACKUP}"

# ── Phase 5: Remove real files, run stow ──────────────────────────────────

log "Phase 5 — Removing real files and creating stow symlinks"

# Stop services that hold credential file handles
# Note: NEVER touch sjl-cloud-access-mcp-rw.service (8777 — protected)
for svc in sjl-unified-mcp.service sjl-cloud-access-mcp.service; do
  if systemctl is-active --quiet "${svc}" 2>/dev/null; then
    info "Stopping ${svc} for migration..."
    systemctl stop "${svc}"
  fi
done

# Remove the real files so stow can create symlinks in their place
# Stow creates symlinks only where files/directories don't already exist
for f in "${CRED_FILES[@]}"; do
  if [[ -f "${f}" && ! -L "${f}" ]]; then
    rm "${f}"
    info "Removed real file: ${f}"
  fi
done

# Also remove the oci directory so stow can symlink at directory level
if [[ -d /opt/secrets/oci && ! -L /opt/secrets/oci ]]; then
  rmdir /opt/secrets/oci 2>/dev/null \
    && info "Removed empty dir: /opt/secrets/oci" \
    || info "Warning: /opt/secrets/oci not empty — stow will link files individually"
fi

# Run stow
stow --dir="${MOUNT_POINT}" --target=/ --verbose "${STOW_PACKAGES[@]}"

# ── Phase 6: Restart services ─────────────────────────────────────────────

log "Phase 6 — Restarting services"

for svc in sjl-unified-mcp.service sjl-cloud-access-mcp.service; do
  if systemctl is-enabled --quiet "${svc}" 2>/dev/null; then
    systemctl start "${svc}"
    sleep 1
    if systemctl is-active --quiet "${svc}"; then
      info "${svc}: active"
    else
      info "WARNING: ${svc} not running — check: journalctl -u ${svc} -n 30"
    fi
  fi
done

# ── Phase 7: Validation ────────────────────────────────────────────────────

log "Phase 7 — Validation"

ALL_OK=true
for f in "${CRED_FILES[@]}"; do
  if [[ -L "${f}" ]] && [[ -e "${f}" ]]; then
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
else
  echo "WARNING: Some symlinks missing or broken. Review output above."
  echo "Restore from backup: cp -a ${BACKUP}/. /"
  exit 1
fi

echo ""
echo "Add mount dependency to sjl-unified-mcp.service:"
echo "  Edit /etc/systemd/system/sjl-unified-mcp.service — add under [Unit]:"
echo "    After=${UNIT_NAME}"
echo "    Requires=${UNIT_NAME}"
echo "  Then: systemctl daemon-reload && systemctl restart sjl-unified-mcp.service"
