# File Warden — Overview & Quick Start

File Warden is the automation module responsible for organizing files into PARA-aware category folders, applying persistent metadata tags, and repairing server-side Node.js environments.

It lives at `03-AUTOMATION/file-warden/` and is part of the AI + Automation layer of the hybrid cloud infrastructure.

---

## What It Does

| Capability | Description |
|------------|-------------|
| **File Organization** | Recursively scans a directory and moves files into named category subfolders (Images, Videos, PDFs, Scripts, etc.) |
| **xattr Tagging** | Applies Linux extended attributes (`user.tags`) to every file — idempotent and comma-appended |
| **MIME Fallback** | Uses `file(1)` MIME detection for files with unrecognized extensions |
| **Node.js Repair** | Removes conflicting system `npm`, cleans broken dependencies, reinstalls from NodeSource |
| **Dry-Run Mode** | Preview all operations before any file is touched |
| **Ops Integration** | Generates 06-OPS approval tickets before destructive operations on production paths |

---

## Quick Start

### 1. Preview organization (always do this first)

```bash
sudo bash 03-AUTOMATION/file-warden/file-warden.sh organize --dry-run /srv/sjl/data
```

### 2. Apply organization

```bash
sudo bash 03-AUTOMATION/file-warden/file-warden.sh organize /srv/sjl/data
```

### 3. Repair Node.js / npm

```bash
sudo bash 03-AUTOMATION/file-warden/file-warden.sh fix-node
```

### 4. Health check

```bash
bash 03-AUTOMATION/file-warden/file-warden.sh status
```

---

## Module Structure

```
03-AUTOMATION/file-warden/
├── file-warden.sh              ← Main entry point
├── modules/
│   ├── organize-and-tag.sh     ← File organization + xattr tagging
│   └── fix-node-env.sh         ← Node.js/npm environment repair
└── config/
    └── category-map.conf       ← Editable category mappings
```

---

## Prerequisites

| Tool | Purpose | Install |
|------|---------|---------|
| `xattr` | Extended attribute tagging | `apt install xattr` |
| `file` | MIME-type detection (fallback) | Pre-installed on Ubuntu |
| `bash 4+` | Script runtime | Pre-installed on Ubuntu 20+ |

---

## Log File

All operations are logged to `/var/log/sjl-file-warden.log` by default.
Override with `--log /path/to/file.log`.

---

## Ops Approval Policy

Per `06-OPS/approvals/POLICY.md`, running `organize` without `--dry-run` on production paths requires an approval ticket:

```bash
bash 06-OPS/request-approval.sh "File Warden Organize" \
  "Organize /srv/sjl/data — dry-run reviewed, N files to move"
```

---

*Source: `03-AUTOMATION/file-warden/README.md` | Last updated: June 2026*
