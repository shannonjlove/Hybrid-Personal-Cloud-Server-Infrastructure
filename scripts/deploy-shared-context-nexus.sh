#!/usr/bin/env bash
# SJL Shared Context — Nexus deployment
# 1. Creates /opt/shared-context (real data) bind-mounted to /mnt/shared-context
#    (so every node addresses the same absolute path)
# 2. Seeds README.md, infrastructure-rules.md, claude-memories/, memory-agent/
# 3. Exports /mnt/shared-context via NFS, restricted to the Tailscale subnet only
# 4. Installs the claude-memory stdio MCP server (no container — direct subprocess)
# 5. Repoints the existing memory-agent Quadlet's volume at the shared folder
#    and migrates any existing data into it

set -euo pipefail

REAL_DIR="/opt/shared-context"
MOUNT_DIR="/mnt/shared-context"
TAILSCALE_SUBNET="100.64.0.0/10"   # Tailscale's CGNAT allocation range
CLAUDE_MEMORY_LIB="${HOME}/.local/lib/claude-memory"
QUADLET_DIR="/etc/containers/systemd"
MEMORY_AGENT_DATA_OLD="/opt/memory-agent/data"

echo "==> Creating ${REAL_DIR} and bind-mounting to ${MOUNT_DIR}"
mkdir -p "${REAL_DIR}"/{claude-memories,memory-agent}
mkdir -p "${MOUNT_DIR}"

if ! mountpoint -q "${MOUNT_DIR}"; then
  mount --bind "${REAL_DIR}" "${MOUNT_DIR}"
  if ! grep -qF "${REAL_DIR} ${MOUNT_DIR} none bind" /etc/fstab 2>/dev/null; then
    echo "${REAL_DIR} ${MOUNT_DIR} none bind 0 0" >> /etc/fstab
  fi
fi

echo "==> Seeding README.md and infrastructure-rules.md"
cat > "${MOUNT_DIR}/README.md" <<'READMEEOF'
# Shared Context — SJL Sovereign Cloud

This folder is mounted at the **same absolute path on every node**:
`/mnt/shared-context`

- **Nexus** — the real data lives here (`/opt/shared-context`, bind-mounted to `/mnt/shared-context`), served over NFS restricted to the Tailscale interface.
- **sOs** — NFS-mounted from Nexus at `/mnt/shared-context`.
- **WebTop** (container running inside sOs) — bind-mounted from sOs's host mount, same path inside the container.

Any AI agent, on any node, working through any interface (Claude Code CLI,
the `memory-agent` HTTP API, or a tool running inside WebTop), should check
this folder before asking Shannon to repeat context.

## Layout

```
/mnt/shared-context/
  README.md                    ← this file
  infrastructure-rules.md      ← canonical, current rules (Podman Quadlets only,
                                  NPM only — no Traefik, no Docker, no Caddy)
  claude-memories/             ← Claude Code CLI memory (memory_20250818 protocol)
                                  same content visible from Nexus, sOs, WebTop
  memory-agent/                ← storage for the memory-agent HTTP service (Nexus)
                                  organized by session_id, same protocol
```

## Rule for any agent reading this

1. `view /mnt/shared-context` (or the equivalent `memory` tool `view /memories`
   call, which is rooted here) before starting work.
2. Read `infrastructure-rules.md` for current, non-negotiable infra conventions.
3. Record anything worth remembering back into this folder before your session
   ends — the next agent, on any node, picks up from here.

READMEEOF

cat > "${MOUNT_DIR}/infrastructure-rules.md" <<'RULESEOF'
# Infrastructure Rules — shannonjlove.cloud

## Container runtime
- ALWAYS use **Podman Quadlets** (systemd `.container` unit files in `/etc/containers/systemd/`)
- Docker and docker-compose are permanently retired — if you find either, convert to a Quadlet and remove the Docker artifacts

## Reverse proxy
- ALWAYS use **Nginx Proxy Manager (NPM)** for reverse proxy and SSL
- Caddy and Traefik are permanently retired — if you find `traefik.*` labels, Caddyfiles, or Traefik config anywhere, remove them; they do nothing under NPM and are leftover cruft

