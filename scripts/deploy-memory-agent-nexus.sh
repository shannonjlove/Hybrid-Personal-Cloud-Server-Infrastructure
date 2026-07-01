#!/usr/bin/env bash
# SJL Memory Agent — deployment script (Nexus)
# Deploys a rootless-Podman Quadlet service wrapping the Anthropic Messages API
# memory tool (memory_20250818), using BetaLocalFilesystemMemoryTool for the
# client-side file handler (view/create/str_replace/insert/delete/rename),
# with spec-compliant path traversal protection built in.
#
# Run this on Nexus (100.115.66.75) as the user/role that manages your other
# system-level Quadlets. It will prompt once, interactively, for your
# Anthropic API key — the key is never written to disk in plaintext.

set -euo pipefail

APP_DIR="/opt/memory-agent"
DATA_DIR="${APP_DIR}/data"
QUADLET_DIR="/etc/containers/systemd"
TAILSCALE_IP="100.115.66.75"
BIND_PORT="8100"

echo "==> Creating directory layout at ${APP_DIR}"
mkdir -p "${APP_DIR}/app" "${DATA_DIR}"

echo "==> Writing app/requirements.txt"
cat > "${APP_DIR}/app/requirements.txt" <<'EOF'
fastapi==0.115.*
uvicorn[standard]==0.32.*
anthropic>=0.40.0
pydantic==2.*
EOF

echo "==> Writing app/main.py"
cat > "${APP_DIR}/app/main.py" <<'PYEOF'
import os
from pathlib import Path

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

import anthropic
from anthropic.tools import BetaLocalFilesystemMemoryTool

MEMORY_BASE_PATH = os.environ.get("MEMORY_BASE_PATH", "/memories")
MODEL = os.environ.get("ANTHROPIC_MODEL", "claude-sonnet-4-6")
MAX_TOKENS = int(os.environ.get("ANTHROPIC_MAX_TOKENS", "2048"))

app = FastAPI(title="SJL Memory Agent")

# anthropic.Anthropic() reads ANTHROPIC_API_KEY from the environment, which
# the Quadlet unit injects via a Podman secret (never written to disk in
# plaintext anywhere in this image or its config).
client = anthropic.Anthropic()


class ChatRequest(BaseModel):
    message: str
    session_id: str = "default"


class ChatResponse(BaseModel):
    reply: str
    session_id: str


@app.get("/healthz")
def healthz():
    return {"status": "ok"}


@app.post("/chat", response_model=ChatResponse)
def chat(req: ChatRequest):
    # One memory subdirectory per session_id so unrelated conversations
    # (e.g. different projects/agents) don't share or clobber memory files.
    if "/" in req.session_id or ".." in req.session_id:
        raise HTTPException(status_code=400, detail="Invalid session_id")

    session_path = Path(MEMORY_BASE_PATH) / req.session_id
    session_path.mkdir(parents=True, exist_ok=True)
    memory = BetaLocalFilesystemMemoryTool(base_path=str(session_path))

    try:
        runner = client.beta.messages.tool_runner(
            model=MODEL,
            max_tokens=MAX_TOKENS,
            messages=[{"role": "user", "content": req.message}],
            tools=[memory],
        )
        final_message = runner.until_done()
    except Exception as exc:  # surfaced as 502 so it's obvious this is upstream
        raise HTTPException(status_code=502, detail=str(exc)) from exc

    text_parts = [
        block.text
        for block in final_message.content
        if getattr(block, "type", None) == "text"
    ]
    return ChatResponse(reply="\n".join(text_parts), session_id=req.session_id)
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

echo "==> Building container image (localhost/memory-agent:latest)"
podman build -t localhost/memory-agent:latest "${APP_DIR}/app"

echo "==> Ensuring Podman secret 'anthropic_api_key' exists"
if podman secret exists anthropic_api_key 2>/dev/null; then
  echo "    Secret already present — leaving it as-is. Delete with"
  echo "    'podman secret rm anthropic_api_key' first if you need to rotate it."
else
  echo "    Enter your Anthropic API key (input hidden, not echoed or logged):"
  read -rs ANTHROPIC_KEY_INPUT
  echo
  printf '%s' "${ANTHROPIC_KEY_INPUT}" | podman secret create anthropic_api_key -
  unset ANTHROPIC_KEY_INPUT
fi

echo "==> Writing Quadlet unit ${QUADLET_DIR}/memory-agent.container"
mkdir -p "${QUADLET_DIR}"
cat > "${QUADLET_DIR}/memory-agent.container" <<EOF
[Unit]
Description=SJL Memory Agent (Claude memory-tool service)
After=network-online.target

[Container]
Image=localhost/memory-agent:latest
ContainerName=memory-agent
PublishPort=${TAILSCALE_IP}:${BIND_PORT}:8000
Volume=${DATA_DIR}:/memories:Z
Secret=anthropic_api_key,type=env,target=ANTHROPIC_API_KEY
Environment=ANTHROPIC_MODEL=claude-sonnet-4-6
Environment=MEMORY_BASE_PATH=/memories

[Service]
Restart=on-failure
TimeoutStartSec=60

[Install]
WantedBy=multi-user.target
EOF

echo "==> Reloading systemd and starting memory-agent.service"
systemctl daemon-reload
systemctl enable --now memory-agent.service

sleep 3
echo "==> Service status"
systemctl status memory-agent.service --no-pager || true

echo "==> Health check (Tailscale-only, ${TAILSCALE_IP}:${BIND_PORT})"
if curl -fsS "http://${TAILSCALE_IP}:${BIND_PORT}/healthz"; then
  echo
  echo "OK — memory-agent is up."
  echo "Test with:"
  echo "  curl -s http://${TAILSCALE_IP}:${BIND_PORT}/chat \\"
  echo "    -H 'Content-Type: application/json' \\"
  echo "    -d '{\"message\":\"Remember that I prefer replies under 3 sentences.\",\"session_id\":\"test\"}'"
else
  echo
  echo "Health check failed. Inspect with: journalctl -u memory-agent -e"
fi
