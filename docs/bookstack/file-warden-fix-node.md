# File Warden — Fix Node Environment Module

The `fix-node-env.sh` module resolves the Node.js/npm version conflict that occurs on Ubuntu/Debian when the system `npm` package conflicts with the npm bundled by NodeSource's `nodejs` package.

---

## Usage

```bash
# Via main CLI
sudo bash 03-AUTOMATION/file-warden/file-warden.sh fix-node

# Standalone
sudo bash 03-AUTOMATION/file-warden/modules/fix-node-env.sh [--log FILE]
```

**Must be run as root.**

---

## What It Does (Step by Step)

1. **Version manager check** — if `nvm`, `volta`, or `fnm` is detected, exits gracefully with instructions. System package repair is not appropriate when a version manager is in use.

2. **Node.js presence check** — exits with an error if `node` is not on the PATH, with a link to NodeSource setup instructions.

3. **NodeSource repo check** — warns if the NodeSource apt repository is not detected in the cache.

4. **Remove conflicting system npm** — runs `apt-get remove --purge npm` if the Ubuntu system `npm` package is installed.

5. **Clean broken dependencies** — runs `apt-get autoremove && autoclean`.

6. **Clear npm cache** — runs `npm cache clean --force` to remove stale cached artifacts.

7. **Reinstall npm** — runs `apt-get update && apt-get install npm` to pull the NodeSource-compatible version.

8. **Verify** — confirms `node --version` and `npm --version` are both present and functional.

---

## Why This Conflict Happens

Ubuntu's default repository ships a standalone `npm` package that depends on an older `nodejs` version. When NodeSource's `nodejs` (which bundles its own npm) is also installed, `apt` cannot resolve the version conflict and blocks further package installations.

The fix removes the Ubuntu npm and lets NodeSource's bundled npm take over.

---

## If NodeSource Is Not Set Up

```bash
# Add NodeSource LTS repository first
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo bash -

# Then run the repair
sudo bash 03-AUTOMATION/file-warden/file-warden.sh fix-node
```

---

## If Using nvm / volta / fnm

The module exits without making any changes. Manage Node versions through your version manager instead:

```bash
# nvm
nvm install --lts && nvm use --lts

# volta
volta install node

# fnm
fnm install --lts && fnm use lts-latest
```

---

## Verification After Run

```bash
node --version   # e.g. v22.x.x
npm --version    # e.g. 10.x.x
```

After a successful repair, re-run any `apt-get install` command that previously failed due to the npm conflict.

---

## Log Output

```
2026-06-30 14:30:00 [fix-node-env] === Node.js Environment Repair ===
2026-06-30 14:30:00 [fix-node-env] Node.js version: v22.4.0
2026-06-30 14:30:01 [fix-node-env] Removing conflicting system npm package...
2026-06-30 14:30:05 [fix-node-env] System npm removed.
2026-06-30 14:30:06 [fix-node-env] Cleaning up broken dependencies...
2026-06-30 14:30:08 [fix-node-env] Clearing npm cache...
2026-06-30 14:30:09 [fix-node-env] Installing npm from NodeSource repository...
2026-06-30 14:30:20 [fix-node-env] === Verification ===
2026-06-30 14:30:20 [fix-node-env]   node: v22.4.0
2026-06-30 14:30:20 [fix-node-env]   npm:  10.7.0
2026-06-30 14:30:20 [fix-node-env] npm is functional.
2026-06-30 14:30:20 [fix-node-env] === Repair complete. node=v22.4.0  npm=v10.7.0 ===
```

---

*Source: `03-AUTOMATION/file-warden/modules/fix-node-env.sh` | Last updated: June 2026*
