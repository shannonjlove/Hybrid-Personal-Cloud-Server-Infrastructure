# SJL Infrastructure — LLM Context File

This file is the authoritative shared context for any AI assistant (Claude, GPT, Gemini,
or other) working on Shannon Jeffrey Love's hybrid personal cloud infrastructure.
Load this file at the start of any session involving `shannonjlove.cloud` or the Oracle VM.

**Owner:** Shannon Jeffrey Love (`sjlove@shannonjeffreylove.com`)
**Last updated:** 2026-06-30

---

## 1. Infrastructure Topology

```
Internet
  ↓
shannonjlove.cloud  (Cloudflare DNS)
  ↓ A record → 72.61.74.250
Nexus — Hostinger VPS  [primary public edge]
  ↓ Nginx Proxy Manager (ports 80/443)
  ↓ Tailscale mesh to all nodes
  ├── sOs — Oracle Cloud ARM64  [private compute / WebTop]
  ├── gclove-server-vm-instance  [GCP]
  ├── ip-172-31-38-121  [AWS]
  └── shannonjlove (Mac)
```

---

## 2. Servers

### Nexus — Hostinger VPS (primary edge)

| Property | Value |
|----------|-------|
| Role | Public ingress, container host, reverse proxy |
| Public IP | `72.61.74.250` |
| Hostname | `nexus.shannonjlove.cloud` |
| OS | Ubuntu (Docker) |
| Reverse proxy | Nginx Proxy Manager (`jc21/nginx-proxy-manager`) |
| NPM admin UI | `http://nexus.shannonjlove.cloud:81` |
| Container runtime | Docker / docker-compose |
| Tailscale node | `nexus` |

### sOs — Oracle Cloud ARM64 (private compute)

| Property | Value |
|----------|-------|
| Role | Private compute, WebTop desktop, AI workloads |
| Public IP | `150.136.77.26` |
| OCI private IP | `10.0.1.2` |
| Tailscale IP | `100.67.229.94` |
| Tailscale node | `oracle-sos` |
| Architecture | `aarch64` / ARM64 |
| Region | `us-ashburn-1` |
| OS | Ubuntu |
| SSH | `ssh ubuntu@sOs` (Tailscale) or `ssh -i ~/.ssh/oracle_rsa_new ubuntu@150.136.77.26` |
| Container runtime | Rootless Podman + Quadlet (systemd) |
| Primary SSH key | `oracle_rsa_new` (RSA 4096) |
| Fallback keys | `oci_rsa`, `oracle_ed25519` |

### Other nodes

| Node | Role | Tailscale name |
|------|------|---------------|
| GCP VM | Supplemental compute | `gclove-server-vm-instance` |
| AWS EC2 | Supplemental compute | `ip-172-31-38-121` |
| Mac | Developer workstation | `shannonjlove` |
| iPhone | Mobile | `shajes-iphone` |

---

## 3. Networking

- **Primary**: Tailscale mesh VPN (MagicDNS enabled) — all nodes reachable by hostname
- **Fallback**: WireGuard (emergency access only)
- **Policy**: Everything private by default; public only via Nexus NPM

---

## 4. Domain Architecture — shannonjlove.cloud

All services on `*.shannonjlove.cloud`. DNS managed at Cloudflare.

| Subdomain | Destination | Service | Notes |
|-----------|-------------|---------|-------|
| agent | 10.88.0.88:80 | Agent service | |
| bookstack | bookstack:80 | BookStack wiki | Documentation |
| claudedashboard | claudedashboard.shannonjlove.cloud:80 | Claude dashboard | |
| dashboard | 72.61.74.250:80 | Dashboard | HTTP only |
| docs | 10.91.0.12:8000 | Paperless-ngx | Document management |
| filebrowser | 10.88.0.1:8788 | File Browser | |
| github-mcp | 10.89.2.9:8082 | GitHub MCP server | |
| hostinger-mcp | sjl-hostinger-mcp:8000 | Hostinger MCP | |
| jellyfin | host.containers.internal:8096 | Jellyfin | Media server |
| mcp | 10.88.0.16:7300 | MCP server | |
| n8n | 10.89.2.182:5678 | n8n | Workflow automation |
| nexus | 72.61.74.250 | Nexus VPS | |
| oracle-mcp | sjl-oracle-mcp:8000 | Oracle MCP | |
| push | 72.61.74.250:8787 | Push service | |
| rclonegui | rclone-gui:5572 | rclone GUI | |
| sjl-mcp | 72.61.74.250:8797 | SJL MCP | |
| ticktick-mcp | 10.89.2.1:8766 | TickTick MCP | |
| webtop | 100.67.229.94:3000 | WebTop desktop | Oracle sOs via Tailscale |

Full NPM config: `02-CONTAINERS/nginx-proxy-manager/proxy-hosts.yaml`

---

## 5. WebTop (Oracle sOs)

WebTop is a browser-accessible Linux desktop running on Oracle sOs as a rootless Podman container.

