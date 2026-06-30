---
title: SJL Media Metadata Recovery & Tagging Skills
tags: [filewarden, exiftool, xattr, macos, metadata, sjl-sovereign-cloud]
created: 2026-06-30
updated: 2026-06-30
---

# SJL Media Metadata Recovery & Tagging Skills

Synthesized from: Andy Polaine (ExifTool), Brett Terpstra (Finder tags / xattr), Eclectic Light (xattr map). Integrated into FileWarden v2 pipeline 2026-06-30.

## ExifTool Date Recovery

### Sentinel dates (corrupt/stripped — reject as captured_at)
- `1970-01-01` — Unix epoch (video corruption by Everpix/Loom)
- `1999-11-30` — WhatsApp strips all EXIF and sets this date
- `2001-01-01` — iOS photo edit extensions strip EXIF on save

### Date priority chain
**Images:** DateTimeOriginal → CreateDate → XMP:DateCreated → IPTC:DateCreated → GPS:GPSDateTime → FileModifyDate (last resort)

**Videos:** QuickTime:DateTimeOriginal → QuickTime:CreateDate → QuickTime:TrackCreateDate (survives most corruption) → XMP:DateCreated → FileModifyDate

### Key commands
```bash
# View all date tags (diagnosis)
exiftool -a -G -time:all /path/to/file

# Fix image from DateTimeOriginal
exiftool '-FileModifyDate<DateTimeOriginal' /path/to/file.jpg

# Fix video with 1970 epoch (recover from TrackCreateDate)
exiftool '-FileModifyDate<TrackCreateDate' '-FileName<TrackCreateDate' \
  -d %Y-%m-%d_%H.%M.%S.%%e /path/to/video.mov

# Batch fix directory
exiftool -r '-FileModifyDate<DateTimeOriginal' /path/

# Find sentinel-date files
exiftool -q -r -if '$DateTimeOriginal =~ /^(1970|1999|2001-01-01)/' \
  -filename -DateTimeOriginal /path/
```

## macOS Finder Tags / xattr

### Always read with mdls (not xattr hex)
```bash
mdls -raw -name kMDItemUserTags /path/to/file
```

### Write tags with jdberry/tag (safe read-modify-write)
```bash
tag --add "sjl-para-070000" /path/to/file   # add, preserves existing
tag --remove "sjl-para-060000" /path/to/file
tag --list /path/to/file
```

### Key xattr keys (macOS)
- `com.apple.metadata:_kMDItemUserTags` — Finder tags (plist array)
- `com.apple.metadata:kMDItemDescription` — DOCID + PARA in Finder Get Info
- `com.apple.metadata:kMDItemWhereFroms` — download origin URLs (plist array)
- `com.apple.quarantine` — Gatekeeper flag, clear after verification: `xattr -d com.apple.quarantine /file`

### xattr write destroys existing tags — always read-modify-write
`xattr -w com.apple.metadata:_kMDItemUserTags` obliterates all existing tags. Use `tag --add` instead to preserve.

### Linux xattr on Nexus (user.* namespace)
```python
import xattr
xattr.setxattr(path, 'user.sjl.docid', docid.encode())
xattr.setxattr(path, 'user.sjl.para', para_code.encode())
xattr.setxattr(path, 'user.sjl.captured_at', captured_at.encode())
xattr.setxattr(path, 'user.sjl.exif_stripped', b'true' if exif_stripped else b'false')
```

## FileWarden Integration

### New Stage 0.3 (Mac-side preprocessing before SFTP)
1. `xattr -d com.apple.quarantine` — clear quarantine after download
2. `exiftool '-FileModifyDate<DateTimeOriginal'` — recover date before SFTP
3. `tag --add sjl-para-NNNNNN` — PARA Finder tag (stripped in SFTP but useful on Mac)

### New Stage 4d (ANALYZE — EXIF date chain)
- Run priority chain via `exiftool -json -a -G -d '%Y-%m-%dT%H:%M:%S%z'`
- Reject sentinel dates
- Store `captured_at`, `captured_at_source`, `exif_stripped` in sidecar JSON
- If `exif_stripped = true` → route to 090000_QUARANTINE

### Stage 8d (Mac post-receive enrichment)
- Write DOCID to `kMDItemDescription` via xattr
- Add PARA Finder tag via `tag --add`
- Preserve WhereFroms if origin URL known

### FileWarden EXCLUSION for basic-memory
```python
# MUST exclude from rename pipeline:
'/srv/sjl/070000_SYSTEM-AUTOMATION/079000_AGENT-CONTEXT/memory/'
```
basic-memory uses filenames as identity keys — FileWarden rename would break the memory graph.

## Tools
- `exiftool` — brew install exiftool / apt install libimage-exiftool-perl
- `tag` (jdberry) — brew install tag — github.com/jdberry/tag
- `mdls` — built-in macOS (man mdls)
- `python-xattr` — pip install xattr
- `plistlib` — Python stdlib, no install
