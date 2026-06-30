#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

# =====================================================================
# SJL MCP Guarded Repair v1.7
#
# Purpose:
#   Recover the write-enabled public MCP gateway on 8797 by locating,
#   ranking, staging, live-validating, and atomically promoting a known-good
#   historical server.py candidate while preserving the healthy guarded
#   backend on 8777.
#
# Core guarantees:
#   - No mutation before complete backup and live preflight validation.
#   - Deterministic FIFO logging with explicit logger shutdown.
#   - Full rollback on any post-mutation failure.
#   - Optional Git acceleration; filesystem recovery remains available.
#   - Git object inspection uses batch-check/batch extraction.
#   - Candidate ranking is heuristic only; promotion requires live MCP proof.
#   - Candidate is staged on a throwaway loopback port before production use.
#   - 8777 must remain healthy before, during, and after repair.
#   - BookStack/write-health capabilities are required when present on 8777.
# =====================================================================

# ---------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
SJL_USER="${SJL_USER:-sjl}"

PUBLIC_PORT="${PUBLIC_PORT:-8797}"
RW_PORT="${RW_PORT:-8777}"
STAGE_PORT="${STAGE_PORT:-18897}"

EXPECTED_MIN_TOOLS="${EXPECTED_MIN_TOOLS:-50}"
MIN_CANDIDATE_SCORE="${MIN_CANDIDATE_SCORE:-70}"
MAX_ALLOWED_RW_GAP="${MAX_ALLOWED_RW_GAP:-5}"
MAX_CANDIDATES_TO_STAGE="${MAX_CANDIDATES_TO_STAGE:-10}"
STAGE_START_TIMEOUT="${STAGE_START_TIMEOUT:-20}"

CURRENT_SOURCE="${CURRENT_SOURCE:-/srv/sjl/70000_SYSTEM-AUTOMATION/76000_mcp-cloud-access/app/server.py}"
BACKUP_ROOT="${BACKUP_ROOT:-/root/backups/sjl-mcp-repair/${STAMP}}"
REPORT="${BACKUP_ROOT}/repair-report.md"
LOG="${BACKUP_ROOT}/repair.log"
LOG_FIFO="${BACKUP_ROOT}/.repair-log.fifo"
CANDIDATE_DIR="${BACKUP_ROOT}/candidates"
ARCHIVE="${BACKUP_ROOT}.tar.gz"

SUCCESS=0
MUTATED=0
ROLLBACK_RUNNING=0
LOGGING_STARTED=0
TEE_PID=""
STAGE_PID=""
TMP_STAGE=""

SJL_UID=""
SJL_HOME=""
RUNTIME_DIR=""
BUS=""
CURRENT_UNIT=""
RW_UNIT=""
PYTHON_BIN=""
WORKDIR=""

declare -A SEEN_CANDIDATES=()

mkdir -p "$CANDIDATE_DIR"

say() { printf '\n== %s ==\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

# ---------------------------------------------------------------------
# Deterministic logging
# ---------------------------------------------------------------------
start_logging() {
    (( LOGGING_STARTED == 0 )) || return 0

    rm -f "$LOG_FIFO"
    mkfifo "$LOG_FIFO"

    exec 3>&1 4>&2

    tee -a "$LOG" < "$LOG_FIFO" &
    TEE_PID=$!

    exec > "$LOG_FIFO" 2>&1
    LOGGING_STARTED=1
}

finish_logging() {
    local requested_status="${1:-0}"
    local final_status="$requested_status"

    (( LOGGING_STARTED == 1 )) || return "$final_status"

    exec 1>&3 2>&4
    exec 3>&- 4>&-

    if [[ -n "${TEE_PID:-}" ]]; then
        if ! wait "$TEE_PID"; then
            printf 'WARNING: tee logging process exited abnormally.\n' >&2
            (( final_status == 0 )) && final_status=1
        fi
    fi

    rm -f "$LOG_FIFO"
    LOGGING_STARTED=0
    TEE_PID=""

    return "$final_status"
}

# ---------------------------------------------------------------------
# Runtime helpers
# ---------------------------------------------------------------------
sjl_systemctl() {
    sudo -u "$SJL_USER" env \
        XDG_RUNTIME_DIR="$RUNTIME_DIR" \
        DBUS_SESSION_BUS_ADDRESS="$BUS" \
        systemctl --user "$@"
}

listener_pid() {
    local port="$1"
    local pid=""

    if have ss; then
        pid="$(
            ss -ltnp 2>/dev/null |
            awk -v port="$port" '
                {
                    address=$4
                    sub(/^.*:/, "", address)
                    if (address == port && match($0, /pid=([0-9]+)/, m)) {
                        print m[1]
                        exit
                    }
                }
            ' || true
        )"
    fi

    if [[ -z "$pid" ]] && have lsof; then
        pid="$(lsof -nP -iTCP:"$port" -sTCP:LISTEN -t 2>/dev/null | head -n1 || true)"
    fi

    if [[ -z "$pid" ]] && have fuser; then
        pid="$(fuser -n tcp "$port" 2>/dev/null | awk '{print $1}' | head -n1 || true)"
    fi

    printf '%s\n' "${pid:-}"
}

