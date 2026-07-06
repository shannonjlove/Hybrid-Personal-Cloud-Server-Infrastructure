# Memory Usage Workflow — shannonjlove.cloud

How to save, organize, and retrieve persistent information across all nodes and sessions.

---

## Where information lives

All memory files share one canonical root, identical on every node:

```
/mnt/shared-context/
  claude-memories/     ← claude-memory MCP server (Claude Code sessions)
  memory-agent/        ← memory-agent REST API (curl, scripts, HTTP clients)
```

- **Nexus** holds the real data at `/opt/shared-context` (bind-mounted to `/mnt/shared-context`), exported over NFS.
- **sOs** and **WebTop** NFS-mount the same path, so they read and write the exact same files.
- **Your iPhone** reaches `memory-agent` via `https://memory.shannonjlove.cloud` (Tailscale required).

---

## Two ways to read and write

### 1. claude-memory — MCP tool inside Claude Code

Used automatically by Claude Code on Nexus, sOs, and inside WebTop. No URL, no auth, no API key.

**Always start every session with:**
```
memory(command='view', path='/memories')
```
This lists everything currently saved. Claude will see it and won't ask you to re-explain context.

| Command | What it does | Example |
|---|---|---|
| `view` | List a directory or read a file | `view /memories` or `view /memories/infra-notes.md` |
| `create` | Write a new file | `create /memories/infra-notes.md` with file_text |
| `str_replace` | Edit a specific block in a file | Replace one unique string with another |
| `insert` | Insert a line at a line number | Insert at line 0 = prepend |
| `delete` | Delete a file or directory | `delete /memories/scratch.md` |
| `rename` | Move or rename a file | Rename `/memories/old.md` to `/memories/new.md` |

All paths must start with `/memories`.

---

### 2. memory-agent REST API — HTTP from anywhere on Tailscale

Base URL: `https://memory.shannonjlove.cloud` (Tailscale-connected clients only)  
Direct: `http://100.115.66.75:8100` (from any Tailscale node)

**List everything:**
```bash
curl -s https://memory.shannonjlove.cloud/memories/
```

**Read a file:**
```bash
curl -s https://memory.shannonjlove.cloud/memories/infra-notes.md
```

**Create a file:**
```bash
curl -s -X POST https://memory.shannonjlove.cloud/memories/infra-notes.md \
  -H "Content-Type: application/json" \
  -d '{"file_text": "# Infra Notes\n\n- NPM on Nexus port 81\n"}'
```

**Edit a file (str_replace):**
```bash
curl -s -X PATCH https://memory.shannonjlove.cloud/memories/infra-notes.md \
  -H "Content-Type: application/json" \
  -d '{"old_str": "port 81", "new_str": "port 81 (Tailscale only)"}'
```

**Delete a file:**
```bash
curl -s -X DELETE https://memory.shannonjlove.cloud/memories/scratch.md
```

**Rename/move a file:**
```bash
curl -s -X POST https://memory.shannonjlove.cloud/memories:rename \
  -H "Content-Type: application/json" \
  -d '{"old_path": "/memories/scratch.md", "new_path": "/memories/archive/scratch.md"}'
```

**Health check:**
```bash
curl -s https://memory.shannonjlove.cloud/healthz
```

---

## What to save and how to organize it

### Good candidates for persistent memory

- Infrastructure decisions and reasoning ("why we chose X over Y")
- Credentials locations (paths only — never actual secrets)
- Current project state and next steps
- Recurring preferences ("always reply under 3 sentences")
- Service URLs, ports, Tailscale IPs
- Things you've had to explain more than once

### File naming and layout

Use subdirectories to keep things from getting noisy:

```
/memories/
  infra/
    nexus.md          ← Nexus node facts (IPs, services, ports)
    sos.md            ← sOs node facts
    decisions.md      ← architecture choices and rationale
  projects/
    current.md        ← active work, what's in progress
    backlog.md        ← future ideas
  prefs.md            ← personal/session preferences
  README.md           ← index, what's in here
```

Flat files work fine for simple notes. Use subdirectories once you have more than ~5 files.

### Write once, update in place

Don't create a new file each session. Keep one `infra/nexus.md` and use `str_replace` to update it. The history lives in git if you need to look back — memory files are for current truth, not a log.

---

## Session startup workflow

**In Claude Code (Nexus, sOs, or WebTop):**

The MCP server starts automatically. At the beginning of your first prompt in a session, Claude will call `view /memories` and read the current state. You don't have to ask — it's in the tool description. If it doesn't, prompt: *"Check memory first."*

**From iPhone / curl:**

```bash
# Quick check — what's in there?
curl -s https://memory.shannonjlove.cloud/memories/ | jq .

# Read the top-level index
curl -s https://memory.shannonjlove.cloud/memories/README.md
```

---

## Retrieving specific information

**Find a file when you don't know the exact name:**
```bash
# List a subdirectory
curl -s https://memory.shannonjlove.cloud/memories/infra/

# Read everything in a file
curl -s https://memory.shannonjlove.cloud/memories/infra/nexus.md
```

**In Claude Code — search by asking:**
Tell Claude: *"Check memory for anything about [topic]."* Claude will `view` the directory, then `view` relevant files.

**From sOs or WebTop:**
Same as Nexus — the claude-memory MCP server is installed with the same `MEMORY_ROOT`. The NFS mount means it's reading the exact same files as Nexus.

---

## Access from each node

| Where you are | How to reach memory |
|---|---|
| Nexus (Claude Code) | MCP tool — `memory(command='view', ...)` |
| sOs (Claude Code) | Same MCP tool — same NFS-backed MEMORY_ROOT |
| WebTop (Claude Code inside container) | Same MCP tool — /mnt/shared-context bind-mounted inside container |
| iPhone (Scriptable / Tailscale) | `https://memory.shannonjlove.cloud` REST API |
| Any Tailscale node (curl) | `http://100.115.66.75:8100` REST API |
| Off-network | **Blocked** — access list allows Tailscale `100.64.0.0/10` only |

---

## Security notes

- `memory.shannonjlove.cloud` is Tailscale-only. The NPM access list blocks `0.0.0.0/0` and allows only `100.64.0.0/10`. Do not remove this restriction.
- Memory files may contain session context and infrastructure notes but **never** credentials, tokens, or private keys.
- NFS is exported to the Tailscale subnet only — it is not reachable from the public internet.
