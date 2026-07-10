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
5. **No Anthropic API key required.** The entire memory stack is fully local — no external API calls, no per-request cost. If you ever see `ANTHROPIC_API_KEY` being re-introduced, that's a regression — stop and flag it.
6. **`memory.shannonjlove.cloud` is Tailscale-restricted, not public.** NPM access list allows only `100.64.0.0/10`. Do not remove this restriction.

## Architecture

```
Nexus (100.115.66.75, public 72.61.74.250)
  ├── memory-agent (v2)   Plain REST CRUD over /memories. No model calls,
  │                       no external API, no cost. Podman Quadlet, port 8100,
  │                       Tailscale-bound. Storage: /mnt/shared-context/memory-agent/
  │
  ├── local-agent         Ollama-backed /chat (natural language memory reasoning).
  │                       Zero cost, zero vendor lock-in. Podman Quadlet, port 8101,
  │                       Tailscale-only. Model: qwen2.5:7b (swappable via OLLAMA_MODEL)
  │
  ├── /opt/shared-context -> bind-mounted to /mnt/shared-context -> NFS-exported
  │                          (Tailscale subnet 100.64.0.0/10 ONLY)
  │
  ├── claude-memory       stdio MCP server (no container), MEMORY_ROOT=/mnt/shared-context/claude-memories
  │
  └── NPM                 Reverse proxy + SSL
                          https://memory.shannonjlove.cloud -> 100.115.66.75:8100 (Tailscale-restricted)

sOs (100.67.229.94)
  ├── /mnt/shared-context  NFS-mounted from Nexus, same absolute path
  ├── claude-memory        Same stdio MCP server, same shared MEMORY_ROOT
  └── WebTop               Podman Quadlet, lscr.io/linuxserver/webtop:ubuntu-xfce
                           Always-on. Bind-mounts /mnt/shared-context at same path inside container.
```

## Memory tools

**claude-memory** (on all nodes, no API key)
- stdio MCP server at `~/.local/lib/claude-memory/server.py`
- Implements the Anthropic `memory_20250818` protocol (view/create/str_replace/insert/delete/rename)
- **MEMORY_ROOT = `/mnt/shared-context/claude-memories`** (shared via NFS — same files on all nodes)
- **Always `view /memories` at the start of every session** to recover prior context
- Zero API calls — pure file I/O

**memory-agent v2** (Nexus only, Tailscale port 8100)
- FastAPI REST CRUD service over `/memories`
- NO model calls, NO Anthropic API key, NO cost — plain file I/O with an HTTP front door
- Source: `02-CONTAINERS/ai-mcp-servers/memory-agent/`

**local-agent** (Nexus only, Tailscale port 8101, not public)
- Recovers natural-language memory reasoning using local Ollama (qwen2.5:7b by default)
- Talks to memory-agent's REST API as its tools — no duplicate file-safety logic
- Source: `02-CONTAINERS/ai-mcp-servers/local-agent/`

## Deployment order (Nexus first, then sOs)

```bash
# On Nexus — Step 0: memory-agent v2 (no API key, pure file CRUD)
bash scripts/deploy-memory-agent-v2.sh

# On Nexus — Step 0b: local-agent (Ollama-backed, free)
# Prerequisite: Ollama running + ollama pull qwen2.5:7b
bash scripts/deploy-local-agent.sh

# On Nexus — Step 1: shared context NFS + claude-memory
bash scripts/deploy-shared-context-nexus.sh

# On sOs (after Nexus Step 1 completes) — Step 2
bash scripts/deploy-shared-context-sos-webtop.sh

# On Nexus — Step 3: NPM proxy host for memory.shannonjlove.cloud
# Prerequisite: .env with NPM_EMAIL / NPM_PASSWORD / NPM_URL
bash scripts/configure-npm-memory.sh
```

## Claude skill — /memory-workflow

`.claude/memory-workflow.md` is a Claude Code skill. Invoke it with `/memory-workflow` or trigger it automatically with phrases like:

> "remember this" · "check memory" · "what do we know about X" · "save this to memory" · "update the infra notes" · "what's in /memories"

**At the start of every session on any node, run this before asking Shannon to re-explain anything:**
```
memory(command='view', path='/memories')
```