port_is_free() {
    local port="$1"
    [[ -z "$(listener_pid "$port")" ]]
}

redact_environment() {
    local pid="$1"
    local outfile="$2"

    if [[ -r "/proc/${pid}/environ" ]]; then
        tr '\0' '\n' < "/proc/${pid}/environ" |
            sed -E \
                's/^([^=]*(TOKEN|SECRET|KEY|PASSWORD|PASS|CREDENTIAL|AUTH)[^=]*)=.*/\1=<REDACTED>/I' |
            sort > "$outfile"
    else
        printf 'Environment unavailable for PID %s\n' "$pid" > "$outfile"
    fi
}

query_tools() {
    local port="$1"
    local outfile="$2"

    python3 - "$port" "$outfile" <<'PY'
import json
import re
import sys
import urllib.error
import urllib.request

port = int(sys.argv[1])
outfile = sys.argv[2]
url = f"http://127.0.0.1:{port}/mcp"

initialize = {
    "jsonrpc": "2.0",
    "id": 1,
    "method": "initialize",
    "params": {
        "protocolVersion": "2025-03-26",
        "capabilities": {},
        "clientInfo": {"name": "sjl-recovery", "version": "1.7"},
    },
}
initialized = {"jsonrpc": "2.0", "method": "notifications/initialized"}
tools_list = {"jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": {}}


def decode_payload(raw: str):
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

    for event in reversed(events):
        if isinstance(event, dict) and ("result" in event or "error" in event):
            return event

    return events[-1] if events else None


def post(payload, session_id=None, expect_response=True):
    headers = {
        "Content-Type": "application/json",
        "Accept": "application/json, text/event-stream",
    }
    if session_id:
        headers["Mcp-Session-Id"] = session_id

    request = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers=headers,
        method="POST",
    )

    with urllib.request.urlopen(request, timeout=20) as response:
        raw = response.read().decode("utf-8", errors="replace")
        returned_session = response.headers.get("Mcp-Session-Id") or session_id
        parsed = decode_payload(raw) if expect_response else None
        return raw, parsed, returned_session


result = {"url": url, "tool_names": [], "tool_count": 0}

try:
    init_raw, init_parsed, session_id = post(initialize)
    result["initialize_raw"] = init_raw
    result["initialize"] = init_parsed
    result["session_id"] = session_id

    try:
        post(initialized, session_id, expect_response=False)
    except Exception as notify_err:
        result["initialized_notification_warning"] = repr(notify_err)

    tools_raw, tools_parsed, _ = post(tools_list, session_id)
    result["tools_raw"] = tools_raw
    result["tools_response"] = tools_parsed

    names = []
    if isinstance(tools_parsed, dict):
        tools = tools_parsed.get("result", {}).get("tools", [])
        if isinstance(tools, list):
            names = [
                item.get("name")
                for item in tools
                if isinstance(item, dict) and isinstance(item.get("name"), str)
            ]

    if not names:
        names = re.findall(r'"name"\s*:\s*"([^"]+)"', tools_raw)

    result["tool_names"] = sorted(set(names))
    result["tool_count"] = len(result["tool_names"])

