# Runbook: MCP Write Access Recovery (Hostinger VPS)

**Applies to:** `sjl-cloud-access-mcp.service` (port `8797`) on `shannonjlove.cloud`
**Script:** `03-AUTOMATION/mcp-repair/guarded-repair-v1.7.sh`
**Symptom:** Public MCP endpoint reports `readonly=true` or exposes fewer than 23 tools.

---

## Overview

The SJL Unified Cloud MCP V2 architecture runs two systemd user services under the `sjl` account:

| Service | Port | Role |
|---------|------|------|
| `sjl-unified-cloud-mcp-rw.service` | `127.0.0.1:8777` | Guarded read/write backend — **never restart this** |
| `sjl-cloud-access-mcp.service` | `0.0.0.0:8797` | Public gateway — this is what gets repaired |

The public gateway's `server.py` may have been overwritten with a read-only variant. The repair script recovers a write-enabled `server.py` from filesystem backups and Git history, stages it on port `18897`, validates it live, and atomically promotes it.

---

## Pre-execution checklist

SSH to the Hostinger VPS and run every check. Abort if any fails.

```bash
# 1. Confirm host identity
hostnamectl

# 2. Confirm sjl user exists
id sjl

# 3. Confirm both services are active
SJL_UID=$(id -u sjl)
sudo -u sjl env \
  XDG_RUNTIME_DIR=/run/user/${SJL_UID} \
  DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/${SJL_UID}/bus \
  systemctl --user status sjl-cloud-access-mcp.service --no-pager

sudo -u sjl env \
  XDG_RUNTIME_DIR=/run/user/${SJL_UID} \
  DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/${SJL_UID}/bus \
  systemctl --user status sjl-unified-cloud-mcp-rw.service --no-pager

# 4. Confirm ports are listening
ss -ltnp | grep -E ':(8777|8797)\b'

# 5. Confirm the source file exists
test -f /srv/sjl/70000_SYSTEM-AUTOMATION/76000_mcp-cloud-access/app/server.py && echo OK

# 6. Confirm staging port is free
ss -ltnp | grep -v '8(777|797)' | grep 18897 && echo "ABORT: 18897 in use" || echo "18897 free"

# 7. Syntax-check the repair script
bash -n /path/to/guarded-repair-v1.7.sh && echo "Syntax OK"

# 8. Verify script SHA-256 matches expected value
sha256sum /path/to/guarded-repair-v1.7.sh
# Expected: a8b404c013d8fc8ed2147622d7ff6ed2f413281ea83012b94948c897474c6509
```

**Abort if:**
- Port `8777` has no listener.
- `sjl-unified-cloud-mcp-rw.service` is not active.
- The `sjl` user bus at `/run/user/<UID>/bus` is not a socket.
- The public source at `/srv/sjl/.../server.py` is missing.
- Port `18897` is already in use.
- Either systemd unit file is missing from `~sjl/.config/systemd/user/`.
- SHA-256 does not match.

---

## Transfer the repair script to the VPS

From your local machine or the WebTop terminal:

```bash
scp 03-AUTOMATION/mcp-repair/guarded-repair-v1.7.sh root@shannonjlove.cloud:/tmp/
# or
ssh hostinger-sjl 'cat > /tmp/guarded-repair-v1.7.sh' < 03-AUTOMATION/mcp-repair/guarded-repair-v1.7.sh
```

---

## Execution

```bash
ssh root@shannonjlove.cloud   # or: ssh hostinger-sjl
sudo bash /tmp/guarded-repair-v1.7.sh
```

The script runs non-interactively and logs to `/root/backups/sjl-mcp-repair/<TIMESTAMP>/repair.log`.

Expected terminal output on success:

```
REPAIR SUCCESSFUL
Report: /root/backups/sjl-mcp-repair/<STAMP>/repair-report.md
Backup directory: /root/backups/sjl-mcp-repair/<STAMP>
Selected candidate: ...
Candidate score: ...
8777 tools: <N>
8797 tools: <N>
Backup archive: /root/backups/sjl-mcp-repair/<STAMP>.tar.gz
```

---

## Post-repair validation

```bash
SJL_UID=$(id -u sjl)

# Services still active
sudo -u sjl env \
  XDG_RUNTIME_DIR=/run/user/${SJL_UID} \
  DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/${SJL_UID}/bus \
  systemctl --user status sjl-cloud-access-mcp.service --no-pager

sudo -u sjl env \
  XDG_RUNTIME_DIR=/run/user/${SJL_UID} \
  DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/${SJL_UID}/bus \
  systemctl --user status sjl-unified-cloud-mcp-rw.service --no-pager

# Ports still bound
ss -ltnp | grep -E ':(8777|8797)\b'

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
names = [l.split('"')[1] for l in body.splitlines() if '"name"' in l and "write" in l.lower() or "bookstack" in l.lower()]
print(f"8797 write-related tools: {names[:10]}")
print(f"Total tools in response: {body.count('\"name\"')}")
PY
```

---

## Success criteria (all required)

- `sjl-unified-cloud-mcp-rw.service` active.
- `sjl-cloud-access-mcp.service` active.
- Port `8777` bound to loopback.
- Port `8797` listening publicly.
- `8797` exposes more than 22 tools.
- `8797` exposes at least 50 tools (default `EXPECTED_MIN_TOOLS`).
- Guarded tools missing from `8797` ≤ 5 (default `MAX_ALLOWED_RW_GAP`).
- `write_access_health` or `controlled_write_health` present when on `8777`.
- `bookstack_create_page`, `bookstack_update_page`, or `bookstack_upsert_page` present when on `8777`.
- Report file states `Result: SUCCESS`.
- Compressed backup archive exists at `/root/backups/sjl-mcp-repair/<STAMP>.tar.gz`.

---

## If repair fails

The script rolls back automatically. Examine the log:

```bash
cat /root/backups/sjl-mcp-repair/<STAMP>/repair.log | tail -60
```

Common failure modes:

| Symptom | Cause | Resolution |
|---------|-------|------------|
| `No high-confidence candidate` | No historical `server.py` found with write signals | Locate the write-enabled source manually; check Oracle DR copy |
| `No candidate passed live staging` | All candidates failed the 50-tool MCP check | Candidate scoring too aggressive; lower `MIN_CANDIDATE_SCORE` |
| `Public service failed after promotion` | `server.py` has import errors at runtime | Check `stage-<sha>.log` for Python tracebacks |
| `8797 remains on the reduced schema` | Promoted file is still the read-only variant | Re-run with broader filesystem search paths |

---

## WebTop operator path

If you cannot SSH to the VPS directly, use the WebTop:

1. Open `https://webtop.shannonjlove.cloud` (or Tailscale IP `100.67.229.94:3000`).
2. Open terminal.
3. Run `~/setup-claude-code.sh` if Claude Code is not installed.
4. Transfer and run the repair script via the SSH alias `hostinger-sjl`:
   ```bash
   scp ~/Desktop/guarded-repair-v1.7.sh hostinger-sjl:/tmp/
   ssh hostinger-sjl 'sudo bash /tmp/guarded-repair-v1.7.sh'
   ```

---

## Related files

| File | Purpose |
|------|---------|
| `03-AUTOMATION/mcp-repair/guarded-repair-v1.7.sh` | Repair script |
| `02-CONTAINERS/webtop/docker-compose.webtop.yml` | WebTop container definition |
| `02-CONTAINERS/webtop/config/setup-claude-code.sh` | Claude Code bootstrap for WebTop |
| `02-CONTAINERS/webtop/config/claude-code-mcp.json` | MCP server config template |
