# Infrastructure Rules — shannonjlove.cloud

## Container runtime
- ALWAYS use **Podman Quadlets** (systemd .container unit files)
- NEVER use Docker or docker-compose — this stack does not use Docker
- Quadlet files live in /etc/containers/systemd/ on each node
- Per-environment units: 01-DEPLOYMENT/hostinger/quadlets/ and 01-DEPLOYMENT/oracle/quadlets/

## Reverse proxy
- ALWAYS use **Nginx Proxy Manager** for reverse proxy and SSL
- NEVER reference Traefik — this stack does not use Traefik
- NPM web UI (Tailscale): http://shannonjlove.tail179603.ts.net:81
- NPM web UI (public):    https://npm.shannonjlove.cloud
- NPM login email: shannonjlove@mac.com
- NPM password lives in .env on each server (gitignored) — never hardcoded
- Proxy hosts are configured via API script: scripts/configure-npm-memory.sh
- Credentials loaded automatically from .env by all install scripts

## Node roles
- Nexus (Hostinger VPS, x86_64): primary host, public-facing, NPM, all public subdomains
- sOs (Oracle Cloud, ARM64): private workloads, Tailscale-only, no public proxy
- WebTop: web desktop container on Nexus, shares Nexus quadlets and NPM

## Memory tools
- claude-memory (Anthropic memory_20250818): stdio MCP for Claude Code, files in ~/.claude/memories/
- ai-memory: stdio MCP for Claude Code + HTTP daemon at 127.0.0.1:9077 for other agents
- memory.shannonjlove.cloud proxied by NPM → ai-memory:9077 (Nexus only)
- Install/update both: bash scripts/install-memory-tools.sh

## Networking
- All nodes connected via Tailscale mesh VPN
- SSH: ssh ubuntu@sOs, ssh ubuntu@gclove-server-vm-instance
- All public services: *.shannonjlove.cloud

## Security
- No secrets, tokens, or credentials in this repo
- Credentials come from .env files (gitignored)
- Destructive/public actions require approval per 06-OPS/approvals/POLICY.md
