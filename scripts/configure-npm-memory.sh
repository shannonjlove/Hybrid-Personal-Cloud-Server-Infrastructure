#!/usr/bin/env bash
# =============================================================================
# configure-npm-memory.sh
# Creates the memory.shannonjlove.cloud proxy host in Nginx Proxy Manager
# via its REST API, requests a Let's Encrypt certificate, and enables SSL.
#
# Reads credentials from environment or .env file — never hardcoded.
#
# Usage:
#   # Export credentials first (or let the script load them from .env):
#   export NPM_EMAIL="admin@shannonjlove.cloud"
#   export NPM_PASSWORD="your-npm-password"
#   bash scripts/configure-npm-memory.sh
#
# Environment variables:
#   NPM_URL       NPM base URL          (default: http://localhost:81)
#   NPM_EMAIL     NPM admin email       (required)
#   NPM_PASSWORD  NPM admin password    (required)
#   DOMAIN        Domain to configure   (default: memory.shannonjlove.cloud)
#   UPSTREAM_HOST Upstream host         (default: 127.0.0.1)
#   UPSTREAM_PORT Upstream port         (default: 9077)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "${SCRIPT_DIR}")"

# Load .env if present and variables not already set
if [[ -f "${REPO_ROOT}/.env" ]]; then
  set -o allexport
  # shellcheck disable=SC1091
  source "${REPO_ROOT}/.env"
  set +o allexport
fi

NPM_URL="${NPM_URL:-http://shannonjlove.tail179603.ts.net:81}"
DOMAIN="${DOMAIN:-memory.shannonjlove.cloud}"
UPSTREAM_HOST="${UPSTREAM_HOST:-127.0.0.1}"
UPSTREAM_PORT="${UPSTREAM_PORT:-9077}"

# -----------------------------------------------------------------------------
# Validate required credentials
# -----------------------------------------------------------------------------
if [[ -z "${NPM_EMAIL:-}" || -z "${NPM_PASSWORD:-}" ]]; then
  echo "ERROR: NPM_EMAIL and NPM_PASSWORD must be set."
  echo "  Export them or add them to .env (which is gitignored)."
  exit 1
fi

if ! command -v jq &>/dev/null; then
  echo "ERROR: jq is required. Install it with: apt install jq  or  brew install jq"
  exit 1
fi

# -----------------------------------------------------------------------------
# Wait for NPM to be reachable
# -----------------------------------------------------------------------------
echo "==> Waiting for NPM at ${NPM_URL}..."
for i in {1..30}; do
  if curl -sf "${NPM_URL}/api/" -o /dev/null 2>/dev/null; then
    echo "    NPM is up."
    break
  fi
  if [[ $i -eq 30 ]]; then
    echo "ERROR: NPM did not become reachable at ${NPM_URL} after 60 seconds."
    exit 1
  fi
  sleep 2
done

# -----------------------------------------------------------------------------
# Authenticate — get bearer token
# -----------------------------------------------------------------------------
echo "==> Authenticating with NPM..."
AUTH_RESPONSE=$(curl -sf -X POST "${NPM_URL}/api/tokens" \
  -H "Content-Type: application/json" \
  -d "{\"identity\":\"${NPM_EMAIL}\",\"secret\":\"${NPM_PASSWORD}\"}")

TOKEN=$(echo "${AUTH_RESPONSE}" | jq -r '.token // empty')
if [[ -z "${TOKEN}" ]]; then
  echo "ERROR: Authentication failed. Check NPM_EMAIL and NPM_PASSWORD."
  echo "       Response: ${AUTH_RESPONSE}"
  exit 1
fi
echo "    Authenticated."

# Convenience wrapper for authenticated API calls
npm_api() {
  local method="$1"; shift
  local path="$1"; shift
  curl -sf -X "${method}" "${NPM_URL}/api${path}" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    "$@"
}

# -----------------------------------------------------------------------------
# Check for existing proxy host — make this idempotent
# -----------------------------------------------------------------------------
echo "==> Checking for existing proxy host for ${DOMAIN}..."
EXISTING=$(npm_api GET "/nginx/proxy-hosts" | \
  jq -r --arg domain "${DOMAIN}" \
  '[.[] | select(.domain_names[] == $domain)] | first | .id // empty')

