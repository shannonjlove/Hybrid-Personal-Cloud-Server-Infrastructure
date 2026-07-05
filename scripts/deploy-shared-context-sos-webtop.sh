#!/usr/bin/env bash
# SJL Shared Context + WebTop — sOs (Oracle ARM64) deployment
# 1. Mounts Nexus's shared-context NFS export at /mnt/shared-context (same
#    absolute path as Nexus)
# 2. Installs the claude-memory stdio MCP server, pointed at the shared mount
# 3. Deploys WebTop as an always-on Podman Quadlet, bind-mounting the shared
#    folder in at the same path inside the container too

set -euo pipefail

NEXUS_TAILSCALE_IP="100.115.66.75"
MOUNT_DIR="/mnt/shared-context"
CLAUDE_MEMORY_LIB="${HOME}/.local/lib/claude-memory"
QUADLET_DIR="/etc/containers/systemd"

WEBTOP_CONFIG_DIR="/opt/webtop/config"
WEBTOP_IMAGE="lscr.io/linuxserver/webtop:ubuntu-xfce"
WEBTOP_PUID="${WEBTOP_PUID:-1000}"
WEBTOP_PGID="${WEBTOP_PGID:-1000}"
WEBTOP_TZ="${WEBTOP_TZ:-America/New_York}"

echo "==> Installing NFS client"
if ! command -v mount.nfs4 &>/dev/null && ! command -v mount.nfs &>/dev/null; then
  apt-get update -qq && apt-get install -y -qq nfs-common
fi

echo "==> Mounting shared-context from Nexus (${NEXUS_TAILSCALE_IP}) at ${MOUNT_DIR}"
mkdir -p "${MOUNT_DIR}"
FSTAB_LINE="${NEXUS_TAILSCALE_IP}:${MOUNT_DIR} ${MOUNT_DIR} nfs4 _netdev,x-systemd.automount,x-systemd.after=tailscaled.service 0 0"
if ! grep -qF "${MOUNT_DIR}" /etc/fstab 2>/dev/null; then
  echo "${FSTAB_LINE}" >> /etc/fstab
fi
systemctl daemon-reload
mount "${MOUNT_DIR}" 2>/dev/null || mount -t nfs4 "${NEXUS_TAILSCALE_IP}:${MOUNT_DIR}" "${MOUNT_DIR}"

if mountpoint -q "${MOUNT_DIR}"; then
  echo "    Mounted OK: $(df -h "${MOUNT_DIR}" | tail -1)"
else
  echo "    WARNING: mount did not confirm — check 'mount ${MOUNT_DIR}' manually and Tailscale connectivity to ${NEXUS_TAILSCALE_IP}."
fi

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

echo "==> Writing .claude/settings.json"
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

echo "==> Deploying WebTop (always-on desktop environment, bind-mounts shared-context)"
mkdir -p "${WEBTOP_CONFIG_DIR}"
mkdir -p "${QUADLET_DIR}"

SOS_TAILSCALE_IP="$(tailscale ip -4 2>/dev/null | head -1 || true)"
if [[ -z "${SOS_TAILSCALE_IP}" ]]; then
  echo "    WARNING: could not auto-detect Tailscale IP via 'tailscale ip -4'."
  echo "    Set SOS_TAILSCALE_IP manually and re-run, or edit the Quadlet after this completes."
  SOS_TAILSCALE_IP="0.0.0.0"
fi

cat > "${QUADLET_DIR}/webtop.container" <<EOF
[Unit]
Description=WebTop — always-on desktop environment (sOs)
After=network-online.target

[Container]
Image=${WEBTOP_IMAGE}
ContainerName=webtop
PublishPort=${SOS_TAILSCALE_IP}:3000:3000
PublishPort=${SOS_TAILSCALE_IP}:3001:3001
Volume=${WEBTOP_CONFIG_DIR}:/config:Z
Volume=${MOUNT_DIR}:${MOUNT_DIR}:Z
Environment=PUID=${WEBTOP_PUID}
Environment=PGID=${WEBTOP_PGID}
Environment=TZ=${WEBTOP_TZ}

[Service]
Restart=always
TimeoutStartSec=120

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl start webtop.service

sleep 3
echo "==> WebTop service status"
systemctl status webtop.service --no-pager || true

echo ""
echo "==> Done."
echo "    Shared context mounted at: ${MOUNT_DIR}"
echo "    WebTop reachable at: https://${SOS_TAILSCALE_IP}:3001 (or http on :3000)"
echo "    Inside WebTop, the same shared folder is at: ${MOUNT_DIR}"
echo "    (If ${SOS_TAILSCALE_IP} shows as 0.0.0.0 above, edit"
echo "     ${QUADLET_DIR}/webtop.container's PublishPort lines with the correct sOs Tailscale IP"
echo "     and run: systemctl daemon-reload && systemctl restart webtop)"
