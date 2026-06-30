#!/usr/bin/env bash
# Runs inside the WebTop container on first start.
# Installs the 'tag' command — a Linux xattr wrapper that mirrors the
# jdberry/tag (macOS) interface so tagging workflows are portable.

set -euo pipefail

TAG_BIN="/usr/local/bin/tag"

if [[ -f "$TAG_BIN" ]]; then
  echo "[tag-init] tag already installed, skipping"
  exit 0
fi

# Install xattr tooling (attr package provides getfattr/setfattr)
apt-get update -qq
apt-get install -y -qq attr python3 git build-essential

# Clone jdberry/tag for reference / macOS build documentation
TAG_SRC="/opt/jdberry-tag"
if [[ ! -d "$TAG_SRC" ]]; then
  git clone --depth 1 https://github.com/jdberry/tag.git "$TAG_SRC"
fi

# Install the Linux-native tag wrapper (xattr-backed, same CLI surface)
cat > "$TAG_BIN" << 'TAGSCRIPT'
#!/usr/bin/env python3
"""
tag – Linux xattr wrapper mirroring jdberry/tag (macOS) CLI interface.
Tags are stored in the user.tag xattr namespace.
Usage mirrors the macOS `tag` command.
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
        subprocess.run(
            ["setfattr", "-n", XATTR_KEY, "-v", ",".join(tags), path],
            check=True
        )
    else:
        subprocess.run(
            ["setfattr", "-x", XATTR_KEY, path],
            stderr=subprocess.DEVNULL
        )

def main():
    parser = argparse.ArgumentParser(
        prog="tag",
        description="Manage file tags via extended attributes (jdberry/tag-compatible)"
    )
    sub = parser.add_subparsers(dest="cmd")

    a = sub.add_parser("add",     help="Add tags to files")
    a.add_argument("tags");  a.add_argument("files", nargs="+")

    r = sub.add_parser("remove",  help="Remove tags from files")
    r.add_argument("tags");  r.add_argument("files", nargs="+")

    s = sub.add_parser("set",     help="Set (replace) tags on files")
    s.add_argument("tags");  s.add_argument("files", nargs="+")

    sub.add_parser("clear",   help="Remove all tags").add_argument("files", nargs="+")
    sub.add_parser("list",    help="List tags on files").add_argument("files", nargs="+")
    sub.add_parser("find",    help="Find files with tag").add_argument("tag")

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
            label = ",".join(tags) if tags else "(no tags)"
            print(f"{f}\t{label}")

    elif args.cmd == "find":
        # Search current directory tree
        for root, dirs, files in os.walk("."):
            for name in files:
                path = os.path.join(root, name)
                if args.tag in get_tags(path):
                    print(path)

    else:
        parser.print_help()
        sys.exit(1)

if __name__ == "__main__":
    main()
TAGSCRIPT

chmod +x "$TAG_BIN"
echo "[tag-init] tag command installed at $TAG_BIN"
