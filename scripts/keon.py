#!/usr/bin/env python3
"""
Keon — Enhanced directory tree command.

Provides tree display, JSON output, and directory structure replication.
Python 3.7+ | stdlib only.

Usage:
  keon.py [directory] [options]

Examples:
  keon.py                              # tree of current directory
  keon.py /srv -L 2 -a                 # 2 levels deep, include hidden files
  keon.py /srv -d -I node_modules      # directories only, ignore pattern
  keon.py /srv -s                      # show file sizes
  keon.py /srv --json                  # JSON tree output
  keon.py /srv -o tree.txt             # save to file
  keon.py /srv --copy-to /backup       # replicate directory structure
  keon.py /srv --copy-to /backup --copy-files --dry-run
"""

import argparse
import fnmatch
import json
import os
import shutil
import sys
from pathlib import Path
from typing import Dict, Iterator, List, Optional, Set, Tuple

# ── ANSI Color ────────────────────────────────────────────────────────────────
_C = {
    'dir':   '\033[34;1m',   # bold blue
    'exe':   '\033[32m',     # green
    'link':  '\033[36m',     # cyan
    'rst':   '\033[0m',
}

# Default directories/files to omit (suppressible with --no-ignore-defaults)
DEFAULT_IGNORE: Set[str] = {
    '.git', '__pycache__', 'node_modules', '.DS_Store',
    '.mypy_cache', '.pytest_cache', '.ruff_cache', '.venv', 'venv',
}


def _use_color(force: Optional[bool] = None) -> bool:
    if force is not None:
        return force
    return sys.stdout.isatty() and os.environ.get('NO_COLOR') is None


def _colorize(name: str, path: str, color: bool) -> str:
    if not color:
        return name
    if os.path.islink(path):
        return f"{_C['link']}{name}{_C['rst']}"
    if os.path.isdir(path):
        return f"{_C['dir']}{name}{_C['rst']}"
    if os.access(path, os.X_OK):
        return f"{_C['exe']}{name}{_C['rst']}"
    return name


def _human_size(path: str) -> str:
    """Return human-readable file size (e.g. '12.3K')."""
    try:
        n = os.path.getsize(path)
    except OSError:
        return '?'
    for unit in ('B', 'K', 'M', 'G', 'T'):
        if n < 1024:
            return f"{n}{unit}" if unit == 'B' else f"{n:.1f}{unit}"
        n //= 1024  # type: ignore[assignment]
    return f"{n}P"


def _ignored(name: str, patterns: Set[str]) -> bool:
    if name in patterns:
        return True
    return any(fnmatch.fnmatch(name, p) for p in patterns if '*' in p or '?' in p or '[' in p)


# ── Text tree ─────────────────────────────────────────────────────────────────
def _tree_lines(
    path: str,
    prefix: str,
    depth: int,
    max_depth: Optional[int],
    dirs_only: bool,
    all_files: bool,
    ignore: Set[str],
    show_size: bool,
    color: bool,
    counters: Dict[str, int],
) -> Iterator[str]:
    """Yield display lines for *path*'s contents (recursive).

    Bug fixes vs. original:
      - depth >= max_depth (was >) fixes off-by-one: -L 1 now means exactly 1 level
      - symlinks to directories are NOT recursed (prevents cycles and misleading display)
      - counters dict passed by reference so summary is accumulated across recursion
    """
    # Off-by-one fix: use >= so -L N shows exactly N levels of children
    if max_depth is not None and depth >= max_depth:
        return

    try:
        raw = sorted(os.listdir(path))
    except PermissionError:
        yield prefix + '[Permission denied]'
        return

    # Apply filters
    entries: List[str] = []
    for e in raw:
        if not all_files and e.startswith('.'):
            continue
        if _ignored(e, ignore):
            continue
        full = os.path.join(path, e)
        if dirs_only and not os.path.isdir(full):
            continue
        entries.append(e)

    for i, entry in enumerate(entries):
        is_last = i == len(entries) - 1
        connector = '└── ' if is_last else '├── '
        full = os.path.join(path, entry)
        is_dir = os.path.isdir(full)
        is_link = os.path.islink(full)

        label = _colorize(entry, full, color)

        # Annotate symlinks with their target
        if is_link:
            try:
                label += f' -> {os.readlink(full)}'
            except OSError:
                pass

        # Append file size
        if show_size and not is_dir:
            label += f' [{_human_size(full)}]'

        yield prefix + connector + label

        # Only recurse into real directories (not symlinks to dirs — avoids cycles)
        if is_dir and not is_link:
            counters['dirs'] += 1
            child_prefix = prefix + ('    ' if is_last else '│   ')
            yield from _tree_lines(
                full, child_prefix, depth + 1, max_depth,
                dirs_only, all_files, ignore, show_size, color, counters,
            )
        elif not is_dir:
            counters['files'] += 1


