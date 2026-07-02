#!/usr/bin/env bash
# Installs system + Python dependencies for the SJL metadata assessment pipeline.
# Run as root on the VPS once before first pipeline execution.
set -Eeuo pipefail

log() { printf '[%s] %s\n' "$(date -u +%H:%M:%SZ)" "$*"; }

if [[ "$EUID" -ne 0 ]]; then
  echo "ERROR: must run as root" >&2; exit 1
fi

log "Updating apt cache..."
apt-get update -qq

log "Installing system tools..."
apt-get install -y --no-install-recommends \
  exiftool \
  ffmpeg \
  tesseract-ocr \
  tesseract-ocr-eng \
  ocrmypdf \
  libmagic1 \
  libaubio5 \
  libaubio-dev \
  python3-pip \
  python3-venv

log "Creating Python venv at /opt/sjl-metadata-pipeline..."
python3 -m venv /opt/sjl-metadata-pipeline
source /opt/sjl-metadata-pipeline/bin/activate

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
log "Installing Python dependencies..."
pip install -q --upgrade pip
pip install -q -r "$SCRIPT_DIR/215000_2026-07-01__SJL-METADATA-PIPELINE__requirements.txt"

log "Verifying installs..."
python3 -c "import mutagen; import fitz; import aubio; print('Python deps OK')"
command -v ffprobe && echo "ffprobe OK"
command -v exiftool && echo "exiftool OK"
command -v ocrmypdf && echo "ocrmypdf OK"
command -v tesseract && tesseract --version 2>&1 | head -1

log "=== Install complete ==="
log "Activate venv: source /opt/sjl-metadata-pipeline/bin/activate"
log "Run pipeline:  python3 $SCRIPT_DIR/215000_2026-07-01__SJL-METADATA-PIPELINE__assess-and-tag__v1-0.py --help"
