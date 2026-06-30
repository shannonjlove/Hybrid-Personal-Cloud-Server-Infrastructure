#!/usr/bin/env bash
# Deploy config symlinks to a machine using GNU Stow.
#
# Usage:
#   ./scripts/stow-deploy.sh           # auto-detects entity from hostname
#   ./scripts/stow-deploy.sh vps       # explicit
#   ./scripts/stow-deploy.sh oracle
#   ./scripts/stow-deploy.sh webtop
#   ./scripts/stow-deploy.sh --delete  # remove symlinks (stow -D)
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
STOW_DIR="$REPO_DIR/stow"
TARGET="${HOME}"
ACTION="--stow"

# Parse flags
ENTITY=""
for arg in "$@"; do
    case "$arg" in
        --delete|-D) ACTION="--delete" ;;
        --restow|-R) ACTION="--restow" ;;
        vps|oracle|webtop) ENTITY="$arg" ;;
        *) echo "Unknown argument: $arg"; exit 1 ;;
    esac
done

# Auto-detect entity from hostname if not supplied
if [ -z "$ENTITY" ]; then
    HOST="$(hostname -s 2>/dev/null || hostname)"
    case "$HOST" in
        *vps*|*hostinger*)  ENTITY="vps" ;;
        *oracle*|*oci*)     ENTITY="oracle" ;;
        *webtop*|*desktop*) ENTITY="webtop" ;;
        *)
            echo "Cannot auto-detect entity from hostname '$HOST'."
            echo "Pass one of: vps | oracle | webtop"
            exit 1
            ;;
    esac
    echo "==> Auto-detected entity: $ENTITY"
fi

if ! command -v stow &>/dev/null; then
    echo "ERROR: GNU Stow not found. Install with:"
    echo "  sudo apt install stow   # Debian/Ubuntu"
    echo "  sudo dnf install stow   # Fedora/RHEL"
    exit 1
fi

stow_package() {
    local pkg="$1"
    echo "==> stow $ACTION $pkg → $TARGET"
    stow "$ACTION" \
         --dir="$STOW_DIR" \
         --target="$TARGET" \
         --verbose=1 \
         "$pkg"
}

# Apply common first, then entity-specific
stow_package common
stow_package "$ENTITY"

echo ""
echo "Done. Symlinks from $TARGET → $STOW_DIR/{common,$ENTITY}"
