#!/usr/bin/env bash
# =============================================================================
# install-memory-tools.sh
# Reference for run order. Execute each script manually in order — do not
# source this file directly as some steps have prerequisites.
#
# RUN ORDER (all on Nexus unless noted):
#   Step 0:  bash scripts/deploy-memory-agent-v2.sh
#              Deploys memory-agent v2 (plain file CRUD REST API, no API key)
#   Step 0b: bash scripts/deploy-local-agent.sh
#              Deploys local-agent (Ollama-backed /chat, zero cost)
#              Prerequisite: Ollama running + ollama pull qwen2.5:7b
#   Step 1:  bash scripts/deploy-shared-context-nexus.sh
#              NFS export, claude-memory, repoints memory-agent volume
#   Step 2:  (on sOs) bash scripts/deploy-shared-context-sos-webtop.sh
#              NFS mount, claude-memory, WebTop Quadlet
#   Step 3:  bash scripts/configure-npm-memory.sh
#              NPM proxy host for memory.shannonjlove.cloud (Tailscale-only)
#              Prerequisite: .env with NPM_EMAIL/NPM_PASSWORD/NPM_URL
# =============================================================================
echo "This script is a reference — run each step script individually."
echo ""
echo "On Nexus (x86_64):"
echo "  bash scripts/deploy-memory-agent-v2.sh"
echo "  bash scripts/deploy-local-agent.sh       # requires Ollama + qwen2.5:7b"
echo "  bash scripts/deploy-shared-context-nexus.sh"
echo "  bash scripts/configure-npm-memory.sh      # requires .env with NPM creds"
echo ""
echo "On sOs (ARM64), after Nexus completes:"
echo "  bash scripts/deploy-shared-context-sos-webtop.sh"
