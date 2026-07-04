# WebTop — Operator Desktop Container

A browser-accessible Linux desktop (`linuxserver/webtop`) providing a persistent operator workspace on the Hostinger VPS. Operators use the WebTop to:

- Run Claude Code with write-enabled MCP access to the SJL Unified Cloud MCP gateway.
- Execute guarded repair scripts (e.g. `03-AUTOMATION/mcp-repair/guarded-repair-v1.7.sh`) against live infrastructure.
- Retain a local copy of recovery archives and redacted configuration snapshots.

## Access

| Endpoint | URL |
|----------|-----|
| WebTop desktop | `https://webtop.shannonjlove.cloud` |
| Via Tailscale | `http://100.67.229.94:3000` (no TLS needed on mesh) |

## Configuration files

| File | Purpose |
|------|---------|
| `docker-compose.webtop.yml` | Docker service definition |
| `config/claude-code-mcp.json` | MCP server template for Claude Code inside WebTop |
| `config/setup-claude-code.sh` | Bootstrap script — run once inside the WebTop terminal |

## First-time setup

1. Deploy the container: `docker compose -f docker-compose.webtop.yml up -d`
2. Open the WebTop URL in a browser.
3. Open a terminal inside the desktop.
4. Run `~/setup-claude-code.sh` to install Claude Code and apply the MCP configuration.
5. Verify the MCP connection: Claude Code → `/mcp` → confirm `sjl-unified-cloud-mcp` shows write tools.

## Security

- Container runs as UID/GID 1000 (`abc`).
- SSH private key for Hostinger VPS access must be injected via a Docker secret or mounted volume — never baked into the image.
- The MCP token (`SJL_MCP_WRITE_TOKEN`) is passed as an environment variable at container startup; it is not stored in this repository.