# ── JSON tree ─────────────────────────────────────────────────────────────────
def _build_dict(
    path: str,
    depth: int,
    max_depth: Optional[int],
    dirs_only: bool,
    all_files: bool,
    ignore: Set[str],
) -> dict:
    """Recursively build a JSON-serialisable tree dict."""
    is_link = os.path.islink(path)
    is_dir = os.path.isdir(path)
    node: dict = {
        'name': os.path.basename(path) or path,
        'path': str(Path(path).resolve()),
        'type': 'symlink' if is_link else ('directory' if is_dir else 'file'),
    }
    if is_link:
        try:
            node['target'] = os.readlink(path)
        except OSError:
            pass
    if not is_dir or is_link:
        try:
            node['size'] = os.path.getsize(path)
        except OSError:
            node['size'] = None
        return node

    if max_depth is not None and depth >= max_depth:
        return node

    try:
        raw = sorted(os.listdir(path))
    except PermissionError:
        node['error'] = 'permission denied'
        return node

    children = []
    for e in raw:
        if not all_files and e.startswith('.'):
            continue
        if _ignored(e, ignore):
            continue
        full = os.path.join(path, e)
        if dirs_only and not os.path.isdir(full):
            continue
        children.append(_build_dict(full, depth + 1, max_depth, dirs_only, all_files, ignore))
    node['children'] = children
    return node


# ── Copy structure ─────────────────────────────────────────────────────────────
def copy_structure(
    src: str,
    dst: str,
    copy_files: bool = False,
    dry_run: bool = False,
    ignore: Set[str] = frozenset(),  # type: ignore[assignment]
    all_files: bool = False,
) -> Tuple[int, int]:
    """Replicate directory structure (and optionally files) from *src* to *dst*.

    Returns (dirs_created, files_copied).
    """
    src = os.path.abspath(src)
    dst = os.path.abspath(dst)

    # Guard: don't copy a directory into itself
    if dst == src or dst.startswith(src + os.sep):
        print(f"Error: destination '{dst}' is inside source '{src}'.", file=sys.stderr)
        sys.exit(1)

    dirs_created = files_copied = 0

    for root, dirs, files in os.walk(src):
        # Prune in-place so os.walk skips excluded subtrees
        dirs[:] = sorted(
            d for d in dirs
            if (all_files or not d.startswith('.')) and not _ignored(d, ignore)
        )

        rel = os.path.relpath(root, src)
        target_dir = dst if rel == '.' else os.path.join(dst, rel)

        if not os.path.exists(target_dir):
            if not dry_run:
                os.makedirs(target_dir, exist_ok=True)
            print(f"  mkdir  {target_dir}")
            dirs_created += 1

        if copy_files:
            for f in sorted(files):
                if not all_files and f.startswith('.'):
                    continue
                if _ignored(f, ignore):
                    continue
                src_f = os.path.join(root, f)
                dst_f = os.path.join(target_dir, f)
                if not dry_run:
                    shutil.copy2(src_f, dst_f)
                print(f"  copy   {os.path.relpath(src_f, src)}  →  {dst_f}")
                files_copied += 1

    return dirs_created, files_copied