## Nodes
- **Nexus** (Hostinger VPS, x86_64) — `72.61.74.250` / Tailscale `100.115.66.75`. Primary host, public-facing, runs NPM, serves the shared-context NFS export.
- **sOs** (Oracle Cloud ARM64) — Tailscale `100.67.229.94`. Private compute workloads.
- **WebTop** — NOT a separate physical node. An always-on desktop-environment Podman Quadlet running *inside* sOs, for GUI-dependent deployment tasks. Shares sOs's Tailscale identity and the shared-context mount.

## Shared context
- Canonical shared folder: `/mnt/shared-context`, identical absolute path on Nexus, sOs, and inside WebTop
- Served via NFS from Nexus, restricted to the Tailscale interface only — never bind NFS to a public interface
- Purpose: every AI agent session, on any node, reads/writes here instead of the user re-explaining infrastructure context per login/session

## Memory tools
- **claude-memory**: stdio MCP server (`server.py`), launched directly by Claude Code — no container, no daemon. `MEMORY_ROOT=/mnt/shared-context/claude-memories`
- **memory-agent**: HTTP API service (Podman Quadlet, Nexus, Tailscale-only, port 8100) wrapping the Anthropic Messages API `memory_20250818` tool. Storage under `/mnt/shared-context/memory-agent/`
- No third-party/unverified memory binaries — if something like `ai-memory` (alphaonedev) shows up again, treat it as out of scope unless explicitly re-approved; it was never verified and pulled via `curl | sh` from an unestablished source

## Security
- No secrets, tokens, or credentials committed to any repo — `.env` gitignored, `env.template` committed with placeholders only
- Public HTTPS exposure decisions (e.g. `npm.shannonjlove.cloud`, `memory.shannonjlove.cloud`) are the user's explicit call — do not re-litigate once made

RULESEOF

echo "==> Installing NFS server"
if ! command -v exportfs &>/dev/null; then
  apt-get update -qq && apt-get install -y -qq nfs-kernel-server
fi

echo "==> Configuring /etc/exports (Tailscale subnet only, never public)"
EXPORT_LINE="${MOUNT_DIR} ${TAILSCALE_SUBNET}(rw,sync,no_subtree_check,no_root_squash)"
if ! grep -qF "${MOUNT_DIR}" /etc/exports 2>/dev/null; then
  echo "${EXPORT_LINE}" >> /etc/exports
fi
exportfs -ra
systemctl enable --now nfs-kernel-server

echo "==> Installing claude-memory stdio MCP server"
mkdir -p "${CLAUDE_MEMORY_LIB}"
cat > "${CLAUDE_MEMORY_LIB}/server.py" <<'PYEOF'
#!/usr/bin/env python3
"""
Claude Memory MCP Server — stdio
Implements the memory_20250818 tool protocol (view/create/str_replace/insert/
delete/rename) backed by the local filesystem. Launched directly by Claude
Code as a subprocess — no container, no systemd unit, no daemon needed.

MEMORY_ROOT should point at the shared-context mount so every node's Claude
Code sessions read/write the same canonical files:
  MEMORY_ROOT=/mnt/shared-context/claude-memories
"""
import os
import re
import shutil
from pathlib import Path
from typing import Optional

from mcp.server.fastmcp import FastMCP

MEMORY_ROOT = Path(os.environ.get("MEMORY_ROOT", "/mnt/shared-context/claude-memories")).resolve()
MEMORY_ROOT.mkdir(parents=True, exist_ok=True)

mcp = FastMCP("claude-memory")


def _resolve(path: str) -> Path:
    if re.search(r"\.\.[/\\]|%2e%2e", path, re.IGNORECASE):
        raise ValueError(f"Path traversal rejected: {path}")
    stripped = path.removeprefix("/memories").lstrip("/")
    target = (MEMORY_ROOT / stripped).resolve() if stripped else MEMORY_ROOT
    if not str(target).startswith(str(MEMORY_ROOT)):
        raise ValueError(f"Path escapes memory root: {path}")
    return target


