#!/bin/bash
# Deploy 1Password Connect as Podman Quadlets on Nexus
# Usage: bash deploy-1password-connect.sh [--skip-credentials-copy]

set -e

CREDENTIALS_FILE="${1:-1password-credentials.json}"
SKIP_COPY="${2:-}"

echo "🔐 1Password Connect Podman Quadlet Deployment"
echo "================================================"

# Check if running with sudo
if [[ $EUID -ne 0 ]]; then
   echo "❌ This script must be run with sudo"
   exit 1
fi

# Verify Podman is installed
if ! command -v podman &> /dev/null; then
    echo "❌ Podman is not installed"
    exit 1
fi

echo "✅ Podman found: $(podman --version)"

# Create data directory
echo "📁 Creating /opt/1password/data directory..."
mkdir -p /opt/1password/data
chmod 755 /opt/1password

# Copy credentials file if not skipped
if [[ "$SKIP_COPY" != "--skip-credentials-copy" ]]; then
    if [[ ! -f "$CREDENTIALS_FILE" ]]; then
        echo "❌ Credentials file not found: $CREDENTIALS_FILE"
        echo "   Please provide the path to 1password-credentials.json"
        exit 1
    fi

    echo "📋 Copying credentials file..."
    cp "$CREDENTIALS_FILE" /opt/1password/
    chmod 600 /opt/1password/1password-credentials.json
    chown 999:999 /opt/1password/1password-credentials.json
    echo "✅ Credentials file copied and secured"
else
    echo "⏭️  Skipping credentials copy (--skip-credentials-copy)"
fi

# Copy Quadlet files
echo "📦 Deploying Quadlet units..."
cp 1password-connect-api.container /etc/containers/systemd/
cp 1password-connect-sync.container /etc/containers/systemd/
echo "✅ Quadlet files deployed"

# Reload systemd
echo "🔄 Reloading systemd..."
systemctl daemon-reload
echo "✅ Systemd daemon reloaded"

# Start services
echo "🚀 Starting 1Password Connect services..."
systemctl start 1password-connect-api.service
systemctl start 1password-connect-sync.service
echo "✅ Services started"

# Verify services are running
echo "🔍 Verifying services..."
sleep 2

if systemctl is-active --quiet 1password-connect-api.service; then
    echo "✅ 1password-connect-api.service is running"
else
    echo "❌ 1password-connect-api.service failed to start"
    journalctl -u 1password-connect-api.service -n 10 --no-pager
    exit 1
fi

if systemctl is-active --quiet 1password-connect-sync.service; then
    echo "✅ 1password-connect-sync.service is running"
else
    echo "❌ 1password-connect-sync.service failed to start"
    journalctl -u 1password-connect-sync.service -n 10 --no-pager
    exit 1
fi

# Test API endpoint
echo ""
echo "🧪 Testing API endpoint..."
if curl -s -f -H "Accept: application/json" http://localhost:8080/health > /dev/null 2>&1; then
    echo "✅ API endpoint is responding"
else
    echo "⚠️  API not yet ready (this is normal on first startup)"
    echo "   Check logs with: sudo journalctl -u 1password-connect-api.service -f"
fi

echo ""
echo "================================================"
echo "✅ Deployment Complete!"
echo ""
echo "📝 Next Steps:"
echo "   1. Verify logs: sudo journalctl -u 1password-connect-api.service -f"
echo "   2. Test API: curl -H 'Accept: application/json' http://localhost:8080/v1/vaults"
echo "   3. (Optional) Configure Nginx Proxy Manager for remote access"
echo ""
echo "📚 Documentation: See 1PASSWORD_SETUP.md"
echo ""
