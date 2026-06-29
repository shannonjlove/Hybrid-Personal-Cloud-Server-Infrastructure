# shannonjlove.cloud — System File Ingest Workflow Governance Manual

**Owner:** Shannon J. Love  
**Domain:** shannonjlove.cloud  
**Status:** Authoritative Reference — Ingest Workflow  
**Last Updated:** 2026-06-30  
**Stored At:** `05-DOCS/file-ingest-governance.md`

> **Naming convention authority:** `00-MASTER-ARCHITECTURE/sjl-para-naming-master.md`
> This document governs the ingest pipeline and storage routing. The naming master governs the canonical filename format, PARA code assignment, and the Master Allocation Registry.

---

## Table of Contents

1. [Purpose & Scope](#1-purpose--scope)
2. [Naming Convention Master Standard](#2-naming-convention-master-standard)
3. [PARA Category Taxonomy](#3-para-category-taxonomy)
4. [File Ingest Workflow — Stage by Stage](#4-file-ingest-workflow--stage-by-stage)
5. [Storage Routing Matrix](#5-storage-routing-matrix)
6. [Automation Layer Reference](#6-automation-layer-reference)
7. [Metadata & Tagging Standards](#7-metadata--tagging-standards)
8. [Cloud Provider Roles & Ingest Endpoints](#8-cloud-provider-roles--ingest-endpoints)
9. [Governance, Exceptions & Change Control](#9-governance-exceptions--change-control)
10. [Audit & Compliance](#10-audit--compliance)
11. [Quick Reference](#11-quick-reference)

---

## 1. Purpose & Scope

### 1.1 What This Manual Governs

This document is the single authoritative source for how any file entering the shannonjlove.cloud ecosystem is:

- Named
- Classified into a PARA category
- Processed through the ingest pipeline
- Tagged with metadata
- Routed to the correct storage tier
- Logged and audited

Every file — documents, media, code, exports, backups, configs, correspondence — is subject to this standard regardless of source device, cloud provider, or entry method.

### 1.2 Scope Boundary

| In Scope | Out of Scope |
|----------|-------------|
| Files entering via Hazel drop zones | System files managed by the OS |
| Files uploaded to cloud providers | Container runtime internals |
| Files created by shell scripts | Git-tracked repo contents (governed by git) |
| Files ingested via MCP server integrations | Temporary `/tmp` scratch files |
| All files under `*.shannonjlove.cloud` | Secrets / `.env` files (never filed) |

### 1.3 Integration Points

This manual governs the **03-AUTOMATION** layer and informs:
- `03-AUTOMATION/file-routing/` — routing logic
- `03-AUTOMATION/auto-tagging/` — Hazel + xattr tagging
- `03-AUTOMATION/metadata-persistence/` — sidecar generation
- `03-AUTOMATION/versioning/` — snapshot policies
- `05-DOCS/troubleshooting.md` — failure recovery
- `06-OPS/approvals/` — change control for pipeline modifications

---

## 2. Naming Convention Master Standard

> **This section is a summary.** The authoritative specification, full field definitions, examples, and the Master Allocation Registry live in:
> `00-MASTER-ARCHITECTURE/sjl-para-naming-master.md`

### 2.1 The Canonical Format (v8.0 — Current)

```
[PPPPPP]_YYYY-MM-DD__DOCID__semantic-title__vMAJOR-MINOR__sha8.ext
```

The **six-digit PARA code** is always the first field. Field delimiters are double underscores `__`. Every field is mandatory.

| Field | Example | Description |
|-------|---------|-------------|
| `[PPPPPP]` | `020000` | Six-digit PARA classification code |
| `YYYY-MM-DD` | `2026-06-30` | ISO 8601 file creation date |
| `DOCID` | `sjl-doc-00417` | Permanent artifact identity — never changes across versions |
| `semantic-title` | `tagback-api-spec` | Lowercase hyphen-slug, ≤60 chars |
| `vMAJOR-MINOR` | `v2-1` | Content revision version |
| `sha8` | `a3f9c2b1` | First 8 hex chars of SHA-256 |
| `.ext` | `.pdf` | Lowercase file extension |

### 2.2 Four Components — Keep Distinct

| Component | Changes When |
|-----------|-------------|
| PARA code | Lifecycle state changes |
| DOCID | **Never** — same across all versions |
| Version | Content changes |
| sha8 | Bytes change |

### 2.3 Field Definitions (Summary)
- Be specific enough to identify the file without opening it
- Example: `traefik-config-updated`, `quarterly-invoice-q2`, `photo-shoot-golden-gate`

#### Field 5 — UUID24: `UUID24`
- A 24-character unique identifier ensuring global uniqueness across the estate
- Format: `[a-z0-9]{24}` — 24 lowercase alphanumeric characters
- Generated at ingest time (see Section 6.3 for generation script)
- Prevents collision across cloud providers, devices, and time
- Example: `a7k3m9p2x8nq4r6t5v1w0ybc`

#### Extension: `.ext`
- Preserve original file extension in lowercase
- If a file has no extension, append the detected MIME type's canonical extension
- Never strip or change extensions

### 2.3 Full Examples

| Situation | Canonical Filename |
|-----------|-------------------|
| Fellowship application PDF | `2026-03-15_10-30_PROJECTS-fellowship_application-draft-v3_m4k9p2x7q8nw3r5t1v0ybc6j.pdf` |
| Server maintenance runbook | `2026-05-01_09-00_AREAS-server_nexus-traefik-restart-runbook_a7k3m9p2x8nq4r6t5v1w0ybc.md` |
| Shell script template | `2026-01-10_00-00_RESOURCES-templates_hazel-rule-base-template_z2x9q7m4p8k3n6r1t5v0wcbj.sh` |
| Completed project archive | `2025-12-31_23-59_ARCHIVE-projects_tagback-v1-final-bundle_b4n7p2x8q9mk3r6t5v1w0ycj.zip` |
| Raw photo import | `2026-06-29_14-30_AREAS-photo_portrait-session-natural-light_k9m4p2x7q8nw3r5t1v0ybc6j.dng` |

### 2.4 Prohibited Patterns

The following are **never** acceptable and will be rejected by the ingest validator:

- Spaces in filenames (use hyphens)
- Uppercase in description or subcategory fields
- Underscores used as word separators within description (underscores are field delimiters only)
- Missing UUID24 (the final `_UUID24` block before `.ext`)
- Date formats other than `YYYY-MM-DD`
- Filenames beginning with a period (hidden files must use the `dot-` prefix convention: `dot-gitignore` as description)

### 2.5 Rename-on-Ingest Rule

Any file entering a drop zone that does **not** already conform to this standard is automatically renamed by the ingest pipeline before routing. The pipeline:

1. Extracts or assigns a creation date from file metadata
2. Classifies the PARA category from folder context or content heuristics
3. Assigns the appropriate subcategory
4. Slugifies the original filename as the description (truncated to 60 chars)
5. Generates a fresh UUID24
6. Preserves the extension in lowercase

---

## 3. PARA Category Taxonomy

### 3.1 PROJECTS

**Definition:** Active work with a defined endpoint (deliverable, deadline, or completion state).

| Subcategory Slug | Description | Example Files |
|-----------------|-------------|---------------|
| `fellowship` | Grant and fellowship applications | Application PDFs, supporting docs |
| `tagback` | TagBack app development | Specs, mockups, code exports |
| `cloudmigration` | Cloud consolidation work | Migration plans, checklists |
| `portfolio` | Portfolio site development | Design files, content drafts |
| `infra` | Infra build-out (one-off) | Provisioning docs, deploy notes |
| `client` | Client project deliverables | Contracts, deliverables, invoices |
| `personal` | Personal one-off projects | Any bounded personal goal |

**Lifecycle Rule:** A file under `PROJECTS` that belongs to a completed project must be moved to `ARCHIVE-projects` within 30 days of project closure.

### 3.2 AREAS

**Definition:** Ongoing responsibilities with no end date. These recur indefinitely and require regular attention.

| Subcategory Slug | Description | Example Files |
|-----------------|-------------|---------------|
| `server` | Server ops and maintenance | Runbooks, configs, logs |
| `cloud` | Cloud account management | Invoices, usage reports |
| `photo` | Photography work | RAW photos, edits, delivery files |
| `finance` | Personal finances | Bank statements, tax docs |
| `health` | Health and wellness records | Medical records, prescriptions |
| `legal` | Legal documents | Contracts, agreements |
| `identity` | Identity and credentials | (Non-secret) ID scans, certificates |
| `network` | Network maintenance | Tailscale configs, WireGuard keys (public only) |

### 3.3 RESOURCES

**Definition:** Reference material with no active work. Consulted but not currently being produced.

| Subcategory Slug | Description | Example Files |
|-----------------|-------------|---------------|
| `templates` | Reusable file templates | Shell script stubs, doc templates |
| `scripts` | Utility shell scripts | Automation scripts, one-liners |
| `configs` | Configuration files | Baseline configs, example `.env` files |
| `docs` | Technical documentation | Vendor docs, man pages, API references |
| `media` | Reusable media assets | Stock photos, icons, audio clips |
| `training` | Learning materials | Course notes, tutorials, PDFs |
| `bookmarks` | Hookmark / URL archives | Exported link bundles |
| `tools` | Software tools and utilities | Installers, AppImages, binaries |

### 3.4 ARCHIVE

**Definition:** Inactive, completed, or deprecated material. No regular access expected. Read-only by convention.

| Subcategory Slug | Description | Example Files |
|-----------------|-------------|---------------|
| `projects` | Completed projects | Final deliverables, post-mortems |
| `areas` | Retired responsibilities | Closed accounts, past roles |
| `resources` | Deprecated resources | Old templates, superseded configs |
| `media` | Archived media from past work | Delivered photos, old reels |
| `correspondence` | Past email / message archives | Exported email threads |
| `finance` | Past financial records (>3 years) | Old tax returns, bank statements |

**Retention Rule:** Archive files are retained indefinitely unless a retention policy specifies otherwise. Files older than 7 years in `ARCHIVE-finance` may be purged after Shannon's manual review.

---

## 4. File Ingest Workflow — Stage by Stage

### Overview

```
[Source Device / Cloud / Manual Drop]
        |
        v
[STAGE 0: DROP ZONE]  ── ~/Inbox or cloud ingest folder
        |
        v
[STAGE 1: VALIDATE]   ── Naming check, type check, duplicate check
        |
        v
[STAGE 2: CLASSIFY]   ── PARA category assignment
        |
        v
[STAGE 3: RENAME]     ── Apply canonical filename (if needed)
        |
        v
[STAGE 4: METADATA]   ── Inject xattrs, sidecar .json, tags
        |
        v
[STAGE 5: ROUTE]      ── Copy to destination(s), verify checksum
        |
        v
[STAGE 6: AUDIT LOG]  ── Append to daily ingest log
        |
        v
[STAGE 7: CLEAN UP]   ── Remove from drop zone, archive original if needed
```

### 4.1 Stage 0 — Drop Zone

Every file ingest begins in a designated drop zone. Files placed here have no further action required from the user — the pipeline takes over.

| Drop Zone Path | Source | Notes |
|---------------|--------|-------|
| `~/Inbox/` | Mac local, Hazel-watched | Primary human ingest point |
| `~/Desktop/` | Mac local, Hazel-watched | Overflow from desktop saves |
| `~/Downloads/` | Browser downloads | Hazel watches, cleans on schedule |
| `/mnt/ingest/` | Nexus VPS local | Used by MCP and API-triggered ingest |
| `gdrive://Inbox/` | Google Drive | Synced to Nexus via MCP integration |
| `pcloud://Inbox/` | pCloud | Synced to Nexus via MCP integration |

**Rule:** Nothing lives in a drop zone for more than 24 hours. Files not processed within 24 hours are flagged in the audit log and routed to `RESOURCES-docs` with a `REVIEW-NEEDED` tag.

### 4.2 Stage 1 — Validate

The validator script (`validate-ingest.sh`) checks:

1. **Filename format** — Does it match the canonical regex?
2. **Extension safety** — Is the extension in the approved list (no `.exe`, `.dmg`, `.bat` without explicit override)?
3. **Duplicate check** — Does the UUID24 already exist in the ingest log?
4. **File integrity** — Is the file fully written (not still being copied)?
5. **Size threshold** — Files over 4 GB are flagged for manual large-file review before routing.

**On validation failure:** The file is moved to `~/Inbox/_FAILED/` and an entry is written to `~/Logs/ingest-failures.log` with the reason.

#### Approved Extension List (non-exhaustive)

| Category | Extensions |
|----------|-----------|
| Documents | `.pdf`, `.md`, `.txt`, `.docx`, `.pages`, `.rtf`, `.odt` |
| Spreadsheets | `.xlsx`, `.numbers`, `.csv`, `.ods` |
| Images | `.jpg`, `.jpeg`, `.png`, `.gif`, `.webp`, `.heic`, `.tiff` |
| RAW Photos | `.dng`, `.cr3`, `.cr2`, `.arw`, `.nef`, `.raf` |
| Video | `.mp4`, `.mov`, `.mkv`, `.m4v` |
| Audio | `.mp3`, `.flac`, `.aac`, `.wav`, `.m4a` |
| Code/Config | `.sh`, `.py`, `.js`, `.ts`, `.json`, `.yaml`, `.yml`, `.toml`, `.env.example` |
| Archives | `.zip`, `.tar`, `.tar.gz`, `.7z` |
| E-books | `.epub`, `.mobi` |

### 4.3 Stage 2 — Classify

Classification determines the PARA category and subcategory. Classification sources, checked in order:

1. **Folder context** — The drop zone subfolder the file was placed in (if user pre-sorts)
2. **Existing filename** — If the file already uses the canonical format, extract from it
3. **Hazel rule match** — One of the 11 PARA-based Hazel rules triggers on content/metadata
4. **AI classification** — MCP-invoked Claude call for ambiguous files (optional, enabled per setting)
5. **Default fallback** — `RESOURCES-docs` with `NEEDS-REVIEW` tag

### 4.4 Stage 3 — Rename

If the file does not already have a canonical filename, it is renamed:

```bash
# Pseudocode
DATE=$(get_creation_date "$FILE")    # from xattr com.apple.metadata:kMDItemContentCreationDate or mtime
TIME=$(get_creation_time "$FILE")
CATEGORY=$(classify_para "$FILE")    # from Stage 2
SUBCAT=$(resolve_subcategory "$CATEGORY" "$FILE")
DESC=$(slugify_original_name "$FILE" | cut -c1-60)
UUID=$(generate_uuid24)
EXT=$(echo "${FILE##*.}" | tr '[:upper:]' '[:lower:]')
NEW_NAME="${DATE}_${TIME}_${CATEGORY}-${SUBCAT}_${DESC}_${UUID}.${EXT}"
mv "$FILE" "$(dirname $FILE)/${NEW_NAME}"
```

**Idempotency rule:** If the same file (identical checksum) is re-ingested, it is skipped. UUID24 is NOT re-generated for already-renamed files.

### 4.5 Stage 4 — Metadata Injection

After renaming, metadata is injected from three angles:

#### a) macOS Extended Attributes (xattr)
Written by `tag-xattr.sh`:
```
com.shannonjlove.para.category    = PROJECTS
com.shannonjlove.para.subcategory = tagback
com.shannonjlove.ingest.date      = 2026-06-29T14:30:00Z
com.shannonjlove.uuid24           = a7k3m9p2x8nq4r6t5v1w0ybc
com.shannonjlove.checksum.sha256  = <sha256 hash>
```

#### b) macOS Finder Tags
Applied via the `tag` CLI:
- Primary PARA tag: `PROJECTS`, `AREAS`, `RESOURCES`, or `ARCHIVE`
- Subcategory tag: e.g. `tagback`, `server`, `templates`
- Status tag: `INGESTED`, `NEEDS-REVIEW`, or `FLAGGED`

#### c) Sidecar JSON
For files where xattr may not survive cloud sync, a sidecar `.json` file is generated alongside the original:
```json
{
  "sjl_uuid24": "a7k3m9p2x8nq4r6t5v1w0ybc",
  "sjl_para_category": "PROJECTS",
  "sjl_para_subcategory": "tagback",
  "sjl_ingest_date": "2026-06-29T14:30:00Z",
  "sjl_original_name": "tagback-spec-v2.pdf",
  "sjl_checksum_sha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
  "sjl_source_device": "shannonjlove-mac",
  "sjl_hookmark_link": ""
}
```

Sidecar files are named identically to the parent with `.meta.json` appended:
```
2026-06-29_14-30_PROJECTS-tagback_spec-v2_UUID24.pdf
2026-06-29_14-30_PROJECTS-tagback_spec-v2_UUID24.pdf.meta.json
```

### 4.6 Stage 5 — Route

The router (`route-file.sh`) copies the file to all applicable destinations based on the Storage Routing Matrix (Section 5). Routing is always copy-then-verify, never move-without-verify.

**Routing sequence:**
1. Copy file (and sidecar) to destination
2. Compute SHA-256 of destination copy
3. Compare against source checksum
4. On match: mark source as `ROUTED`, log entry written
5. On mismatch: retry once, then flag in audit log and alert

### 4.7 Stage 6 — Audit Log

Every processed file gets one line appended to the daily audit log:

```
~/Logs/ingest/YYYY-MM-DD-ingest.log
```

Format (tab-separated):
```
TIMESTAMP_UTC  UUID24  ORIGINAL_NAME  FINAL_NAME  PARA_CATEGORY  DESTINATION(S)  STATUS
```

Example:
```
2026-06-29T14:30:05Z  a7k3m9p2x8nq4r6t5v1w0ybc  tagback-spec-v2.pdf  2026-06-29_14-30_PROJECTS-tagback_spec-v2_a7k3m9p2x8nq4r6t5v1w0ybc.pdf  PROJECTS/tagback  local+gdrive+idrivee2  OK
```

### 4.8 Stage 7 — Drop Zone Cleanup

After successful routing:
- The drop zone copy is deleted (it is now in its canonical location)
- If the file was ingested from a cloud provider's Inbox folder, the source cloud copy is also moved to `Archive/Ingested/YYYY-MM/` within that provider

---

## 5. Storage Routing Matrix

### 5.1 Tier Definitions

| Tier | Label | Access Pattern | Providers |
|------|-------|---------------|-----------|
| Hot | Local + Sync | Daily access | Mac local, Google Drive |
| Warm | Nexus/sOs | Weekly access | Nexus VPS, sOs Oracle |
| Cold | Object Storage | Archival | iDrive E2 (S3-compatible) |

### 5.2 Routing Table

| PARA Category | Hot (Local) | Hot (Cloud Sync) | Warm (Server) | Cold (S3) |
|--------------|-------------|-----------------|---------------|-----------|
| `PROJECTS-*` | YES | Google Drive | Nexus `/data/projects/` | iDrive E2 `projects/` prefix |
| `AREAS-server` | YES | NO | Nexus + sOs | iDrive E2 `areas/server/` |
| `AREAS-photo` | YES | pCloud (RAW) | sOs PhotoPrism | iDrive E2 `areas/photo/` |
| `AREAS-finance` | YES | NO | Nexus (encrypted) | iDrive E2 `areas/finance/` |
| `AREAS-*` (other) | YES | Google Drive | Nexus | iDrive E2 `areas/` |
| `RESOURCES-*` | YES | Google Drive | Nexus `/data/resources/` | iDrive E2 `resources/` |
| `ARCHIVE-*` | NO | NO | Nexus cold path | iDrive E2 `archive/` |

### 5.3 Special Routing Rules

**RAW Photos (`AREAS-photo` with `.dng`, `.cr3`, etc.):**
- Primary: pCloud (native app sync for iOS access)
- Secondary: sOs PhotoPrism (auto-indexed on arrival)
- Archive: iDrive E2 `areas/photo/raw/YYYY/`
- Local copy retained only until confirmation of two remote copies

**Finance and Legal (`AREAS-finance`, `AREAS-legal`):**
- NOT routed to any sync folder (Google Drive, pCloud)
- Nexus storage only (encrypted at rest via filesystem encryption)
- iDrive E2 with server-side encryption enabled
- Local copy encrypted with FileVault

**Server configs (`AREAS-server`):**
- Nexus AND sOs (both nodes)
- NOT to Google Drive (may contain sensitive path info)
- iDrive E2 `areas/server/` as cold backup

**Large files (>500 MB):**
- Skip local hot storage
- Route directly to appropriate Nexus path
- Cold-copy to iDrive E2
- Log with `LARGE-FILE` tag in audit log

---

## 6. Automation Layer Reference

### 6.1 Hazel Rules (11 Rules)

Hazel runs on the Mac and watches the drop zone folders. Rules fire in order; first match wins.

| Rule # | Rule Name | Trigger Condition | Action |
|--------|-----------|------------------|--------|
| 1 | `para-inbox-rename` | Any file in `~/Inbox` without canonical name | Run `rename-ingest.sh` |
| 2 | `para-projects-route` | Filename contains `_PROJECTS-` | Move to `~/PARA/Projects/` + run `route-file.sh` |
| 3 | `para-areas-route` | Filename contains `_AREAS-` | Move to `~/PARA/Areas/` + run `route-file.sh` |
| 4 | `para-resources-route` | Filename contains `_RESOURCES-` | Move to `~/PARA/Resources/` + run `route-file.sh` |
| 5 | `para-archive-route` | Filename contains `_ARCHIVE-` | Move to `~/PARA/Archive/` + run `route-file.sh` |
| 6 | `media-raw-photo` | Extension is `.dng`, `.cr3`, `.arw`, `.nef` | Apply `AREAS-photo` tag, route to pCloud |
| 7 | `pdf-document-classify` | Extension is `.pdf` + no PARA tag | Run AI classifier, apply tag, re-queue |
| 8 | `downloads-auto-clean` | File in `~/Downloads` older than 48h | Move to `~/Inbox` for processing |
| 9 | `duplicate-detect` | UUID24 already in ingest log | Move to `~/Inbox/_DUPLICATES/` |
| 10 | `failed-flag` | File in `_FAILED` older than 7 days | Notify via log, move to `RESOURCES-docs` with `NEEDS-REVIEW` |
| 11 | `stale-inbox-alert` | File in `~/Inbox` older than 24h unprocessed | Write to `ingest-failures.log` |

### 6.2 Shell Scripts (8 Scripts)

All scripts live in `scripts/` or `03-AUTOMATION/file-routing/scripts/`.

| Script | Purpose | Invoked By |
|--------|---------|-----------|
| `validate-ingest.sh` | Stage 1 validator — checks naming, extension, duplicates | Hazel Rule 1 |
| `rename-ingest.sh` | Stage 3 renamer — applies canonical format | Hazel Rule 1 |
| `tag-xattr.sh` | Stage 4 — writes xattr metadata and Finder tags | rename-ingest.sh |
| `generate-sidecar.sh` | Stage 4 — writes `.meta.json` sidecar | rename-ingest.sh |
| `route-file.sh` | Stage 5 — copies to all tier destinations, verifies checksum | Hazel Rules 2–5 |
| `audit-log.sh` | Stage 6 — appends to daily ingest log | route-file.sh |
| `generate-uuid24.sh` | UUID24 generator helper | rename-ingest.sh |
| `cleanup-dropzone.sh` | Stage 7 — removes drop zone originals after verified routing | route-file.sh |

### 6.3 UUID24 Generation

```bash
#!/usr/bin/env bash
# generate-uuid24.sh — generates a 24-char lowercase alphanumeric UUID
generate_uuid24() {
    cat /dev/urandom | LC_ALL=C tr -dc 'a-z0-9' | head -c 24
}
generate_uuid24
```

### 6.4 LaunchAgent Schedule

LaunchAgents on the Mac run scripts on schedule to catch files that escape event-based triggers.

| LaunchAgent Label | Script | Schedule | Purpose |
|------------------|--------|----------|---------|
| `cloud.shannonjlove.ingest.inbox` | `rename-ingest.sh` | Every 5 min | Catch new inbox files |
| `cloud.shannonjlove.ingest.downloads` | `cleanup-dropzone.sh` | Every 15 min | Process Downloads |
| `cloud.shannonjlove.ingest.route` | `route-file.sh` | Every 30 min | Route renamed files |
| `cloud.shannonjlove.ingest.audit` | `audit-log.sh` | Daily 02:00 | Daily log rollup |
| `cloud.shannonjlove.ingest.cloud-pull` | `pull-cloud-inboxes.sh` | Every 60 min | Pull from gdrive/pcloud Inbox |

### 6.5 MCP Cloud Integration Points

MCP servers enable cloud provider integration from within Claude Code and automation workflows.

| MCP Server | Role in Ingest | Ingest Trigger |
|-----------|----------------|----------------|
| Google Drive MCP | Pull from `gdrive://Inbox/`, push routed files | LaunchAgent every 60 min |
| pCloud MCP | Pull from `pcloud://Inbox/`, push RAW photos | LaunchAgent every 60 min |
| Backblaze MCP | Cold backup of routed files | Post-route hook |
| iDrive E2 (rclone) | S3-compatible cold storage target | `route-file.sh` Stage 5 |

---

## 7. Metadata & Tagging Standards

### 7.1 xattr Keys (Extended Attributes)

All keys use the `com.shannonjlove.` namespace.

| xattr Key | Type | Description |
|-----------|------|-------------|
| `com.shannonjlove.para.category` | string | One of: PROJECTS, AREAS, RESOURCES, ARCHIVE |
| `com.shannonjlove.para.subcategory` | string | Subcategory slug (see Section 3) |
| `com.shannonjlove.ingest.date` | ISO 8601 | UTC datetime of ingest pipeline processing |
| `com.shannonjlove.uuid24` | string | The UUID24 from the canonical filename |
| `com.shannonjlove.checksum.sha256` | hex string | SHA-256 of file contents at ingest |
| `com.shannonjlove.source.device` | string | Hostname of originating device |
| `com.shannonjlove.hookmark.link` | string | Hookmark deep link (populated on first Hookmark use) |
| `com.shannonjlove.version` | integer | Version counter, starts at 1 |
| `com.shannonjlove.review.needed` | boolean | Set to `1` if NEEDS-REVIEW flagged |

### 7.2 Finder Tag Vocabulary

Finder tags serve as the fast visual layer. All tags are defined here — no ad-hoc tags.

**PARA Tags (mutually exclusive, one required):**
- `PROJECTS` (red)
- `AREAS` (orange)
- `RESOURCES` (blue)
- `ARCHIVE` (gray)

**Status Tags (zero or more):**
- `INGESTED` (green) — successfully processed
- `NEEDS-REVIEW` (yellow) — classification uncertain
- `FLAGGED` (red) — validation failure, requires manual attention
- `LARGE-FILE` (purple) — over 500 MB
- `ENCRYPTED` (gray) — encrypted at rest

**Subcategory Tags (one, matching the subcategory field):**
- Applied verbatim from the subcategory slug: `tagback`, `server`, `photo`, etc.

### 7.3 Hookmark Integration

Hookmark links are created for files in `PROJECTS-*` and `AREAS-*` automatically. The Hookmark link is:
- Written to `com.shannonjlove.hookmark.link` xattr
- Added to the sidecar `.meta.json`
- Survives file moves within the local filesystem (Hookmark tracks by UUID24 in the filename)

For cloud-synced files, the Hookmark link remains valid as long as the local copy exists. When a local copy is removed (archive-only files), the Hookmark link is marked `CLOUD-ONLY` in the sidecar.

---

## 8. Cloud Provider Roles & Ingest Endpoints

### 8.1 Provider Role Summary

| Provider | Primary Role | Ingest Inbox Path | Notes |
|----------|-------------|------------------|-------|
| Google Drive | Hot sync for PROJECTS + AREAS + RESOURCES | `gdrive://SJL-Cloud/Inbox/` | MCP-accessible |
| pCloud | RAW photo sync + personal backup | `pcloud://Inbox/` | MCP-accessible |
| iDrive E2 | Cold S3-compatible object storage | S3 bucket via rclone | PARA-structured prefixes |
| Backblaze B2 | Cold backup mirror | B2 bucket via rclone | Mirror of iDrive E2 |
| AWS S3 | Supplemental / app-specific storage | Governed per service | Not general ingest |
| GCP GCS | Supplemental / app-specific storage | Governed per service | Not general ingest |

### 8.2 iDrive E2 Bucket Structure

```
sjl-cloud-vault/
├── projects/
│   ├── tagback/
│   ├── fellowship/
│   └── ...
├── areas/
│   ├── server/
│   ├── photo/
│   │   ├── raw/
│   │   │   └── YYYY/
│   │   └── delivered/
│   ├── finance/
│   └── ...
├── resources/
│   ├── templates/
│   ├── scripts/
│   └── ...
└── archive/
    ├── projects/
    ├── areas/
    ├── YYYY/     (year-partitioned for large archives)
    └── ...
```

### 8.3 Google Drive Folder Structure

```
SJL-Cloud/
├── Inbox/             ← drop zone (pulled every 60 min)
├── PROJECTS/
│   ├── tagback/
│   ├── fellowship/
│   └── ...
├── AREAS/
│   ├── server/
│   └── ...
├── RESOURCES/
│   ├── templates/
│   └── ...
└── ARCHIVE/           ← read-only by convention
```

---

## 9. Governance, Exceptions & Change Control

### 9.1 Rule Authority

This manual is authoritative. Any deviation from naming conventions, routing rules, or metadata standards requires a documented exception (Section 9.3) or a formal change (Section 9.4).

### 9.2 Who Can Trigger Ingest

| Actor | Method | Authorization |
|-------|--------|--------------|
| Shannon (human) | Drop file in watch folder | Always authorized |
| Hazel | Event-based automation | Governed by this manual |
| LaunchAgent scripts | Scheduled runs | Governed by this manual |
| MCP server actions | API-triggered ingest | Requires explicit Claude Code session |
| External webhooks | Via Nexus ingest endpoint | Requires API key + source allowlist |

### 9.3 Exception Process

An exception is required when:
- A file cannot be named per the convention (e.g. a system export with a required fixed name)
- A file must go to a non-standard destination
- A PARA category assignment is genuinely ambiguous

**Exception procedure:**
1. Place the file in `~/Inbox/_EXCEPTIONS/` with a companion `*.exception.txt` describing the reason
2. The exception file will be manually reviewed and routed
3. A record is kept in `~/Logs/ingest/exceptions.log`

### 9.4 Change Control for Pipeline Modifications

Any change to this manual, the routing matrix, Hazel rules, shell scripts, or LaunchAgents requires:

1. Create an approval request:
   ```bash
   bash 06-OPS/request-approval.sh "File Ingest Pipeline Change" "Brief description"
   ```
2. Fill in the risk level, proposed actions, and rollback plan in the generated file
3. Mark `[ ] Approved by Shannon` before deploying
4. Update this manual's **Last Updated** date and the relevant section
5. Commit the change to the repo on the appropriate branch

**Risk level guidelines:**
- **Low:** Updating description text, adding a subcategory slug (no behavioral change)
- **Medium:** Adding a new Hazel rule, changing routing for one subcategory
- **High:** Changing the canonical filename format, altering the UUID24 algorithm, routing finance/legal files to a new destination

### 9.5 Annual Review

This manual is reviewed annually each January. The review covers:
- Subcategory list relevance (add/remove)
- Routing matrix accuracy (provider changes)
- Storage tier costs and efficiency
- Exception log patterns (recurring exceptions indicate a rule gap)

---

## 10. Audit & Compliance

### 10.1 Log Locations

| Log | Path | Retention |
|-----|------|-----------|
| Daily ingest log | `~/Logs/ingest/YYYY-MM-DD-ingest.log` | 1 year rolling |
| Failure log | `~/Logs/ingest/ingest-failures.log` | 90 days rolling |
| Exception log | `~/Logs/ingest/exceptions.log` | Indefinite |
| Routing verification log | `~/Logs/ingest/route-verify.log` | 30 days rolling |

All logs are also synced to Nexus at `/var/log/sjl-ingest/` via nightly rclone.

### 10.2 What the Audit Log Proves

The daily ingest log provides:
- When a file entered the system (UTC timestamp)
- What it was called originally
- What it became after canonical renaming
- Which PARA category and subcategory it was assigned
- Where it was routed (all destinations)
- Whether checksums matched (integrity)

This log is the authoritative record for dispute resolution (e.g. "when did this document arrive?") and for recovery after data loss.

### 10.3 Checksum Verification

SHA-256 checksums are:
- Computed at Stage 4 (before any copy)
- Re-verified after every copy (Stage 5)
- Stored in xattr and sidecar
- Re-verifiable at any time via:
  ```bash
  sha256sum <filename>
  # Compare against com.shannonjlove.checksum.sha256 xattr
  ```

### 10.4 Duplicate Detection

A UUID24 is globally unique across the estate. The ingest log serves as the UUID registry.

To check if a UUID24 already exists:
```bash
grep "UUID24_VALUE" ~/Logs/ingest/*.log
```

If a UUID24 collision is detected (theoretically ~10^43 probability for 24 alphanumeric chars), both files are placed in `~/Inbox/_DUPLICATES/` and flagged.

---

## 11. Quick Reference

### 11.1 Naming Convention Cheatsheet

```
YYYY-MM-DD_HH-MM_CATEGORY-subcategory_description_UUID24.ext
│          │      │        │           │            │
│          │      │        │           │            └── lowercase original ext
│          │      │        │           └── 60-char lowercase hyphen-slug
│          │      │        └── lowercase slug from taxonomy
│          │      └── PROJECTS | AREAS | RESOURCES | ARCHIVE
│          └── 24-hour time, hyphen-separated
└── ISO 8601 date

Example:
2026-06-29_14-30_AREAS-server_traefik-ssl-renewed_k9m4p2x7q8nw3r5t1v0ybc6j.md
```

### 11.2 PARA Category Quick Lookup

| If the file is... | Use category |
|------------------|-------------|
| Part of a project I'm actively working on | `PROJECTS-<project>` |
| An ongoing responsibility (no end date) | `AREAS-<area>` |
| Reference material I consult | `RESOURCES-<type>` |
| Done, deprecated, or historical | `ARCHIVE-<original>` |

### 11.3 Common Script Invocations

```bash
# Manually ingest a single file
bash scripts/rename-ingest.sh ~/Desktop/my-document.pdf

# Manually route an already-renamed file
bash scripts/route-file.sh 2026-06-29_14-30_PROJECTS-tagback_spec-v2_UUID24.pdf

# Generate a UUID24
bash scripts/generate-uuid24.sh

# Check ingest log for today
cat ~/Logs/ingest/$(date +%Y-%m-%d)-ingest.log

# Re-run xattr tagging on a file
bash scripts/tag-xattr.sh <filename> PROJECTS tagback

# Request a pipeline change approval
bash 06-OPS/request-approval.sh "Pipeline Change" "Description of change"
```

### 11.4 Troubleshooting Quick Guide

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| File stuck in `~/Inbox` > 24h | Hazel not running or rule mismatch | Check Hazel preferences, re-apply rules |
| File in `_FAILED/` | Name validation failure | Check `ingest-failures.log`, rename manually |
| File in `_DUPLICATES/` | UUID24 already seen | Verify if true duplicate; delete or re-UUID |
| xattr missing after cloud sync | Provider stripped xattr | Re-run `tag-xattr.sh`, check sidecar `.meta.json` |
| Routing checksum mismatch | Network interruption during copy | Re-run `route-file.sh`, check disk health |
| LaunchAgent not firing | Plist unloaded or macOS permission | Run `launchctl list | grep shannonjlove`, reload plist |

---

*This document is version-controlled in the Hybrid Personal Cloud Server Infrastructure repository.*  
*Change log: see `git log 05-DOCS/file-ingest-governance.md`*
