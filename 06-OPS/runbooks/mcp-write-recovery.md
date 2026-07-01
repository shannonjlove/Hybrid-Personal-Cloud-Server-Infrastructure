# Runbook: MCP Write Access Recovery (Hostinger VPS)

**Applies to:** `sjl-cloud-access-mcp.service` (port `8797`) on `shannonjlove.cloud`
**Canonical script:** `03-AUTOMATION/mcp-repair/760000_2026-07-01__SJL-MCP__guarded-restore-write-access__v3-2.sh`
**Canonical script SHA-256:** `88bf77fe5ce39e571665a7246504536fc72059741659b5aad6eb6f36d38fb513`
**Symptom:** Public MCP endpoint reports `readonly=true` or exposes fewer than 23 tools.

---

## Overview

The SJL Unified Cloud MCP V2 architecture runs two systemd user services under the `sjl` account:

| Service | Port | Role |
|---------|------|------|
| `sjl-unified-cloud-mcp-rw.service` | `127.0.0.1:8777` | Guarded read/write backend — **never restart this** |
| `sjl-cloud-access-mcp.service` | `0.0.0.0:8797` | Public gateway — this is what gets repaired |

The public gateway's `server.py` was overwritten with a read-only variant during a June 2026 incident. The repair script (v3.2) recovers the pre-incident `server.py` from filesystem backups, stages it on port `18897` with full MCP session-aware validation, and atomically promotes it.

**Constraints (never violate):**
- Never stop, restart, or modify `sjl-unified-cloud-mcp-rw.service` (port 8777)
- Only `sjl-cloud-access-mcp.service` (port 8797) is restarted during repair
- No mutation before complete backup and live preflight validation
- Rollback is automatic on any post-mutation failure

---

## Incident history

The June 2026 write-access loss occurred in two stages:

- **Stage A (June 25, ~08:09 UTC):** The sudo-backed write route was removed from `server.py`. Best candidate for recovery: `server.py.20260625T080902Z.before-remove-sudo` (11,658 bytes, created just before the `remove-sudo` change).
- **Stage B (June 26, 06:21–08:33 UTC):** Emergency recovery restored availability with a smaller read-only server. The full write-enabled source and `gcp_tools` module were not restored.

---

## Pre-execution checklist

SSH to the Hostinger VPS as root and run every check. Abort if any fails.

```bash
APP=/srv/sjl/70000_SYSTEM-AUTOMATION/76000_mcp-cloud-access/app
UNIT=sjl-cloud-access-mcp.service
SJL_USER=sjl
UID_SJL="$(id -u "$SJL_USER")"

# 1. Confirm host identity
hostnamectl
date -u --iso-8601=seconds
uname -a

# 2. Resources
df -hT /
free -h

# 3. Confirm source and interpreter exist
ls -la "$APP"
stat "$APP/server.py"
sha256sum "$APP/server.py"
"$APP/venv/bin/python" -V 2>/dev/null || true
"$APP/.venv/bin/python" -V 2>/dev/null || true

# 4. Confirm June 24-26 candidates exist
find "$APP" -maxdepth 1 -type f -name 'server.py.*' \
  -newermt '2026-06-24 00:00:00Z' ! -newermt '2026-06-27 00:00:00Z' \
  -printf '%TY-%Tm-%TdT%TH:%TM:%TSZ %s %p\n' | sort

# 5. Confirm gcp_tools is present
find "$APP" -maxdepth 3 \
  \( -type f -name 'gcp_tools.py' -o -type d -name 'gcp_tools' \) -print

# 6. Confirm both services are active
sudo -u "$SJL_USER" env \
  XDG_RUNTIME_DIR="/run/user/$UID_SJL" \
  DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$UID_SJL/bus" \
  systemctl --user status "$UNIT" --no-pager

# 7. Confirm ports
ss -ltnp | grep -E ':(8777|8797|18897)\b' || true
```

**Abort without mutation if:**
- Live service is down before work begins
- Either interpreter (`venv/bin/python`, `.venv/bin/python`) is absent
- Port `18897` is occupied by an unknown process
- June 24–26 candidates are absent
- This is not the intended Hostinger host
- The unit points to another application tree
- Disk or memory conditions make safe staging impossible

---

## Install the v3.2 script on VPS

From the WebTop terminal or any machine with repo access:

```bash
# Download directly from GitHub
curl -fsSL \
  "https://raw.githubusercontent.com/shannonjlove/Hybrid-Personal-Cloud-Server-Infrastructure/claude/mcp-webtop-reconnect-gngmmx/03-AUTOMATION/mcp-repair/760000_2026-07-01__SJL-MCP__guarded-restore-write-access__v3-2.sh" \
  -o /tmp/v3-2.sh

# Verify SHA
sha256sum /tmp/v3-2.sh
# Must equal: 88bf77fe5ce39e571665a7246504536fc72059741659b5aad6eb6f36d38fb513

# Install
bash -n /tmp/v3-2.sh && echo "Syntax OK"
install -o root -g root -m 0700 /tmp/v3-2.sh \
  /root/760000_2026-07-01__SJL-MCP__guarded-restore-write-access__v3-2.sh
```

---

## Execution (two-phase: audit then apply)

### Phase 1 — Audit (safe, no mutation)

```bash
sudo bash /root/760000_2026-07-01__SJL-MCP__guarded-restore-write-access__v3-2.sh --audit
```

Evidence is written to `/root/backups/sjl-mcp-revised-fix/<UTC-STAMP>/`. Review:

```
run.log          candidates.tsv      *.static.json
*.stage.log      *.tools.json        selected.txt
server.py.live   live.sha256         listeners-before.txt
sjl-cloud-access-mcp.service.cat.txt
sjl-cloud-access-mcp.service.show.txt
```

**The audit must print `AUTOMATIC PROMOTION ELIGIBLE` before proceeding.**

Expected preferred candidate: `server.py.20260625T080902Z.before-remove-sudo`

**Stop (do not apply) if any of these appear:**
```
SCHEMA_UNRESOLVED
CALL_FAILED
NO_EXACT_WRITE_HEALTH_TOOL
missing imports
direct execution primitives detected
failed to bind staging port
```

Also stop if:
- Selected file is the 597-byte stub or the known 6,198-byte broken copy
- Staging binds publicly
- Port `18897` remains occupied after staging
- Arbitrary shell execution is exposed
- Audit does not declare automatic promotion eligibility

### Phase 2 — Manual candidate review

```bash
RUN=/root/backups/sjl-mcp-revised-fix/<timestamp>
SELECTED="$(cat "$RUN/selected.txt")"
LIVE=/srv/sjl/70000_SYSTEM-AUTOMATION/76000_mcp-cloud-access/app/server.py

diff -u "$LIVE" "$SELECTED" | less

grep -nE \
  '8777|8797|write_access_health|controlled_write_health|approval|token|sudo|subprocess|os\.system|bookstack_(create|update|upsert)' \
  "$SELECTED"
```

Document before applying:
- Authorization and approval logic
- Guarded-backend routing
- All sudo and subprocess use
- Whether arbitrary command text can reach execution
- BookStack write registrations
- Whether read-only remains the default state
- Whether port `8777` is loopback-only

### Phase 3 — Apply (only after both audit and review pass)

```bash
sudo bash /root/760000_2026-07-01__SJL-MCP__guarded-restore-write-access__v3-2.sh --apply
```

The script will:
1. Back up current production `server.py`
2. Install the validated candidate atomically
3. Restart `sjl-cloud-access-mcp.service`
4. Initialize a fresh production MCP session
5. List production tools
6. Execute the exact write-health tool
7. Roll back automatically if validation fails

---

## Post-repair validation

```bash
APP=/srv/sjl/70000_SYSTEM-AUTOMATION/76000_mcp-cloud-access/app
UNIT=sjl-cloud-access-mcp.service
UID_SJL="$(id -u sjl)"

sudo -u sjl env \
  XDG_RUNTIME_DIR="/run/user/$UID_SJL" \
  DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$UID_SJL/bus" \
  systemctl --user status "$UNIT" --no-pager

ss -ltnp | grep -E ':(8777|8797|18897)\b' || true
sha256sum "$APP/server.py"

# Confirm write tools visible on public gateway
python3 - <<'PY'
import json, urllib.request
url = "http://127.0.0.1:8797/mcp"
init = {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"validation","version":"1.0"}}}
req = urllib.request.Request(url, data=json.dumps(init).encode(), headers={"Content-Type":"application/json","Accept":"application/json, text/event-stream"}, method="POST")
with urllib.request.urlopen(req, timeout=10) as r:
    sid = r.headers.get("Mcp-Session-Id")
    r.read()
req2 = urllib.request.Request(url, data=json.dumps({"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}).encode(), headers={"Content-Type":"application/json","Accept":"application/json, text/event-stream","Mcp-Session-Id":sid or ""}, method="POST")
with urllib.request.urlopen(req2, timeout=10) as r:
    body = r.read().decode()
names = [l.split('"')[1] for l in body.splitlines() if '"name"' in l and ("write" in l.lower() or "bookstack" in l.lower())]
print(f"8797 write-related tools: {names[:10]}")
print(f"Total tools in response: {body.count('\"name\"')}")
PY
```

