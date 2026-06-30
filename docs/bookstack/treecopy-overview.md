# TreeCopy — Overview & Quick Start

TreeCopy is an enhanced `tree` command implemented in Python. It displays a visual directory hierarchy, outputs structured JSON, and replicates directory structures to a target location.

It lives at `scripts/treecopy.py` and requires Python 3.7+ with no external dependencies (stdlib only).

---

## What It Does

| Capability | Description |
|------------|-------------|
| **Tree Display** | Visual directory hierarchy with `├──` / `└──` connectors |
| **ANSI Color** | Bold blue directories, green executables, cyan symlinks — auto-detected, TTY-aware |
| **Depth Limit** | `-L N` limits display to exactly N levels |
| **Hidden Files** | `-a` includes dotfiles |
| **File Sizes** | `-s` shows human-readable sizes next to each file |
| **Ignore Patterns** | `-I PATTERN` skips matching entries; sensible defaults built in |
| **JSON Output** | `--json` outputs a fully structured tree as JSON |
| **File to File** | `-o FILE` saves text or JSON output to a file |
| **Copy Structure** | `--copy-to DEST` replicates the directory tree to a new location |
| **Copy Files** | `--copy-files` also copies file contents during structure replication |
| **Dry Run** | `--dry-run` previews a copy without making changes |
| **Count Summary** | Prints `N directories, M files` at the end of every text tree |

---

## Quick Start

```bash
# Basic tree of current directory
python3 scripts/treecopy.py

# 2 levels deep, include hidden files
python3 scripts/treecopy.py /srv -L 2 -a

# Directories only, skip node_modules
python3 scripts/treecopy.py /srv -d -I node_modules

# Show file sizes
python3 scripts/treecopy.py /srv -s

# JSON output
python3 scripts/treecopy.py /srv --json

# Save tree to file
python3 scripts/treecopy.py /srv -o /tmp/tree.txt

# Replicate structure (dry-run first)
python3 scripts/treecopy.py /srv --copy-to /backup --dry-run
python3 scripts/treecopy.py /srv --copy-to /backup

# Replicate structure + all files
python3 scripts/treecopy.py /srv --copy-to /backup --copy-files
```

---

## Default Ignore List

The following are hidden by default. Use `--no-ignore-defaults` to disable.

- `.git`
- `__pycache__`
- `node_modules`
- `.DS_Store`
- `.venv` / `venv`
- `.mypy_cache`
- `.pytest_cache`
- `.ruff_cache`

---

## Example Output

```
/srv/sjl/data
├── Archives
│   └── backup.tar.gz
├── Images
│   ├── photo.jpg
│   └── screenshot.png
└── Scripts
    └── deploy.sh

3 directories, 4 files
```

---

## Color Coding

| Color | Meaning |
|-------|---------|
| Bold blue | Directory |
| Green | Executable file |
| Cyan | Symbolic link (with `→ target` shown) |
| Default | Regular file |

Color is automatically disabled when output is piped or redirected, or when the `NO_COLOR` environment variable is set.

---

*Source: `scripts/treecopy.py` | Last updated: June 2026*
