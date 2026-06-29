# Infrastructure Map — SJL Sovereign Cloud v8.0

> **Last updated: 2026-06-29 (v8.0)**
> See full reference: `00-MASTER-ARCHITECTURE/v8/070000_2026-06-29__SJL-CLOUD-MASTER-MANUAL__sovereign-cloud-complete-reference__v8-0.md`

## Active Server Inventory

### Nexus — Hostinger VPS (Primary)

| Field | Value |
|---|---|
| Provider | Hostinger KVM2 |
| Public IP | 72.61.74.250 |
| Tailscale IP | 100.115.66.75 |
| SSH | `ssh sjl@72.61.74.250` or `ssh sjl@100.115.66.75` |
| OS | Ubuntu 24.04 LTS x86_64 |
| Specs | 4 vCPU / 16 GB RAM / 200 GB NVMe |
| Role | Public edge, TLS termination, orchestration, system of record |
| Runtime | rootless Podman + systemd Quadlets |
| Reverse Proxy | **Nginx Proxy Manager** (sjl-npm) — ports 80/443/81 |

**Services on Nexus (18 containers):**
NPM · Portainer · Uptime Kuma · BookStack (+ MariaDB) · PaperParrot (+ PostgreSQL + Redis + AI) · n8n · Tailscale · 7× MCP servers

### sOs — Oracle Cloud ARM64 (Private Compute)

| Field | Value |
|---|---|
| Provider | Oracle Cloud Always Free |
| Tailscale IP | 100.67.229.94 (only access path) |
| SSH | `ssh sjl@100.67.229.94` (via Tailscale) |
| OS | Ubuntu 22.04 LTS ARM64 |
| Specs | 4 OCPU / 24 GB RAM (pending resize to 2 OCPU / 12 GB) |
| Role | Private ARM64 compute worker — no public ingress |
| Storage | Block storage ONLY — no ephemeral local disk |
| Runtime | rootless Podman + systemd Quadlets |

**Services on sOs (3 containers):**
Tailscale · n8n Worker (queue mode) · OCR/Vision Worker (ARM64)

## Network Topology

```
PUBLIC INTERNET
  72.61.74.250  →  NPM (port 80/443)  →  all *.shannonjlove.cloud
  
TAILSCALE MESH (zero-trust, primary)
  Nexus (100.115.66.75)  ←→  sOs (100.67.229.94)
  + shajes-iphone  + shannonjlove (Mac)
  
WIREGUARD (10.10.10.0/24 — failover only)
  Nexus ←→ sOs
```

## Subdomain Map

| Subdomain | Service | Access |
|---|---|---|
| bookstack.shannonjlove.cloud | BookStack | Public via NPM |
| paperless.shannonjlove.cloud | PaperParrot | Public via NPM |
| n8n.shannonjlove.cloud | n8n | Public via NPM |
| status.shannonjlove.cloud | Uptime Kuma | Public via NPM |
| admin.shannonjlove.cloud | NPM admin | Public (auth required) |
| agent.shannonjlove.cloud | ops-agent / AI Brain | Public via NPM |
| mcp.shannonjlove.cloud | MCP gateway | Public |
| github-mcp.shannonjlove.cloud | GitHub MCP | HTTP 401 = correct |
| paperless-ai.shannonjlove.cloud | PaperParrot-AI | **Tailscale only** (100.115.66.75:3000) |

## Decommissioned / Not Used

| Item | Status | Notes |
|---|---|---|
| AWS compute | Removed from active arch | Historical only |
| GCP compute | Removed from active arch | Historical only |
| ~~Traefik~~ | **Eliminated** | Never deployed; NPM is reverse proxy |
| ~~Caddy~~ | **Eliminated** | Never deployed |
| ~~Docker Compose~~ | **Eliminated** | `~/npm-stack/` kept stopped on Nexus only |
| 5-digit PARA codes | Migration aliases only | All new work uses 6-digit codes |
