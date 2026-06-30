# WebTop — Browser Desktop with OCI MCP Server

Runs a full KDE desktop in the browser via [linuxserver/webtop](https://docs.linuxserver.io/images/docker-webtop/).
On first boot, `init-mcp-oci.sh` installs `mcp-server-oci` inside the container and writes a Claude Desktop config so the OCI MCP server is immediately available.

## Quick Start

```bash
# Copy and fill in your env values
cp .env.example .env

# Build the OCI MCP image (first time only)
docker compose build mcp-server-oci

# Start both services
docker compose up -d
```

Then open `http://<host>:3010` (or `https://desktop.shannonjlove.cloud` if Traefik is configured).

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `TZ` | `America/New_York` | Container timezone |
| `OCI_CONFIG_DIR` | `~/.oci` | Host path to OCI credentials |
| `WEBTOP_AUTH_USERS` | — | Traefik basicauth user:hash pairs |
| `FASTMCP_LOG_LEVEL` | `INFO` | MCP server log level |

## OCI Credentials

Mount your existing OCI config read-only. Inside the container it lands at `/config/.oci/config`.

```
~/.oci/
  config
  oci_api_key.pem
```

The `init-mcp-oci.sh` script points `OCI_CONFIG_FILE` to `/config/.oci/config`.

## Claude Desktop Config

After first boot, Claude Desktop will find the MCP server config at:
`/config/.config/Claude/claude_desktop_config.json`

Restart Claude Desktop inside the WebTop session to pick up the server.

---
*No real credentials or private server details should be stored here.*
