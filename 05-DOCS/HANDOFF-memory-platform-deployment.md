# Handoff: Memory Platform Deployment
**For:** Claude Console (or any new Claude Code session)  
**Repo:** `shannonjlove/Hybrid-Personal-Cloud-Server-Infrastructure`  
**Active branch:** `claude/memory-mcp-comparison-9e2hto`  
**Session this came from:** `session_01MiL72Avu9eE8fjr3YPbT81`

Paste this entire document at the start of a new session. It is fully self-contained.

---

## ABSOLUTE INFRASTRUCTURE RULES — NEVER DEVIATE

1. **Podman Quadlets ONLY.** All containers are systemd `.container` unit files in `/etc/containers/systemd/`. Never use Docker Compose. Never use `docker` CLI. Never use `docker-compose`. This was corrected once mid-session after Docker Compose was accidentally introduced.

2. **Nginx Proxy Manager ONLY.** NPM handles all reverse proxy and SSL. Never use Traefik. Never add `traefik.*` labels to anything. This was corrected once mid-session after Traefik labels appeared.

3. **No secrets in the repo.** `.env` is gitignored. `env.template` (no leading dot) is committed with placeholders only.

---

## Architecture

### Three Nodes

| Node | Role | Arch | Access |
|---|---|---|---|
| **Nexus** (Hostinger VPS) | Primary host, public-facing, NPM runs here | x86_64 | `72.61.74.250`, `nexus.shannonjlove.cloud` |
| **sOs** (Oracle Cloud ARM64) | Private compute, Tailscale-only | arm64 | `ssh ubuntu@sOs` (Tailscale) |
| **WebTop** | Web desktop container running on Nexus | x86_64 | Traefik-routed subdomain (NEXUS only) |

All nodes connected via **Tailscale** mesh VPN.  
All services under `*.shannonjlove.cloud` — wildcard `*` A record → `72.61.74.250` covers everything.

### NPM Access
- Public: `https://npm.shannonjlove.cloud`
- Tailscale: `http://shannonjlove.tail179603.ts.net:81`
- Credentials: `shannonjlove@mac.com` / `Yerffej!Yerffej1`

---

## Memory Platform — What Was Built

### Decision
After comparing memlord, mcp-ragdocs, ai-memory-mcp, epitome, and Anthropic's first-party `memory_20250818` tool, the decision was to install **both**:

| Tool | Role |
|---|---|
| **claude-memory** (Anthropic `memory_20250818`) | Primary — Claude Code's own session memory. Plain `.md` files in `~/.claude/memories/`. View at session start. |
| **ai-memory** (Rust binary, Apache 2.0) | Secondary — Semantic vector search via SQLite. HTTP REST at `:9077`. Used by non-Claude agents. Public at `https://memory.shannonjlove.cloud`. |

### MCP Config (`.claude/settings.json` — written by install script with absolute paths)
```json
{
  "mcpServers": {
    "claude-memory": {
      "command": "python3",
      "args": ["/home/USER/.local/lib/claude-memory/server.py"],
      "env": { "MEMORY_ROOT": "/home/USER/.claude/memories" }
    },
    "ai-memory": {
      "command": "ai-memory",
      "args": ["mcp", "--tier", "semantic"],
      "env": { "AI_MEMORY_DB": "/home/USER/.claude/ai-memory.db" }
    }
  }
}
```

---

## Files Created (All on Branch `claude/memory-mcp-comparison-9e2hto`)

### Container Definitions
```
02-CONTAINERS/ai-mcp-servers/
  claude-memory/
    server.py                      ← Python MCP server (Anthropic memory_20250818 protocol)
    requirements.txt               ← mcp[cli]>=1.0.0
    Dockerfile                     ← python:3.12-slim, VOLUME /memories
    seed-memories/
      infrastructure-rules.md      ← Copied to ~/.claude/memories/ on install

  ai-memory/
    Dockerfile                     ← Multi-stage Rust build, amd64 + arm64 supported
```

