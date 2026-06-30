# Metadata Persistence

Ensuring file metadata (tags, links, attributes) survives moves, syncs, and cloud transfers.

## Role

- Preserve extended attributes and tags across cloud providers
- Hookmark link persistence during file migration
- Metadata backup and restore for cloud consolidation

## Files (Planned)

- Metadata extraction scripts
- Sidecar file generators
- Sync validation tools

## Implemented

- **File Warden** (`../file-warden/`) — applies and preserves `user.tags` xattr across reorganization runs; idempotent tagging survives repeated moves.

---
*Last updated: February 2026*