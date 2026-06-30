# Nginx Proxy Manager

GUI-driven reverse proxy and SSL termination for all containerized services on Nexus VPS.

## Access

- **Admin UI**: `http://nexus.shannonjlove.cloud:81` (restrict to Tailscale in production)
- **Default credentials (first boot)**: `admin@example.com` / `changeme` — change immediately

## Role

- HTTP/HTTPS reverse proxy for all `*.shannonjlove.cloud` services
- Automatic SSL certificate management (Let's Encrypt)
- HTTP → HTTPS redirect per proxy host
- WebSocket support configurable per host

## Volumes

| Volume | Purpose |
|--------|---------|
| `npm-data` | NPM database, config, and proxy host definitions |
| `npm-letsencrypt` | Let's Encrypt certificates and keys |

## Ports

| Port | Purpose |
|------|---------|
| 80 | HTTP (redirect to HTTPS) |
| 443 | HTTPS |
| 81 | Admin UI |

## Adding a New Proxy Host (GUI)

1. Log into NPM admin UI → **Proxy Hosts** → **Add Proxy Host**
2. **Domain Names**: `service.shannonjlove.cloud`
3. **Forward Hostname**: container name or `127.0.0.1`
4. **Forward Port**: service port
5. **Websockets Support**: enable for KasmVNC / WebTop and streaming services
6. **SSL tab** → Request a new SSL certificate → Force SSL → Save

## Known Proxy Hosts

All hosts confirmed Online as of June 2026. Managed via NPM admin UI.

| Upstream | SSL | Notes |
|----------|-----|-------|
| bookstack:80 | Let's Encrypt | BookStack docs |
| bookstack-board.shannonjlove.cloud:80 | Let's Encrypt | BookStack board |
| 172.81.78.233:88 | HTTP Only | Internal — no SSL |
| 172.81.61.12:8000 | Let's Encrypt | |
| 195.88.61.9:765 | Let's Encrypt | |
| 195.88.2.8:8082 | Let's Encrypt | |
| sjl-frontpage-vnc:80697 | Let's Encrypt | VNC frontend container |
| local.containers.internal:80685 | Let's Encrypt | Internal container bridge |
| 195.88.68.75:500 | Let's Encrypt | |
| 195.88.2.132:3478 | Let's Encrypt | |
| sjl-oracle-voce:80005 | Let's Encrypt | Oracle voice service |
| 172.81.78.233:8787 | Let's Encrypt | |
| bitware.gpl:2312 | Let's Encrypt | |
| 195.88.3.7:8705 | Let's Encrypt | |
| 2103.87.226.88:3006 | Let's Encrypt | |

> Full subdomain list requires higher-resolution screenshot — domain column was blurred.

## Backup

NPM config is stored in the `npm-data` Docker volume.
Back it up with: `docker run --rm -v npm-data:/data -v $(pwd):/backup alpine tar czf /backup/npm-data-$(date +%Y%m%d).tar.gz /data`

---
*No real credentials or private server details should be stored here.*
