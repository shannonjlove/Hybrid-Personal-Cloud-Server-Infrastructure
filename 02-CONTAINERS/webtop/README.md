# WebTop — Browser-Accessible Linux Desktop

Image: `lscr.io/linuxserver/webtop:ubuntu-kde`
URL: https://desktop.shannonjlove.cloud

Browser-based KDE desktop for managing the cloud infrastructure without needing
a local machine. Claude Desktop runs inside WebTop and connects to both memory
MCP servers via `mcp-config.json`.

## MCP Servers Configured in WebTop

| Server      | Type        | Transport                                    |
|-------------|-------------|----------------------------------------------|
| memlord     | Self-hosted | HTTP → `https://memory.shannonjlove.cloud/mcp` |
| memstate    | SaaS (npx)  | stdio via `npx @memstate/mcp`                |

## Setup

### 1. Add env vars to root `.env`

```bash
TZ=America/Chicago
WEBTOP_BASIC_AUTH=shannon:$$apr1$$...   # htpasswd -nb user password
```

### 2. Fill in API key

Edit `mcp-config.json` and replace `YOUR_MEMSTATE_API_KEY_HERE` with the key
from https://memstate.ai/dashboard — or supply it via the Docker env if you
prefer not to store it here.

### 3. Deploy

```bash
# From repo root on Nexus VPS:
docker compose -f 02-CONTAINERS/webtop/docker-compose.yml up -d
```

### 4. Install Claude Desktop inside WebTop

Once WebTop is running, open the browser at `https://desktop.shannonjlove.cloud`,
open a terminal in the KDE desktop, and run:

```bash
# Download Claude Desktop .deb (check https://claude.ai/download for latest URL)
wget -O claude-desktop.deb "https://storage.googleapis.com/osprey-downloads-c02f6a0d-347c-492b-a752-3e0651722e97/nest-win-x64/Claude-Setup-x64.exe"
# Use the Linux AppImage or .deb from Anthropic's download page
```

The `mcp-config.json` is automatically mounted to the correct path for Claude Desktop.

## DNS

Add a CNAME: `desktop.shannonjlove.cloud → nexus.shannonjlove.cloud`

## Security

WebTop is protected by Traefik Basic Auth middleware. Do not expose port 3000
directly — all access goes through Traefik + TLS.
