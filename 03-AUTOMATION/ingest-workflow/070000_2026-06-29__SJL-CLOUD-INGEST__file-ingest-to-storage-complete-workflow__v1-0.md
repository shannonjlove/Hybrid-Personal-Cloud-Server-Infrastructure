# SJL SOVEREIGN CLOUD — FILE INGEST WORKFLOW
## Complete End-to-End: From File Drop to Governed Storage

| Field | Value |
|---|---|
| DOCID | SJL-CLOUD-INGEST-001 |
| Version | v1-0 |
| Date | 2026-06-29 |
| PARA | 070000_SYSTEM-AUTOMATION |
| Status | Specification — FileWarden not yet implemented |

> This document specifies every program, service, and action involved in the journey of a file from any intake method to governed, mirrored, registered, and published storage. It maps WHICH PROGRAM does WHAT at each stage.

---

## STAGE 0 — FILE INTAKE

### 0.1 Intake Methods

| Method | Actor | Destination | How |
|---|---|---|---|
| iOS Share Sheet | User (NeoServer / Files app) | `/srv/sjl/010000_INBOX/` | SFTP via Tailscale (ssh sjl@100.115.66.75) |
| macOS drop | User | `/srv/sjl/010000_INBOX/` | SFTP or WebDAV over Tailscale |
| PaperParrot UI upload | User → Browser | `/srv/sjl/010000_INBOX/010300_PAPERLESS-CONSUME/` | PaperParrot web interface |
| n8n workflow | **n8n** (sjl-n8n container) | `/srv/sjl/010000_INBOX/` | n8n Write File node or wget/curl node |
| Email attachment | **n8n** + email receiver | `/srv/sjl/010000_INBOX/` | n8n Email Trigger → save attachment |
| FetchWarden (planned) | FetchWarden daemon (742000) | `/srv/sjl/010000_INBOX/` via FileWarden Bridge | FetchWarden API → CloudWarden → local staging |
| API direct upload | External client | PaperParrot `/api/documents/post_document/` | HTTP POST with Authorization token |
| Git commit | Claude Code / operator | `/srv/sjl/070000_SYSTEM-AUTOMATION/` | git push → GitOps trigger |

### 0.2 PaperParrot Direct Path (Consume Dir)

When a file lands in `/srv/sjl/010000_INBOX/010300_PAPERLESS-CONSUME/`:

**Program:** `sjl-paperparrot` container (paperlessngx/paperless-ngx)
**Action:** Paperless-NGX monitors the bind-mounted consume directory (`/usr/src/paperless/consume`) via inotify.

```
File appears in consume dir
    ↓
Paperless-NGX consumer service (internal to container)
    ↓
OCR via Tesseract (built into paperless-ngx image)
    ↓
Tag inference via ML classifier (built-in)
    ↓
Stored in /opt/paperless/media/ (bind mount → Nexus disk)
    ↓
Indexed in PostgreSQL (sjl-paperparrot-db container)
    ↓
Available in PaperParrot web UI at https://paperless.shannonjlove.cloud
```

**Note:** Files consumed directly via PaperParrot skip the FileWarden pipeline. They should still have FileWarden process them via the FileWarden → PaperParrot integration once FileWarden is implemented.

### 0.3 Mac-Side Preprocessing (runs on `shannonjlove` Mac before SFTP upload)

Files arriving from the Mac may carry corrupt dates, stripped EXIF (WhatsApp, social media), or a quarantine xattr. This preprocessing layer runs on the Mac before SFTP — it is NOT a Nexus operation.

**Tools required on Mac:**
- `exiftool` — `brew install exiftool`
- `tag` (jdberry/tag) — `brew install tag`
- `mdls` — built into macOS

#### 0.3a — Strip quarantine xattr (post-download / post-AirDrop)
```bash
# After FetchWarden or AirDrop delivery, clear quarantine flag:
xattr -d com.apple.quarantine /path/to/file

# Bulk clear on a directory:
xattr -dr com.apple.quarantine /srv/sjl/010000_INBOX/
```
**Why:** macOS Gatekeeper adds `com.apple.quarantine` to downloaded files, causing dialogs on open. Clear after integrity verification, never before.

#### 0.3b — ExifTool date recovery (sentinel detection)
Run before SFTP upload. Fixes corrupt/stripped dates so FileWarden ANALYZE gets correct `captured_at`.

```bash
# Check for sentinel dates (WhatsApp/social-media-stripped, Unix-epoch-corrupt):
exiftool -q -if '$DateTimeOriginal =~ /^(1970|1999)/' -filename -DateTimeOriginal /path/

# For images: recover FileModifyDate from DateTimeOriginal (if valid):
exiftool '-FileModifyDate<DateTimeOriginal' /path/to/file.jpg

# For videos with corrupt creation date (1970-01-01): recover from TrackCreateDate:
exiftool '-FileModifyDate<TrackCreateDate' '-FileName<TrackCreateDate' \
  -d %Y-%m-%d_%H.%M.%S.%%e /path/to/video.mov

# Batch: recover all images in a folder from DateTimeOriginal:
exiftool -r '-FileModifyDate<DateTimeOriginal' /srv/sjl/010000_INBOX/
```

