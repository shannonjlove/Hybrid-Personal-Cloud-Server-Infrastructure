#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# SJL Unified MCP Gateway Installer – Hardened Version

APP_DIR="/opt/sjl-unified-mcp"
ETC_DIR="/etc/sjl-unified-mcp"
SECRETS_DIR="/opt/secrets/sjl-unified-mcp"
SERVICE="sjl-unified-mcp.service"
PORT="${SJL_UNIFIED_MCP_PORT:-8798}"
USER_NAME="${SJL_UNIFIED_MCP_USER:-sjlmcp}"
GROUP_NAME="${SJL_UNIFIED_MCP_GROUP:-sjlmcp}"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="/root/sjl-unified-mcp-backup-${STAMP}"

log() { printf '\n== %s ==\n' "$*"; }
die() { echo "ERROR: $*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"; }

[[ ${EUID:-$(id -u)} -eq 0 ]] || die "Run as root."
for c in python3 systemctl install openssl curl awk sed grep ss; do need "$c"; done

log "Create service account and directories"
getent group "$GROUP_NAME" >/dev/null || groupadd --system "$GROUP_NAME"
id "$USER_NAME" >/dev/null 2>&1 || useradd \
  --system --gid "$GROUP_NAME" --home "$APP_DIR" --shell /usr/sbin/nologin "$USER_NAME"

# Backup existing content
mkdir -p "$BACKUP"
for d in "$APP_DIR" "$ETC_DIR" "$SECRETS_DIR"; do
  if [[ -d "$d" ]]; then
    cp -a "$d" "$BACKUP/$(basename "$d")" 2>/dev/null || true
  fi
done

mkdir -p "$APP_DIR" "$ETC_DIR" "$SECRETS_DIR"
chmod 0750 "$APP_DIR" "$ETC_DIR" "$SECRETS_DIR"
chown -R "$USER_NAME:$GROUP_NAME" "$APP_DIR"
chown root:"$GROUP_NAME" "$ETC_DIR" "$SECRETS_DIR"

log "Create Python virtual environment"
python3 -m venv "$APP_DIR/venv"
"$APP_DIR/venv/bin/pip" install --upgrade pip wheel --no-cache-dir
"$APP_DIR/venv/bin/pip" install --no-cache-dir \
  "mcp[cli]>=1.10" \
  "fastapi>=0.115" \
  "uvicorn>=0.34" \
  "requests>=2.32" \
  "oci>=2.150" \
  "google-api-python-client>=2.160" \
  "google-auth>=2.38"

log "Write unified MCP application (with improved error handling)"
cat > "$APP_DIR/server.py" <<'PY'
from __future__ import annotations

import json
import os
import pathlib
import shlex
import subprocess
import sys
from typing import Any

import requests
from mcp.server.fastmcp import FastMCP

PORT = int(os.getenv("SJL_UNIFIED_MCP_PORT", "8799"))
mcp = FastMCP("SJL Unified Cloud MCP", host="0.0.0.0", port=PORT)

WRITE_TOKEN = os.getenv("WRITE_APPROVAL_TOKEN", "")
SERVICE_USER = os.getenv("HOSTINGER_ROOTLESS_USER", "sjl")
BOOKSTACK_URL = os.getenv("BOOKSTACK_URL", "").rstrip("/")
BOOKSTACK_TOKEN_ID = os.getenv("BOOKSTACK_TOKEN_ID", "")
BOOKSTACK_TOKEN_SECRET = os.getenv("BOOKSTACK_TOKEN_SECRET", "")
HOSTINGER_API_BASE_URL = os.getenv("HOSTINGER_API_BASE_URL", "https://developers.hostinger.com")
HOSTINGER_API_TOKEN = os.getenv("HOSTINGER_API_TOKEN", "")
HOSTINGER_VPS_ID = os.getenv("HOSTINGER_VPS_ID", "")
GOOGLE_PROJECT = os.getenv("GOOGLE_CLOUD_PROJECT", "")
OCI_CONFIG_FILE = os.getenv("OCI_CONFIG_FILE", "/opt/secrets/oci/config")
OCI_PROFILE = os.getenv("OCI_PROFILE", "DEFAULT")

