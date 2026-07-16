#!/bin/bash
# Deploy 1Password Connect as Podman Quadlets on Nexus
# Usage: sudo bash /deploy1passwordconnect.sh

set -e

# Absolute paths to files
CREDENTIALS_SRC="/1password-credentials.json"
API_CONTAINER="/1passwordconnectapi.container"
SYNC_CONTAINER="/1passwordconnectsync.container"

# Deployment destinations
CREDENTIALS_DEST="/opt/1password/1password-credentials.json"
QUADLET_DIR="/etc/containers/systemd"

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

# Verify source files exist
echo "🔍 Verifying source files..."
if [[ ! -f "$CREDENTIALS_SRC" ]]; then
    echo "❌ Credentials file not found: $CREDENTIALS_SRC"
    exit 1
fi
echo "✅ Found: $CREDENTIALS_SRC"

if [[ ! -f "$API_CONTAINER" ]]; then
    echo "❌ API container file not found: $API_CONTAINER"
    exit 1
fi
echo "✅ Found: $API_CONTAINER"

if [[ ! -f "$SYNC_CONTAINER" ]]; then
    echo "❌ Sync container file not found: $SYNC_CONTAINER"
    exit 1
fi
echo "✅ Found: $SYNC_CONTAINER"

# Create data directory
echo "📁 Creating /opt/1password/data directory..."
mkdir -p /opt/1password/data
chmod 755 /opt/1password

# Copy credentials file
echo "📋 Copying credentials file..."
cp "$CREDENTIALS_SRC" "$CREDENTIALS_DEST"
chmod 600 "$CREDENTIALS_DEST"
chown 999:999 "$CREDENTIALS_DEST"
echo "✅ Credentials file copied and secured at $CREDENTIALS_DEST"

# Copy Quadlet files
echo "📦 Deploying Quadlet units..."
cp "$API_CONTAINER" "$QUADLET_DIR/1passwordconnectapi.container"
cp "$SYNC_CONTAINER" "$QUADLET_DIR/1passwordconnectsync.container"
echo "✅ Quadlet files deployed to $QUADLET_DIR"

# Reload systemd
echo "🔄 Reloading systemd..."
systemctl daemon-reload
echo "✅ Systemd daemon reloaded"

# Start services
echo "🚀 Starting 1Password Connect services..."
systemctl start 1passwordconnectapi.service
systemctl start 1passwordconnectsync.service
echo "✅ Services started"

# Verify services are running
echo "🔍 Verifying services..."
sleep 2

if systemctl is-active --quiet 1passwordconnectapi.service; then
    echo "✅ 1passwordconnectapi.service is running"
else
    echo "❌ 1passwordconnectapi.service failed to start"
    journalctl -u 1passwordconnectapi.service -n 10 --no-pager
    exit 1
fi

if systemctl is-active --quiet 1passwordconnectsync.service; then
    echo "✅ 1passwordconnectsync.service is running"
else
    echo "❌ 1passwordconnectsync.service failed to start"
    journalctl -u 1passwordconnectsync.service -n 10 --no-pager
    exit 1
fi

# Test API endpoint
echo ""
echo "🧪 Testing API endpoint..."
sleep 2
if curl -s -f -H "Accept: application/json" http://localhost:8080/health > /dev/null 2>&1; then
    echo "✅ API endpoint is responding"
else
    echo "⚠️  API not yet ready (this is normal on first startup)"
    echo "   Check logs with: sudo journalctl -u 1passwordconnectapi.service -f"
fi

echo ""
echo "================================================"
echo "✅ Deployment Complete!"
echo ""
echo "📝 Next Steps:"
echo "   1. Verify logs: sudo journalctl -u 1passwordconnectapi.service -f"
echo "   2. Test API: curl -H 'Accept: application/json' http://localhost:8080/v1/vaults"
echo "   3. (Optional) Configure Nginx Proxy Manager for remote access"
echo ""
echo "📚 Documentation: See /1PASSWORD_SETUP.md"
echo ""
