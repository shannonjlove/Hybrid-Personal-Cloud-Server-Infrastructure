# Infrastructure Rules — shannonjlove.cloud
**This file is seeded to /mnt/shared-context/claude-memories/ on every node.**
**MEMORY_ROOT is shared via NFS — changes here are visible from all nodes (Nexus, sOs, WebTop).**

## ABSOLUTE RULES

1. **Podman Quadlets only.** Every container is a systemd `.container` unit in
   `/etc/containers/systemd/`. Never Docker, never docker-compose.
2. **Nginx Proxy Manager only.** NPM handles all reverse proxy + SSL. Never
   Traefik, never Caddy. Delete any `traefik.*` labels on sight.
3. **Two physical hosts, not three.**
   - **Nexus** (Hostinger VPS, x86_64) — `72.61.74.250` / Tailscale `100.115.66.75`
   - **sOs** (Oracle Cloud ARM64) — Tailscale `100.67.229.94`
   - **WebTop** is NOT a third node. It is an always-on Podman Quadlet running *inside sOs*.
4. **No `ai-memory` binary.** Do not install `alphaonedev/ai-memory-mcp` — unverified,
   pulled via `curl | sh`, permanently out of scope.
5. **No secrets in the repo.** `.env` is gitignored. Real credentials on each server only.

## Architecture

```
Nexus (100.115.66.75, public 72.61.74.250)
  ├── memory-agent   FastAPI + BetaLocalFilesystemMemoryTool, port 8100 (Tailscale-bound)
  ├── /mnt/shared-context  NFS export restricted to Tailscale subnet 100.64.0.0/10
  ├── claude-memory  stdio MCP, MEMORY_ROOT=/mnt/shared-context/claude-memories
  └── NPM            https://memory.shannonjlove.cloud → 100.115.66.75:8100

sOs (100.67.229.94)
  ├── /mnt/shared-context  NFS-mounted from Nexus (same absolute path)
  ├── claude-memory  Same stdio MCP, same shared MEMORY_ROOT
  └── WebTop         lscr.io/linuxserver/webtop:ubuntu-xfce Quadlet, /mnt/shared-context inside
```

## Memory tools

### memory-agent (HTTP API, Nexus only)
- `GET http://100.115.66.75:8100/healthz`
- `POST http://100.115.66.75:8100/chat` with `{"message": "...", "session_id": "..."}`
- Public: `https://memory.shannonjlove.cloud` (NPM → 100.115.66.75:8100)
- Anthropic API key stored as Podman secret `anthropic_api_key`

### claude-memory (stdio MCP, all nodes)
- Server: `~/.local/lib/claude-memory/server.py`
- MEMORY_ROOT: `/mnt/shared-context/claude-memories` (shared NFS — same files everywhere)
- **Always `view /memories` at session start** — this is a shared context store

## NPM access
- Public: `https://npm.shannonjlove.cloud`
- Tailscale: `http://shannonjlove.tail179603.ts.net:81`

## Deployment (run in order)
```bash
# Nexus:
bash scripts/deploy-memory-agent-nexus.sh
bash scripts/deploy-shared-context-nexus.sh
bash scripts/configure-npm-memory.sh

# sOs (after Nexus steps complete):
bash scripts/deploy-shared-context-sos-webtop.sh
```

## DNS
- Wildcard `*` A → `72.61.74.250` — no new DNS records needed for any `*.shannonjlove.cloud`

## Security
- NFS exported to Tailscale subnet only (100.64.0.0/10) — never public
- No secrets in git repo
- Destructive/public actions require approval per 06-OPS/approvals/POLICY.md
