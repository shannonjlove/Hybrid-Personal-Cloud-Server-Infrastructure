#!/usr/bin/env bash
set -euo pipefail

TS="$(date -u +%Y%m%dT%H%M%SZ)"
TITLE="${1:-Change Request}"
DESC="${2:-No description provided}"
FILE="06-OPS/approvals/${TS}__${TITLE// /_}.md"

cat > "$FILE" <<EOT
# $TITLE
**Created (UTC):** $TS

## Summary
$DESC

## Risk Level
- [ ] Low (docs/config checks only)
- [ ] Medium (service restart, internal-only change)
- [ ] High (public exposure, secrets, firewall, data changes)

## Proposed Actions (fill in)
1.
2.
3.

## Rollback Plan (required)
1.

## Approval
- [ ] Approved by Shannon
- [ ] Rejected
EOT

echo "Created: $FILE"
