#!/usr/bin/env bash
# =============================================================================
# deploy-claude-architecture-v3.sh
# SJL Sovereign Cloud — Claude Code Agent Context Deployment
# Version: 3.0 | 2026-06-30
# Run on: Nexus (Hostinger VPS) as root or sjl service user
# =============================================================================
#
# USAGE:
#   bash deploy-claude-architecture-v3.sh              # write files + symlinks
#   bash deploy-claude-architecture-v3.sh --dry-run    # print paths, no writes
#   bash deploy-claude-architecture-v3.sh --bookstack  # write + export to BookStack
#   bash deploy-claude-architecture-v3.sh --paperless  # write + export to Paperless
#   bash deploy-claude-architecture-v3.sh --all        # write + all exports
#
# CREDENTIALS (never hardcode here):
#   /root/secrets/bookstack.env   — BOOKSTACK_URL, BOOKSTACK_TOKEN_ID, BOOKSTACK_TOKEN_SECRET
#   /root/secrets/paperless.env   — PAPERLESS_URL, PAPERLESS_TOKEN
#
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
CONTEXT_DIR="/srv/sjl/070000_SYSTEM-AUTOMATION/079000_agent-context"
BOOKSTACK_SECRETS="/root/secrets/bookstack.env"
PAPERLESS_SECRETS="/root/secrets/paperless.env"
BOOKSTACK_BOOK_NAME="SJL Sovereign Cloud"

DRY_RUN=false
DO_BOOKSTACK=false
DO_PAPERLESS=false

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
for arg in "$@"; do
  case "$arg" in
    --dry-run)   DRY_RUN=true ;;
    --bookstack) DO_BOOKSTACK=true ;;
    --paperless) DO_PAPERLESS=true ;;
    --all)       DO_BOOKSTACK=true; DO_PAPERLESS=true ;;
    --help|-h)
      cat <<'HELPEOF'
deploy-claude-architecture-v3.sh — SJL Claude Code Context Deployment

Usage:
  bash deploy-claude-architecture-v3.sh [options]

Options:
  (none)         Write 9 CLAUDE.md files and create symlinks
  --dry-run      Print what would be written without touching disk
  --bookstack    Also export to BookStack (requires /root/secrets/bookstack.env)
  --paperless    Also export to Paperless-NGX (requires /root/secrets/paperless.env)
  --all          Write + export to both BookStack and Paperless
  --help         Show this message

Secrets file format:
  /root/secrets/bookstack.env:
    BOOKSTACK_URL="https://docs.shannonjlove.cloud"
    BOOKSTACK_TOKEN_ID="<your_token_id>"
    BOOKSTACK_TOKEN_SECRET="<your_token_secret>"

  /root/secrets/paperless.env:
    PAPERLESS_URL="https://paperless.shannonjlove.cloud"
    PAPERLESS_TOKEN="<your_token>"
HELPEOF
      exit 0 ;;
    *)
      echo "Unknown argument: $arg" >&2
      echo "Run with --help for usage." >&2
      exit 1 ;;
  esac
done

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log()  { echo "[$(date -u +%H:%M:%SZ)] $*"; }
info() { echo "  → $*"; }

write_file() {
  local filepath="$1"
  local content
  content="$(cat)"   # reads from stdin via heredoc at call site

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[DRY-RUN] Would write: ${filepath} ($(echo "$content" | wc -l) lines)"
    return
  fi

  mkdir -p "$(dirname "$filepath")"
  printf '%s\n' "$content" > "$filepath"
  local lines
  lines=$(wc -l < "$filepath")
  info "Wrote: ${filepath} (${lines} lines)"
}

symlink_for_user() {
  local target="$1"
  local link="$2"
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[DRY-RUN] Would symlink: ${link} -> ${target}"
    return
  fi
  mkdir -p "$(dirname "$link")"
  ln -sf "$target" "$link"
  info "Symlinked: ${link} -> ${target}"
}

# ---------------------------------------------------------------------------
# Phase 1 — Write all 9 context files
# ---------------------------------------------------------------------------
log "Phase 1: Writing Claude Code context files to ${CONTEXT_DIR}"

# ---- File 1: CLAUDE.md (root constitution) --------------------------------
write_file "${CONTEXT_DIR}/CLAUDE.md" <<'CLAUDEEOF'
# CLAUDE.md — SJL Sovereign Cloud Agent Constitution
# shannonjlove.cloud | Effective 2026-06-30

## MANDATORY: Read companion files before acting on any task

| Companion File | Read When |
|----------------|-----------|
| CLAUDE.runtime.md | Before running ANY shell command |
| CLAUDE.services.md | Before starting, stopping, or modifying any container |
| CLAUDE.network.md | Before touching Traefik, Tailscale, WireGuard, or DNS |
| CLAUDE.storage.md | Before any rclone, iDrive, or cloud sync operation |
| CLAUDE.automation.md | Before modifying FileWarden, Hazel, MCP, or n8n |
| CLAUDE.troubleshooting.md | When a service is down or behaving unexpectedly |
| CLAUDE.commands.md | For the canonical set of safe read commands |
| CLAUDE.do-not-touch.md | BEFORE every write or destructive operation |

## Infrastructure Topology

