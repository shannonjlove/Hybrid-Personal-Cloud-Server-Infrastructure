#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

# SJL MCP guarded restoration v3.2
# Default: audit only. Mutation requires --apply.
# Requires an exact, successful write-health tools/call before promotion.

MODE="${1:---audit}"
APP="${APP:-/srv/sjl/70000_SYSTEM-AUTOMATION/76000_mcp-cloud-access/app}"
LIVE="${LIVE:-${APP}/server.py}"
UNIT="${UNIT:-sjl-cloud-access-mcp.service}"
SJL_USER="${SJL_USER:-sjl}"
STAGE_PORT="${STAGE_PORT:-18897}"
PROD_PORT="${PROD_PORT:-8797}"
START_UTC="${START_UTC:-2026-06-24 00:00:00Z}"
END_UTC="${END_UTC:-2026-06-27 00:00:00Z}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="${OUT:-/root/backups/sjl-mcp-revised-fix/${STAMP}}"

VENV_PY="${APP}/venv/bin/python"
[[ -x "$VENV_PY" ]] || VENV_PY="${APP}/.venv/bin/python"

mkdir -p "$OUT"
exec > >(tee -a "$OUT/run.log") 2>&1

say(){ printf '\n== %s ==\n' "$*"; }
die(){ echo "ERROR: $*" >&2; exit 1; }

[[ "$MODE" == "--audit" || "$MODE" == "--apply" ]] ||
  die "Usage: $0 [--audit|--apply]"
[[ -f "$LIVE" ]] || die "Missing live server: $LIVE"
[[ -x "$VENV_PY" ]] || die "No application Python interpreter found"
id "$SJL_USER" >/dev/null 2>&1 || die "Missing service user: $SJL_USER"
command -v setsid >/dev/null 2>&1 || die "setsid is required"
command -v ss >/dev/null 2>&1 || die "ss is required"

SJL_UID="$(id -u "$SJL_USER")"
XDG_RUNTIME_DIR="/run/user/${SJL_UID}"
DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/bus"
export XDG_RUNTIME_DIR DBUS_SESSION_BUS_ADDRESS

sjlctl() {
  sudo -u "$SJL_USER" env \
    XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
    DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
    systemctl --user "$@"
}

listener_pid() {
  local port="$1"
  ss -ltnp 2>/dev/null |
    awk -v p=":${port}" '$4 ~ p"$" {
      if (match($0,/pid=([0-9]+)/,m)) {print m[1]; exit}
    }'
}

port_free() {
  [[ -z "$(listener_pid "$1")" ]]
}

STAGE_PGID=""
MUTATED=0
SUCCESS=0

stop_stage_group() {
  set +e
  if [[ -n "${STAGE_PGID:-}" ]]; then
    kill -TERM "-${STAGE_PGID}" 2>/dev/null || true
    for _ in {1..20}; do
      kill -0 "${STAGE_PGID}" 2>/dev/null || break
      sleep 0.25
    done
    kill -KILL "-${STAGE_PGID}" 2>/dev/null || true
    wait "${STAGE_PGID}" 2>/dev/null || true
  fi
  STAGE_PGID=""
  for _ in {1..20}; do
    port_free "$STAGE_PORT" && break
    sleep 0.25
  done
  set -e
}

rollback() {
  local status="${1:-1}"
  trap - ERR INT TERM EXIT
  stop_stage_group
  if (( MUTATED == 1 && SUCCESS == 0 )); then
    say "ROLLBACK"
    install -o "$SJL_USER" -g "$SJL_USER" -m 0750 \
      "$OUT/server.py.live" "$LIVE"
    sjlctl restart "$UNIT" || true
    sleep 3
    sjlctl is-active --quiet "$UNIT" || \
      echo "WARNING: prior service did not return active after rollback"
  fi
  exit "$status"
}

on_exit() {
  local status=$?
  if (( status != 0 )); then
    rollback "$status"
  fi
  stop_stage_group
}

trap 'rollback 130' INT
trap 'rollback 143' TERM
trap 'rollback 1' ERR
trap on_exit EXIT

say "Backing up current production state"
cp -a "$LIVE" "$OUT/server.py.live"
sha256sum "$LIVE" > "$OUT/live.sha256"
sjlctl cat "$UNIT" > "$OUT/${UNIT}.cat.txt" 2>&1 || true
sjlctl show "$UNIT" > "$OUT/${UNIT}.show.txt" 2>&1 || true
sjlctl status "$UNIT" --no-pager > "$OUT/${UNIT}.status-before.txt" 2>&1 || true
ss -ltnp > "$OUT/listeners-before.txt" 2>&1 || true

