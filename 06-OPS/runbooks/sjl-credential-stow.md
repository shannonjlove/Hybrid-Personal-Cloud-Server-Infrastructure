# SJL Credential Stow — Local Credential Management

**Last updated:** 2026-07-03  
**Canonical reference:** This document is the single source of truth for VPS credential organization.

---

## Architecture

All SJL credentials live on the **Hostinger VPS** (`72.61.74.250`) in a single root-protected GNU Stow source tree:

```
/etc/sjl-credentials/stow/          ← Authoritative source tree (chmod 0700 root)
├── oci/                             ← Package: Oracle Cloud
│   └── opt/secrets/oci/
│       ├── config
│       └── oci_api_key.pem
├── gcp/                             ← Package: Google Cloud
│   └── opt/secrets/sjl-unified-mcp/
│       └── google-service-account.json
├── sjl-unified-mcp-env/             ← Package: MCP gateway runtime env
│   └── etc/sjl-unified-mcp/
│       └── runtime.env
└── sjl-write-token/                 ← Package: Write gate token
    └── root/
        └── .sjl-unified-mcp-write-token
```

GNU Stow creates symlinks from the expected service paths to the source tree:

| Symlink path | Points to |
|---|---|
| `/opt/secrets/oci/` | `/etc/sjl-credentials/stow/oci/opt/secrets/oci/` |
| `/opt/secrets/sjl-unified-mcp/google-service-account.json` | `/etc/sjl-credentials/stow/gcp/opt/secrets/sjl-unified-mcp/...` |
| `/etc/sjl-unified-mcp/runtime.env` | `/etc/sjl-credentials/stow/sjl-unified-mcp-env/etc/sjl-unified-mcp/runtime.env` |
| `/root/.sjl-unified-mcp-write-token` | `/etc/sjl-credentials/stow/sjl-write-token/root/...` |

**Key constraints (from architecture handoff):**
- `memory.shannonjlove.cloud` is NOT a credential store — it is the operational memory container
- No `sshfs` cross-system credential mounting
- The memory platform stores references to secrets (path, owner, rotation policy), never secret values
- Actual credentials remain in root-protected files on the VPS filesystem

---

## Initial Setup

**Run once on the Hostinger VPS as root:**

```bash
bash 04-SECURITY/credential-management/sjl-stow-vps-setup.sh
```

The script:
1. Installs GNU Stow
2. Creates `/etc/sjl-credentials/stow/` package structure
3. Backs up existing credential files to `/root/sjl-creds-pre-stow-TIMESTAMP`
4. Uses `stow --adopt` to move real files into the stow tree and replace them with symlinks
5. Restarts services
6. Validates all symlinks

---

## Adding a New Credential

```bash
# 1. Create package directory in stow tree
mkdir -p /etc/sjl-credentials/stow/NEW-PACKAGE/path/to/

# 2. Place the credential file
install -m 0600 /path/to/credential \
  /etc/sjl-credentials/stow/NEW-PACKAGE/path/to/credential

# 3. Create the symlink
stow --dir=/etc/sjl-credentials/stow --target=/ NEW-PACKAGE

# 4. Verify
ls -la /path/to/credential   # Should show: credential → /etc/sjl-credentials/stow/...
```

---

## Rotating a Credential

Since all service paths are symlinks into the stow tree, rotation requires only:

```bash
# Replace the file in the stow tree
install -m 0600 /path/to/new-credential \
  /etc/sjl-credentials/stow/PACKAGE/path/to/credential

# Restart services that cache credentials at startup
systemctl restart sjl-unified-mcp.service
```

No path changes needed anywhere — the symlinks already point to the updated file.

---

## Health Check

```bash
# Verify all symlinks are intact
for f in \
  /opt/secrets/oci/config \
  /opt/secrets/oci/oci_api_key.pem \
  /opt/secrets/sjl-unified-mcp/google-service-account.json \
  /etc/sjl-unified-mcp/runtime.env \
  /root/.sjl-unified-mcp-write-token; do
  [[ -L "$f" && -e "$f" ]] && echo "OK  $f" || echo "FAIL $f"
done
```

---

## Recovery

```bash
# Re-run stow (idempotent — no-op if already correct)
stow --dir=/etc/sjl-credentials/stow --target=/ \
  oci gcp sjl-unified-mcp-env sjl-write-token

# Force restow (remove and recreate all symlinks)
stow --dir=/etc/sjl-credentials/stow --target=/ --restow \
  oci gcp sjl-unified-mcp-env sjl-write-token

# Revert to real files (emergency only)
# 1. Restore from pre-stow backup
cp -a /root/sjl-creds-pre-stow-TIMESTAMP/. /
# 2. Remove stow symlinks
stow --dir=/etc/sjl-credentials/stow --target=/ --delete \
  oci gcp sjl-unified-mcp-env sjl-write-token
```

---

## Files

| File | Purpose |
|---|---|
| `04-SECURITY/credential-management/sjl-stow-vps-setup.sh` | Sets up local stow tree and symlinks on the VPS |
| `06-OPS/diagrams/sjl-credential-stow.mmd` | Architecture diagram |
