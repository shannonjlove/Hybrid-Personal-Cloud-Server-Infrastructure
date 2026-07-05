#!/usr/bin/env bash
# deploy_memory_agent_v2_no_api.sh
# Decommissions any existing memory-agent (v1 — Anthropic API-backed) and
# deploys v2: a plain file-CRUD REST API over /memories, no external API,
# no cost. Same port (8100), same purpose from the outside — internals
# rewritten.

set -euo pipefail

APP_DIR="/opt/memory-agent"
QUADLET_DIR="/etc/containers/systemd"
TAILSCALE_IP="100.115.66.75"
BIND_PORT="8100"

echo "==> Decommissioning any existing memory-agent (v1)..."
if systemctl is-active --quiet memory-agent.service 2>/dev/null; then
  systemctl stop memory-agent.service
  echo "    Stopped running memory-agent.service"
fi
if podman secret exists anthropic_api_key 2>/dev/null; then
  podman secret rm anthropic_api_key
  echo "    Removed Podman secret 'anthropic_api_key' — no Anthropic API key remains anywhere in this stack."
else
  echo "    No 'anthropic_api_key' secret found (nothing to remove)."
fi
podman rmi -f localhost/memory-agent:latest 2>/dev/null || true

echo "==> Writing app/requirements.txt (no 'anthropic' package)"
mkdir -p "${APP_DIR}/app"
cat > "${APP_DIR}/app/requirements.txt" <<'EOF'
fastapi==0.115.*
uvicorn[standard]==0.32.*
pydantic==2.*
EOF

echo "==> Writing app/main.py (v2 — file CRUD, no model calls)"
cat > "${APP_DIR}/app/main.py" <<'PYEOF'
"""
memory-agent (v2 — no external API)
Plain REST CRUD over the shared-context filesystem (/memories, backed by
/mnt/shared-context/memory-agent on the host). No model calls, no Anthropic
API key, no per-request cost of any kind — this is file I/O with an HTTP
front door, nothing more.

v1 of this service called the Anthropic Messages API's memory_20250818 tool
per request, which cost money per call. That's removed entirely. If you ever
want a live model in the loop again, that's a new, explicit decision — not
something this service does implicitly.
"""
import os
import re
import shutil
from pathlib import Path
from typing import Optional

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

MEMORY_BASE_PATH = Path(os.environ.get("MEMORY_BASE_PATH", "/memories")).resolve()
MEMORY_BASE_PATH.mkdir(parents=True, exist_ok=True)

app = FastAPI(title="SJL Memory Agent — file CRUD, no external API, no cost")


def _resolve(path: str) -> Path:
    if re.search(r"\.\.[/\\]|%2e%2e", path, re.IGNORECASE):
        raise ValueError(f"Path traversal rejected: {path}")
    stripped = path.lstrip("/")
    target = (MEMORY_BASE_PATH / stripped).resolve() if stripped else MEMORY_BASE_PATH
    if not str(target).startswith(str(MEMORY_BASE_PATH)):
        raise ValueError(f"Path escapes memory root: {path}")
    return target


def _list_dir(target: Path) -> dict:
    entries = []
    for item in sorted(target.rglob("*")):
        rel_parts = item.relative_to(target).parts
        if any(p.startswith(".") or p == "node_modules" for p in rel_parts):
            continue
        if len(rel_parts) > 2:
            continue
        entries.append(
            {
                "path": "/" + str(item.relative_to(MEMORY_BASE_PATH)),
                "type": "dir" if item.is_dir() else "file",
                "size": item.stat().st_size if item.is_file() else 0,
            }
        )
    return {"path": "/", "entries": entries}


class CreateBody(BaseModel):
    file_text: str = ""


class RenameBody(BaseModel):
    old_path: str
    new_path: str


@app.get("/healthz")
def healthz():
    return {"status": "ok", "uses_anthropic_api": False, "cost_per_request": 0}


@app.get("/memories")
@app.get("/memories/{path:path}")
def view(path: str = "", start: Optional[int] = None, end: Optional[int] = None):
    try:
        target = _resolve(path)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))

    if not target.exists():
        if target == MEMORY_BASE_PATH:
            return _list_dir(target)
        raise HTTPException(status_code=404, detail=f"{path} does not exist")

    if target.is_dir():
        return _list_dir(target)

    lines = target.read_text(errors="replace").splitlines()
    s = max(1, start) if start else 1
    e = len(lines) if not end or end == -1 else min(len(lines), end)
    return {
        "path": "/" + path.lstrip("/"),
        "type": "file",
        "lines": [{"n": i, "text": l} for i, l in enumerate(lines[s - 1 : e], start=s)],
    }


