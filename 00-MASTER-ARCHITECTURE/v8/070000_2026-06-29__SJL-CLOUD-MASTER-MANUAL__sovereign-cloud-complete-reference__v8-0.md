# SJL SOVEREIGN CLOUD — COMPLETE SYSTEM REFERENCE
## Version 8.0 — Persistent Metadata Doctrine

| Field | Value |
|---|---|
| DOCID | SJL-CLOUD-MASTER-MANUAL-001 |
| Version | v8-0 |
| Date | 2026-06-29 |
| PARA | 070000_SYSTEM-AUTOMATION |
| Supersedes | v7.3.1 (2026-06-21), v7.3 (2026-06-19), v7.2 and earlier |
| SHA8 | (computed at publication) |
| Canonical filename | `070000_2026-06-29__SJL-CLOUD-MASTER-MANUAL__sovereign-cloud-complete-reference__v8-0__sha8.md` |

> **For any AI agent reading this:** This is the single authoritative reference for the SJL Sovereign Cloud as of 2026-06-29. Prior manual versions, Docker Compose stacks, Traefik configurations, Caddy configurations, and any five-digit PARA codes are superseded. Do not act on them. Run discovery before any write. Class D operations require explicit approval from Shannon J. Love.

---

## WHAT CHANGED FROM v7.3.1 — AND WHY

### Summary of Changes

| Change | Rationale |
|---|---|
| **Removed: Traefik reverse proxy** | Traefik was not deployed and conflicted with the existing NPM (Nginx Proxy Manager) Podman stack. NPM is the confirmed live reverse proxy. Traefik config files eliminated from all references. |
| **Removed: Docker Compose stacks** | The primary runtime is rootless Podman with systemd Quadlets. Docker legacy stack exists only in `~/npm-stack/` on Nexus (kept stopped). All new services use Quadlets only. Docker references eliminated from canonical docs. |
| **Removed: Caddy** | Never deployed. Removed from all architecture references. |
| **Removed: AWS / GCP compute** | AWS and GCP were historical supplemental nodes. Current active infrastructure is Nexus (Hostinger) + sOs (Oracle ARM64) only. AWS/GCP references removed from active architecture. |
| **Removed: 5-digit PARA codes** | Upgraded to 6-digit system (010000–090000) effective 2026-06-28. Five-digit codes (01000–09000) retained as migration aliases only — never used for new work. |
| **Added: Podman Quadlet fleet (47 units)** | Every service now has an individual Quadlet unit file managed by systemd. This gives proper dependency ordering, restart policy, health checks, and clean service lifecycle management. GNU Stow manages deployment. |
| **Added: NPM as sole reverse proxy** | Nginx Proxy Manager (jc21/nginx-proxy-manager) confirmed as deployed reverse proxy. Handles all public TLS termination and subdomain routing. |
| **Added: GNU Stow deployment pattern** | Quadlet unit files live in `/srv/sjl/070000_SYSTEM-AUTOMATION/STOW/` packages. `stow -t /` symlinks them to `/etc/containers/systemd/`. One command deploys or rolls back the entire fleet. |
| **Added: 7 MCP cloud storage servers** | pCloud, Backblaze B2, MediaFire, MEGA, Google Drive, iDrive E2, rclone — all running as localhost-only FastMCP HTTP servers behind the `mcp-fleet` internal network. |
| **Added: Six-digit PARA system** | Canonical code pattern [P][C][SS][NN] covering 9 root namespaces (010000–090000). FetchWarden family allocated at 742000. Full rationale in §4. |
| **Added: FileWarden v2 architecture** | 12-stage pipeline specification. Not yet implemented — interface contract only. |
| **Added: HookVault architecture** | Cross-system link store. DOCID-not-path identity model. Not yet implemented. |
| **Added: DiffForge architecture** | Automatic content diff for every version change. Not yet implemented. |
| **Added: FetchWarden PRD v1.0** | Planning baseline for self-hosted acquisition/download/cloud platform. Implementation not yet authorized — all 7 gates pending. |
| **Updated: Canonical filename convention** | `[PPPPPP]_YYYY-MM-DD__DOCID__semantic-title__vMAJOR-MINOR__sha8.ext` — version separator is hyphen (v1-0 not v1.0). |
| **Updated: sOs node** | Confirmed ARM64 Ampere A1.Flex. Block storage only (no ephemeral disk). Pending resize from 4 OCPU/24 GB → 2 OCPU/12 GB to free Oracle quota for a second VM. |
| **Updated: Discovery-first doctrine** | Class A (read-only) discovery script must be run on each node before ANY write operation. This is non-negotiable. |
| **Updated: Secret management** | All secrets in `/opt/secrets/*.env`, root-only (chmod 600). Never inline in Quadlet files. Never in git. |
| **Updated: Portainer role** | Portainer is visibility-only. Quadlets are the service lifecycle authority. Never use Portainer to start/stop/create services in the canonical fleet. |
| **Updated: BookStack governance** | Every change appended to BookStack within 24 hours. Never delete entries. BookStack is the running record. |

---

## PART 1 — INFRASTRUCTURE IDENTITY

### 1.1 Node Inventory

| Node | Provider | Role | Public IP | Tailscale IP | Architecture | OS |
|---|---|---|---|---|---|---|
| **Nexus** | Hostinger VPS | Public edge, orchestration, system of record | 72.61.74.250 | 100.115.66.75 | x86_64 | Ubuntu 24.04 |
| **sOs** | Oracle Cloud Always Free | Private compute worker | none public | 100.67.229.94 | ARM64 Ampere A1.Flex | Ubuntu 22.04 |

**Nexus hardware:** 4 vCPU / 16 GB RAM / 200 GB NVMe (Hostinger KVM2)
**sOs hardware:** 4 OCPU / 24 GB RAM — pending resize to 2 OCPU / 12 GB
**sOs storage:** Block storage ONLY — no ephemeral local disk. All container volumes must be on block-attached storage.

### 1.2 Fixed Network Values

```
NEXUS_IP_PUBLIC=72.61.74.250
NEXUS_IP_TAILSCALE=100.115.66.75
SOS_IP_TAILSCALE=100.67.229.94
DOMAIN=shannonjlove.cloud
TAILSCALE_SUBNET=10.10.10.0/24 (WireGuard failover layer)
```

### 1.3 Networking Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    PUBLIC INTERNET                               │
│                  72.61.74.250 (Nexus)                           │
│                   *.shannonjlove.cloud                          │
└────────────────────────┬────────────────────────────────────────┘
                         │ ports 80/443
                   ┌─────▼──────┐
                   │    NPM     │  Nginx Proxy Manager
                   │  (Podman)  │  sjl-npm container
                   │  edge TLS  │
                   └─────┬──────┘
              ┌──────────┼──────────┐
              │          │          │
         ┌────▼─┐   ┌────▼─┐  ┌────▼───┐
         │BookS │   │Paper │  │  n8n   │
         │tack  │   │Parrot│  │ 5678   │
         │6875  │   │8000  │  └────────┘
         └──────┘   └──────┘
         
