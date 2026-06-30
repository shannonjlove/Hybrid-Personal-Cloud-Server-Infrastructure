#!/usr/bin/env bash
# File Warden — Organize & Tag Module
# Moves files into PARA-aware category subfolders and tags them via xattr (user.tags).
# Standalone or invoked by: file-warden.sh organize [OPTIONS] <directory>
#
# Usage: [sudo] organize-and-tag.sh [--dry-run] [--exclude PATTERN] [--log FILE] <directory>
#
# Bugs fixed vs. original:
#  - 'local' keyword moved inside functions (was in main body, invalid in bash)
#  - Extension matching rewritten: splits pipe-delimited list, exact compare (no broken regex)
#  - IFS='|' used when parsing get_category() output (was split on whitespace, lost tag)
set -Eeuo pipefail

# ── Configuration ──────────────────────────────────────────────────────────────
DRY_RUN=false
ROOT_DIR=""
LOG_FILE="/var/log/sjl-file-warden.log"
EXCLUDE_PATTERN=""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/../config/category-map.conf"

# Default CATEGORY_MAP (loaded from config file if present).
# Format per entry:  "ext1|ext2|ext3:DestFolder:tag"
declare -a CATEGORY_MAP=(
  "jpg|jpeg|png|gif|bmp|tiff|tif|svg|webp|heic|heif|raw|arw|cr2|nef:Images:image"
  "mp4|avi|mov|mkv|webm|flv|m4v|wmv|mpg|mpeg|ts:Videos:video"
  "mp3|wav|flac|aac|ogg|m4a|opus|wma|aiff:Audio:audio"
  "pdf:PDFs:pdf"
  "doc|docx|odt|rtf|pages:Documents:word"
  "xls|xlsx|ods|csv|numbers:Spreadsheets:excel"
  "ppt|pptx|odp|key:Presentations:powerpoint"
  "txt|log|cfg|conf|ini|env|properties:Text:config"
  "zip|tar|gz|bz2|xz|7z|rar|zst|lz4:Archives:archive"
  "deb|rpm|pkg|dmg|msi|apk:Packages:package"
  "sh|bash|zsh|fish|py|pl|js|ts|jsx|tsx|rb|go|rs|c|cpp|cc|h|hpp|java|kt|swift|lua|php|r:Scripts:code"
  "iso|img|bin|toast:ISOs:iso"
  "db|sqlite|sqlite3|sql:Databases:database"
  "key|pem|crt|cer|p12|pfx|gpg|asc|pub:Certificates:security"
  "md|markdown|rst|adoc:Markdown:markdown"
  "json|yaml|yml|toml|xml|hcl|tf|jsonc:Config:config-file"
  "ttf|otf|woff|woff2|eot:Fonts:font"
)

# ── Helpers ────────────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
Usage: $0 [OPTIONS] <directory>

Organizes files into PARA-aware category subfolders and adds xattr tags.

Options:
  --dry-run              Preview moves without making changes.
  --exclude PATTERN      Exclude paths matching PATTERN (passed to find -not -path).
  --log FILE             Override log file (default: $LOG_FILE).
  --help                 Show this help.

Examples:
  sudo $0 --dry-run /srv/sjl/data
  sudo $0 --exclude '*/.git/*' /srv/sjl/300000_AREAS/oracle-config
EOF
  exit 0
}

log() {
  local ts
  ts="$(date '+%Y-%m-%d %H:%M:%S')"
  echo "$ts [organize-and-tag] $*" | tee -a "$LOG_FILE"
}

die() {
  echo "ERROR: $*" >&2
  log "ERROR: $*"
  exit 1
}

# ── Load external config ───────────────────────────────────────────────────────
load_config() {
  [[ ! -f "$CONFIG_FILE" ]] && return 0
  CATEGORY_MAP=()
  local line
  while IFS= read -r line; do
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line// }" ]] && continue
    CATEGORY_MAP+=("$line")
  done < "$CONFIG_FILE"
  log "Loaded category map from $CONFIG_FILE (${#CATEGORY_MAP[@]} entries)"
}