| Node | Role | Access | IP |
|------|------|--------|----|
| Nexus (Hostinger VPS) | Public edge, Traefik, containers | Tailscale + public SSH | varies |
| sOs (Oracle ARM64) | Private compute, AI, indexing, automation | `ssh ubuntu@sOs` (Tailscale) | 100.67.229.94 |
| iDrive E2 | Cold S3-compatible object storage | rclone / S3 API | — |

All services: `*.shannonjlove.cloud`

## Hard Constraints

1. **Never run as root unless unavoidable.** The `sjl` service user owns all containers (rootless Podman). See CLAUDE.runtime.md.
2. **No secrets in files or git.** Credentials live in `/root/secrets/*.env` and are sourced at runtime.
3. **Never restart Traefik without verifying TLS cert state** — a botched restart drops all services behind HTTPS.
4. **Feature branches only.** Never push directly to `main`.
5. **PARA code first.** All governed filenames begin with a six-digit PARA code. Naming master: `00-MASTER-ARCHITECTURE/sjl-para-naming-master.md` in the infrastructure repo.
6. **Do not bulk rename cloud files** without an approved migration mapping.

## PARA Naming (Six-Digit Canonical)

Format: `[PPPPPP]_YYYY-MM-DD__DOCID__semantic-title__vMAJOR-MINOR__sha8.ext`

Roots: 010000 INBOX · 020000 PROJECTS · 030000 AREAS · 040000 RESOURCES · 050000 ARCHIVES · 060000 PRIVATE MEDIA · 070000 SYSTEM AUTOMATION · 080000 APPLICATION DATA · 090000 QUARANTINE

## Context Directory

This file and its companions live at:
`/srv/sjl/070000_SYSTEM-AUTOMATION/079000_agent-context/`

Deploy/update with:
`bash /srv/sjl/070000_SYSTEM-AUTOMATION/079000_agent-context/deploy-claude-architecture-v3.sh`
CLAUDEEOF

# ---- File 2: CLAUDE.runtime.md --------------------------------------------
write_file "${CONTEXT_DIR}/CLAUDE.runtime.md" <<'CLAUDEEOF'
# CLAUDE.runtime.md — Execution Environment
# shannonjlove.cloud | Nexus VPS

## Service User: sjl

All container workloads run as the `sjl` system user (rootless Podman).
Do NOT run container operations as root unless a specific service explicitly requires it.

```bash
# Switch to sjl for container operations
sudo -u sjl bash

# Run podman as sjl
sudo -u sjl podman ps -a
sudo -u sjl podman-compose -f /srv/sjl/compose/<service>/compose.yml up -d
```

## Rootless Podman

- Socket: `/run/user/$(id -u sjl)/podman/podman.sock`
- Systemd scope: `user@$(id -u sjl).service`
- Quadlet units: `/home/sjl/.config/containers/systemd/`
- To reload after changing quadlets:
  ```bash
  sudo -u sjl systemctl --user daemon-reload
  sudo -u sjl systemctl --user start <service>.service
  ```

## Directory Layout (Stow-managed under /srv/sjl)

```
/srv/sjl/
├── 010000_INBOX/                # Drop zone for ingest pipeline
├── 020000_PROJECTS/             # Active project working directories
├── 030000_AREAS/                # Ongoing ops (server configs, network)
├── 040000_RESOURCES/            # Templates, scripts, reference
├── 050000_ARCHIVES/             # Completed/retired
├── 060000_PRIVATE-MEDIA/        # Restricted media (encrypted volume)
├── 070000_SYSTEM-AUTOMATION/    # Infrastructure automation
│   ├── 071000_FILEWARDEN/       # FileWarden routing rules
│   ├── 072000_HOOK-SCRIPTS/     # Hook event scripts
│   ├── 079000_agent-context/    # THIS DIRECTORY — Claude Code context
├── 080000_APPLICATION-DATA/     # App state, indices, registries
└── 090000_QUARANTINE/           # Integrity failures / pending review
```

## Container Runtime

- **Engine:** Podman (rootless, sjl user)
- **Compose:** podman-compose or Podman Quadlets
- **Networking:** `sjl_net` (default bridge), Traefik labels for routing
- **Traefik socket:** read-only bind mount `/run/user/<uid>/podman/podman.sock:/var/run/docker.sock:ro`

## Environment Variables

Runtime secrets are sourced from `/root/secrets/*.env` files. The `sjl` user's services source from `/home/sjl/secrets/*.env`. Never export credentials as environment variables in a shell session that might be logged.

## Current OS

Linux (Hostinger VPS, x86_64)
Distro: Ubuntu 22.04 LTS (verify with `lsb_release -a`)
CLAUDEEOF

# ---- File 3: CLAUDE.services.md -------------------------------------------
write_file "${CONTEXT_DIR}/CLAUDE.services.md" <<'CLAUDEEOF'
# CLAUDE.services.md — Container Service Inventory
# shannonjlove.cloud | Nexus VPS

## Service Status Key
- `deployed` — running in production, verified
- `verify/optional` — deployed but requires validation before relying on it
- `planned` — not yet deployed

## Nexus Services

