#!/usr/bin/env bash
# configure-npm-memory.sh
# Creates the NPM (Nginx Proxy Manager) proxy host for the memory layer:
#   https://memory.shannonjlove.cloud  →  100.115.66.75:8100  (memory-agent)
#
# DNS is already handled — shannonjlove.cloud has a wildcard `*` A record to
# 72.61.74.250, confirmed live via Hostinger DNS. Nothing to add there.
#
# Intended to be run via Claude Code on Nexus. Reads NPM_EMAIL, NPM_PASSWORD,
# NPM_URL from .env if present in the current or parent directory, otherwise
# from the environment. Idempotent — safe to re-run.

set -euo pipefail

MEMORY_TARGET_HOST="${MEMORY_TARGET_HOST:-100.115.66.75}"
MEMORY_TARGET_PORT="${MEMORY_TARGET_PORT:-8100}"
NPM_DOMAIN="${NPM_DOMAIN:-memory.shannonjlove.cloud}"

# Locate and source .env if present (current dir, then parent)
for candidate in "./.env" "../.env"; do
  if [[ -f "${candidate}" ]]; then
    echo "==> Sourcing ${candidate}"
    set -o allexport
    # shellcheck disable=SC1090
    source "${candidate}"
    set +o allexport
    break
  fi
done

NPM_URL="${NPM_URL:-http://shannonjlove.tail179603.ts.net:81}"

if [[ -z "${NPM_EMAIL:-}" || -z "${NPM_PASSWORD:-}" ]]; then
  echo "ERROR: NPM_EMAIL and NPM_PASSWORD must be set (via .env or environment)."
  exit 1
fi

if ! command -v jq &>/dev/null; then
  echo "ERROR: jq is required. Install with: apt-get install -y jq"
  exit 1
fi

# -----------------------------------------------------------------------------
# Pre-flight: confirm memory-agent is actually up before proxying to it
# -----------------------------------------------------------------------------
echo "==> Checking memory-agent health at ${MEMORY_TARGET_HOST}:${MEMORY_TARGET_PORT}..."
if ! curl -fsS "http://${MEMORY_TARGET_HOST}:${MEMORY_TARGET_PORT}/healthz" >/dev/null; then
  echo "ERROR: memory-agent is not responding at ${MEMORY_TARGET_HOST}:${MEMORY_TARGET_PORT}/healthz."
  echo "       Fix that first (systemctl status memory-agent) — proceeding would publish a dead endpoint."
  exit 1
fi
echo "    OK — memory-agent is healthy."

# -----------------------------------------------------------------------------
# Authenticate with NPM
# -----------------------------------------------------------------------------
echo "==> Authenticating with NPM (${NPM_URL})..."
AUTH=$(curl -sf -X POST "${NPM_URL}/api/tokens" \
  -H "Content-Type: application/json" \
  -d "{\"identity\":\"${NPM_EMAIL}\",\"secret\":\"${NPM_PASSWORD}\"}")
TOKEN=$(echo "${AUTH}" | jq -r '.token // empty')
if [[ -z "${TOKEN}" ]]; then
  echo "ERROR: NPM authentication failed. Check NPM_EMAIL / NPM_PASSWORD."
  exit 1
fi

npm_api() {
  local method="$1"; shift
  local path="$1"; shift
  curl -sf -X "${method}" "${NPM_URL}/api${path}" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    "$@"
}

# -----------------------------------------------------------------------------
# Idempotency check
# -----------------------------------------------------------------------------
echo "==> Checking for existing proxy host for ${NPM_DOMAIN}..."
EXISTING=$(npm_api GET "/nginx/proxy-hosts" | \
  jq -r --arg d "${NPM_DOMAIN}" '[.[] | select(.domain_names[] == $d)] | first | .id // empty')

if [[ -n "${EXISTING}" ]]; then
  CERT_ID=$(npm_api GET "/nginx/proxy-hosts/${EXISTING}" | jq -r '.certificate_id // 0')
  if [[ "${CERT_ID}" != "0" && "${CERT_ID}" != "null" ]]; then
    echo "    ${NPM_DOMAIN} already configured with SSL. Nothing to do."
    echo "    Live at: https://${NPM_DOMAIN}"
    exit 0
  fi
  PROXY_ID="${EXISTING}"
  CREATED=false
else
  CREATED=true
fi

