#!/usr/bin/env bash
# =============================================================================
# NPM Proxy Host Configurator
# Creates proxy hosts + Let's Encrypt SSL certs via the NPM REST API.
# Called automatically by deploy-all.sh, or run standalone after deploy.
#
# Overrideable env vars:
#   NPM_URL       (default: http://localhost:81)
#   NPM_EMAIL     (default: admin@example.com)
#   NPM_PASSWORD  (default: changeme  — change this after first login)
#   LE_EMAIL      (default: sjlove@shannonjeffreylove.com)
# =============================================================================
set -euo pipefail

NPM_URL="${NPM_URL:-http://localhost:81}"
NPM_EMAIL="${NPM_EMAIL:-admin@example.com}"
NPM_PASSWORD="${NPM_PASSWORD:-changeme}"
LE_EMAIL="${LE_EMAIL:-sjlove@shannonjeffreylove.com}"

# ── Dependencies ──────────────────────────────────────────────────────────────

command -v jq   &>/dev/null || { apt-get update -qq && apt-get install -y jq;   }
command -v curl &>/dev/null || { apt-get update -qq && apt-get install -y curl;  }

# ── Proxy hosts to configure ──────────────────────────────────────────────────
# Fields: domain   forward_host   forward_port

PROXY_HOSTS=(
  "paperless.shannonjlove.cloud  paperless   8000"
  "docs.shannonjlove.cloud       bookstack   6875"
  "photos.shannonjlove.cloud     photoprism  2342"
)

# ── API helpers ───────────────────────────────────────────────────────────────

npm_auth() {
  local resp
  resp=$(curl -sf -X POST "$NPM_URL/api/tokens" \
    -H 'Content-Type: application/json' \
    -d "{\"identity\":\"$NPM_EMAIL\",\"secret\":\"$NPM_PASSWORD\"}" 2>&1) || {
    echo "ERROR: NPM auth failed. Check NPM_EMAIL / NPM_PASSWORD."
    echo "       Response: $resp"
    exit 1
  }
  echo "$resp" | jq -r '.token'
}

npm_existing_host_id() {
  local token="$1" domain="$2"
  curl -sf "$NPM_URL/api/nginx/proxy-hosts" \
    -H "Authorization: Bearer $token" \
  | jq -r --arg d "$domain" '.[] | select(.domain_names[] == $d) | .id // empty'
}

npm_create_host() {
  local token="$1" domain="$2" host="$3" port="$4"
  curl -sf -X POST "$NPM_URL/api/nginx/proxy-hosts" \
    -H "Authorization: Bearer $token" \
    -H 'Content-Type: application/json' \
    -d "$(jq -n \
      --arg  domain "$domain" \
      --arg  host   "$host"   \
      --argjson port  "$port"   \
      '{
        domain_names:           [$domain],
        forward_scheme:         "http",
        forward_host:           $host,
        forward_port:           $port,
        access_list_id:         0,
        certificate_id:         0,
        ssl_forced:             false,
        block_exploits:         true,
        allow_websocket_upgrade: true,
        enabled:                true,
        meta:                   {}
      }')" \
  | jq -r '.id'
}

npm_request_cert() {
  local token="$1" domain="$2"
  local resp
  resp=$(curl -sf -X POST "$NPM_URL/api/nginx/certificates" \
    -H "Authorization: Bearer $token" \
    -H 'Content-Type: application/json' \
    -d "$(jq -n \
      --arg domain "$domain" \
      --arg email  "$LE_EMAIL" \
      '{
        provider:     "letsencrypt",
        domain_names: [$domain],
        meta: {
          letsencrypt_email: $email,
          letsencrypt_agree: true,
          dns_challenge:     false
        }
      }')") || {
    echo "  ERROR: cert request failed for $domain"
    echo "         Response: $resp"
    echo "  Hint: ensure port 80 is open and $domain resolves to this server."
    return 1
  }
  echo "$resp" | jq -r '.id'
}

npm_enable_ssl() {
  local token="$1" host_id="$2" cert_id="$3"
  local current
  current=$(curl -sf "$NPM_URL/api/nginx/proxy-hosts/$host_id" \
    -H "Authorization: Bearer $token")

  echo "$current" \
  | jq --argjson cert "$cert_id" \
      '.certificate_id = $cert | .ssl_forced = true | .http2_support = true' \
  | curl -sf -X PUT "$NPM_URL/api/nginx/proxy-hosts/$host_id" \
      -H "Authorization: Bearer $token" \
      -H 'Content-Type: application/json' \
      -d @- \
  > /dev/null
}

# ── Wait for NPM ──────────────────────────────────────────────────────────────

wait_for_npm() {
  echo "==> Waiting for NPM API..."
  local attempts=0
  until curl -sf "$NPM_URL/api/" > /dev/null 2>&1; do
    attempts=$((attempts + 1))
    if [[ $attempts -ge 36 ]]; then
      echo "ERROR: NPM not reachable at $NPM_URL after 3 minutes."
      exit 1
    fi
    printf "  %d/36\r" "$attempts"
    sleep 5
  done
  echo "  NPM is ready."
}

# ── Main ──────────────────────────────────────────────────────────────────────

wait_for_npm

echo ""
echo "==> Authenticating..."
TOKEN=$(npm_auth)
echo "  OK"

CREATED=0
SKIPPED=0
FAILED=0

for entry in "${PROXY_HOSTS[@]}"; do
  read -r domain host port <<< "$entry"

  echo ""
  echo "==> $domain  →  http://$host:$port"

  existing=$(npm_existing_host_id "$TOKEN" "$domain")
  if [[ -n "$existing" ]]; then
    echo "  Already configured (ID: $existing) — skipping."
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  HOST_ID=$(npm_create_host "$TOKEN" "$domain" "$host" "$port")
  echo "  Proxy host created (ID: $HOST_ID)"

  echo "  Requesting Let's Encrypt cert (may take 60-90 s)..."
  if ! CERT_ID=$(npm_request_cert "$TOKEN" "$domain"); then
    FAILED=$((FAILED + 1))
    continue
  fi
  echo "  Certificate issued (ID: $CERT_ID)"

  npm_enable_ssl "$TOKEN" "$HOST_ID" "$CERT_ID"
  echo "  HTTPS + HTTP→HTTPS redirect enabled."
  CREATED=$((CREATED + 1))
done

echo ""
echo "==> Summary: $CREATED created, $SKIPPED skipped, $FAILED failed."
echo ""
if [[ $FAILED -eq 0 ]]; then
  echo "    https://paperless.shannonjlove.cloud"
  echo "    https://docs.shannonjlove.cloud"
  echo "    https://photos.shannonjlove.cloud"
fi
