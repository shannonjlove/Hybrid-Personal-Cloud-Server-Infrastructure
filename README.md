# Hybrid Personal Cloud Server Infrastructure (SJL)

This repo is the operational blueprint for Shannon J. Love’s hybrid cloud infrastructure: a secure, metadata-driven, automation-first system spanning a public edge VPS (Nexus) and a private ARM compute node (sOs), with S3-compatible object storage as the long-term vault.

## Core Roles

### Nexus (Hostinger VPS) — Public Edge / Ingress
- Primary public-facing node
- Traefik reverse proxy on 80/443
- Hosts the portfolio + routing layer + “front door” services
- Only node that should expose services to the public internet

### sOs (Oracle ARM64) — Private Compute / “The Brain”
- ARM64 compute for AI, indexing, recognition, automation workers
- Not publicly exposed
- Accessed over Tailscale (preferred)

### Storage Layer (S3-compatible: iDrive E2 / similar)
- Long-term vault for assets, archives, backups
- PARA-structured buckets / prefixes
- Designed for portability across providers

## Networking (Tailscale-First)
- Tailscale is the default mesh networking layer (MagicDNS recommended)
- WireGuard retained only as failover / emergency access
- Goal: everything private by default, public only via Nexus + Traefik

## Container Runtime
- Podman + podman-compose
- Podman socket is used for Traefik provider discovery where required

## Repo Layout (PARA-aligned)
- `00-MASTER-ARCHITECTURE/` — system overview, infra map, PARA structure
- `01-DEPLOYMENT/` — node provisioning (Hostinger, Oracle, AWS, GCP)
- `02-CONTAINERS/` — service modules (Traefik, BookStack, PhotoPrism, Stash, MCP servers)
- `03-AUTOMATION/` — tagging, routing, metadata persistence, versioning
- `04-SECURITY/` — Tailscale, WireGuard failover, secrets management
- `05-DOCS/` — full manual + troubleshooting

## Quickstart (Nexus)
1. Bring up Traefik first
2. Attach services to `sjl_net`
3. Route public traffic via Traefik labels
4. Keep secrets in `.env` (never committed)

## Security Rules (Non-negotiable)
- No secrets committed to git (API keys, SSH keys, auth tokens)
- `.env` is local-only
- Prefer private services behind Tailscale; publish only what must be public

## Troubleshooting
See:
- `05-DOCS/troubleshooting.md`