def csvset(name: str) -> set[str]:
    return {x.strip() for x in os.getenv(name, "").split(",") if x.strip()}

ALLOWED_USER_SERVICES = csvset("ALLOWED_USER_SERVICES")
ALLOWED_CONTAINERS = csvset("ALLOWED_CONTAINERS")
ALLOWED_GCP_INSTANCES = csvset("ALLOWED_GCP_INSTANCES")
ALLOWED_OCI_INSTANCES = csvset("ALLOWED_OCI_INSTANCES")
ALLOWED_FILE_ROOTS = [pathlib.Path(p).resolve() for p in csvset("ALLOWED_FILE_ROOTS")]
ALLOWED_WRITE_EXTENSIONS = csvset("ALLOWED_WRITE_EXTENSIONS") or {
    ".txt", ".md", ".json", ".yaml", ".yml", ".toml", ".conf", ".ini", ".service", ".container", ".network"
}

def ok(data: Any = None, **extra: Any) -> dict[str, Any]:
    out = {"ok": True}
    if data is not None:
        out["data"] = data
    out.update(extra)
    return out

def fail(message: str, **extra: Any) -> dict[str, Any]:
    out = {"ok": False, "error": message}
    out.update(extra)
    return out

def require_write(token: str) -> None:
    if not WRITE_TOKEN:
        raise PermissionError("Write access is not configured.")
    if token != WRITE_TOKEN:
        raise PermissionError("Invalid approval token.")

def run(cmd: list[str], timeout: int = 45, env: dict[str, str] | None = None) -> dict[str, Any]:
    p = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, env=env)
    return {
        "returncode": p.returncode,
        "stdout": p.stdout.strip(),
        "stderr": p.stderr.strip(),
        "command": shlex.join(cmd),
    }

def rootless_env() -> dict[str, str]:
    import pwd
    uid = pwd.getpwnam(SERVICE_USER).pw_uid
    env = os.environ.copy()
    env["XDG_RUNTIME_DIR"] = f"/run/user/{uid}"
    return env

def ensure_allowed(value: str, allowed: set[str], label: str) -> None:
    if value not in allowed:
        raise PermissionError(f"{label} is not allowlisted: {value}")

def resolve_allowed_path(raw: str, for_write: bool = False) -> pathlib.Path:
    p = pathlib.Path(raw).expanduser().resolve()
    if not ALLOWED_FILE_ROOTS:
        raise PermissionError("No filesystem roots are allowlisted.")
    if not any(p == root or root in p.parents for root in ALLOWED_FILE_ROOTS):
        raise PermissionError(f"Path is outside the allowlisted roots: {p}")
    if for_write and p.suffix and p.suffix.lower() not in ALLOWED_WRITE_EXTENSIONS:
        raise PermissionError(f"File extension is not approved for writing: {p.suffix}")
    return p

@mcp.tool()
def gateway_health() -> dict[str, Any]:
    return ok({
        "service": "sjl-unified-mcp",
        "port": PORT,
        "write_token_configured": bool(WRITE_TOKEN),
        "bookstack_configured": bool(BOOKSTACK_URL and BOOKSTACK_TOKEN_ID and BOOKSTACK_TOKEN_SECRET),
        "hostinger_token_present": bool(HOSTINGER_API_TOKEN),
        "hostinger_vps_id_present": bool(HOSTINGER_VPS_ID),
        "google_project": GOOGLE_PROJECT or None,
        "oci_config_present": pathlib.Path(OCI_CONFIG_FILE).exists(),
        "allowed_services": sorted(ALLOWED_USER_SERVICES),
        "allowed_containers": sorted(ALLOWED_CONTAINERS),
        "allowed_gcp_instances": sorted(ALLOWED_GCP_INSTANCES),
        "allowed_oci_instances": sorted(ALLOWED_OCI_INSTANCES),
        "allowed_file_roots": [str(x) for x in ALLOWED_FILE_ROOTS],
    })

