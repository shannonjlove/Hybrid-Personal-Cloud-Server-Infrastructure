#!/usr/bin/env python3
from starlette.responses import JSONResponse
import json
import os
import socket
import subprocess
from pathlib import Path
from typing import Any, Dict, List, Optional
from gcp_tools import register_gcp_tools
from write_tools import register_write_tools

try:
    from mcp.server.fastmcp import FastMCP
except ImportError:
    from fastmcp import FastMCP

ENV_FILE = Path("/opt/secrets/sjl-cloud-access.env")


def load_env_file(path: Path = ENV_FILE) -> None:
    if not path.exists():
        return

    for raw in path.read_text(errors="ignore").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue

        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip('"').strip("'")

        if key and key not in os.environ:
            os.environ[key] = value


load_env_file()

SJL_MCP_HOST = os.getenv("SJL_MCP_HOST", os.getenv("HOST", "127.0.0.1"))
SJL_MCP_PORT = int(os.getenv("SJL_MCP_PORT", os.getenv("PORT", "8797")))

mcp = FastMCP(
    "SJL Cloud Access MCP",
    host=SJL_MCP_HOST,
    port=SJL_MCP_PORT,
    streamable_http_path="/mcp",
    sse_path="/sse",
)


def ok(data: Any) -> Dict[str, Any]:
    return {"ok": True, "data": data}


def fail(message: str, detail: Optional[Any] = None) -> Dict[str, Any]:
    return {"ok": False, "error": message, "detail": detail}


def run_cmd(cmd: List[str], timeout: int = 20) -> Dict[str, Any]:
    try:
        p = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout,
            check=False,
        )
        return {
            "returncode": p.returncode,
            "stdout": p.stdout.strip(),
            "stderr": p.stderr.strip(),
        }
    except Exception as exc:
        return {"returncode": -1, "stdout": "", "stderr": str(exc)}


@mcp.tool()
def cloud_access_health() -> Dict[str, Any]:
    return ok({
        "service": "sjl-cloud-access-mcp",
        "hostname": socket.gethostname(),
        "host": SJL_MCP_HOST,
        "port": SJL_MCP_PORT,
        "readonly": os.getenv("SJL_MCP_READONLY", "true"),
        "providers": {
            "hostinger_token_present": bool(os.getenv("HOSTINGER_API_TOKEN")),
            "oci_config_present": Path(os.getenv("OCI_CONFIG_FILE", "/opt/secrets/oci-config")).exists(),
            "google_credentials_present": Path(os.getenv("GOOGLE_APPLICATION_CREDENTIALS", "/opt/secrets/google-cloud-service-account.json")).exists(),
            "google_project": os.getenv("GOOGLE_CLOUD_PROJECT", ""),
        },
    })


@mcp.tool()
def vps_local_status() -> Dict[str, Any]:
    commands = {
        "uptime": ["uptime", "-p"],
        "disk": ["df", "-h", "/"],
        "memory": ["free", "-h"],
        "kernel": ["uname", "-a"],
        "listening_ports": ["bash", "-lc", "ss -ltnp 2>/dev/null | grep -E ':8797|:8766|:8000|:8811|python' || true"],
    }
    return ok({name: run_cmd(cmd) for name, cmd in commands.items()})


@mcp.tool()
def hostinger_config_status() -> Dict[str, Any]:
    return ok({
        "api_base_url": os.getenv("HOSTINGER_API_BASE_URL", ""),
        "token_present": bool(os.getenv("HOSTINGER_API_TOKEN")),
        "vps_id_present": bool(os.getenv("HOSTINGER_VPS_ID")),
        "domain_present": bool(os.getenv("HOSTINGER_DOMAIN")),
    })


@mcp.tool()
def hostinger_api_probe() -> Dict[str, Any]:
    token = os.getenv("HOSTINGER_API_TOKEN", "")
    base = os.getenv("HOSTINGER_API_BASE_URL", "https://developers.hostinger.com/api").rstrip("/")

    if not token:
        return fail("HOSTINGER_API_TOKEN is not set")

    try:
        import requests

        r = requests.get(
            base,
            headers={
                "Authorization": f"Bearer {token}",
                "Accept": "application/json",
                "User-Agent": "sjl-mcp/1.0",
            },
            timeout=20,
        )
        return ok({"status_code": r.status_code, "body_preview": r.text[:1200]})
    except Exception as exc:
        return fail("Hostinger API probe failed", str(exc))


@mcp.tool()
def oracle_config_status() -> Dict[str, Any]:
    config_file = Path(os.getenv("OCI_CONFIG_FILE", "/opt/secrets/oci-config"))
    profile = os.getenv("OCI_PROFILE", "DEFAULT")

    key_file = None
    if config_file.exists():
        for line in config_file.read_text(errors="ignore").splitlines():
            if line.strip().startswith("key_file="):
                key_file = line.split("=", 1)[1].strip()

    return ok({
        "oci_config_present": config_file.exists(),
        "oci_profile": profile,
        "key_file_declared": bool(key_file),
        "key_file_present": Path(key_file).exists() if key_file else False,
    })


@mcp.tool()
def google_config_status() -> Dict[str, Any]:
    cred_path = Path(os.getenv(
        "GOOGLE_APPLICATION_CREDENTIALS",
        "/opt/secrets/google-cloud-service-account.json",
    ))

    service_account_email = ""
    if cred_path.exists():
        try:
            data = json.loads(cred_path.read_text())
            service_account_email = data.get("client_email", "")
        except Exception:
            pass

    return ok({
        "credentials_present": cred_path.exists(),
        "service_account_email": service_account_email,
        "default_project": os.getenv("GOOGLE_CLOUD_PROJECT", ""),
    })



# Register Google Cloud read-only tools before MCP startup.
register_gcp_tools(mcp)
register_write_tools(mcp)

# BEGIN SJL OCI TOOL REGISTRATION
from oracle_tools import (
    oracle_identity_test, oracle_regions_list, oracle_compartments_list,
    oracle_instances_list, oracle_vcns_list, oracle_subnets_list,
    oracle_boot_volumes_list, oracle_block_volumes_list,
    oracle_buckets_list, oracle_resources_summary,
)

for _oci_tool in (
    oracle_identity_test, oracle_regions_list, oracle_compartments_list,
    oracle_instances_list, oracle_vcns_list, oracle_subnets_list,
    oracle_boot_volumes_list, oracle_block_volumes_list,
    oracle_buckets_list, oracle_resources_summary,
):
    mcp.tool()(_oci_tool)
# END SJL OCI TOOL REGISTRATION

# BEGIN SJL FASTMCP HEALTH ROUTES
@mcp.custom_route("/health", methods=["GET"])
async def sjl_health_check(request):
    """Fast, dependency-free liveness endpoint."""
    return JSONResponse(
        {
            "status": "healthy",
            "service": "SJL Unified Cloud MCP V2",
            "transport": "streamable-http",
        },
        status_code=200,
    )


@mcp.custom_route("/health/live", methods=["GET"])
async def sjl_liveness_check(request):
    """Explicit liveness alias for monitors and orchestrators."""
    return JSONResponse(
        {
            "status": "alive",
            "service": "SJL Unified Cloud MCP V2",
        },
        status_code=200,
    )
# END SJL FASTMCP HEALTH ROUTES

if __name__ == "__main__":
    print(f"Starting MCP on http://{SJL_MCP_HOST}:{SJL_MCP_PORT}/mcp", flush=True)
    mcp.run(transport="streamable-http")