def _human_size(n: int) -> str:
    for unit in ("B", "K", "M", "G"):
        if n < 1024:
            return f"{n:.1f}{unit}"
        n /= 1024
    return f"{n:.1f}T"


def _list_dir(target: Path, display_path: str) -> str:
    lines = [
        f"Here're the files and directories up to 2 levels deep in {display_path},"
        " excluding hidden items and node_modules:"
    ]
    lines.append(f"{'0B':>5}\t{display_path}")
    for item in sorted(target.rglob("*")):
        if any(p.startswith(".") or p == "node_modules" for p in item.parts[len(target.parts):]):
            continue
        depth = len(item.relative_to(target).parts)
        if depth > 2:
            continue
        sz = _human_size(item.stat().st_size) if item.is_file() else "0B"
        rel = "/memories/" + str(item.relative_to(MEMORY_ROOT))
        lines.append(f"{sz:>5}\t{rel}")
    return "\n".join(lines)


@mcp.tool()
def memory(
    command: str,
    path: str = "/memories",
    file_text: str = "",
    old_str: str = "",
    new_str: str = "",
    view_range: Optional[list] = None,
    insert_line: int = 0,
    insert_text: str = "",
    old_path: str = "",
    new_path: str = "",
) -> str:
    """
    Store and retrieve information across conversations using file operations.
    ALWAYS run memory(command='view', path='/memories') before starting any task —
    this is a SHARED store visible from every node (Nexus, sOs, WebTop). Check it
    first so you don't ask the user to repeat context they've already given
    another session.

    Commands: view, create, str_replace, insert, delete, rename
    All paths must start with /memories.
    """
    try:
        if command == "view":
            return _cmd_view(path, view_range)
        if command == "create":
            return _cmd_create(path, file_text)
        if command == "str_replace":
            return _cmd_str_replace(path, old_str, new_str)
        if command == "insert":
            return _cmd_insert(path, insert_line, insert_text)
        if command == "delete":
            return _cmd_delete(path)
        if command == "rename":
            return _cmd_rename(old_path, new_path)
        return f"Error: unknown command '{command}'"
    except ValueError as exc:
        return f"Error: {exc}"


def _cmd_view(path: str, view_range: Optional[list]) -> str:
    target = _resolve(path)

    if not target.exists():
        if target == MEMORY_ROOT:
            return _list_dir(target, path)
        return f"The path {path} does not exist. Please provide a valid path."

    if target.is_dir():
        return _list_dir(target, path)

    content = target.read_text(errors="replace")
    file_lines = content.splitlines()
    if len(file_lines) > 999_999:
        return f"File {path} exceeds maximum line limit of 999,999 lines."

    start, end = 1, len(file_lines)
    if view_range and len(view_range) == 2:
        start = max(1, view_range[0])
        end = len(file_lines) if view_range[1] == -1 else min(len(file_lines), view_range[1])

    numbered = [
        f"{i:6d}\t{line}"
        for i, line in enumerate(file_lines[start - 1 : end], start=start)
    ]
    return f"Here's the content of {path} with line numbers:\n" + "\n".join(numbered)


def _cmd_create(path: str, file_text: str) -> str:
    target = _resolve(path)
    if target.exists():
        return f"Error: File {path} already exists"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(file_text)
    return f"File created successfully at: {path}"


def _cmd_str_replace(path: str, old_str: str, new_str: str) -> str:
    target = _resolve(path)
    if target.is_dir() or not target.exists():
        return f"Error: The path {path} does not exist. Please provide a valid path."

    content = target.read_text(errors="replace")
    count = content.count(old_str)

    if count == 0:
        return f"No replacement was performed, old_str `{old_str}` did not appear verbatim in {path}."
    if count > 1:
        hits = [str(i + 1) for i, l in enumerate(content.splitlines()) if old_str in l]
        return (
            f"No replacement was performed. Multiple occurrences of old_str `{old_str}`"
            f" in lines: {', '.join(hits)}. Please ensure it is unique"
        )

    updated = content.replace(old_str, new_str, 1)
    target.write_text(updated)
    snippet = "\n".join(
        f"{i+1:6d}\t{l}" for i, l in enumerate(updated.splitlines()[:10])
    )
    return f"The memory file has been edited.\n{snippet}"