| Service | Container | Domain | Status | Notes |
|---------|-----------|--------|--------|-------|
| Traefik | `traefik` | — | deployed | Reverse proxy, TLS termination; restart with extreme care |
| BookStack | `bookstack` + `bookstack-db` | `docs.shannonjlove.cloud` | deployed | Requires MariaDB; data in `bookstack-data` volume |
| PhotoPrism | `photoprism` | `photos.shannonjlove.cloud` | deployed | Originals read-only from `~/Pictures` |
| Stash | `stash` | `stash.shannonjlove.cloud` | planned | Media organization |
| n8n | `n8n` | see below | planned | Workflow automation |
| Portainer | `portainer` | `portainer.shannonjlove.cloud` | verify/optional | Rootless Podman socket access requires explicit verification |
| MCP Fleet | various | Tailscale-internal | planned | Google Drive, pCloud, iDrive E2, Hostinger, Oracle |

## n8n Access Model (IMPORTANT — do not make admin public)

| Endpoint | Domain | Access |
|----------|--------|--------|
| Admin UI | `n8n.shannonjlove.cloud` | Tailscale only — never expose admin to public internet |
| Webhooks | `hooks.shannonjlove.cloud` | Public via Traefik — webhook-only subdomain |

## Traefik Label Pattern

```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.<name>.rule=Host(`<subdomain>.shannonjlove.cloud`)"
  - "traefik.http.routers.<name>.tls.certresolver=letsencrypt"
  - "traefik.http.routers.<name>.middlewares=tailscale-only@file"  # for private services
  - "traefik.http.services.<name>.loadbalancer.server.port=<port>"
```

## sOs Services

| Service | Role | Status |
|---------|------|--------|
| PhotoPrism indexer | Indexes originals from iDrive E2 mount | planned |
| AI/LLM inference | Local model inference for classification | planned |
| Mirror Registry | Canonical file state registry | planned/custom — fallback is filesystem + SHA256 + BookStack |

## Mirror Registry Note

Mirror Registry is not yet deployed. Do not attempt to call it. Current fallback for file identity verification: SHA256 checksums stored in sidecar `.meta.json` files and the ingest audit log at `~/Logs/ingest/`.

## Volume Inventory (Nexus)

| Volume | Service | Contents |
|--------|---------|----------|
| `traefik-certs` | Traefik | Let's Encrypt certificates |
| `bookstack-data` | BookStack | App config, attachments |
| `bookstack-db-data` | MariaDB | BookStack database |
| `photoprism-data` | PhotoPrism | Thumbnails, index, sidecar data |
CLAUDEEOF

# ---- File 4: CLAUDE.network.md --------------------------------------------
write_file "${CONTEXT_DIR}/CLAUDE.network.md" <<'CLAUDEEOF'
# CLAUDE.network.md — Network Architecture
# shannonjlove.cloud | Nexus VPS

## Tailscale Mesh (Primary)

Tailscale is the default connectivity layer. All private inter-node communication goes over Tailscale.

| Node | Tailscale Name | Tailscale IP | Role |
|------|---------------|-------------|------|
| sOs | `sOs` | 100.67.229.94 | Oracle ARM64 private compute |
| GCP instance | `gclove-server-vm-instance` | varies | Supplemental |
| AWS instance | `ip-172-31-38-121` | varies | Supplemental |
| iPhone | `shajes-iphone` | varies | Mobile device |
| Mac | `shannonjlove` | varies | Admin workstation |

MagicDNS recommended. Prefer `ssh ubuntu@sOs` over raw IP addresses.

## WireGuard (Failover Only)

WireGuard is retained exclusively as a failover/emergency access layer when Tailscale is unavailable. Do not use WireGuard for routine operations.

## Traefik Routing

Traefik runs on Nexus as the public-facing ingress. All HTTPS termination happens here.

- Config: `02-CONTAINERS/traefik/traefik.yml` (static) + `02-CONTAINERS/traefik/dynamic/` (dynamic)
- TLS: Let's Encrypt via `letsencrypt` cert resolver
- Provider: Docker/Podman socket (read-only)
- Network: `sjl_net` — all containers that need Traefik routing must attach to this network

**Middleware: `tailscale-only`** — defined in `02-CONTAINERS/traefik/dynamic/middlewares.yml`. Apply this to any service that must not be reachable from the public internet.

## Domain Architecture

| Subdomain | Service | Exposure |
|-----------|---------|----------|
| `docs.shannonjlove.cloud` | BookStack | Public |
| `photos.shannonjlove.cloud` | PhotoPrism | Public (auth required) |
| `stash.shannonjlove.cloud` | Stash | Tailscale only |
| `n8n.shannonjlove.cloud` | n8n admin | Tailscale only |
| `hooks.shannonjlove.cloud` | n8n webhooks | Public |
| `portainer.shannonjlove.cloud` | Portainer | Tailscale only |
| `admin.shannonjlove.cloud` | Admin panel | Tailscale only |
| `nexus.shannonjlove.cloud` | Nexus status | Tailscale only |

## Container Networking

All services share the `sjl_net` bridge network. Only Traefik binds ports 80/443 to the host. Services communicate via container names over `sjl_net`.

```yaml
networks:
  sjl_net:
    external: true
```

Create the network if absent:
```bash
sudo -u sjl podman network create sjl_net
```

## DNS

