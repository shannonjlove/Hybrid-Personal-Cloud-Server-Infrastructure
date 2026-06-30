# CLAUDE.md — SJL Sovereign Cloud Persistent Skills & Patterns

> Canonical reference for Claude Code sessions on this repository.
> Updated: 2026-06-30 | PARA: 070000_SYSTEM-AUTOMATION

---

## IDENTITY

**Project:** SJL Sovereign Cloud (v8.0)
**Owner:** Shannon J. Love (sjl@shannonjeffreylove.com)
**Canonical branch:** `claude/sjl-sovereign-cloud-7-4-anvsn5`
**Nodes:** Nexus (72.61.74.250 / 100.115.66.75) + sOs (100.67.229.94 Tailscale-only)

---

## DOCTRINE (NEVER VIOLATE)

- **Discovery before write:** Run snapshot script on each node before any write operation
- **Class D requires approval:** Destructive operations need explicit Shannon approval before execution
- **DOCID is permanent:** Never reuse, rename, or delete a DOCID
- **No secrets in git:** `/opt/secrets/` is never tracked; secrets never inline in Quadlet files
- **Sidecar write = fatal:** 8a+8b+8c must ALL succeed or transaction aborts
- **Private services = Tailscale or 127.0.0.1 ONLY:** Never bind to 0.0.0.0
- **Quadlets are authority:** Portainer is visibility only, never used to start/stop services
- **FileWarden exclusion — basic-memory:** `/srv/sjl/070000_SYSTEM-AUTOMATION/079000_AGENT-CONTEXT/memory/` is EXCLUDED from FileWarden rename pipeline
- **PARA 6-digit codes:** All files, containers, services use 010000–090000 codes

---

## ARCHITECTURE QUICK REFERENCE

| Layer | Implementation |
|---|---|
| Runtime | rootless Podman + systemd Quadlets (47 unit files) |
| Deployment | GNU Stow (`stow -t / nexus` from `~/quadlets-nexus/`) |
| Reverse proxy | **NPM only** (sjl-npm, ports 80/443/81) — Traefik/Caddy ELIMINATED |
| Networking | Tailscale mesh (primary) + WireGuard failover |
| Containers (Nexus) | 19 total (18 services + basic-memory) |
| MCP fleet | 7× FastMCP HTTP (ports 7701-7705, 8025, 8026) + basic-memory (stdio) |
| Storage primary | iDrive E2 (11 PARA S3 buckets via rclone) |
| Domain | `*.shannonjlove.cloud` → 72.61.74.250 (Cloudflare) |

---

## SKILL: EXIFTOOL DATE RECOVERY

**When to use:** Any time media files have corrupt dates (1970-01-01, 1999-11-30, 2001-01-01) or missing EXIF. Always run before SFTP upload from Mac.

### Date Priority Chain

**Images:** `DateTimeOriginal` → `CreateDate` → `XMP:DateCreated` → `IPTC:DateCreated` → `GPS:GPSDateTime` → `FileModifyDate`

**Videos:** `QuickTime:DateTimeOriginal` → `QuickTime:CreateDate` → `QuickTime:TrackCreateDate` ← survives most corruption → `XMP:DateCreated` → `FileModifyDate`

### Sentinel Dates (REJECT — indicate corruption)
- `1970-01-01` — Unix epoch (video container corruption by Everpix/Loom)
- `1999-11-30` — WhatsApp EXIF strip default
- `2001-01-01` — iOS timestamp reset

### Key Commands
```bash
# Diagnose: view all date tags
exiftool -a -G -time:all /path/to/file

# Fix image: recover FileModifyDate from DateTimeOriginal
exiftool '-FileModifyDate<DateTimeOriginal' /path/to/file.jpg

# Fix video (1970 epoch): recover from TrackCreateDate
exiftool '-FileModifyDate<TrackCreateDate' '-FileName<TrackCreateDate' \
  -d %Y-%m-%d_%H.%M.%S.%%e /path/to/video.mov

# Fix video: repair CreateDate from TrackCreateDate
exiftool '-CreateDate<TrackCreateDate' '-ModifyDate<TrackCreateDate' /path/to/video.mov

# Batch fix all images in directory
exiftool -r '-FileModifyDate<DateTimeOriginal' /path/

# Find sentinel-date files
exiftool -q -r -if '$DateTimeOriginal =~ /^(1970|1999|2001-01-01)/' \
  -filename -DateTimeOriginal /path/

# Batch fix only 1970-epoch videos
exiftool -r -if '$CreateDate =~ /^1970/' \
  '-CreateDate<TrackCreateDate' '-ModifyDate<TrackCreateDate' /path/
```

