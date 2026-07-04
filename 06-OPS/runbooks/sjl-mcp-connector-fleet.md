# SJL MCP Connector Fleet — Architecture, Health and Recovery

**Last updated:** 2026-07-03  
**Canonical reference:** This document is the single source of truth for all MCP connector state.

---

## Architecture Overview

The SJL MCP fleet exposes cloud infrastructure tools to AI clients (ChatGPT, Claude) through a layered gateway architecture on a single Hostinger VPS.

```
AI Clients (ChatGPT / Claude)
        │
        ▼
ChatGPT Connector Registrations
        │
        ▼
Hostinger VPS — 72.61.74.250 — shannonjlove
        │
        ├── sjl-unified-mcp.service (port 8799) ← TARGET: all connectors point here
        ├── sjl-cloud-access-mcp.service (port 8797) ← LEGACY: decommission after migration
        └── sjl-cloud-access-mcp-rw.service (port 8777) ← PROTECTED: never touch
```

---

## Port Map

| Port | Bind | Process | Service | Status | Action |
|---|---|---|---|---|---|
| 8777 | 127.0.0.1 | python | sjl-cloud-access-mcp-rw.service | **PROTECTED** | NEVER TOUCH |
| 8797 | 0.0.0.0 | python | sjl-cloud-access-mcp.service | Legacy | Decommission after migration |
| 8798 | 127.0.0.1 | python | 76500_oci-mcp-rw | Legacy standalone OCI | Decommission after validation |
| 8799 | 0.0.0.0 | python | sjl-unified-mcp.service | **Active — 17 tools** | TARGET |
| 8811 | 127.0.0.1 | unknown | unknown | Unidentified | Audit required |
| 8812 | 127.0.0.1 | unknown | unknown | Unidentified | Audit required |
| 8766 | 0.0.0.0 | python | likely TickTick MCP | Unconfirmed | Verify |
| 8786 | 0.0.0.0 | uvicorn | unknown | Unidentified | Audit required |

---

## Connector Registrations (ChatGPT)

| Registration Name | Target URL | Backend | Status | Action |
|---|---|---|---|---|
| SJL Unified Cloud MCP V2 | `http://72.61.74.250:8797/mcp` | sjl-cloud-access-mcp | Degraded — migrate | **Point to 8799** |
| SJL Unified Cloud MCP | `http://72.61.74.250:8797/mcp` | sjl-cloud-access-mcp | Duplicate | Retire after V2 migrated |
| SJL Oracle MCP | unknown | sjl-oracle-mcp container | Broken — no OCI mount | Fix container mount |

**Connector migration step:**  
Change `SJL Unified Cloud MCP V2` URL to: `http://72.61.74.250:8799/mcp`

---

## New Unified Gateway (sjl-unified-mcp — port 8799)

**17 confirmed tools:**

| Tool | Domain | Write-Gated |
|---|---|---|
| `gateway_health` | System | No |
| `vps_local_status` | System | No |
| `hostinger_api_probe` | Hostinger | No |
| `hostinger_podman_list` | Podman | No |
| `hostinger_podman_action` | Podman | Yes |
| `hostinger_user_service_status` | Systemd | No |
| `hostinger_user_service_action` | Systemd | Yes |
| `oracle_identity_test` | OCI | No |
| `oracle_instances_list` | OCI | No |
| `oracle_instance_action` | OCI | Yes |
| `google_compute_instances_list` | GCP | No |
| `google_instance_action` | GCP | Yes |
| `google_service_enable` | GCP | Yes |
| `bookstack_page_upsert` | BookStack | Yes |
| `filesystem_list` | Filesystem | No |
| `filesystem_read_text` | Filesystem | No |
| `filesystem_write_text` | Filesystem | Yes |

**Runtime files:**
```
Application:     /opt/sjl-unified-mcp/
Config:          /etc/sjl-unified-mcp/runtime.env
Secrets:         /opt/secrets/sjl-unified-mcp/
OCI config:      /opt/secrets/oci/config
OCI key:         /opt/secrets/oci/oci_api_key.pem
GCP credentials: /opt/secrets/sjl-unified-mcp/google-service-account.json
Write token:     /root/.sjl-unified-mcp-write-token
Systemd unit:    sjl-unified-mcp.service
```

**Health check:**
```bash
systemctl status sjl-unified-mcp.service --no-pager
ss -ltnp | grep 8799
```