cat > "$OUT/mcp_probe.py" <<'PY'
import json
import sys
import urllib.error
import urllib.request
from typing import Any

port = int(sys.argv[1])
action = sys.argv[2]
out_path = sys.argv[3]
url = f"http://127.0.0.1:{port}/mcp"

def decode(raw: str, expected_id: int | None = None) -> Any:
    raw = raw.strip()
    if not raw:
        return None
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        pass
    events = []
    for line in raw.splitlines():
        if not line.startswith("data:"):
            continue
        payload = line[5:].strip()
        if not payload:
            continue
        try:
            events.append(json.loads(payload))
        except json.JSONDecodeError:
            continue
    if expected_id is not None:
        for item in reversed(events):
            if isinstance(item, dict) and item.get("id") == expected_id:
                return item
    return events[-1] if events else None

def post(payload: dict, sid: str | None = None, expect=True):
    headers = {
        "Content-Type": "application/json",
        "Accept": "application/json, text/event-stream",
    }
    if sid:
        headers["Mcp-Session-Id"] = sid
    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers=headers,
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=20) as resp:
        raw = resp.read().decode("utf-8", errors="replace")
        obj = decode(raw, payload.get("id")) if expect else None
        return obj, resp.headers.get("Mcp-Session-Id") or sid, raw

def initialize():
    init = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "initialize",
        "params": {
            "protocolVersion": "2025-03-26",
            "capabilities": {},
            "clientInfo": {"name": "sjl-recovery-audit", "version": "3.2"},
        },
    }
    obj, sid, raw = post(init)
    if not isinstance(obj, dict) or "error" in obj or "result" not in obj:
        raise RuntimeError(f"initialize failed: {obj!r}; raw={raw[:500]!r}")
    try:
        post(
            {"jsonrpc": "2.0", "method": "notifications/initialized"},
            sid,
            expect=False,
        )
    except Exception:
        pass
    return sid, obj

def list_tools(sid):
    payload = {"jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": {}}
    obj, sid, raw = post(payload, sid)
    if not isinstance(obj, dict) or "error" in obj:
        raise RuntimeError(f"tools/list failed: {obj!r}; raw={raw[:500]!r}")
    tools = obj.get("result", {}).get("tools", [])
    if not isinstance(tools, list):
        raise RuntimeError("tools/list returned no tools array")
    return sid, tools, obj

UNRESOLVED = object()

def safe_value(schema):
    if not isinstance(schema, dict):
        return UNRESOLVED
    if "default" in schema:
        return schema["default"]
    if "const" in schema:
        return schema["const"]
    enum = schema.get("enum")
    if isinstance(enum, list) and len(enum) == 1:
        return enum[0]
    typ = schema.get("type")
    if typ == "object" or "properties" in schema:
        props = schema.get("properties", {})
        required = schema.get("required", [])
        result = {}
        for key in required:
            value = safe_value(props.get(key, {}))
            if value is UNRESOLVED:
                return UNRESOLVED
            result[key] = value
        for key, subschema in props.items():
            if key in result:
                continue
            if isinstance(subschema, dict) and (
                "default" in subschema or "const" in subschema
                or (isinstance(subschema.get("enum"), list)
                    and len(subschema["enum"]) == 1)
            ):
                value = safe_value(subschema)
                if value is not UNRESOLVED:
                    result[key] = value
        return result
    return UNRESOLVED

sid, init_obj = initialize()
sid, tools, tools_obj = list_tools(sid)

preferred = ["controlled_write_health", "write_access_health"]
by_name = {t.get("name"): t for t in tools if isinstance(t, dict)}
health_name = next((n for n in preferred if n in by_name), None)
write_names = sorted(
    n for n in by_name
    if isinstance(n, str) and any(
        k in n.lower()
        for k in ("create", "update", "write", "deploy", "restart", "execute", "upsert")
    )
)

report = {
    "url": url,
    "initialize": init_obj,
    "tools_response": tools_obj,
    "tools": tools,
    "tool_names": sorted(by_name),
    "tool_count": len(by_name),
    "health_tool": health_name,
    "write_tools": write_names,
    "health_call": None,
}

if action == "list":
    pass