Review evidence files:
```
production-before.json    production-after.json
live-after.sha256         listeners-after.txt
sjl-cloud-access-mcp.service.status-after.txt
```

---

## Success criteria (all required)

- `sjl-unified-cloud-mcp-rw.service` active.
- `sjl-cloud-access-mcp.service` active.
- Port `8777` bound to loopback only.
- Port `8797` listening publicly.
- Port `18897` free (no staging process remains).
- `8797` exposes more than 22 tools (≥ 50 expected).
- `write_access_health` or `controlled_write_health` passes on production.
- `bookstack_create_page`, `bookstack_update_page`, or `bookstack_upsert_page` present.
- No broad sudoers policy was introduced.
- Read operations still work.
- Tool inventory was not unexpectedly reduced.

---

## Manual rollback (if script rollback did not trigger)

```bash
RUN=/root/backups/sjl-mcp-revised-fix/<timestamp>
APP=/srv/sjl/70000_SYSTEM-AUTOMATION/76000_mcp-cloud-access/app
UID_SJL="$(id -u sjl)"

install -o sjl -g sjl -m 0750 \
  "$RUN/server.py.live" \
  "$APP/server.py"

sudo -u sjl env \
  XDG_RUNTIME_DIR="/run/user/$UID_SJL" \
  DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$UID_SJL/bus" \
  systemctl --user restart sjl-cloud-access-mcp.service

sudo -u sjl env \
  XDG_RUNTIME_DIR="/run/user/$UID_SJL" \
  DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$UID_SJL/bus" \
  systemctl --user status sjl-cloud-access-mcp.service --no-pager
```

Verify the prior read-only endpoint returns before declaring done.

---

## WebTop operator path

If you cannot SSH to the VPS directly, use the WebTop:

1. Open `https://webtop.shannonjlove.cloud` (or Tailscale IP `100.67.229.94:3000`).
2. Open terminal.
3. Run `~/setup-claude-code.sh` if Claude Code is not installed.
4. Download and run the repair script via the SSH alias `hostinger-sjl`:
   ```bash
   ssh hostinger-sjl 'curl -fsSL "https://raw.githubusercontent.com/shannonjlove/Hybrid-Personal-Cloud-Server-Infrastructure/claude/mcp-webtop-reconnect-gngmmx/03-AUTOMATION/mcp-repair/760000_2026-07-01__SJL-MCP__guarded-restore-write-access__v3-2.sh" -o /tmp/v3-2.sh && bash -n /tmp/v3-2.sh && install -o root -g root -m 0700 /tmp/v3-2.sh /root/760000_2026-07-01__SJL-MCP__guarded-restore-write-access__v3-2.sh'
   ssh hostinger-sjl 'sudo bash /root/760000_2026-07-01__SJL-MCP__guarded-restore-write-access__v3-2.sh --audit'
   # Review output; if AUTOMATIC PROMOTION ELIGIBLE:
   ssh hostinger-sjl 'sudo bash /root/760000_2026-07-01__SJL-MCP__guarded-restore-write-access__v3-2.sh --apply'
   ```

---

## Related files

| File | Purpose |
|------|---------|
| `03-AUTOMATION/mcp-repair/760000_2026-07-01__SJL-MCP__guarded-restore-write-access__v3-2.sh` | **Canonical repair script (v3.2)** |
| `03-AUTOMATION/mcp-repair/guarded-repair-v1.7.sh` | Historical only — superseded by v3.2 |
| `02-CONTAINERS/webtop/docker-compose.webtop.yml` | WebTop container definition |
| `02-CONTAINERS/webtop/config/setup-claude-code.sh` | Claude Code bootstrap for WebTop |
| `02-CONTAINERS/webtop/config/claude-code-mcp.json` | MCP server config template |

---

## If repair fails

The script rolls back automatically. Examine the log:

```bash
cat /root/backups/sjl-mcp-revised-fix/<STAMP>/run.log | tail -80
```

Common failure modes:

| Symptom | Cause | Resolution |
|---------|-------|------------|
| `NO_EXACT_WRITE_HEALTH_TOOL` | Staged server lacks `controlled_write_health` / `write_access_health` | Selected candidate is wrong — check candidates.tsv for alternate; consult Oracle DR copy |
| `CALL_FAILED` | Write-health tool call returned error | Check stage.log for Python tracebacks; verify gcp_tools module is present in `$APP` |
| `SCHEMA_UNRESOLVED` | Tool input schema has unresolvable required fields | Manual schema review needed; candidate may need companion module |
| `failed to bind staging port` | Port 18897 occupied | Find and kill the blocking process: `ss -ltnp \| grep 18897` |
| Candidates absent | No June 24–26 server.py backups found | Locate write-enabled source manually; check Oracle DR copy or git history |