### Podman Quadlets — Nexus (x86_64)
```
01-DEPLOYMENT/hostinger/quadlets/
  claude-memory.container          ← Volume: /opt/claude-memory/memories:/memories:Z
  ai-memory.container              ← PublishPort: 127.0.0.1:9077:9077
                                      NPM routes memory.shannonjlove.cloud → 127.0.0.1:9077
```

### Podman Quadlets — Oracle sOs (arm64)
```
01-DEPLOYMENT/oracle/quadlets/
  claude-memory.container          ← Same as Nexus
  ai-memory.container              ← Tailscale-only, no public port mapping
```

### Scripts
```
scripts/
  install-memory-tools.sh          ← ONE command to run on each server. Does:
                                      1. Detect ARM64 vs x86_64
                                      2. Install ai-memory binary (cargo or curl)
                                      3. Copy server.py to ~/.local/lib/claude-memory/
                                      4. Copy seed memory to ~/.claude/memories/infrastructure-rules.md
                                      5. podman build both images
                                      6. Copy quadlets to /etc/containers/systemd/
                                      7. systemctl daemon-reload && enable --now both services
                                      8. Write .claude/settings.json with absolute paths
                                      9. x86_64 only: run configure-npm-memory.sh + configure-npm-public.sh

  configure-npm-memory.sh          ← Automates NPM proxy host: memory.shannonjlove.cloud → 127.0.0.1:9077
                                      POST /api/tokens → auth
                                      Idempotency check → skip if already exists with SSL
                                      POST /api/nginx/proxy-hosts → create
                                      POST /api/nginx/certificates → Let's Encrypt
                                      PUT /api/nginx/proxy-hosts/{id} → enable SSL + HTTP/2 + HSTS
                                      Reads NPM_URL, NPM_EMAIL, NPM_PASSWORD from .env

  configure-npm-public.sh          ← Same pattern, creates npm.shannonjlove.cloud → 127.0.0.1:81
                                      (NPM proxies its own admin UI publicly)
```

### iOS Scriptable Scripts (4 files)
```
ios/scriptable/
  00-setup-keychain.js             ← Run once on iPhone. Stores to iOS Keychain:
                                      npm.url, npm.url.tailscale, npm.email, npm.password, memory.url
  npm-manager.js                   ← UITable: list/enable/disable NPM proxy hosts
  memory-query.js                  ← Search/store ai-memory. Shortcuts-compatible (pass text input).
  server-status-widget.js          ← Home screen widget polling NPM/Memory/Docs/Photos every 5 min
  README.md                        ← Setup guide + Shortcuts integration steps
```

### Other Key Files
```
CLAUDE.md                          ← Project context. Read by Claude Code at every session start.
                                      Contains: Podman Quadlets rule, NPM rule, node roles,
                                      memory tool info, NPM URLs, install command.
env.template                       ← Committed. Placeholder values. Shows all required keys.
.env                               ← GITIGNORED. Real credentials. Must be scp'd to each server.
05-DOCS/handoff-memory-mcp-comparison.md   ← Earlier summary handoff (less detailed than this)
```

---

## Credentials & Secrets

### `.env` contents (gitignored, NOT in repo — must be scp'd to each server)
```bash
NPM_URL=http://shannonjlove.tail179603.ts.net:81
NPM_EMAIL=shannonjlove@mac.com
NPM_PASSWORD=Yerffej!Yerffej1
NPM_DOMAIN=npm.shannonjlove.cloud

HOSTINGER_API_TOKEN=NcIQV8JdAL3mMMzBVrpxyM7DLeoWvidHDqQByam0b59983be
HOSTINGER_CLAUDE_TOKEN=LCIFC19zI6CfyEObVeXj9XkIZPTpluLhnfz9trKE53d68846

NEXUS_SSH_PUBKEY=ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMFczs+HI7Y29yoWJ/ZKcpjNBqBcDossU3kqj5B0NYu0
```

