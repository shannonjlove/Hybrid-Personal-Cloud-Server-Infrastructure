# Infrastructure Map

## Server Inventory

### Hostinger VPS — Nexus Server
- **Role**: Primary container host
- **URL**: nexus.shannonjlove.cloud
- **Reverse Proxy**: Traefik (Docker) — routes to both Docker containers and Podman services
- **Docker containers**: PhotoPrism, BookStack
- **Podman Quadlets (systemd)**: Paperless-NGX (+ broker, db, gotenberg, tika)
- **Admin**: admin.shannonjlove.cloud

#### Services

| Service | URL | Runtime | Notes |
|---------|-----|---------|-------|
| Paperless-NGX | paperless.shannonjlove.cloud | Podman Quadlet | Document archive, PARA-tagged |
| BookStack | docs.shannonjlove.cloud | Docker | Knowledge base |
| PhotoPrism | photos.shannonjlove.cloud | Docker | Photo management |
| Traefik | — | Docker | Reverse proxy + SSL (Let's Encrypt) |

### Oracle Cloud — sOs Instance
- **Role**: ARM compute, secondary workloads
- **Region**: us-ashburn-1
- **IP**: 150.136.77.26
- **Tailscale IP**: 100.67.229.94
- **SSH**: `ssh ubuntu@sOs` (via Tailscale)

### AWS
- **Role**: Supplemental services
- **Status**: Active

### GCP
- **Role**: Supplemental services
- **Status**: Active

## Network Topology

All servers connected via Tailscale mesh VPN (5 devices):
- `sOs` (Oracle Cloud)
- `gclove-server-vm-instance`
- `ip-172-31-38-121` (AWS)
- `shajes-iphone`
- `shannonjlove` (Mac)

## Domain Architecture

All services use `shannonjlove.cloud` with subdomains:
- `paperless.shannonjlove.cloud` — Paperless-NGX document archive
- `docs.shannonjlove.cloud` — BookStack
- `photos.shannonjlove.cloud` — PhotoPrism
- `admin.shannonjlove.cloud` — Admin panel
- `nexus.shannonjlove.cloud` — Nexus VPS

---
*Last updated: February 2026*
