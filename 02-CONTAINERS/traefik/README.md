# ~~Traefik~~ — ELIMINATED IN v8.0

> **STATUS: ELIMINATED — 2026-06-29**
> Traefik was never deployed on the current SJL Sovereign Cloud stack.
> It has been removed from all architecture references.

## Replacement

**Nginx Proxy Manager (NPM)** is the confirmed, deployed reverse proxy.

- Container: `sjl-npm` (Podman Quadlet: `npm.container`)
- Image: `jc21/nginx-proxy-manager:latest`
- Ports: 80:80, 443:443, 81:81 (host-bound — privileged exception)
- Admin URL: `https://admin.shannonjlove.cloud` (port 81)
- TLS: Let's Encrypt auto-renew via NPM
- Subdomain routing: All `*.shannonjlove.cloud` proxy hosts configured in NPM UI

## Why Traefik Was Removed

1. NPM was already deployed and managing TLS for all live subdomains
2. Traefik requires Docker labels on containers — incompatible with the rootless Podman Quadlet model
3. Running both would create port 80/443 conflicts
4. NPM's web UI provides easier operational management without requiring container restarts for route changes

## Reference

See `00-MASTER-ARCHITECTURE/v8/070000_2026-06-29__SJL-CLOUD-MASTER-MANUAL__sovereign-cloud-complete-reference__v8-0.md` — Part 3 (Service Registry) and Part 4 (Subdomain Map).
