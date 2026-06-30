# System Overview — SJL Sovereign Cloud v8.0

> **Last updated: 2026-06-29 (v8.0)**
> Canonical reference: `00-MASTER-ARCHITECTURE/v8/070000_2026-06-29__SJL-CLOUD-MASTER-MANUAL__sovereign-cloud-complete-reference__v8-0.md`

## Hybrid Personal Cloud Server Infrastructure

A self-hosted sovereign cloud spanning two active nodes — Hostinger VPS (Nexus) and Oracle Cloud ARM64 (sOs) — unified through Tailscale mesh networking, rootless Podman Quadlets managed by GNU Stow, Nginx Proxy Manager for TLS termination, and a six-digit PARA-based file governance system.

## Design Principles

- **Self-Hosted First:** All personal data under direct control
- **Two-Node Architecture:** Nexus (public edge + orchestration) · sOs (private ARM64 compute worker only)
- **Podman Quadlets:** All services run as individual systemd units via Quadlet files — no Docker Compose, no Traefik, no Caddy
- **GNU Stow Deployment:** Single-command deploy and rollback via symlink management
- **PARA Governance:** Six-digit codes (010000–090000) across all files, containers, and services
- **Discovery Before Write:** Discovery script mandatory before any configuration change
- **Zero-storage Servers:** Durable data lives in iDrive E2 (11 PARA-organized S3 buckets)

## Active Nodes

| Node | Provider | Public IP | Tailscale IP | Role |
|------|---------|-----------|-------------|------|
| **Nexus** | Hostinger KVM | 72.61.74.250 | 100.115.66.75 | Public edge, orchestration, system of record |
| **sOs** | Oracle Cloud (Always Free) | none | 100.67.229.94 | Private ARM64 compute worker |

## Core Components

| Layer | Purpose | Implementation |
|-------|---------|---------------|
| Compute | Container hosting | rootless Podman + systemd Quadlets |
| Deployment | Service lifecycle | GNU Stow symlink packages |
| Reverse Proxy | TLS + subdomain routing | **Nginx Proxy Manager** (sjl-npm container) |
| Networking | Zero-trust mesh | Tailscale + WireGuard failover |
| Automation | Workflows | n8n (Nexus main + sOs worker) |
| Document Archive | Knowledge + indexing | PaperParrot (Paperless-NGX) + BookStack |
| File Governance | Metadata, versioning, mirroring | FileWarden v2 pipeline (spec; impl pending) |
| Cloud Storage | Primary + redundancy | iDrive E2 (primary), B2, pCloud, GDrive |
| MCP Fleet | Claude Code cloud access + persistent memory | 7 FastMCP HTTP servers + basic-memory (stdio) |
| Monitoring | Health + alerting | Uptime Kuma + n8n alert routing |

## NOT Used (Explicitly Removed in v8.0)

- ~~Traefik~~ — eliminated; never deployed on current stack; NPM is the confirmed live reverse proxy
- ~~Caddy~~ — eliminated; never deployed
- ~~Docker Compose stacks~~ — superseded by Podman Quadlets; `~/npm-stack/` (Docker) kept stopped on Nexus only as a legacy artifact, never started
- ~~AWS / GCP~~ — historical supplemental nodes; not in active two-node architecture

## Domain

All services: `*.shannonjlove.cloud` → 72.61.74.250 (Cloudflare DNS)

See `00-MASTER-ARCHITECTURE/v8/` for the complete v8.0 reference manual, diagrams, and ingest workflow.