@mcp.tool()
def vps_local_status() -> dict[str, Any]:
    return ok({
        "uptime": run(["uptime", "-p"]),
        "disk": run(["df", "-h", "/"]),
        "memory": run(["free", "-h"]),
        "kernel": run(["uname", "-a"]),
        "ports": run(["ss", "-ltnp"]),
    })

@mcp.tool()
def hostinger_api_probe() -> dict[str, Any]:
    if not HOSTINGER_API_TOKEN:
        return fail("HOSTINGER_API_TOKEN is not configured.")
    headers = {"Authorization": f"Bearer {HOSTINGER_API_TOKEN}", "Accept": "application/json"}
    url = f"{HOSTINGER_API_BASE_URL.rstrip('/')}/api/vps/v1/virtual-machines"
    r = requests.get(url, headers=headers, timeout=30)
    return ok({"status_code": r.status_code, "body_preview": r.text[:2000]}) if r.ok else fail(
        "Hostinger API request failed", status_code=r.status_code, body_preview=r.text[:2000]
    )

@mcp.tool()
def hostinger_podman_list() -> dict[str, Any]:
    cmd = ["sudo", "-iu", SERVICE_USER, "podman", "ps", "-a", "--format", "json"]
    result = run(cmd, env=rootless_env())
    return ok(result) if result["returncode"] == 0 else fail("Podman list failed.", **result)

@mcp.tool()
def hostinger_podman_action(container: str, action: str, approval_token: str) -> dict[str, Any]:
    require_write(approval_token)
    ensure_allowed(container, ALLOWED_CONTAINERS, "Container")
    if action not in {"start", "stop", "restart"}:
        return fail("Unsupported action.")
    result = run(["sudo", "-iu", SERVICE_USER, "podman", action, container], env=rootless_env())
    return ok(result) if result["returncode"] == 0 else fail("Podman action failed.", **result)

@mcp.tool()
def hostinger_user_service_status(service: str) -> dict[str, Any]:
    ensure_allowed(service, ALLOWED_USER_SERVICES, "Service")
    result = run(["sudo", "-iu", SERVICE_USER, "systemctl", "--user", "status", service, "--no-pager"], env=rootless_env())
    return ok(result) if result["returncode"] in {0, 3} else fail("Service status failed.", **result)

@mcp.tool()
def hostinger_user_service_action(service: str, action: str, approval_token: str) -> dict[str, Any]:
    require_write(approval_token)
    ensure_allowed(service, ALLOWED_USER_SERVICES, "Service")
    if action not in {"start", "stop", "restart", "reload"}:
        return fail("Unsupported action.")
    result = run(["sudo", "-iu", SERVICE_USER, "systemctl", "--user", action, service], env=rootless_env())
    return ok(result) if result["returncode"] == 0 else fail("Service action failed.", **result)

def oci_config():
    import oci
    return oci.config.from_file(OCI_CONFIG_FILE, OCI_PROFILE)

@mcp.tool()
def oracle_identity_test() -> dict[str, Any]:
    try:
        import oci
        cfg = oci_config()
        identity = oci.identity.IdentityClient(cfg)
        tenancy = identity.get_tenancy(cfg["tenancy"]).data
        user = identity.get_user(cfg["user"]).data
        return ok({"tenancy": str(tenancy), "user": str(user), "region": cfg.get("region")})
    except Exception as e:
        return fail(str(e))

@mcp.tool()
def oracle_instances_list(compartment_id: str = "") -> dict[str, Any]:
    try:
        import oci
        cfg = oci_config()
        cid = compartment_id or cfg["tenancy"]
        client = oci.core.ComputeClient(cfg)
        rows = client.list_instances(cid).data
        return ok([{
            "id": x.id, "display_name": x.display_name, "state": x.lifecycle_state,
            "shape": x.shape, "availability_domain": x.availability_domain,
        } for x in rows])
    except Exception as e:
        return fail(str(e))

