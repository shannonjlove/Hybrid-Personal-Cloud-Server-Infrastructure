# Hybrid Personal Cloud Server Infrastructure

A self-hosted, multi-cloud personal infrastructure for file management, documentation, media, and automation — unified through Tailscale mesh networking, Docker containerization, and PARA-based digital organization.

## Architecture

| Provider | Role | Hostname |
|----------|------|----------|
| Hostinger VPS | Primary container host | Nexus |
| Oracle Cloud | ARM compute | sOs |
| AWS | Supplemental services | — |
| GCP | Supplemental services | — |

All services accessible via `*.shannonjlove.cloud` subdomains. Servers connected through Tailscale mesh VPN.

## Repository Structure

```
Hybrid-Personal-Cloud-Server-Infrastructure/
│
├── 00-MASTER-ARCHITECTURE/       # System design and PARA methodology
│   ├── system-overview.md
│   ├── infrastructure-map.md
│   └── para-structure.md
│
├── 01-DEPLOYMENT/                # Provider-specific provisioning
│   ├── hostinger/
│   ├── oracle/
│   ├── aws/
│   └── gcp/
│
├── 02-CONTAINERS/                # Docker service configurations
│   ├── traefik/
│   ├── bookstack/
│   ├── photoprism/
│   ├── stash/
   ├── hookmark-sync/
   └── ai-mcp-servers/
│
├── 03-AUTOMATION/                # File routing, tagging, versioning
│   ├── auto-tagging/
│   ├── versioning/
│   ├── file-routing/
│   └── metadata-persistence/
│
├── 04-SECURITY/                  # VPN, tunnels, secrets
│   ├── tailscale/
│   ├── wireguard/
│   └── secrets-management/
│
├── 05-DOCS/                      # Operational documentation
│   ├── full-system-manual.md
│   └── troubleshooting.md
│
└── docker-compose.yml            # Master service definitions
```

## Key Technologies

- **Containers**: Docker + Docker Compose
- **Reverse Proxy**: Traefik (SSL via Let's Encrypt)
- **Networking**: Tailscale mesh VPN, WireGuard
- **IaC**: Terraform, Ansible
- **Automation**: Hazel, shell scripts, LaunchAgents, MCP servers
- **Documentation**: BookStack (docs.shannonjlove.cloud)
- **Organization**: PARA methodology

## Security

> **No real credentials, API keys, tokens, or private keys should ever be committed to this repository.** All sensitive values use environment variables and `.env` files (gitignored).

---
*Last updated: February 2026*