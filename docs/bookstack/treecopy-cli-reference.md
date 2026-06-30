# TreeCopy — CLI Reference

Full flag reference for `scripts/treecopy.py`.

---

## Synopsis

```
treecopy.py [directory] [OPTIONS]
```

`directory` defaults to the current directory (`.`) if omitted.

---

## Display Options

| Flag | Short | Description |
|------|-------|-------------|
| `--max-depth N` | `-L N` | Limit tree depth to N levels. `-L 1` shows only direct children. |
| `--dirs-only` | `-d` | Show directories only; skip all files. |
| `--all` | `-a` | Include hidden files and directories (dotfiles). |
| `--size` | `-s` | Append human-readable file size to each file entry. |
| `--no-color` | | Disable ANSI colour output. Also disabled automatically when piping. |

---

## Filter Options

| Flag | Short | Description |
|------|-------|-------------|
| `--ignore PATTERN` | `-I PATTERN` | Exclude entries matching PATTERN (fnmatch-style, repeatable). |
| `--no-ignore-defaults` | | Disable the built-in ignore list (.git, node_modules, etc.). |

### Pattern Examples

```bash
-I '*.log'          # ignore all .log files
-I 'tmp*'           # ignore anything starting with tmp
-I node_modules     # ignore node_modules exactly
-I node_modules -I dist -I build   # multiple ignores
```

---

## Output Options

| Flag | Short | Description |
|------|-------|-------------|
| `--json` | | Output tree as JSON instead of text. |
| `--output FILE` | `-o FILE` | Write output to FILE instead of stdout. Works with both text and `--json`. |

### JSON Output Structure

```json
{
  "name": "data",
  "path": "/srv/sjl/data",
  "type": "directory",
  "children": [
    {
      "name": "report.pdf",
      "path": "/srv/sjl/data/report.pdf",
      "type": "file",
      "size": 204800
    }
  ]
}
```

Node types: `"directory"`, `"file"`, `"symlink"`. Symlink nodes include a `"target"` field.

---

## Copy Options

| Flag | Description |
|------|-------------|
| `--copy-to DEST` | Replicate the directory structure from source to DEST. By default only directories are created (no files). |
| `--copy-files` | Used with `--copy-to`: also copy file contents (`shutil.copy2`, preserves metadata). |
| `--dry-run` | Used with `--copy-to`: print what would be created/copied without making changes. |

### Copy Workflow

Always preview first:

```bash
python3 scripts/treecopy.py /srv/sjl/data --copy-to /backup/data --dry-run
```

Then apply:

```bash
python3 scripts/treecopy.py /srv/sjl/data --copy-to /backup/data --copy-files
```

**Safety**: TreeCopy refuses to copy a directory into itself or any subdirectory of itself.

---

## Other Flags

| Flag | Description |
|------|-------------|
| `--version` | Print `treecopy 2.0.0` and exit. |
| `--help` | Print usage summary and exit. |

---

## Exit Codes

| Code | Meaning |
|------|---------|
| `0` | Success |
| `1` | Error (directory not found, write failure, self-copy guard) |

---

## Environment Variables

| Variable | Effect |
|----------|--------|
| `NO_COLOR` | If set, disables ANSI color output (same as `--no-color`). |

---

## Size Format

File sizes use binary units with 1-decimal precision:

| Suffix | Threshold |
|--------|-----------|
| `B` | < 1024 bytes |
| `K` | < 1 MiB |
| `M` | < 1 GiB |
| `G` | < 1 TiB |
| `T` | ≥ 1 TiB |

---

*Source: `scripts/treecopy.py` | Version: 2.0.0 | Last updated: June 2026*
