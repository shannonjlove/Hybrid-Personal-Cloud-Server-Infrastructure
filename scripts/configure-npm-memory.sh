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
TAILSCALE_CIDR="${TAILSCALE_CIDR:-100.64.0.0/10}"
ACCESS_LIST_NAME="${ACCESS_LIST_NAME:-tailscale-only-memory}"

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
NPM_EMAIL="${NPM_EMAIL:-shannonjlove@mac.com}"

if [[ -z "${NPM_PASSWORD:-}" ]]; then
  read -r -s -p "NPM Password for ${NPM_EMAIL}: " NPM_PASSWORD
  echo
fi
if [[ -z "${NPM_PASSWORD:-}" ]]; then
  echo "ERROR: NPM_PASSWORD must be set."
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
AUTH=$(curl -s --max-time 10 -X POST "${NPM_URL}/api/tokens" \
  -H "Content-Type: application/json" \
  -d "{\"identity\":\"${NPM_EMAIL}\",\"secret\":\"${NPM_PASSWORD}\"}" 2>&1) || true
TOKEN=$(echo "${AUTH}" | jq -r '.token // empty' 2>/dev/null || true)
if [[ -z "${TOKEN}" ]]; then
  echo "ERROR: NPM authentication failed."
  echo "  URL:      ${NPM_URL}"
  echo "  Email:    ${NPM_EMAIL}"
  echo "  Response: ${AUTH}"
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
# Tailscale-only access list — this is what actually restricts
# memory.shannonjlove.cloud to "my cloud" only. Nothing else on Nexus (other
# public subdomains, other proxy hosts) is touched — scoped to this host only.
# -----------------------------------------------------------------------------
echo "==> Ensuring Tailscale-only access list '${ACCESS_LIST_NAME}' exists..."
ACCESS_LIST_ID=$(npm_api GET "/nginx/access-lists" | \
  jq -r --arg n "${ACCESS_LIST_NAME}" '[.[] | select(.name == $n)] | first | .id // empty')

if [[ -z "${ACCESS_LIST_ID}" ]]; then
  ACL_CREATE=$(npm_api POST "/nginx/access-lists" -d "$(cat <<JSON
{
  "name": "${ACCESS_LIST_NAME}",
  "satisfy_any": true,
  "pass_auth": false,
  "items": [],
  "clients": [
    { "address": "${TAILSCALE_CIDR}", "directive": "allow" },
    { "address": "0.0.0.0/0", "directive": "deny" }
  ]
}
JSON
)")
  ACCESS_LIST_ID=$(echo "${ACL_CREATE}" | jq -r '.id // empty')
  if [[ -z "${ACCESS_LIST_ID}" ]]; then
    echo "ERROR: Failed to create access list. Response: ${ACL_CREATE}"
    exit 1
  fi
  echo "    Created access list (id=${ACCESS_LIST_ID}): allow ${TAILSCALE_CIDR}, deny everything else."
else
  echo "    Access list already exists (id=${ACCESS_LIST_ID})."
fi

# -----------------------------------------------------------------------------
# Idempotency check
# -----------------------------------------------------------------------------
echo "==> Checking for existing proxy host for ${NPM_DOMAIN}..."
EXISTING=$(npm_api GET "/nginx/proxy-hosts" | \
  jq -r --arg d "${NPM_DOMAIN}" '[.[] | select(.domain_names[] == $d)] | first | .id // empty')

if [[ -n "${EXISTING}" ]]; then
  EXISTING_HOST=$(npm_api GET "/nginx/proxy-hosts/${EXISTING}")
  CERT_ID=$(echo "${EXISTING_HOST}" | jq -r '.certificate_id // 0')
  EXISTING_ACL=$(echo "${EXISTING_HOST}" | jq -r '.access_list_id // 0')

  if [[ "${CERT_ID}" != "0" && "${CERT_ID}" != "null" ]]; then
    if [[ "${EXISTING_ACL}" == "${ACCESS_LIST_ID}" ]]; then
      echo "    ${NPM_DOMAIN} already configured with SSL and the Tailscale-only access list. Nothing to do."
      echo "    Live at: https://${NPM_DOMAIN} (Tailscale-only)"
      exit 0
    fi
    echo "    ${NPM_DOMAIN} already has SSL but access_list_id=${EXISTING_ACL} (expected ${ACCESS_LIST_ID})."
    echo "    Patching access list only — leaving cert/forward config as-is."
    PATCH=$(npm_api PUT "/nginx/proxy-hosts/${EXISTING}" -d "{\"access_list_id\": ${ACCESS_LIST_ID}}")
    if [[ -z "$(echo "${PATCH}" | jq -r '.id // empty')" ]]; then
      echo "ERROR: Failed to patch access_list_id. Response: ${PATCH}"
      exit 1
    fi
    echo "    Done — ${NPM_DOMAIN} is now Tailscale-only."
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
  "access_list_id": ${ACCESS_LIST_ID},
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
  "access_list_id": ${ACCESS_LIST_ID},
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
# Verify
# -----------------------------------------------------------------------------
echo "==> Verifying memory-agent is reachable behind the proxy (via direct Tailscale IP)..."
sleep 2
if curl -fsS "http://${MEMORY_TARGET_HOST}:${MEMORY_TARGET_PORT}/healthz" >/dev/null 2>&1; then
  echo "    OK — memory-agent itself is healthy."
else
  echo "    WARNING — memory-agent did not respond directly. Check: systemctl status memory-agent"
fi

echo ""
echo "==> Done."
echo "    memory.shannonjlove.cloud → ${MEMORY_TARGET_HOST}:${MEMORY_TARGET_PORT} (memory-agent)"
echo "    SSL: forced, HTTP/2, HSTS"
echo "    Access: restricted to ${TAILSCALE_CIDR} via NPM access list '${ACCESS_LIST_NAME}'"
echo ""
echo "    NOTE: do NOT verify the public-domain restriction by curling"
echo "    https://${NPM_DOMAIN} from Nexus itself — same-host NAT hairpin can"
echo "    make the request look local regardless of the access list, giving a"
echo "    false pass/fail either way. Test from an actual Tailscale-connected"
echo "    client (your iPhone on Tailscale, or from sOs):"
echo "      curl -s https://${NPM_DOMAIN}/healthz"
echo "    And confirm it's actually blocked from off-network (e.g. cellular"
echo "    data with Tailscale off) — expect a 403 or connection refusal."
echo ""
echo "    Test (from a Tailscale-connected client):"
echo "    curl -s https://${NPM_DOMAIN}/chat -H 'Content-Type: application/json' \\"
echo "      -d '{\"message\":\"hello\",\"session_id\":\"test\"}'"

