# Traefik

Reverse proxy and SSL termination for all containerized services on Nexus VPS.

## Role

- Automatic SSL certificate management (Let's Encrypt)
- HTTP-to-HTTPS redirect
- Dynamic container discovery via Docker labels
- Subdomain routing for *.shannonjlove.cloud

## Migration

Migrated from Caddy to Traefik for improved Docker integration and dynamic configuration.

## Files (Planned)

- `traefik.yml` — Static configuration
- `dynamic/` — Dynamic route configurations
- Docker Compose service definition

---
*No real credentials or private server details should be stored here.*
