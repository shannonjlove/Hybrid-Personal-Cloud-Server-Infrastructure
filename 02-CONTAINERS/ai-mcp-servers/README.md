# AI MCP Servers

Memory and context services for Claude and other AI agents across all three environments.

## Services

### claude-memory
Implements the **Anthropic `memory_20250818` protocol** as a local MCP server.

- Transport: **stdio** (used by Claude Code directly)
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

## Installation

Run on each node (auto-detects ARM64 vs x86_64):

```bash
bash scripts/install-memory-tools.sh
```

This installs binaries, deploys Docker services, and writes `.claude/settings.json`.

## Docker Compose

```bash
# Nexus VPS / WebTop (x86_64)
docker compose \
  -f 02-CONTAINERS/ai-mcp-servers/docker-compose.yml \
  -f 01-DEPLOYMENT/hostinger/memory-compose.override.yml \
  up -d --build

# Oracle sOs (ARM64)
docker compose \
  -f 02-CONTAINERS/ai-mcp-servers/docker-compose.yml \
  -f 01-DEPLOYMENT/oracle/memory-compose.override.yml \
  up -d --build
```

## Architecture

```
Claude Code CLI
  ├── MCP stdio → claude-memory (server.py) → ~/.claude/memories/
  └── MCP stdio → ai-memory binary          → ~/.claude/ai-memory.db

Other AI agents / API integrations
  └── HTTP → ai-memory HTTP daemon (Docker, :9077)
           → https://memory.shannonjlove.cloud (Nexus via Traefik)
```

## Files

```
claude-memory/
  server.py          MCP server implementing memory_20250818 protocol
  requirements.txt   mcp[cli]>=1.0.0
  Dockerfile         python:3.12-slim image
ai-memory/
  Dockerfile         Multi-arch Rust build (amd64 + arm64)
docker-compose.yml   Both services (base config)
```

---
*No credentials or real server details stored here.*