**Restart (only if needed — not 8777):**
```bash
systemctl restart sjl-unified-mcp.service
```

---

## Cloud Provider Status

### Oracle Cloud
- Tenancy: lovecloud
- Home region: us-ashburn-1
- Auth: Working via unified gateway
- OCI config: `/opt/secrets/oci/config` (mode 640, root:sjlmcp)
- Inventory: 1 instance, 1 VCN, 1 subnet, 1 boot volume
- OCID: `ocid1.instance.oc1.iad.anuwcljsnyncf7yc2fta5ymmyy5uphdf7xog6ofw5sbjszd5i5cs4gxw3vqa`

### Google Cloud
- Project: resourcespace-nexus
- Service account: `sjl-cloud-access-mcp@resourcespace-nexus.iam.gserviceaccount.com`
- Credentials: `/opt/secrets/sjl-unified-mcp/google-service-account.json`
- Storage API: Working
- Compute Engine API (`compute.googleapis.com`): **DISABLED** — decision required
- IAM API (`iam.googleapis.com`): **DISABLED** — decision required

### Hostinger
- VPS ID: 1174666
- API token: present in runtime.env
- API base: `https://developers.hostinger.com`
- Status: 404 on probe — API path needs verification

---

## Rootless Podman Fleet (user: sjl)

**Current status: BROKEN — `cannot clone: Operation not permitted`**

Root cause: Kernel updated (23 pending updates + restart required), Podman pause process running against old kernel. User-namespace clone rules changed.

Fix requires:
1. Confirm kernel mismatch via diagnostics
2. `podman system migrate` (if no destructive containers running) OR controlled reboot
3. See dedicated runbook section

**Known containers:**
`webtopsjl`, `memory-platform`, `sjl-hookvault`, `sjl-filewarden`, `sjl-diffforge`, `mcp-filesystem`, `sjl-file-api`, `rclone-mcp`, `rclone-gui`, `rclone-rc`, `ops-agent`, `portainer`, `webtop`, `sjl-hostinger-mcp`, `sjl-oracle-mcp`, `sjl-controlled-admin`, `sjl-filesystem-mcp`, `sjl-mcp-gateway`, `ai-supervisor`, `ai-brain`, `proxy-agent`, `mcp-apple-docs`, `mcp-ios-sim`, `mcp-mobile`, `mcp-memory`, `github-mcp`, `resourcespace-db`, `resourcespace`, `paperless-*`, `bookstack`, `bookstack-db`, `jellyfin`, `stash`, `n8n`, `n8n-postgres`, `n8n-redis`, `nginx-proxy-manager`, `pcloud`, `dropbox`

---

## Write Control Policy

All write operations require:
1. The exact `WRITE_APPROVAL_TOKEN` value (stored at `/root/.sjl-unified-mcp-write-token`)
2. The target must be in its respective `ALLOWED_*` list in `runtime.env`

No arbitrary shell execution is exposed. Allowlists must be populated with exact names before writes succeed.

---

## Migration Checklist

- [ ] Point `SJL Unified Cloud MCP V2` to `http://72.61.74.250:8799/mcp`
- [ ] Validate 17 tools and one `gateway_health` write through live connector
- [ ] Stop and disable `sjl-cloud-access-mcp.service` (port 8797)
- [ ] Stop and disable `76500_oci-mcp-rw` (port 8798)
- [ ] Remove `SJL Unified Cloud MCP` (V1) connector registration
- [ ] Remove `SJL Oracle MCP` connector registration (after container fixed or retired)
- [ ] Keep old service files backed up until rollback window closes

---

## Recovery Commands

```bash
# Restart unified gateway (safe)
systemctl restart sjl-unified-mcp.service

# View unified gateway logs
journalctl -u sjl-unified-mcp.service -n 50 --no-pager

# Check all MCP-range ports
ss -ltnp | grep -E ':(87[0-9]{2}|88[0-9]{2})' | sort

# Podman diagnostics (read-only)
sudo -iu sjl podman info
sudo -iu sjl podman ps -a

# NEVER run without explicit approval
# podman system reset
# systemctl stop sjl-cloud-access-mcp-rw.service
```

---

## Diagrams

- Process: `06-OPS/diagrams/sjl-issue-resolution-process.mmd`
- Fleet architecture: `06-OPS/diagrams/sjl-mcp-fleet-architecture.mmd`
