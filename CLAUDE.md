# SJL Hybrid Cloud — Claude Code Project Memory

**Owner:** Shannon Jeffrey Love
**Full context file:** `docs/llm-context.md` — read this for any task involving live infrastructure.

---

## Quick Reference

### Servers
| Node | Role | Access |
|------|------|--------|
| Nexus (Hostinger) | Public edge, Docker, NPM | `ssh nexus` / `72.61.74.250` |
| sOs (Oracle ARM64) | Private compute, WebTop | `ssh ubuntu@sOs` / Tailscale `100.67.229.94` |

### Critical paths on Oracle sOs
- WebTop Quadlet: `/etc/containers/systemd/webtop.container`
- WebTop config (live): `/srv/sjl/300000_AREAS/390000_oracle-webtop/config`
- WebTop config (orphaned original): `/home/ubuntu/.local/share/webtop/config`
- Backup script: `/usr/local/sbin/sjl-webtop-backup.sh`
- Backup timer: `webtop-backup.timer` (02:30 UTC daily)
- Backup archives: `/srv/sjl/500000_ARCHIVES/590000_oracle-webtop-backups/`

### Services
- Reverse proxy: **Nginx Proxy Manager** on Nexus (admin: `:81`) — Traefik is gone
- WebTop: `https://webtop.shannonjlove.cloud` → NPM → Tailscale → `100.67.229.94:3000`
- BookStack: `https://bookstack.shannonjlove.cloud`
- Paperless-ngx: `https://docs.shannonjlove.cloud`
- All 17 NPM proxy hosts: `02-CONTAINERS/nginx-proxy-manager/proxy-hosts.yaml`

### BookStack API (for searching docs programmatically)
- URL: `https://bookstack.shannonjlove.cloud`
- Token stored in: `~/.claude/CLAUDE.md` (user-level memory, not in repo)
- Usage: `curl -H "Authorization: Token ID:SECRET" "https://bookstack.shannonjlove.cloud/api/search?query=..."`

---

## Repo Layout
```
00-MASTER-ARCHITECTURE/   system overview, infra map
01-DEPLOYMENT/            node provisioning (oracle/, hostinger/, aws/, gcp/)
02-CONTAINERS/            service configs
  nginx-proxy-manager/    NPM README + proxy-hosts.yaml (all 17 hosts)
  nginx/                  CLI nginx mgmt script for Oracle sOs
  webtop/                 WebTop backup script + systemd units
  traefik/                DEPRECATED — replaced by NPM
03-AUTOMATION/            tagging, routing, metadata
04-SECURITY/              Tailscale, WireGuard, secrets
05-DOCS/                  troubleshooting.md, full-system-manual.md
06-OPS/                   approvals, runbooks
docs/
  llm-context.md          FULL infrastructure context for any LLM
.claude/commands/
  nginx-proxy.md          /nginx-proxy skill — manage nginx on sOs
```

---

## Rules
- No secrets committed to git (tokens, passwords, SSH keys)
- Tailscale-first for inter-node traffic
- Public exposure requires approval (`06-OPS/approvals/POLICY.md`)
- WebTop lifecycle: `systemctl --user [start|stop|restart] webtop.service` (not `enable`)
- Container runtime: Podman + Quadlet on Oracle; Docker + compose on Nexus
