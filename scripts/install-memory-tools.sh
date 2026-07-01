#!/usr/bin/env bash
# =============================================================================
# install-memory-tools.sh
# Wrapper that runs the correct deploy script for the current host.
#
# Two-script deployment — no API key required:
#   Nexus:  bash scripts/deploy-shared-context-nexus.sh
#   sOs:    bash scripts/deploy-shared-context-sos-webtop.sh
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARCH="$(uname -m)"

if [[ "${ARCH}" == "aarch64" || "${ARCH}" == "arm64" ]]; then
  echo "==> Detected ARM64 — running sOs deployment"
  echo "    Ensure Nexus deploy-shared-context-nexus.sh completed first."
  bash "${SCRIPT_DIR}/deploy-shared-context-sos-webtop.sh"
else
  echo "==> Detected x86_64 — running Nexus deployment"
  bash "${SCRIPT_DIR}/deploy-shared-context-nexus.sh"
fi
