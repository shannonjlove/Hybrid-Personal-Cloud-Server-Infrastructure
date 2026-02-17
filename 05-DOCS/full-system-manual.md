# Full System Manual

Comprehensive operational reference for the Hybrid Personal Cloud Server Infrastructure.

## Table of Contents

1. [System Architecture](#system-architecture)
2. [Server Access](#server-access)
3. [Container Management](#container-management)
4. [Networking](#networking)
5. [Backup & Recovery](#backup--recovery)
6. [Monitoring](#monitoring)
7. [Maintenance Procedures](#maintenance-procedures)

## System Architecture

> See: `00-MASTER-ARCHITECTURE/system-overview.md` for full architecture details.

## Server Access

### Hostinger VPS (Nexus)
- Primary container host
- Access via Tailscale or direct SSH

### Oracle Cloud (sOs)
- ARM compute instance
- Primary SSH: `ssh -i ~/.ssh/oracle_rsa_new ubuntu@150.136.77.26`
- Tailscale: `ssh ubuntu@sOs`

### Domain
- All services: `*.shannonjlove.cloud`

## Container Management

All containers managed via Docker Compose on Nexus VPS with Traefik reverse proxy.

> See: `02-CONTAINERS/` for individual service configurations.

## Networking

Tailscale mesh VPN connects all 5 devices. WireGuard available as supplemental layer.

> See: `04-SECURITY/` for networking and VPN configurations.

## Backup & Recovery

*To be documented.*

## Monitoring

*To be documented.*

## Maintenance Procedures

*To be documented.*

---
*Last updated: February 2026*