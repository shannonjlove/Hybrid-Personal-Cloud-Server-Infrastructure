# Hybrid Personal Cloud Server Infrastructure

## What this repo is

Blueprint and configuration for a multi-node self-hosted cloud spanning:

| Node | Role | Access |
|---|---|---|
| **Nexus** (Hostinger VPS) | Primary container host, Traefik reverse proxy, public-facing | `nexus.shannonjlove.cloud` |
| **sOs** (Oracle Cloud ARM64) | Secondary compute, private workloads | `ssh ubuntu@sOs` (Tailscale) |
| **WebTop** | Web-based desktop container on Nexus | Traefik-routed subdomain |

All nodes connected via **Tailscale** mesh VPN. All services under `*.shannonjlove.cloud`.

## Memory tools (active on all three nodes)

Two memory backends are installed on every environment:

### 1. claude-memory (Anthropic memory_20250818 protocol)
- MCP server at `~/.local/lib/claude-memory/server.py`
- Files stored in `~/.claude/memories/`
- **Always `view /memories` at the start of every session** to recover prior context
- Used via Claude Code MCP (stdio) and directly via the Anthropic API

### 2. ai-memory (ai-memory, Apache 2.0)
- Binary: `ai-memory mcp --tier semantic` for Claude Code (stdio)
- HTTP daemon: `ai-memory serve` → `http://127.0.0.1:9077` (for other agents)
- Database: `~/.claude/ai-memory.db`
- Cross-agent: available at `https://memory.shannonjlove.cloud` (Nexus only, proxied by Nginx Proxy Manager)

### Installing / updating memory tools on a node
```bash
bash scripts/install-memory-tools.sh
```
Auto-detects ARM64 (Oracle) vs x86_64 (Nexus/WebTop) and installs the correct Podman Quadlet unit files.

## Key directories

```
02-CONTAINERS/ai-mcp-servers/   ← memory service Docker definitions
  claude-memory/server.py       ← Anthropic memory protocol MCP server
  ai-memory/Dockerfile          ← ai-memory multi-arch build
  docker-compose.yml            ← base compose (both services)
01-DEPLOYMENT/hostinger/        ← Nexus-specific overrides
01-DEPLOYMENT/oracle/           ← sOs ARM64 overrides
.claude/settings.json           ← Claude Code MCP config (written by install script)
scripts/install-memory-tools.sh ← one-shot installer for any node
```

## Container management

All containers run under **Podman Quadlets** (systemd `.container` units). Nginx Proxy Manager handles reverse proxy and SSL on Nexus. Never commit real credentials. Environment variables come from `.env` files (gitignored).

## Security rules

- No secrets, keys, tokens, or credentials in this repo (enforced by `.gitignore`)
- All destructive / public actions require approval per `06-OPS/approvals/POLICY.md`
- Memory files may contain session context but never credentials

## Tailscale mesh

Five devices: `sOs`, `gclove-server-vm-instance`, `ip-172-31-38-121`, `shajes-iphone`, `shannonjlove`
SSH via Tailscale hostname: `ssh ubuntu@sOs`, `ssh ubuntu@gclove-server-vm-instance`, etc.