---

## SKILL: MACOS XATTR + FINDER TAGS

**When to use:** Mac-side preprocessing before SFTP, or annotating files returned to Mac.

### Reading Tags (always use mdls, NOT xattr hex)
```bash
# Read Finder tags (clean output):
mdls -raw -name kMDItemUserTags /path/to/file

# Read any metadata xattr:
mdls -raw -name kMDItemDescription /path/to/file
mdls -raw -name kMDItemWhereFroms /path/to/file

# List all xattrs:
xattr -l /path/to/file
```

### Writing Finder Tags (read-modify-write — use `tag` CLI)
```bash
# Install: brew install tag
tag --add "sjl-para-070000" /path/to/file   # add (preserves existing)
tag --remove "sjl-para-060000" /path/to/file
tag --list /path/to/file
tag --set "sjl-para-070000,filewarden" /path/to/file  # replace all
```

### Writing Standard Metadata xattrs (Mac)
```bash
# DOCID in Finder Get Info (kMDItemDescription):
xattr -w com.apple.metadata:kMDItemDescription \
  "SJL-CLOUD-0042 | 070000 | v1-0" /path/to/file

# Clear quarantine (after download/verification):
xattr -d com.apple.quarantine /path/to/file
xattr -dr com.apple.quarantine /directory/

# Creator tag:
xattr -w com.apple.metadata:kMDItemCreator "FileWarden-v2" /path/to/file
```

### Key macOS xattr Keys
| Key | Purpose |
|---|---|
| `com.apple.metadata:_kMDItemUserTags` | Finder tags (plist array) |
| `com.apple.metadata:kMDItemDescription` | DOCID + PARA + version (Finder Get Info) |
| `com.apple.metadata:kMDItemWhereFroms` | Download origin URLs (plist array) |
| `com.apple.metadata:kMDItemDownloadedDate` | Acquisition timestamp |
| `com.apple.metadata:kMDItemCreator` | Creating application |
| `com.apple.quarantine` | Gatekeeper flag — CLEAR after verification |

### Linux xattr (Nexus — `user.*` namespace)
```python
import xattr
xattr.setxattr(path, 'user.sjl.docid',        docid.encode())
xattr.setxattr(path, 'user.sjl.para',          para_code.encode())
xattr.setxattr(path, 'user.sjl.version',       version_string.encode())
xattr.setxattr(path, 'user.sjl.sha256',        sha256_hex.encode())
xattr.setxattr(path, 'user.sjl.captured_at',   captured_at.encode())
xattr.setxattr(path, 'user.sjl.exif_stripped', b'true' if exif_stripped else b'false')
```

---

## SKILL: FILEWARDEN v2 STAGE MAP

| Stage | Fatal? | Program | Platform |
|---|---|---|---|
| 0 INTAKE | — | SFTP/n8n/PaperParrot | Nexus |
| 0.3 MAC PREPROCESSING | — | exiftool + tag + xattr | **Mac** |
| 1 DISCOVER | — | inotify_simple (Python) | Nexus |
| 2 STABILIZE | — | stat() polling | Nexus |
| 3 IDENTIFY | yes | hashlib.sha256 + Mirror Registry | Nexus |
| 4 ANALYZE | — | python-magic + exiftool + OCR/Vision | Nexus + **sOs** |
| 4d DATE CHAIN | — | exiftool priority chain + sentinel detection | Nexus |
| 5 VERSION | — | Mirror Registry + increment_version() | Nexus |
| 6 DIFF | — | DiffForge :8087 (non-fatal) | Nexus |
| 7 RENAME | — | canonical filename builder | Nexus |
| 8 SIDECAR | **FATAL** | JSON + xattr + XMP-sjl | Nexus |
| 8d MAC XATTR | — | kMDItemDescription + tag CLI | **Mac** (post-receive) |
| 9 HOOK | — | sjl-hook :8086 (async retry) | Nexus |
| 10 MIRROR | — | rclone + hashsum verify | Nexus |
| 11 REGISTER | **FATAL** | psycopg2 → logical_files | Nexus |
| 12 PUBLISH | — | BookStack API + PaperParrot API | Nexus |