DNS is managed externally (Cloudflare or Hostinger DNS). Do not modify DNS records from within the VPS — use the provider dashboard or the DNS MCP server tool.
CLAUDEEOF

# ---- File 5: CLAUDE.storage.md --------------------------------------------
write_file "${CONTEXT_DIR}/CLAUDE.storage.md" <<'CLAUDEEOF'
# CLAUDE.storage.md — Storage Architecture
# shannonjlove.cloud | Nexus VPS

## Storage Tiers

| Tier | Provider | Access Pattern | Encryption |
|------|---------|----------------|-----------|
| Hot (local) | Mac + server volumes | Daily | FileVault / LUKS |
| Hot (sync) | Google Drive | Daily | Provider-side |
| Warm | Nexus + sOs volumes | Weekly | LUKS at rest |
| Cold | iDrive E2 (S3-compatible) | Archival | rclone --crypt |
| Cold mirror | Backblaze B2 | Archival | rclone --crypt |

## iDrive E2 — Primary Cold Store

- Protocol: S3-compatible via rclone
- **Always use `--crypt` flag** — never upload plaintext to E2
- Config: `/home/sjl/.config/rclone/rclone.conf` (credentials NOT in git)
- Bucket structure: PARA-aligned prefixes under `sjl-cloud-vault/`

```
sjl-cloud-vault/
├── 020000_projects/
├── 030000_areas/
│   ├── 030300_photo/raw/YYYY/
│   └── 030400_finance/          # encrypted, never synced to Google Drive
├── 040000_resources/
└── 050000_archives/
```

## rclone Patterns

```bash
# Sync AREAS/photo to iDrive E2 (encrypted)
rclone sync ~/PARA/Areas/photo/ idrivee2crypt:sjl-cloud-vault/030000_areas/030300_photo/ \
  --progress --transfers=4 --checkers=8 --log-level INFO

# Verify a remote copy
rclone check ~/PARA/Areas/photo/ idrivee2crypt:sjl-cloud-vault/030000_areas/030300_photo/

# List remote without decrypting (use the plain remote, not crypt):
rclone ls idrivee2:sjl-cloud-vault/
```

## Finance and Legal — Special Handling

Files classified `030400_finance` or `030600_legal`:
- **NOT synced to Google Drive or pCloud** — local + E2 only
- E2 bucket uses server-side encryption (in addition to rclone --crypt)
- Local copy encrypted via FileVault (Mac) or LUKS (server)
- Never include raw `.env` backup content in any rclone job

## Google Drive

- Role: Hot sync for PROJECTS, AREAS (non-sensitive), RESOURCES
- Ingest inbox: `gdrive://SJL-Cloud/Inbox/`
- MCP integration: Google Drive MCP server (planned)
- Access: via rclone or MCP — never mount as filesystem on server

## pCloud

- Role: RAW photo sync + personal media backup
- Ingest inbox: `pcloud://Inbox/`
- MCP integration: pCloud MCP server (planned)

## Volume Backup Policy

Production volumes (BookStack, PhotoPrism) are backed up to iDrive E2 nightly via a cron job on Nexus. Backup script: `/srv/sjl/070000_SYSTEM-AUTOMATION/073000_diff-scripts/volume-backup.sh`.
CLAUDEEOF

# ---- File 6: CLAUDE.automation.md ----------------------------------------
write_file "${CONTEXT_DIR}/CLAUDE.automation.md" <<'CLAUDEEOF'
# CLAUDE.automation.md — Automation Layer
# shannonjlove.cloud | All Nodes

## FileWarden (070000 / 071000)

FileWarden is the primary file routing and governance engine.

- Config: `/srv/sjl/070000_SYSTEM-AUTOMATION/071000_FILEWARDEN/`
- Role: routes files from drop zones → PARA classification → storage tier
- Status: planned/in development
- Fallback: Hazel rules on Mac (11 PARA-based rules)

**Do not bypass FileWarden routing** by manually moving files between PARA directories on the server. All routing must go through the pipeline to preserve audit log integrity.

## Hazel Rules (Mac — 11 Rules)

Hazel watches `~/Inbox`, `~/Desktop`, `~/Downloads` and enforces naming/routing rules.

| Rule | Trigger | Action |
|------|---------|--------|
| para-inbox-rename | Any file in `~/Inbox` without canonical name | Run rename-ingest.sh |
| para-projects-route | Filename contains `_020000` | Move to ~/PARA/Projects/ |
| para-areas-route | Filename contains `_030000` | Move to ~/PARA/Areas/ |
| para-resources-route | Filename contains `_040000` | Move to ~/PARA/Resources/ |
| para-archive-route | Filename contains `_050000` | Move to ~/PARA/Archives/ |
| media-raw-photo | Extension is .dng/.cr3/.arw/.nef | Apply 030300 tag, route to pCloud |
| downloads-auto-clean | File in ~/Downloads older than 48h | Move to ~/Inbox |
| duplicate-detect | UUID24 already in ingest log | Move to ~/Inbox/_DUPLICATES/ |

## LaunchAgents (Mac)

