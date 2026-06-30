#!/usr/bin/env bash
# =============================================================================
# configure-npm-public.sh
# Creates a public HTTPS proxy host for the NPM admin UI itself:
#   https://npm.shannonjlove.cloud → 127.0.0.1:81
#
# NPM proxies itself — no extra services needed.
# Called automatically by install-memory-tools.sh on Nexus (x86_64).
#
# Usage:
#   bash scripts/configure-npm-public.sh
#
# Reads NPM_EMAIL, NPM_PASSWORD, NPM_URL from .env or environment.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "${SCRIPT_DIR}")"

if [[ -f "${REPO_ROOT}/.env" ]]; then
  set -o allexport
  source "${REPO_ROOT}/.env"
  set +o allexport
fi

NPM_URL="${NPM_URL:-http://shannonjlove.tail179603.ts.net:81}"
NPM_DOMAIN="${NPM_DOMAIN:-npm.shannonjlove.cloud}"
NPM_UPSTREAM_PORT="${NPM_UPSTREAM_PORT:-81}"

if [[ -z "${NPM_EMAIL:-}" || -z "${NPM_PASSWORD:-}" ]]; then
  echo "ERROR: NPM_EMAIL and NPM_PASSWORD must be set in .env or environment."
  exit 1
fi

if ! command -v jq &>/dev/null; then
  echo "ERROR: jq is required. Install with: apt install jq"
  exit 1
fi

# -----------------------------------------------------------------------------
# Authenticate
# -----------------------------------------------------------------------------
echo "==> Authenticating with NPM..."
AUTH=$(curl -sf -X POST "${NPM_URL}/api/tokens" \
  -H "Content-Type: application/json" \
  -d "{\"identity\":\"${NPM_EMAIL}\",\"secret\":\"${NPM_PASSWORD}\"}")
TOKEN=$(echo "${AUTH}" | jq -r '.token // empty')
if [[ -z "${TOKEN}" ]]; then
  echo "ERROR: Authentication failed. Check NPM_EMAIL / NPM_PASSWORD."
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
    echo "    Public NPM UI: https://${NPM_DOMAIN}"
    exit 0
  fi
  PROXY_ID="${EXISTING}"
  CREATED=false
else
  CREATED=true
fi

# -----------------------------------------------------------------------------
# Create proxy host (HTTP first)
# -----------------------------------------------------------------------------
if [[ "${CREATED}" == "true" ]]; then
  echo "==> Creating proxy host ${NPM_DOMAIN} → 127.0.0.1:${NPM_UPSTREAM_PORT}..."
  CREATE=$(npm_api POST "/nginx/proxy-hosts" -d "$(cat <<JSON
{
  "domain_names": ["${NPM_DOMAIN}"],
  "forward_scheme": "http",
  "forward_host": "127.0.0.1",
  "forward_port": ${NPM_UPSTREAM_PORT},
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
  echo "ERROR: Certificate request failed. Make sure ${NPM_DOMAIN} points to this server."
  echo "       Response: ${CERT}"
  exit 1
fi
echo "    Certificate issued (id=${CERT_ID})."

# -----------------------------------------------------------------------------
# Update proxy host with SSL
# -----------------------------------------------------------------------------
echo "==> Enabling SSL on ${NPM_DOMAIN}..."
UPDATE=$(npm_api PUT "/nginx/proxy-hosts/${PROXY_ID}" -d "$(cat <<JSON
{
  "domain_names": ["${NPM_DOMAIN}"],
  "forward_scheme": "http",
  "forward_host": "127.0.0.1",
  "forward_port": ${NPM_UPSTREAM_PORT},
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
# Done
# -----------------------------------------------------------------------------
echo ""
echo "==> NPM public access configured."
echo ""
echo "    Public UI  : https://${NPM_DOMAIN}"
echo "    Tailscale  : ${NPM_URL}"
echo "    Upstream   : 127.0.0.1:${NPM_UPSTREAM_PORT}"
echo "    SSL        : forced, HTTP/2, HSTS"
echo ""
echo "    SECURITY: ${NPM_DOMAIN} is publicly reachable."
echo "    Use a strong unique password and consider adding an access list"
echo "    in NPM (Dashboard → Access Lists) to restrict by IP if needed."
