# Paperless-NGX

Document management for the Shannon J Love personal archive.  
Deployed via **Podman Quadlets** (systemd-native — no Docker Compose).

- **URL**: https://paperless.shannonjlove.cloud
- **Data**: `/opt/paperless/` on Nexus VPS (`72.61.74.250`)
- **Logs**: `journalctl -u paperless.service -f`

---

## Stack

| Service | Image | Quadlet file |
|---------|-------|-------------|
| App | `ghcr.io/paperless-ngx/paperless-ngx:latest` | `paperless.container` |
| Database | `postgres:16-alpine` | `paperless-db.container` |
| Broker | `valkey/valkey:8` | `paperless-broker.container` |
| Converter | `gotenberg/gotenberg:8` | `paperless-gotenberg.container` |
| Extractor | `ghcr.io/paperless-ngx/tika:latest` | `paperless-tika.container` |

All containers share the `paperless` Podman network (internal).  
Traefik (Docker) reaches the app via the file provider — see `traefik/dynamic/paperless.yml`.

---

## First-Time Deployment

```bash
# SSH into Nexus
ssh ubuntu@nexus.shannonjlove.cloud

# Pull the repo
cd ~/Hybrid-Personal-Cloud-Server-Infrastructure

# Create and populate the env file
sudo mkdir -p /etc/paperless
sudo cp 02-CONTAINERS/paperless-ngx/.env.example /etc/paperless/paperless.env
sudo nano /etc/paperless/paperless.env   # replace all CHANGE_ME values
sudo chmod 640 /etc/paperless/paperless.env

# Deploy (installs quadlets, pulls images, starts services)
sudo chmod +x 02-CONTAINERS/paperless-ngx/scripts/*.sh
sudo 02-CONTAINERS/paperless-ngx/scripts/deploy.sh

# Create admin user
sudo 02-CONTAINERS/paperless-ngx/scripts/create-superuser.sh

# After logging in and getting API token, add to /etc/paperless/paperless.env:
#   PAPERLESS_API_TOKEN=<token from Settings → API Token>

# Seed PARA tags, document types, and correspondents
sudo 02-CONTAINERS/paperless-ngx/scripts/seed-para-tags.sh

# Restart Traefik to pick up the file provider config
cd /path/to/docker-compose
docker compose restart traefik
```

---

## DNS

Add **A record** at Hostinger DNS:
```
paperless.shannonjlove.cloud  →  72.61.74.250
```

---

## Quadlet Files

```
quadlets/
├── paperless.network              ← internal Podman bridge
├── paperless-broker-data.volume   ← Valkey persistence
├── paperless-pgdata.volume        ← PostgreSQL persistence
├── paperless-broker.container     ← Valkey 8
├── paperless-db.container         ← PostgreSQL 16
├── paperless-gotenberg.container  ← Office → PDF conversion
├── paperless-tika.container       ← Content extraction
└── paperless.container            ← Main app (publishes :8000)
```

Quadlet files are installed to `/etc/containers/systemd/` by `deploy.sh`.  
`systemctl daemon-reload` triggers systemd to generate `.service` units from them.

---

## Data Directory Structure on VPS

```
/opt/paperless/
├── consume/           ← Drop files here to auto-ingest
│   ├── inbox/         ← Untagged (default)
│   ├── projects/      ← Auto-tagged "projects"
│   ├── areas/         ← Auto-tagged "areas"
│   ├── resources/     ← Auto-tagged "resources"
│   └── archive/       ← Auto-tagged "archive"
├── data/              ← App state, search index
├── media/             ← Processed originals + thumbnails
│   └── documents/
│       ├── originals/ ← YEAR/tag/correspondent/title.pdf
│       └── thumbnails/
└── export/            ← Backup output
```

`PAPERLESS_CONSUMER_SUBDIRS_AS_TAGS=true` means dropping a file into `consume/areas/` automatically tags it `areas`.

---

## PARA Tag Structure

| Tag | Colour | Meaning |
|-----|--------|---------|
| `project` | Red `#e74c3c` | Active work with deadline |
| `area` | Blue `#3498db` | Ongoing responsibility |
| `resource` | Green `#2ecc71` | Reference material |
| `archive` | Grey `#95a5a6` | Completed / inactive |
| `inbox` | Orange `#e67e22` | Unprocessed (inbox tag) |

Content tags: `legal`, `finance`, `medical`, `creative`, `personal`, `technical`

Document Types: Invoice, Contract, Receipt, Statement, Letter, Report, ID Document, Certificate, Policy, Manuscript

---

## Traefik Integration

Traefik (Docker) cannot auto-discover Podman containers via labels.  
The bridge uses Traefik's **file provider**:

1. `02-CONTAINERS/traefik/dynamic/paperless.yml` — static route to `http://host.docker.internal:8000`
2. `docker-compose.yml` Traefik service has `extra_hosts: ["host.docker.internal:host-gateway"]`

Port 8000 is published by the Paperless Quadlet. The Hostinger firewall group should block 8000 from the public internet — all traffic enters via Traefik on 443.

---

## Service Management

```bash
# Status
systemctl status paperless.service

# Logs (live)
journalctl -u paperless.service -f

# Restart
systemctl restart paperless.service

# Update (pull new image and restart)
podman pull ghcr.io/paperless-ngx/paperless-ngx:latest
systemctl restart paperless.service

# Stop all Paperless services
systemctl stop paperless.service paperless-db.service paperless-broker.service \
  paperless-gotenberg.service paperless-tika.service
```

---

## Backup

```bash
# Manual
sudo 02-CONTAINERS/paperless-ngx/scripts/backup.sh

# Cron (3 AM daily)
echo "0 3 * * * root /home/ubuntu/Hybrid-Personal-Cloud-Server-Infrastructure/02-CONTAINERS/paperless-ngx/scripts/backup.sh >> /var/log/paperless-backup.log 2>&1" \
  | sudo tee /etc/cron.d/paperless-backup
```

---

## iOS Integration

See [`../../ios/paperless/`](../../ios/paperless/) for the Scriptable client (browse, search, upload) and widget.