### Hostinger API Notes
- MCP tools `mcp__SJL_Hostinger__dns_list` and `mcp__SJL_Hostinger__vps_list` are **read-only**
- Direct REST to `api.hostinger.com` is blocked by Cloudflare from remote cloud environments (1016 error)
- Tokens are valid — REST calls work fine from actual Nexus VPS
- DNS write endpoint: `POST https://api.hostinger.com/v1/dns/zone/{domain}/records` with `Authorization: Bearer $HOSTINGER_API_TOKEN`

### DNS (confirmed via Hostinger MCP)
- Wildcard `*` A → `72.61.74.250` — covers ALL `*.shannonjlove.cloud` subdomains
- No new DNS records needed for npm, memory, or any other service we add

---

## What Is NOT Done Yet (Blocking Deployment)

### Step 1 — Deploy to Nexus
```bash
# On your local machine or any node with the repo:
scp .env user@nexus.shannonjlove.cloud:~/Hybrid-Personal-Cloud-Server-Infrastructure/

# SSH to Nexus:
ssh nexus
cd ~/Hybrid-Personal-Cloud-Server-Infrastructure
git fetch origin && git checkout claude/memory-mcp-comparison-9e2hto
bash scripts/install-memory-tools.sh
```
This will: build containers, start services, configure NPM proxy hosts automatically.

### Step 2 — Deploy to Oracle sOs
```bash
scp .env ubuntu@sOs:~/Hybrid-Personal-Cloud-Server-Infrastructure/
ssh ubuntu@sOs
cd ~/Hybrid-Personal-Cloud-Server-Infrastructure
git fetch origin && git checkout claude/memory-mcp-comparison-9e2hto
bash scripts/install-memory-tools.sh
```

### Step 3 — Deploy to WebTop
Same as Nexus (x86_64). WebTop is a container on Nexus — SSH or open terminal in WebTop and repeat Step 1.

### Step 4 — iOS Setup
1. Copy `ios/scriptable/*.js` to iCloud Drive → Scriptable/ folder
2. Open Scriptable on iPhone — files appear automatically
3. Run `00-setup-keychain.js` first (stores credentials to iOS Keychain)
4. Add `server-status-widget.js` as a home screen widget

### Step 5 — Verify Everything Works
```bash
# On each node after install:
systemctl status claude-memory ai-memory
curl http://127.0.0.1:9077/health
ls ~/.claude/memories/
# Should show infrastructure-rules.md

# Public endpoint (from anywhere):
curl https://memory.shannonjlove.cloud/health
```

---

## GNU Stow / Shared Dotfiles

**Not built in this session.** The user mentioned GNU Stow for symlinking credentials/config to all environments, but this was from a different Claude session. This session used a flat `.env` file manually scp'd to each node. If you find a GNU Stow implementation in another session's branch, reconcile those two approaches before deploying.

---

## Ongoing Concerns

- **NPM password `Yerffej!Yerffej1`** — password manager flagged this as reused. User chose to leave it as-is. Should be changed when convenient.
- **Password appeared in chat transcript** — it was typed in plaintext in this session. Treat as known to Anthropic. Recommend rotating after deployment.
- **This branch is not merged to main** — all work is on `claude/memory-mcp-comparison-9e2hto`. Merge when deployment is verified working.

---

## Quick Reference: Service URLs

| Service | URL | Notes |
|---|---|---|
| NPM Admin (public) | https://npm.shannonjlove.cloud | Proxied by NPM itself |
| NPM Admin (Tailscale) | http://shannonjlove.tail179603.ts.net:81 | Direct access |
| ai-memory (public) | https://memory.shannonjlove.cloud | NPM → 127.0.0.1:9077 |
| ai-memory (local) | http://127.0.0.1:9077 | On-server only |
| BookStack | https://docs.shannonjlove.cloud | Not yet configured with content |
| PhotoPrism | https://photos.shannonjlove.cloud | |
| WebTop | https://webtop.shannonjlove.cloud | |