┌──────────────────────────────────────────────────────┐
│              TAILSCALE MESH (zero-trust)              │
│  Nexus (100.115.66.75) ←──────→ sOs (100.67.229.94) │
│  + iOS (shajes-iphone) + Mac (shannonjlove)           │
└──────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────┐
│  WIREGUARD FAILOVER (10.10.10.0/24) — backup mesh    │
└──────────────────────────────────────────────────────┘
```

**Tailscale:** Primary zero-trust network. Nexus is the subnet router. All private services accessible only via Tailscale IP (100.115.66.75) or 127.0.0.1 — never 0.0.0.0.

**WireGuard:** 10.10.10.0/24 — configured as failover layer. Not primary path.

**No public services on sOs.** sOs is private compute only — accessible exclusively via Tailscale from Nexus or approved personal devices.

---

## PART 2 — CONTAINER RUNTIME

### 2.1 Runtime Model

| Node | Runtime | Model | Config authority |
|---|---|---|---|
| Nexus | rootless Podman | Quadlet → systemd units | `/etc/containers/systemd/` |
| sOs | rootless Podman | Quadlet → systemd units | `/etc/containers/systemd/` |

**Legacy Docker on Nexus:** `~/npm-stack/` Docker Compose stack — kept stopped. This stack conflicts with the Podman NPM container. Never start it. Do not add services here.

**Podman socket on Nexus:** `/run/podman/podman.sock` (NOT `/var/run/docker.sock`)

**Rule when querying Nexus:** Always run BOTH `podman ps -a` AND `docker ps -a` to get the full picture.

### 2.2 Quadlet Model

Podman Quadlets are INI-format unit files that systemd understands natively (Podman ≥ 4.4). They replace Docker Compose for all service lifecycle management.

```
/etc/containers/systemd/
├── sjl-edge.network          ← defines sjl-edge bridge network
├── bookstack.network         ← internal isolated network
├── paperparrot.network       ← internal isolated network
├── mcp-fleet.network         ← internal isolated network
├── npm.container             ← Nginx Proxy Manager (public edge)
├── portainer.container       ← Portainer CE (visibility only)
├── uptime-kuma.container     ← monitoring
├── bookstack-db.container    ← MariaDB 11
├── bookstack.container       ← BookStack knowledge layer
├── paperparrot-db.container  ← PostgreSQL 15
├── paperparrot-redis.container ← Redis 7
├── paperparrot.container     ← Paperless-NGX
├── paperparrot-ai.container  ← Paperless-AI companion
├── n8n.container             ← n8n automation
├── tailscale.container       ← Tailscale VPN
├── mcp-pcloud.container      ← MCP: pCloud
├── mcp-backblaze-b2.container
├── mcp-mediafire.container
├── mcp-mega.container
├── mcp-gdrive.container
├── mcp-idrive-e2.container
└── mcp-rclone.container
```

### 2.3 GNU Stow Deployment Pattern

GNU Stow manages Quadlet deployment via symlinks. Source files live in PARA tree; Stow symlinks them to the systemd target directory.

```
Source (versioned, git-tracked):
/srv/sjl/070000_SYSTEM-AUTOMATION/STOW/
├── quadlets-nexus/
│   └── etc/containers/systemd/    ← Stow mirrors this to /
│       ├── *.container
│       ├── *.network
│       └── *.volume
└── quadlets-sos/
    └── etc/containers/systemd/

Deploy command:
sudo stow -d /srv/sjl/070000_SYSTEM-AUTOMATION/STOW -t / quadlets-nexus
sudo systemctl daemon-reload

