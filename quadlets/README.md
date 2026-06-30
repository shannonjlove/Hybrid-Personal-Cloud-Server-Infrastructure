# Podman Quadlets

Systemd-native container management via Podman Quadlets — no Docker daemon, no Compose.
Each service is a `.container` unit file managed directly by systemd.

## Directory Layout

```
quadlets/
  vps/       → Nexus VPS (72.61.74.250) — all services
  oracle/    → Oracle sOs (150.136.77.26) — memlord only
  webtop/    → WebTop + Ollama (runs on VPS, separate network)
```

## Prerequisites (all servers)

```bash
# Install Podman (Ubuntu 24.04)
apt-get install -y podman

# Enable Podman socket (required for Traefik auto-discovery)
systemctl enable --now podman.socket

# Verify
podman info
```

## Deploy — VPS (Nexus)

```bash
# 1. Copy quadlet files
cp quadlets/vps/*.container  /etc/containers/systemd/
cp quadlets/vps/*.volume     /etc/containers/systemd/
cp quadlets/vps/*.network    /etc/containers/systemd/
cp quadlets/webtop/*.container /etc/containers/systemd/
cp quadlets/webtop/*.volume    /etc/containers/systemd/
cp quadlets/webtop/*.network   /etc/containers/systemd/

# 2. Install config files
mkdir -p /etc/infra/traefik/dynamic /etc/infra/webtop/init
cp 02-CONTAINERS/traefik/traefik.yml       /etc/infra/traefik/traefik.yml
cp 02-CONTAINERS/traefik/dynamic/*         /etc/infra/traefik/dynamic/
cp 02-CONTAINERS/webtop/mcp-config.json    /etc/infra/webtop/mcp-config.json
cp 02-CONTAINERS/webtop/init/install-uv.sh /etc/infra/webtop/init/install-uv.sh
chmod +x /etc/infra/webtop/init/install-uv.sh

# 3. Create env file from template and fill in secrets
cp quadlets/vps/infra.env.example /etc/containers/systemd/infra.env
cp quadlets/webtop/webtop.env.example /etc/containers/systemd/webtop.env
nano /etc/containers/systemd/infra.env
nano /etc/containers/systemd/webtop.env
chmod 600 /etc/containers/systemd/infra.env /etc/containers/systemd/webtop.env

# 4. Reload systemd and start all services
systemctl daemon-reload
systemctl enable --now traefik.service bookstack-db.service bookstack.service \
  memlord-db.service memlord.service photoprism.service \
  ollama.service webtop.service
```

## Deploy — Oracle (sOs)

```bash
# 1. Copy quadlet files
scp quadlets/oracle/*.container ubuntu@100.67.229.94:/tmp/
scp quadlets/oracle/*.volume    ubuntu@100.67.229.94:/tmp/
scp quadlets/oracle/*.network   ubuntu@100.67.229.94:/tmp/
ssh ubuntu@100.67.229.94 "sudo mv /tmp/*.container /tmp/*.volume /tmp/*.network /etc/containers/systemd/"

# 2. Create env file
scp quadlets/oracle/memlord.env.example ubuntu@100.67.229.94:/tmp/memlord.env
ssh ubuntu@100.67.229.94 "sudo mv /tmp/memlord.env /etc/containers/systemd/memlord.env && sudo nano /etc/containers/systemd/memlord.env && sudo chmod 600 /etc/containers/systemd/memlord.env"

# 3. Start
ssh ubuntu@100.67.229.94 "sudo systemctl daemon-reload && sudo systemctl enable --now memlord-db.service memlord.service"
```

## Managing Services

```bash
# Status of all quadlet containers
systemctl status '*.service' | grep -E 'traefik|bookstack|memlord|photoprism|webtop|ollama'

# Logs
journalctl -u memlord.service -f
journalctl -u webtop.service -f

# Restart a service
systemctl restart memlord.service

# Pull latest image and restart
podman pull ghcr.io/myrikld/memlord:latest
systemctl restart memlord.service
```

## Traefik + Podman Socket

Traefik uses the Podman socket mounted at `/var/run/docker.sock` (via bind mount from
`/run/podman/podman.sock`). The `podman.socket` systemd unit must be active for Traefik
to discover other containers via their labels.

## Notes

- `%E{VAR}` in `.container` files expands environment variables from `EnvironmentFile=`
- All containers on the same `.network` can reach each other by `ContainerName`
- Quadlet files are regenerated into transient systemd units on `daemon-reload`
- Legacy `docker-compose.yml` files are retained as reference but are superseded by quadlets
