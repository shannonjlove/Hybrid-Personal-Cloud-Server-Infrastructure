# Full System Manual

Comprehensive operational reference for the Hybrid Personal Cloud Server Infrastructure.

## Table of Contents

1. [System Architecture](#system-architecture)
2. [Server Access](#server-access)
3. [Container Management](#container-management)
4. [Networking](#networking)
5. [Automation Tools](#automation-tools)
6. [Backup & Recovery](#backup--recovery)
7. [Monitoring](#monitoring)
8. [Maintenance Procedures](#maintenance-procedures)

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

## Automation Tools

### File Warden

Organizes files into PARA-aware category folders and applies xattr metadata tags.
Repairs Node.js/npm environment conflicts on Ubuntu/Debian.

```bash
# Entry point
bash 03-AUTOMATION/file-warden/file-warden.sh <subcommand> [options]

# Subcommands: organize | fix-node | status
```

> Full documentation: `docs/bookstack/file-warden-overview.md`
> Source: `03-AUTOMATION/file-warden/`

### TreeCopy

Enhanced `tree` command with color output, JSON export, and directory structure replication.

```bash
python3 scripts/treecopy.py [directory] [options]
```

> Full documentation: `docs/bookstack/treecopy-overview.md`
> Source: `scripts/treecopy.py`

---

## Backup & Recovery

*To be documented.*

## Monitoring

*To be documented.*

## Maintenance Procedures

*To be documented.*

---
*Last updated: February 2026*