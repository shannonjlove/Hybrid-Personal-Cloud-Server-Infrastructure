#!/bin/bash
# Configure Nginx Proxy Manager for 1Password Connect API
# Exposes 1password.shannonjlove.cloud via Tailscale only (100.64.0.0/10)
# Usage: sudo bash configure-npm-1password.sh

set -e

# Configuration
NPM_URL="${NPM_URL:-http://localhost:81}"
NPM_EMAIL="${NPM_EMAIL:-}"
NPM_PASSWORD="${NPM_PASSWORD:-}"
NPM_TOKEN="${NPM_TOKEN:-}"

echo "🔒 Nginx Proxy Manager - 1Password Connect Configuration"
echo "=========================================================="

# Check if running with sudo
if [[ $EUID -ne 0 ]]; then
   echo "❌ This script must be run with sudo"
   exit 1
fi

# Load credentials from .env if not already set
if [[ -z "$NPM_EMAIL" ]] || [[ -z "$NPM_PASSWORD" ]]; then
    if [[ -f ".env" ]]; then
        source .env
    else
        echo "❌ Missing NPM credentials"
        echo "   Please set NPM_EMAIL and NPM_PASSWORD in .env or as environment variables"
        echo "   Or export NPM_TOKEN if you already have a valid JWT token"
        exit 1
    fi
fi

# Verify NPM is accessible
echo "🔍 Verifying NPM accessibility at $NPM_URL..."
if ! curl -s -f "$NPM_URL" > /dev/null 2>&1; then
    echo "❌ NPM not accessible at $NPM_URL"
    echo "   Ensure NPM is running: sudo systemctl status nginx-proxy-manager.service"
    echo "   Or check: sudo podman ps | grep nginx"
    exit 1
fi
echo "✅ NPM is accessible"

# Authenticate if no token provided
if [[ -z "$NPM_TOKEN" ]]; then
    echo "🔐 Authenticating with NPM..."
    AUTH_RESPONSE=$(curl -s -X POST "$NPM_URL/api/tokens" \
        -H "Content-Type: application/json" \
        -d "{
            \"identity\": \"$NPM_EMAIL\",
            \"secret\": \"$NPM_PASSWORD\"
        }")

    NPM_TOKEN=$(echo "$AUTH_RESPONSE" | grep -o '"token":"[^"]*' | cut -d'"' -f4)

    if [[ -z "$NPM_TOKEN" ]]; then
        echo "❌ Authentication failed"
        echo "Response: $AUTH_RESPONSE"
        exit 1
    fi
    echo "✅ Authenticated"
fi

# Verify 1Password API is running
echo "🔍 Verifying 1Password Connect API is accessible..."
if ! curl -s -f http://localhost:8080/health > /dev/null 2>&1; then
    echo "❌ 1Password Connect API not accessible at http://localhost:8080/health"
    echo "   Ensure service is running: sudo systemctl status 1password-connect-api.service"
    exit 1
fi
echo "✅ 1Password Connect API is running"

# Get or create SSL certificate
echo "🔐 Setting up Let's Encrypt SSL certificate..."
CERT_RESPONSE=$(curl -s -X POST "$NPM_URL/api/ssl/certificates" \
    -H "Authorization: Bearer $NPM_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
        "provider": "letsencrypt",
        "certificate_name": "1password.shannonjlove.cloud",
        "domain_names": ["1password.shannonjlove.cloud"],
        "agree_tos": true,
        "email": "'$NPM_EMAIL'"
    }')

CERT_ID=$(echo "$CERT_RESPONSE" | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)

if [[ -z "$CERT_ID" ]]; then
    echo "⚠️  Could not create certificate automatically"
    echo "   You may need to manually create or upload the certificate in NPM UI"
    echo "   Response: $CERT_RESPONSE"
    CERT_ID=0  # Default to no certificate; user can update after
else
    echo "✅ Certificate created/found (ID: $CERT_ID)"
fi

# Create proxy host
echo "🌐 Creating proxy host for 1password.shannonjlove.cloud..."
PROXY_RESPONSE=$(curl -s -X POST "$NPM_URL/api/nginx/proxy-hosts" \
    -H "Authorization: Bearer $NPM_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
        "domain_names": ["1password.shannonjlove.cloud"],
        "forward_scheme": "http",
        "forward_host": "localhost",
        "forward_port": 8080,
        "certificate_id": '$CERT_ID',
        "ssl_forced": true,
        "caching_enabled": false,
        "websocket_support": true,
        "access_list_id": 0,
        "advanced_config": "",
        "meta": {
            "letsencrypt_agree": true,
            "letsencrypt_email": "'$NPM_EMAIL'"
        }
    }')

PROXY_ID=$(echo "$PROXY_RESPONSE" | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)

if [[ -z "$PROXY_ID" ]]; then
    echo "❌ Failed to create proxy host"
    echo "Response: $PROXY_RESPONSE"
    exit 1
fi

echo "✅ Proxy host created (ID: $PROXY_ID)"

# Create or get access list for Tailscale subnet
echo "🔐 Configuring Tailscale-only access (100.64.0.0/10)..."
ACCESS_LIST_RESPONSE=$(curl -s -X POST "$NPM_URL/api/access-lists" \
    -H "Authorization: Bearer $NPM_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
        "name": "Tailscale Subnet",
        "client_ip_whitelist": ["100.64.0.0/10"],
        "satisfy_any": false
    }')

ACCESS_LIST_ID=$(echo "$ACCESS_LIST_RESPONSE" | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)

if [[ -n "$ACCESS_LIST_ID" ]] && [[ "$ACCESS_LIST_ID" != "0" ]]; then
    echo "✅ Access list created (ID: $ACCESS_LIST_ID)"

    # Update proxy host with access list
    echo "📋 Applying Tailscale access restriction..."
    curl -s -X PUT "$NPM_URL/api/nginx/proxy-hosts/$PROXY_ID" \
        -H "Authorization: Bearer $NPM_TOKEN" \
        -H "Content-Type: application/json" \
        -d '{
            "domain_names": ["1password.shannonjlove.cloud"],
            "forward_scheme": "http",
            "forward_host": "localhost",
            "forward_port": 8080,
            "certificate_id": '$CERT_ID',
            "ssl_forced": true,
            "caching_enabled": false,
            "websocket_support": true,
            "access_list_id": '$ACCESS_LIST_ID',
            "advanced_config": ""
        }' > /dev/null 2>&1

    echo "✅ Access restriction applied"
else
    echo "⚠️  Could not create access list automatically"
    echo "   You can manually configure Tailscale-only access in NPM UI"
fi

echo ""
echo "=========================================================="
echo "✅ Configuration Complete!"
echo ""
echo "📝 Next Steps:"
echo "   1. Test via Tailscale: https://1password.shannonjlove.cloud"
echo "   2. Verify access is Tailscale-only (not public)"
echo "   3. Check logs: sudo journalctl -u nginx-proxy-manager.service -f"
echo ""
echo "🔗 Access Points:"
echo "   - NPM Dashboard: http://localhost:81 (or https://npm.shannonjlove.cloud)"
echo "   - 1Password API: https://1password.shannonjlove.cloud (Tailscale only)"
echo ""
echo "📚 Documentation: See 1PASSWORD_SETUP.md for manual NPM setup"
echo ""