except Exception as exc:
    result["error"] = repr(exc)
    print(f"MCP query failed for port {port}: {exc!r}", file=sys.stderr)

with open(outfile, "w", encoding="utf-8") as handle:
    json.dump(result, handle, indent=2)

print(result["tool_count"])
PY
}

candidate_add() {
    local source_path="$1"
    local origin="$2"
    local sha target

    [[ -f "$source_path" ]] || return 0
    sha="$(sha256sum "$source_path" | awk '{print $1}')"

    if [[ -z "${SEEN_CANDIDATES[$sha]:-}" ]]; then
        target="${CANDIDATE_DIR}/${sha}.py"
        cp -a "$source_path" "$target"
        SEEN_CANDIDATES["$sha"]=1
    fi

    printf '%s\t%s\n' "$sha" "$origin" >> "$CANDIDATE_DIR/origins.tsv"
}

cleanup_stage() {
    set +e
    if [[ -n "${STAGE_PID:-}" ]] && kill -0 "$STAGE_PID" 2>/dev/null; then
        kill "$STAGE_PID" 2>/dev/null || true
        for _ in {1..20}; do
            kill -0 "$STAGE_PID" 2>/dev/null || break
            sleep 0.25
        done
        kill -9 "$STAGE_PID" 2>/dev/null || true
    fi
    STAGE_PID=""

    if [[ -n "${TMP_STAGE:-}" && -d "$TMP_STAGE" ]]; then
        rm -rf "$TMP_STAGE"
    fi
    TMP_STAGE=""
}

# ---------------------------------------------------------------------
# Rollback and traps
# ---------------------------------------------------------------------
rollback() {
    local status="${1:-1}"

    if (( ROLLBACK_RUNNING == 1 )); then
        cleanup_stage
        finish_logging "$status" || true
        exit "$status"
    fi

    ROLLBACK_RUNNING=1
    trap - EXIT ERR INT TERM
    set +Eeuo pipefail

    cleanup_stage
    say "ROLLBACK"

    if (( MUTATED == 1 )); then
        install -D -m 0644 "$BACKUP_ROOT/server.py" "$CURRENT_SOURCE" || true
        install -D -m 0644 "$BACKUP_ROOT/sjl-cloud-access-mcp.service" "$CURRENT_UNIT" || true
        chown "$SJL_USER:$SJL_USER" "$CURRENT_SOURCE" "$CURRENT_UNIT" || true

        sjl_systemctl daemon-reload || true
        sjl_systemctl restart sjl-cloud-access-mcp.service || true
        sjl_systemctl status sjl-cloud-access-mcp.service --no-pager || true
    else
        echo "No mutation occurred; rollback was not required."
    fi

    {
        echo
        echo "## Rollback"
        echo
        echo "- Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
        echo "- Mutation occurred: ${MUTATED}"
        echo "- Result: rollback attempted"
    } >> "$REPORT" 2>/dev/null || true

    echo "Rollback sequence complete."

    finish_logging "$status" || true

    if [[ -d "$BACKUP_ROOT" ]]; then
        tar -C "$(dirname "$BACKUP_ROOT")" \
            -czf "$ARCHIVE" \
            "$(basename "$BACKUP_ROOT")" || true
    fi

    exit "$status"
}

on_exit() {
    local status=$?
    (( SUCCESS == 1 )) && return 0
    rollback "$status"
}

trap on_exit EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

start_logging

# ---------------------------------------------------------------------
# Preflight
# ---------------------------------------------------------------------
say "Preflight validation"

for cmd in sudo python3 systemctl sha256sum install ss find grep sort awk sed tar mkfifo tee; do
    have "$cmd" || die "Missing required command: $cmd"
done

id "$SJL_USER" >/dev/null 2>&1 || die "User does not exist: $SJL_USER"