@mcp.tool()
def oracle_instance_action(instance_ocid: str, action: str, approval_token: str) -> dict[str, Any]:
    require_write(approval_token)
    ensure_allowed(instance_ocid, ALLOWED_OCI_INSTANCES, "OCI instance")
    mapping = {"start": "START", "stop": "SOFTSTOP", "reset": "RESET", "softreset": "SOFTRESET"}
    if action.lower() not in mapping:
        return fail("Unsupported action.")
    try:
        import oci
        client = oci.core.ComputeClient(oci_config())
        resp = client.instance_action(instance_ocid, mapping[action.lower()])
        return ok({"status": resp.status})
    except Exception as e:
        return fail(str(e))

def google_credentials():
    from google.auth import default
    creds, project = default(scopes=["https://www.googleapis.com/auth/cloud-platform"])
    return creds, GOOGLE_PROJECT or project

@mcp.tool()
def google_compute_instances_list() -> dict[str, Any]:
    try:
        from googleapiclient.discovery import build
        creds, project = google_credentials()
        svc = build("compute", "v1", credentials=creds, cache_discovery=False)
        result = svc.instances().aggregatedList(project=project).execute()
        rows = []
        for scope, payload in result.get("items", {}).items():
            for x in payload.get("instances", []):
                rows.append({
                    "name": x["name"], "status": x.get("status"), "zone": x.get("zone", "").split("/")[-1],
                    "machine_type": x.get("machineType", "").split("/")[-1],
                })
        return ok({"project": project, "instances": rows})
    except Exception as e:
        return fail(str(e))

@mcp.tool()
def google_instance_action(instance: str, zone: str, action: str, approval_token: str) -> dict[str, Any]:
    require_write(approval_token)
    ensure_allowed(f"{zone}/{instance}", ALLOWED_GCP_INSTANCES, "GCP instance")
    if action not in {"start", "stop", "reset", "suspend", "resume"}:
        return fail("Unsupported action.")
    try:
        from googleapiclient.discovery import build
        creds, project = google_credentials()
        svc = build("compute", "v1", credentials=creds, cache_discovery=False)
        req = getattr(svc.instances(), action)(project=project, zone=zone, instance=instance)
        return ok(req.execute())
    except Exception as e:
        return fail(str(e))

@mcp.tool()
def google_service_enable(service: str, approval_token: str) -> dict[str, Any]:
    require_write(approval_token)
    safe = {"compute.googleapis.com", "iam.googleapis.com", "serviceusage.googleapis.com"}
    if service not in safe:
        return fail("Service is not in the fixed safe allowlist.")
    try:
        from googleapiclient.discovery import build
        creds, project = google_credentials()
        svc = build("serviceusage", "v1", credentials=creds, cache_discovery=False)
        name = f"projects/{project}/services/{service}"
        return ok(svc.services().enable(name=name, body={}).execute())
    except Exception as e:
        return fail(str(e))

@mcp.tool()
def bookstack_page_upsert(title: str, markdown: str, book_id: int = 1, approval_token: str = "") -> dict[str, Any]:
    require_write(approval_token)
    if not (BOOKSTACK_URL and BOOKSTACK_TOKEN_ID and BOOKSTACK_TOKEN_SECRET):
        return fail("BookStack credentials are not configured.")
    headers = {
        "Authorization": f"Token {BOOKSTACK_TOKEN_ID}:{BOOKSTACK_TOKEN_SECRET}",
        "Content-Type": "application/json",
    }
    search = requests.get(
        f"{BOOKSTACK_URL}/api/search",
        headers=headers,
        params={"query": f'title:"{title}"', "count": 100},
        timeout=30,
    )
    if not search.ok:
        return fail("BookStack search failed.", status_code=search.status_code, body=search.text[:2000])
    exact = next((x for x in search.json().get("data", []) if x.get("name") == title and x.get("type") == "page"), None)
    payload = {"name": title, "markdown": markdown}
    if exact:
        r = requests.put(f"{BOOKSTACK_URL}/api/pages/{exact['id']}", headers=headers, json=payload, timeout=30)
    else:
        payload["book_id"] = book_id
        r = requests.post(f"{BOOKSTACK_URL}/api/pages", headers=headers, json=payload, timeout=30)
    return ok(r.json()) if r.ok else fail("BookStack upsert failed.", status_code=r.status_code, body=r.text[:2000])

