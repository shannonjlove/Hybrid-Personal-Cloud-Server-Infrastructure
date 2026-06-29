# SJL Sovereign Cloud — BookStack Running Record Update
## Session Entry: 2026-06-29  ·  v8.0 Architecture Upgrade

**BookStack path:** SJL Sovereign Cloud → Implementation Passes → Running Record
**Update policy:** Append to existing page — never replace. This file is the append block for the 2026-06-29 session.
**DOCID:** SJL-CLOUD-RUNLOG-001 (persistent; entry appended to existing record)
**Entry type:** Major architecture revision + complete documentation rebuild

---

## 2026-06-29 — v8.0 Architecture Upgrade: Complete System Reference

| Field | Value |
|---|---|
| Operator | Shannon J. Love [Claude Code] |
| Nodes affected | Neither (artifacts only — no deployment this session) |
| PARA | 070000_SYSTEM-AUTOMATION |
| Git branch | `claude/sjl-sovereign-cloud-7-4-anvsn5` |
| Manual version | v8.0 (supersedes v7.3.1) |

---

### What Changed

#### 1. Complete manual rebuild — v7.3.1 → v8.0

**File:** `070000_2026-06-29__SJL-CLOUD-MASTER-MANUAL__sovereign-cloud-complete-reference__v8-0.md`

The manual was rebuilt from the ground up with the following structural changes:

**Removed from all documentation:**
- ~~Traefik~~ — never deployed; conflicted with live NPM Podman stack. Eliminated from all references.
- ~~Docker Compose stacks~~ — superseded by Podman Quadlets. Only legacy `~/npm-stack/` (Docker) remains on Nexus as a kept-stopped artifact. Zero new Docker Compose references.
- ~~Caddy~~ — never deployed. Removed from all architecture references.
- ~~AWS / GCP compute nodes~~ — historical supplemental nodes. Current active infrastructure is Nexus + sOs only.
- ~~Five-digit PARA codes as canonical~~ — now migration aliases only. All new work uses six-digit codes.

**Added:**
- Complete Podman Quadlet fleet specification (47 unit files: 21 containers + 5 networks + 21 volumes across both nodes)
- NPM (Nginx Proxy Manager) confirmed as sole reverse proxy — all subdomain routing documented
- GNU Stow deployment model fully specified with deploy + rollback commands
- 7 MCP cloud storage servers (pCloud, B2, MediaFire, MEGA, GDrive, iDrive E2, rclone) — build and registration instructions
- Six-digit PARA system (010000–090000) — canonical from 2026-06-28
- FileWarden v2 12-stage pipeline — interface specification
- HookVault — interface specification
- DiffForge — interface specification
- FetchWarden PRD — planning baseline (742000 family)
- Complete file ingest workflow: which program conducts which action at every stage
- Full subdomain map, container registry, volume registry, port map
- Git repository inventory and branching convention
- Permissions model (Class A/B/C/D operations)
- Nightly integrity verification specification

---

#### 2. System Diagrams — 10 Mermaid flowcharts

**File:** `070000_2026-06-29__SJL-CLOUD-DIAGRAMS__system-flowcharts-and-architecture__v1-0.md`

| Diagram | Title |
|---|---|
| 1 | Overall System Architecture (Nexus + sOs + cloud storage) |
| 2 | File Ingest Complete Workflow (12-stage FileWarden pipeline) |
| 3 | Six-Layer Metadata Authority Pyramid |
| 4 | Subdomain & NPM Routing Map |
| 5 | MCP Server Fleet Architecture |
| 6 | Quadlet Deployment via GNU Stow |
| 7 | HookVault Cross-System Links |
| 8 | File Versioning Decision Flow |
| 9 | n8n Automation Architecture (Nexus ↔ sOs) |
| 10 | PARA Six-Digit Classification Tree |

---

#### 3. File Ingest Workflow — Complete Program Map

**File:** `070000_2026-06-29__SJL-CLOUD-INGEST__file-ingest-to-storage-complete-workflow__v1-0.md`

Documents every stage of the file governance pipeline with:
- Which program/service executes each action
- Whether it runs on Nexus or sOs (ARM64)
- Python code contracts for each FileWarden stage
- Specific rclone commands for mirror + checksum verification
- BookStack API append call
- PaperParrot API post_document call
- Audit log structure
- Nightly integrity verification cron specification

---

#### 4. High-Resolution System Infographic

**Files:**
- `070000_2026-06-29__SJL-CLOUD-INFOGRAPHIC__sovereign-cloud-v8-poster__v1-0__e2fdac5b.png` (3840×5800, 300 DPI, 1.0 MB)
- `070000_2026-06-29__SJL-CLOUD-INFOGRAPHIC__sovereign-cloud-v8-poster__v1-0__e2fdac5b.pdf` (1.8 MB)

