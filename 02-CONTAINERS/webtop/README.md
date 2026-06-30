# WebTop — Browser-Accessible Linux Desktop

Image: `lscr.io/linuxserver/webtop:ubuntu-kde`
URL: https://desktop.shannonjlove.cloud

Browser-based KDE desktop for managing the cloud infrastructure without needing
a local machine. Claude Desktop runs inside WebTop with all MCP servers pre-configured.

## MCP Servers Configured in WebTop

| Server         | Type          | Transport                                      |
|----------------|---------------|------------------------------------------------|
| memlord        | Self-hosted   | HTTP → `https://memory.shannonjlove.cloud/mcp` |
| memstate       | SaaS (npx)    | stdio via `npx @memstate/mcp`                  |
| ollama         | Local (uvx)   | stdio via `uvx mcp-ollama` → Ollama container  |
| cloudflare     | SaaS (HTTP)   | HTTP → `https://mcp.cloudflare.com/mcp`        |
| mediaProcessor | npx           | stdio via `npx mcp-media-processor@latest`     |
| mcp-server-oci | Local (uv)    | stdio via `uv run mcp_server_oci` in `/config` |

Ollama runs as a sibling Podman service (`ollama:11434`) on the shared `webtop` network.
`mcp-ollama` connects to it via `http://ollama:11434`.

`mcp-server-oci` is cloned to `/config/mcp-server-oci` on first container start
by `init/install-oci-mcp.sh`, with credentials at `/config/.oci/config`.

## Setup

> **Note:** The old `docker-compose.yml` in this directory is kept as a reference only.
> The production setup uses Podman Quadlets in `quadlets/webtop/`.

### 1. Deploy and start WebTop (Nexus VPS, as root)

```bash
# From repo root:
bash scripts/start-webtop.sh
```

This script:
- Installs quadlet unit files to `/etc/containers/systemd/`
- Installs config and init scripts to `/etc/infra/webtop/`
- Creates `/etc/containers/systemd/webtop.env` (prompts for BasicAuth)
- Starts webtop-network, ollama, and webtop services
- Injects OCI credentials into the running container

On subsequent boots, systemd starts everything automatically.

### 2. Set BasicAuth password

The `start-webtop.sh` script creates `/etc/containers/systemd/webtop.env` on first run.
Edit it to set a real password:

```bash
# Generate the hash:
htpasswd -nb youruser yourpassword

# Then edit:
vi /etc/containers/systemd/webtop.env
# Set: WEBTOP_BASIC_AUTH=youruser:$$apr1$$...   (double $$ to escape systemd)

systemctl daemon-reload && systemctl restart webtop.service
```

### 3. Fill in Memstate API key

Edit `/etc/infra/webtop/mcp-config.json` on the VPS:

```bash
vi /etc/infra/webtop/mcp-config.json
# Replace YOUR_MEMSTATE_API_KEY_HERE with your key from https://memstate.ai/dashboard
```

### 4. Pull an Ollama model

After the stack is up, pull at least one model:

```bash
podman exec ollama ollama pull llama3.2
# or: mistral, gemma3, phi4, etc.
```

### 5. Install Claude Desktop inside WebTop

Open https://desktop.shannonjlove.cloud, open a terminal in the KDE desktop, and run:

```bash
# Download the latest Claude Desktop .deb for Linux:
wget -O claude-desktop.deb "https://storage.googleapis.com/osprey-downloads-c02f6a0d-347c-492b-a752-3e0651722e97/nest-win-x64/claude-desktop_latest_amd64.deb"
sudo dpkg -i claude-desktop.deb
sudo apt-get install -f   # fix any missing deps
```

The `mcp-config.json` is automatically bind-mounted at the correct Claude Desktop config path.

### 6. OCI credentials

`setup-oci-keys.sh` (or `start-webtop.sh`) injects them via:

```bash
podman cp /root/.oci/oci_api_key.pem webtop:/config/.oci/oci_api_key.pem
```

Config is written to `/config/.oci/config` with `key_file=/config/.oci/oci_api_key.pem`.

## Useful Commands

```bash
# Status
systemctl status webtop.service ollama.service

# Logs
journalctl -u webtop.service -f

# Shell into WebTop
podman exec -it webtop bash

# Restart
systemctl restart webtop.service

# View init script output (runs on each container start)
podman logs webtop | grep '\[init\]'
```

## File Layout (on Nexus VPS)

```
/etc/containers/systemd/
  webtop.container          # Podman Quadlet unit
  webtop.network
  webtop-data.volume
  ollama.container
  ollama-data.volume
  webtop.env                # Secrets (TZ, WEBTOP_BASIC_AUTH)

/etc/infra/webtop/
  mcp-config.json           # Claude Desktop MCP config (bind-mounted :ro)
  init/
    install-uv.sh           # Installs uv/uvx on first start
    install-media-tools.sh  # Installs ffmpeg + imagemagick
    install-oci-mcp.sh      # Clones mcp-server-oci, runs uv sync
```

## DNS

Add a CNAME: `desktop.shannonjlove.cloud → nexus.shannonjlove.cloud`

## Security

WebTop is protected by Traefik Basic Auth middleware. Do not expose port 3000
directly — all access goes through Traefik + TLS.