@app.post("/memories/{path:path}")
def create(path: str, body: CreateBody):
    try:
        target = _resolve(path)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    if target.exists():
        raise HTTPException(status_code=409, detail=f"{path} already exists")
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(body.file_text)
    return {"status": "created", "path": "/" + path.lstrip("/")}


@app.patch("/memories/{path:path}")
def edit(path: str, body: dict):
    try:
        target = _resolve(path)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    if not target.exists() or target.is_dir():
        raise HTTPException(status_code=404, detail=f"{path} does not exist")

    if "old_str" in body and "new_str" in body:
        content = target.read_text(errors="replace")
        count = content.count(body["old_str"])
        if count == 0:
            raise HTTPException(status_code=400, detail="old_str not found in file")
        if count > 1:
            raise HTTPException(status_code=400, detail="old_str is not unique in file")
        target.write_text(content.replace(body["old_str"], body["new_str"], 1))
        return {"status": "edited", "path": "/" + path.lstrip("/")}

    if "insert_line" in body and "insert_text" in body:
        lines = target.read_text(errors="replace").splitlines()
        n = body["insert_line"]
        if n < 0 or n > len(lines):
            raise HTTPException(status_code=400, detail="insert_line out of range")
        lines.insert(n, str(body["insert_text"]).rstrip("\n"))
        target.write_text("\n".join(lines))
        return {"status": "edited", "path": "/" + path.lstrip("/")}

    raise HTTPException(
        status_code=400, detail="Provide {old_str,new_str} or {insert_line,insert_text}"
    )


@app.delete("/memories/{path:path}")
def delete(path: str):
    if path.strip("/") == "":
        raise HTTPException(status_code=400, detail="Cannot delete the /memories root")
    try:
        target = _resolve(path)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    if not target.exists():
        raise HTTPException(status_code=404, detail=f"{path} does not exist")
    if target.is_dir():
        shutil.rmtree(target)
    else:
        target.unlink()
    return {"status": "deleted", "path": "/" + path.lstrip("/")}


@app.post("/memories:rename")
def rename(body: RenameBody):
    if body.old_path.strip("/") == "":
        raise HTTPException(status_code=400, detail="Cannot rename the /memories root")
    try:
        src = _resolve(body.old_path)
        dst = _resolve(body.new_path)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    if not src.exists():
        raise HTTPException(status_code=404, detail=f"{body.old_path} does not exist")
    if dst.exists():
        raise HTTPException(status_code=409, detail=f"{body.new_path} already exists")
    dst.parent.mkdir(parents=True, exist_ok=True)
    src.rename(dst)
    return {"status": "renamed", "from": body.old_path, "to": body.new_path}

PYEOF

echo "==> Writing app/Containerfile"
cat > "${APP_DIR}/app/Containerfile" <<'EOF'
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY main.py .
RUN mkdir -p /memories
EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
EOF

echo "==> Building image (localhost/memory-agent:latest, v2)"
podman build -t localhost/memory-agent:latest "${APP_DIR}/app"

echo "==> Writing Quadlet (no Secret= line — nothing sensitive to store)"
mkdir -p "${QUADLET_DIR}"
cat > "${QUADLET_DIR}/memory-agent.container" <<EOF
[Unit]
Description=SJL Memory Agent — file CRUD, no external API, no cost
After=network-online.target

[Container]
Image=localhost/memory-agent:latest
ContainerName=memory-agent
PublishPort=${TAILSCALE_IP}:${BIND_PORT}:8000
Volume=/opt/memory-agent/data:/memories:Z

[Service]
Restart=on-failure
TimeoutStartSec=60

[Install]
WantedBy=multi-user.target
EOF
# NOTE: if Step 1 (shared-context) already ran, its script repoints this
# Volume= line at /mnt/shared-context/memory-agent via sed. If you're running
# this v2 script AFTER Step 1, re-run that repoint manually:
#   sed -i 's#Volume=.*:/memories:Z#Volume=/mnt/shared-context/memory-agent:/memories:Z#' \
#     /etc/containers/systemd/memory-agent.container
#   systemctl daemon-reload && systemctl restart memory-agent

systemctl daemon-reload
systemctl start memory-agent.service

sleep 3
echo "==> Service status"
systemctl status memory-agent.service --no-pager || true

echo "==> Health check"
if curl -fsS "http://${TAILSCALE_IP}:${BIND_PORT}/healthz"; then
  echo
  echo "OK — memory-agent v2 is up. uses_anthropic_api: false, cost_per_request: 0"
  echo "Test:"
  echo "  curl -s http://${TAILSCALE_IP}:${BIND_PORT}/memories"
  echo "  curl -s -X POST http://${TAILSCALE_IP}:${BIND_PORT}/memories/test.md \\"
  echo "    -H 'Content-Type: application/json' -d '{\"file_text\":\"hello\"}'"
else
  echo
  echo "Health check failed. Inspect with: journalctl -u memory-agent -e"
fi
