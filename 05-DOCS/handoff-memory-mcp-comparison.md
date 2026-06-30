# Handoff: Memory MCP Tool Comparison Session
**Session:** claude/memory-mcp-comparison-9e2hto  
**Branch:** `claude/memory-mcp-comparison-9e2hto`  
**Date:** 2026-06-30

---

## What Was Decided

### Memory Tool Choice
Evaluated four third-party MCP memory servers (memlord, mcp-ragdocs, ai-memory-mcp, epitome) plus Anthropic's first-party `memory_20250818` tool. **Decision: install both Anthropic claude-memory AND ai-memory** on all three nodes.

| Tool | Role |
|---|---|
| **claude-memory** (Anthropic `memory_20250818`) | Primary — Claude Code's own memory, file-based `.md` files in `~/.claude/memories/`, persistent context across sessions |
| **ai-memory** (Rust binary, Apache 2.0) | Secondary — semantic vector search, HTTP REST API at port 9077, accessible by other AI agents at `https://memory.shannonjlove.cloud` |

**Which works best:** Both serve different purposes. claude-memory is for Claude's session context. ai-memory is for cross-agent shared memory with semantic search. Run both.

---

## Infrastructure Rules (Hardcoded in CLAUDE.md and seed memory)

- **Container runtime:** Podman Quadlets ONLY — systemd `.container` unit files in `/etc/containers/systemd/`. Never Docker Compose.
- **Reverse proxy:** Nginx Proxy Manager ONLY. Never Traefik.
- All services under `*.shannonjlove.cloud` via wildcard DNS `*` → `72.61.74.250`

---

## What Was Built (All on branch `claude/memory-mcp-comparison-9e2hto`)

### New Files Created

```
02-CONTAINERS/ai-mcp-servers/
  claude-memory/
    server.py                        ← Anthropic memory_20250818 MCP server (Python)
    requirements.txt                 ← mcp[cli]>=1.0.0
    Dockerfile                       ← python:3.12-slim, VOLUME /memories
    seed-memories/
      infrastructure-rules.md        ← Copied to ~/.claude/memories/ on every install

  ai-memory/
    Dockerfile                       ← Multi-stage Rust build, amd64 + arm64

01-DEPLOYMENT/
  hostinger/quadlets/
    claude-memory.container          ← Podman Quadlet for Nexus (x86_64)
    ai-memory.container              ← Port 127.0.0.1:9077, NPM proxies to memory.shannonjlove.cloud
  oracle/quadlets/
    claude-memory.container          ← Same, ARM64
    ai-memory.container              ← Tailscale-only, no public exposure

.claude/settings.json                ← MCP config for both tools (written by install script)
CLAUDE.md                            ← Project context, loaded every session

scripts/
  install-memory-tools.sh            ← One-shot installer: builds images, installs quadlets,
                                        copies seed memories, writes MCP config
                                        On x86_64: also runs NPM config scripts
  configure-npm-memory.sh            ← Automates NPM proxy host for memory.shannonjlove.cloud
  configure-npm-public.sh            ← Automates NPM proxy host for npm.shannonjlove.cloud

env.template                         ← Template with all required env var keys (no secrets)
.env                                 ← GITIGNORED — real credentials, must be scp'd to each node

ios/scriptable/
  00-setup-keychain.js               ← One-time iOS Keychain credential setup
  npm-manager.js                     ← List/enable/disable NPM proxy hosts from iPhone
  memory-query.js                    ← Search/store ai-memory; Shortcuts-compatible
  server-status-widget.js            ← Home screen widget, polls services every 5 min
  README.md                          ← Setup guide for Scriptable + Shortcuts
```

---

## Credentials & Secrets

### `.env` file (gitignored, at repo root)
Must be manually `scp`'d to each server before running install scripts.

```
NPM_URL=http://shannonjlove.tail179603.ts.net:81
NPM_EMAIL=shannonjlove@mac.com
NPM_PASSWORD=<set>
NPM_DOMAIN=npm.shannonjlove.cloud

HOSTINGER_API_TOKEN=<set>           ← Personal Hostinger API token
HOSTINGER_CLAUDE_TOKEN=<set>        ← "Claude Hostinger API" token from hPanel
NEXUS_SSH_PUBKEY=ssh-ed25519 ...    ← Nexus ed25519 public key
```

### iOS Keychain (on iPhone via 00-setup-keychain.js)
```
npm.url            = https://npm.shannonjlove.cloud
npm.url.tailscale  = http://shannonjlove.tail179603.ts.net:81
npm.email          = shannonjlove@mac.com
npm.password       = <set>
memory.url         = https://memory.shannonjlove.cloud
```

---

## Service URLs

| Service | URL |
|---|---|
| NPM Admin (public) | https://npm.shannonjlove.cloud |
| NPM Admin (Tailscale) | http://shannonjlove.tail179603.ts.net:81 |
| ai-memory (public) | https://memory.shannonjlove.cloud |
| ai-memory (local) | http://127.0.0.1:9077 |
| BookStack docs | https://docs.shannonjlove.cloud |
| Photos | https://photos.shannonjlove.cloud |

---

## What Still Needs to Be Done

### High Priority
- [ ] **Run install on all three nodes.** The scripts exist but haven't been executed yet:
  ```bash
  # On each node:
  scp .env user@nexus:~/Hybrid-Personal-Cloud-Server-Infrastructure/
  ssh nexus
  cd Hybrid-Personal-Cloud-Server-Infrastructure
  bash scripts/install-memory-tools.sh
  ```
- [ ] **Copy Scriptable files to iPhone** (iCloud Drive → Scriptable/ or paste directly)
- [ ] **Run `00-setup-keychain.js` first** to store iOS credentials

### Not Yet Built (from other sessions / future work)
- [ ] GNU Stow dotfiles setup for shared credential symlinking across nodes — **this was NOT built in this session**, it's from a different conversation
- [ ] Centralized secrets manager (Vault / Infisical) — only `.env` flat file exists now
- [ ] BookStack content — service exists at bookstack.shannonjlove.cloud but no content yet
- [ ] WebTop-specific quadlet deployment (oracle/ quadlets cover sOs; WebTop uses Nexus)

---

## Hostinger API Status

The Hostinger MCP (`mcp__SJL_Hostinger__dns_list`, `mcp__SJL_Hostinger__vps_list`) is **read-only** — no write tools exposed via MCP. Direct REST calls to `api.hostinger.com` return Cloudflare 1016 errors from this remote cloud environment (IP-blocked). The tokens are valid and will work from your actual Nexus VPS.

DNS write access for future use: call `https://api.hostinger.com/v1/dns/zone/{domain}/records` with `Authorization: Bearer $HOSTINGER_API_TOKEN`.

---

## DNS Records Confirmed (via Hostinger MCP)

Wildcard `*` → `72.61.74.250` covers all subdomains. Specific records also exist for: www, agent, status, assets, stacks, pages, docs, pics, webtop, rclone-mcp, admin, n8n, bookstack, api, private, dashboard, media.

No new DNS records were needed — wildcard covers npm, memory, and everything else.