---

## SKILL: PODMAN QUADLET PATTERNS

```bash
# Enable + start a new Quadlet service:
systemctl --user daemon-reload
systemctl --user enable --now sjl-SERVICE_NAME.service

# Stow deploy (from ~/quadlets-nexus package root):
stow -t / nexus

# Stow rollback:
stow -D nexus

# Build custom image before enabling:
podman build -t localhost/sjl-IMAGE_NAME:latest ./02-CONTAINERS/IMAGE_NAME/

# Check status:
systemctl --user status sjl-SERVICE_NAME.service
podman logs sjl-SERVICE_NAME
```

---

## SKILL: MCP FLEET REGISTRATION

```bash
# Type A — FastMCP HTTP (7 servers):
claude mcp add --transport http --scope user pcloud       http://localhost:7701/mcp
claude mcp add --transport http --scope user backblaze-b2 http://localhost:7702/mcp
claude mcp add --transport http --scope user mediafire     http://localhost:7703/mcp
claude mcp add --transport http --scope user mega          http://localhost:7704/mcp
claude mcp add --transport http --scope user gdrive        http://localhost:7705/mcp
claude mcp add --transport http --scope user idrive-e2     http://localhost:8025/mcp
claude mcp add --transport http --scope user rclone        http://localhost:8026/mcp

# Type B — stdio (basic-memory):
claude mcp add --transport stdio --scope user memory \
  podman exec -i sjl-basic-memory uvx basic-memory mcp --home /memory
```

---

## KEY FILE LOCATIONS

| What | Where |
|---|---|
| v8.0 master manual | `00-MASTER-ARCHITECTURE/v8/070000_2026-06-29__SJL-CLOUD-MASTER-MANUAL__*.md` |
| Ingest workflow | `03-AUTOMATION/ingest-workflow/070000_2026-06-29__SJL-CLOUD-INGEST__*.md` |
| ExifTool + xattr reference | `03-AUTOMATION/070000_2026-06-30__SJL-CLOUD-METADATA__exiftool-xattr-tagging-reference__v1-0.md` |
| System diagrams (10 Mermaid) | `diagrams/070000_2026-06-29__SJL-CLOUD-DIAGRAMS__*.md` |
| Infographic PNG | `diagrams/070000_2026-06-29__SJL-CLOUD-INFOGRAPHIC__*__e2fdac5b.png` |
| Infographic SVG | `diagrams/070000_2026-06-29__SJL-CLOUD-INFOGRAPHIC__*__d9382ef7.svg` |
| basic-memory Dockerfile | `02-CONTAINERS/mcp-basic-memory/Dockerfile` |
| basic-memory Quadlet | `quadlets/nexus/mcp-basic-memory.container` |
| Memory notes (basic-memory) | `memory/` in repo → `/srv/sjl/070000_SYSTEM-AUTOMATION/079000_AGENT-CONTEXT/memory/` on Nexus |
| Secrets (never in git) | `/opt/secrets/*.env` on Nexus |

---

## CANONICAL FILENAME CONVENTION

```
[PPPPPP]_YYYY-MM-DD__DOCID__semantic-title__vMAJOR-MINOR__sha8.ext

Example:
040000_2026-06-30__SJL-CLOUD-0042__annual-budget-review__v1-0__a1b2c3d4.pdf
```

- `PPPPPP` = 6-digit PARA code (010000–090000)
- `DOCID` = permanent document identity (never changes)
- `sha8` = first 8 chars of SHA-256 (changes with content)
- Version: PATCH = `vN-M+1`, MINOR = `vN+1-0`, MAJOR = `vN+1-0` (per change_type)
