# SJL PARA Naming Convention — Master Reference
## Version 8.0 | Effective 2026-06-30 | shannonjlove.cloud

**Owner:** Shannon J. Love  
**Classification:** `070000` SYSTEM AUTOMATION / Governance  
**Status:** Authoritative — supersedes all prior naming convention documents  
**Stored at:** `00-MASTER-ARCHITECTURE/sjl-para-naming-master.md`

---

## The SJL Methodology in One Sentence

> Classify visibly, identify permanently, version explicitly, verify cryptographically, register authoritatively, document the rationale, and preserve every prior state.

---

## Table of Contents

1. [Historical Evolution](#1-historical-evolution)
2. [The Six-Digit Standard — Current Canonical](#2-the-six-digit-standard--current-canonical)
3. [Root Namespace Chart](#3-root-namespace-chart)
4. [Digit-Position Reference](#4-digit-position-reference)
5. [Canonical Filename Contract](#5-canonical-filename-contract)
6. [Classification and Routing Workflow](#6-classification-and-routing-workflow)
7. [Migration Rules](#7-migration-rules)
8. [Key Distinctions: PARA Code, DOCID, Version, Hash](#8-key-distinctions-para-code-docid-version-hash)
9. [Governance and Change Control](#9-governance-and-change-control)
10. [LLM Handoff Instructions](#10-llm-handoff-instructions)
11. [Master Allocation Registry](#11-master-allocation-registry)
12. [Appendix A — Five-to-Six Digit Migration Table](#appendix-a--five-to-six-digit-migration-table)
13. [Appendix B — LLM Pre-Assignment Checklist](#appendix-b--llm-pre-assignment-checklist)

---

## 1. Historical Evolution

The SJL PARA numbering system developed in three documented eras before arriving at the current six-digit canonical form. Understanding this lineage is necessary for correct handling of legacy files and migration aliases.

### Era 1 — Origins: Sequential Decimal Scheme (pre–June 11, 2026)

The numeric prefix scheme began as a way to make PARA lifecycle classification **visible and sortable everywhere**: filenames, folders, cloud object keys, BookStack, Paperless / PaperParrot, dashboards, FileWarden routing, and restore workflows.

The design intent was always:
- One prefix per file, placed **first** in the filename
- Machine-readable category without opening the file
- Lexically sortable across all storage systems
- Portable across cloud providers, Linux filesystems, macOS, and S3

### Era 2 — First Formally Documented Scheme: 10000–90000 (June 11, 2026)

The first clearly documented implementation used a sequential five-digit range with large gaps for hierarchical subdivision:

| Code  | Root Category       |
|-------|---------------------|
| 10000 | INBOX               |
| 20000 | PROJECTS            |
| 30000 | AREAS               |
| 40000 | RESOURCES           |
| 50000 | ARCHIVES            |
| 60000 | PRIVATE MEDIA       |
| 70000 | SYSTEM AUTOMATION   |
| 80000 | QUARANTINE / REVIEW |
| 90000 | EXPORTS / SHARES    |

The document from this era explicitly stated that the PARA code must appear **first** in every governed filename. It demonstrated hierarchical subdivision:

```
10000_INBOX
10100_mobile
10200_scans
10300_email

70000_SYSTEM-AUTOMATION
70100_stow
70200_filewarden
70300_hookvault
70500_bookstack-automation
```

**Important:** This era used decimal hierarchy with large sortable gaps — not a system where every individual digit carries a separately encoded meaning.

On **June 17, 2026**, Shannon explicitly reinforced the requirement to place the five-digit PARA code at the very front of every canonical filename and to apply it consistently across the PARA structure.

### Era 3 — v7.3 Strict Form: 01000–09000 (June 19, 2026)

The v7.3 Persistent Metadata Doctrine normalized the roots into a zero-padded strict five-digit form to remove ambiguity in sorting (preventing `10000` from sorting ahead of `2000`):

| Code  | Root Category       |
|-------|---------------------|
| 01000 | INBOX               |
| 02000 | PROJECTS            |
| 03000 | AREAS               |
| 04000 | RESOURCES           |
| 05000 | ARCHIVES            |
| 06000 | PRIVATE MEDIA       |
| 07000 | SYSTEM AUTOMATION   |
| 08000 | APPLICATION DATA    |
| 09000 | QUARANTINE          |

v7.3 stated that all governed directories and hierarchies use five digits, and that legacy 10000–90000 numbering may remain only as **temporary migration aliases**.

The **June 20, 2026** metadata reference then explicitly identified the former 10000–90000 structure as the prior ambiguous scheme, declared 01000–09000 strict five-digit codes to be the live v7.3 standard, and confirmed that the structure follows a hierarchical allocation logic — not a per-digit encoding scheme.

A convenience configuration from this era introduced `76000` for "SYSTEM DOCUMENTATION." This was taxonomy drift from the older 70000-style scheme and conflicted with the canonical 07000–07900 namespace. It was never adopted into the authoritative doctrine and must not be propagated.

### Era 4 — Current Canonical: Six-Digit [P][C][SS][NN] (June 30, 2026 — Present)

After v7.3 proved the five-digit scheme adequate for naming but insufficient for future expansion at leaf-node depth, the standard was extended to **six digits**. This is the **current and only canonical form**.

The five-digit roots expand directly:

| Five-Digit (v7.3) | Six-Digit (Current) | Root Category       |
|-------------------|---------------------|---------------------|
| 01000             | 010000              | INBOX               |
| 02000             | 020000              | PROJECTS            |
| 03000             | 030000              | AREAS               |
| 04000             | 040000              | RESOURCES           |
| 05000             | 050000              | ARCHIVES            |
| 06000             | 060000              | PRIVATE MEDIA       |
| 07000             | 070000              | SYSTEM AUTOMATION   |
| 08000             | 080000              | APPLICATION DATA    |
| 09000             | 090000              | QUARANTINE          |

The migration rule is simple: **append one zero** to any five-digit code to produce its six-digit equivalent.

---

## 2. The Six-Digit Standard — Current Canonical

The current PARA code is a **six-digit decimal string** structured as:

```
[P][C][SS][NN]
```

Where:

| Position | Label | Digits | Values    | Meaning |
|----------|-------|--------|-----------|---------|
| 1        | P     | 1      | 0         | Principal namespace — always `0` for the main SJL system |
| 2        | C     | 1      | 1–9       | Category root (the nine PARA categories) |
| 3–4      | SS    | 2      | 00–99     | Subcategory / major subdivision (up to 99 per root) |
| 5–6      | NN    | 2      | 00–99     | Node / leaf classification (up to 99 per subdivision) |

Total addressable leaf codes: 9 × 99 × 99 = **88,110** unique classifications.

### What [P][C][SS][NN] Is Not

- It is **not** a scheme where every digit carries an independent universal meaning.
- It is **not** a six-digit free-for-all where any combination is valid.
- It is a **hierarchical decimal namespace**. Trailing zeros indicate unoccupied lower levels.
- `010000` means INBOX root. `010100` means INBOX / first major subdivision. `010101` means INBOX / first major subdivision / first leaf.

### Allocation Hierarchy

| Pattern  | Level              | Example                        |
|----------|--------------------|-------------------------------|
| `0C0000` | Root               | `010000` INBOX                |
| `0CSS00` | Major subdivision  | `010100` INBOX / mobile       |
| `0CSSNN` | Leaf classification| `010101` INBOX / mobile / priority |

---

## 3. Root Namespace Chart

```
010000  INBOX               Active intake — files awaiting classification
020000  PROJECTS            Active work with a defined endpoint
030000  AREAS               Ongoing responsibilities, no end date
040000  RESOURCES           Reference material, consulted not produced
050000  ARCHIVES            Inactive, completed, deprecated
060000  PRIVATE MEDIA       Restricted personal media
070000  SYSTEM AUTOMATION   Infrastructure, scripts, agents, automation
080000  APPLICATION DATA    App state, databases, indices, registries
090000  QUARANTINE          Integrity failures, missing metadata, review holds
```

---

## 4. Digit-Position Reference

### Positional Interpretation

```
0  1  0  1  0  0
│  │  │  │  │  │
│  │  │  │  └──┴── NN: leaf node (00–99); 00 = subdivision root
│  │  └──┴──────── SS: major subdivision (00–99); 00 = category root
│  └────────────── C: category (1–9)
└───────────────── P: principal namespace (always 0 for SJL main system)
```

### Reading Examples

| Code   | P | C | SS | NN | Meaning |
|--------|---|---|----|----|---------|
| 010000 | 0 | 1 | 00 | 00 | INBOX root |
| 010100 | 0 | 1 | 01 | 00 | INBOX / mobile |
| 010200 | 0 | 1 | 02 | 00 | INBOX / scans |
| 010300 | 0 | 1 | 03 | 00 | INBOX / email |
| 020000 | 0 | 2 | 00 | 00 | PROJECTS root |
| 070000 | 0 | 7 | 00 | 00 | SYSTEM AUTOMATION root |
| 071000 | 0 | 7 | 10 | 00 | FileWarden |
| 071001 | 0 | 7 | 10 | 01 | FileWarden / routing rules |
| 072000 | 0 | 7 | 20 | 00 | Hook scripts |
| 073000 | 0 | 7 | 30 | 00 | Diff scripts |
| 074000 | 0 | 7 | 40 | 00 | Mirror Registry |
| 075000 | 0 | 7 | 50 | 00 | BookStack automation |
| 076000 | 0 | 7 | 60 | 00 | OCR and vision |
| 077000 | 0 | 7 | 70 | 00 | Device intake |
| 078000 | 0 | 7 | 80 | 00 | Migration |
| 079000 | 0 | 7 | 90 | 00 | Agent context |
| 090000 | 0 | 9 | 00 | 00 | QUARANTINE root |
| 091000 | 0 | 9 | 10 | 00 | Missing sidecar |
| 092000 | 0 | 9 | 20 | 00 | Hash mismatch |
| 093000 | 0 | 9 | 30 | 00 | Metadata conflict |
| 094000 | 0 | 9 | 40 | 00 | Mirror failure |
| 095000 | 0 | 9 | 50 | 00 | Version-chain error |

---

## 5. Canonical Filename Contract

### The Format

```
[PPPPPP]_YYYY-MM-DD__DOCID__semantic-title__vMAJOR-MINOR__sha8.ext
```

### Field Table

| Field | Format | Description | Example |
|-------|--------|-------------|---------|
| `[PPPPPP]` | Six-digit PARA code | Lifecycle classification — always first | `020000` |
| `YYYY-MM-DD` | ISO 8601 date | File creation date (not ingest date) | `2026-06-30` |
| `DOCID` | Permanent artifact ID | Assigned once, never changed | `sjl-doc-00417` |
| `semantic-title` | Lowercase hyphen-slug, ≤60 chars | Human-readable content description | `traefik-ssl-config` |
| `vMAJOR-MINOR` | Version: `v` + int + `-` + int | Content revision | `v1-0`, `v2-3` |
| `sha8` | First 8 hex chars of SHA-256 | Content-integrity fingerprint | `a3f9c2b1` |
| `.ext` | Lowercase file extension | Preserve original; lowercase always | `.pdf`, `.sh` |

**Field delimiters:** Double underscore `__` separates primary fields. Single hyphen `-` separates words within a field. Never use spaces. Never use single underscores within a field.

### Full Example

```
020000_2026-06-30__sjl-doc-00417__tagback-api-specification__v2-1__a3f9c2b1.pdf
│      │           │              │                           │     │
│      │           │              │                           │     └── SHA-256 first 8 chars
│      │           │              │                           └──────── version 2.1
│      │           │              └──────────────────────────────────── semantic description
│      │           └─────────────────────────────────────────────────── permanent DOCID
│      └─────────────────────────────────────────────────────────────── creation date
└────────────────────────────────────────────────────────────────────── PARA code: PROJECTS root
```

### More Examples

| Situation | Canonical Filename |
|-----------|-------------------|
| Active fellowship application | `020000_2026-03-15__sjl-doc-00203__fellowship-application-draft__v3-0__b4e7f1a9.pdf` |
| Server maintenance runbook | `030000_2026-05-01__sjl-doc-00118__nexus-traefik-restart-runbook__v1-2__c9d2e4f8.md` |
| Hazel rule template | `040000_2026-01-10__sjl-doc-00055__hazel-rule-base-template__v1-0__d1f5a7b3.sh` |
| Completed project archive | `050000_2025-12-31__sjl-doc-00389__tagback-v1-final-bundle__v1-0__e8c3b9a2.zip` |
| FileWarden routing config | `071000_2026-06-15__sjl-doc-00412__filewarden-routing-rules__v2-0__f7b4c1d6.yaml` |
| Quarantined hash-mismatch file | `092000_2026-06-29__sjl-doc-00501__unknown-origin-document__v1-0__a0b1c2d3.pdf` |

### Prohibited Patterns

| Pattern | Reason |
|---------|--------|
| Spaces in any field | Breaks shell parsing and S3 key handling |
| Single underscore as field delimiter | Double underscore `__` is the canonical separator |
| Uppercase in semantic-title | Inconsistent cross-filesystem sorting |
| Five-digit PARA code on new files | Current standard is six digits |
| Missing DOCID field | DOCID is mandatory; use a placeholder `sjl-doc-XXXXX` if pending assignment |
| Missing version field | `v1-0` is the correct initial version |
| Missing sha8 | Compute with `sha256sum <file> | cut -c1-8` |
| Extension in uppercase | Always lowercase |

---

## 6. Classification and Routing Workflow

### Step 1 — Determine Lifecycle State

Ask: **What is the primary relationship between this file and active work?**

| Answer | Category | Code Range |
|--------|----------|-----------|
| It just arrived and hasn't been processed | INBOX | `010000–019999` |
| It belongs to a bounded project with an endpoint | PROJECTS | `020000–029999` |
| It supports an ongoing responsibility | AREAS | `030000–039999` |
| It is reference material I look up but don't produce | RESOURCES | `040000–049999` |
| It belongs to something completed or retired | ARCHIVES | `050000–059999` |
| It is restricted personal media | PRIVATE MEDIA | `060000–069999` |
| It is automation infrastructure or system tooling | SYSTEM AUTOMATION | `070000–079999` |
| It is application state, index, database, or registry | APPLICATION DATA | `080000–089999` |
| It failed integrity checks or needs manual review | QUARANTINE | `090000–099999` |

### Step 2 — Resolve Subcategory

Consult the Master Allocation Registry (Section 11). Find the matching `0CSS00` code for the major subdivision within the root.

If no match exists: request a new allocation per Section 9 before proceeding. **Do not invent a code.**

### Step 3 — Assign or Retrieve DOCID

- If this file already has a DOCID (e.g., it is a new version of an existing artifact): **reuse the existing DOCID**. Never create a new DOCID for a new version of an existing document.
- If this is a genuinely new artifact: assign the next available DOCID from the DOCID registry (`080000` APPLICATION DATA / DOCID Registry).

### Step 4 — Compose the Filename

Assemble all fields per the canonical format. Compute the sha8 **after** finalizing content (sha8 changes with every content revision).

### Step 5 — Route

Route per the storage routing matrix in `05-DOCS/file-ingest-governance.md` §5.

---

## 7. Migration Rules

### Five-to-Six Digit Conversion

**Rule:** Append one zero to any five-digit v7.3 code to produce the six-digit equivalent.

```
ABCDE (five-digit) → ABCDE0 (six-digit)
```

Examples:
```
01000 → 010000
01100 → 011000
07100 → 071000
07900 → 079000
09000 → 090000
```

This rule is reversible: a six-digit code whose last digit is `0` is likely a direct migration from five digits.

### Legacy 10000–90000 Codes

The original 10000–90000 range is **transitional only**. Files using these codes are valid for reading but must not be created with them. When renaming legacy files:

```
10000 → 010000   INBOX
20000 → 020000   PROJECTS
30000 → 030000   AREAS
40000 → 040000   RESOURCES
50000 → 050000   ARCHIVES
60000 → 060000   PRIVATE MEDIA
70000 → 070000   SYSTEM AUTOMATION
80000 → 090000   QUARANTINE (80000 mapped to 090000; 80000 root retired)
90000 → (evaluate: exports/shares → RESOURCES or PROJECTS as appropriate)
```

### The 76000 Correction

`76000` appeared in a Scriptable configuration as "SYSTEM DOCUMENTATION." It is five digits, not six, and belongs to the older 70000-style scheme. It conflicts with the canonical 070000–079000 namespace.

- Do **not** propagate `76000` to new files.
- Do **not** interpret it as evidence that the system became six digits independently.
- System documentation lives within `070000` SYSTEM AUTOMATION. Under the current allocation, agent documentation is `079000` AGENT CONTEXT; general system documentation may use `079100` or a specifically allocated code from Section 11.
- When renaming a file tagged `76000`: convert to `076000` (PRIVATE MEDIA root) if the content is media, or to `079000` / `079100` if it is system documentation.

### No Bulk Renames Without Registry Resolution

Do not perform bulk renames of Google Drive files or any cloud-synced directory until:
1. The Master Allocation Registry (Section 11) is finalized for the affected namespace.
2. A migration mapping document is committed to the repo.
3. A change approval has been completed per Section 9.

---

## 8. Key Distinctions: PARA Code, DOCID, Version, Hash

These four components serve entirely different purposes. Do not conflate or encode one into another.

| Component | What It Is | Changes When | Example |
|-----------|-----------|-------------|---------|
| **PARA Code** | Lifecycle classification — where this file lives in the estate's organization | The file's lifecycle state changes (e.g., project completes → Archive) | `020000` |
| **DOCID** | Permanent artifact identity — the unique, stable name for this document across all versions | **Never.** Same DOCID across v1-0, v2-0, v3-0 | `sjl-doc-00417` |
| **Version** | Content revision counter | Every time the content changes and the file is saved as a new version | `v2-1` → `v2-2` |
| **sha8** | Content integrity fingerprint | Every time the bytes change (even minor edits) | `a3f9c2b1` |

### Why This Matters

A correctly named file at two different stages of its life:

```
# Initial draft (in PROJECTS):
020000_2026-01-15__sjl-doc-00417__tagback-api-spec__v1-0__d4c9a2f1.pdf

# After project completion (moved to ARCHIVES):
050000_2026-06-01__sjl-doc-00417__tagback-api-spec__v3-2__b8e1f7c3.pdf
```

- PARA code changed: `020000` → `050000` (lifecycle state changed)
- DOCID unchanged: `sjl-doc-00417` (same artifact)
- Version changed: `v1-0` → `v3-2` (content evolved)
- sha8 changed: reflects new content bytes

The PARA code tells you **where** the file is in its lifecycle. The DOCID tells you **what** it is across all time.

---

## 9. Governance and Change Control

### Who May Assign New Codes

Any code under an existing allocated subdivision (`0CSS00` already in the registry) may be used immediately. New subdivision or root-level allocations require:

1. Submit a change request: `bash 06-OPS/request-approval.sh "PARA Code Allocation" "Description"`
2. Assign a risk level (new leaf = Low; new subdivision = Medium; new root = High)
3. Get Shannon's approval in the generated `.md` file
4. Add the new code to Section 11 of this document
5. Commit with message referencing the approval file

### Rule: No Unregistered Codes on New Files

Any PARA code applied to a new file must already appear in the Master Allocation Registry (Section 11). An unregistered code on a committed file is a governance violation.

### PARA Code Immutability Within a Lifecycle State

Once a file is at a given lifecycle stage, its PARA code should not change unless the lifecycle state genuinely changes. Reclassification requires a re-route through the ingest pipeline, not a manual rename.

### Annual Review

This document is reviewed each January. Review scope:
- Verify all subcategory allocations are still in use
- Retire unused allocations with a `DEPRECATED` note (do not delete from this document)
- Evaluate whether new root-level categories are needed
- Update migration aliases table

---

## 10. LLM Handoff Instructions

When beginning a session involving file naming, classification, code assignment, or any operation governed by this standard, an LLM must:

1. **Read this document first.** Do not reconstruct the naming convention from memory or training data — this document is the authority.
2. **Never invent a PARA code.** All codes must come from Section 11. If a match is unclear, ask before assigning.
3. **Never re-derive the standard from prior chat history alone.** Prior chats may reference transitional or draft versions. This document supersedes all.
4. **Preserve the four-component distinction.** Never encode version information into DOCID. Never change DOCID between versions. Never use PARA code as a content descriptor.
5. **Flag conflicts.** If any existing file, script, or configuration uses a code that contradicts this document, surface the conflict rather than silently propagating the incorrect code.
6. **Do not bulk rename** any file collection without explicit approval per Section 9.

### Questions an LLM Must Resolve Before Assigning a New Code

Before assigning a PARA code to any file:

1. What is the **lifecycle state** of this file? (INBOX, active project, ongoing area, reference, archived, restricted, system, app data, quarantine)
2. Does an **existing subcategory** in Section 11 match? If yes, use it.
3. Is this a **new version** of an existing artifact (same DOCID) or a **genuinely new artifact** (new DOCID)?
4. Is the **semantic-title** sufficiently specific to identify the file without opening it?
5. Has the **sha8** been computed from the current file bytes?
6. Is the **version** correct, or does it need incrementing?
7. Is any piece of information being encoded into the wrong field?

---

## 11. Master Allocation Registry

### 010000 — INBOX

| Code   | Label              | Description |
|--------|--------------------|-------------|
| 010000 | INBOX root         | All intake — files awaiting classification |
| 010100 | Mobile intake      | Files arriving from phone / tablet |
| 010200 | Scans              | Paper scans and document captures |
| 010300 | Email intake       | Exported email attachments |
| 010400 | Browser downloads  | Files from web browsers |
| 010500 | Cloud pull         | Files pulled from cloud inboxes |
| 010900 | Failed intake      | Validation failures, awaiting manual triage |

### 020000 — PROJECTS

| Code   | Label            | Description |
|--------|------------------|-------------|
| 020000 | PROJECTS root    | All active bounded work |
| 020100 | TagBack          | TagBack app development |
| 020200 | Fellowship       | Grant and fellowship applications |
| 020300 | Portfolio        | Portfolio site and personal brand |
| 020400 | Infrastructure   | One-off infra build-out projects |
| 020500 | Cloud migration  | Cloud consolidation work |
| 020600 | Client work      | Client project deliverables |
| 020900 | Personal         | Bounded personal goal projects |

### 030000 — AREAS

| Code   | Label            | Description |
|--------|------------------|-------------|
| 030000 | AREAS root       | All ongoing responsibilities |
| 030100 | Server ops       | Nexus and sOs maintenance |
| 030200 | Cloud accounts   | Cloud account management |
| 030300 | Photography      | Photography work and delivery |
| 030400 | Finance          | Personal finances |
| 030500 | Health           | Health and wellness records |
| 030600 | Legal            | Legal documents and agreements |
| 030700 | Identity         | Identity documents (non-secret) |
| 030800 | Network          | Tailscale, WireGuard, mesh maintenance |

### 040000 — RESOURCES

| Code   | Label            | Description |
|--------|------------------|-------------|
| 040000 | RESOURCES root   | Reference material |
| 040100 | Templates        | Reusable file and doc templates |
| 040200 | Scripts          | Utility shell and automation scripts |
| 040300 | Configs          | Baseline and example configuration files |
| 040400 | Documentation    | Technical docs, API references, vendor docs |
| 040500 | Media assets     | Stock photos, icons, reusable audio |
| 040600 | Training         | Learning materials and course notes |
| 040700 | Bookmarks        | Hookmark and URL archives |
| 040800 | Tools            | Software installers and utilities |

### 050000 — ARCHIVES

| Code   | Label               | Description |
|--------|---------------------|-------------|
| 050000 | ARCHIVES root       | Inactive, completed, deprecated |
| 050100 | Completed projects  | Final project deliverables |
| 050200 | Retired areas       | Closed accounts, past roles |
| 050300 | Deprecated resources| Old templates, superseded configs |
| 050400 | Archived media      | Past-delivered photos, old reels |
| 050500 | Correspondence      | Past email and message archives |
| 050600 | Finance archive     | Financial records older than 3 years |

### 060000 — PRIVATE MEDIA

| Code   | Label               | Description |
|--------|---------------------|-------------|
| 060000 | PRIVATE MEDIA root  | Restricted personal media |
| 060100 | Personal photos     | Private personal photography |
| 060200 | Personal video      | Private personal video |
| 060300 | Identity media      | ID scans, passport photos |

### 070000 — SYSTEM AUTOMATION

| Code   | Label                | Description |
|--------|----------------------|-------------|
| 070000 | SYSTEM AUTOMATION root | All automation infrastructure |
| 071000 | FileWarden           | Routing rules, warden configs |
| 072000 | Hook scripts         | Hookmark and event hook scripts |
| 073000 | Diff scripts         | File comparison and diff tools |
| 074000 | Mirror Registry      | Mirror sync state and registry |
| 075000 | BookStack automation | BookStack export and automation |
| 076000 | OCR and vision       | OCR pipelines, vision processing |
| 077000 | Device intake        | Device-specific ingest automation |
| 078000 | Migration            | Migration scripts and mappings |
| 079000 | Agent context        | LLM agent context and handoff docs |
| 079100 | System documentation | Governance docs, naming standards (this doc) |

### 080000 — APPLICATION DATA

| Code   | Label               | Description |
|--------|---------------------|-------------|
| 080000 | APPLICATION DATA root | App state and persistent data |
| 080100 | DOCID Registry      | Permanent artifact identity registry |
| 080200 | Ingest logs         | Daily ingest audit logs |
| 080300 | Indices             | Search and content indices |
| 080400 | Databases           | Application databases |
| 080500 | Mirror state        | Mirror sync state snapshots |

### 090000 — QUARANTINE

| Code   | Label                | Description |
|--------|----------------------|-------------|
| 090000 | QUARANTINE root      | All integrity failures and review holds |
| 091000 | Missing sidecar      | File lacks required `.meta.json` |
| 092000 | Hash mismatch        | Checksum does not match registered value |
| 093000 | Metadata conflict    | Conflicting PARA codes or DOCIDs |
| 094000 | Mirror failure       | Mirror sync failed for this artifact |
| 095000 | Version-chain error  | Version sequence broken or duplicated |
| 096000 | Unclassified intake  | Held in INBOX > 24h without classification |

---

## Appendix A — Five-to-Six Digit Migration Table

| Five-Digit | Six-Digit | Root Label |
|-----------|-----------|------------|
| 01000 | 010000 | INBOX |
| 01100 | 010100 | INBOX / mobile |
| 01200 | 010200 | INBOX / scans |
| 01300 | 010300 | INBOX / email |
| 02000 | 020000 | PROJECTS |
| 03000 | 030000 | AREAS |
| 04000 | 040000 | RESOURCES |
| 05000 | 050000 | ARCHIVES |
| 06000 | 060000 | PRIVATE MEDIA |
| 07000 | 070000 | SYSTEM AUTOMATION |
| 07100 | 071000 | FileWarden |
| 07200 | 072000 | Hook scripts |
| 07300 | 073000 | Diff scripts |
| 07400 | 074000 | Mirror Registry |
| 07500 | 075000 | BookStack automation |
| 07600 | 076000 | OCR and vision |
| 07700 | 077000 | Device intake |
| 07800 | 078000 | Migration |
| 07900 | 079000 | Agent context |
| 08000 | 080000 | APPLICATION DATA |
| 09000 | 090000 | QUARANTINE |
| 09100 | 091000 | Missing sidecar |
| 09200 | 092000 | Hash mismatch |
| 09300 | 093000 | Metadata conflict |
| 09400 | 094000 | Mirror failure |
| 09500 | 095000 | Version-chain error |

**Legacy 10000–90000 to current:**

| Legacy | Current Six-Digit | Notes |
|--------|------------------|-------|
| 10000 | 010000 | INBOX |
| 20000 | 020000 | PROJECTS |
| 30000 | 030000 | AREAS |
| 40000 | 040000 | RESOURCES |
| 50000 | 050000 | ARCHIVES |
| 60000 | 060000 | PRIVATE MEDIA |
| 70000 | 070000 | SYSTEM AUTOMATION |
| 76000 | 079100 | System documentation (taxonomy drift — see §7) |
| 80000 | 090000 | QUARANTINE (80000 root retired) |
| 90000 | 040000 or 020000 | Exports/Shares → evaluate as RESOURCES or PROJECTS |

---

## Appendix B — LLM Pre-Assignment Checklist

Before assigning any PARA code or composing any canonical filename, verify:

- [ ] I have read Section 2 (six-digit standard) and understand [P][C][SS][NN]
- [ ] I have looked up the code in Section 11 (Master Allocation Registry) — not invented it
- [ ] I know whether this is a new artifact (new DOCID) or a new version of an existing one (same DOCID)
- [ ] The semantic-title is lowercase, hyphen-separated, ≤60 chars, and content-specific
- [ ] The version field reflects the correct revision number
- [ ] The sha8 is computed from the actual file bytes (not a placeholder)
- [ ] No field contains information that belongs in a different field
- [ ] If I need a code not in Section 11, I have flagged it rather than invented one
- [ ] I have not confused five-digit (legacy) with six-digit (current) codes
- [ ] I have not placed the date, version, or hash into the PARA code field

---

*This document is version-controlled in the Hybrid Personal Cloud Server Infrastructure repository.*  
*For changes: see `06-OPS/request-approval.sh` and commit to a feature branch.*  
*Change log: `git log 00-MASTER-ARCHITECTURE/sjl-para-naming-master.md`*
