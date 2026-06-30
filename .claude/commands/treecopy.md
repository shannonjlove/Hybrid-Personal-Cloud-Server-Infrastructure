---
description: Run TreeCopy — enhanced directory tree display, JSON output, and structure copy
argument-hint: [directory] [-L N] [-d] [-a] [-s] [--json] [--copy-to DEST] [--dry-run]
---

You are invoking the TreeCopy directory tree tool at `scripts/treecopy.py`.

## Common usage patterns

### Display tree
```bash
python3 scripts/treecopy.py [directory] [options]
```

### Key flags
| Flag | Meaning |
|------|---------|
| `-L N` | Limit depth to N levels |
| `-d` | Directories only |
| `-a` | Include hidden files/dotfiles |
| `-s` | Show file sizes |
| `-I PATTERN` | Ignore pattern (repeatable, fnmatch) |
| `--no-ignore-defaults` | Disable built-in ignores (.git, node_modules, etc.) |
| `--json` | JSON tree output |
| `-o FILE` | Write output to file |
| `--no-color` | Disable ANSI color |

### Replicate structure
```bash
# Preview
python3 scripts/treecopy.py <src> --copy-to <dest> --dry-run

# Structure only
python3 scripts/treecopy.py <src> --copy-to <dest>

# Structure + files
python3 scripts/treecopy.py <src> --copy-to <dest> --copy-files
```

## Defaults
- Default ignores: `.git`, `__pycache__`, `node_modules`, `.DS_Store`, `.venv`, `.mypy_cache`, `.pytest_cache`, `.ruff_cache`
- Color: auto-detected (TTY-aware, respects `NO_COLOR` env var)

## Execution
Run the appropriate treecopy.py command based on $ARGUMENTS. Show output to the user.
For copy operations, always confirm the dry-run output before proceeding to a live copy.
