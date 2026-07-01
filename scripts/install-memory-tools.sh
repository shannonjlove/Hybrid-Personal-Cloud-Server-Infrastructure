#!/usr/bin/env bash
# =============================================================================
# install-memory-tools.sh
# DEPRECATED — replaced by targeted deploy scripts. This wrapper runs them in order.
#
# Usage:
#   # On Nexus (x86_64):
#   bash scripts/deploy-memory-agent-nexus.sh
#   bash scripts/deploy-shared-context-nexus.sh
#   bash scripts/configure-npm-memory.sh
#
#   # On sOs (ARM64):
#   bash scripts/deploy-shared-context-sos-webtop.sh
#
# This file remains for backwards compatibility and runs the correct subset
# based on the detected architecture.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARCH="$(uname -m)"

if [[ "${ARCH}" == "aarch64" || "${ARCH}" == "arm64" ]]; then
  echo "==> Detected ARM64 — running sOs deployment"
  echo "    Ensure Nexus Steps 0-1 are complete before running this."
  bash "${SCRIPT_DIR}/deploy-shared-context-sos-webtop.sh"
else
  echo "==> Detected x86_64 — running Nexus deployment (Steps 0, 1, 3)"
  bash "${SCRIPT_DIR}/deploy-memory-agent-nexus.sh"
  bash "${SCRIPT_DIR}/deploy-shared-context-nexus.sh"
  bash "${SCRIPT_DIR}/configure-npm-memory.sh"
fi