| Property | Value |
|----------|-------|
| Public URL | `https://webtop.shannonjlove.cloud` |
| Image | `lscr.io/linuxserver/webtop:ubuntu-mate` |
| Desktop | Ubuntu MATE |
| Streaming | Selkies (KasmVNC) |
| Container HTTP port | `3000` |
| Container HTTPS port | `3001` |
| Quadlet file | `/etc/containers/systemd/webtop.container` |
| Config volume (current) | `/srv/sjl/300000_AREAS/390000_oracle-webtop/config` |
| Config volume (original, orphaned) | `/home/ubuntu/.local/share/webtop/config` |
| Service | `systemctl --user start\|stop\|restart webtop.service` |
| Auth user | `shannonjlove@mac.com` |
| Auth config | `/home/ubuntu/.config/webtop/` (mode 0700) |

**Routing:** `webtop.shannonjlove.cloud` → NPM on Nexus → Tailscale → `100.67.229.94:3000`

**NPM settings for WebTop:** WebSockets enabled, `proxy_read_timeout 3600s`, `proxy_buffering off`, Force SSL, HTTP/2.

**TLS cert:** Let's Encrypt, valid Jun 21 – Sep 19, 2026.

**Known issue — orphaned config:** The original config (`/home/ubuntu/.local/share/webtop/config`) was the data directory when the container ran as a user-level rootless Quadlet (`~/.config/containers/systemd/`). When migrated to a system-level Quadlet (`/etc/containers/systemd/`) and the image changed from `ubuntu-xfce` to `ubuntu-mate`, the volume path changed to `/srv/sjl/300000_AREAS/390000_oracle-webtop/config`. Browser profiles, bookmarks, and desktop settings from the original deployment are still on disk at the old path but are no longer mounted.

**Daily backup:** `/usr/local/sbin/sjl-webtop-backup.sh` runs via `webtop-backup.timer` at 02:30 UTC. Archives to `/srv/sjl/500000_ARCHIVES/590000_oracle-webtop-backups/`. Retention: 7 days.

---

## 6. Key File Paths

### On Nexus (Hostinger VPS)

| Path | Purpose |
|------|---------|
| `/etc/nginx/` | Not used — NPM manages nginx via Docker volume |
| `npm-data` Docker volume | NPM proxy host config, DB |
| `npm-letsencrypt` Docker volume | Let's Encrypt certs |

### On Oracle sOs

| Path | Purpose |
|------|---------|
| `/etc/containers/systemd/webtop.container` | WebTop Quadlet definition |
| `/srv/sjl/300000_AREAS/390000_oracle-webtop/config` | WebTop live config volume |
| `/home/ubuntu/.local/share/webtop/config` | **Orphaned** original config (recoverable) |
| `/home/ubuntu/.config/webtop/` | Auth credentials (0700, not in version control) |
| `/srv/sjl/500000_ARCHIVES/590000_oracle-webtop-backups/` | Daily backup archives |
| `/usr/local/sbin/sjl-webtop-backup.sh` | Backup script |
| `/etc/systemd/system/webtop-backup.timer` | Daily backup timer (02:30 UTC) |
| `/srv/sjl/70000_SYSTEM-AUTOMATION/76000_documentation/` | Documentation source files |

---

## 7. Services Inventory

| Service | Host | Runtime | Status |
|---------|------|---------|--------|
| Nginx Proxy Manager | Nexus | Docker | Active |
| BookStack | Nexus | Docker | Active |
| Paperless-ngx | Nexus | Docker | Active |
| Jellyfin | Nexus | Docker | Active |
| n8n | Nexus | Docker | Active |
| File Browser | Nexus | Docker | Active |
| rclone GUI | Nexus | Docker | Active |
| SJL MCP suite | Nexus | Docker | Active |
| WebTop (Ubuntu MATE) | Oracle sOs | Rootless Podman Quadlet | Active |

---

## 8. Documentation

| System | Location |
|--------|----------|
| BookStack wiki | `https://bookstack.shannonjlove.cloud` |
| BookStack book | "SJL Cloud Infrastructure" |
| WebTop deployment doc | BookStack page 485 (`76000_2026-06-21__ORACLE-WEBTOP-ACCESS`) |
| Repo | `shannonjlove/Hybrid-Personal-Cloud-Server-Infrastructure` |
| NPM proxy config | `02-CONTAINERS/nginx-proxy-manager/proxy-hosts.yaml` |
| Troubleshooting | `05-DOCS/troubleshooting.md` |

---

## 9. Conventions

- **PARA structure**: `000-099` Projects, `100-399` Areas, `400-499` Resources, `500-599` Archives on `/srv/sjl/`
- **Naming**: `[PPPPP]_YYYY-MM-DD__DOCID__title-slug__vX-Y.ext`
- **No secrets in repo**: Credentials stay in `.env`, `EnvironmentFile=`, or `~/.config/webtop/`
- **Tailscale-first**: Always prefer Tailscale for inter-node communication; direct IPs are fallback only

---

## 10. Recovery Quick Reference

| Scenario | Command |
|----------|---------|
| Restart WebTop | `ssh ubuntu@sOs` → `systemctl --user restart webtop.service` |
| Check WebTop status | `systemctl --user is-active webtop.service && podman ps --filter name=webtop` |
| Force backup | `sudo systemctl start webtop-backup.service` |
| List backups | `ls -lh /srv/sjl/500000_ARCHIVES/590000_oracle-webtop-backups/` |
| NPM admin | `http://nexus.shannonjlove.cloud:81` |
| Recover orphaned config | `cp -a /home/ubuntu/.local/share/webtop/config/. /srv/sjl/300000_AREAS/390000_oracle-webtop/config/` |