elif action == "health":
    if not health_name:
        report["health_call"] = {"status": "NO_EXACT_WRITE_HEALTH_TOOL"}
    else:
        schema = by_name[health_name].get("inputSchema", {"type": "object"})
        args = safe_value(schema)
        if args is UNRESOLVED:
            report["health_call"] = {
                "status": "SCHEMA_UNRESOLVED",
                "tool": health_name,
                "inputSchema": schema,
            }
        else:
            payload = {
                "jsonrpc": "2.0",
                "id": 3,
                "method": "tools/call",
                "params": {"name": health_name, "arguments": args},
            }
            try:
                result, sid, raw = post(payload, sid)
                passed = (
                    isinstance(result, dict)
                    and "error" not in result
                    and isinstance(result.get("result"), dict)
                    and not result["result"].get("isError", False)
                )
                report["health_call"] = {
                    "status": "PASS" if passed else "CALL_FAILED",
                    "tool": health_name,
                    "arguments": args,
                    "response": result,
                    "raw_excerpt": raw[:1000],
                }
            except Exception as exc:
                report["health_call"] = {
                    "status": "CALL_FAILED",
                    "tool": health_name,
                    "arguments": args,
                    "exception": repr(exc),
                }
else:
    raise SystemExit(f"unknown action: {action}")

with open(out_path, "w", encoding="utf-8") as handle:
    json.dump(report, handle, indent=2)

status = (report.get("health_call") or {}).get("status")
if action == "health" and status != "PASS":
    raise SystemExit(2)
PY

cat > "$OUT/static_scan.py" <<'PY'
import ast
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
tree = ast.parse(path.read_text(encoding="utf-8", errors="replace"))

dangerous = {
    "os.system",
    "os.popen",
    "subprocess.call",
    "subprocess.Popen",
    "subprocess.run",
    "subprocess.check_call",
    "subprocess.check_output",
    "pty.spawn",
    "eval",
    "exec",
    "__import__",
}

def dotted(node):
    if isinstance(node, ast.Name):
        return node.id
    if isinstance(node, ast.Attribute):
        left = dotted(node.value)
        return f"{left}.{node.attr}" if left else node.attr
    return ""

hits = []
imports = set()
for node in ast.walk(tree):
    if isinstance(node, ast.Import):
        imports.update(alias.name.split(".")[0] for alias in node.names)
    elif isinstance(node, ast.ImportFrom):
        if node.module:
            imports.add(node.module.split(".")[0])
        elif node.level:
            imports.add("<relative>")
    elif isinstance(node, ast.Call):
        name = dotted(node.func)
        if name in dangerous:
            hits.append({"line": node.lineno, "call": name})

print(json.dumps({
    "path": str(path),
    "imports": sorted(imports),
    "dangerous_calls": hits,
}, indent=2))
raise SystemExit(3 if hits else 0)
PY

say "Discovering candidates from June 24–26 UTC"
mapfile -d '' CANDIDATES < <(
  find "$APP" -maxdepth 1 -type f -name 'server.py.*' \
    -newermt "$START_UTC" ! -newermt "$END_UTC" \
    -printf '%s\t%T@\t%p\0' |
  sort -z -t $'\t' -k1,1nr -k2,2nr |
  cut -z -f3-
)