SJL_UID="$(id -u "$SJL_USER")"
SJL_HOME="$(getent passwd "$SJL_USER" | awk -F: '{print $6}')"
[[ -n "$SJL_HOME" && -d "$SJL_HOME" ]] ||
    die "Unable to resolve valid home directory for $SJL_USER"

RUNTIME_DIR="/run/user/${SJL_UID}"
BUS="unix:path=${RUNTIME_DIR}/bus"
CURRENT_UNIT="${SJL_HOME}/.config/systemd/user/sjl-cloud-access-mcp.service"
RW_UNIT="${SJL_HOME}/.config/systemd/user/sjl-unified-cloud-mcp-rw.service"

[[ -S "$RUNTIME_DIR/bus" ]] || die "SJL user bus unavailable"
[[ -f "$CURRENT_UNIT" ]] || die "Missing public unit: $CURRENT_UNIT"
[[ -f "$RW_UNIT" ]] || die "Missing RW unit: $RW_UNIT"
[[ -f "$CURRENT_SOURCE" ]] || die "Missing current source: $CURRENT_SOURCE"

sjl_systemctl is-active --quiet sjl-unified-cloud-mcp-rw.service ||
    die "RW service is not active"

sjl_systemctl is-active --quiet sjl-cloud-access-mcp.service ||
    die "Public service is not active"

PID_8777="$(listener_pid "$RW_PORT")"
PID_8797="$(listener_pid "$PUBLIC_PORT")"

[[ -n "$PID_8777" ]] || die "No listener on $RW_PORT"
[[ -n "$PID_8797" ]] || die "No listener on $PUBLIC_PORT"

port_is_free "$STAGE_PORT" || die "Staging port $STAGE_PORT is already in use"

PYTHON_BIN="$(readlink -f "/proc/${PID_8797}/exe")"
WORKDIR="$(readlink -f "/proc/${PID_8797}/cwd")"

[[ -x "$PYTHON_BIN" ]] || die "Unable to identify active Python interpreter"
[[ -d "$WORKDIR" ]] || die "Unable to identify active working directory"

# ---------------------------------------------------------------------
# Backup live state
# ---------------------------------------------------------------------
say "Preserve current state"

cp -a "$CURRENT_SOURCE" "$BACKUP_ROOT/server.py"
cp -a "$CURRENT_UNIT" "$BACKUP_ROOT/sjl-cloud-access-mcp.service"
cp -a "$RW_UNIT" "$BACKUP_ROOT/sjl-unified-cloud-mcp-rw.service"

if [[ -d "${SJL_HOME}/.config/systemd/user/sjl-cloud-access-mcp.service.d" ]]; then
    cp -a \
        "${SJL_HOME}/.config/systemd/user/sjl-cloud-access-mcp.service.d" \
        "$BACKUP_ROOT/"
fi

if [[ -d "${SJL_HOME}/.config/systemd/user/sjl-unified-cloud-mcp-rw.service.d" ]]; then
    cp -a \
        "${SJL_HOME}/.config/systemd/user/sjl-unified-cloud-mcp-rw.service.d" \
        "$BACKUP_ROOT/"
fi

sjl_systemctl cat sjl-cloud-access-mcp.service > "$BACKUP_ROOT/public-unit-expanded.txt"
sjl_systemctl cat sjl-unified-cloud-mcp-rw.service > "$BACKUP_ROOT/rw-unit-expanded.txt"

sha256sum "$CURRENT_SOURCE" > "$BACKUP_ROOT/current-source.sha256"
redact_environment "$PID_8797" "$BACKUP_ROOT/8797-environment-redacted.txt"
redact_environment "$PID_8777" "$BACKUP_ROOT/8777-environment-redacted.txt"

PRE_8777="$(query_tools "$RW_PORT" "$BACKUP_ROOT/8777-tools-before.json")"
PRE_8797="$(query_tools "$PUBLIC_PORT" "$BACKUP_ROOT/8797-tools-before.json")"

(( PRE_8777 > 0 )) || die "$RW_PORT did not return tools"

