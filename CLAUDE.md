# Hybrid Personal Cloud Server Infrastructure

## What this repo is

Blueprint and configuration for a multi-node self-hosted cloud spanning:

| Node | Role | Access |
|---|---|---|
| **Nexus** (Hostinger VPS, x86_64) | Primary container host, NPM reverse proxy, public-facing | `72.61.74.250` / Tailscale `100.115.66.75` |
| **sOs** (Oracle Cloud ARM64) | Private compute, Tailscale-only | `ssh ubuntu@sOs` (Tailscale `100.67.229.94`) |
| **WebTop** | Always-on desktop-environment Podman Quadlet running **inside sOs** — not a separate node | Tailscale via sOs `:3000`/`:3001` |

All nodes connected via **Tailscale** mesh VPN. All services under `*.shannonjlove.cloud`.

## ABSOLUTE RULES

1. **Podman Quadlets only.** Every container is a systemd `.container` unit in `/etc/containers/systemd/`. Never Docker, never docker-compose.
2. **Nginx Proxy Manager only.** NPM handles all reverse proxy + SSL. Never Traefik, never Caddy. Delete any `traefik.*` labels on sight.
3. **No `ai-memory` binary.** Do not install `alphaonedev/ai-memory-mcp` — unverified, pulled via `curl | sh`, out of scope permanently.
4. **No secrets in the repo.** `.env` is gitignored. `env.template` (no leading dot) committed with placeholders only.

## Architecture

```
Nexus (100.115.66.75, public 72.61.74.250)
  ├── memory-agent   FastAPI + BetaLocalFilesystemMemoryTool, Tailscale-bound port 8100
  │                  Storage: /mnt/shared-context/memory-agent/
  ├── /opt/shared-context  → bind-mounted to /mnt/shared-context → exported via NFS
  │                           (Tailscale subnet 100.64.0.0/10 ONLY)
  ├── claude-memory  stdio MCP server (no container), MEMORY_ROOT=/mnt/shared-context/claude-memories
  └── NPM            https://memory.shannonjlove.cloud → 100.115.66.75:8100

sOs (100.67.229.94)
  ├── /mnt/shared-context  NFS-mounted from Nexus, same absolute path
  ├── claude-memory  Same stdio MCP server, same shared MEMORY_ROOT
  └── WebTop         Podman Quadlet, lscr.io/linuxserver/webtop:ubuntu-xfce
                     Always-on. Bind-mounts /mnt/shared-context at same path inside container.
```

## Memory tools (active on all nodes)

### 1. memory-agent (Nexus only — HTTP API)
- FastAPI service wrapping Anthropic `BetaLocalFilesystemMemoryTool`
- Podman Quadlet bound to `100.115.66.75:8100` (Tailscale-only)
- Anthropic API key stored as Podman secret `anthropic_api_key` (never on disk in plaintext)
- Public at `https://memory.shannonjlove.cloud` (NPM proxy)
- Health: `GET /healthz` | Chat: `POST /chat {"message": "...", "session_id": "..."}`

### 2. claude-memory (Anthropic memory_20250818 protocol)
- stdio MCP server at `~/.local/lib/claude-memory/server.py`
- **MEMORY_ROOT = `/mnt/shared-context/claude-memories`** (shared NFS — same files on all nodes)
- **Always `view /memories` at the start of every session** to recover prior context
- This is a SHARED store — context written on Nexus is readable on sOs, in WebTop, etc.

## Deployment scripts

All scripts in `scripts/` — run on the host specified in the filename:

```bash
# Nexus only (run in order):
bash scripts/deploy-memory-agent-nexus.sh        # Step 0: FastAPI memory-agent
bash scripts/deploy-shared-context-nexus.sh      # Step 1: NFS export + claude-memory
bash scripts/configure-npm-memory.sh             # Step 3: NPM proxy host

# sOs (after Nexus Steps 0-1 complete):
bash scripts/deploy-shared-context-sos-webtop.sh # Step 2: NFS mount + WebTop
```

## Key directories

```
02-CONTAINERS/ai-mcp-servers/
  claude-memory/server.py          <- Anthropic memory_20250818 stdio MCP server
  claude-memory/seed-memories/     <- infrastructure-rules.md seeded to MEMORY_ROOT on install
01-DEPLOYMENT/hostinger/quadlets/  <- Nexus quadlet unit files
01-DEPLOYMENT/oracle/quadlets/     <- sOs quadlet unit files (includes webtop)
scripts/                           <- Deployment scripts (see above)
ios/scriptable/                    <- iPhone Scriptable JS files
.claude/settings.json              <- Claude Code MCP config (written by deploy scripts)
```

## NPM access
- Public: `https://npm.shannonjlove.cloud`
- Tailscale: `http://shannonjlove.tail179603.ts.net:81`
- Credentials in `.env` on each server (gitignored)

## DNS
- Wildcard `*` A -> `72.61.74.250` covers ALL `*.shannonjlove.cloud` — no new DNS records needed

## Security rules
- No secrets, keys, tokens, or credentials in this repo (enforced by `.gitignore`)
- NFS exported to Tailscale subnet only — never bind to a public interface
- Destructive/public actions require approval per `06-OPS/approvals/POLICY.md`
- Memory files may contain session context but never credentials

## Tailscale mesh
SSH via Tailscale hostname: `ssh ubuntu@sOs`, `ssh ubuntu@gclove-server-vm-instance`, etc.
