#!/usr/bin/env bash
# deploy-local-agent.sh
# Deploys local-agent: recovers the natural-language /chat capability lost
# when memory-agent dropped the Anthropic API, using a local Ollama model
# instead. Zero external API, zero cost, zero vendor lock-in.
#
# PREREQUISITE: Ollama must already be running and reachable. Per existing
# infra (PaperParrot stack), Ollama is expected at port 11434 — confirm with:
#   curl -s http://localhost:11434/api/tags
# and pull a tool-calling-capable model before running this, e.g.:
#   ollama pull neural-chat:7b

set -euo pipefail

APP_DIR="/opt/local-agent"
QUADLET_DIR="/etc/containers/systemd"
TAILSCALE_IP="${TAILSCALE_IP:-100.115.66.75}"
BIND_PORT="${BIND_PORT:-8101}"
OLLAMA_URL="${OLLAMA_URL:-http://host.containers.internal:11434}"
OLLAMA_MODEL="${OLLAMA_MODEL:-neural-chat:7b}"
MEMORY_AGENT_URL="${MEMORY_AGENT_URL:-http://${TAILSCALE_IP}:8100}"

echo "==> Checking Ollama is reachable before deploying..."
if ! curl -fsS "http://localhost:11434/api/tags" >/dev/null 2>&1; then
  echo "WARNING: Ollama not responding at http://localhost:11434 on this host."
  echo "         local-agent will deploy but /chat will fail until Ollama is up."
  echo "         Check: systemctl status ollama  (or wherever it's running)"
fi

mkdir -p "${APP_DIR}/app"

echo "==> Writing app/requirements.txt"
cat > "${APP_DIR}/app/requirements.txt" <<'EOF'
fastapi==0.115.*
uvicorn[standard]==0.32.*
pydantic==2.*
requests==2.32.*
EOF

echo "==> Writing app/main.py"
cat > "${APP_DIR}/app/main.py" <<'PYEOF'
"""
local-agent
Recovers the "autonomous reasoning over memory" capability that v1's
Anthropic-API-backed /chat endpoint provided — using a locally-hosted Ollama
model instead. Zero external API, zero per-request cost, zero vendor
lock-in: swap OLLAMA_MODEL to any tool-calling-capable model Ollama
supports (Llama, Qwen, Mistral, DeepSeek's own open-weight releases, etc.)
with no code changes.

Honesty check, not marketing: a local 7-8B class model will not reason as
well as Claude did at deciding what to read/write and when. This recovers
the shape of the functionality — natural-language-driven memory management
— not its full quality. If reasoning quality on complex multi-step tasks
matters more than cost/lock-in for a given use case, that's a real tradeoff,
not one this script can eliminate.

Talks to memory-agent's REST API (the dumb, safe CRUD layer) as its tools —
this service adds reasoning on top, it doesn't duplicate the file-safety
logic memory-agent already has.
"""
import json
import os

import requests
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

OLLAMA_URL = os.environ.get("OLLAMA_URL", "http://localhost:11434")
OLLAMA_MODEL = os.environ.get("OLLAMA_MODEL", "qwen2.5:7b")
MEMORY_AGENT_URL = os.environ.get("MEMORY_AGENT_URL", "http://100.115.66.75:8100")
MAX_TOOL_ROUNDS = int(os.environ.get("MAX_TOOL_ROUNDS", "6"))

app = FastAPI(title="local-agent — free, local, no vendor lock-in")

TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "view",
            "description": "View a memory file's contents, or list a directory, under /memories",
            "parameters": {
                "type": "object",
                "properties": {"path": {"type": "string", "description": "Path under /memories, e.g. /notes.md or / for root"}},
                "required": ["path"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "create",
            "description": "Create a new memory file",
            "parameters": {
                "type": "object",
                "properties": {"path": {"type": "string"}, "file_text": {"type": "string"}},
                "required": ["path", "file_text"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "str_replace",
            "description": "Replace an exact, unique block of text in a memory file",
            "parameters": {
                "type": "object",
                "properties": {
                    "path": {"type": "string"},
                    "old_str": {"type": "string"},
                    "new_str": {"type": "string"},
                },
                "required": ["path", "old_str", "new_str"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "insert",
            "description": "Insert a line into a memory file at a given (0-indexed) line number",
            "parameters": {
                "type": "object",
                "properties": {
                    "path": {"type": "string"},
                    "insert_line": {"type": "integer"},
                    "insert_text": {"type": "string"},
                },
                "required": ["path", "insert_line", "insert_text"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "delete",
            "description": "Delete a memory file or directory",
            "parameters": {"type": "object", "properties": {"path": {"type": "string"}}, "required": ["path"]},
        },
    },
]


def _call_memory_agent(tool_name: str, args: dict) -> dict:
    path = str(args.get("path", "")).lstrip("/")
    try:
        if tool_name == "view":
            r = requests.get(f"{MEMORY_AGENT_URL}/memories/{path}", timeout=15)
        elif tool_name == "create":
            r = requests.post(
                f"{MEMORY_AGENT_URL}/memories/{path}", json={"file_text": args.get("file_text", "")}, timeout=15
            )
        elif tool_name == "str_replace":
            r = requests.patch(
                f"{MEMORY_AGENT_URL}/memories/{path}",
                json={"old_str": args.get("old_str", ""), "new_str": args.get("new_str", "")},
                timeout=15,
            )
        elif tool_name == "insert":
            r = requests.patch(
                f"{MEMORY_AGENT_URL}/memories/{path}",
                json={"insert_line": args.get("insert_line", 0), "insert_text": args.get("insert_text", "")},
                timeout=15,
            )
        elif tool_name == "delete":
            r = requests.delete(f"{MEMORY_AGENT_URL}/memories/{path}", timeout=15)
        else:
            return {"error": f"unknown tool {tool_name}"}
        try:
            return r.json()
        except ValueError:
            return {"status_code": r.status_code, "text": r.text}
    except Exception as exc:
        return {"error": str(exc)}


class ChatRequest(BaseModel):
    message: str


class ChatResponse(BaseModel):
    reply: str
    model: str
    tool_calls_made: int


@app.get("/healthz")
def healthz():
    return {"status": "ok", "model": OLLAMA_MODEL, "uses_external_api": False, "cost_per_request": 0}


@app.post("/chat", response_model=ChatResponse)
def chat(req: ChatRequest):
    messages = [
        {
            "role": "system",
            "content": (
                "You have tools to read and write persistent memory files under /memories. "
                "Use them when relevant to the user's request."
            ),
        },
        {"role": "user", "content": req.message},
    ]
    tool_calls_made = 0

    for _ in range(MAX_TOOL_ROUNDS):
        try:
            resp = requests.post(
                f"{OLLAMA_URL}/api/chat",
                json={"model": OLLAMA_MODEL, "messages": messages, "tools": TOOLS, "stream": False},
                timeout=120,
            )
            resp.raise_for_status()
            data = resp.json()
        except Exception as exc:
            raise HTTPException(status_code=502, detail=f"Ollama unreachable at {OLLAMA_URL}: {exc}")

        msg = data.get("message", {})
        tool_calls = msg.get("tool_calls") or []

        if not tool_calls:
            return ChatResponse(reply=msg.get("content", ""), model=OLLAMA_MODEL, tool_calls_made=tool_calls_made)

        messages.append(msg)
        for call in tool_calls:
            fn = call.get("function", {})
            name = fn.get("name")
            args = fn.get("arguments") or {}
            result = _call_memory_agent(name, args)
            tool_calls_made += 1
            messages.append({"role": "tool", "content": json.dumps(result)})

    return ChatResponse(
        reply="(stopped after max tool-call rounds without a final answer)",
        model=OLLAMA_MODEL,
        tool_calls_made=tool_calls_made,
    )

PYEOF

echo "==> Writing app/Containerfile"
cat > "${APP_DIR}/app/Containerfile" <<'EOF'
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY main.py .
EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
EOF

echo "==> Building image"
podman build -t localhost/local-agent:latest "${APP_DIR}/app"

echo "==> Writing Quadlet (Tailscale-only, no secrets — nothing sensitive here)"
mkdir -p "${QUADLET_DIR}"
cat > "${QUADLET_DIR}/local-agent.container" <<EOF
[Unit]
Description=local-agent — free, local Ollama-backed memory reasoning
After=network-online.target

[Container]
Image=localhost/local-agent:latest
ContainerName=local-agent
PublishPort=${TAILSCALE_IP}:${BIND_PORT}:8000
AddHost=host.containers.internal:host-gateway
Environment=OLLAMA_URL=${OLLAMA_URL}
Environment=OLLAMA_MODEL=${OLLAMA_MODEL}
Environment=MEMORY_AGENT_URL=${MEMORY_AGENT_URL}

[Service]
Restart=on-failure
TimeoutStartSec=60

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl start local-agent.service

sleep 3
echo "==> Service status"
systemctl status local-agent.service --no-pager || true

echo "==> Health check"
curl -fsS "http://${TAILSCALE_IP}:${BIND_PORT}/healthz" && echo || echo "Health check failed — check: journalctl -u local-agent -e"

echo ""
echo "==> Done. NOT exposed via NPM/public domain — Tailscale-only by default."
echo "    Test (from a Tailscale-connected client):"
echo "    curl -s http://${TAILSCALE_IP}:${BIND_PORT}/chat -H 'Content-Type: application/json' \\"
echo "      -d '{\"message\":\"remember that I prefer replies under 3 sentences\"}'"