The skill covers: MCP tool vs REST API decision logic, all six MCP commands, all REST endpoints with curl examples, file organization conventions, access matrix, and security boundaries. Read it before touching memory if anything is unclear.

**Memory file naming:** Files are named by topic (`infra/nexus.md`), not by timestamp. The `YYYY-MM-DD_HH-MM_category_UUID` convention used elsewhere does NOT apply here — memory files are living documents, not point-in-time artifacts. Write once, update in place with `str_replace`.

## Key directories

```
02-CONTAINERS/ai-mcp-servers/
  claude-memory/server.py          <- stdio MCP server (memory_20250818 protocol)
  claude-memory/seed-memories/     <- seeded into MEMORY_ROOT on install
  memory-agent/                    <- FastAPI file CRUD (v2, no API key)
  local-agent/                     <- Ollama-backed /chat service
01-DEPLOYMENT/hostinger/quadlets/  <- Nexus Quadlet unit files
  memory-agent.container
  local-agent.container
01-DEPLOYMENT/oracle/quadlets/     <- sOs Quadlet unit files (webtop)
scripts/
  install-memory-tools.sh          <- ONE-SHOT: runs all Nexus steps in order (pull + deploy)
  deploy-memory-agent-v2.sh
  deploy-local-agent.sh
  deploy-shared-context-nexus.sh
  deploy-shared-context-sos-webtop.sh
  configure-npm-memory.sh
05-DOCS/
  HANDOFF-memory-usage-workflow.md <- full memory usage reference (also at artifact link)
ios/scriptable/                    <- iPhone Scriptable JS files
.claude/
  settings.json                    <- Claude Code MCP config (claude-memory server entry)
  memory-workflow.md               <- /memory-workflow Claude skill
```

## Deployment gotchas (learned in practice)

**Podman Quadlet systemctl:** Never use `systemctl enable --now <quadlet>.service` — Quadlet units are generated at runtime and `enable --now` fails with "unit is transient or generated". Always use:
```bash
systemctl daemon-reload
systemctl start <service>.service
```
NFS (`nfs-kernel-server`) is a real service and CAN use `enable --now`. Quadlets cannot.

**Python venv on Ubuntu 24.04:** `pip3 install --user` is blocked by PEP 668 ("externally managed environment"). Always create a venv first:
```bash
apt-get install -y python3-venv python3-full
python3 -m venv ~/.local/lib/claude-memory/venv
~/.local/lib/claude-memory/venv/bin/pip install "mcp[cli]>=1.0.0"
```
The `settings.json` `command` field must point to the venv python, not the system python.

**NPM URL from Nexus:** NPM runs on Nexus itself. When running `configure-npm-memory.sh` on Nexus, use `http://localhost:81` — not the Tailscale hostname (`shannonjlove.tail179603.ts.net:81`), which may not be reachable from the same host due to NAT hairpin.

**Repo directory:** All scripts use `git rev-parse --show-toplevel` or assume they're run from the repo root. Always `cd ~/Hybrid-Personal-Cloud-Server-Infrastructure` before running any script.

**sOs needs sudo:** `ubuntu` user on Oracle Cloud requires `sudo bash scripts/deploy-shared-context-sos-webtop.sh` for systemctl and apt operations.

## NPM access
- Public: `https://npm.shannonjlove.cloud`
- Tailscale: `http://shannonjlove.tail179603.ts.net:81`
- Local (from Nexus): `http://localhost:81`
- Credentials in `.env` on each server (gitignored)

## DNS
- Wildcard `*` A -> `72.61.74.250` covers ALL `*.shannonjlove.cloud` — no new DNS records needed
- `memory.shannonjlove.cloud` resolves already (wildcard), only the NPM proxy host was missing

## Security rules
- No secrets, keys, tokens, or credentials in this repo (enforced by `.gitignore`)
- NFS exported to Tailscale subnet only — never bind to a public interface
- `memory.shannonjlove.cloud` Tailscale-restricted via NPM access list — do not remove
- Destructive/public actions require approval per `06-OPS/approvals/POLICY.md`
- Memory files may contain session context but never credentials

## Tailscale mesh
SSH via Tailscale hostname: `ssh ubuntu@sOs`, `ssh ubuntu@gclove-server-vm-instance`, etc.