@mcp.tool()
def filesystem_list(path: str) -> dict[str, Any]:
    try:
        p = resolve_allowed_path(path)
        if not p.is_dir():
            return fail("Path is not a directory.")
        return ok([{
            "name": x.name,
            "path": str(x),
            "type": "directory" if x.is_dir() else "file",
            "size": x.stat().st_size if x.is_file() else None,
        } for x in sorted(p.iterdir(), key=lambda z: (not z.is_dir(), z.name.lower()))])
    except Exception as e:
        return fail(str(e))

@mcp.tool()
def filesystem_read_text(path: str, max_bytes: int = 1048576) -> dict[str, Any]:
    try:
        p = resolve_allowed_path(path)
        if not p.is_file():
            return fail("Path is not a file.")
        data = p.read_bytes()[:max_bytes]
        return ok({"path": str(p), "text": data.decode("utf-8", errors="replace"), "truncated": p.stat().st_size > len(data)})
    except Exception as e:
        return fail(str(e))

@mcp.tool()
def filesystem_write_text(path: str, text: str, approval_token: str, create_parents: bool = False) -> dict[str, Any]:
    try:
        require_write(approval_token)
        p = resolve_allowed_path(path, for_write=True)
        if create_parents:
            p.parent.mkdir(parents=True, exist_ok=True)
        if not p.parent.exists():
            return fail("Parent directory does not exist.")
        tmp = p.with_name(p.name + ".tmp")
        tmp.write_text(text, encoding="utf-8")
        os.replace(tmp, p)
        return ok({"path": str(p), "bytes": len(text.encode("utf-8"))})
    except Exception as e:
        return fail(str(e))

if __name__ == "__main__":
    # Validate critical credentials before starting
    errors = []
    if not WRITE_TOKEN:
        errors.append("WRITE_APPROVAL_TOKEN is not set")
    if not (BOOKSTACK_URL and BOOKSTACK_TOKEN_ID and BOOKSTACK_TOKEN_SECRET):
        errors.append("BookStack credentials incomplete")
    if errors:
        print("WARNING: Missing configuration:", file=sys.stderr)
        for e in errors:
            print(f"  - {e}", file=sys.stderr)
    mcp.run(transport="streamable-http")
PY

chown "$USER_NAME:$GROUP_NAME" "$APP_DIR/server.py"
chmod 0750 "$APP_DIR/server.py"

log "Create environment template with validation"
ENV_FILE="$ETC_DIR/runtime.env"
if [[ ! -f "$ENV_FILE" ]]; then
  cat > "$ENV_FILE" <<EOF
SJL_UNIFIED_MCP_PORT=$PORT
HOSTINGER_ROOTLESS_USER=sjl

# Controlled write approval
WRITE_APPROVAL_TOKEN=

# Hostinger
HOSTINGER_API_BASE_URL=https://developers.hostinger.com
HOSTINGER_API_TOKEN=
HOSTINGER_VPS_ID=

# Oracle
OCI_CONFIG_FILE=/opt/secrets/oci/config
OCI_PROFILE=DEFAULT

# Google Cloud
GOOGLE_CLOUD_PROJECT=resourcespace-nexus
GOOGLE_APPLICATION_CREDENTIALS=/opt/secrets/sjl-unified-mcp/google-service-account.json

# BookStack
BOOKSTACK_URL=https://bookstack.shannonjlove.cloud
BOOKSTACK_TOKEN_ID=
BOOKSTACK_TOKEN_SECRET=

# Allowlisted write targets
ALLOWED_USER_SERVICES=
ALLOWED_CONTAINERS=
ALLOWED_GCP_INSTANCES=
ALLOWED_OCI_INSTANCES=
ALLOWED_FILE_ROOTS=/srv/sjl,/home/sjl
ALLOWED_WRITE_EXTENSIONS=.txt,.md,.json,.yaml,.yml,.toml,.conf,.ini,.service,.container,.network
EOF
fi
chmod 0640 "$ENV_FILE"
chown root:"$GROUP_NAME" "$ENV_FILE"