# ---------------------------------------------------------------------
# Collect filesystem candidates
# ---------------------------------------------------------------------
say "Collect filesystem candidates"

: > "$CANDIDATE_DIR/origins.tsv"

while IFS= read -r -d '' file; do
    candidate_add "$file" "filesystem:${file}"
done < <(
    find /srv/sjl /root/backups /home/sjl /opt /var/backups \
        -xdev -type f \
        \( \
            -name 'server.py' \
            -o -name 'server.py.*' \
            -o -name '*cloud-access*.py' \
            -o -name '*unified-cloud*.py' \
        \) \
        -size -2M \
        -print0 2>/dev/null
)

# ---------------------------------------------------------------------
# Collect Git-history candidates efficiently
# ---------------------------------------------------------------------
say "Collect Git-history candidates"

if have git; then
    while IFS= read -r -d '' gitdir; do
        repo="${gitdir%/.git}"
        object_list="${CANDIDATE_DIR}/git-objects.$$.txt"
        blob_list="${CANDIDATE_DIR}/git-blobs.$$.txt"

        git -C "$repo" rev-list --all --objects 2>/dev/null |
            awk '$2 ~ /(^|\/)server\.py$/ {print $1 "\t" $2}' \
            > "$object_list" || true

        [[ -s "$object_list" ]] || {
            rm -f "$object_list" "$blob_list"
            continue
        }

        cut -f1 "$object_list" |
            git -C "$repo" cat-file --batch-check='%(objectname) %(objecttype) %(objectsize)' 2>/dev/null |
            awk '$2=="blob" && $3 < 2097152 {print $1}' \
            > "$blob_list" || true

        while IFS= read -r object_id; do
            [[ -n "$object_id" ]] || continue

            temp_blob="${CANDIDATE_DIR}/.git-${object_id}.tmp"
            if git -C "$repo" cat-file blob "$object_id" > "$temp_blob" 2>/dev/null; then
                original_path="$(awk -F'\t' -v obj="$object_id" '$1==obj {print $2; exit}' "$object_list")"
                candidate_add "$temp_blob" "git:${repo}:${object_id}:${original_path}"
            fi
            rm -f "$temp_blob"
        done < "$blob_list"

        rm -f "$object_list" "$blob_list"
    done < <(
        find /srv/sjl /root/backups /home/sjl /opt \
            -xdev -type d -name .git -print0 2>/dev/null
    )
else
    echo "NOTICE: git is unavailable; continuing with filesystem candidates only."
fi

# ---------------------------------------------------------------------
# Rank candidates
# ---------------------------------------------------------------------
say "Rank candidates"

python3 - "$CANDIDATE_DIR" "$CURRENT_SOURCE" "$BACKUP_ROOT/candidate-ranking.json" <<'PY'
import ast
import hashlib
import json
import re
import sys
from pathlib import Path

candidate_dir = Path(sys.argv[1])
current_path = Path(sys.argv[2])
output_path = Path(sys.argv[3])


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


current_sha = sha256(current_path)
records = []

positive_checks = [
    (r"127\.0\.0\.1:8777|localhost:8777", 35, "8777 integration"),
    (r"sjl-unified-cloud-mcp-rw", 25, "RW service reference"),
    (r"write_access_health|controlled_write_health", 25, "write health"),
    (r"bookstack_(create|update|upsert)_page", 20, "BookStack write"),
    (r"SJL_MCP_WRITE_TOKEN|SJL_WRITE_APPROVAL_TOKEN", 20, "approval token"),
    (r"forward|proxy|wrapper", 15, "forwarding logic"),
    (r"jsonrpc|Mcp-Session-Id|tools/list|FastMCP|mcp\.", 10, "MCP implementation"),
]

negative_checks = [
    (r"readonly\s*=\s*true", -25, "explicit read-only default"),
    (r"SJL_MCP_READONLY[^=\n]*=\s*[\"']?(?:1|true|yes|on)", -25, "read-only enabled"),
    (r"\bREADONLY[^=\n]*=\s*[\"']?(?:1|true|yes|on)", -20, "generic read-only enabled"),
]