#### 0.3c — Pre-tag with PARA codes (Finder tags)
Apply PARA Finder tags on Mac using `mdls` + `xattr` (read-modify-write). This survives SFTP if metadata is preserved; FileWarden also re-applies on Nexus in Stage 8.

```bash
# Read existing tags (safe — uses mdls, not xattr hex dump):
mdls -raw -name kMDItemUserTags /path/to/file

# Write PARA Finder tag (plist XML format — overwrites all tags):
xattr -w com.apple.metadata:_kMDItemUserTags \
  '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><array><string>sjl-para-070000</string></array></plist>' \
  /path/to/file

# Add tag WITHOUT destroying existing tags (read-modify-write via `tag` CLI):
tag --add sjl-para-070000 /path/to/file

# Preferred one-liner using jdberry/tag:
tag --add "sjl-para-${PARA_CODE}" /path/to/file
```

**Note on xattr transport:** Standard `scp`/`sftp` do NOT preserve macOS xattrs. Tags and quarantine flags are stripped in transit. The Mac-side preprocessing (especially ExifTool date recovery into FileModifyDate) is what survives the SFTP transfer. xattr data on Nexus is re-written by FileWarden Stage 8 using Linux `user.*` namespace.

---

## STAGE 1 — DISCOVER

**Program:** FileWarden daemon (Python service, port TBD, not yet implemented)
**Mechanism:** `inotify_simple` Python library watching approved roots via kernel inotify/fanotify API

```python
# FileWarden internal
import inotify_simple
watcher = inotify_simple.INotify()
for root in APPROVED_WATCH_ROOTS:
    watcher.add_watch(root, inotify_simple.flags.CLOSE_WRITE | inotify_simple.flags.MOVED_TO)
```

**Approved watch roots:**
```
/srv/sjl/010000_INBOX/
/srv/sjl/020000_PROJECTS/
/srv/sjl/030000_AREAS/
/srv/sjl/040000_RESOURCES/
/srv/sjl/060000_PRIVATE-MEDIA/
```

**Excluded paths (never watched):**
```
/proc  /sys  /dev  /tmp  /run  /var/run
.git/  node_modules/  .sidecars/  __pycache__/
/etc/containers/systemd/
/opt/secrets/
```

**Output:** Raw event with file path → passed to STABILIZE stage.

---

## STAGE 2 — STABILIZE

**Program:** FileWarden daemon
**Why this exists:** Files written in chunks (large uploads, streaming writes) would trigger inotify before the write is complete. Stabilize waits for the file to stop changing.

```python
# FileWarden internal — write quiescence check
def stabilize(path, poll_interval=0.5, stable_duration=2.0):
    last_size = -1
    last_mtime = -1
    stable_count = 0
    while stable_count < int(stable_duration / poll_interval):
        stat = os.stat(path)
        if stat.st_size == last_size and stat.st_mtime == last_mtime:
            stable_count += 1
        else:
            stable_count = 0
            last_size, last_mtime = stat.st_size, stat.st_mtime
        time.sleep(poll_interval)
    return path
```

**On failure:** Retry with exponential backoff (2s, 4s, 8s, 16s). If file disappears → log and discard event.

---

## STAGE 3 — IDENTIFY

**Program:** FileWarden daemon
**Two sub-functions:**

### 3a. calculate_hash(path) → sha256_hex
```python
import hashlib

def calculate_hash(path: str) -> str:
    sha256 = hashlib.sha256()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(65536), b''):
            sha256.update(chunk)
    return sha256.hexdigest()
```

**On failure:** Route to `090000_QUARANTINE/`. Log full error.

### 3b. assign_docid(path, existing_sidecar) → docid

```python
def assign_docid(path: str, existing_sidecar: dict | None) -> str:
    # Check for existing DOCID in existing sidecar (re-processing known file)
    if existing_sidecar and 'docid' in existing_sidecar:
        return existing_sidecar['docid']
    
    # Check xattr (local acceleration layer)
    try:
        return xattr.getxattr(path, 'user.sjl.docid').decode()
    except OSError:
        pass
    
    # Check canonical filename pattern
    match = re.match(r'\d{6}_\d{4}-\d{2}-\d{2}__([A-Z0-9-]+)__', os.path.basename(path))
    if match:
        return match.group(1)
    
    # New file — allocate from Mirror Registry sequence
    return mirror_registry.next_docid()   # → "SJL-CLOUD-NNNN"
```

