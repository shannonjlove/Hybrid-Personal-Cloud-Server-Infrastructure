---
description: Repair Node.js/npm version conflicts on Ubuntu/Debian (NodeSource)
---

You are invoking the File Warden node environment repair module.

Run:
```bash
sudo bash 03-AUTOMATION/file-warden/file-warden.sh fix-node
```

This resolves the conflict between Ubuntu's system `npm` package and the npm
bundled with NodeSource's `nodejs` package.

**What it does:**
1. Detects nvm/volta/fnm — exits gracefully if a version manager is in use
2. Removes the conflicting system `npm` package
3. Runs `apt-get autoremove && autoclean` to clear broken deps
4. Clears stale npm cache
5. Reinstalls npm from the NodeSource repository
6. Verifies `node --version` and `npm --version`

**After running**, verify:
```bash
node --version   # e.g. v22.x.x
npm --version    # e.g. 10.x.x
```

Then re-run any previously failed `apt install` command.

**If NodeSource repo is missing**, re-add it first:
```bash
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo bash -
```

Log output is written to `/var/log/sjl-file-warden.log`.