| Label | Schedule | Script |
|-------|----------|--------|
| `cloud.shannonjlove.ingest.inbox` | Every 5 min | rename-ingest.sh |
| `cloud.shannonjlove.ingest.downloads` | Every 15 min | cleanup-dropzone.sh |
| `cloud.shannonjlove.ingest.route` | Every 30 min | route-file.sh |
| `cloud.shannonjlove.ingest.cloud-pull` | Every 60 min | pull-cloud-inboxes.sh |

## MCP Fleet (Planned)

| MCP Server | Provider | Role |
|-----------|---------|------|
| Google Drive MCP | Google Drive | Pull from gdrive://Inbox/, push routed files |
| pCloud MCP | pCloud | Pull from pcloud://Inbox/, push RAW photos |
| iDrive E2 MCP | iDrive E2 | Cold storage operations |
| Backblaze MCP | Backblaze B2 | Cold mirror |
| Hostinger MCP | Hostinger | VPS management |
| Oracle MCP | Oracle Cloud | sOs instance management |

MCP servers run as containers on sOs (not Nexus) to keep the public edge clean.

## n8n Workflows

n8n handles event-driven automation (webhooks, scheduled syncs, notifications).
- Admin: `n8n.shannonjlove.cloud` — Tailscale only
- Webhooks: `hooks.shannonjlove.cloud` — public
- Workflows are version-controlled as exported JSON in `03-AUTOMATION/n8n-workflows/`

## Ingest Pipeline Scripts

Location: `03-AUTOMATION/file-routing/scripts/`

| Script | Stage | Purpose |
|--------|-------|---------|
| validate-ingest.sh | 1 | Naming check, extension safety, duplicate check |
| rename-ingest.sh | 3 | Apply canonical filename |
| tag-xattr.sh | 4 | Write xattr metadata and Finder tags |
| generate-sidecar.sh | 4 | Write .meta.json sidecar |
| route-file.sh | 5 | Copy to all tier destinations, verify checksum |
| audit-log.sh | 6 | Append to daily ingest log |
| generate-uuid24.sh | — | Helper: 24-char alphanumeric UUID |
| cleanup-dropzone.sh | 7 | Remove originals after verified routing |
CLAUDEEOF

# ---- File 7: CLAUDE.troubleshooting.md ------------------------------------
write_file "${CONTEXT_DIR}/CLAUDE.troubleshooting.md" <<'CLAUDEEOF'
# CLAUDE.troubleshooting.md — Incident Response
# shannonjlove.cloud | Nexus VPS

## STOP — Read CLAUDE.do-not-touch.md before taking any remediation action

## Service Down: General Diagnostic Flow

```bash
# 1. Check container status
sudo -u sjl podman ps -a

# 2. Read recent logs for the failed service
sudo -u sjl podman logs --tail=50 <container-name>

# 3. Check Traefik logs if a service is reachable but not routing
sudo -u sjl podman logs --tail=50 traefik

# 4. Check disk space — low disk is a common silent failure cause
df -h /

# 5. Check memory
free -m
```

## Traefik Issues

| Symptom | Likely Cause | Safe Action |
|---------|-------------|-------------|
| 502 Bad Gateway | Service container down | Restart the backend container, NOT Traefik |
| SSL cert expired | Cert renewal failed | Check `traefik-certs` volume; `podman restart traefik` only after verifying cert state |
| Service not routing | Missing `sjl_net` attachment | `podman network connect sjl_net <container>` |
| Traefik won't start | Bad config syntax | Validate with `traefik validate` before restarting |

**Do NOT restart Traefik unless it is the confirmed cause of the issue.** A Traefik restart during cert renewal can drop HTTPS for all services.

## BookStack Down

```bash
# Check both containers
sudo -u sjl podman logs bookstack
sudo -u sjl podman logs bookstack-db

# MariaDB is usually the root cause
# If db container is crashed, restart it first
sudo -u sjl podman restart bookstack-db
# Wait 10 seconds, then restart the app
sleep 10 && sudo -u sjl podman restart bookstack
```

## PhotoPrism Issues

```bash
# Indexing hung? Check logs
sudo -u sjl podman logs photoprism

# Restart triggers re-index — safe to do
sudo -u sjl podman restart photoprism
```

## Tailscale Connectivity Lost

```bash
# Check Tailscale status on Nexus
tailscale status

# If down, restart daemon
systemctl restart tailscaled

# Verify sOs is reachable
tailscale ping sOs
```

## Rootless Podman: Container Won't Start

```bash
# Common: lingering lock file
sudo -u sjl podman system prune --volumes  # CAUTION: removes stopped containers + dangling volumes

# User systemd scope not running
loginctl enable-linger sjl
systemctl start user@$(id -u sjl).service
```

## Rclone Sync Failures

```bash
# Check last run log
cat /var/log/sjl/rclone-sync.log | tail -100

# Test connectivity to E2
rclone about idrivee2:

# Re-run a specific sync with verbose output
rclone sync --progress --log-level DEBUG <source> <dest>
```

## Ingest Pipeline Failures

```bash
# Check failure log
cat ~/Logs/ingest/ingest-failures.log | tail -50

# Files stuck in ~/Inbox > 24h
find ~/Inbox -maxdepth 1 -type f -mmin +1440

# Re-trigger rename on a specific file
bash /srv/sjl/070000_SYSTEM-AUTOMATION/079000_agent-context/../scripts/rename-ingest.sh <file>
```
CLAUDEEOF

