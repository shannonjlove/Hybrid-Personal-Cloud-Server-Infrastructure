#!/usr/bin/env bash
# Build sjl-basic-memory image on Nexus (run as sjl)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE="localhost/sjl-basic-memory:latest"

echo "==> Building $IMAGE"
podman build -t "$IMAGE" "$SCRIPT_DIR"

echo "==> Creating memory directory (PARA path)"
mkdir -p /srv/sjl/070000_SYSTEM-AUTOMATION/079000_AGENT-CONTEXT/memory

echo "==> Stow and enable"
# From ~/quadlets-nexus (GNU Stow package root):
#   stow -t / nexus
# Then:
systemctl --user daemon-reload
systemctl --user enable --now sjl-basic-memory.service

echo ""
echo "==> Register with Claude Code (run once per machine):"
echo "    claude mcp add --transport stdio --scope user memory \\"
echo "      podman exec -i sjl-basic-memory uvx basic-memory mcp --home /memory"
echo ""
echo "Done."
