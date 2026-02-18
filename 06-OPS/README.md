# 06-OPS — Supervised Autonomy Control Center

This folder enforces "supervised autonomous" operations:
- The system can PLAN + PREPARE autonomously
- The system must REQUEST APPROVAL before:
  - Publishing anything public
  - Rotating keys / changing DNS
  - Deleting data
  - Deploying new containers
  - Modifying firewall rules

## Files
- approvals/ : pending + approved change requests
- runbooks/  : step-by-step operational playbooks
- changes/   : generated diffs / patch notes
- logs/      : execution logs (non-sensitive)
