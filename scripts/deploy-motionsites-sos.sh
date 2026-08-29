#!/usr/bin/env bash
# deploy-motionsites-sos.sh
# Deploys motionsites-prompt-collection as a Podman Quadlet on sOs (Oracle Cloud ARM64)
# Tailscale-only exposure for experimental/secondary workloads
#
# PREREQUISITE: Run on sOs with sudo (ubuntu user needs elevated permissions for systemd/apt)
# USAGE: sudo bash deploy-motionsites-sos.sh

set -euo pipefail

APP_NAME="motionsites-prompt-collection"
APP_DIR="/opt/${APP_NAME}"
QUADLET_DIR="/etc/containers/systemd"
TAILSCALE_IP="${TAILSCALE_IP:-100.67.229.94}"
BIND_PORT="${BIND_PORT:-8102}"
REPO_URL="https://github.com/shannonjlove/motionsites-prompt-collection.git"

echo "==> Deploying ${APP_NAME} to sOs (Tailscale-only)"
echo "    Target: ${TAILSCALE_IP}:${BIND_PORT}"
echo "    App directory: ${APP_DIR}"

# Check if running on sOs
if [[ ! -f /etc/hostname ]] || ! grep -qi "sOs\|ubuntu" /etc/hostname 2>/dev/null; then
  echo "WARNING: This script is designed for sOs (Oracle Cloud ARM64)."
  echo "         Current hostname: $(hostname)"
  read -p "Continue anyway? (y/N) " -n 1 -r
  echo
  [[ ! $REPLY =~ ^[Yy]$ ]] && exit 1
fi

# Ensure directories exist
mkdir -p "${APP_DIR}" "${QUADLET_DIR}"

echo "==> Cloning repository..."
if [[ -d "${APP_DIR}/.git" ]]; then
  echo "    Repository already exists, updating..."
  cd "${APP_DIR}" && git pull origin main || git pull origin master
else
  git clone "${REPO_URL}" "${APP_DIR}"
  cd "${APP_DIR}"
fi

echo "==> Detecting application type..."
# Check what kind of application this is
if [[ -f "package.json" ]]; then
  APP_TYPE="nodejs"
  echo "    Detected: Node.js application"
elif [[ -f "requirements.txt" ]]; then
  APP_TYPE="python"
  echo "    Detected: Python application"
elif [[ -f "Dockerfile" ]]; then
  APP_TYPE="docker"
  echo "    Detected: Dockerfile present"
else
  APP_TYPE="generic"
  echo "    Detected: Generic application (check repo for runtime requirements)"
fi

# Check if there's already a Containerfile/Dockerfile
if [[ -f "Containerfile" ]] || [[ -f "Dockerfile" ]]; then
  echo "==> Building container image from ${APP_TYPE}..."
  CONTAINERFILE=$(ls -1 Containerfile Dockerfile 2>/dev/null | head -1)
  podman build -t "localhost/${APP_NAME}:latest" -f "${CONTAINERFILE}" "${APP_DIR}"
else
  case "${APP_TYPE}" in
    nodejs)
      echo "==> Creating Node.js Containerfile..."
      cat > "${APP_DIR}/Containerfile" <<'EOF'
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
EXPOSE 8000
CMD ["npm", "start"]
EOF
      podman build -t "localhost/${APP_NAME}:latest" "${APP_DIR}"
      ;;
    python)
      echo "==> Creating Python Containerfile..."
      cat > "${APP_DIR}/Containerfile" <<'EOF'
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 8000
CMD ["python", "app.py"]
EOF
      podman build -t "localhost/${APP_NAME}:latest" "${APP_DIR}"
      ;;
    *)
      echo "ERROR: No Containerfile/Dockerfile found and cannot auto-detect application type."
      echo "       Please add a Containerfile to the repository."
      exit 1
      ;;
  esac
fi

echo "==> Writing Quadlet configuration (Tailscale-only, no secrets)"
cat > "${QUADLET_DIR}/${APP_NAME}.container" <<EOF
[Unit]
Description=motionsites-prompt-collection (sOs, Tailscale-only)
After=network-online.target

[Container]
Image=localhost/${APP_NAME}:latest
ContainerName=${APP_NAME}
PublishPort=${TAILSCALE_IP}:${BIND_PORT}:8000
Restart=on-failure
RestartPolicy=on-failure:5

[Service]
Restart=on-failure
TimeoutStartSec=60

[Install]
WantedBy=multi-user.target
EOF

echo "==> Reloading systemd and starting service..."
systemctl daemon-reload
systemctl start ${APP_NAME}.service

sleep 2
echo "==> Service status:"
systemctl status ${APP_NAME}.service --no-pager || true

echo ""
echo "==> Deployment complete!"
echo "    Application: ${APP_NAME}"
echo "    Tailscale URL: http://${TAILSCALE_IP}:${BIND_PORT}"
echo "    Status: systemctl status ${APP_NAME}.service"
echo "    Logs: journalctl -u ${APP_NAME}.service -f"
echo ""
echo "    Note: This service is Tailscale-only. Access from Tailscale-connected clients only."
echo "          To expose publicly via Nexus NPM, configure reverse proxy on NPM and wire Tailscale"
echo "          to Nexus (both nodes on mesh)."
