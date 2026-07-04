# CLAUDE.md — SJL Infrastructure Session Rules

## File Delivery

Whenever a script, config file, or any artifact is intended for the user to run or use
outside this environment (on the VPS, on another server, locally), ALWAYS deliver it
via SendUserFile so it appears as a downloadable attachment. Never just reference the
repo path and expect the user to find it.

Pattern:
1. Write/commit the file to the repo
2. Immediately call SendUserFile with the file path
3. Include a caption with the exact command to run after downloading

## Protected Services

- `sjl-cloud-access-mcp-rw.service` on port `8777` — NEVER stop, restart, or modify
- Port `8777` is the guarded write gateway — hands off at all times

## Port Allocation Rule

Always run `ss -ltnp` before recommending or assigning any port. Never assume a port is free.

## Canonical Process (Non-Negotiable)

Before recommending ANY fix or change:
1. Analyze system logs, configs, and incident history FIRST
2. Research official docs, GitHub issues, real solved community threads
3. Cross-reference against actual SJL infrastructure state
4. Dry run — simulate every change before presenting it
5. Only then present commands to the user

No guessing. No "try this, try that." Evidence only.

## Secret Handling

- Never print API tokens, private keys, session secrets, or approval tokens in any output
- Never commit secrets to git
- Reference secrets by file path only: `/opt/secrets/…`, `/etc/sjl-unified-mcp/runtime.env`

## Architecture References

- Fleet runbook: `06-OPS/runbooks/sjl-mcp-connector-fleet.md`
- Issue resolution process: `06-OPS/runbooks/sjl-issue-resolution-process.md`
- Credential stow: `06-OPS/runbooks/sjl-credential-stow.md`
- Memory platform handoff: `03-AUTOMATION/memory-platform/` (PARA code 036500)