# ---- File 8: CLAUDE.commands.md -------------------------------------------
write_file "${CONTEXT_DIR}/CLAUDE.commands.md" <<'CLAUDEEOF'
# CLAUDE.commands.md — Safe Command Reference
# shannonjlove.cloud | Nexus VPS

## Read-Only Discovery Commands (always safe)

```bash
# Container status
sudo -u sjl podman ps -a
sudo -u sjl podman stats --no-stream

# Container logs (read-only)
sudo -u sjl podman logs --tail=100 <container>

# Inspect a container
sudo -u sjl podman inspect <container>

# Network topology
sudo -u sjl podman network ls
sudo -u sjl podman network inspect sjl_net

# Volume listing
sudo -u sjl podman volume ls

# Disk usage
df -h
du -sh /srv/sjl/*/

# Tailscale
tailscale status
tailscale netcheck

# Service status (systemd user units)
sudo -u sjl systemctl --user list-units --type=service

# Rclone remote listing (read-only)
rclone ls idrivee2:sjl-cloud-vault/ --max-depth=2
rclone about idrivee2:

# Ingest log review
cat ~/Logs/ingest/$(date +%Y-%m-%d)-ingest.log
```

## Container Lifecycle Commands

```bash
# Start a service (safe)
sudo -u sjl podman start <container>

# Restart a service (caution with Traefik — see CLAUDE.troubleshooting.md)
sudo -u sjl podman restart <container>

# Stop a service (caution — stops traffic handling for that service)
sudo -u sjl podman stop <container>

# Rebuild and restart from compose
sudo -u sjl podman-compose -f /srv/sjl/compose/<service>/compose.yml up -d

# Apply quadlet changes
sudo -u sjl systemctl --user daemon-reload
sudo -u sjl systemctl --user restart <service>.service
```

## Rclone Sync Commands

```bash
# Dry-run any sync before executing (always do this first)
rclone sync --dry-run --progress <source> <dest>

# Execute after confirming dry-run output
rclone sync --progress --transfers=4 --checkers=8 <source> <dest>

# Verify after sync
rclone check <source> <dest>
```

## Ingest and Naming

```bash
# Generate a UUID24
cat /dev/urandom | LC_ALL=C tr -dc 'a-z0-9' | head -c 24

# Compute sha8 for a file
sha256sum <file> | cut -c1-8

# Manually trigger ingest rename for a single file
bash /srv/sjl/070000_SYSTEM-AUTOMATION/079000_agent-context/scripts/rename-ingest.sh <file>
```

## Git Operations (Infrastructure Repo)

```bash
# Always on a feature branch
git checkout -b feature/<description>

# Check what changed
git diff
git status

# Commit with session attribution
git commit -m "type: description"
```

## Audit One-Liner (base64 integrity check)

```bash
# Encode a file to base64, pipe through sha256sum, extract first 8 chars
base64 -w0 <file> | sha256sum | cut -c1-8
```
CLAUDEEOF

# ---- File 9: CLAUDE.do-not-touch.md ---------------------------------------
write_file "${CONTEXT_DIR}/CLAUDE.do-not-touch.md" <<'CLAUDEEOF'
# CLAUDE.do-not-touch.md — Protected Resources
# shannonjlove.cloud | ALL NODES
# READ THIS BEFORE EVERY WRITE OR DESTRUCTIVE OPERATION

## ABSOLUTE PROHIBITIONS — No exceptions without Shannon's explicit approval

### Never modify without approval:
1. **Traefik TLS configuration** — breaking this drops HTTPS for every service on the domain
2. **Tailscale auth keys** — loss of access to sOs means no path back without console access
3. **BookStack database volume** (`bookstack-db-data`) — contains all documentation, no easy restore
4. **Production Let's Encrypt certs** (`traefik-certs` volume) — rate-limited, loss = downtime
5. **iDrive E2 encryption keys** (`rclone.conf` `--crypt` passphrase) — loss = permanent data loss
6. **`/home/sjl/secrets/`** and **`/root/secrets/`** — never read, write, print, or log these
7. **sOs `~ubuntu/` home directory** directly — use the defined paths under `/srv/sjl/`
8. **DNS records at Cloudflare / Hostinger** — wrong records break all public-facing services
9. **Mirror Registry state files** — if/when deployed, the registry is the authority for file identity; never edit manually

## Never Commit to Git:
- `.env` files
- API keys, tokens, bearer tokens
- SSH private keys (`~/.ssh/id_*`, `~/.ssh/oracle_rsa*`)
- Tailscale auth keys
- rclone.conf (contains E2 credentials and crypt passphrase)
- Any file under `/root/secrets/` or `/home/sjl/secrets/`
- BookStack token IDs or secrets
- Paperless-NGX auth tokens

## Never Delete:
- `~/Logs/ingest/` — audit record, required for file identity resolution
- Any `.meta.json` sidecar file — these are the fallback identity layer when Mirror Registry is unavailable
- Contents of the `traefik-certs` Docker/Podman volume
- Contents of the `bookstack-data` or `bookstack-db-data` volumes without a verified backup

## Never Run Without a Dry-Run First:
- Any `rclone sync` or `rclone move` command
- Any `podman system prune` command
- Any batch rename or `find -exec mv` across PARA directories
- The deploy script (`deploy-claude-architecture-v3.sh`) with `--all`

