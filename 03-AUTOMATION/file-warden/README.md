# File Warden

Automated file organization, metadata tagging, and environment repair module.
Part of the 03-AUTOMATION layer, integrated with the 06-OPS supervised autonomy framework.

## Role

- Recursively scan a directory and route files into PARA-aware category subfolders
- Apply persistent `user.tags` via Linux extended attributes (`xattr`)
- Detect and repair Node.js/npm version conflicts (Ubuntu/Debian NodeSource)
- Dry-run preview mode — always safe to check before committing changes
- Idempotent — safe to re-run; already-organized files are skipped

## Module Structure

```
file-warden/
├── file-warden.sh              Main CLI orchestrator (entry point)
├── modules/
│   ├── organize-and-tag.sh     File organization + xattr tagging
│   └── fix-node-env.sh         Node.js/npm environment repair
└── config/
    └── category-map.conf       Externalized category mapping (edit to customise)
```

## Quick Start

```bash
# 1. Preview organization — no changes made
sudo bash 03-AUTOMATION/file-warden/file-warden.sh organize --dry-run /srv/sjl/data

# 2. Apply organization
sudo bash 03-AUTOMATION/file-warden/file-warden.sh organize /srv/sjl/data

# 3. Repair Node.js/npm conflicts
sudo bash 03-AUTOMATION/file-warden/file-warden.sh fix-node

# 4. Check system status
bash 03-AUTOMATION/file-warden/file-warden.sh status
```

## Subcommands

### `organize`

```
sudo file-warden.sh organize [--dry-run] [--exclude PATTERN] [--log FILE] <directory>
```

| Option | Description |
|--------|-------------|
| `--dry-run` | Preview moves and tags without making changes |
| `--exclude PATTERN` | Skip paths matching PATTERN (find `-not -path` syntax) |
| `--log FILE` | Override log file (default: `/var/log/sjl-file-warden.log`) |

Files are classified by extension (see `config/category-map.conf`), with MIME-type fallback.
Name collisions are resolved by appending `_N` to the basename.
The `user.tags` xattr is appended idempotently — existing tags are preserved.

### `fix-node`

```
sudo file-warden.sh fix-node [--log FILE]
```

Repairs the Ubuntu/Debian npm dependency conflict caused by the system `npm` package
conflicting with NodeSource's bundled npm. Detects and gracefully exits if `nvm`,
`volta`, or `fnm` is managing Node.js (in which case system packages should not be used).

Steps:
1. Detect version managers — skip if nvm/volta/fnm present
2. Remove conflicting system `npm` package
3. Run `apt-get autoremove && autoclean`
4. Clear stale npm cache
5. Reinstall npm from NodeSource
6. Verify `node --version` and `npm --version`

### `status`

```
file-warden.sh status
```

Prints system health: xattr availability, node/npm versions, and recent log tail.

## Configuration

Edit `config/category-map.conf` to add or change file categories without touching any script.

Format: `ext1|ext2|ext3:DestinationFolder:tag`

```conf
# Example: route .sketch and .fig files to a Design folder
sketch|fig|xd:Design:design
```

## Ops Approval Policy

Per `06-OPS/approvals/POLICY.md`, the organize subcommand requires approval before
running without `--dry-run` on production server paths, as it moves (not copies) files.

Generate an approval request:
```bash
bash 06-OPS/request-approval.sh "File Warden Organize" \
  "Run organize-and-tag on /srv/sjl/data — dry-run reviewed, 47 files to move"
```

## Prerequisites

| Tool | Purpose | Install |
|------|---------|---------|
| `xattr` | Extended attribute tagging | `apt install xattr` |
| `file` | MIME-type fallback detection | `apt install file` (usually pre-installed) |
| `bash 4+` | Script runtime | Pre-installed on Ubuntu 20+ |

## Log File

All actions logged to `/var/log/sjl-file-warden.log` (overrideable with `--log`).

---
*Last updated: June 2026*
