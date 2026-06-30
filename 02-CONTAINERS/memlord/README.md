# memlord — Self-Hosted MCP Memory Server

Source: https://github.com/MyrikLD/memlord

Hybrid BM25 + pgvector (Reciprocal Rank Fusion) memory server for Claude and other
MCP-compatible AI assistants. Provides persistent, searchable memory across sessions
with a web UI and OAuth 2.1 authentication.

## Deployments

| Target   | URL                                    | Method                       |
|----------|----------------------------------------|------------------------------|
| VPS      | https://memory.shannonjlove.cloud      | Main docker-compose.yml      |
| Oracle   | http://100.67.229.94:8000 (Tailscale)  | docker-compose.oracle.yml    |
| WebTop   | Connects to VPS URL via MCP config     | mcp-config.json              |

## MCP Endpoint

```
https://memory.shannonjlove.cloud/mcp   # VPS (public, TLS)
http://100.67.229.94:8000/mcp           # Oracle (Tailscale only)
```

## VPS Deployment (Nexus)

Memlord is included in the root `docker-compose.yml`. Add required env vars to
the root `.env` file before starting:

```bash
# Required in root .env
MEMLORD_DB_PASS=<strong-random-password>
MEMLORD_JWT_SECRET=<long-random-secret>
```

Then deploy:

```bash
docker compose up -d memlord memlord-db
```

## Oracle Deployment (sOs)

```bash
scp 02-CONTAINERS/memlord/docker-compose.oracle.yml ubuntu@150.136.77.26:~/memlord/docker-compose.yml
scp 02-CONTAINERS/memlord/.env.example ubuntu@150.136.77.26:~/memlord/.env
# Edit .env on the server, then:
ssh ubuntu@150.136.77.26 "cd ~/memlord && docker compose up -d"
```

## WebTop

See `02-CONTAINERS/webtop/README.md` — Claude Desktop inside WebTop connects to
the VPS instance via the public URL.

## First-Run: Download ONNX Model

The embedding model (~23 MB) downloads on first start. This is handled automatically
by the container if the volume is empty. No manual step needed.

## DNS

Add a CNAME record: `memory.shannonjlove.cloud → nexus.shannonjlove.cloud`
