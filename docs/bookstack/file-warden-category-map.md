# File Warden — Category Map Configuration

The category map controls how files are classified and tagged. It is stored in `03-AUTOMATION/file-warden/config/category-map.conf` and is loaded at runtime — no script edits required.

---

## File Location

```
03-AUTOMATION/file-warden/config/category-map.conf
```

---

## Format

Each non-comment line defines one category mapping:

```
ext1|ext2|ext3:DestinationFolder:tag
```

| Part | Description |
|------|-------------|
| `ext1\|ext2\|ext3` | Pipe-separated list of file extensions (lowercase, no dots) |
| `DestinationFolder` | Subfolder name to create under the scanned root |
| `tag` | Value written to the `user.tags` xattr attribute |

Lines beginning with `#` are comments. Blank lines are ignored.

---

## Example Entry

```conf
# Images
jpg|jpeg|png|gif|bmp|tiff|tif|svg|webp|heic|heif|raw|arw|cr2|nef:Images:image
```

This routes all JPEG, PNG, SVG, WebP, HEIC, and RAW files into an `Images/` folder and tags each with `image`.

---

## Adding a Custom Category

To route `.sketch`, `.fig`, and `.xd` design files into a `Design/` folder:

```conf
# Design files
sketch|fig|xd:Design:design
```

Save the file — the change takes effect on the next `file-warden.sh organize` run.

---

## Precedence

1. **Category map** (extension match, first-wins)
2. **MIME fallback** (`file(1)` detection for unlisted extensions)
3. **Misc** (unclassifiable files go to `Misc/` with tag `misc`)

---

## Full Default Map

```conf
jpg|jpeg|png|gif|bmp|tiff|tif|svg|webp|heic|heif|raw|arw|cr2|nef:Images:image
mp4|avi|mov|mkv|webm|flv|m4v|wmv|mpg|mpeg|ts:Videos:video
mp3|wav|flac|aac|ogg|m4a|opus|wma|aiff:Audio:audio
pdf:PDFs:pdf
doc|docx|odt|rtf|pages:Documents:word
xls|xlsx|ods|csv|numbers:Spreadsheets:excel
ppt|pptx|odp|key:Presentations:powerpoint
txt|log|cfg|conf|ini|env|properties:Text:config
zip|tar|gz|bz2|xz|7z|rar|zst|lz4:Archives:archive
deb|rpm|pkg|dmg|msi|apk:Packages:package
sh|bash|zsh|fish|py|pl|js|ts|jsx|tsx|rb|go|rs|c|cpp|cc|h|hpp|java|kt|swift|lua|php|r:Scripts:code
iso|img|bin|toast:ISOs:iso
db|sqlite|sqlite3|sql:Databases:database
key|pem|crt|cer|p12|pfx|gpg|asc|pub:Certificates:security
md|markdown|rst|adoc:Markdown:markdown
json|yaml|yml|toml|xml|hcl|tf|jsonc:Config:config-file
ttf|otf|woff|woff2|eot:Fonts:font
```

---

*Source: `03-AUTOMATION/file-warden/config/category-map.conf` | Last updated: June 2026*