for path in sorted(candidate_dir.glob("*.py")):
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except Exception:
        continue

    candidate_sha = sha256(path)
    if candidate_sha == current_sha:
        continue

    score = 0
    reasons = []

    for pattern, points, label in positive_checks:
        if re.search(pattern, text, flags=re.I):
            score += points
            reasons.append(f"{points:+d} {label}")

    for pattern, points, label in negative_checks:
        if re.search(pattern, text, flags=re.I):
            score += points
            reasons.append(f"{points:+d} {label}")

    tool_hits = len(
        re.findall(
            r"@\s*(?:mcp|server|app)\.(?:tool|resource|prompt)\b|register_tool\s*\(",
            text,
        )
    )
    tool_points = min(tool_hits, 50)
    score += tool_points
    reasons.append(f"+{tool_points} static registrations ({tool_hits})")

    syntax_ok = True
    syntax_error = None
    try:
        ast.parse(text)
        score += 10
        reasons.append("+10 valid Python syntax")
    except SyntaxError as exc:
        syntax_ok = False
        syntax_error = f"{exc.msg} at {exc.lineno}:{exc.offset}"
        score -= 200
        reasons.append("-200 syntax error")

    records.append(
        {
            "path": str(path),
            "sha256": candidate_sha,
            "score": score,
            "tool_hits": tool_hits,
            "syntax_ok": syntax_ok,
            "syntax_error": syntax_error,
            "reasons": reasons,
        }
    )

records.sort(
    key=lambda item: (
        item["score"],
        item["tool_hits"],
        item["sha256"],
    ),
    reverse=True,
)

output_path.write_text(json.dumps(records, indent=2), encoding="utf-8")

for record in records[:25]:
    print(
        f'{record["score"]:4d}\t'
        f'{record["tool_hits"]:3d}\t'
        f'{record["sha256"]}\t'
        f'{record["path"]}'
    )
PY

# ---------------------------------------------------------------------
# Stage candidates on throwaway port
# ---------------------------------------------------------------------
say "Stage and live-validate candidates"

mapfile -t RANKED_PATHS < <(
    python3 - "$BACKUP_ROOT/candidate-ranking.json" "$MIN_CANDIDATE_SCORE" "$MAX_CANDIDATES_TO_STAGE" <<'PY'
import json
import sys

records = json.load(open(sys.argv[1], encoding="utf-8"))
minimum = int(sys.argv[2])
limit = int(sys.argv[3])

count = 0
for record in records:
    if not record.get("syntax_ok"):
        continue
    if int(record.get("score", 0)) < minimum:
        continue
    print(record["path"])
    count += 1
    if count >= limit:
        break
PY
)