# Generate write token if missing
if ! grep -q '^WRITE_APPROVAL_TOKEN=.\+' "$ENV_FILE"; then
  TOKEN="$(openssl rand -hex 32)"
  sed -i "s/^WRITE_APPROVAL_TOKEN=.*/WRITE_APPROVAL_TOKEN=$TOKEN/" "$ENV_FILE"
  printf '%s\n' "$TOKEN" > /root/.sjl-unified-mcp-write-token
  chmod 0600 /root/.sjl-unified-mcp-write-token
fi

log "Install sudo policy – restrict targets to safe characters only"
cat > /etc/sudoers.d/sjl-unified-mcp <<EOF
# Allow service user to run specific commands as the rootless user 'sjl'
# Arguments are restricted to names matching [A-Za-z0-9_.-] to prevent options injection
$USER_NAME ALL=(sjl) NOPASSWD: /usr/bin/podman ps -a --format json
$USER_NAME ALL=(sjl) NOPASSWD: /usr/bin/podman start [A-Za-z0-9_.-]*
$USER_NAME ALL=(sjl) NOPASSWD: /usr/bin/podman stop [A-Za-z0-9_.-]*
$USER_NAME ALL=(sjl) NOPASSWD: /usr/bin/podman restart [A-Za-z0-9_.-]*
$USER_NAME ALL=(sjl) NOPASSWD: /usr/bin/systemctl --user status [A-Za-z0-9_.-]*
$USER_NAME ALL=(sjl) NOPASSWD: /usr/bin/systemctl --user start [A-Za-z0-9_.-]*
$USER_NAME ALL=(sjl) NOPASSWD: /usr/bin/systemctl --user stop [A-Za-z0-9_.-]*
$USER_NAME ALL=(sjl) NOPASSWD: /usr/bin/systemctl --user restart [A-Za-z0-9_.-]*
$USER_NAME ALL=(sjl) NOPASSWD: /usr/bin/systemctl --user reload [A-Za-z0-9_.-]*
EOF
chmod 0440 /etc/sudoers.d/sjl-unified-mcp
visudo -cf /etc/sudoers.d/sjl-unified-mcp

log "Install systemd service with additional hardening"
cat > "/etc/systemd/system/$SERVICE" <<EOF
[Unit]
Description=SJL Unified Cloud MCP Gateway
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$USER_NAME
Group=$GROUP_NAME
WorkingDirectory=$APP_DIR
EnvironmentFile=$ENV_FILE
ExecStart=$APP_DIR/venv/bin/python $APP_DIR/server.py
Restart=on-failure
RestartSec=3
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=read-only
ProtectClock=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
ReadOnlyPaths=/
ReadWritePaths=/srv/sjl /home/sjl /var/log
CapabilityBoundingSet=
AmbientCapabilities=
LockPersonality=true
MemoryDenyWriteExecute=true
RestrictSUIDSGID=true
SystemCallArchitectures=native

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now "$SERVICE"

log "Wait for service to become responsive"
sleep 5
if systemctl is-active --quiet "$SERVICE"; then
  log "Service is active."
else
  log "WARNING: Service not active. Check logs: journalctl -u $SERVICE"
fi

ss -ltnp "sport = :$PORT" || true

cat <<EOF

Deployment complete.

Primary endpoint:
  http://<host>:$PORT/mcp

Runtime configuration:
  $ENV_FILE

Write token file:
  /root/.sjl-unified-mcp-write-token

Next required actions:
1. Restore real secrets into $ENV_FILE.
2. Populate every ALLOWED_* entry with exact approved targets.
3. Copy OCI config/key to /opt/secrets/oci/.
4. Copy Google service-account JSON to:
     /opt/secrets/sjl-unified-mcp/google-service-account.json
5. Restart:
     systemctl restart $SERVICE
6. Verify: curl http://localhost:$PORT/mcp (POST gateway_health)
7. Repoint ChatGPT connector registrations to this one endpoint.
8. Remove duplicate V1/V2 and standalone Oracle registrations after validation.

Backup:
  $BACKUP
EOF
