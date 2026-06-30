#!/usr/bin/env bash
# Runs at WebTop container start via /config/custom-cont-init.d/
# Installs FFmpeg and ImageMagick — required by mcp-media-processor.
set -euo pipefail

if command -v ffmpeg &>/dev/null && command -v convert &>/dev/null; then
  exit 0
fi

echo "[init] Installing FFmpeg and ImageMagick for mcp-media-processor..."
apt-get update -qq
apt-get install -y --no-install-recommends ffmpeg imagemagick
echo "[init] ffmpeg $(ffmpeg -version 2>&1 | head -1)"
echo "[init] ImageMagick $(convert --version | head -1)"