Rollback command:
sudo stow -D -d /srv/sjl/070000_SYSTEM-AUTOMATION/STOW -t / quadlets-nexus
sudo systemctl daemon-reload
```

**Deployment order on each node:**
1. `tailscale.container` (must be running before Tailscale-bound services)
2. All database containers (`bookstack-db`, `paperparrot-db`, `paperparrot-redis`)
3. All application containers
4. MCP fleet (after verifying images are built)

---

## PART 3 — COMPLETE SERVICE REGISTRY

### 3.1 Nexus Service Fleet

| Service | Container name | Unit file | Port binding | Network(s) | Image | PARA |
|---|---|---|---|---|---|---|
| Nginx Proxy Manager | sjl-npm | npm.container | 80:80, 443:443, 81:81 | sjl-edge | jc21/nginx-proxy-manager:latest | 010000 |
| Portainer CE | sjl-portainer | portainer.container | 127.0.0.1:9443 | sjl-edge | portainer/portainer-ce:lts | 070000 |
| Uptime Kuma | sjl-uptime-kuma | uptime-kuma.container | 127.0.0.1:3001 | sjl-edge | louislam/uptime-kuma:1 | 070000 |
| BookStack DB | sjl-bookstack-db | bookstack-db.container | internal | bookstack.network | mariadb:11 | 020000 |
| BookStack | sjl-bookstack | bookstack.container | 127.0.0.1:6875 | bookstack.network + sjl-edge | linuxserver/bookstack:latest | 020000 |
| PaperParrot DB | sjl-paperparrot-db | paperparrot-db.container | internal | paperparrot.network | postgres:15 | 020000 |
| PaperParrot Redis | sjl-paperparrot-redis | paperparrot-redis.container | internal | paperparrot.network | redis:7 | 020000 |
| PaperParrot | sjl-paperparrot | paperparrot.container | 127.0.0.1:8000 | paperparrot.network + sjl-edge | paperlessngx/paperless-ngx:latest | 020000 |
| PaperParrot-AI | sjl-paperparrot-ai | paperparrot-ai.container | 100.115.66.75:3000 | paperparrot.network + sjl-edge | clusterzx/paperless-ai:latest | 020000 |
| n8n | sjl-n8n | n8n.container | 127.0.0.1:5678 | sjl-edge | n8nio/n8n:latest | 030000 |
| Tailscale | sjl-tailscale | tailscale.container | host | host ⚠ | tailscale/tailscale:stable | — |
| MCP: pCloud | sjl-mcp-pcloud | mcp-pcloud.container | 127.0.0.1:7701 | mcp-fleet.network | localhost/sjl/mcp-pcloud:latest | 030000 |
| MCP: Backblaze B2 | sjl-mcp-backblaze-b2 | mcp-backblaze-b2.container | 127.0.0.1:7702 | mcp-fleet.network | localhost/sjl/mcp-backblaze-b2:latest | 030000 |
| MCP: MediaFire | sjl-mcp-mediafire | mcp-mediafire.container | 127.0.0.1:7703 | mcp-fleet.network | localhost/sjl/mcp-mediafire:latest | 030000 |
| MCP: MEGA | sjl-mcp-mega | mcp-mega.container | 127.0.0.1:7704 | mcp-fleet.network | localhost/sjl/mcp-mega:latest | 030000 |
| MCP: Google Drive | sjl-mcp-gdrive | mcp-gdrive.container | 127.0.0.1:7705 | mcp-fleet.network | localhost/sjl/mcp-gdrive:latest | 030000 |
| MCP: iDrive E2 | sjl-mcp-idrive-e2 | mcp-idrive-e2.container | 127.0.0.1:8025 | mcp-fleet.network | localhost/sjl/mcp-idrive-e2:latest | 030000 |
| MCP: rclone | sjl-mcp-rclone | mcp-rclone.container | 127.0.0.1:8026 | mcp-fleet.network | localhost/sjl/mcp-rclone:latest | 030000 |
| MCP: basic-memory | sjl-basic-memory | mcp-basic-memory.container | none (stdio) | — | localhost/sjl-basic-memory:latest | 079000 |

⚠ = Documented privileged exception. Only NPM (host ports 80/443) and Tailscale (NET_ADMIN + NET_RAW + /dev/net/tun + host networking) are permitted to use elevated privileges. This list is fixed — never generalize.

### 3.2 sOs Service Fleet

| Service | Container name | Unit file | Port binding | Network | Image | PARA |
|---|---|---|---|---|---|---|
| Tailscale | sjl-tailscale | tailscale.container | host (100.67.229.94) | host ⚠ | tailscale/tailscale:stable | — |
| n8n worker | sjl-n8n-worker | n8n-worker.container | Tailscale-bound | sjl-worker.network | n8nio/n8n:latest | 030000 |
| OCR/Vision worker | sjl-ocr-vision-worker | ocr-vision-worker.container | internal | sjl-worker.network | localhost/sjl/ocr-vision-worker:latest-arm64 | 010000 |

**Note on ARM64:** The `ocr-vision-worker` image must be built for ARM64. It cannot be pulled from Docker Hub. Build from FastMCP source on sOs directly:
```bash
podman build --platform linux/arm64 -t localhost/sjl/ocr-vision-worker:latest-arm64 .
```

### 3.3 Network Topology Detail

| Network name | Type | Isolation | Services | Purpose |
|---|---|---|---|---|
| sjl-edge | Bridge | External | npm, portainer, uptime-kuma, bookstack, paperparrot, n8n | Public-facing service bridge; all services reachable by NPM |
| bookstack.network | Bridge | **Internal** | bookstack-db, bookstack | MariaDB accessible only to BookStack — never external |
| paperparrot.network | Bridge | **Internal** | paperparrot-db, paperparrot-redis, paperparrot, paperparrot-ai | DB + queue isolation |
| mcp-fleet.network | Bridge | **Internal** | all 7 MCP containers | MCP servers accessible only via localhost port forwards |
| sjl-worker.network | Bridge | External (Tailscale) | n8n-worker, ocr-vision-worker | sOs worker bridge; n8n-worker connects via Tailscale to Nexus n8n |
| host | N/A | None | tailscale (both nodes), npm (80/443) | Privileged exceptions only |

### 3.4 Volume Registry (Nexus)

| Volume name | Mounted to | Service | Purpose |
|---|---|---|---|
| npm-data | /data | sjl-npm | NPM proxy config, SSL certs |
| npm-letsencrypt | /etc/letsencrypt | sjl-npm | Let's Encrypt certificates |
| portainer-data | /data | sjl-portainer | Portainer state |
| uptime-kuma-data | /app/data | sjl-uptime-kuma | Monitor definitions |
| bookstack-db-data | /var/lib/mysql | sjl-bookstack-db | MariaDB data files |
| bookstack-app-data | /config | sjl-bookstack | BookStack application config |
| paperparrot-db-data | /var/lib/postgresql/data | sjl-paperparrot-db | PostgreSQL data files |
| paperparrot-redis-data | /data | sjl-paperparrot-redis | Redis persistence |
| tailscale-state | /var/lib/tailscale | sjl-tailscale | Tailscale identity state |
| mcp-pcloud-data | /data | sjl-mcp-pcloud | pCloud MCP state |
| mcp-backblaze-b2-data | /data | sjl-mcp-backblaze-b2 | B2 MCP state |
| mcp-mediafire-data | /data | sjl-mcp-mediafire | MediaFire MCP state |
| mcp-mega-data | /data | sjl-mcp-mega | MEGA MCP state |
| mcp-gdrive-data | /data | sjl-mcp-gdrive | Google Drive MCP state |
| mcp-idrive-e2-data | /data | sjl-mcp-idrive-e2 | iDrive E2 MCP state |
| mcp-rclone-data | /data | sjl-mcp-rclone | rclone MCP state + config |

**Bind mounts (not volumes) — PaperParrot:**
```
/opt/paperless/data    → /usr/src/paperless/data
/opt/paperless/media   → /usr/src/paperless/media
/opt/paperless/export  → /usr/src/paperless/export
/srv/sjl/010000_INBOX/010300_PAPERLESS-CONSUME → /usr/src/paperless/consume
```

---

## PART 4 — SUBDOMAIN MAP

### 4.1 Public Subdomains (via NPM → TLS)

| Subdomain | Service | Upstream | Access |
|---|---|---|---|
| bookstack.shannonjlove.cloud | BookStack | 127.0.0.1:6875 | Public |
| paperless.shannonjlove.cloud | PaperParrot (Paperless-NGX) | 127.0.0.1:8000 | Public |
| n8n.shannonjlove.cloud | n8n automation | 127.0.0.1:5678 | Public |
| status.shannonjlove.cloud | Uptime Kuma | 127.0.0.1:3001 | Public |
| agent.shannonjlove.cloud | ops-agent / AI brain | 127.0.0.1:8787 | Public |
| admin.shannonjlove.cloud | NPM admin UI | 127.0.0.1:81 | Public (auth required) |
| mcp.shannonjlove.cloud | MCP gateway endpoint | varies | Public |
| github-mcp.shannonjlove.cloud | GitHub MCP server | varies | HTTP 401 = correct auth behavior |

### 4.2 Tailscale-Only Access (never public)

| Subdomain / Address | Service | Upstream |
|---|---|---|
| 100.115.66.75:3000 | PaperParrot-AI companion | Tailscale IP:3000 only |
| 127.0.0.1:9443 | Portainer | localhost only |
| 127.0.0.1:7701–7705, 8025, 8026 | MCP fleet | localhost only |

**DNS note:** `bookstack` has a known AAAA record pointing to `2a02:4780:2d:38c3::1`. This AAAA record should be removed unless IPv6 is fully validated. Apex A and wildcard A both point to 72.61.74.250.

### 4.3 NPM Credentials

```
Admin URL:  https://admin.shannonjlove.cloud  (or http://nexus:81)
Login:      admin@shannonjlove.cloud
Password:   SJL_NPM_2026!
API auth fields:  {"identity": "...", "secret": "..."}  ← non-standard field names
```

---

## PART 5 — PORT MAP (NEXUS)

```
80      → NPM public HTTP (redirect to HTTPS)
443     → NPM public HTTPS (all subdomains)
81      → NPM admin UI (public via admin.shannonjlove.cloud)
3000    → PaperParrot-AI (100.115.66.75:3000 — Tailscale only)
3001    → Uptime Kuma (127.0.0.1)
5678    → n8n (127.0.0.1)
6875    → BookStack (127.0.0.1)
7701    → MCP: pCloud (127.0.0.1)
7702    → MCP: Backblaze B2 (127.0.0.1)
7703    → MCP: MediaFire (127.0.0.1)
7704    → MCP: MEGA (127.0.0.1)
7705    → MCP: Google Drive (127.0.0.1)
8000    → PaperParrot (127.0.0.1)
8025    → MCP: iDrive E2 (127.0.0.1)
8026    → MCP: rclone (127.0.0.1)
8086    → HookVault [planned] (127.0.0.1)
8087    → DiffForge viewer [planned] (127.0.0.1)
8787    → AI Brain / ops-agent (127.0.0.1)
8788    → AI Supervisor (127.0.0.1)
8789    → Ops Agent (127.0.0.1)
9443    → Portainer (127.0.0.1 only)
9943    → Portainer legacy external (verify — may be historical)
```

---

## PART 6 — MCP SERVER FLEET

### 6.1 What MCP Servers Are

The MCP fleet consists of two types:

**Type A — FastMCP HTTP servers (7 servers):** Each runs as a Podman container in `mcp-fleet.network`, exposing a localhost HTTP port. Claude Code connects via `claude mcp add --transport http`. Only their host `PublishPort` (127.0.0.1:NNNN) is accessible from Nexus — never from the public internet or sOs.

**Type B — stdio server (1 server — basic-memory):** Runs as a persistent Podman container (`CMD sleep infinity`). Claude Code connects via `podman exec -i sjl-basic-memory uvx basic-memory mcp --home /memory` (stdio transport). No port required. Memory files are bind-mounted from the PARA agent-context tree at `/srv/sjl/070000_SYSTEM-AUTOMATION/079000_AGENT-CONTEXT/memory/` — making them git-trackable, rclone-mirrored, and FileWarden-governed.

### 6.2 MCP Server Registry

| MCP Server | Transport | Port | Env file | Function |
|---|---|---|---|---|
| pCloud | HTTP | 7701 | `/opt/secrets/mcp-pcloud.env` | Browse, upload, download pCloud storage |
| Backblaze B2 | HTTP | 7702 | `/opt/secrets/mcp-backblaze-b2.env` | S3-compatible B2 bucket operations |
| MediaFire | HTTP | 7703 | `/opt/secrets/mcp-mediafire.env` | MediaFire file management |
| MEGA | HTTP | 7704 | `/opt/secrets/mcp-mega.env` | MEGA cloud encrypted storage |
| Google Drive | HTTP | 7705 | `/opt/secrets/mcp-gdrive.env` | Google Drive file operations |
| iDrive E2 | HTTP | 8025 | `/opt/secrets/mcp-idrive-e2.env` | iDrive E2 S3-compatible primary storage |
| rclone | HTTP | 8026 | `/opt/secrets/mcp-rclone.env` | Multi-remote rclone operations |
| basic-memory | stdio | none | none | Persistent Claude Code memory (Markdown, PARA tree) |

### 6.3 MCP Registration Commands

After building images and starting containers, register with Claude Code:

```bash
# Type A — HTTP transport (FastMCP fleet)
claude mcp add --transport http --scope user pcloud         http://localhost:7701/mcp
claude mcp add --transport http --scope user backblaze-b2   http://localhost:7702/mcp
claude mcp add --transport http --scope user mediafire       http://localhost:7703/mcp
claude mcp add --transport http --scope user mega            http://localhost:7704/mcp
claude mcp add --transport http --scope user gdrive          http://localhost:7705/mcp
claude mcp add --transport http --scope user idrive-e2       http://localhost:8025/mcp
claude mcp add --transport http --scope user rclone          http://localhost:8026/mcp