**SHA-8:** `e2fdac5b`

**Eight sections rendered:**
- A: Canonical filename pattern with field chips
- B: PARA six-digit namespace (9 codes, hex colors)
- C: Dual-node architecture (Nexus + sOs + Tailscale bridge)
- D: FileWarden 12-stage pipeline with fatal stage callouts
- E: Six-layer metadata authority pyramid
- F: Version bump decision table
- G: Subdomain map (9 subdomains, Tailscale-only marked)
- H: MCP fleet (7 servers) + Component architecture (FileWarden / HookVault / DiffForge / Mirror Registry)

---

### Deployment Status

⏳ **PENDING** — All prior Quadlet fleet artifacts (from 2026-06-21 pass) still pending deployment.

This session produced documentation and diagrams only. No changes applied to live servers.

---

### Acceptance Criteria Outstanding (Cumulative)

**From 2026-06-21 (original Quadlet pass):**
- [ ] Run discovery script on Nexus and sOs
- [ ] Create `/opt/secrets/*.env` files (14 files required)
- [ ] Run GNU Stow layout setup script
- [ ] Copy Quadlets into Stow packages and deploy
- [ ] Build 7 MCP container images from FastMCP source
- [ ] Register MCPs with Claude Code (`claude mcp add`)
- [ ] Build OCR/Vision worker (ARM64) on sOs
- [ ] Deploy sOs fleet

**From 2026-06-30 (six-digit PARA + FetchWarden PRD):**
- [ ] Confirm master live document committed to git
- [ ] Consume FetchWarden PRD into PaperParrot

**From this session (2026-06-29, v8.0):**
- [ ] Import this running record update into BookStack (append to Running Record page)
- [ ] Consume infographic PNG + PDF into PaperParrot consume dir
  - type: Infographic; tags: #sjl-sovereigncloud #automation #infra #v8
- [ ] Consume v8.0 manual into PaperParrot
  - type: ManualRevision; tags: #sjl-sovereigncloud #automation #infra #final
- [ ] Remove AAAA record for `bookstack.shannonjlove.cloud` (DNS conflict risk per §1.2)
- [ ] Resize sOs: 4 OCPU/24 GB → 2 OCPU/12 GB (pending Oracle quota for second VM)

---

### Files Produced This Session

| Canonical filename | PARA | Description | SHA-8 |
|---|---|---|---|
| `070000_2026-06-29__SJL-CLOUD-MASTER-MANUAL__sovereign-cloud-complete-reference__v8-0.md` | 070000 | Complete v8.0 system reference | — |
| `070000_2026-06-29__SJL-CLOUD-DIAGRAMS__system-flowcharts-and-architecture__v1-0.md` | 070000 | 10 Mermaid diagrams | — |
| `070000_2026-06-29__SJL-CLOUD-INGEST__file-ingest-to-storage-complete-workflow__v1-0.md` | 070000 | Ingest program map | — |
| `070000_2026-06-29__SJL-CLOUD-INFOGRAPHIC__sovereign-cloud-v8-poster__v1-0__e2fdac5b.png` | 070000 | High-res poster 3840×5800 | e2fdac5b |
| `070000_2026-06-29__SJL-CLOUD-INFOGRAPHIC__sovereign-cloud-v8-poster__v1-0__e2fdac5b.pdf` | 070000 | Poster PDF 300 DPI | e2fdac5b |
| `generate_infographic.py` | 070000 | Infographic generator source | — |

---

### Next Session Should Start With

1. **Run discovery script** on Nexus and sOs — compare against this document
2. **Create `/opt/secrets/*.env` files** — 14 files with real credentials
3. **Deploy Quadlet fleet** — Stow setup → copy units → deploy → verify
4. **Build MCP images** from FastMCP source — 7 servers
5. **Register MCPs** with Claude Code
6. **Import this running record entry** into BookStack

---

### PaperParrot Archival Queue (This Session)

Drop the following files into `/srv/sjl/010000_INBOX/010300_PAPERLESS-CONSUME/` after deployment:

```
070000_2026-06-29__SJL-CLOUD-INFOGRAPHIC__sovereign-cloud-v8-poster__v1-0__e2fdac5b.pdf
  → type: Infographic; tags: #sjl-sovereigncloud #v8 #automation #infra #visual

070000_2026-06-29__SJL-CLOUD-MASTER-MANUAL__sovereign-cloud-complete-reference__v8-0.md
  → type: ManualRevision; tags: #sjl-sovereigncloud #v8 #automation #infra #final
```