# -----------------------------------------------------------------------------
# Create proxy host (HTTP first, SSL added after cert issuance)
# -----------------------------------------------------------------------------
if [[ "${CREATED}" == "true" ]]; then
  echo "==> Creating proxy host ${NPM_DOMAIN} → ${MEMORY_TARGET_HOST}:${MEMORY_TARGET_PORT}..."
  CREATE=$(npm_api POST "/nginx/proxy-hosts" -d "$(cat <<JSON
{
  "domain_names": ["${NPM_DOMAIN}"],
  "forward_scheme": "http",
  "forward_host": "${MEMORY_TARGET_HOST}",
  "forward_port": ${MEMORY_TARGET_PORT},
  "access_list_id": 0,
  "certificate_id": 0,
  "ssl_forced": false,
  "block_exploits": true,
  "allow_websocket_upgrade": true,
  "http2_support": false,
  "enabled": true,
  "locations": [],
  "hsts_enabled": false,
  "hsts_subdomains": false,
  "meta": {
    "letsencrypt_agree": false,
    "dns_challenge": false
  }
}
JSON
)")
  PROXY_ID=$(echo "${CREATE}" | jq -r '.id // empty')
  if [[ -z "${PROXY_ID}" ]]; then
    echo "ERROR: Failed to create proxy host. Response: ${CREATE}"
    exit 1
  fi
  echo "    Proxy host created (id=${PROXY_ID})."
fi

# -----------------------------------------------------------------------------
# Request Let's Encrypt certificate
# -----------------------------------------------------------------------------
echo "==> Requesting Let's Encrypt certificate for ${NPM_DOMAIN}..."
CERT=$(npm_api POST "/nginx/certificates" -d "$(cat <<JSON
{
  "provider": "letsencrypt",
  "domain_names": ["${NPM_DOMAIN}"],
  "meta": {
    "letsencrypt_agree": true,
    "dns_challenge": false
  }
}
JSON
)")
CERT_ID=$(echo "${CERT}" | jq -r '.id // empty')
if [[ -z "${CERT_ID}" ]]; then
  echo "ERROR: Certificate request failed. Response: ${CERT}"
  exit 1
fi
echo "    Certificate issued (id=${CERT_ID})."

# -----------------------------------------------------------------------------
# Update proxy host with SSL enforced
# -----------------------------------------------------------------------------
echo "==> Enabling SSL on ${NPM_DOMAIN}..."
UPDATE=$(npm_api PUT "/nginx/proxy-hosts/${PROXY_ID}" -d "$(cat <<JSON
{
  "domain_names": ["${NPM_DOMAIN}"],
  "forward_scheme": "http",
  "forward_host": "${MEMORY_TARGET_HOST}",
  "forward_port": ${MEMORY_TARGET_PORT},
  "access_list_id": 0,
  "certificate_id": ${CERT_ID},
  "ssl_forced": true,
  "block_exploits": true,
  "allow_websocket_upgrade": true,
  "http2_support": true,
  "enabled": true,
  "locations": [],
  "hsts_enabled": true,
  "hsts_subdomains": false,
  "meta": {
    "letsencrypt_agree": true,
    "dns_challenge": false
  }
}
JSON
)")
UPDATED_ID=$(echo "${UPDATE}" | jq -r '.id // empty')
if [[ -z "${UPDATED_ID}" ]]; then
  echo "ERROR: Failed to enable SSL. Response: ${UPDATE}"
  exit 1
fi

# -----------------------------------------------------------------------------
# Verify end-to-end
# -----------------------------------------------------------------------------
echo "==> Verifying public endpoint..."
sleep 2
if curl -fsS "https://${NPM_DOMAIN}/healthz" >/dev/null 2>&1; then
  echo "    OK — https://${NPM_DOMAIN}/healthz responding."
else
  echo "    NOTE: not responding yet — cert/propagation can take a minute. Retry:"
  echo "    curl -s https://${NPM_DOMAIN}/healthz"
fi

echo ""
echo "==> Done."
echo "    memory.shannonjlove.cloud → ${MEMORY_TARGET_HOST}:${MEMORY_TARGET_PORT} (memory-agent)"
echo "    SSL: forced, HTTP/2, HSTS"
echo ""
echo "    Test:"
echo "    curl -s https://${NPM_DOMAIN}/chat -H 'Content-Type: application/json' \\"
echo "      -d '{\"message\":\"hello\",\"session_id\":\"test\"}'"