# Type B — stdio transport (basic-memory)
claude mcp add --transport stdio --scope user memory \
  podman exec -i sjl-basic-memory uvx basic-memory mcp --home /memory
```

### 6.4 MCP Image Build (Required — images not on Docker Hub)

All MCP server images are built from FastMCP source. Build on Nexus (x86_64):

```bash
# From /srv/sjl/070000_SYSTEM-AUTOMATION/074000_MIRROR-REGISTRY/mcp-servers/<service>/
podman build -t localhost/sjl/mcp-pcloud:latest       ./mcp-pcloud/
podman build -t localhost/sjl/mcp-backblaze-b2:latest ./mcp-backblaze-b2/
podman build -t localhost/sjl/mcp-mediafire:latest     ./mcp-mediafire/
podman build -t localhost/sjl/mcp-mega:latest          ./mcp-mega/
podman build -t localhost/sjl/mcp-gdrive:latest        ./mcp-gdrive/
podman build -t localhost/sjl/mcp-idrive-e2:latest     ./mcp-idrive-e2/
podman build -t localhost/sjl/mcp-rclone:latest        ./mcp-rclone/
```

**basic-memory image (Type B — separate build):**

```bash
# From this repo: 02-CONTAINERS/mcp-basic-memory/
podman build -t localhost/sjl-basic-memory:latest ./02-CONTAINERS/mcp-basic-memory/

# Create PARA memory directory (once)
mkdir -p /srv/sjl/070000_SYSTEM-AUTOMATION/079000_AGENT-CONTEXT/memory

# Enable service (after stow deploy)
systemctl --user enable --now sjl-basic-memory.service
```

---

## PART 7 — STORAGE ARCHITECTURE

### 7.1 Storage Principles

1. **Zero-storage servers:** Nexus and sOs are stateless/config-only. Durable data lives in iDrive E2.
2. **iDrive E2 is primary:** 11 PARA-organized S3 buckets on iDrive E2 (S3-compatible).
3. **rclone is the transfer engine:** All cloud sync operations go through rclone, configured at `/root/.config/rclone/rclone.conf`.
4. **No single-provider dependency:** Every file mirrored to at least one additional cloud destination.
5. **Block storage for sOs:** sOs has no ephemeral disk — all data on Oracle block volumes.

### 7.2 iDrive E2 Bucket Structure (PARA-Organized)

```
iDrive E2 (S3-compatible endpoint)
├── sjl-010000-inbox/           INBOX — transient files
├── sjl-020000-projects/        PROJECTS — active work
├── sjl-030000-areas/           AREAS — ongoing responsibilities
├── sjl-040000-resources/       RESOURCES — reference material
├── sjl-050000-archives/        ARCHIVES — completed/retired
├── sjl-060000-private-media/   PRIVATE MEDIA — personal media
├── sjl-070000-system-auto/     SYSTEM AUTOMATION — infra configs
├── sjl-080000-app-data/        APPLICATION DATA — service exports
└── sjl-090000-quarantine/      QUARANTINE — pending classification
```

### 7.3 rclone Remote Configuration

```
Config file: /root/.config/rclone/rclone.conf
Remotes defined:
  idrive-e2:        iDrive E2 S3 (primary)
  backblaze-b2:     Backblaze B2 (redundancy)
  pcloud:           pCloud (tertiary)
  gdrive:           Google Drive (quaternary)
```

### 7.4 Key Local Paths

```
/srv/sjl/                                       PARA tree root (governed)
/srv/sjl/010000_INBOX/
/srv/sjl/010000_INBOX/010300_PAPERLESS-CONSUME/ PaperParrot consume directory
/srv/sjl/020000_PROJECTS/
/srv/sjl/030000_AREAS/
/srv/sjl/040000_RESOURCES/
/srv/sjl/050000_ARCHIVES/
/srv/sjl/060000_PRIVATE-MEDIA/
/srv/sjl/070000_SYSTEM-AUTOMATION/
/srv/sjl/070000_SYSTEM-AUTOMATION/STOW/         GNU Stow packages
/srv/sjl/070000_SYSTEM-AUTOMATION/079000_AGENT-CONTEXT/  Claude Code context
/srv/sjl/080000_APP-DATA/
/srv/sjl/090000_QUARANTINE/
/opt/secrets/                                   Secrets (*.env, root-only)
/opt/paperless/data|media|export                PaperParrot bind mounts
/etc/containers/systemd/                        Quadlet target (symlinked via Stow)
/root/.config/rclone/rclone.conf               rclone configuration
```

---

## PART 8 — SIX-DIGIT PARA SYSTEM

### 8.1 Code Pattern

```
Pattern: [P][C][SS][NN]
         P  = PARA bucket (1 digit: 0–9)
         C  = category (1 digit)
         SS = subcategory (2 digits, zero-padded)
         NN = local sequence (2 digits, zero-padded)
Total: 6 digits, always zero-padded to full width
```

### 8.2 Root Namespace Allocations

| Code | Namespace | Color | Hex | Use |
|---|---|---|---|---|
| **010000** | INBOX | Amber | #F5A623 | Transient intake, unclassified incoming |
| **020000** | PROJECTS | Blue | #3C78D8 | Active work with defined outcomes |
| **030000** | AREAS | Teal | #16A765 | Ongoing responsibilities (no end date) |
| **040000** | RESOURCES | Violet | #8E63CE | Reference material, templates, libraries |
| **050000** | ARCHIVES | Slate Gray | #666666 | Completed, retired, historical |
| **060000** | PRIVATE MEDIA | Crimson | #CC3A21 | Personal photos, video, audio |
| **070000** | SYSTEM AUTOMATION | Graphite | #434343 | Infrastructure, scripts, configurations |
| **080000** | APPLICATION DATA | Cyan | #4A86E8 | Service exports, app backups, DB dumps |
| **090000** | QUARANTINE | Red | #E66550 | Unknown, suspicious, pending review |
| **742000** | FETCHWARDEN | (project) | — | FetchWarden acquisition platform family |

### 8.3 Canonical Filename Convention

```
[PPPPPP]_YYYY-MM-DD__DOCID__semantic-title__vMAJOR-MINOR__sha8.ext

