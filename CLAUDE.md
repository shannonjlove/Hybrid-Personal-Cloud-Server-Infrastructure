# CLAUDE.md — Shannon J. Love / shannonjlove.cloud Infrastructure

This file governs how Claude Code operates within this repository.

---

## PARA Prefix Rule — Non-Negotiable

**The six-digit PARA code MUST be the first field in every canonical filename.**

Current canonical format:
```
[PPPPPP]_YYYY-MM-DD__DOCID__semantic-title__vMAJOR-MINOR__sha8.ext
```

The PARA code is a six-digit classification using the [P][C][SS][NN] scheme.  
The nine root codes are: `010000` INBOX · `020000` PROJECTS · `030000` AREAS · `040000` RESOURCES · `050000` ARCHIVES · `060000` PRIVATE MEDIA · `070000` SYSTEM AUTOMATION · `080000` APPLICATION DATA · `090000` QUARANTINE.

**Full standard:** `00-MASTER-ARCHITECTURE/sjl-para-naming-master.md` — read it before touching any file naming, code assignment, or routing task.

---

## Critical Rules for Every Session

1. **Read the naming master first** (`00-MASTER-ARCHITECTURE/sjl-para-naming-master.md`) before any task involving file classification, naming, routing, or PARA code assignment.
2. **Never invent a PARA code.** All codes come from the Master Allocation Registry in §11 of the naming master. If no match exists, surface the gap — do not assign.
3. **Never bulk rename cloud files** (Google Drive, pCloud, iDrive E2) without an approved migration mapping and explicit permission.
4. **Keep the four components distinct:**
   - `PARA code` = lifecycle/location classification
   - `DOCID` = permanent artifact identity (never changes across versions)
   - `version` = content revision (`vMAJOR-MINOR`)
   - `sha8` = content-integrity fingerprint (first 8 hex chars of SHA-256)
5. **No secrets in git.** `.env` files, API keys, SSH private keys, and auth tokens are never committed.
6. **Change control.** Any modification to the ingest pipeline, routing rules, Hazel configurations, or this CLAUDE.md requires a `06-OPS/request-approval.sh` approval record before deployment.
7. **Feature branches only.** All work goes on a feature branch. Never push directly to `main`.

---

## Repository Layout (PARA-Aligned)

```
00-MASTER-ARCHITECTURE/   System overview, infra map, naming standard (READ FIRST)
01-DEPLOYMENT/            Node provisioning (Hostinger, Oracle, AWS, GCP)
02-CONTAINERS/            Service modules (Traefik, BookStack, PhotoPrism, Stash, MCP)
03-AUTOMATION/            File routing, auto-tagging, metadata persistence, versioning
04-SECURITY/              Tailscale, WireGuard failover, secrets management
05-DOCS/                  Full manuals, troubleshooting, ingest governance
06-OPS/                   Approvals, runbooks, operational scripts
```

## Key Infrastructure

| Node | Role | Access |
|------|------|--------|
| Nexus (Hostinger VPS) | Public edge, Traefik reverse proxy | SSH via Tailscale |
| sOs (Oracle ARM64) | Private compute, AI/indexing/automation | `ssh ubuntu@sOs` via Tailscale |
| iDrive E2 | Cold S3-compatible object storage | rclone / S3 API |

All services on `*.shannonjlove.cloud`.

## Ingest Governance

Full ingest workflow: `05-DOCS/file-ingest-governance.md`  
Naming convention master: `00-MASTER-ARCHITECTURE/sjl-para-naming-master.md`

---

*Last updated: 2026-06-30*
