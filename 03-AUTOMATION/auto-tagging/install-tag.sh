#!/usr/bin/env bash
# =============================================================================
# tag – Cross-platform install script
#   macOS  → builds jdberry/tag from source (or installs via Homebrew)
#   Linux  → installs attr package + the xattr-backed tag wrapper
#            (same wrapper deployed inside WebTop via custom-cont-init.d)
# =============================================================================

set -euo pipefail

OS="$(uname -s)"

install_macos() {
  echo "==> Detected macOS"

  if command -v brew &>/dev/null; then
    echo "==> Installing via Homebrew"
    brew install tag
    echo "==> Done. Run: tag --help"
    return
  fi

  echo "==> Homebrew not found — building from source"
  TMP_DIR="$(mktemp -d)"
  git clone --depth 1 https://github.com/jdberry/tag.git "$TMP_DIR/tag"
  cd "$TMP_DIR/tag"

  # Requires Xcode Command Line Tools
  if ! xcode-select -p &>/dev/null; then
    echo "ERROR: Xcode Command Line Tools required. Run: xcode-select --install"
    exit 1
  fi

  make
  sudo cp tag /usr/local/bin/tag
  echo "==> tag installed to /usr/local/bin/tag"
  rm -rf "$TMP_DIR"
}

install_linux() {
  echo "==> Detected Linux"
  sudo apt-get update -qq
  sudo apt-get install -y -qq attr python3 git

  TAG_BIN="/usr/local/bin/tag"
  TAG_SRC="/opt/jdberry-tag"

  if [[ ! -d "$TAG_SRC" ]]; then
    echo "==> Cloning jdberry/tag source reference to $TAG_SRC"
    sudo git clone --depth 1 https://github.com/jdberry/tag.git "$TAG_SRC"
  fi

  echo "==> Installing Linux xattr tag wrapper to $TAG_BIN"
  sudo tee "$TAG_BIN" > /dev/null << 'TAGSCRIPT'
#!/usr/bin/env python3
"""
tag – Linux xattr wrapper mirroring jdberry/tag (macOS) CLI interface.
Tags are stored in the user.tag xattr namespace.
"""
import sys, os, argparse, subprocess

XATTR_KEY = "user.tag"

def get_tags(path):
    try:
        out = subprocess.check_output(
            ["getfattr", "--only-values", "-n", XATTR_KEY, path],
            stderr=subprocess.DEVNULL
        ).decode().strip()
        return [t for t in out.split(",") if t]
    except subprocess.CalledProcessError:
        return []

def set_tags(path, tags):
    if tags:
        subprocess.run(["setfattr", "-n", XATTR_KEY, "-v", ",".join(tags), path], check=True)
    else:
        subprocess.run(["setfattr", "-x", XATTR_KEY, path], stderr=subprocess.DEVNULL)

def main():
    parser = argparse.ArgumentParser(
        prog="tag",
        description="Manage file tags via extended attributes (jdberry/tag-compatible)"
    )
    sub = parser.add_subparsers(dest="cmd")

    for cmd in ("add", "remove", "set"):
        p = sub.add_parser(cmd)
        p.add_argument("tags"); p.add_argument("files", nargs="+")

    sub.add_parser("clear").add_argument("files", nargs="+")
    sub.add_parser("list").add_argument("files", nargs="+")
    sub.add_parser("find").add_argument("tag")

    args = parser.parse_args()

    if args.cmd in ("add", "remove", "set"):
        new_tags = [t.strip() for t in args.tags.split(",") if t.strip()]
        for f in args.files:
            current = get_tags(f)
            if args.cmd == "add":
                merged = list(dict.fromkeys(current + new_tags))
            elif args.cmd == "remove":
                merged = [t for t in current if t not in new_tags]
            else:
                merged = new_tags
            set_tags(f, merged)

    elif args.cmd == "clear":
        for f in args.files:
            set_tags(f, [])

    elif args.cmd == "list":
        for f in args.files:
            tags = get_tags(f)
            print(f"{f}\t{','.join(tags) if tags else '(no tags)'}")

    elif args.cmd == "find":
        for root, dirs, files in os.walk("."):
            for name in files:
                path = os.path.join(root, name)
                if args.tag in get_tags(path):
                    print(path)
    else:
        parser.print_help(); sys.exit(1)

if __name__ == "__main__":
    main()
TAGSCRIPT

  sudo chmod +x "$TAG_BIN"
  echo "==> tag wrapper installed to $TAG_BIN"
}

case "$OS" in
  Darwin) install_macos ;;
  Linux)  install_linux  ;;
  *)
    echo "Unsupported OS: $OS"
    exit 1
    ;;
esac

echo ""
echo "Verify with: tag --help"