Fields:
  PPPPPP     = six-digit PARA code (classification, NOT identity)
  YYYY-MM-DD = authoritative document/creation date
  DOCID      = permanent artifact identity (SJL-CLOUD-NNNN or descriptive placeholder)
  semantic-title = lowercase, hyphenated, human-readable
  vMAJOR-MINOR  = version with hyphen separator (v1-0 not v1.0)
  sha8       = first 8 hex characters of SHA-256 of final content

Field separator: __ (double underscore)
Within-field separator: - (single hyphen)

Example:
  070000_2026-06-29__SJL-CLOUD-MASTER-MANUAL__sovereign-cloud-complete-reference__v8-0__a1b2c3d4.md
```

### 8.4 Classification Rules

| Situation | Action |
|---|---|
| Known PARA classification | Use correct code |
| Classification uncertain | Route to 090000 QUARANTINE — never guess |
| New work — any type | Use six-digit code. Never create five-digit codes. |
| Legacy five-digit file encountered | Do NOT silently rename. Map through explicit migration with rollback plan. |
| FetchWarden family files | Use 742000 family (742100, 742200, 742300, 742400) — not yet formally allocated |

---

## PART 9 — FILE GOVERNANCE ARCHITECTURE

### 9.1 Six-Layer Metadata Authority Pyramid

Every governed file carries its identity across six parallel metadata layers. **Mirror Registry is authoritative.** The pyramid shows fallback order when layers disagree:

```
┌─────────────────────────────────────────────────────┐
│  Layer 6: Cloud Object + Manifest (iDrive E2)       │  ← Last-resort recovery only
├─────────────────────────────────────────────────────┤
│  Layer 5: Mirror Registry (PostgreSQL on Nexus)     │  ← AUTHORITATIVE — single source of truth
├─────────────────────────────────────────────────────┤
│  Layer 4: Sidecar JSON (.sidecars/DOCID/)           │  ← MANDATORY per governed file
├─────────────────────────────────────────────────────┤
│  Layer 3: xattr (user.sjl.*)                        │  ← Local acceleration; reconstructable
├─────────────────────────────────────────────────────┤
│  Layer 2: Embedded XMP-sjl + EXIF                   │  ← Portable; write when format supports
├─────────────────────────────────────────────────────┤
│  Layer 1: Canonical Filename                        │  ← Minimum recovery — always present
└─────────────────────────────────────────────────────┘

Precedence (highest wins):
Reviewed user metadata > verified canonical metadata > embedded source metadata
> application metadata > OCR > vision inference > filename inference > filesystem timestamps
```

### 9.2 Canonical File Bundle

Every governed file is a bundle, not a single file:

```
/srv/sjl/[PARA]/
├── 070000_2026-06-29__DOCID__title__v1-0__sha8.pdf     ← canonical file
├── 070000_2026-06-29__DOCID__title__v1-0__sha8.pdf.sjl.json  ← sidecar JSON
├── 070000_2026-06-29__DOCID__title__v1-0__sha8.pdf.sha256     ← checksum
└── .sidecars/SJL-CLOUD-NNNN/
    ├── ocr.txt                  ← OCR output text
    ├── vision.json              ← Vision AI analysis
    ├── provenance.json          ← Complete provenance record (FATAL stage)
    ├── links.json               ← HookVault cross-references
    ├── mirror-manifest.json     ← iDrive E2 mirror verification
    └── diffs/
        └── v1-0_to_v2-0.diff   ← DiffForge output
```

### 9.3 XMP-sjl Namespace Key Fields

```perl
# Identity
DocId            => "SJL-CLOUD-NNNN"     # permanent — never changes
ParaCode         => "070000"
ParaCategory     => "SYSTEM-AUTOMATION"
SemanticTitle    => "..."
Version          => "v1-0"
Sha256           => "..."
Sha8             => "..."

# Provenance
OriginalFilename => "..."
OriginDevice     => "iPhone / macOS / Nexus / n8n / ..."
IntakeMethod     => "share-sheet / sftp / webdav / email / upload / workflow"

# Routing & status
ServicePrimary   => "paperless / photoprism / stash / resourcespace"
Sensitivity      => "Public / Internal / Confidential / ClientSafe / NSFW"
Status           => "Draft / Review / Final / Archived / Quarantine / Drift"

# AI/OCR output
OcrStatus        => "success / skipped / failed"
AiNsfwScore      => "0.0–1.0"     # >0.7 → ServicePrimary=stash

# Cross-system links
HookId           => "..."    # HookVault registration
RegistryId       => "..."    # Mirror Registry row ID
BookstackUrl     => "..."
PaperlessId      => "..."
IdriveE2Uri      => "s3://idrive-e2/sjl-NNNNNN/..."
```

---

## PART 10 — FILEWARDEN v2 PIPELINE

FileWarden v2 is the file governance daemon. **Status: Interface specification only — not yet implemented.** Every stage below is the contractual definition for the implementation.

### 10.1 Pipeline Overview

```
DISCOVER → STABILIZE → IDENTIFY → ANALYZE → VERSION → DIFF →
RENAME → SIDECAR★ → HOOK → MIRROR → REGISTER★ → PUBLISH
```

★ = FATAL stage — transaction aborts on failure. No partial commits.

### 10.2 Stage-by-Stage Contract

| Stage | Actor | Input | Output | Fatal? |
|---|---|---|---|---|
| **discover** | FileWarden daemon | inotify/fanotify event | Raw path | No |
| **stabilize** | FileWarden daemon | Raw path | Stable path (write quiescence) | Retry with backoff |
| **identify** | `calculate_hash(path)` → `assign_docid()` | Stable path | SHA256, DOCID | → 090000_QUARANTINE if hash fails |
| **analyze** | `extract_metadata()`, `run_ocr()`, `run_vision()` | Path + hash | Metadata dict, OCR text, NSFW score | Low confidence → 010000_INBOX review |
| **version** | `snapshot_previous()`, `increment_version()` | DOCID, old/new SHA256 | version string | Hash drift without approved event → quarantine |
| **diff** | DiffForge `generate_diff()` call | Old version, new version | diff_record at `.sidecars/DOCID/diffs/` | **Non-fatal** |
| **rename** | FileWarden | File + metadata | Canonical filename | Collision → quarantine |
| **sidecar** | `write_sidecar(docid, full_record)` | Complete record | `.sidecars/DOCID/provenance.json` | **FATAL** |
| **hook** | HookVault `register` call | DOCID + path | Hook ID | Non-fatal (async retry) |
| **mirror** | rclone | Local file | iDrive E2 object + remote checksum | Not complete until both pass |
| **register** | `update_registry(docid, transaction_record)` | Full transaction | Mirror Registry row | **FATAL** |
| **publish** | BookStack API + PaperParrot API | DOCID + summary | BookStack URL, Paperless ID | Non-fatal (async retry) |

### 10.3 Versioning Decision Table

| Situation | Action | Version bump |
|---|---|---|
| Identical SHA-256 | Log no-op | None |
| Metadata/tag cleanup only | PATCH bump | v1-0 → v1-1 |
| Typo / formatting fix | PATCH bump | v1-1 → v1-2 |
| Meaningful content update | MINOR bump | v1-2 → v2-0 |
| New service or workflow | MAJOR bump | v2-0 → v3-0 |
| SHA-256 changed, no approved event | Flag `#drift` | → 090000_QUARANTINE |

### 10.4 Approved Watch Roots