if [[ -n "${EXISTING}" ]]; then
  echo "    Proxy host already exists (id=${EXISTING}). Checking SSL..."
  CERT_ID=$(npm_api GET "/nginx/proxy-hosts/${EXISTING}" | jq -r '.certificate_id // 0')
  if [[ "${CERT_ID}" != "0" && "${CERT_ID}" != "null" ]]; then
    echo "    SSL already configured. Nothing to do."
    exit 0
  fi
  PROXY_ID="${EXISTING}"
  CREATED=false
else
  CREATED=true
fi

# -----------------------------------------------------------------------------
# Create proxy host (HTTP first, SSL added after cert is issued)
# -----------------------------------------------------------------------------
if [[ "${CREATED}" == "true" ]]; then
  echo "==> Creating proxy host ${DOMAIN} → ${UPSTREAM_HOST}:${UPSTREAM_PORT}..."
  CREATE_RESPONSE=$(npm_api POST "/nginx/proxy-hosts" -d "$(cat <<JSON
{
  "domain_names": ["${DOMAIN}"],
  "forward_scheme": "http",
  "forward_host": "${UPSTREAM_HOST}",
  "forward_port": ${UPSTREAM_PORT},
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

  PROXY_ID=$(echo "${CREATE_RESPONSE}" | jq -r '.id // empty')
  if [[ -z "${PROXY_ID}" ]]; then
    echo "ERROR: Failed to create proxy host."
    echo "       Response: ${CREATE_RESPONSE}"
    exit 1
  fi
  echo "    Proxy host created (id=${PROXY_ID})."
fi

# -----------------------------------------------------------------------------
# Request Let's Encrypt certificate
# -----------------------------------------------------------------------------
echo "==> Requesting Let's Encrypt certificate for ${DOMAIN}..."
CERT_RESPONSE=$(npm_api POST "/nginx/certificates" -d "$(cat <<JSON
{
  "provider": "letsencrypt",
  "domain_names": ["${DOMAIN}"],
  "meta": {
    "letsencrypt_agree": true,
    "dns_challenge": false
  }
}
JSON
)")

CERT_ID=$(echo "${CERT_RESPONSE}" | jq -r '.id // empty')
if [[ -z "${CERT_ID}" ]]; then
  echo "ERROR: Certificate request failed."
  echo "       Response: ${CERT_RESPONSE}"
  echo "       Make sure ${DOMAIN} resolves to this server's public IP."
  exit 1
fi
echo "    Certificate issued (id=${CERT_ID})."

# -----------------------------------------------------------------------------
# Update proxy host with certificate and enable SSL + HSTS
# -----------------------------------------------------------------------------
echo "==> Enabling SSL on proxy host ${PROXY_ID}..."
UPDATE_RESPONSE=$(npm_api PUT "/nginx/proxy-hosts/${PROXY_ID}" -d "$(cat <<JSON
{
  "domain_names": ["${DOMAIN}"],
  "forward_scheme": "http",
  "forward_host": "${UPSTREAM_HOST}",
  "forward_port": ${UPSTREAM_PORT},
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

UPDATED_ID=$(echo "${UPDATE_RESPONSE}" | jq -r '.id // empty')
if [[ -z "${UPDATED_ID}" ]]; then
  echo "ERROR: Failed to update proxy host with SSL."
  echo "       Response: ${UPDATE_RESPONSE}"
  exit 1
fi

# -----------------------------------------------------------------------------
# Done
# -----------------------------------------------------------------------------
echo ""
echo "==> NPM proxy host configured successfully."
echo ""
echo "    Domain    : https://${DOMAIN}"
echo "    Upstream  : ${UPSTREAM_HOST}:${UPSTREAM_PORT}"
echo "    Cert ID   : ${CERT_ID}"
echo "    Proxy ID  : ${PROXY_ID}"
echo "    SSL       : forced, HTTP/2 enabled, HSTS on"
echo ""
echo "    Test: curl -sf https://${DOMAIN}/health | jq"
