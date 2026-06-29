# PARA Structure

> **Authoritative reference:** `00-MASTER-ARCHITECTURE/sjl-para-naming-master.md`
> This file is an overview. The master document governs all naming, classification, and routing decisions.

## Digital Organization Methodology

This infrastructure follows the PARA methodology (Projects, Areas, Resources, Archive) extended with five additional system categories, applied across all systems — file storage, container organization, cloud object keys, automation rules, and documentation.

## Nine Categories (Current — v8.0, 2026-06-30)

| Six-Digit Code | Category | Definition | Examples |
|----------------|----------|-----------|----------|
| `010000` | **INBOX** | Active intake awaiting classification | New downloads, mobile captures |
| `020000` | **PROJECTS** | Active work with a defined endpoint | Fellowship applications, TagBack development |
| `030000` | **AREAS** | Ongoing responsibilities, no end date | Server maintenance, cloud accounts, production work |
| `040000` | **RESOURCES** | Reference material | Technical docs, templates, scripts |
| `050000` | **ARCHIVES** | Inactive, completed, deprecated | Past projects, deprecated configs |
| `060000` | **PRIVATE MEDIA** | Restricted personal media | Personal photos, identity documents |
| `070000` | **SYSTEM AUTOMATION** | Infrastructure, scripts, agents | FileWarden, MCP configs, routing rules |
| `080000` | **APPLICATION DATA** | App state, registries, indices | DOCID registry, ingest logs |
| `090000` | **QUARANTINE** | Integrity failures, review holds | Hash mismatches, missing sidecars |

## Canonical Filename Format (Current)

```
[PPPPPP]_YYYY-MM-DD__DOCID__semantic-title__vMAJOR-MINOR__sha8.ext
```

The six-digit PARA code is always the **first field** in every governed filename.

## Naming Convention History

| Era | Scheme | Status |
|-----|--------|--------|
| Pre-June 11, 2026 | Informal | Retired |
| June 11, 2026 | 10000-90000 sequential five-digit | Legacy alias only |
| June 19, 2026 (v7.3) | 01000-09000 strict five-digit | Migration source |
| June 30, 2026 (v8.0) | 010000-090000 six-digit [P][C][SS][NN] | **Current canonical** |

## Tools

- **Hazel**: macOS file automation with PARA-based rules (11 rules)
- **FileWarden** (`071000`): Routing rules and file governance automation
- **Shell scripts** (`040200`): 8 ingest and routing scripts
- **LaunchAgents**: Scheduled automation on Mac
- **Hookmark**: Deep linking with metadata persistence
- **MCP integrations**: Google Drive, pCloud, iDrive E2

---
*Last updated: 2026-06-30 — see sjl-para-naming-master.md for full standard*
