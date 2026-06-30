# Approval Policy (Supervised Autonomous)

## Autopilot Allowed (no approval)
- Read-only audits (status, logs, disk, memory)
- Generating plans, checklists, diffs
- Validating configs (lint, syntax checks)
- Backups and non-destructive exports

## Requires Approval
- Any public exposure (ports, NPM proxy hosts, DNS, TLS)
- Any key/token generation or rotation
- Any container deployment or image updates
- Any filesystem deletions or destructive actions
- Any firewall changes
- Any database migrations
