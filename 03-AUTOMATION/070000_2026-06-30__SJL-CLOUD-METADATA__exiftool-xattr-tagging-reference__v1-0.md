# SJL SOVEREIGN CLOUD — ExifTool + xattr + Finder Tag Reference
## Metadata Recovery, Tagging, and Provenance Patterns

| Field | Value |
|---|---|
| DOCID | SJL-CLOUD-META-001 |
| Version | v1-0 |
| Date | 2026-06-30 |
| PARA | 070000_SYSTEM-AUTOMATION |
| Sources | Polaine (ExifTool), Terpstra (Finder tags), Eclectic Light (xattr map) |

> Persistent reference for FileWarden v2 implementation and operator use.
> Synthesized from research session 2026-06-30.

---

## PART 1 — EXIFTOOL DATE RECOVERY

### 1.1 Why Dates Break

| Source | Problem | Sentinel date |
|---|---|---|
| WhatsApp | Strips all EXIF — sets epoch timestamp | `1999-11-30 00:00:00` |
| Twitter/X | Strips GPS, sometimes DateTimeOriginal | varies |
| iOS photo editing extensions | Strips EXIF on save | `2001-01-01` or `1970-01-01` |
| Everpix / Loom (defunct) | Re-stamped file creation dates | `1970-01-01` |
| iMessage photo edits | Strips EXIF | `2001-01-01` |
| Video container corruption | Unix epoch reset | `1970-01-01T00:00:00` |

**Rule:** Any date before `1990-01-01` in modern media (iPhone, digital camera) is a sentinel. Reject it and walk the priority chain.

---

### 1.2 Date Priority Chain

**Images (`image/*`):**
```
1. EXIF:DateTimeOriginal       ← capture moment, never rewritten by apps
2. EXIF:CreateDate             ← camera-set, occasionally overwritten
3. XMP:DateCreated             ← editing app may preserve
4. IPTC:DateCreated            ← professional editorial metadata
5. Composite:GPSDateTime       ← GPS clock (UTC — adjust for local TZ)
6. File:FileModifyDate         ← last resort; may be upload/transfer time
   REJECT: any sentinel date
```

**Videos (`video/*, .mov, .mp4, .m4v`):**
```
1. QuickTime:DateTimeOriginal
2. QuickTime:CreateDate
3. QuickTime:TrackCreateDate   ← SURVIVES many corruption events (use this for 1970 epoch videos)
4. QuickTime:TrackModifyDate
5. XMP:DateCreated
6. File:FileModifyDate         ← last resort
   REJECT: any sentinel date
```

---

### 1.3 ExifTool Command Cheat Sheet

```bash
# VIEW all date tags for a file (diagnosis):
exiftool -a -G -time:all /path/to/file

# VIEW everything (verbose — use for diagnosis):
exiftool -a /path/to/file

# FIX image: set FileModifyDate from DateTimeOriginal:
exiftool '-FileModifyDate<DateTimeOriginal' /path/to/file.jpg

# FIX video: recover from TrackCreateDate (1970-epoch corruption):
exiftool '-FileModifyDate<TrackCreateDate' '-FileName<TrackCreateDate' \
  -d %Y-%m-%d_%H.%M.%S.%%e /path/to/video.mov

# FIX video: repair CreateDate from TrackCreateDate:
exiftool '-CreateDate<TrackCreateDate' '-ModifyDate<TrackCreateDate' /path/to/video.mov

# BATCH recover all images in directory:
exiftool -r '-FileModifyDate<DateTimeOriginal' /srv/sjl/010000_INBOX/

# BATCH fix only 1970-epoch videos:
exiftool -r -if '$CreateDate =~ /^1970/' \
  '-CreateDate<TrackCreateDate' '-ModifyDate<TrackCreateDate' \
  /srv/sjl/010000_INBOX/

# FIND sentinel-date files (for quarantine routing):
exiftool -q -r -if '$DateTimeOriginal =~ /^(1970|1999|2001-01-01)/' \
  -filename -DateTimeOriginal /srv/sjl/010000_INBOX/

# RENAME file to date-based pattern:
exiftool '-FileName<DateTimeOriginal' -d %Y-%m-%d_%H.%M.%S.%%le /path/to/file

# WRITE custom date (manual correction):
exiftool -DateTimeOriginal='2024:06:15 14:30:00' /path/to/file

# EXTRACT GPS as decimal:
exiftool -n -GPSLatitude -GPSLongitude /path/to/photo.jpg

# REMOVE all metadata (privacy scrub):
exiftool -all= /path/to/file
```

---

