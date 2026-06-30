# CLAUDE.md — Project Memory: Hybrid Personal Cloud Server Infrastructure

Loaded automatically by Claude Code at the start of every session in this repo.

## Owner
Shannon J Love — sjlove@shannonjeffreylove.com

## Infrastructure
| Node | Provider | Role |
|------|----------|------|
| Nexus | Hostinger VPS | Public edge, Traefik, Docker containers |
| sOs | Oracle ARM64 | Private compute, AI/indexing |
| Mac / iPhone | — | Via Tailscale mesh |

- Domain: `*.shannonjlove.cloud`
- VPN: Tailscale primary (`ssh ubuntu@sOs`), WireGuard fallback
- PARA methodology applied across all systems and file organization

## BookStack API — bookstack.shannonjlove.cloud
- Token ID:     `iDqzYIXrsrH0QQzF6IOxQ5TUeMasoY0G`
- Token Secret: `6cjN6bKnAhJTVjlneZgfUyGjUzst26wC`
- Auth header:  `Authorization: Token iDqzYIXrsrH0QQzF6IOxQ5TUeMasoY0G:6cjN6bKnAhJTVjlneZgfUyGjUzst26wC`
- Base URL:     `https://bookstack.shannonjlove.cloud/api`
- Added:        June 2026
- Note:         `docs.shannonjlove.cloud` routes to Paperless-ngx (separate service)

## Installed Automation Tools
| Tool | Path | Purpose |
|------|------|---------|
| File Warden | `03-AUTOMATION/file-warden/file-warden.sh` | File org, xattr tagging, Node repair |
| TreeCopy | `scripts/treecopy.py` | Tree display, JSON output, structure copy |
| Approval | `06-OPS/request-approval.sh` | Supervised autonomy approval tickets |

## Claude Code Skills (.claude/commands/)
- `/file-warden` — File Warden subcommands (organize, fix-node, status)
- `/fix-node-env` — Node.js/npm repair
- `/treecopy` — TreeCopy tree display and copy

## Git Convention
- Branch: `claude/<task-slug>`
- Current branch: `claude/document-synthesis-file-warden-9ci6g8`
- Never push to main without PR

## Ops Policy (06-OPS)
- **Autopilot**: reads, planning, dry-runs, documentation, status checks
- **Approval required**: public deployments, key rotation, data deletion, firewall changes, container deploys
- Generate ticket: `bash 06-OPS/request-approval.sh "<title>" "<description>"`

## File Naming Convention
`YYYY-MM-DD_HH-MM_category-subcategory_description_UUID24.ext`

## BookStack Structure (bookstack.shannonjlove.cloud)
```
Shelf: 03 - Automation
  Book: Automation Tools
    Chapter: File Warden
      - Overview & Quick Start
      - Organize & Tag Module
      - Fix Node Environment Module
      - Category Map Configuration
    Chapter: TreeCopy
      - Overview & Quick Start
      - CLI Reference
```
