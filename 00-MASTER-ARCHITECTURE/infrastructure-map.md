# Infrastructure Map

## Server Inventory

### Hostinger VPS — Nexus Server
- **Role**: Primary container host
- **URL**: nexus.shannonjlove.cloud
- **Reverse Proxy**: Traefik
- **Containers**: Paperless-ngx, PhotoPrism, Jellyfin, BookStack, and more
- **Admin**: admin.shannonjlove.cloud

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

| Subdomain | Service | Status |
|-----------|---------|--------|
| `nexus.shannonjlove.cloud` | Nexus VPS (Hostinger) | Active |
| `admin.shannonjlove.cloud` | Admin Panel | Active |
| `docs.shannonjlove.cloud` | BookStack — Knowledge Base | Active |
| `photos.shannonjlove.cloud` | PhotoPrism — Photo Library | Active |
| `paperless.shannonjlove.cloud` | Paperless-ngx — Documents | Planned |
| `media.shannonjlove.cloud` | Jellyfin — Media Server | Planned |
| `stash.shannonjlove.cloud` | Stash — Media Library | Planned |

All routes managed by Traefik reverse proxy with Let's Encrypt SSL.

---
*Last updated: July 2026*