## PART 2 — macOS XATTR PATTERNS

### 2.1 Key xattr Namespace Map

**`com.apple.metadata:*` namespace (Spotlight-indexed):**

| xattr key | Description | FileWarden use |
|---|---|---|
| `_kMDItemUserTags` | Finder tags (plist array of strings) | PARA code tags: `sjl-para-070000` |
| `kMDItemDescription` | Arbitrary text info (Get Info → More Info) | DOCID + PARA + version string |
| `kMDItemWhereFroms` | Download origin URLs (plist array) | FetchWarden source URL + referrer |
| `kMDItemDownloadedDate` | Download timestamp (plist date) | FetchWarden acquisition date |
| `kMDItemCreator` | App that created the file | `FileWarden-v2` tag |
| `kMDItemCopyright` | Copyright info | For media files |
| `kMDItemHeadline` | Arbitrary headline text | DOCID as short headline |

**Other `com.apple.*`:**

| xattr key | Description | FileWarden use |
|---|---|---|
| `com.apple.quarantine` | Gatekeeper quarantine flag | Clear after download verification (Stage 0.3a) |
| `com.apple.FinderInfo` | Finder color labels (legacy) | Avoid — use tag CLI instead |
| `org.openmetainfo:` | OpenMeta third-party metadata | Legacy — read only |

---

### 2.2 Reading Tags (macOS)

**CORRECT — use `mdls` (readable output, no hex):**
```bash
mdls -raw -name kMDItemUserTags /path/to/file
# Output:
# (
#     "sjl-para-070000",
#     "filewarden"
# )

# Read any xattr cleanly:
mdls -raw -name kMDItemDescription /path/to/file
mdls -raw -name kMDItemWhereFroms /path/to/file
```

**AVOID — `xattr -px` gives binary plist hex dump:**
```bash
# This gives unreadable hex → requires perl | plutil pipeline:
xattr -px com.apple.metadata:_kMDItemUserTags /path/to/file  # avoid
```

**List all xattrs on a file:**
```bash
xattr -l /path/to/file    # shows all keys + values
xattr -p com.apple.metadata:kMDItemWhereFroms /path/to/file  # specific key
```

---

### 2.3 Writing Finder Tags (macOS)

**IMPORTANT:** `xattr -w` on `_kMDItemUserTags` OBLITERATES existing tags. Always read-modify-write.

**Option A — jdberry/tag CLI (recommended, handles read-modify-write):**
```bash
# Install: brew install tag
tag --list /path/to/file          # read tags
tag --add "sjl-para-070000" /path/to/file     # add tag (preserves existing)
tag --remove "sjl-para-060000" /path/to/file  # remove specific tag
tag --set "sjl-para-070000,filewarden" /path/to/file  # replace all
```

**Option B — direct xattr (obliterates existing tags):**
```bash
xattr -w com.apple.metadata:_kMDItemUserTags \
  '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><array><string>sjl-para-070000</string><string>filewarden</string></array></plist>' \
  /path/to/file
```

**Option C — Python (read-modify-write with plistlib):**
```python
import subprocess, plistlib

def add_finder_tag(path: str, new_tag: str):
    # Read existing tags via mdls (safe)
    result = subprocess.run(
        ['mdls', '-raw', '-name', 'kMDItemUserTags', path],
        capture_output=True, text=True
    )
    existing = []
    if '(' in result.stdout:
        for line in result.stdout.splitlines():
            line = line.strip().strip(',').strip('"')
            if line and line not in ('(', ')'):
                existing.append(line)
    
    if new_tag in existing:
        return  # already tagged
    
    tags = existing + [new_tag]
    plist_xml = plistlib.dumps(tags, fmt=plistlib.FMT_XML).decode()
    subprocess.run(['xattr', '-w', 'com.apple.metadata:_kMDItemUserTags', plist_xml, path])
```

---

### 2.4 Writing Standard Metadata xattrs (macOS)

```bash
# DOCID + PARA + version in kMDItemDescription (shows in Finder Get Info):
xattr -w com.apple.metadata:kMDItemDescription \
  "SJL-CLOUD-0042 | 070000 | v1-0" /path/to/file

# WhereFroms (provenance URL — plist array):
python3 -c "
import plistlib, subprocess, sys
urls = [sys.argv[1], sys.argv[2]]
plist = plistlib.dumps(urls, fmt=plistlib.FMT_XML).decode()
subprocess.run(['xattr', '-w', 'com.apple.metadata:kMDItemWhereFroms', plist, sys.argv[3]])
" "https://source.example.com/file.pdf" "https://referring.page.com" /path/to/file

# Creator tag:
xattr -w com.apple.metadata:kMDItemCreator "FileWarden-v2" /path/to/file

# Clear quarantine (after verification):
xattr -d com.apple.quarantine /path/to/file
xattr -dr com.apple.quarantine /directory/  # recursive
```

