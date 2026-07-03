# SJL Credential Stow — Centralized Credential Management

**Last updated:** 2026-07-03  
**Canonical reference:** This document is the single source of truth for credential centralization.

---

## Purpose

All SJL infrastructure credentials live on one authoritative server (`memory.shannonjlove.cloud`). Every other server accesses them via:
1. **sshfs** — mounts the memory server's stow tree locally over Tailscale SSH
2. **GNU Stow** — creates symlinks from expected credential paths to the mounted tree

This means there is exactly one copy of each credential file. Rotating a credential requires changing it once, on the memory server. All clients pick up the change immediately (the mount is live).

---

## Architecture

```
memory.shannonjlove.cloud
/etc/sjl-credentials/stow/
├── oci/                             ← Stow package: Oracle Cloud
│   └── opt/secrets/oci/
│       ├── config
│       └── oci_api_key.pem
├── gcp/                             ← Stow package: Google Cloud
│   └── opt/secrets/sjl-unified-mcp/
│       └── google-service-account.json
├── sjl-unified-mcp-env/             ← Stow package: MCP gateway env
│   └── etc/sjl-unified-mcp/
│       └── runtime.env
└── sjl-write-token/                 ← Stow package: write gate token
    └── root/
        └── .sjl-unified-mcp-write-token
```

On each client server (after `sjl-stow-client-setup.sh`):

| Symlink path (client) | Points to (via sshfs) |
|---|---|
| `/opt/secrets/oci` | `/mnt/sjl-creds/oci/opt/secrets/oci` |
| `/opt/secrets/sjl-unified-mcp/google-service-account.json` | `/mnt/sjl-creds/gcp/opt/secrets/sjl-unified-mcp/google-service-account.json` |
| `/etc/sjl-unified-mcp/runtime.env` | `/mnt/sjl-creds/sjl-unified-mcp-env/etc/sjl-unified-mcp/runtime.env` |
| `/root/.sjl-unified-mcp-write-token` | `/mnt/sjl-creds/sjl-write-token/root/.sjl-unified-mcp-write-token` |

---

## Prerequisites

- Tailscale active on all servers (`tailscaled.service` running)
- `memory.shannonjlove.cloud` reachable from all client servers over Tailscale
- SSH key for `root@memory.shannonjlove.cloud` present on each client at the path configured in `SSH_KEY`
- `stow` and `sshfs`/`fuse3` installable via apt/yum

---

## Initial Setup — Memory Server

**Run once on `memory.shannonjlove.cloud` as root:**

```bash
bash 04-SECURITY/credential-management/sjl-stow-memory-server-setup.sh
```

Then populate each package with the actual credential files (copy from current location on VPS):

```bash
# From memory.shannonjlove.cloud, or use scp from the VPS
STOW=/etc/sjl-credentials/stow

scp root@72.61.74.250:/opt/secrets/oci/config                              ${STOW}/oci/opt/secrets/oci/config
scp root@72.61.74.250:/opt/secrets/oci/oci_api_key.pem                     ${STOW}/oci/opt/secrets/oci/oci_api_key.pem
scp root@72.61.74.250:/opt/secrets/sjl-unified-mcp/google-service-account.json \
                                                                             ${STOW}/gcp/opt/secrets/sjl-unified-mcp/google-service-account.json
scp root@72.61.74.250:/etc/sjl-unified-mcp/runtime.env                     ${STOW}/sjl-unified-mcp-env/etc/sjl-unified-mcp/runtime.env
scp root@72.61.74.250:/root/.sjl-unified-mcp-write-token                   ${STOW}/sjl-write-token/root/.sjl-unified-mcp-write-token

# Lock down permissions
chmod 0600 ${STOW}/oci/opt/secrets/oci/config
chmod 0600 ${STOW}/oci/opt/secrets/oci/oci_api_key.pem
chmod 0600 ${STOW}/gcp/opt/secrets/sjl-unified-mcp/google-service-account.json
chmod 0600 ${STOW}/sjl-unified-mcp-env/etc/sjl-unified-mcp/runtime.env
chmod 0600 ${STOW}/sjl-write-token/root/.sjl-unified-mcp-write-token
```

---

## Initial Setup — Each Client Server

**Run on the Hostinger VPS (and any other client) as root:**

```bash
MEMORY_HOST=memory.shannonjlove.cloud \
SSH_KEY=/root/.ssh/id_ed25519 \
bash 04-SECURITY/credential-management/sjl-stow-client-setup.sh
```

The script:
1. Tests SSH connectivity to memory server
2. Installs `stow` and `sshfs`
3. Creates systemd mount unit at `/mnt/sjl-creds`
4. Backs up all existing credential files to `/root/sjl-creds-pre-stow-TIMESTAMP`
5. Removes real credential files (they exist on memory server)
6. Runs `stow` to create symlinks
7. Restarts services
8. Validates all symlinks resolve correctly