((${#RANKED_PATHS[@]} > 0)) ||
    die "No high-confidence candidate reached the minimum score"

SELECTED_PATH=""
SELECTED_SCORE=""
SELECTED_STAGE_TOOLS=0

for candidate in "${RANKED_PATHS[@]}"; do
    cleanup_stage

    candidate_sha="$(sha256sum "$candidate" | awk '{print $1}')"
    candidate_score="$(
        python3 - "$BACKUP_ROOT/candidate-ranking.json" "$candidate" <<'PY'
import json
import sys

records = json.load(open(sys.argv[1], encoding="utf-8"))
target = sys.argv[2]
for record in records:
    if record["path"] == target:
        print(record["score"])
        break
PY
    )"

    say "Stage candidate ${candidate_sha} (score ${candidate_score})"

    python3 -m py_compile "$candidate"

    TMP_STAGE="$(mktemp -d /var/tmp/sjl-mcp-stage.XXXXXX)"
    cp -a "$candidate" "$TMP_STAGE/server.py"

    # Preserve the active working directory and runtime environment.
    # Override common port/host variables only for the staging process.
    (
        cd "$WORKDIR"
        env \
            PORT="$STAGE_PORT" \
            MCP_PORT="$STAGE_PORT" \
            SJL_MCP_PORT="$STAGE_PORT" \
            HOST="127.0.0.1" \
            MCP_HOST="127.0.0.1" \
            SJL_MCP_HOST="127.0.0.1" \
            "$PYTHON_BIN" "$TMP_STAGE/server.py"
    ) > "$BACKUP_ROOT/stage-${candidate_sha}.log" 2>&1 &
    STAGE_PID=$!

    stage_ready=0
    for ((attempt=1; attempt<=STAGE_START_TIMEOUT; attempt++)); do
        if [[ -n "$(listener_pid "$STAGE_PORT")" ]]; then
            stage_ready=1
            break
        fi
        if ! kill -0 "$STAGE_PID" 2>/dev/null; then
            break
        fi
        sleep 1
    done

    if (( stage_ready == 0 )); then
        echo "Candidate failed to bind staging port."
        continue
    fi

    STAGE_TOOLS="$(query_tools "$STAGE_PORT" "$BACKUP_ROOT/stage-${candidate_sha}-tools.json")"

    if python3 - \
        "$BACKUP_ROOT/8777-tools-before.json" \
        "$BACKUP_ROOT/stage-${candidate_sha}-tools.json" \
        "$EXPECTED_MIN_TOOLS" \
        "$MAX_ALLOWED_RW_GAP" <<'PY'
import json
import sys

rw = json.load(open(sys.argv[1], encoding="utf-8"))
stage = json.load(open(sys.argv[2], encoding="utf-8"))
minimum = int(sys.argv[3])
max_gap = int(sys.argv[4])

rw_names = set(rw.get("tool_names", []))
stage_names = set(stage.get("tool_names", []))

if len(stage_names) < minimum:
    raise SystemExit(1)

if len(stage_names) <= 22:
    raise SystemExit(1)

missing = rw_names - stage_names
if len(missing) > max_gap:
    raise SystemExit(1)

required_groups = {
    "write health": {"write_access_health", "controlled_write_health"},
    "BookStack write": {
        "bookstack_create_page",
        "bookstack_update_page",
        "bookstack_upsert_page",
    },
}

for alternatives in required_groups.values():
    if alternatives & rw_names and not alternatives & stage_names:
        raise SystemExit(1)
PY
    then
        SELECTED_PATH="$candidate"
        SELECTED_SCORE="$candidate_score"
        SELECTED_STAGE_TOOLS="$STAGE_TOOLS"
        echo "Candidate passed live staging validation."
        break
    fi

    echo "Candidate failed live MCP capability validation."
done

[[ -n "$SELECTED_PATH" ]] ||
    die "No candidate passed live staging validation"

cleanup_stage

# ---------------------------------------------------------------------
# Atomic promotion
# ---------------------------------------------------------------------
say "Promote validated candidate"

SELECTED_SHA="$(sha256sum "$SELECTED_PATH" | awk '{print $1}')"
cp -a "$SELECTED_PATH" "$BACKUP_ROOT/selected-candidate.py"
sha256sum "$SELECTED_PATH" > "$BACKUP_ROOT/selected-candidate.sha256"

PROMOTION_TEMP="${CURRENT_SOURCE}.new.${STAMP}"
install -m 0644 "$SELECTED_PATH" "$PROMOTION_TEMP"
chown "$SJL_USER:$SJL_USER" "$PROMOTION_TEMP"

MUTATED=1
mv -f "$PROMOTION_TEMP" "$CURRENT_SOURCE"

sjl_systemctl restart sjl-cloud-access-mcp.service
sleep 5

sjl_systemctl is-active --quiet sjl-cloud-access-mcp.service ||
    die "Public service failed after promotion"

sjl_systemctl is-active --quiet sjl-unified-cloud-mcp-rw.service ||
    die "RW service became inactive during promotion"

POST_PID_8777="$(listener_pid "$RW_PORT")"
POST_PID_8797="$(listener_pid "$PUBLIC_PORT")"

[[ -n "$POST_PID_8777" ]] || die "RW listener disappeared"
[[ -n "$POST_PID_8797" ]] || die "Public listener did not return"

POST_8777="$(query_tools "$RW_PORT" "$BACKUP_ROOT/8777-tools-after.json")"
POST_8797="$(query_tools "$PUBLIC_PORT" "$BACKUP_ROOT/8797-tools-after.json")"

# ---------------------------------------------------------------------
# Final production validation
# ---------------------------------------------------------------------
say "Validate production gateway"

python3 - \
    "$BACKUP_ROOT/8777-tools-after.json" \
    "$BACKUP_ROOT/8797-tools-after.json" \
    "$EXPECTED_MIN_TOOLS" \
    "$MAX_ALLOWED_RW_GAP" <<'PY'
import json
import sys

rw = json.load(open(sys.argv[1], encoding="utf-8"))
public = json.load(open(sys.argv[2], encoding="utf-8"))
minimum = int(sys.argv[3])
max_gap = int(sys.argv[4])

rw_names = set(rw.get("tool_names", []))
public_names = set(public.get("tool_names", []))

print("8777 tool count:", len(rw_names))
print("8797 tool count:", len(public_names))

if not rw_names:
    raise SystemExit("FAIL: 8777 returned no tools")

if len(public_names) < minimum:
    raise SystemExit(
        f"FAIL: 8797 exposes {len(public_names)} tools; expected at least {minimum}"
    )

if len(public_names) <= 22:
    raise SystemExit("FAIL: 8797 remains on the reduced schema")

missing = sorted(rw_names - public_names)
if len(missing) > max_gap:
    print("Missing from public gateway:")
    for name in missing:
        print(" -", name)
    raise SystemExit(
        f"FAIL: public gateway is missing {len(missing)} guarded tools"
    )

required_groups = {
    "write health": {"write_access_health", "controlled_write_health"},
    "BookStack write": {
        "bookstack_create_page",
        "bookstack_update_page",
        "bookstack_upsert_page",
    },
}

for label, alternatives in required_groups.items():
    if alternatives & rw_names and not alternatives & public_names:
        raise SystemExit(f"FAIL: missing required {label} capability")
PY

POST_SOURCE_SHA="$(sha256sum "$CURRENT_SOURCE" | awk '{print $1}')"

sjl_systemctl status sjl-cloud-access-mcp.service --no-pager \
    > "$BACKUP_ROOT/public-status-after.txt"

sjl_systemctl status sjl-unified-cloud-mcp-rw.service --no-pager \
    > "$BACKUP_ROOT/rw-status-after.txt"

cat > "$REPORT" <<EOF
# SJL MCP Guarded Repair v1.7 Report

- Timestamp: ${STAMP}
- Host: $(hostname -f 2>/dev/null || hostname)
- Selected candidate: ${SELECTED_PATH}
- Selected candidate SHA-256: ${SELECTED_SHA}
- Candidate score: ${SELECTED_SCORE}
- Staging tool count: ${SELECTED_STAGE_TOOLS}
- Pre-repair 8777 tools: ${PRE_8777}
- Pre-repair 8797 tools: ${PRE_8797}
- Post-repair 8777 tools: ${POST_8777}
- Post-repair 8797 tools: ${POST_8797}
- Restored source SHA-256: ${POST_SOURCE_SHA}
- Result: SUCCESS
EOF

echo
echo "REPAIR SUCCESSFUL"
echo "Report: $REPORT"
echo "Backup directory: $BACKUP_ROOT"
echo "Selected candidate: $SELECTED_PATH"
echo "Candidate score: $SELECTED_SCORE"
echo "8777 tools: $POST_8777"
echo "8797 tools: $POST_8797"

SUCCESS=1

finish_logging 0
LOG_STATUS=$?

if [[ "$LOG_STATUS" -ne 0 ]]; then
    SUCCESS=0
    printf 'ERROR: deterministic log shutdown failed.\n' >&2
    exit "$LOG_STATUS"
fi

tar -C "$(dirname "$BACKUP_ROOT")" \
    -czf "$ARCHIVE" \
    "$(basename "$BACKUP_ROOT")"

printf 'Backup archive: %s\n' "$ARCHIVE"

exit 0
