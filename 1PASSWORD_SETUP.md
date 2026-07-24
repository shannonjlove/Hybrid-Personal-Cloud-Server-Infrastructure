# 1Password Connect Podman Quadlet Setup

This guide converts the 1Password Connect Docker Compose configuration to Podman Quadlets for your Hybrid Personal Cloud infrastructure.

## Prerequisites

1. **1Password credentials file**: `1password-credentials.json` from 1Password Connect setup
2. **Podman** installed on Nexus
3. **Access to `/etc/containers/systemd/`** (requires `sudo`)

## Setup Steps

### 1. Create the data directory on Nexus

```bash
sudo mkdir -p /opt/1password/data
sudo chmod 755 /opt/1password
```

### 2. Copy the credentials file

Place your `1password-credentials.json` in the secure location:

```bash
sudo cp /path/to/1password-credentials.json /opt/1password/
sudo chmod 600 /opt/1password/1password-credentials.json
sudo chown 999:999 /opt/1password/1password-credentials.json  # opuser in the container
```

### 3. Deploy the Quadlet units

Copy the `.container` files to the systemd directory on Nexus:

```bash
sudo cp 1password-connect-api.container /etc/containers/systemd/
sudo cp 1password-connect-sync.container /etc/containers/systemd/
```

### 4. Enable and start the services

```bash
sudo systemctl daemon-reload
sudo systemctl start 1password-connect-api.service
sudo systemctl start 1password-connect-sync.service

# Verify they're running
sudo systemctl status 1password-connect-api.service
sudo systemctl status 1password-connect-sync.service
```

### 5. Check logs

```bash
# API logs
sudo journalctl -u 1password-connect-api.service -f

# Sync logs
sudo journalctl -u 1password-connect-sync.service -f
```

## Verification

Test the API endpoint:

```bash
curl -H "Accept: application/json" \
  -H "Authorization: Bearer $OP_API_TOKEN" \
  http://localhost:8080/v1/vaults
```

## Nginx Proxy Manager Integration (Optional)

To expose 1Password Connect through Nginx Proxy Manager for remote access via Tailscale:

1. Log into NPM at `http://localhost:81` (or `https://npm.shannonjlove.cloud` if already configured)
2. Create a new **Proxy Host** with:
   - **Domain Names**: `1password.shannonjlove.cloud`
   - **Scheme**: `http`
   - **Forward Hostname/IP**: `localhost`
   - **Forward Port**: `8080`
   - **Access List**: Tailscale subnet `100.64.0.0/10` (Tailscale-only, not public)
   - **SSL Certificate**: Let's Encrypt (auto-generated)

This makes the API available at `https://1password.shannonjlove.cloud` over Tailscale only.

## Quadlet Features Used

| Feature | Purpose |
|---------|---------|
| `After=` | Ensures API starts before Sync |
| `BindsTo=` | Sync stops if API stops |
| `Wants=` | Soft dependency on network |
| `PublishPort=` | Maps container → host ports |
| `Volume=` | Mounts credentials and data directories |
| `:ro` | Read-only mount for credentials |
| `:Z` | SELinux labeling for data volume |
| `Restart=on-failure` | Auto-restart on crashes |
| `RestartSec=5s` | 5-second delay between restarts |

## Key Differences from Docker Compose

| Docker Compose | Podman Quadlet |
|---|---|
| `docker-compose up` | `systemctl start <service>` |
| Named volumes | Host paths at `/opt/1password/` |
| Service dependencies | `After=`, `Wants=`, `BindsTo=` |
| Network (implied) | Direct port publishing |
| Log management | `journalctl` (systemd integration) |

## Security Considerations

1. **Credentials file permissions** (600) — only the `opuser` (UID 999) in the container can read
2. **Tailscale-only access** — NPM access list restricts to Tailscale subnet
3. **Read-only credentials** — `:ro` flag prevents container from modifying credentials
4. **Data volume labeling** — `:Z` flag ensures proper SELinux context

## Troubleshooting

**Service won't start:**
```bash
sudo systemctl status 1password-connect-api.service
sudo journalctl -u 1password-connect-api.service --no-pager
```

**Permission denied on credentials:**
```bash
ls -la /opt/1password/1password-credentials.json
# Should show: -rw------- 1 root root (or opuser if UID 999)
# Fix: sudo chmod 600 && sudo chown 999:999
```

**Containers stuck in restart loop:**
```bash
sudo journalctl -u 1password-connect-api.service -n 50
# Check if credentials file is readable
# Check if port 8080 is already in use
```

## Environment Variables

You can customize logging by editing the `.container` files and changing:

```ini
Environment=OP_LOG_LEVEL=debug
```

Valid values: `trace`, `debug`, `info`, `warn`, `error`, `fatal`

Default is `info` if omitted.

## Next Steps

1. Follow the setup steps above to deploy the containers
2. Verify the API is responsive with the curl command
3. (Optional) Configure NPM for remote Tailscale access
4. Test with 1Password CLI: `op user list` (if configured as a Connect instance)