---

## Adding a New Service Dependency (Systemd)

After migration, `sjl-unified-mcp.service` must wait for the sshfs mount. Add to its `[Unit]` section:

```ini
[Unit]
After=mnt-sjl\x2dcreds.mount
Requires=mnt-sjl\x2dcreds.mount
```

Get the exact unit name:
```bash
systemd-escape --path /mnt/sjl-creds
# Output: mnt-sjl\x2dcreds
# Unit name: mnt-sjl\x2dcreds.mount
```

Apply:
```bash
systemctl edit sjl-unified-mcp.service --force
# Add the After= and Requires= lines above
systemctl daemon-reload
systemctl restart sjl-unified-mcp.service
```

---

## Adding a New Credential

1. On memory server, create the stow package structure:
```bash
mkdir -p /etc/sjl-credentials/stow/NEW-PACKAGE/path/to/
cp /path/to/credential /etc/sjl-credentials/stow/NEW-PACKAGE/path/to/credential
chmod 0600 /etc/sjl-credentials/stow/NEW-PACKAGE/path/to/credential
```

2. On each client server, run stow for the new package:
```bash
stow --dir=/mnt/sjl-creds --target=/ NEW-PACKAGE
```

3. Verify:
```bash
ls -la /path/to/credential   # Should show symlink → /mnt/sjl-creds/NEW-PACKAGE/...
```

---

## Credential Rotation

1. On memory server — replace the file in the stow tree:
```bash
# Example: rotate OCI API key
install -m 0600 /path/to/new-oci_api_key.pem \
  /etc/sjl-credentials/stow/oci/opt/secrets/oci/oci_api_key.pem
```

2. The sshfs mount is live — the symlinks on all clients immediately reflect the new file.
3. Restart any services that cache credential content at startup:
```bash
systemctl restart sjl-unified-mcp.service
```

---

## Disaster Recovery

**Mount is down (memory server unreachable):**

```bash
# Check mount state
mountpoint -q /mnt/sjl-creds && echo UP || echo DOWN
systemctl status mnt-sjl\\x2dcreds.mount

# Force remount
systemctl restart mnt-sjl\\x2dcreds.mount

# If memory server is permanently gone: restore from backup
ls /root/sjl-creds-pre-stow-*
cp -a /root/sjl-creds-pre-stow-TIMESTAMP/. /
stow --dir=/mnt/sjl-creds --target=/ --delete oci gcp sjl-unified-mcp-env sjl-write-token
```

**Broken symlinks:**

```bash
# Re-run stow (safe — no-op if symlinks already correct)
stow --dir=/mnt/sjl-creds --target=/ oci gcp sjl-unified-mcp-env sjl-write-token

# Or force restow (removes and recreates symlinks)
stow --dir=/mnt/sjl-creds --target=/ --restow oci gcp sjl-unified-mcp-env sjl-write-token
```

**Remove stow symlinks entirely (revert to real files):**

```bash
# 1. Restore real files from backup
cp -a /root/sjl-creds-pre-stow-TIMESTAMP/. /

# 2. Delete stow symlinks (stow won't delete if real files are in the way)
stow --dir=/mnt/sjl-creds --target=/ --delete oci gcp sjl-unified-mcp-env sjl-write-token
```

---

## Health Check

```bash
# Mount
mountpoint -q /mnt/sjl-creds && echo "mount: OK" || echo "mount: DOWN"

# Symlinks
for f in \
  /opt/secrets/oci/config \
  /opt/secrets/oci/oci_api_key.pem \
  /opt/secrets/sjl-unified-mcp/google-service-account.json \
  /etc/sjl-unified-mcp/runtime.env \
  /root/.sjl-unified-mcp-write-token; do
  if [[ -L "$f" && -e "$f" ]]; then
    echo "OK  $f"
  else
    echo "FAIL $f"
  fi
done
```

---

## Security Notes

- The sshfs mount is **read-only** (`ro` option) — client servers cannot modify credentials
- Files appear mode `644` on clients via `umask=0133` — readable by service users
- The `/mnt/sjl-creds` directory is mode `0700` — only root can browse the mount
- Credential symlinks are readable by service users (sjlmcp, etc.) because `allow_other` is set
- The memory server's stow tree is `chmod 0700` — root-only access
- `NEVER` commit actual credential files to git — only the stow setup scripts

---

## Files

| File | Purpose |
|---|---|
| `04-SECURITY/credential-management/sjl-stow-memory-server-setup.sh` | Creates stow directory tree on memory server |
| `04-SECURITY/credential-management/sjl-stow-client-setup.sh` | Sets up sshfs + stow symlinks on client servers |
| `06-OPS/diagrams/sjl-credential-stow.mmd` | Architecture diagram |
