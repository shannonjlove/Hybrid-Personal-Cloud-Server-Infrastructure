---
name: memory-workflow
description: Read, write, and organize persistent memory files on the shannonjlove.cloud SJL Sovereign Cloud shared-context system, shared across Nexus, sOs, and WebTop via NFS. Use this skill whenever Shannon asks Claude to check memory, save something for later, recall infrastructure facts, update project state, or otherwise persist/retrieve information that should survive across sessions and nodes — including phrases like "remember this", "check memory", "what do we know about X", "save this to memory", "update the infra notes", or "what's in /memories". Also use when working inside Claude Code on Nexus, sOs, or WebTop and the task would benefit from checking prior context before starting, or from persisting new decisions/facts once the task is done. Covers both the claude-memory MCP tool (used automatically inside Claude Code sessions) and the memory-agent REST API (for curl, scripts, or off-Claude-Code HTTP access from any Tailscale-connected client, including iPhone).
---

# Memory Workflow — shannonjlove.cloud Shared Context

Persistent memory for the SJL Sovereign Cloud lives in one place and is readable/writable from every node. This skill covers how to read from it, write to it, and keep it organized so it stays useful instead of turning into noise.

## Why this exists

Nexus, sOs, and WebTop are three different machines, but they should behave like one system with continuity of context. Instead of Shannon re-explaining infrastructure decisions, project state, or preferences every session, that information lives in shared files any of the three can read and write. The two access methods below (MCP tool vs. REST API) are just different doors into the same room — always confirm which door is available before picking one.

## Where the files actually live

```
/mnt/shared-context/
  claude-memories/     ← used by the claude-memory MCP tool (Claude Code sessions)
  memory-agent/        ← used by the memory-agent REST API (curl, scripts, HTTP clients)
```

- **Nexus** holds the real data at `/opt/shared-context`, bind-mounted to `/mnt/shared-context`, exported over NFS.
- **sOs** and **WebTop** NFS-mount that same path — reads and writes land on the identical files, not copies.
- Off of any of the three nodes (e.g. from an iPhone), the only door in is the memory-agent REST API over Tailscale.

## Choosing which access method to use

| If you are... | Use... |
|---|---|
| Running inside Claude Code on Nexus, sOs, or WebTop | The `memory` MCP tool — no URL, no auth, already wired up |
| Running a curl command, a script, or hitting this from an iPhone/off-Claude-Code client | The memory-agent REST API over Tailscale |

Don't reach for curl inside a Claude Code session just because it's familiar — the MCP tool is faster and already scoped correctly. Reach for curl when there's no Claude Code session to run the MCP tool in.

## Method 1: claude-memory MCP tool

All paths must start with `/memories`.

**Start every session by checking what's already there:**
```
memory(command='view', path='/memories')
```
This surfaces existing context so Shannon doesn't have to re-explain it. If Claude hasn't done this at the start of a session and the task would benefit from prior context, do it before proceeding — don't wait to be asked.

| Command | What it does |
|---|---|
| `view` | List a directory or read a file |
| `create` | Write a new file (needs `file_text`) |
| `str_replace` | Replace one unique string in a file with another |
| `insert` | Insert a line at a given line number (0 = prepend) |
| `delete` | Delete a file or directory |
| `rename` | Move or rename a file |

## Method 2: memory-agent REST API

Base URL (Tailscale-connected clients only): `https://memory.shannonjlove.cloud`
Direct (from any Tailscale node): `http://100.115.66.75:8100`

This endpoint is Tailscale-only by design — the NPM access list blocks `0.0.0.0/0` and allows only `100.64.0.0/10`. Never suggest removing that restriction or exposing it publicly.

```bash
# List everything
curl -s https://memory.shannonjlove.cloud/memories/

# Read a file
curl -s https://memory.shannonjlove.cloud/memories/infra-notes.md

# Create a file
curl -s -X POST https://memory.shannonjlove.cloud/memories/infra-notes.md \
  -H "Content-Type: application/json" \
  -d '{"file_text": "# Infra Notes\n\n- NPM on Nexus port 81\n"}'

# Edit a file (str_replace)
curl -s -X PATCH https://memory.shannonjlove.cloud/memories/infra-notes.md \
  -H "Content-Type: application/json" \
  -d '{"old_str": "port 81", "new_str": "port 81 (Tailscale only)"}'

# Delete a file
curl -s -X DELETE https://memory.shannonjlove.cloud/memories/scratch.md

# Rename/move a file
curl -s -X POST https://memory.shannonjlove.cloud/memories:rename \
  -H "Content-Type: application/json" \
  -d '{"old_path": "/memories/scratch.md", "new_path": "/memories/archive/scratch.md"}'

# Health check
curl -s https://memory.shannonjlove.cloud/healthz
```

Per Shannon's standing infrastructure rule, if any of this needs to run as a terminal command on a remote node (not just illustrated here), combine it into a single base64-encoded one-liner rather than issuing it as separate steps — see the base64 delivery convention in Shannon's infra practices.

## What belongs in persistent memory

Good candidates:
- Infrastructure decisions and the reasoning behind them ("why we chose X over Y")
- Credential *locations* (paths only — never actual secrets, tokens, or private keys)
- Current project state and next steps
- Recurring preferences ("always reply under 3 sentences")
- Service URLs, ports, Tailscale IPs
- Anything Shannon has had to explain more than once

Not a fit: secrets/keys/tokens, one-off scratch thoughts that don't need to survive, or anything that's really a historical log — memory files hold current truth, not a changelog. If Shannon wants history, that's what git commits in the private repo are for.

## Organizing files

Flat files are fine for a handful of notes. Once there are more than ~5 files, split into subdirectories so retrieval stays fast:

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
  README.md           ← index — what's in here and where to look
```

**Write once, update in place.** Don't create a new file each session for the same topic — that just fragments the context. Keep one `infra/nexus.md` and use `str_replace` (or the PATCH equivalent) to update it as facts change. The file naming convention Shannon uses for other artifacts (`YYYY-MM-DD_HH-MM_category-subcategory_description_UUID24.ext`) does not apply here — memory files are named by topic, not by timestamp, precisely because they're living documents, not point-in-time artifacts.

## Retrieving specific information

**Don't know the exact filename?**
```bash
curl -s https://memory.shannonjlove.cloud/memories/infra/        # list a subdirectory
curl -s https://memory.shannonjlove.cloud/memories/infra/nexus.md # read a file
```

**Inside Claude Code**, just ask in natural language — "check memory for anything about X" — and let Claude `view` the directory tree, then `view` the files that look relevant. Don't require Shannon to know the exact path.

## Access matrix

| Where you are | How to reach memory |
|---|---|
| Nexus (Claude Code) | `memory` MCP tool |
| sOs (Claude Code) | Same MCP tool — same NFS-backed root |
| WebTop (Claude Code inside container) | Same MCP tool — `/mnt/shared-context` bind-mounted inside the container |
| iPhone (Scriptable / Tailscale) | `https://memory.shannonjlove.cloud` REST API |
| Any Tailscale node (curl) | `http://100.115.66.75:8100` REST API |
| Off-Tailscale-network | Blocked by design — do not attempt to work around this |

## Security boundaries — do not cross these

- `memory.shannonjlove.cloud` must stay Tailscale-only (`100.64.0.0/10`). Never suggest opening it to `0.0.0.0/0`.
- Never write actual credentials, tokens, API keys, or private key material into memory files — locations/paths only.
- NFS is exported to the Tailscale subnet only; it should never be reachable from the public internet. If a task seems to require changing this, flag it to Shannon before proceeding rather than doing it quietly.
