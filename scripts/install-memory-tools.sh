#!/usr/bin/env bash
# =============================================================================
# install-memory-tools.sh
# Run this script directly on Nexus to deploy the full memory platform.
# It pulls the latest code first, then runs each step in order.
#
# On sOs (ARM64), run manually after this completes:
#   bash scripts/deploy-shared-context-sos-webtop.sh
# =============================================================================
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

echo "==> Pulling latest from main"
git pull origin main

echo ""
echo "==> Step 0: Deploy memory-agent v2"
bash scripts/deploy-memory-agent-v2.sh

echo ""
echo "==> Step 1: Deploy shared context + claude-memory (NFS, venv)"
bash scripts/deploy-shared-context-nexus.sh

echo ""
echo "==> Step 3: Configure NPM proxy host for memory.shannonjlove.cloud"
bash scripts/configure-npm-memory.sh

echo ""
echo "Done. On sOs, run: bash scripts/deploy-shared-context-sos-webtop.sh"
