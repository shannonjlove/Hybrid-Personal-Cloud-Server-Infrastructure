# MCP Guarded Repair

Scripts to restore write-enabled capability to the public SJL Unified Cloud MCP V2 endpoint (`sjl-cloud-access-mcp.service`, port `8797`) while preserving the healthy guarded backend (`sjl-unified-cloud-mcp-rw.service`, port `8777`).

## Scripts

### `guarded-repair-v1.7.sh`

**SHA-256:** `d58669ce5c51b6e3ee86092a3ede8927facf69c810686c4d8c90508eda09186a`

The primary recovery script. Run as root on the Hostinger VPS (`shannonjlove.cloud`).

See `06-OPS/runbooks/mcp-write-recovery.md` for the full pre-execution checklist.

## What it does

1. Backs up the current `server.py` and systemd unit files before any mutation.
2. Queries both live MCP endpoints (`8777` and `8797`) to capture pre-repair tool manifests.
3. Searches filesystem backups, source trees, and Git history for historical `server.py` candidates.
4. Deduplicates candidates by SHA-256 and ranks them by write-path evidence (8777 integration, RW service reference, write-health functions, BookStack write tools, approval token presence).
5. Penalises any candidate with an explicit `readonly=true` default.
6. Starts each high-scoring candidate on the throwaway loopback port `18897` and performs a full MCP handshake.
7. Requires write-health and BookStack create/update/upsert capabilities before accepting any candidate.
8. Atomically promotes the validated candidate via `mv` (same-directory temp file).
9. Restarts only `sjl-cloud-access-mcp.service`; `sjl-unified-cloud-mcp-rw.service` is never touched.
10. Verifies `8797` exposes more than 22 tools and is within the configured gap tolerance from `8777`.
11. Rolls back automatically (restoring the backed-up `server.py`) on any post-mutation failure.
12. Generates a repair report, SHA-256 manifests, redacted environment files, service status output, repair log, and a compressed backup archive.

## Safety constraints

- No mutation before complete backup and live preflight validation.
- `sjl-unified-cloud-mcp-rw.service` (port `8777`) must remain active at all times.
- Staging port `18897` must be free before execution begins.
- Rollback cannot recurse; a single guard flag prevents double-rollback.
- Logging uses a named FIFO with explicit `tee` shutdown to avoid partial log writes.