---

### 2.5 Linux xattr Patterns (Nexus)

On Linux (Nexus/sOs), macOS `com.apple.*` xattrs do not exist. FileWarden uses the `user.*` namespace:

```python
import xattr  # pip install xattr

# Write:
xattr.setxattr(path, 'user.sjl.docid',           docid.encode())
xattr.setxattr(path, 'user.sjl.para',             para_code.encode())
xattr.setxattr(path, 'user.sjl.version',          version_string.encode())
xattr.setxattr(path, 'user.sjl.sha256',           sha256_hex.encode())
xattr.setxattr(path, 'user.sjl.captured_at',      captured_at.encode())
xattr.setxattr(path, 'user.sjl.exif_stripped',    b'true' if exif_stripped else b'false')
xattr.setxattr(path, 'user.sjl.origin_url',       origin_url.encode())

# Read:
docid = xattr.getxattr(path, 'user.sjl.docid').decode()

# List all:
for key in xattr.listxattr(path):
    print(key, '=', xattr.getxattr(path, key).decode(errors='replace'))
```

**Shell (Nexus):**
```bash
# Read:
getfattr -d /path/to/file              # list all user.* xattrs
getfattr -n user.sjl.docid /path/to/file  # specific key

# Write:
setfattr -n user.sjl.docid -v "SJL-CLOUD-0042" /path/to/file
```

---

## PART 3 — FILEWARDEN INTEGRATION SUMMARY

### 3.1 Which Stage Uses Which Tool

| Tool | Stage | Platform | Purpose |
|---|---|---|---|
| `exiftool -a -G -time:all` | 4d ANALYZE | Nexus | Diagnose all date tags |
| `exiftool` priority chain | 4d ANALYZE | Nexus | Extract best `captured_at` |
| `xattr.setxattr(user.sjl.*)` | 8b SIDECAR | Nexus (Linux) | Local acceleration layer |
| `exiftool -XMP-sjl:*` | 8c SIDECAR | Nexus | Embedded XMP metadata |
| `xattr -d com.apple.quarantine` | 0.3a Pre-intake | **Mac** | Clear quarantine after download |
| `exiftool '-FileModifyDate<DateTimeOriginal'` | 0.3b Pre-intake | **Mac** | Recover date before SFTP |
| `tag --add sjl-para-NNNNNN` | 0.3c Pre-intake | **Mac** | PARA Finder tag |
| `xattr kMDItemDescription` | 8d (post-receive) | **Mac** | DOCID in Finder Get Info |
| `mdls -raw kMDItemUserTags` | 8d (post-receive) | **Mac** | Read existing tags before write |

### 3.2 Sentinel Detection Table

```python
DATE_SENTINELS = [
    '1970-01-01',   # Unix epoch — video container corruption
    '1999-11-30',   # WhatsApp EXIF strip default
    '2001-01-01',   # iOS timestamp reset
]

def is_sentinel(date_str: str) -> bool:
    return any(s in date_str for s in DATE_SENTINELS) or \
           (date_str < '1990-01-01' and not is_archival_scan)
```

### 3.3 FileWarden Exclusion for basic-memory
The memory directory at `079000_AGENT-CONTEXT/memory/` must be excluded from FileWarden's rename pipeline. basic-memory uses filenames as identity keys.

```python
# FileWarden exclusion (add to EXCLUDED_PATHS):
EXCLUDED_PATHS = [
    ...existing exclusions...,
    '/srv/sjl/070000_SYSTEM-AUTOMATION/079000_AGENT-CONTEXT/memory/',
]
```

---

## PART 4 — TOOLS REFERENCE

| Tool | Install | Docs |
|---|---|---|
| `exiftool` | `brew install exiftool` (Mac) / `apt install libimage-exiftool-perl` (Linux) | Phil Harvey's ExifTool |
| `tag` (jdberry) | `brew install tag` | github.com/jdberry/tag |
| `mdls` | Built into macOS | `man mdls` |
| `xattr` | Built into macOS + Linux (util-linux) | `man xattr` |
| `getfattr` / `setfattr` | Linux: `apt install attr` | `man getfattr` |
| `python-xattr` | `pip install xattr` | pypi.org/project/xattr |
| `plistlib` | Python stdlib | No install needed |
