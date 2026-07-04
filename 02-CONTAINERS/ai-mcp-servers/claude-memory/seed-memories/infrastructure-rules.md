# Infrastructure Rules — shannonjlove.cloud
**Seeded to /mnt/shared-context/claude-memories/ on every node.**
**This is a SHARED NFS store — visible from Nexus, sOs, and WebTop.**

## ABSOLUTE RULES

1. **Podman Quadlets only.** Every container is a systemd `.container` unit in
   `/etc/containers/systemd/`. Never Docker, never docker-compose.
2. **Nginx Proxy Manager only.** NPM handles all reverse proxy + SSL. Never
   Traefik, never Caddy. Delete any `traefik.*` labels on sight.
3. **Two physical hosts, not three.**
   - **Nexus** (Hostinger VPS, x86_64) — `72.61.74.250` / Tailscale `100.115.66.75`
   - **sOs** (Oracle Cloud ARM64) — Tailscale `100.67.229.94`
   - **WebTop** is NOT a third node. It is an always-on Podman Quadlet running *inside sOs*.
4. **No `ai-memory` binary.** `alphaonedev/ai-memory-mcp` is permanently out of scope.
5. **No Anthropic API key.** Memory stack is fully local — zero external API calls.
6. **No secrets in the repo.** `.env` is gitignored.

## Architecture

```
Nexus (100.115.66.75, public 72.61.74.250)
  ├── /mnt/shared-context  real data at /opt/shared-context, NFS-exported (Tailscale only)
  ├── claude-memory  stdio MCP, MEMORY_ROOT=/mnt/shared-context/claude-memories
  └── NPM            reverse proxy + SSL

sOs (100.67.229.94)
  ├── /mnt/shared-context  NFS-mounted from Nexus (same absolute path)
  ├── claude-memory  same stdio MCP, same shared MEMORY_ROOT
  └── WebTop         lscr.io/linuxserver/webtop:ubuntu-xfce Quadlet, mounts /mnt/shared-context
```

## Memory tool — claude-memory

- Server: `~/.local/lib/claude-memory/server.py`
- MEMORY_ROOT: `/mnt/shared-context/claude-memories` (same files on all nodes via NFS)
- **Always `view /memories` at session start** — shared context, check before asking user to repeat anything
- Free — no API calls, pure file I/O

## Deployment
```bash
# Nexus:
bash scripts/deploy-shared-context-nexus.sh

# sOs (after Nexus):
bash scripts/deploy-shared-context-sos-webtop.sh
```

## NPM access
- Public: https://npm.shannonjlove.cloud
- Tailscale: http://shannonjlove.tail179603.ts.net:81

## DNS
- Wildcard `*` A -> `72.61.74.250` — no new records needed for any *.shannonjlove.cloud

## Security
- NFS to Tailscale subnet only (100.64.0.0/10) — never public
- No secrets in git
- Destructive/public actions require approval per 06-OPS/approvals/POLICY.md
