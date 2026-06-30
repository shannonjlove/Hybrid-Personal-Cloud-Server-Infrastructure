#!/usr/bin/env bash
# File Warden — Main CLI Orchestrator
# Part of the 03-AUTOMATION layer. Integrates with 06-OPS approval workflow.
#
# Subcommands:
#   organize [--dry-run] [--exclude PATTERN] [--log FILE] <directory>
#   fix-node [--log FILE]
#   status
#
# Usage: [sudo] ./file-warden.sh <subcommand> [options]
set -Eeuo pipefail

WARDEN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/sjl-file-warden.log"
VERSION="1.0.0"

log() {
  local ts
  ts="$(date '+%Y-%m-%d %H:%M:%S')"
  echo "$ts [file-warden] $*" | tee -a "$LOG_FILE"
}

usage() {
  cat <<EOF
File Warden v${VERSION} — Automated file organization, tagging & environment repair

Usage:
  sudo $0 organize [--dry-run] [--exclude PATTERN] [--log FILE] <directory>
  sudo $0 fix-node [--log FILE]
       $0 status
       $0 --help

Subcommands:
  organize   Move files into PARA-aware category subfolders; apply xattr tags.
             Always run with --dry-run first to preview changes.
  fix-node   Repair Node.js/npm version conflicts on Ubuntu/Debian (NodeSource).
  status     Show File Warden health and recent log entries.

Options (organize):
  --dry-run              Preview only — no files are moved or tagged.
  --exclude PATTERN      Exclude paths matching PATTERN (find -not -path syntax).
  --log FILE             Override log file (default: $LOG_FILE).

Examples:
  sudo $0 organize --dry-run /srv/sjl/data
  sudo $0 organize --exclude '*/.git/*' /srv/sjl/data
  sudo $0 fix-node
       $0 status
EOF
  exit 0
}

cmd_status() {
  echo "=== File Warden Status (v${VERSION}) ==="
  printf "%-18s %s\n" "Script dir:"  "$WARDEN_DIR"
  printf "%-18s %s\n" "Log file:"    "$LOG_FILE"
  printf "%-18s %s\n" "xattr:"       "$(command -v xattr >/dev/null 2>&1 && echo "installed ($(command -v xattr))" || echo "NOT INSTALLED — apt install xattr")"
  printf "%-18s %s\n" "node:"        "$(node --version 2>/dev/null || echo "not found")"
  printf "%-18s %s\n" "npm:"         "$(npm --version 2>/dev/null | sed 's/^/v/' || echo "not found")"
  printf "%-18s %s\n" "file(1):"     "$(command -v file >/dev/null 2>&1 && echo "available" || echo "NOT FOUND — apt install file")"
  echo ""
  if [[ -f "$LOG_FILE" ]]; then
    echo "--- Last 15 log entries ---"
    tail -15 "$LOG_FILE"
  else
    echo "(No log file yet at $LOG_FILE)"
  fi
}

# ── Dispatch ───────────────────────────────────────────────────────────────────
[[ $# -eq 0 ]] && usage

# Allow --log to be parsed before subcommand (e.g., file-warden.sh --log /tmp/fw.log status)
if [[ "$1" == "--log" ]]; then
  LOG_FILE="$2"; shift 2
fi

case "${1:-}" in
  organize)
    shift
    log "Invoking organize-and-tag module..."
    bash "${WARDEN_DIR}/modules/organize-and-tag.sh" --log "$LOG_FILE" "$@"
    ;;

  fix-node|fix-node-env)
    shift
    log "Invoking fix-node-env module..."
    bash "${WARDEN_DIR}/modules/fix-node-env.sh" --log "$LOG_FILE" "$@"
    ;;

  status)
    cmd_status
    ;;

  --help|-h|help)
    usage
    ;;

  *)
    echo "Unknown subcommand: ${1:-}" >&2
    echo "Run '$0 --help' for usage." >&2
    exit 1
    ;;
esac