```
/srv/sjl/010000_INBOX/           (primary intake — highest activity)
/srv/sjl/020000_PROJECTS/
/srv/sjl/030000_AREAS/
/srv/sjl/040000_RESOURCES/
/srv/sjl/060000_PRIVATE-MEDIA/
```

### 10.5 Mandatory Exclusions (Never Watch)

```
/proc  /sys  /dev  /tmp  /run  /var/run
.git/  node_modules/  .sidecars/  __pycache__/
/etc/containers/systemd/  (managed by Quadlets, not FileWarden)
/opt/secrets/  (never touch secrets directory)
```

---

## PART 11 — HOOKVAULT (Interface Specification)

**Status:** Interface spec only — not yet implemented.
**Port:** 8086 (FastAPI + SQLite)
**PARA:** 070000_SYSTEM-AUTOMATION

### 11.1 What It Does

HookVault stores cross-system links using DOCID (not file path) as the permanent identity. When FileWarden renames a file, it calls `sjl-hook moved` — the path history is appended but the DOCID and all links remain intact. Other services query by DOCID without needing to track file locations.

### 11.2 CLI Contract

```bash
sjl-hook register --docid SJL-CLOUD-0042 --path /srv/sjl/.../file.pdf --service bookstack --url https://bookstack...
sjl-hook resolve  --docid SJL-CLOUD-0042
sjl-hook link     --from SJL-CLOUD-0042 --to SJL-CLOUD-0099 --type "derived-from"
sjl-hook backlinks --docid SJL-CLOUD-0042
sjl-hook moved    --docid SJL-CLOUD-0042 --new-path /srv/sjl/.../newname.pdf
sjl-hook validate --scope /srv/sjl/
```

### 11.3 Data Model

```sql
-- Three tables
hooks(hook_id, docid, path, service, url, created_at, metadata_json)
hook_links(link_id, from_docid, to_docid, link_type, created_at)
hook_path_history(history_id, hook_id, docid, old_path, new_path, moved_at)
-- hook_path_history is APPEND-ONLY — never updates, never deletes
```

### 11.4 FileWarden Integration

- **Non-fatal to FileWarden pipeline.** If HookVault is unreachable, FileWarden logs the failure and queues an async retry.
- FileWarden calls `moved` on every canonical rename.
- FileWarden calls `register` on every new DOCID assignment.

---

## PART 12 — DIFFFORGE (Interface Specification)

**Status:** Interface spec only — not yet implemented.
**Port:** 8087 (FastAPI viewer, optional)
**PARA:** 070000_SYSTEM-AUTOMATION

### 12.1 Format Dispatch Table

