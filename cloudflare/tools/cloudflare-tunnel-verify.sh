#!/bin/bash

# Load environment variables
UTILS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../utils" && pwd)"
ENV_LOADER="$UTILS_DIR/load-env.sh"

if [[ ! -f "$ENV_LOADER" ]]; then
  echo "❌ Could not find required: $ENV_LOADER"
  exit 1
fi

source "$ENV_LOADER"

# === Prompt for tunnel name ===
DEFAULT_SUFFIX=""
if [[ "$MAIN_INSTANCE" != "true" && -z "$INSTANCE_SUFFIX" ]]; then
  read -p "Enter suffix for this install (e.g. dev, v13): " INSTANCE_SUFFIX
  INSTANCE_SUFFIX=$(echo "$INSTANCE_SUFFIX" | xargs)
  if [[ -z "$INSTANCE_SUFFIX" ]]; then
    echo "❌ Suffix is required."
    exit 1
  fi
fi

if [[ "$MAIN_INSTANCE" != "true" ]]; then
  DEFAULT_SUFFIX="-$INSTANCE_SUFFIX"
fi

DEFAULT_TUNNEL_NAME="foundry${DEFAULT_SUFFIX}"
read -p "Enter tunnel name to verify [$DEFAULT_TUNNEL_NAME]: " INPUT_NAME
TUNNEL_NAME="${INPUT_NAME:-$DEFAULT_TUNNEL_NAME}"
CONFIG_FILE="/etc/cloudflared/${TUNNEL_NAME}.yml"

# === Output header ===
echo ""
echo "╭──────────────────────────────────────────────╮"
echo "│ 🔍 Verifying Cloudflare Tunnel: $TUNNEL_NAME"
echo "╰──────────────────────────────────────────────╯"

# === Step 1: Check config file ===
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "❌ Config file not found at $CONFIG_FILE"
  echo "   This file is expected after 'cloudflared tunnel create'."
  exit 1
fi

# === Step 2: Extract tunnel info ===
HOSTNAME=$(awk '/- hostname:/ { print $3; exit }' "$CONFIG_FILE")
UUID=$(awk -F: '/tunnel:/ { gsub(/ /,"",$2); print $2; exit }' "$CONFIG_FILE")
CREDENTIAL_FILE=$(awk -F: '/credentials-file:/ { gsub(/ /,"",$2); print $2; exit }' "$CONFIG_FILE")

if [[ -z "$HOSTNAME" || -z "$UUID" || -z "$CREDENTIAL_FILE" ]]; then
  echo "❌ Failed to extract hostname, UUID, or credentials-file from config."
  exit 1
fi

if [[ ! -f "$CREDENTIAL_FILE" ]]; then
  echo "❌ Credentials file missing: $CREDENTIAL_FILE"
  echo "   You may need to re-run 'cloudflared tunnel login' and 'cloudflared tunnel create'."
  exit 1
fi

echo "✅ Configured hostname: $HOSTNAME"
echo "✅ Tunnel UUID: $UUID"
echo "✅ Credentials file found."

# === Step 3: Check DNS A/AAAA ===
echo ""
echo "🌐 Checking public DNS A/AAAA records for: $HOSTNAME"
A_RESULT=$(dig +short "$HOSTNAME" A)
AAAA_RESULT=$(dig +short "$HOSTNAME" AAAA)

if [[ -n "$A_RESULT" || -n "$AAAA_RESULT" ]]; then
  echo "✅ DNS is resolving through Cloudflare."
  echo "🔎 A: $A_RESULT"
  echo "🔎 AAAA: $AAAA_RESULT"
else
  echo "❌ DNS not resolving. Try:"
  echo "   https://www.whatsmydns.net/#A/$HOSTNAME"
  exit 1
fi

# === Step 4: Check systemd service ===
SERVICE_NAME="cloudflared@$TUNNEL_NAME"
echo ""
echo "🛠️ Checking systemd service: $SERVICE_NAME"

if systemctl is-active --quiet "$SERVICE_NAME"; then
  echo "✅ $SERVICE_NAME is active."
else
  echo "❌ $SERVICE_NAME is not running."
  echo "   Start with: sudo systemctl start $SERVICE_NAME"
  exit 1
fi

if systemctl is-enabled --quiet "$SERVICE_NAME"; then
  echo "✅ $SERVICE_NAME is enabled on boot."
else
  echo "⚠️  $SERVICE_NAME is not enabled. Run:"
  echo "    sudo systemctl enable $SERVICE_NAME"
fi

# === Step 5: HTTPS Test ===
echo ""
echo "🌐 Testing HTTPS response from https://$HOSTNAME"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "https://$HOSTNAME")

if [[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "302" ]]; then
  echo "✅ Foundry tunnel is online and responding (HTTP $HTTP_CODE)"
else
  echo "⚠️  Tunnel responded with HTTP $HTTP_CODE"
  echo "    Visit in browser or check Foundry container logs."
fi

# === Final ===
echo ""
echo "🎯 Verification complete for: $TUNNEL_NAME"
echo "🔗 https://$HOSTNAME"
echo "🧪 https://www.whatsmydns.net/#A/$HOSTNAME"
echo "📋 View logs: journalctl -u $SERVICE_NAME"