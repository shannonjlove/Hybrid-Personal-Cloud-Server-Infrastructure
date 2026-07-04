#!/usr/bin/env bash
# =============================================================================
# Seeds Paperless-NGX with the PARA tag/type/correspondent structure.
# Run after deploy.sh and create-superuser.sh.
# Requires: PAPERLESS_URL and PAPERLESS_API_TOKEN in .env
# =============================================================================
set -euo pipefail

COMPOSE_DIR="$(cd "$(dirname "$0")/.." && pwd)"

if [ ! -f "${COMPOSE_DIR}/.env" ]; then
  echo "ERROR: .env not found."
  exit 1
fi

# shellcheck source=/dev/null
source "${COMPOSE_DIR}/.env"

BASE_URL="${PAPERLESS_URL:-https://paperless.shannonjlove.cloud}"
TOKEN="${PAPERLESS_API_TOKEN:?Set PAPERLESS_API_TOKEN in .env after first login}"

api_post() {
  local endpoint="$1"
  local data="$2"
  curl -sf \
    -H "Authorization: Token ${TOKEN}" \
    -H "Content-Type: application/json" \
    -X POST \
    -d "$data" \
    "${BASE_URL}/api/${endpoint}/" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('id','?'), d.get('name',''))"
}

echo "==> Creating PARA tags..."
# Primary PARA tags (colour hex codes for visual organisation)
api_post "tags" '{"name":"project","colour":"#e74c3c","is_inbox_tag":false}'
api_post "tags" '{"name":"area","colour":"#3498db","is_inbox_tag":false}'
api_post "tags" '{"name":"resource","colour":"#2ecc71","is_inbox_tag":false}'
api_post "tags" '{"name":"archive","colour":"#95a5a6","is_inbox_tag":false}'

echo ""
echo "==> Creating content-type tags..."
api_post "tags" '{"name":"legal","colour":"#8e44ad"}'
api_post "tags" '{"name":"finance","colour":"#f39c12"}'
api_post "tags" '{"name":"medical","colour":"#e74c3c"}'
api_post "tags" '{"name":"creative","colour":"#1abc9c"}'
api_post "tags" '{"name":"personal","colour":"#3498db"}'
api_post "tags" '{"name":"technical","colour":"#2c3e50"}'
api_post "tags" '{"name":"inbox","colour":"#e67e22","is_inbox_tag":true}'

echo ""
echo "==> Creating document types..."
api_post "document_types" '{"name":"Invoice","matching_algorithm":6}'
api_post "document_types" '{"name":"Contract","matching_algorithm":6}'
api_post "document_types" '{"name":"Receipt","matching_algorithm":6}'
api_post "document_types" '{"name":"Statement","matching_algorithm":6}'
api_post "document_types" '{"name":"Letter","matching_algorithm":6}'
api_post "document_types" '{"name":"Report","matching_algorithm":6}'
api_post "document_types" '{"name":"ID Document","matching_algorithm":6}'
api_post "document_types" '{"name":"Certificate","matching_algorithm":6}'
api_post "document_types" '{"name":"Policy","matching_algorithm":6}'
api_post "document_types" '{"name":"Manuscript","matching_algorithm":6}'

echo ""
echo "==> Seeding complete. Review tags at: ${BASE_URL}/tags/"
echo "    Configure auto-matching rules per document type in the web UI."
