# AI MCP Servers

Memory and context services for Claude and other AI agents across all three environments.
All services run as **Podman Quadlets** (systemd `.container` unit files).

## Services

### claude-memory
Implements the **Anthropic `memory_20250818` protocol** as a local MCP server.

- Transport: **stdio** (Claude Code calls it directly as an MCP server)
- Storage: filesystem under `~/.claude/memories/`
- Commands: `view`, `create`, `str_replace`, `insert`, `delete`, `rename`
- Path traversal protection built in
- License: Apache 2.0 (this implementation)

### ai-memory
**[ai-memory](https://github.com/alphaonedev/ai-memory-mcp)** — Rust MCP server with 3-tier memory and FTS5+vector recall.

- Transport: **stdio** for Claude Code (`ai-memory mcp --tier semantic`)
- Transport: **HTTP** for other agents (`ai-memory serve` → port 9077)
- Storage: SQLite at `~/.claude/ai-memory.db`
- Tiers: keyword → semantic → smart → autonomous
- License: Apache 2.0
- On Nexus: `memory.shannonjlove.cloud` proxied by Nginx Proxy Manager → `127.0.0.1:9077`

## Installation

Run on each node (auto-detects ARM64 vs x86_64):

```bash
bash scripts/install-memory-tools.sh
```

Builds Podman images, copies Quadlet unit files to `/etc/containers/systemd/`,
reloads systemd, and starts both services.

## Quadlet unit files

Per-environment `.container` files live in:

```
01-DEPLOYMENT/hostinger/quadlets/   ← Nexus VPS + WebTop (x86_64)
  claude-memory.container
  ai-memory.container

01-DEPLOYMENT/oracle/quadlets/      ← sOs (ARM64)
  claude-memory.container
  ai-memory.container
```

The install script copies the correct set to `/etc/containers/systemd/` and
calls `systemctl daemon-reload` + `systemctl enable --now`.

## Architecture

```
Claude Code CLI
  ├── MCP stdio → claude-memory (server.py) → ~/.claude/memories/
  └── MCP stdio → ai-memory binary          → ~/.claude/ai-memory.db

Other AI agents / API integrations
  └── HTTP → ai-memory Podman service (:9077)
           → https://memory.shannonjlove.cloud  (Nexus via Nginx Proxy Manager)
```

## Source files

```
claude-memory/
  server.py          MCP server implementing memory_20250818 protocol
  requirements.txt   mcp[cli]>=1.0.0
  Dockerfile         python:3.12-slim image (built by install script)
ai-memory/
  Dockerfile         Multi-arch Rust build (amd64 + arm64)
```

---
*No credentials or real server details stored here.*
