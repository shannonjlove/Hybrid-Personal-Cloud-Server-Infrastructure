# Full System Manual — SJL Sovereign Cloud v8.0

> **NOTICE:** This file is a redirect stub. The canonical v8.0 manual is:
> `00-MASTER-ARCHITECTURE/v8/070000_2026-06-29__SJL-CLOUD-MASTER-MANUAL__sovereign-cloud-complete-reference__v8-0.md`
>
> **Do not edit this stub.** All updates go into the canonical file above.
> Last updated: 2026-06-29

---

## Quick Navigation

| Topic | File |
|---|---|
| Complete v8.0 Reference | `00-MASTER-ARCHITECTURE/v8/070000_2026-06-29__SJL-CLOUD-MASTER-MANUAL__sovereign-cloud-complete-reference__v8-0.md` |
| System Diagrams (10 Mermaid) | `diagrams/070000_2026-06-29__SJL-CLOUD-DIAGRAMS__system-flowcharts-and-architecture__v1-0.md` |
| File Ingest Workflow | `03-AUTOMATION/ingest-workflow/070000_2026-06-29__SJL-CLOUD-INGEST__file-ingest-to-storage-complete-workflow__v1-0.md` |
| System Infographic (PNG) | `diagrams/070000_2026-06-29__SJL-CLOUD-INFOGRAPHIC__sovereign-cloud-v8-poster__v1-0__e2fdac5b.png` |
| System Infographic (SVG) | `diagrams/070000_2026-06-29__SJL-CLOUD-INFOGRAPHIC__sovereign-cloud-v8-poster__v1-0__d9382ef7.svg` |
| BookStack Running Record | `05-DOCS/020000_2026-06-29__SJL-CLOUD-BOOKSTACK__running-record-v8-update__v1-1.md` |
| Infrastructure Map | `00-MASTER-ARCHITECTURE/infrastructure-map.md` |
| System Overview | `00-MASTER-ARCHITECTURE/system-overview.md` |

## What's New in v8.0

- **Runtime:** Podman Quadlets (47 unit files) + GNU Stow — no Docker Compose, no Traefik, no Caddy
- **Reverse proxy:** NPM (Nginx Proxy Manager) — sole TLS termination and routing authority
- **PARA:** Six-digit codes (010000–090000) — canonical as of 2026-06-28
- **MCP fleet:** 7 cloud storage servers (FastMCP HTTP) + basic-memory (stdio) for persistent Claude Code memory
- **File governance:** FileWarden v2 12-stage pipeline specification (implementation pending)
- **Ingest program map:** Every stage of file governance documented with which program executes each action
- **10 Mermaid diagrams:** Complete architecture, pipeline, metadata, subdomain, and classification flows

## Access Reference

```
# Nexus
ssh sjl@72.61.74.250          # public
ssh sjl@100.115.66.75         # Tailscale

# sOs (Tailscale only)
ssh sjl@100.67.229.94

# Service health checks
curl -fsS http://127.0.0.1:81          # NPM admin
curl -fsS http://127.0.0.1:6875/status # BookStack
curl -fsS http://127.0.0.1:8000        # PaperParrot
curl -fsS http://127.0.0.1:3001        # Uptime Kuma
```
