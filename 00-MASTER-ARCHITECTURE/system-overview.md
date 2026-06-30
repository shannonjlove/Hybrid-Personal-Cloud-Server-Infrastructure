# System Overview

## Hybrid Personal Cloud Server Infrastructure

A self-hosted, multi-cloud personal infrastructure spanning Hostinger VPS (Nexus), Oracle Cloud (sOs), AWS, and GCP — unified through Tailscale mesh networking, Docker containerization, and PARA-based digital organization.

### Design Principles

- **Self-Hosted First**: All personal data remains under direct control
- **Multi-Cloud Redundancy**: No single provider dependency
- **Automation-Driven**: Terraform, Ansible, and MCP integrations for hands-off management
- **PARA Methodology**: Projects, Areas, Resources, Archive — applied across all systems

### Core Components

| Layer | Purpose | Primary Tools |
|-------|---------|---------------|
| Compute | VM hosting & containers | Hostinger VPS, Oracle Cloud ARM |
| Networking | Secure mesh connectivity | Tailscale, WireGuard |
| Reverse Proxy | Traffic routing & SSL | Nginx Proxy Manager |
| Storage | File & document management | Cloud sync, Paperless-ngx |
| Automation | Tagging, routing, versioning | Hazel, shell scripts, LaunchAgents |
| Documentation | Knowledge base | BookStack (bookstack.shannonjlove.cloud) |

### Domain

All services accessible via `*.shannonjlove.cloud` subdomains.

---
*Last updated: February 2026*
