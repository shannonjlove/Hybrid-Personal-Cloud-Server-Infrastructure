# File Warden — Organize & Tag Module

The `organize-and-tag.sh` module recursively scans a directory, routes files into PARA-aware category subfolders, and applies `user.tags` extended attributes.

---

## Usage

```bash
# Via main CLI (recommended)
sudo bash 03-AUTOMATION/file-warden/file-warden.sh organize [OPTIONS] <directory>

# Standalone
sudo bash 03-AUTOMATION/file-warden/modules/organize-and-tag.sh [OPTIONS] <directory>
```

### Options

| Option | Description |
|--------|-------------|
| `--dry-run` | Preview moves and tags — no changes made |
| `--exclude PATTERN` | Skip paths matching PATTERN (find `-not -path` syntax) |
| `--log FILE` | Override log file (default: `/var/log/sjl-file-warden.log`) |
| `--help` | Show usage |

---

## How Files Are Classified

1. **Extension match** — the file's extension is looked up in `config/category-map.conf` (exact, case-insensitive, pipe-delimited list per entry)
2. **MIME fallback** — if the extension is not in the map, `file -b --mime-type` is used for broad categorization
3. **Misc** — files that match neither go into a `Misc/` folder with the `misc` tag

---

## Default Category Map

| Extensions | Destination Folder | Tag |
|------------|-------------------|-----|
| jpg, jpeg, png, gif, bmp, tiff, svg, webp, heic, raw… | `Images/` | `image` |
| mp4, avi, mov, mkv, webm, flv… | `Videos/` | `video` |
| mp3, wav, flac, aac, ogg, m4a… | `Audio/` | `audio` |
| pdf | `PDFs/` | `pdf` |
| doc, docx, odt, rtf, pages | `Documents/` | `word` |
| xls, xlsx, ods, csv | `Spreadsheets/` | `excel` |
| ppt, pptx, odp, key | `Presentations/` | `powerpoint` |
| txt, log, cfg, conf, ini, env | `Text/` | `config` |
| zip, tar, gz, bz2, xz, 7z, rar, zst | `Archives/` | `archive` |
| deb, rpm, pkg, dmg, apk | `Packages/` | `package` |
| sh, py, js, ts, go, rs, rb, c, cpp… | `Scripts/` | `code` |
| iso, img | `ISOs/` | `iso` |
| db, sqlite, sql | `Databases/` | `database` |
| key, pem, crt, cer, p12 | `Certificates/` | `security` |
| md, markdown, rst | `Markdown/` | `markdown` |
| json, yaml, yml, toml, xml, tf, hcl | `Config/` | `config-file` |
| ttf, otf, woff, woff2 | `Fonts/` | `font` |

To add or modify entries, edit `03-AUTOMATION/file-warden/config/category-map.conf` — no script changes needed.

---

## Name Collision Handling

If a file with the same name already exists in the target folder, the module appends `_N` before the extension:

```
report.pdf  →  report_1.pdf  →  report_2.pdf  …
```

---

## xattr Tagging

Tags are written to the `user.tags` extended attribute. The operation is idempotent — if a tag already exists on the file it is not duplicated.

```bash
# View tags on a file
xattr -p user.tags /srv/sjl/data/PDFs/report.pdf
# → pdf

# Multiple tags accumulate as comma-separated values
# → pdf,reviewed,2026
```

Tagging requires `xattr` to be installed (`apt install xattr`). If missing, tagging is skipped with a warning — organization still proceeds.

---

## Example Run

```
2026-06-30 14:21:09 [organize-and-tag] Starting organize-and-tag on '/srv/sjl/data' (dry-run=true)
2026-06-30 14:21:09 [organize-and-tag] Processing: /srv/sjl/data/photo.jpg
  [DRY] /srv/sjl/data/photo.jpg → /srv/sjl/data/Images/photo.jpg  (tag: image)
2026-06-30 14:21:09 [organize-and-tag] Processing: /srv/sjl/data/report.pdf
  [DRY] /srv/sjl/data/report.pdf → /srv/sjl/data/PDFs/report.pdf  (tag: pdf)
2026-06-30 14:21:09 [organize-and-tag] === Summary: total=2 moved=2 skipped=0 errors=0 ===
DRY RUN — no changes made.
```

---

*Source: `03-AUTOMATION/file-warden/modules/organize-and-tag.sh` | Last updated: June 2026*