## Destructive Operations Requiring Explicit User Approval:
- `git push --force` to any branch
- `git reset --hard`
- `podman volume rm <name>` (any production volume)
- `rclone delete` or `rclone purge`
- `DROP TABLE` or `DELETE FROM` in BookStack or PhotoPrism databases
- Any operation that changes file DOCIDs (permanent artifact identity must be stable)
- Bulk renames of any cloud-synced directory
CLAUDEEOF

# ---------------------------------------------------------------------------
# Phase 2 — Create symlinks for Claude Code discovery
# ---------------------------------------------------------------------------
log "Phase 2: Creating symlinks"

symlink_for_user "${CONTEXT_DIR}/CLAUDE.md" "/root/CLAUDE.md"

if id sjl &>/dev/null; then
  symlink_for_user "${CONTEXT_DIR}/CLAUDE.md" "/home/sjl/CLAUDE.md"
else
  info "User 'sjl' does not exist on this host — /home/sjl/CLAUDE.md symlink skipped"
  info "(Create the sjl user first, then re-run to add the symlink)"
fi

# ---------------------------------------------------------------------------
# Phase 3 — Optional: Export to BookStack
# ---------------------------------------------------------------------------
export_to_bookstack() {
  log "Phase 3a: Exporting to BookStack"

  if [[ ! -f "$BOOKSTACK_SECRETS" ]]; then
    echo "ERROR: BookStack secrets file not found: ${BOOKSTACK_SECRETS}" >&2
    echo "Create it with: BOOKSTACK_URL, BOOKSTACK_TOKEN_ID, BOOKSTACK_TOKEN_SECRET" >&2
    return 1
  fi

  # Source credentials (never echo them)
  # shellcheck source=/dev/null
  source "$BOOKSTACK_SECRETS"

  local api_base="${BOOKSTACK_URL}/api"
  local auth_header="Token-Id: ${BOOKSTACK_TOKEN_ID}"
  local auth_secret="Token-Secret: ${BOOKSTACK_TOKEN_SECRET}"

  # Find or create the book
  local book_id
  book_id=$(curl -sf \
    -H "$auth_header" -H "$auth_secret" -H "Content-Type: application/json" \
    "${api_base}/books?filter[name]=$(python3 -c "import urllib.parse; print(urllib.parse.quote('${BOOKSTACK_BOOK_NAME}'))")" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['data'][0]['id'] if d['data'] else '')" 2>/dev/null || true)

  if [[ -z "$book_id" ]]; then
    info "Creating BookStack book: ${BOOKSTACK_BOOK_NAME}"
    book_id=$(curl -sf \
      -H "$auth_header" -H "$auth_secret" -H "Content-Type: application/json" \
      -X POST "${api_base}/books" \
      -d "{\"name\": \"${BOOKSTACK_BOOK_NAME}\"}" \
      | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")
  fi

  info "BookStack book ID: ${book_id}"

  # File → page title/slug mapping (includes CLAUDE.runtime.md — Bug 3 fix)
  declare -A bs_titles=(
    ["CLAUDE.md"]="Agent Constitution"
    ["CLAUDE.runtime.md"]="Runtime Environment"
    ["CLAUDE.services.md"]="Service Inventory"
    ["CLAUDE.network.md"]="Network Architecture"
    ["CLAUDE.storage.md"]="Storage Architecture"
    ["CLAUDE.automation.md"]="Automation Layer"
    ["CLAUDE.troubleshooting.md"]="Troubleshooting Guide"
    ["CLAUDE.commands.md"]="Safe Command Reference"
    ["CLAUDE.do-not-touch.md"]="Do Not Touch"
  )
  declare -A bs_slugs=(
    ["CLAUDE.md"]="claude-constitution"
    ["CLAUDE.runtime.md"]="claude-runtime"
    ["CLAUDE.services.md"]="claude-services"
    ["CLAUDE.network.md"]="claude-network"
    ["CLAUDE.storage.md"]="claude-storage"
    ["CLAUDE.automation.md"]="claude-automation"
    ["CLAUDE.troubleshooting.md"]="claude-troubleshooting"
    ["CLAUDE.commands.md"]="claude-commands"
    ["CLAUDE.do-not-touch.md"]="claude-do-not-touch"
  )

  for filename in "${!bs_titles[@]}"; do
    local filepath="${CONTEXT_DIR}/${filename}"
    local title="${bs_titles[$filename]}"
    local slug="${bs_slugs[$filename]}"
    local content
    content=$(cat "$filepath")
    local md_content
    md_content=$(printf '```\n%s\n```' "$content")

    # Bug 4 fix: use filter[slug] and filter[book_id] (BookStack v3+ API)
    local page_id
    page_id=$(curl -sf \
      -H "$auth_header" -H "$auth_secret" \
      "${api_base}/pages?filter[slug]=${slug}&filter[book_id]=${book_id}" \
      | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['data'][0]['id'] if d['data'] else '')" 2>/dev/null || true)

    local payload
    payload=$(python3 -c "
import json, sys
print(json.dumps({
  'book_id': ${book_id},
  'name': sys.argv[1],
  'markdown': sys.argv[2],
  'slug': sys.argv[3]
}))" "$title" "$md_content" "$slug")

    if [[ -z "$page_id" ]]; then
      info "Creating page: ${title}"
      curl -sf -X POST "${api_base}/pages" \
        -H "$auth_header" -H "$auth_secret" -H "Content-Type: application/json" \
        -d "$payload" > /dev/null
    else
      info "Updating page (id=${page_id}): ${title}"
      curl -sf -X PUT "${api_base}/pages/${page_id}" \
        -H "$auth_header" -H "$auth_secret" -H "Content-Type: application/json" \
        -d "$payload" > /dev/null
    fi
  done

  log "BookStack export complete — ${#bs_titles[@]} pages written to book '${BOOKSTACK_BOOK_NAME}'"
}

# ---------------------------------------------------------------------------
# Phase 3b — Optional: Export to Paperless-NGX
# ---------------------------------------------------------------------------
export_to_paperless() {
  log "Phase 3b: Exporting to Paperless-NGX"

  if [[ ! -f "$PAPERLESS_SECRETS" ]]; then
    echo "ERROR: Paperless secrets file not found: ${PAPERLESS_SECRETS}" >&2
    echo "Create it with: PAPERLESS_URL, PAPERLESS_TOKEN" >&2
    return 1
  fi

  # Source credentials
  # shellcheck source=/dev/null
  source "$PAPERLESS_SECRETS"

  local api_base="${PAPERLESS_URL}/api"
  local auth_header="Authorization: Token ${PAPERLESS_TOKEN}"

  # Bug 5 fix — Phase 1: resolve tag IDs (Paperless requires integer IDs, not name strings)
  paperless_get_or_create_tag() {
    local tag_name="$1"
    local existing_id
    # Query for existing tag (case-insensitive)
    existing_id=$(curl -sf \
      -H "$auth_header" \
      "${api_base}/tags/?name__iexact=${tag_name}" \
      | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['results'][0]['id'] if d['results'] else '')" 2>/dev/null || true)

    if [[ -n "$existing_id" ]]; then
      echo "$existing_id"
      return
    fi

    # Create the tag
    local new_id
    new_id=$(curl -sf -X POST "${api_base}/tags/" \
      -H "$auth_header" -H "Content-Type: application/json" \
      -d "{\"name\": \"${tag_name}\"}" \
      | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])" 2>/dev/null || true)
    echo "$new_id"
  }

  info "Resolving Paperless tag IDs..."
  local tag_claude tag_arch tag_sjl tag_agent
  tag_claude=$(paperless_get_or_create_tag "CLAUDE")
  tag_arch=$(paperless_get_or_create_tag "Architecture")
  tag_sjl=$(paperless_get_or_create_tag "SJL-Cloud")
  tag_agent=$(paperless_get_or_create_tag "agent-context")

  info "Tag IDs: CLAUDE=${tag_claude} Architecture=${tag_arch} SJL-Cloud=${tag_sjl} agent-context=${tag_agent}"

  if [[ -z "$tag_claude" || -z "$tag_arch" || -z "$tag_sjl" || -z "$tag_agent" ]]; then
    echo "ERROR: Failed to resolve one or more Paperless tag IDs. Check API access." >&2
    return 1
  fi

  # Phase 2: Upload each file with integer tag IDs
  local files=(
    "CLAUDE.md"
    "CLAUDE.runtime.md"
    "CLAUDE.services.md"
    "CLAUDE.network.md"
    "CLAUDE.storage.md"
    "CLAUDE.automation.md"
    "CLAUDE.troubleshooting.md"
    "CLAUDE.commands.md"
    "CLAUDE.do-not-touch.md"
  )

  for filename in "${files[@]}"; do
    local filepath="${CONTEXT_DIR}/${filename}"
    local title="SJL Cloud — ${filename}"
    local response

    info "Uploading: ${filename}"
    response=$(curl -s -w "\n%{http_code}" -X POST "${api_base}/documents/post_document/" \
      -H "$auth_header" \
      -F "document=@${filepath};type=text/plain" \
      -F "title=${title}" \
      -F "tags=${tag_claude}" \
      -F "tags=${tag_arch}" \
      -F "tags=${tag_sjl}" \
      -F "tags=${tag_agent}")

    local http_code body
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n-1)

    if [[ "$http_code" -ge 200 && "$http_code" -lt 300 ]]; then
      info "  → OK (task_id: ${body})"
    else
      echo "  WARNING: Upload failed for ${filename} — HTTP ${http_code}: ${body}" >&2
    fi
  done

  log "Paperless export complete"
}

# ---------------------------------------------------------------------------
# Execute optional phases
# ---------------------------------------------------------------------------
if [[ "$DO_BOOKSTACK" == "true" ]]; then
  export_to_bookstack
fi

if [[ "$DO_PAPERLESS" == "true" ]]; then
  export_to_paperless
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
if [[ "$DRY_RUN" == "false" ]]; then
  log "Done. Files written to: ${CONTEXT_DIR}"
  log "Verify with: ls -la ${CONTEXT_DIR}"
  ls -la "${CONTEXT_DIR}/"*.md 2>/dev/null || true
else
  log "Dry-run complete. No files were modified."
fi