# ── CLI ────────────────────────────────────────────────────────────────────────
def main() -> None:
    p = argparse.ArgumentParser(
        prog='keon',
        description='Keon — Enhanced directory tree command',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    p.add_argument('directory', nargs='?', default='.',
                   help='Root directory (default: current)')
    p.add_argument('-L', '--max-depth', type=int, metavar='N',
                   help='Limit display depth to N levels')
    p.add_argument('-d', '--dirs-only', action='store_true',
                   help='Show directories only')
    p.add_argument('-a', '--all', action='store_true', dest='all_files',
                   help='Include hidden files/dirs (dotfiles)')
    p.add_argument('-s', '--size', action='store_true',
                   help='Show file sizes')
    p.add_argument('-I', '--ignore', action='append', metavar='PATTERN', default=[],
                   help='Ignore entries matching PATTERN (repeatable, fnmatch-style). '
                        f'Default ignores: {", ".join(sorted(DEFAULT_IGNORE))}')
    p.add_argument('--no-ignore-defaults', action='store_true',
                   help='Disable built-in ignore list')
    p.add_argument('--json', action='store_true',
                   help='Output tree as JSON instead of text')
    p.add_argument('--no-color', action='store_true',
                   help='Disable ANSI colour output')
    p.add_argument('-o', '--output', metavar='FILE',
                   help='Write output to FILE (text or JSON)')
    p.add_argument('--copy-to', metavar='DEST',
                   help='Replicate directory structure to DEST (dirs only unless --copy-files)')
    p.add_argument('--copy-files', action='store_true',
                   help='With --copy-to: also copy files (shutil.copy2)')
    p.add_argument('--dry-run', action='store_true',
                   help='With --copy-to: preview without making changes')
    p.add_argument('--version', action='version', version='keon 2.0.0')

    args = p.parse_args()

    start = os.path.abspath(args.directory)
    if not os.path.isdir(start):
        p.error(f"'{args.directory}' is not a directory")

    ignore: Set[str] = set() if args.no_ignore_defaults else set(DEFAULT_IGNORE)
    ignore.update(args.ignore)

    color = _use_color(force=False if args.no_color else None)

    # ── JSON output ────────────────────────────────────────────────────────────
    if args.json:
        tree = _build_dict(start, 0, args.max_depth, args.dirs_only, args.all_files, ignore)
        text = json.dumps(tree, indent=2)
        if args.output:
            Path(args.output).write_text(text, encoding='utf-8')
            print(f"JSON tree written to {args.output}")
        else:
            print(text)
        return

    # ── Text tree output ───────────────────────────────────────────────────────
    counters: Dict[str, int] = {'dirs': 0, 'files': 0}
    root_label = _colorize(start, start, color)
    lines = [root_label, *_tree_lines(
        start, '', 0, args.max_depth,
        args.dirs_only, args.all_files, ignore,
        args.size, color, counters,
    )]

    d, f = counters['dirs'], counters['files']
    summary = f"{d} director{'y' if d == 1 else 'ies'}"
    if not args.dirs_only:
        summary += f", {f} file{'s' if f != 1 else ''}"
    lines += ['', summary]

    output_text = '\n'.join(lines)

    if args.output:
        try:
            Path(args.output).write_text(output_text, encoding='utf-8')
            print(f"Tree written to {args.output}")
        except OSError as e:
            print(f"Error writing '{args.output}': {e}", file=sys.stderr)
            sys.exit(1)
    else:
        print(output_text)

    # ── Copy mode ──────────────────────────────────────────────────────────────
    if args.copy_to:
        action = 'Would replicate' if args.dry_run else 'Replicating'
        print(f"\n{action} '{start}' → '{args.copy_to}' ...")
        nd, nf = copy_structure(
            start, args.copy_to,
            copy_files=args.copy_files,
            dry_run=args.dry_run,
            ignore=ignore,
            all_files=args.all_files,
        )
        if args.dry_run:
            print(f"Dry run complete: {nd} dirs, {nf} files (no changes made).")
        else:
            print(f"Done: {nd} dir{'s' if nd != 1 else ''} created, {nf} file{'s' if nf != 1 else ''} copied.")


if __name__ == '__main__':
    main()