**Output:** SHA256 hex string + DOCID string (e.g., `SJL-CLOUD-0042`)

---

## STAGE 4 — ANALYZE

**Program:** FileWarden daemon (orchestrator) + specialized workers

### 4a. extract_metadata(path) → dict
**Program:** FileWarden daemon
**Library:** `python-magic` (MIME detection), `mutagen` (audio), `pypdf` (PDF), `python-docx` (DOCX), `PIL/Pillow` (images), `exiftool` (subprocess)

```python
def extract_metadata(path: str) -> dict:
    mime = magic.from_file(path, mime=True)
    meta = {
        'mime_type': mime,
        'file_size': os.path.getsize(path),
        'created_at': datetime.fromtimestamp(os.stat(path).st_ctime, tz=timezone.utc).isoformat(),
        'modified_at': datetime.fromtimestamp(os.stat(path).st_mtime, tz=timezone.utc).isoformat(),
    }
    # MIME-specific extraction follows...
    return meta
```

### 4b. run_ocr(path) → {status, text, confidence}
**Program:** OCR worker (sOs ARM64 — `sjl-ocr-vision-worker` container)
**Method:** FileWarden queues OCR job via n8n → n8n dispatches to sOs n8n-worker → ocr-vision-worker executes

```
FileWarden → HTTP POST to n8n webhook
    ↓ (via Tailscale)
sOs: n8n worker receives job
    ↓
sOs: sjl-ocr-vision-worker (Tesseract + pytesseract + pdf2image)
    ↓ OCR text + confidence score
Return to FileWarden via n8n callback
```

**Tools used:**
- `pdf2image` (convert PDF pages to images)
- `pytesseract` + `tesseract-ocr` (OCR engine, ARM64 native)
- Confidence threshold: < 0.5 → route to 010000_INBOX for manual review

### 4c. run_vision(path) → {status, objects, nsfw_score}
**Program:** OCR/Vision worker (sOs ARM64)
**Method:** Same queue path as OCR

```
FileWarden → n8n → sOs ocr-vision-worker
    ↓
Vision inference (NSFW detection + object detection)
NSFW score 0.0–1.0
    ↓ if nsfw_score > 0.7 → ServicePrimary = stash (private routing)
Return to FileWarden
```

**PARA classification from analysis:**
- OCR text contains financial terms → likely 020000_PROJECTS or 040000_RESOURCES
- Vision detects "personal photo" → likely 060000_PRIVATE-MEDIA
- NSFW > 0.7 → 060000_PRIVATE-MEDIA, ServicePrimary=stash
- Classification confidence < threshold → 090000_QUARANTINE

### 4d. extract_captured_at(path, mime_type) → captured_at dict
**Program:** FileWarden daemon via `exiftool` subprocess
**Why this exists:** Cloud services, messaging apps (WhatsApp), and iOS photo editors strip or corrupt EXIF dates. FileWarden must derive the best available `captured_at` from a priority chain rather than trusting filesystem timestamps.

**Date sentinel table** (dates that indicate corruption/stripping — reject as `captured_at`):

| Sentinel date | Cause |
|---|---|
| `1970-01-01` | Unix epoch — video container corruption (Everpix, Loom) |
| `1999-11-30` | WhatsApp EXIF strip default |
| `2001-01-01` | iOS creation timestamp reset |
| Any pre-`1990-01-01` in modern media | Indicates corruption unless archival scan |

**Priority chain by MIME type:**

