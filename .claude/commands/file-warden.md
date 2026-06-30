---
description: Run File Warden — organize files, apply xattr tags, or check system status
argument-hint: organize <path> | fix-node | status
---

You are invoking the File Warden automation module at `03-AUTOMATION/file-warden/file-warden.sh`.

## Subcommands

### organize
Moves files into PARA-aware category subfolders and applies `user.tags` via xattr.

**Always run dry-run first:**
```bash
sudo bash 03-AUTOMATION/file-warden/file-warden.sh organize --dry-run $ARGUMENTS
```
If the user approves the preview, then run for real:
```bash
sudo bash 03-AUTOMATION/file-warden/file-warden.sh organize $ARGUMENTS
```

Options:
- `--exclude '*/.git/*'` — skip git directories
- `--log /path/to/log.log` — custom log file

For production server paths, generate a 06-OPS approval request before running:
```bash
bash 06-OPS/request-approval.sh "File Warden Organize" "Description of what will be moved"
```

### fix-node
Repairs Node.js/npm conflicts on Ubuntu/Debian:
```bash
sudo bash 03-AUTOMATION/file-warden/file-warden.sh fix-node
```

### status
Show File Warden health (xattr, node, npm, recent log):
```bash
bash 03-AUTOMATION/file-warden/file-warden.sh status
```

## Defaults
- Log file: `/var/log/sjl-file-warden.log`
- Category map: `03-AUTOMATION/file-warden/config/category-map.conf`

## Execution flow
1. Run the appropriate subcommand based on $ARGUMENTS
2. Show the log output to the user
3. For organize: always confirm dry-run output before proceeding to live run
4. Report summary (files moved, tagged, errors)