((${#CANDIDATES[@]} > 0)) ||
  die "No candidates found in the June 24–26 UTC window"

printf 'sha256\tbytes\tmtime_utc\tcandidate\n' > "$OUT/candidates.tsv"
for c in "${CANDIDATES[@]}"; do
  printf '%s\t%s\t%s\t%s\n' \
    "$(sha256sum "$c" | awk '{print $1}')" \
    "$(stat -c %s "$c")" \
    "$(date -u -d "@$(stat -c %Y "$c")" --iso-8601=seconds)" \
    "$c" >> "$OUT/candidates.tsv"
done

SELECTED=""
for c in "${CANDIDATES[@]}"; do
  stop_stage_group
  port_free "$STAGE_PORT" || die "Staging port ${STAGE_PORT} is occupied"

  name="$(basename "$c")"
  safe_name="${name//[^A-Za-z0-9_.-]/_}"
  log="$OUT/${safe_name}.stage.log"
  static="$OUT/${safe_name}.static.json"
  tools="$OUT/${safe_name}.tools.json"

  say "Testing $name"

  if ! "$VENV_PY" -m py_compile "$c"; then
    echo "Rejected: syntax error" | tee -a "$log"
    continue
  fi

  if ! "$VENV_PY" "$OUT/static_scan.py" "$c" > "$static"; then
    echo "Rejected: direct execution primitives detected; see $static" | tee -a "$log"
    continue
  fi

  missing="$("$VENV_PY" - "$c" "$APP" <<'PY'
import ast
import importlib.util
import pathlib
import sys

candidate = pathlib.Path(sys.argv[1])
app = pathlib.Path(sys.argv[2])
tree = ast.parse(candidate.read_text(encoding="utf-8", errors="replace"))
mods = set()
for node in ast.walk(tree):
    if isinstance(node, ast.Import):
        mods.update(alias.name.split(".")[0] for alias in node.names)
    elif isinstance(node, ast.ImportFrom) and node.module:
        mods.add(node.module.split(".")[0])

missing = []
for mod in sorted(mods):
    if (app / f"{mod}.py").exists() or (app / mod).is_dir():
        continue
    try:
        found = importlib.util.find_spec(mod)
    except Exception:
        found = None
    if found is None:
        missing.append(mod)
print(" ".join(missing))
PY
)"
  if [[ -n "$missing" ]]; then
    echo "Rejected: missing imports: $missing" | tee -a "$log"
    continue
  fi

  (
    cd "$APP"
    exec setsid sudo -u "$SJL_USER" env \
      PYTHONPATH="$APP" \
      PORT="$STAGE_PORT" \
      MCP_PORT="$STAGE_PORT" \
      SJL_MCP_PORT="$STAGE_PORT" \
      HOST="127.0.0.1" \
      MCP_HOST="127.0.0.1" \
      SJL_MCP_HOST="127.0.0.1" \
      SJL_MCP_CONFIG="${SJL_MCP_CONFIG:-/etc/sjl/mcp-config.json}" \
      LOG_LEVEL="${LOG_LEVEL:-INFO}" \
      "$VENV_PY" "$c"
  ) > "$log" 2>&1 &
  STAGE_PGID=$!

  ready=0
  for _ in {1..30}; do
    if ! kill -0 "$STAGE_PGID" 2>/dev/null; then
      break
    fi
    if ! port_free "$STAGE_PORT"; then
      ready=1
      break
    fi
    sleep 1
  done

  if (( ready == 0 )); then
    echo "Rejected: failed to bind staging port" | tee -a "$log"
    stop_stage_group
    continue
  fi

  if "$VENV_PY" "$OUT/mcp_probe.py" "$STAGE_PORT" health "$tools"; then
    "$VENV_PY" - "$tools" <<'PY'
import json
import sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
if not d.get("write_tools"):
    raise SystemExit("no operational write tools found")
if (d.get("health_call") or {}).get("status") != "PASS":
    raise SystemExit("write-health call did not pass")
PY
    SELECTED="$c"
    echo "AUTOMATIC PROMOTION ELIGIBLE: $SELECTED"
    stop_stage_group
    break
  else
    echo "Rejected or manual review required; inspect $tools" | tee -a "$log"
    stop_stage_group
  fi
done

[[ -n "$SELECTED" ]] ||
  die "No candidate passed exact, schema-aware write-health validation"

say "Selected candidate"
echo "$SELECTED" | tee "$OUT/selected.txt"

if [[ "$MODE" == "--audit" ]]; then
  say "AUDIT COMPLETE — no mutation"
  echo "AUTOMATIC PROMOTION ELIGIBLE"
  echo "Candidate: $SELECTED"
  echo "Evidence: $OUT"
  SUCCESS=1
  exit 0
fi

say "Final pre-promotion checks"
port_free "$STAGE_PORT" || die "Staging port is still occupied"
sjlctl is-active --quiet "$UNIT" || die "Current production service is not active"
"$VENV_PY" "$OUT/mcp_probe.py" "$PROD_PORT" list \
  "$OUT/production-before.json" || die "Current production MCP is not queryable"

say "Atomic promotion"
install -o "$SJL_USER" -g "$SJL_USER" -m 0750 \
  "$SELECTED" "${LIVE}.new"
mv -f "${LIVE}.new" "$LIVE"
MUTATED=1

sjlctl restart "$UNIT"
sleep 5
sjlctl is-active --quiet "$UNIT" ||
  die "Service failed after promotion"

"$VENV_PY" "$OUT/mcp_probe.py" "$PROD_PORT" health \
  "$OUT/production-after.json" ||
  die "Production write-health validation failed"

say "SUCCESS"
sha256sum "$LIVE" | tee "$OUT/live-after.sha256"
sjlctl status "$UNIT" --no-pager > "$OUT/${UNIT}.status-after.txt" 2>&1 || true
ss -ltnp > "$OUT/listeners-after.txt" 2>&1 || true
SUCCESS=1
MUTATED=0
echo "Promoted: $SELECTED"
echo "Evidence: $OUT"