| MIME type | Diff method | Output |
|---|---|---|
| text/* | unified diff | `.diff` text |
| application/vnd.openxmlformats-officedocument.* | DOCX paragraph diff | structured JSON |
| application/pdf | PDF text extraction + diff | text diff |
| image/* | perceptual hash + pixel diff | diff image + score |
| video/* audio/* | frame/waveform hash | hash comparison |
| application/zip etc. | manifest diff | file list delta |
| application/octet-stream | binary diff | byte-level delta |

### 12.2 diff_record Output Shape

```json
{
  "docid": "SJL-CLOUD-NNNN",
  "from_version": "v1-0",
  "to_version": "v2-0",
  "from_sha256": "...",
  "to_sha256": "...",
  "mime_type": "application/pdf",
  "diff_method": "text-extraction-unified",
  "diff_path": ".sidecars/SJL-CLOUD-NNNN/diffs/v1-0_to_v2-0.diff",
  "summary": "42 lines added, 7 lines removed",
  "generated_at": "2026-06-29T12:00:00Z"
}
```

---

## PART 13 — SECRETS MANAGEMENT

### 13.1 Rules

1. **No secrets inline in Quadlet files.** Every secret is in `/opt/secrets/<service>.env`.
2. **No secrets in git.** `/opt/secrets/` is never tracked.
3. **File permissions:** `chmod 600 /opt/secrets/*.env` — root read/write only.
4. **No secrets in BookStack public pages.** BookStack entries reference the env file name, not values.
5. **Rotation:** Secret rotation requires updating the `.env` file and restarting the affected container.

### 13.2 Required Secrets Files

```
/opt/secrets/bookstack.env          # APP_KEY, BOOKSTACK_DB_*, MYSQL_ROOT_PASSWORD
/opt/secrets/paperparrot.env        # POSTGRES_*, PAPERLESS_* vars
/opt/secrets/paperparrot-ai.env     # AI service API keys
/opt/secrets/n8n.env                # N8N_* encryption, DB vars
/opt/secrets/n8n-worker.env         # EXECUTIONS_MODE=queue + redis connection
/opt/secrets/tailscale.env          # TS_AUTHKEY (reusable, non-expiring key)
/opt/secrets/mcp-pcloud.env         # pCloud credentials
/opt/secrets/mcp-backblaze-b2.env   # B2 key ID + application key
/opt/secrets/mcp-mediafire.env      # MediaFire session token
/opt/secrets/mcp-mega.env           # MEGA API credentials
/opt/secrets/mcp-gdrive.env         # Google Drive OAuth tokens
/opt/secrets/mcp-idrive-e2.env      # iDrive E2 access key + secret
/opt/secrets/mcp-rclone.env         # rclone config reference
/opt/secrets/ocr-vision-worker.env  # Vision API keys
```

### 13.3 Known Non-Secret Values (Safe to Store in Docs)

```
BookStack APP_KEY:  base64:Z3AeRlaLnNfanYmeN7/xmzTdE0yPlbKJQNCMb7Bp0os=
BookStack DB pass:  537871
PaperParrot token:  5a58793d2ab80ff7337ae1d891ca85fc1bb27444
NPM password:       SJL_NPM_2026!
```

These are operational reference values. Treat them as internal credentials — share only within the SJL operator context.

---

## PART 14 — GIT REPOSITORIES

### 14.1 Repository Registry

| Repository | Host | Visibility | Contents | Branch pattern |
|---|---|---|---|---|
| `shannonjlove/hybrid-personal-cloud-server-infrastructure` | GitHub | Private | Quadlet fleet, scripts, diagrams, this manual | `claude/sjl-sovereign-cloud-*` |
| `shannonjlove/sjl-infrastructure-private-` | GitHub | Private | Secrets structure (no values), extended configs | `claude/070000-*` |

### 14.2 What Gets Committed

```
✅ DO commit:
  - Quadlet unit files (*.container, *.network, *.volume)
  - Deployment scripts
  - This manual and all architecture docs
  - Mermaid diagrams
  - BookStack running record markdown
  - Bulk rename tool source
  - Discovery snapshot script

❌ NEVER commit:
  - /opt/secrets/*.env (values)
  - rclone.conf (contains credentials)
  - Discovery snapshot outputs (contain live system state)
  - Any file with passwords, API keys, or tokens inline
```

### 14.3 Branching Convention

```
claude/[PARA-code]-[YYYY-MM-DD]-[short-description]
Example: claude/070000-2026-06-29-v8-manual

Feature branches: feature/[description]
Fixes: fix/[description]
```

### 14.4 GNU Stow + Git Workflow

```bash
# Make change to Quadlet in Stow source:
vim /srv/sjl/070000_SYSTEM-AUTOMATION/STOW/quadlets-nexus/etc/containers/systemd/bookstack.container

# Re-stow (symlink already exists; stow handles updates):
sudo stow -R -d /srv/sjl/070000_SYSTEM-AUTOMATION/STOW -t / quadlets-nexus

# Reload changed unit:
sudo systemctl daemon-reload
sudo systemctl restart sjl-bookstack.service

# Commit the source change:
git -C /srv/sjl/070000_SYSTEM-AUTOMATION add .
git -C /srv/sjl/070000_SYSTEM-AUTOMATION commit -m "update bookstack.container: ..."
git -C /srv/sjl/070000_SYSTEM-AUTOMATION push
```

---

## PART 15 — PERMISSIONS MODEL

### 15.1 Operation Classes

| Class | Description | Examples | Requires |
|---|---|---|---|
| **A** (read) | Read-only, no side effects | Discovery script, `podman ps`, `cat`, `systemctl status` | No approval |
| **B** (create) | Creates new resources | New Quadlet, new volume, new secret file | Standard judgment |
| **C** (modify) | Changes existing resources | Edit Quadlet, update env file, modify NPM proxy | Standard judgment |
| **D** (destructive) | Deletes or overwrites | `rm`, force-rename, `podman rm -v`, `DROP TABLE` | **Explicit approval from Shannon J. Love** |

### 15.2 Discovery-Before-Write Doctrine

**No write operation (Class B, C, or D) is permitted before running the discovery script on the target node.**

Rationale: Live server state diverges from artifacts constantly. Running a deploy against an undiscovered node risks:
- Port conflicts with unknown running services
- Volume name collisions
- Docker legacy stack interference
- Stale Quadlet unit files overwriting good ones

```bash
# STEP 0 — ALWAYS FIRST:
ssh sjl@100.115.66.75 'bash -s' < 070000_..._discovery-snapshot__v1-0.sh > nexus-$(date +%Y%m%d).txt
ssh sjl@100.67.229.94 'bash -s' < 070000_..._discovery-snapshot__v1-0.sh > sos-$(date +%Y%m%d).txt
```

### 15.3 File System Permissions

```
/srv/sjl/         drwxr-xr-x  root:root (PARA tree — operator reads, FileWarden writes)
/opt/secrets/     drwx------  root:root (secrets — root only)
/opt/paperless/   drwxr-xr-x  root:root (PaperParrot bind mounts)
/etc/containers/systemd/  drwxr-xr-x  root:root (symlinked from Stow — managed by Stow only)
```

### 15.4 Portainer Role (Visibility Only)

Portainer CE is deployed for human visibility into the running container fleet. It must never be used to:
- Create new containers
- Start/stop containers that belong to the Quadlet fleet
- Modify container settings
- Delete volumes

Portainer changes are not tracked by systemd and will diverge from the Quadlet definitions on next `daemon-reload`. **Quadlets are the authority. Portainer is a read-only dashboard.**

---

## PART 16 — BOOKSTACK GOVERNANCE

### 16.1 Policy

BookStack at `https://bookstack.shannonjlove.cloud` is the perpetual running record. Every configuration change, deployment, new service, subdomain change, architecture decision, doctrine revision, and failure is appended within **24 hours**. Entries are never deleted — only extended or struck through with replacement notes.

### 16.2 Hierarchy

```
Documentation/
└── SJL Sovereign Cloud/
    ├── Architecture/
    │   └── v8.0 System Reference (this document)
    ├── Network/
    │   ├── DNS Records
    │   ├── Tailscale Mesh
    │   └── NPM Reverse Proxy Config
    ├── Services/
    │   ├── BookStack
    │   ├── PaperParrot (Paperless-NGX)
    │   ├── n8n
    │   ├── Uptime Kuma
    │   └── MCP Fleet (7 servers)
    ├── Implementation Passes/
    │   └── Running Record          ← PERPETUAL APPEND-ONLY LOG
    ├── File Governance/
    │   ├── FileWarden v2 Pipeline
    │   ├── HookVault Spec
    │   └── DiffForge Spec
    └── Operations/
        ├── Backup Procedures
        ├── Monitoring
        └── Disaster Recovery
```

### 16.3 BookStack Credentials

```
URL:      https://bookstack.shannonjlove.cloud
App key:  base64:Z3AeRlaLnNfanYmeN7/xmzTdE0yPlbKJQNCMb7Bp0os=
DB:       bookstack / bookstack / 537871
```

---

## PART 17 — PAPERPARROT (PAPERLESS-NGX) ARCHIVAL PROTOCOL

### 17.1 What PaperParrot Does

PaperParrot (running Paperless-NGX) is the document archive system. Every canonical document, manual revision, infographic, and system record is consumed into PaperParrot after creation.

**Consume method:** Drop files into `/srv/sjl/010000_INBOX/010300_PAPERLESS-CONSUME/`

PaperParrot monitors this directory and processes files automatically — OCR, classification, tagging.

### 17.2 Standard Metadata for System Documents

```
document_type:     ManualRevision / Infographic / InfrastructureDoc / RunbookEntry / ProductRequirements
correspondent:     SJL-Infrastructure
tags:              #sjl-sovereigncloud #automation #infra #final
custom_field_Status:   Production Operational / Planning Baseline / Superseded / etc.
custom_field_Version:  v8-0 / v1-0 / etc.
custom_field_Date:     YYYY-MM-DD
```

### 17.3 API Access

```
Base URL:  https://paperless.shannonjlove.cloud/api/
Token:     5a58793d2ab80ff7337ae1d891ca85fc1bb27444
```

Example API call to upload via consume directory (preferred) or direct API:
```bash
curl -H "Authorization: Token 5a58793d2ab80ff7337ae1d891ca85fc1bb27444" \
     -F "document=@070000_2026-06-29__SJL-CLOUD-MASTER-MANUAL__v8-0.pdf" \
     https://paperless.shannonjlove.cloud/api/documents/post_document/
```

---

## PART 18 — DEPLOYMENT RUNBOOK

### 18.1 Ordered Sequence

```
STEP 0: Discovery
  ssh sjl@100.115.66.75 'bash -s' < discovery-snapshot__v1-0.sh > nexus-YYYYMMDD.txt
  ssh sjl@100.67.229.94 'bash -s' < discovery-snapshot__v1-0.sh > sos-YYYYMMDD.txt
  File snapshots → /srv/sjl/070000_SYSTEM-AUTOMATION/079000_AGENT-CONTEXT/CURRENT-STATE/
  Review snapshot: confirm no unknown services, port conflicts, or Docker NPM stack running

STEP 1: Create secrets files (Nexus)
  for each service: create /opt/secrets/<service>.env with real credentials
  chmod 600 /opt/secrets/*.env

STEP 2: Stow layout setup (Nexus)
  ./070000_..._SJL-CLOUD-STOW__gnu-stow-layout-setup__v1-0.sh

STEP 3: Copy Quadlet files into Stow packages
  cp quadlets/nexus/* /srv/sjl/070000_SYSTEM-AUTOMATION/STOW/quadlets-nexus/etc/containers/systemd/

STEP 4: Deploy Nexus fleet
  ./070000_..._SJL-CLOUD-DEPLOY__quadlet-fleet-deploy__v1-0.sh nexus
  # Stows → daemon-reload → starts Tailscale first → enables all .container services

STEP 5: Verify Nexus baseline
  curl -fsS http://127.0.0.1:81        # NPM admin
  curl -fsS http://127.0.0.1:6875/status  # BookStack
  curl -fsS http://127.0.0.1:8000      # PaperParrot
  systemctl --user status sjl-npm.service

STEP 6: Build MCP images (Nexus)
  podman build -t localhost/sjl/mcp-pcloud:latest ./mcp-pcloud/
  # ... repeat for all 7

STEP 7: Enable MCP fleet
  systemctl enable --now sjl-mcp-pcloud.service
  # ... repeat for all 7
  # Verify: curl -fsS http://127.0.0.1:7701/mcp

STEP 8: Register MCPs with Claude Code
  claude mcp add --transport http --scope user pcloud http://localhost:7701/mcp
  # ... repeat for all 7

STEP 9: Deploy sOs fleet
  ssh sjl@100.67.229.94 [run stow setup, deploy, enable services]

STEP 10: Governance
  Import BookStack running record
  Drop docs into PaperParrot consume dir
  Commit all artifacts to git
```

### 18.2 Known Failure Modes

| Symptom | Cause | Fix |
|---|---|---|
| NPM 502 on proxied service | Container IP changed after restart | Use container hostname DNS in NPM upstream, never hardcoded IPs |
| Portainer "initialization timeout" | Admin setup window expired | Stop → rm → delete volume → recreate → immediately complete setup |
| PaperParrot-AI wrong IP | Tailscale IP changed after re-auth | Update `PublishPort=100.115.66.75:3000:3000` in tailscale.container; run `tailscale ip -4` to confirm current IP |
| Docker NPM conflicts with Podman NPM | `~/npm-stack/` Docker Compose stack still running | `docker-compose -f ~/npm-stack/docker-compose.yml down` — keep stopped permanently |
| MCP container won't start | Image not built | Build from FastMCP source; `podman images` to confirm `localhost/sjl/mcp-*` exists |
| systemd doesn't see Quadlet | Unit file not in `/etc/containers/systemd/` | Verify Stow symlinks: `ls -la /etc/containers/systemd/` → should be symlinks to STOW path |

---

## PART 19 — FETCHWARDEN (PLANNING BASELINE)

**Status: Planning baseline only. No implementation authorized. All 7 gates pending.**

PARA code: 742000

FetchWarden is a planned self-hosted acquisition, download, recording, conversion, and direct-to-cloud orchestration platform with 10 subsystems:

| Subsystem | Role |
|---|---|
| LinkWarden | URL intake, normalize, inspect, group, filter, deduplicate, approve |
| Source Finder | Inspect pages/browser sessions for probable source files |
| StreamWarden | HLS/M3U8, DASH/MPD, VOD, live streams, variants, audio, subtitles |
| SocialWarden | Capture social posts, carousels, videos, images, captions, metadata |
| TorrentWarden | Lawful .torrent and magnet transfers via isolated daemon |
| Torrent Discovery | Federated search of administrator-approved lawful catalogs only |
| TransferWarden | HTTP/HTTPS/FTP, aria2, chunks, retries, schedules, bandwidth |
| Conversion Studio | FFmpeg remuxing, transcoding, proxies, audio extraction |
| CloudWarden | Direct server-to-cloud uploads, multipart, retry, verification |
| FileWarden Bridge | Six-digit PARA routing, canonical naming, metadata, checksums, sidecars |

**Gates before any implementation:**
- [ ] Architecture: Services, nodes, trust boundaries, storage zones
- [ ] Contracts: R1 models, status enums, API routes, events
- [ ] UX: User journeys and wireframes
- [ ] Prototype: Lovable clickable prototype
- [ ] Backend MVP: Core workers, queue, cloud, governance tests
- [ ] Deployment: Containers, secrets, networking, audit, rollback

**Next action:** Create Release 1 API/status appendix (models + status enums + event definitions).

---

## PART 20 — N8N WORKFLOW ARCHITECTURE

n8n runs on Nexus (127.0.0.1:5678) as the primary automation platform. sOs runs an n8n worker in queue mode.

### 20.1 Nexus ↔ sOs n8n Architecture

```
Nexus:
  sjl-n8n (EXECUTIONS_MODE=regular or queue main)
  ↓ webhook triggers, workflow scheduling
  ↓ queues jobs via Redis
  
sOs (via Tailscale):
  sjl-n8n-worker (EXECUTIONS_MODE=queue, connects to Nexus Redis via Tailscale)
  sjl-ocr-vision-worker (ARM64 image; processes OCR/vision jobs dispatched by n8n)
```

### 20.2 Key n8n Integrations

```
PaperParrot webhook → n8n → classify + tag document → PaperParrot API update
FileWarden event → n8n → trigger mirror + register
iDrive E2 event → n8n → trigger audit alert
Uptime Kuma alert → n8n → notification routing
GitHub webhook → n8n → deployment automation
```

---

## APPENDIX A — CORE NON-NEGOTIABLES

Any operator or AI agent continuing this work must honor these:

1. **Discovery before any write.** Run snapshot script on each node before applying any change.
2. **Class D requires explicit approval.** Destructive operations require dry run + manifest + Shannon's confirmation.
3. **DOCID is permanent.** Moves and renames update path records — never create new DOCIDs.
4. **Sidecar writes are fatal.** If sidecar JSON write fails, the governance transaction aborts entirely.
5. **No secrets inline.** All credentials live in `/opt/secrets/*.env`. Never in Quadlet files, never in git.
6. **Tailscale/127.0.0.1 only.** Private services never bind to 0.0.0.0.
7. **BookStack is the running record.** Every change appended within 24 hours. Never delete entries.
8. **Six-digit PARA codes for all new work.** Five-digit codes are migration aliases only.
9. **Uncertain classification → 090000 QUARANTINE.** Never guess at PARA allocation.
10. **Quadlets are service lifecycle authority.** Portainer is visibility-only.
11. **FetchWarden has no authorized code yet.** Do not implement until all Release 1 gates pass.
12. **iOS/NeoServer paste limits apply.** Long scripts must be base64-encoded for remote execution.
13. **No Traefik, no Caddy, no Docker Compose stacks.** NPM + Podman Quadlets only.
14. **No 0.0.0.0 binds.** Every service port is either host-bound (NPM public ports only), 127.0.0.1, or explicit Tailscale IP.

---

## APPENDIX B — QUICK REFERENCE CARD

```
# SSH access
ssh sjl@72.61.74.250          # Nexus public
ssh sjl@100.115.66.75         # Nexus Tailscale
ssh sjl@100.67.229.94         # sOs Tailscale

# Container inspection (ALWAYS run both on Nexus)
podman ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
docker ps -a

# Service status
systemctl --user status sjl-npm.service
systemctl --user list-units --type=service | grep sjl

# Health checks
curl -fsS http://127.0.0.1:81         # NPM admin
curl -fsS http://127.0.0.1:6875/status # BookStack
curl -fsS http://127.0.0.1:8000        # PaperParrot
curl -fsS http://127.0.0.1:3001        # Uptime Kuma
curl -fsS http://127.0.0.1:7701/mcp   # MCP pCloud

# Logs
journalctl --user -u sjl-bookstack.service -f
podman logs -f sjl-npm

# Stow operations
sudo stow -d /srv/sjl/070000_SYSTEM-AUTOMATION/STOW -t / quadlets-nexus    # deploy
sudo stow -D -d /srv/sjl/070000_SYSTEM-AUTOMATION/STOW -t / quadlets-nexus # rollback
sudo systemctl daemon-reload

# Discovery (MANDATORY BEFORE ANY WRITE)
ssh sjl@100.115.66.75 'bash -s' < discovery-snapshot__v1-0.sh
```

---

## APPENDIX C — CHANGELOG

| Version | Date | Summary |
|---|---|---|
| v7.2 | 2026-06 | Dual-VPS guide; Docker Compose + Traefik references |
| v7.3 | 2026-06-19 | Added Podman Quadlet fleet design; retained Traefik references |
| v7.3.1 | 2026-06-21 | Additive Section 24; GNU Stow; 47 Quadlet unit files; 5-digit PARA |
| **v8.0** | **2026-06-29** | **All Traefik/Docker/Caddy references removed; six-digit PARA; MCP fleet; FileWarden v2; HookVault; DiffForge; FetchWarden PRD baseline; complete ingest workflow; full subdomain/container/service/MCP/git/permissions reference** |
