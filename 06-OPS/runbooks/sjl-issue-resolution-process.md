# SJL Issue Resolution Process — Canonical Template

**Status:** Active canonical standard. Applies to all infrastructure issues, all services, all sessions.

---

## The Rule (Non-Negotiable)

Before recommending **any** fix for **any** problem:

1. **Analyze system logs, configs, and incident history FIRST**
2. **Research** — official docs, GitHub issues, changelogs, real solved community threads
3. **Cross-reference** against the actual SJL infrastructure state
4. **Dry run** — simulate every change before executing
5. **Only then** present commands to the user

No guessing. No "try this, try that." Every recommendation must be grounded in evidence already present in the system or authoritative external sources.

---

## Phase 1 — Evidence Collection

Before touching anything, collect:

### System Logs
```bash
# Systemd services
journalctl -u SERVICE_NAME -n 100 --no-pager
journalctl -u SERVICE_NAME --since "1 hour ago" --no-pager

# Podman containers
sudo -iu sjl podman logs CONTAINER_NAME --tail 200

# Docker containers
sudo docker logs CONTAINER_NAME --tail 200

# Kernel / system events
journalctl -k --since "24 hours ago" --no-pager | tail -50
```

### Configuration Files
```bash
# Active port bindings (always check before recommending a port)
ss -ltnp

# Systemd unit state
systemctl cat SERVICE_NAME
systemctl show SERVICE_NAME

# Environment (never print — note path only)
ls -la /etc/sjl-*/runtime.env
```

### Incident History
- Review `git log` on the infrastructure repo
- Check `06-OPS/runbooks/` for prior incidents
- Review session history for this service

---

## Phase 2 — Research

Search in this order:

1. **Official SDK/API documentation** — changelog, migration guides, known issues
2. **GitHub issue tracker** — search by error message, version, transport type
3. **Community** — forums, Stack Overflow, Discord — look for threads with confirmed working solutions, not just suggestions

**Do not present a fix based on a guess or a single unverified suggestion.**

---

## Phase 3 — Solution Design

1. **Cross-reference** — map the proposed fix to the actual SJL infrastructure:
   - Which ports are in use? (run `ss -ltnp` first)
   - Which services depend on what?
   - Does this touch anything near the protected services?
2. **Minimal surgical fix** — smallest possible change, no unrelated cleanup
3. **Rollback plan** — every change must have an explicit undo command
4. **Dry run** — simulate the change, verify expected output, confirm no side effects

Present the dry run output before asking for execution.

---

## Phase 4 — Validation

After every change, validate in this order:

```bash
# 1. Service status
systemctl status SERVICE_NAME --no-pager

# 2. Port / bind
ss -ltnp | grep PORT

# 3. Protocol-level probe (MCP)
python3 - <<'PY'
import json, urllib.request, sys
url = "http://127.0.0.1:PORT/mcp"
init = {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"v","version":"1"}}}
req = urllib.request.Request(url, data=json.dumps(init).encode(), headers={"Content-Type":"application/json","Accept":"application/json, text/event-stream"}, method="POST")
try:
    with urllib.request.urlopen(req, timeout=15) as r:
        sid = r.headers.get("Mcp-Session-Id","")
        r.read()
except Exception as e:
    print(f"INIT FAILED: {e}"); sys.exit(1)
req2 = urllib.request.Request(url, data=json.dumps({"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}).encode(), headers={"Content-Type":"application/json","Accept":"application/json, text/event-stream","Mcp-Session-Id":sid}, method="POST")
with urllib.request.urlopen(req2, timeout=15) as r:
    raw = r.read().decode()
tools = []
for line in raw.splitlines():
    line = line.strip()
    if line.startswith("data:"):
        try:
            obj = json.loads(line[5:])
            tools = [t["name"] for t in obj.get("result",{}).get("tools",[])]
        except: pass
print(f"Tools ({len(tools)}): {tools}")
PY

# 4. End-to-end tool test (via connector)
```

---

## Phase 5 — Document and Archive

After every resolved issue:

1. **Commit to repo** — update the relevant runbook, commit with descriptive message, push to branch
2. **BookStack** — upsert the canonical page via `bookstack_page_upsert` tool on the unified gateway
3. **Paperless NGX** — file the incident report, tag appropriately
4. **Update architecture diagram** — reflect the new state in `06-OPS/diagrams/`

---

## Protected Services — Hard Constraints

| Service | Port | Constraint |
|---|---|---|
| `sjl-cloud-access-mcp-rw.service` | `127.0.0.1:8777` | **NEVER stop, restart, or modify** |
| Any service on `8777` | loopback | Guarded write gateway — hands off |

---

## Port Allocation — Always Check Before Assigning

```bash
ss -ltnp | grep -E ':(87[0-9]{2}|88[0-9]{2})' | sort
```

Never recommend a port without running this check first.

---

## Secret Handling — Absolute Rules

- Never print API tokens, private keys, or session secrets in any output
- Never commit secrets to Git
- Never include secrets in runbooks, handoff docs, or logs
- Reference by file path only: `/opt/secrets/…`, `/etc/sjl-unified-mcp/runtime.env`
- Always use read-only volume mounts for cloud credential files

---

## Diagram

See: `06-OPS/diagrams/sjl-issue-resolution-process.mmd`

---

*This document is the canonical process template. All future issue resolution must follow it.*
