#!/usr/bin/env bash
# Updates the Anthropic API key stored in the server's .env after rotation.
# Run this after generating a new key at console.anthropic.com.
set -euo pipefail

ENV_FILE="${ENV_FILE:-.env}"
NEW_KEY="${1:-${ANTHROPIC_API_KEY:-}}"

if [ -z "$NEW_KEY" ]; then
    echo "Usage: $0 <new-api-key>"
    echo "   or: ANTHROPIC_API_KEY=sk-ant-... $0"
    exit 1
fi

if [ ! -f "$ENV_FILE" ]; then
    echo "ANTHROPIC_API_KEY=$NEW_KEY" > "$ENV_FILE"
    echo "Created $ENV_FILE"
else
    if grep -q "^ANTHROPIC_API_KEY=" "$ENV_FILE"; then
        sed -i "s|^ANTHROPIC_API_KEY=.*|ANTHROPIC_API_KEY=$NEW_KEY|" "$ENV_FILE"
        echo "Updated ANTHROPIC_API_KEY in $ENV_FILE"
    else
        echo "ANTHROPIC_API_KEY=$NEW_KEY" >> "$ENV_FILE"
        echo "Appended ANTHROPIC_API_KEY to $ENV_FILE"
    fi
fi

echo "Key rotated. Restart any services that consume ANTHROPIC_API_KEY."
