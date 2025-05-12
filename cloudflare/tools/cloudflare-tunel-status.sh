#!/bin/bash

CONFIG_FILE="$HOME/.cloudflared/config.yml"

# === Step 1: Check for cloudflared ===
if ! command -v cloudflared > /dev/null 2>&1; then
  echo "❌ cloudflared is not installed. Please run the setup script first."
  exit 1
fi

# === Step 2: Show current tunnels ===
echo "📋 Existing Cloudflare Tunnels:"
echo "--------------------------------"
cloudflared tunnel list || {
  echo "⚠️ Unable to list tunnels. Are you authenticated with Cloudflare?"
  exit 1
}

# === Step 3: Show configured tunnel (if any) ===
if [[ -f "$CONFIG_FILE" ]]; then
  echo ""
  echo "🧾 Current active config from: $CONFIG_FILE"
  grep -E '^(tunnel|hostname|service):' "$CONFIG_FILE"
else
  echo ""
  echo "ℹ️ No tunnel config file found at: $CONFIG_FILE"
fi

exit 0