# ── File categorization ────────────────────────────────────────────────────────
# Outputs "DestFolder|tag" for a given file path.
get_category() {
  local file="$1"
  local ext="${file##*.}"
  ext="$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')"

  local entry extensions rest dest tag
  for entry in "${CATEGORY_MAP[@]}"; do
    extensions="${entry%%:*}"
    rest="${entry#*:}"
    dest="${rest%:*}"
    tag="${rest##*:}"
    # Split pipe-delimited extension list and compare each exactly
    local e
    IFS='|' read -ra exts <<< "$extensions"
    for e in "${exts[@]}"; do
      if [[ "$ext" == "$e" ]]; then
        printf '%s|%s\n' "$dest" "$tag"
        return 0
      fi
    done
  done

  # Fallback: MIME type detection
  local mime
  mime="$(file -b --mime-type "$file" 2>/dev/null || echo "application/octet-stream")"
  case "$mime" in
    image/*)                                    printf 'Images|image\n' ;;
    video/*)                                    printf 'Videos|video\n' ;;
    audio/*)                                    printf 'Audio|audio\n' ;;
    text/*)                                     printf 'Text|text\n' ;;
    application/pdf)                            printf 'PDFs|pdf\n' ;;
    application/zip|application/x-tar| \
    application/gzip|application/x-bzip2| \
    application/x-xz|application/x-7z-compressed)
                                                printf 'Archives|archive\n' ;;
    application/x-executable| \
    application/x-sharedlib|application/x-pie-executable)
                                                printf 'Binaries|binary\n' ;;
    *)                                          printf 'Misc|misc\n' ;;
  esac
}

# ── Idempotent xattr tagging ───────────────────────────────────────────────────
add_tag() {
  local target="$1" new_tag="$2"
  if [[ "$DRY_RUN" == true ]]; then
    echo "  [DRY] tag '$new_tag' → $(basename "$target")"
    return 0
  fi
  if ! command -v xattr >/dev/null 2>&1; then
    return 0
  fi
  local existing
  existing="$(xattr -p user.tags "$target" 2>/dev/null || true)"
  if [[ -z "$existing" ]]; then
    xattr -w user.tags "$new_tag" "$target"
  elif [[ ",$existing," != *",$new_tag,"* ]]; then
    xattr -w user.tags "${existing},${new_tag}" "$target"
  fi
}

# ── Core processing (wrapped in function so 'local' is valid) ─────────────────
process_files() {
  local total=0 moved=0 skipped=0 errors=0
  local file category tag target_dir base_name target_path
  local base ext counter

  # Build find arguments
  local -a find_args=(-type f)
  [[ -n "$EXCLUDE_PATTERN" ]] && find_args+=(-not -path "$EXCLUDE_PATTERN")
  find_args+=(-print0)

  while IFS= read -r -d '' file; do
    # find -type f already excludes dirs & symlinks, but guard anyway
    [[ -d "$file" || -L "$file" ]] && continue

    total=$((total + 1))
    log "Processing: $file"

    # Resolve category and tag — pipe delimiter preserved by IFS='|'
    IFS='|' read -r category tag <<< "$(get_category "$file")"
    : "${category:=Misc}" "${tag:=misc}"

    target_dir="$ROOT_DIR/$category"
    base_name="$(basename "$file")"
    target_path="$target_dir/$base_name"

    # Skip if already in the correct category folder
    local file_dir
    file_dir="$(dirname "$file")"
    if [[ "$file_dir" == "$target_dir" || "$file_dir" == "$(realpath "$target_dir" 2>/dev/null || echo "$target_dir")" ]]; then
      log "  Already in place: $file"
      add_tag "$file" "$tag"
      skipped=$((skipped + 1))
      continue
    fi

    if [[ "$DRY_RUN" == true ]]; then
      echo "  [DRY] $file → $target_path  (tag: $tag)"
      moved=$((moved + 1))
      continue
    fi

    mkdir -p "$target_dir"

    # Resolve name collisions by appending _N counter
    if [[ -e "$target_path" ]]; then
      ext="${base_name##*.}"
      base="${base_name%.*}"
      if [[ "$base_name" == "$ext" ]]; then
        ext=""
      else
        ext=".$ext"
      fi
      counter=1
      while [[ -e "$target_dir/${base}_${counter}${ext}" ]]; do
        counter=$((counter + 1))
      done
      target_path="$target_dir/${base}_${counter}${ext}"
      log "  Collision resolved → $(basename "$target_path")"
    fi

    if mv "$file" "$target_path" 2>/dev/null; then
      moved=$((moved + 1))
      add_tag "$target_path" "$tag"
      log "  Moved → $target_path"
    else
      log "  ERROR: could not move '$file'"
      errors=$((errors + 1))
    fi
  done < <(find "$ROOT_DIR" "${find_args[@]}")

  log "=== Summary: total=$total moved=$moved skipped=$skipped errors=$errors ==="
  if [[ "$DRY_RUN" == true ]]; then
    echo "DRY RUN — no changes made."
  else
    echo "Complete. Log: $LOG_FILE"
  fi
  return "$errors"
}

# ── Argument parsing ───────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)  DRY_RUN=true; shift ;;
    --exclude)  EXCLUDE_PATTERN="$2"; shift 2 ;;
    --log)      LOG_FILE="$2"; shift 2 ;;
    --help|-h)  usage ;;
    -*)         die "Unknown option: $1" ;;
    *)
      if [[ -z "$ROOT_DIR" ]]; then
        ROOT_DIR="$1"; shift
      else
        die "Only one directory argument allowed."
      fi
      ;;
  esac
done

[[ -z "$ROOT_DIR" ]] && usage
[[ ! -d "$ROOT_DIR" ]] && die "Directory '$ROOT_DIR' does not exist."

# Warn if xattr unavailable
command -v xattr >/dev/null 2>&1 || log "WARNING: 'xattr' not installed — tagging skipped. Install: apt install xattr"

# ── Run ────────────────────────────────────────────────────────────────────────
load_config
log "Starting organize-and-tag on '$ROOT_DIR' (dry-run=$DRY_RUN)"
cd "$ROOT_DIR" || die "Cannot cd into '$ROOT_DIR'"
process_files
