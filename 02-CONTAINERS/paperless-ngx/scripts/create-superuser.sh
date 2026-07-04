#!/usr/bin/env bash
# Creates the initial Paperless-NGX admin user.
# Run once after deploy.sh, when the paperless.service is healthy.
set -euo pipefail

ENV_FILE="/etc/paperless/paperless.env"

if [ ! -f "${ENV_FILE}" ]; then
  echo "ERROR: ${ENV_FILE} not found. Run deploy.sh first."
  exit 1
fi

# shellcheck source=/dev/null
source "${ENV_FILE}"

echo "==> Creating admin user '${PAPERLESS_ADMIN_USER}'..."

podman exec -it paperless \
  python manage.py createsuperuser \
  --noinput \
  --username "${PAPERLESS_ADMIN_USER}" \
  --email "${PAPERLESS_ADMIN_MAIL}" \
  || true   # may already exist

# Set the password via shell
podman exec paperless \
  python manage.py shell -c "
from django.contrib.auth.models import User
u, created = User.objects.get_or_create(username='${PAPERLESS_ADMIN_USER}')
u.email = '${PAPERLESS_ADMIN_MAIL}'
u.set_password('${PAPERLESS_ADMIN_PASSWORD}')
u.is_staff = True
u.is_superuser = True
u.save()
print('User', u.username, 'saved. Created:', created)
"

echo ""
echo "==> Admin user ready."
echo "    Login:  https://paperless.shannonjlove.cloud"
echo "    User:   ${PAPERLESS_ADMIN_USER}"
echo ""
echo "==> After login, get your API token:"
echo "    Settings → API Token"
echo "    Then add it to ${ENV_FILE}:  PAPERLESS_API_TOKEN=<token>"
echo "    Then run: scripts/seed-para-tags.sh"
