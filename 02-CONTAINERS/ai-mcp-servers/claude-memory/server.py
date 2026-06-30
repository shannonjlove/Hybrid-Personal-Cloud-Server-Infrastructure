#!/usr/bin/env python3
"""
Claude Memory MCP Server
Implements the memory_20250818 tool protocol (view/create/str_replace/insert/delete/rename)
backed by the local filesystem. Compatible with Claude Code via MCP and the Anthropic API.
"""
import asyncio
import os
import re
import shutil
from pathlib import Path
from typing import Optional

from mcp.server.fastmcp import FastMCP

MEMORY_ROOT = Path(os.environ.get("MEMORY_ROOT", "/memories")).resolve()
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
    ALWAYS run memory(command='view', path='/memories') before starting any task.

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