| Priority | Image (image/*) | Video (video/*) |
|---|---|---|
| 1 (best) | `EXIF:DateTimeOriginal` | `QuickTime:DateTimeOriginal` |
| 2 | `EXIF:CreateDate` | `QuickTime:CreateDate` |
| 3 | `XMP:DateCreated` | `QuickTime:TrackCreateDate` ← survives many corruptions |
| 4 | `IPTC:DateCreated` | `QuickTime:TrackModifyDate` |
| 5 | `GPS:GPSDateTime` | `XMP:DateCreated` |
| 6 (last resort) | `File:FileModifyDate` | `File:FileModifyDate` |
| — (reject) | Sentinel date → `captured_at = null`, `exif_stripped = true` | Same |

```python
EXIF_DATE_PRIORITY_IMAGE = [
    'EXIF:DateTimeOriginal',
    'EXIF:CreateDate',
    'XMP:DateCreated',
    'IPTC:DateCreated',
    'Composite:GPSDateTime',
    'File:FileModifyDate',  # last resort only
]

EXIF_DATE_PRIORITY_VIDEO = [
    'QuickTime:DateTimeOriginal',
    'QuickTime:CreateDate',
    'QuickTime:TrackCreateDate',   # often survives when container is corrupt
    'QuickTime:TrackModifyDate',
    'XMP:DateCreated',
    'File:FileModifyDate',
]

DATE_SENTINELS = ['1970-01-01', '1999-11-30', '2001-01-01']

def extract_captured_at(path: str, mime_type: str) -> dict:
    result = subprocess.run(
        ['exiftool', '-json', '-a', '-G', '-d', '%Y-%m-%dT%H:%M:%S%z', path],
        capture_output=True, text=True, timeout=30
    )
    if result.returncode != 0:
        return {'captured_at': None, 'captured_at_source': None, 'exif_stripped': True}
    
    tags = json.loads(result.stdout)[0] if result.stdout.strip() else {}
    
    priority = EXIF_DATE_PRIORITY_IMAGE if mime_type.startswith('image/') else EXIF_DATE_PRIORITY_VIDEO
    
    for key in priority:
        val = tags.get(key)
        if not val:
            continue
        if any(sentinel in val for sentinel in DATE_SENTINELS):
            continue  # reject sentinel date
        return {
            'captured_at': val,
            'captured_at_source': key,
            'exif_stripped': False,
        }
    
    # No valid date found — route to quarantine for manual date entry
    return {'captured_at': None, 'captured_at_source': None, 'exif_stripped': True}
```

**On `exif_stripped = True`:**
- Source is likely WhatsApp, Twitter/X, iMessage photo edit, or corrupted archive app
- Record `exif_stripped: true` in sidecar JSON
- Route to `090000_QUARANTINE/` with reason `exif_stripped` for manual `captured_at` assignment
- Preserve the `kMDItemWhereFroms` xattr if present (contains origin URL/service name)

**ExifTool batch repair command (operator tool — not automated):**
```bash
# Recover all images in a directory from DateTimeOriginal:
exiftool -r '-FileModifyDate<DateTimeOriginal' /srv/sjl/010000_INBOX/

# Recover videos from TrackCreateDate when container date is 1970:
exiftool -r -if '$CreateDate =~ /^1970/' \
  '-CreateDate<TrackCreateDate' '-ModifyDate<TrackCreateDate' \
  /srv/sjl/010000_INBOX/

# View all date tags for a single file (diagnosis):
exiftool -a -G -time:all /path/to/file
```

---

## STAGE 5 — VERSION

**Program:** FileWarden daemon
**Dependency:** Mirror Registry (PostgreSQL, port not yet assigned) for version history

```python
def increment_version(old_sha256: str, new_sha256: str, change_type: str) -> str:
    current = mirror_registry.get_current_version(docid)  # e.g., "v1-2"
    major, minor = current.lstrip('v').split('-')
    
    if change_type == 'no-change':
        return current  # no bump
    elif change_type in ('metadata', 'tag-cleanup', 'typo', 'formatting'):
        return f"v{major}-{int(minor)+1}"  # PATCH
    elif change_type == 'content-update':
        return f"v{int(major)+1}-0"  # MINOR (resets minor)
    elif change_type == 'new-workflow':
        return f"v{int(major)+1}-0"  # MAJOR
    else:
        # change_type == 'unexpected-drift'
        mirror_registry.flag_drift(docid)
        raise DriftException(f"SHA changed without approved event: {docid}")
```

**Drift → Quarantine:** If SHA-256 changed without a registered approved event, the file is quarantined. An operator must review and either:
1. Approve the change (creates approved-event record, unquarantines)
2. Restore from Mirror Registry backup

---

## STAGE 6 — DIFF

**Program:** DiffForge service (FastAPI, port 8087, not yet implemented)
**Called by:** FileWarden daemon via HTTP POST

```
FileWarden → POST http://127.0.0.1:8087/diff
    Body: { docid, from_path, to_path, from_sha256, to_sha256, mime_type }
    ↓
DiffForge selects diff method by MIME:
  text/*          → Python difflib unified diff
  application/pdf → pdf2image → pytesseract → difflib
  .docx           → python-docx paragraph extraction → difflib
  image/*         → PIL perceptual hash + pixel diff overlay
  audio/* video/* → frame hash / waveform comparison
  binary          → binwalk byte diff
    ↓
diff_record stored → .sidecars/DOCID/diffs/vA-B_to_vC-D.diff
    ↓
Returns: { diff_path, summary, generated_at }
```

**Non-fatal:** If DiffForge is unreachable or fails, FileWarden logs the error and continues to next stage. Diff is generated asynchronously if needed.

---

## STAGE 7 — RENAME

**Program:** FileWarden daemon
**Action:** Rename file to canonical convention in-place (same directory, or to target PARA directory)

```python
def build_canonical_name(docid, para_code, date, semantic_title, version, sha8, ext) -> str:
    title_clean = re.sub(r'[^a-z0-9-]', '-', semantic_title.lower())
    title_clean = re.sub(r'-+', '-', title_clean).strip('-')
    return f"{para_code}_{date}__{docid}__{title_clean}__{version}__{sha8}{ext}"

# Example output:
# 040000_2026-06-29__SJL-CLOUD-0042__annual-budget-review__v1-0__a1b2c3d4.pdf
```

**Collision handling:** If canonical name already exists:
- Check if same DOCID → same file, skip rename
- Different DOCID → route to 090000_QUARANTINE (never overwrite)

**Semantic title derivation priority:**
1. User-provided via metadata API
2. OCR extracted title
3. Vision inference
4. Original filename (cleaned)
5. DOCID placeholder

---

## STAGE 8 — SIDECAR (FATAL)

**Program:** FileWarden daemon
**This stage is FATAL — if it fails, the entire transaction aborts.**

Three parallel writes must ALL succeed:

### 8a. Write sidecar JSON
```python
sidecar_dir = Path(f'.sidecars/{docid}')
sidecar_dir.mkdir(parents=True, exist_ok=True)
sidecar_path = sidecar_dir / 'provenance.json'

record = {
    'docid': docid,
    'para_code': para_code,
    'canonical_path': str(canonical_path),
    'sha256': sha256_hex,
    'sha8': sha256_hex[:8],
    'version': version_string,
    'mime_type': mime_type,
    'ocr_status': ocr_result['status'],
    'ocr_text_path': str(sidecar_dir / 'ocr.txt'),
    'vision_path': str(sidecar_dir / 'vision.json'),
    'nsfw_score': vision_result.get('nsfw_score', 0.0),
    'origin_device': metadata.get('origin_device', 'unknown'),
    'intake_method': metadata.get('intake_method', 'unknown'),
    'captured_at': metadata.get('captured_at'),           # best date from EXIF chain
    'captured_at_source': metadata.get('captured_at_source'),  # which EXIF tag won
    'exif_stripped': metadata.get('exif_stripped', False), # True = WhatsApp/social stripped
    'governed_at': datetime.now(timezone.utc).isoformat(),
    'mirror_manifest_path': str(sidecar_dir / 'mirror-manifest.json'),
}
sidecar_path.write_text(json.dumps(record, indent=2))
```

### 8b. Write xattr (local acceleration)
```python
import xattr
xattr.setxattr(canonical_path, 'user.sjl.docid', docid.encode())
xattr.setxattr(canonical_path, 'user.sjl.para', para_code.encode())
xattr.setxattr(canonical_path, 'user.sjl.version', version_string.encode())
xattr.setxattr(canonical_path, 'user.sjl.sha256', sha256_hex.encode())
```

### 8c. Embed XMP-sjl (if format supports it)
**Tool:** `exiftool` (subprocess call) for PDFs, images
**Tool:** `python-docx` for DOCX custom properties

```bash
# FileWarden calls exiftool for supported formats:
exiftool \
  -XMP-sjl:DocId="${DOCID}" \
  -XMP-sjl:ParaCode="${PARA_CODE}" \
  -XMP-sjl:Version="${VERSION}" \
  -XMP-sjl:Sha256="${SHA256}" \
  "${CANONICAL_PATH}"
```

### 8d. Enrich standard metadata xattrs (Linux — non-fatal)
**Program:** FileWarden daemon via `xattr` lib + `exiftool` subprocess
**Platform:** Nexus (Linux — `user.*` namespace, NOT `com.apple.*`)
**Non-fatal:** Failures here are logged but do not abort the transaction.

These xattrs make file provenance readable by any `xattr`-aware tool on the Linux side:

```python
# Standard Linux xattrs for provenance (user.* namespace on Linux):
xattr.setxattr(canonical_path, 'user.sjl.docid',    docid.encode())
xattr.setxattr(canonical_path, 'user.sjl.para',     para_code.encode())
xattr.setxattr(canonical_path, 'user.sjl.version',  version_string.encode())
xattr.setxattr(canonical_path, 'user.sjl.sha256',   sha256_hex.encode())
xattr.setxattr(canonical_path, 'user.sjl.captured_at', captured_at.encode() if captured_at else b'unknown')
xattr.setxattr(canonical_path, 'user.sjl.exif_stripped', b'true' if exif_stripped else b'false')

# If provenance URL known (FetchWarden, download source):
if origin_url:
    xattr.setxattr(canonical_path, 'user.sjl.origin_url', origin_url.encode())
```

**macOS xattr enrichment (cross-reference — NOT run on Nexus):**
When a file is served back to Mac (via SFTP, Finder mount, or direct copy), the Mac-side post-receive script applies:

```bash
# On Mac, after receiving file from Nexus:

# Write DOCID to kMDItemDescription (appears in Finder "Get Info"):
xattr -w com.apple.metadata:kMDItemDescription \
  "${DOCID} | ${PARA_CODE} | ${VERSION}" \
  /path/to/file

# Write PARA code as Finder tag (using jdberry/tag for safe read-modify-write):
tag --add "sjl-para-${PARA_CODE}" /path/to/file

# Preserve WhereFroms if origin URL available (Spotlight-searchable):
python3 -c "
import plistlib, subprocess
plist = plistlib.dumps(['${ORIGIN_URL}', '${FETCH_REFERRER}'], fmt=plistlib.FMT_XML)
subprocess.run(['xattr', '-w', 'com.apple.metadata:kMDItemWhereFroms', plist.decode(), '/path/to/file'])
"
```

**Key macOS xattr reference** (from Eclectic Light Company — read with `mdls` or `xattr -l`):

| xattr key | Purpose | FileWarden use |
|---|---|---|
| `com.apple.metadata:_kMDItemUserTags` | Finder tags (plist array) | PARA code tags |
| `com.apple.metadata:kMDItemDescription` | Arbitrary text (Finder Get Info) | DOCID + PARA + version |
| `com.apple.metadata:kMDItemWhereFroms` | Download origin URLs (plist array) | FetchWarden provenance |
| `com.apple.metadata:kMDItemDownloadedDate` | Download timestamp | FetchWarden acquisition date |
| `com.apple.metadata:kMDItemCreator` | App that created file | FileWarden tag |
| `com.apple.quarantine` | Gatekeeper quarantine flag | Clear after verification (Stage 0.3a) |

**Reading tags safely on Mac (use mdls, not xattr hex):**
```bash
# CORRECT — readable output:
mdls -raw -name kMDItemUserTags /path/to/file

# AVOID — binary plist hex dump:
xattr -px com.apple.metadata:_kMDItemUserTags /path/to/file
```

**On any write failure in 8a, 8b, or 8c:** Transaction aborts. File is moved back to pre-rename location. Error written to audit log. Operator alert via n8n.

---

## STAGE 9 — HOOK

**Program:** FileWarden daemon → HookVault CLI (`sjl-hook`)
**Port:** 8086 (not yet implemented)

```bash
# Called by FileWarden after successful sidecar:
sjl-hook register \
  --docid "${DOCID}" \
  --path "${CANONICAL_PATH}" \
  --service filewarden \
  --url "file://${CANONICAL_PATH}"
```

**Non-fatal:** If HookVault is unreachable, FileWarden:
1. Writes hook registration to a local retry queue
2. Logs the failure
3. Continues to MIRROR stage
4. A background retry worker attempts hook registration every 60s until success

---

## STAGE 10 — MIRROR

**Program:** `rclone` (command-line, called by FileWarden daemon)
**Purpose:** Copy canonical file + sidecar bundle to iDrive E2 primary storage. Verify remote checksum.

```bash
# FileWarden calls rclone:
rclone copy "${CANONICAL_PATH}" "idrive-e2:sjl-${PARA_CODE}/${DOCID}/"
rclone copy "${SIDECAR_DIR}/" "idrive-e2:sjl-${PARA_CODE}/${DOCID}/.sidecars/"

# Verify remote checksum (must match local SHA-256):
REMOTE_SHA256=$(rclone hashsum SHA-256 "idrive-e2:sjl-${PARA_CODE}/${DOCID}/${CANONICAL_FILENAME}" | awk '{print $1}')
if [ "${REMOTE_SHA256}" != "${LOCAL_SHA256}" ]; then
    echo "MIRROR CHECKSUM MISMATCH — aborting"
    exit 1
fi
```

**Mirror manifest written:**
```json
{
  "docid": "SJL-CLOUD-NNNN",
  "mirror_uri": "s3://idrive-e2/sjl-070000/SJL-CLOUD-NNNN/",
  "remote_sha256": "...",
  "local_sha256": "...",
  "verified_at": "2026-06-29T12:00:00Z",
  "rclone_remote": "idrive-e2",
  "status": "verified"
}
```

**Stage is complete only when both of these are true:**
1. `rclone copy` returns exit code 0
2. Remote SHA-256 checksum matches local SHA-256

---

## STAGE 11 — REGISTER (FATAL)

**Program:** FileWarden daemon → Mirror Registry (PostgreSQL on Nexus)
**This stage is FATAL — if it fails, the entire transaction aborts.**

Mirror Registry is the authoritative system of record. Every governed file must have a row here.

```python
def update_registry(docid: str, transaction_record: dict) -> bool:
    conn = psycopg2.connect(MIRROR_REGISTRY_DSN)
    cur = conn.cursor()
    cur.execute("""
        INSERT INTO logical_files (
            docid, para_code, canonical_path, canonical_filename,
            sha256, sha8, version, mime_type, nsfw_score,
            origin_device, intake_method, status,
            sidecar_path, hook_id, idrive_e2_uri,
            governed_at, last_verified_at
        ) VALUES (
            %(docid)s, %(para_code)s, %(canonical_path)s, %(canonical_filename)s,
            %(sha256)s, %(sha8)s, %(version)s, %(mime_type)s, %(nsfw_score)s,
            %(origin_device)s, %(intake_method)s, 'governed',
            %(sidecar_path)s, %(hook_id)s, %(idrive_e2_uri)s,
            NOW(), NOW()
        )
        ON CONFLICT (docid) DO UPDATE SET
            canonical_path = EXCLUDED.canonical_path,
            version = EXCLUDED.version,
            sha256 = EXCLUDED.sha256,
            last_verified_at = NOW()
    """, transaction_record)
    conn.commit()
    return True
```

**Schema (key tables):**
```sql
CREATE TABLE logical_files (
    docid           TEXT PRIMARY KEY,  -- permanent identity
    para_code       TEXT NOT NULL,
    canonical_path  TEXT NOT NULL,
    canonical_filename TEXT NOT NULL,
    sha256          TEXT NOT NULL,
    sha8            TEXT NOT NULL,
    version         TEXT NOT NULL,
    mime_type       TEXT,
    nsfw_score      FLOAT DEFAULT 0.0,
    origin_device   TEXT,
    intake_method   TEXT,
    status          TEXT DEFAULT 'governed',
    sidecar_path    TEXT,
    hook_id         TEXT,
    idrive_e2_uri   TEXT,
    bookstack_url   TEXT,
    paperless_id    TEXT,
    governed_at     TIMESTAMPTZ DEFAULT NOW(),
    last_verified_at TIMESTAMPTZ
);

CREATE TABLE mirror_events (
    event_id        SERIAL PRIMARY KEY,
    docid           TEXT REFERENCES logical_files(docid),
    event_type      TEXT,  -- 'mirror', 'verify', 'drift', 'quarantine'
    remote          TEXT,
    remote_sha256   TEXT,
    local_sha256    TEXT,
    result          TEXT,  -- 'ok', 'mismatch', 'error'
    recorded_at     TIMESTAMPTZ DEFAULT NOW()
);
```

**On failure:** Transaction aborts. FileWarden attempts to reverse the canonical rename (restore original filename). Full error logged to audit trail. Operator alert via n8n.

---

## STAGE 12 — PUBLISH

**Program:** FileWarden daemon → BookStack API + PaperParrot API
**Non-fatal:** Both calls are async. Failures are retried without blocking the transaction.

### 12a. BookStack update
**Program:** FileWarden daemon → BookStack API (REST)
**Action:** Append an entry to the running record page

```python
import requests

def update_bookstack(docid: str, summary: dict) -> str:
    """Appends a governance entry to the BookStack running record page."""
    # Get current page content
    page = requests.get(
        f"https://bookstack.shannonjlove.cloud/api/pages/{RUNNING_RECORD_PAGE_ID}",
        headers={"Authorization": f"Token {BS_TOKEN_ID}:{BS_TOKEN_SECRET}"}
    ).json()
    
    new_entry = f"""
### {datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M')} UTC — {docid}
- **File:** `{summary['canonical_filename']}`
- **PARA:** {summary['para_code']}
- **Version:** {summary['version']}
- **SHA8:** `{summary['sha8']}`
- **OCR:** {summary['ocr_status']}
- **NSFW:** {summary.get('nsfw_score', 0.0):.2f}
- **iDrive E2:** `{summary['idrive_e2_uri']}`
"""
    
    updated_markdown = page['markdown'] + new_entry
    
    requests.put(
        f"https://bookstack.shannonjlove.cloud/api/pages/{RUNNING_RECORD_PAGE_ID}",
        headers={"Authorization": f"Token {BS_TOKEN_ID}:{BS_TOKEN_SECRET}"},
        json={"markdown": updated_markdown}
    )
    return f"https://bookstack.shannonjlove.cloud/books/.../pages/running-record"
```

### 12b. PaperParrot archive
**Program:** FileWarden daemon → PaperParrot API

```python
def archive_paperparrot(docid: str, canonical_path: str) -> str:
    """Post document to PaperParrot for archival indexing."""
    with open(canonical_path, 'rb') as f:
        response = requests.post(
            "https://paperless.shannonjlove.cloud/api/documents/post_document/",
            headers={"Authorization": f"Token {PP_TOKEN}"},
            files={"document": (os.path.basename(canonical_path), f)},
            data={
                "title": docid,
                "correspondent": "SJL-Infrastructure",
                "tags": "sjl-sovereigncloud,automation,infra,final",
            }
        )
    task_id = response.json().get('task_id')
    return task_id  # Paperless processes asynchronously
```

---

## COMPLETE JOURNEY SUMMARY — PROGRAM MAP

| Stage | Program/Service | On Nexus or sOs | Notes |
|---|---|---|---|
| Pre-intake: quarantine clear | `xattr -d com.apple.quarantine` | **Mac** | After download verification |
| Pre-intake: date recovery | `exiftool -r '-FileModifyDate<DateTimeOriginal'` | **Mac** | Before SFTP upload |
| Pre-intake: PARA tag | `tag --add sjl-para-NNNNNN` (jdberry/tag) | **Mac** | Finder tag; stripped in SFTP |
| Intake (SFTP) | OpenSSH sshd | Nexus | User connects to sjl@100.115.66.75 |
| Intake (n8n) | sjl-n8n container | Nexus | Podman Quadlet |
| Intake (PaperParrot) | sjl-paperparrot container | Nexus | Direct consume dir |
| DISCOVER | FileWarden daemon (Python) | Nexus | inotify kernel API |
| STABILIZE | FileWarden daemon | Nexus | Polling stat() |
| IDENTIFY / hash | FileWarden daemon | Nexus | hashlib.sha256 |
| IDENTIFY / docid | FileWarden + Mirror Registry | Nexus | PostgreSQL sequence |
| ANALYZE / metadata | FileWarden + exiftool | Nexus | Subprocess |
| ANALYZE / date chain | FileWarden + exiftool (priority chain) | Nexus | Sentinel detection; EXIF date fallback |
| ANALYZE / OCR | sjl-ocr-vision-worker | **sOs ARM64** | Queue via n8n + Tailscale |
| ANALYZE / vision | sjl-ocr-vision-worker | **sOs ARM64** | Same worker |
| VERSION | FileWarden + Mirror Registry | Nexus | PostgreSQL lookup |
| DIFF | DiffForge (FastAPI :8087) | Nexus | Non-fatal |
| RENAME | FileWarden daemon | Nexus | os.rename() |
| SIDECAR / JSON | FileWarden daemon | Nexus | json.dumps + write; includes captured_at + exif_stripped |
| SIDECAR / xattr (Linux) | FileWarden + xattr lib | Nexus | user.sjl.* namespace |
| SIDECAR / XMP | FileWarden + exiftool | Nexus | Subprocess |
| SIDECAR / xattr (macOS) | xattr + mdls + jdberry/tag | **Mac** (post-receive) | com.apple.* namespace; kMDItemDescription=DOCID |
| HOOK | HookVault CLI (sjl-hook) | Nexus | FastAPI :8086 |
| MIRROR | rclone | Nexus | S3 PUT to iDrive E2 |
| MIRROR verify | rclone hashsum | Nexus | SHA-256 comparison |
| REGISTER | FileWarden + psycopg2 | Nexus | PostgreSQL INSERT |
| PUBLISH / BookStack | FileWarden + requests | Nexus | BookStack REST API |
| PUBLISH / PaperParrot | FileWarden + requests | Nexus | PaperParrot REST API |

---

## AUDIT TRAIL

Every FileWarden transaction produces an audit log entry:

```json
{
  "transaction_id": "txn-20260629-120000-a1b2c3d4",
  "docid": "SJL-CLOUD-0042",
  "started_at": "2026-06-29T12:00:00Z",
  "completed_at": "2026-06-29T12:00:08Z",
  "stages": {
    "discover": "ok",
    "stabilize": "ok",
    "identify": "ok",
    "analyze": "ok",
    "version": "ok - v1-0",
    "diff": "ok - 42 lines added",
    "rename": "ok",
    "sidecar": "ok",
    "hook": "ok",
    "mirror": "ok - sha256 verified",
    "register": "ok",
    "publish_bookstack": "ok",
    "publish_paperparrot": "pending"
  },
  "errors": [],
  "final_status": "governed"
}
```

Audit logs are stored at: `/srv/sjl/080000_APP-DATA/filewarden-audit/YYYY-MM/`
And mirrored to: `idrive-e2:sjl-080000/filewarden-audit/YYYY-MM/`

---

## NIGHTLY INTEGRITY VERIFICATION

**Program:** n8n scheduled workflow (cron: 03:00 UTC daily)
**Action:** Pull all logical_files records from Mirror Registry → rclone hashsum verify each → flag mismatches

```bash
# Simplified integrity check (run by n8n cron workflow):
psql "${MIRROR_REGISTRY_DSN}" -c "SELECT docid, idrive_e2_uri, sha256 FROM logical_files WHERE status='governed'" \
  | while IFS='|' read -r docid uri local_sha256; do
      remote_sha256=$(rclone hashsum SHA-256 "${uri}" | awk '{print $1}')
      if [ "${remote_sha256}" != "${local_sha256}" ]; then
          echo "INTEGRITY FAIL: ${docid}" | tee -a /srv/sjl/080000_APP-DATA/integrity-failures.log
          # n8n sends alert notification
      fi
  done
```

**Alert routing:** n8n → notification (email / push / Uptime Kuma alert)
