# /nginx-proxy — Manage nginx reverse proxy on Oracle sOs VM

You are helping Shannon manage nginx reverse-proxy entries on the Oracle ARM instance (sOs, IP 150.136.77.26, Tailscale: `ssh ubuntu@sOs`).

The management script lives at `/usr/local/sbin/sjl-nginx-proxy.sh` on the VM.
Repo source: `02-CONTAINERS/nginx/scripts/sjl-nginx-proxy.sh`

## What this skill does

When invoked, determine the user's intent from their message (or ask if ambiguous) and execute the appropriate action. Common tasks:

### Show current proxy state
```bash
sudo sjl-nginx-proxy.sh list
sudo nginx -t
sudo systemctl status nginx
```

### Add a new proxy
```bash
sudo sjl-nginx-proxy.sh add <name> <host:port> [--domain <fqdn>] [--ssl]
```
- If the user doesn't specify a domain, default to `<name>.shannonjlove.cloud`
- Always ask about SSL if not specified — prefer `--ssl` for public-facing services
- WebTop specifically uses port 3000 (KasmVNC) and needs WebSocket support (already in template)

### Update an upstream (service moved ports or hosts)
```bash
sudo sjl-nginx-proxy.sh update <name> <new-host:port> [--domain <fqdn>]
```

### Remove a proxy
```bash
sudo sjl-nginx-proxy.sh remove <name>
```

### After any change — verify
```bash
sudo nginx -t && sudo systemctl reload nginx
sudo journalctl -u nginx --since "1 minute ago"
```

## Decision guide

| Situation | Action |
|-----------|--------|
| New container added to sOs | `add` with the container's published port |
| Container port changed | `update` with the new port |
| Service decommissioned | `remove` |
| nginx failing after update | `check` → inspect journal → fix template |
| SSL cert expiry warning | `certbot renew --dry-run` first, then `certbot renew` |

## Known services on sOs

| Name | Upstream | Domain | SSL |
|------|----------|--------|-----|
| webtop | 127.0.0.1:3000 | webtop.shannonjlove.cloud | yes (when public) |

## Deployment (first-time install on sOs)

```bash
# Install nginx and certbot
sudo apt-get install -y nginx certbot python3-certbot-nginx

# Copy script and templates
sudo cp 02-CONTAINERS/nginx/scripts/sjl-nginx-proxy.sh /usr/local/sbin/
sudo chmod 0755 /usr/local/sbin/sjl-nginx-proxy.sh
sudo mkdir -p /etc/nginx/sjl-templates
sudo cp 02-CONTAINERS/nginx/templates/proxy-http.conf /etc/nginx/sjl-templates/
sudo cp 02-CONTAINERS/nginx/templates/proxy-ssl.conf  /etc/nginx/sjl-templates/

# Enable nginx
sudo systemctl enable --now nginx

# Add WebTop proxy (internal/Tailscale only — no --ssl needed on private network)
sudo sjl-nginx-proxy.sh add webtop 127.0.0.1:3000
```

## Template locations on sOs

- Sites available: `/etc/nginx/sites-available/sjl-<name>.conf`
- Sites enabled:   `/etc/nginx/sites-enabled/sjl-<name>.conf` (symlink)
- Templates:       `/etc/nginx/sjl-templates/`

## Notes

- The templates include WebSocket upgrade headers (`Upgrade`, `Connection`) required by
  WebTop's KasmVNC interface and long-lived streaming proxies.
- `proxy_read_timeout 3600s` prevents desktop sessions from dropping after 60 s idle.
- `proxy_buffering off` is essential for real-time desktop streaming — do not remove it.
- For Tailscale-internal services, HTTP is fine (Tailscale encrypts in transit); only
  enable `--ssl` for publicly routed domains.
