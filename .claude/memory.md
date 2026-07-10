# /memory — Persistent Memory Skill

Use this skill whenever you need to read, save, or manage persistent context across Claude Code sessions and nodes (Nexus, sOs, WebTop).

## When to invoke

- At the start of every session — always view before asking the user to re-explain anything
- Before writing a memory file — check if one already exists so you don't duplicate
- When the user says "remember this", "save that", "don't forget", or "update memory"
- When the user asks "what do you know about X" or "check memory for Y"
- At session end if anything new and worth keeping was learned

---

## Step 1 — Always start by viewing

Run this first, before any other memory operation:

```
memory(command='view', path='/memories')
```

This lists everything stored. Read the relevant files before proceeding. Never ask the user to repeat context that might already be in memory.

---

## Step 2 — Read specific files as needed

```
memory(command='view', path='/memories/infra/nexus.md')
memory(command='view', path='/memories/prefs.md')
```

Use `view` with `view_range` to read a section of a long file:
```
memory(command='view', path='/memories/projects/current.md', view_range=[1, 40])
```

---

## Step 3 — Write or update memory

### If the file does not exist yet — create it:
```
memory(command='create', path='/memories/infra/nexus.md', file_text="# Nexus\n\n...")
```

### If the file exists — edit in place with str_replace:
```
memory(command='str_replace',
  path='/memories/infra/nexus.md',
  old_str='old text to replace',
  new_str='new updated text')
```

`old_str` must appear exactly once in the file. If it appears multiple times, narrow it with more surrounding context.

### To insert a line (e.g. prepend a log entry):
```
memory(command='insert', path='/memories/projects/current.md',
  insert_line=0, insert_text='2026-07-10: deployed memory stack on Nexus and sOs')
```

---

## File organization

```
/memories/
  README.md              ← index — what's in here
  prefs.md               ← user preferences and working style
  infra/
    nexus.md             ← Nexus IPs, services, ports
    sos.md               ← sOs facts
    decisions.md         ← architecture choices and why
  projects/
    current.md           ← active work and next steps
    backlog.md           ← future ideas
```

Rules:
- Keep one file per topic, update it in place — do not create a new file each session
- Memory files record current truth, not history (git has history)
- Never store credentials, tokens, or private keys — paths only

---

## Rename or delete

```
memory(command='rename', old_path='/memories/scratch.md', new_path='/memories/archive/scratch.md')
memory(command='delete', path='/memories/scratch.md')
```

Cannot rename or delete `/memories` root.

---

## Where this data lives

- `MEMORY_ROOT` = `/mnt/shared-context/claude-memories/`
- Same files on **all nodes** via NFS — Nexus, sOs, WebTop all share one store
- Changes made from any node are immediately visible everywhere
- This MCP server (`claude-memory`) is a stdio subprocess — no container, no API key, no cost

---

## If invoked with an argument

| Argument | Action |
|---|---|
| `/memory` (no arg) | `view /memories`, report what's there |
| `/memory view [path]` | View the given path, default `/memories` |
| `/memory save "..."` | Choose the right file, create or update it |
| `/memory search [topic]` | View directory then relevant files, summarize what's found |
| `/memory clean` | List stale or duplicate files and propose what to remove |