def _cmd_insert(path: str, insert_line: int, insert_text: str) -> str:
    target = _resolve(path)
    if target.is_dir() or not target.exists():
        return f"Error: The path {path} does not exist"

    lines = target.read_text(errors="replace").splitlines()
    if insert_line < 0 or insert_line > len(lines):
        return (
            f"Error: Invalid `insert_line` parameter: {insert_line}."
            f" It should be within the range of lines of the file: [0, {len(lines)}]"
        )

    lines.insert(insert_line, insert_text.rstrip("\n"))
    target.write_text("\n".join(lines))
    return f"The file {path} has been edited."


def _cmd_delete(path: str) -> str:
    if path.rstrip("/") in ("/memories", ""):
        return "Error: Cannot delete the /memories root directory"
    target = _resolve(path)
    if not target.exists():
        return f"Error: The path {path} does not exist"
    shutil.rmtree(target) if target.is_dir() else target.unlink()
    return f"Successfully deleted {path}"


def _cmd_rename(old_path: str, new_path: str) -> str:
    if old_path.rstrip("/") in ("/memories", ""):
        return "Error: Cannot rename the /memories root directory"
    src = _resolve(old_path)
    dst = _resolve(new_path)
    if not src.exists():
        return f"Error: The path {old_path} does not exist"
    if dst.exists():
        return f"Error: The destination {new_path} already exists"
    dst.parent.mkdir(parents=True, exist_ok=True)
    src.rename(dst)
    return f"Successfully renamed {old_path} to {new_path}"


if __name__ == "__main__":
    mcp.run()

PYEOF

echo "==> Creating Python venv for claude-memory and installing mcp"
python3 -m venv "${CLAUDE_MEMORY_LIB}/venv"
"${CLAUDE_MEMORY_LIB}/venv/bin/pip" install --quiet "mcp[cli]>=1.0.0"

echo "==> Writing/merging .claude/settings.json (project-local, adjust path if needed)"
CLAUDE_SETTINGS_DIR="${HOME}/.claude"
mkdir -p "${CLAUDE_SETTINGS_DIR}"
cat > "${CLAUDE_SETTINGS_DIR}/settings.json" <<EOF
{
  "mcpServers": {
    "claude-memory": {
      "command": "${CLAUDE_MEMORY_LIB}/venv/bin/python3",
      "args": ["${CLAUDE_MEMORY_LIB}/server.py"],
      "env": {
        "MEMORY_ROOT": "${MOUNT_DIR}/claude-memories"
      }
    }
  }
}
EOF

echo "==> Migrating existing memory-agent data into shared-context (if present)"
if [[ -d "${MEMORY_AGENT_DATA_OLD}" ]] && [[ -n "$(ls -A "${MEMORY_AGENT_DATA_OLD}" 2>/dev/null)" ]]; then
  rsync -a "${MEMORY_AGENT_DATA_OLD}/" "${MOUNT_DIR}/memory-agent/"
  echo "    Migrated $(du -sh "${MEMORY_AGENT_DATA_OLD}" | cut -f1) of existing memory-agent data."
fi

echo "==> Repointing memory-agent Quadlet volume at shared-context"
QUADLET_FILE="${QUADLET_DIR}/memory-agent.container"
if [[ -f "${QUADLET_FILE}" ]]; then
  sed -i "s#Volume=.*:/memories:Z#Volume=${MOUNT_DIR}/memory-agent:/memories:Z#" "${QUADLET_FILE}"
  systemctl daemon-reload
  systemctl restart memory-agent.service || echo "    WARNING: memory-agent.service restart failed — check journalctl -u memory-agent"
  echo "    memory-agent Quadlet updated and restarted."
else
  echo "    NOTE: ${QUADLET_FILE} not found — skipping (deploy memory-agent first if you haven't)."
fi

echo ""
echo "==> Done. Shared context is live at ${MOUNT_DIR} (real data: ${REAL_DIR})"
echo "    NFS export restricted to ${TAILSCALE_SUBNET} (Tailscale only)"
echo "    Next: run the sOs/WebTop script on sOs to mount this and deploy WebTop."
