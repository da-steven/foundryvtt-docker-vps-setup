#!/bin/bash

# === Load env ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "$SCRIPT_DIR/../../.env.defaults" ] && source "$SCRIPT_DIR/../../.env.defaults"
[ -f "$SCRIPT_DIR/../../.env.local" ] && source "$SCRIPT_DIR/../../.env.local"

# === Step 1: Resolve tunnel name ===
DEFAULT_SUFFIX=""
if [[ "$MAIN_INSTANCE" != "true" && -z "$INSTANCE_SUFFIX" ]]; then
  read -p "Enter suffix for this install (e.g. dev, v13): " INSTANCE_SUFFIX
  INSTANCE_SUFFIX=$(echo "$INSTANCE_SUFFIX" | xargs)
  if [[ -z "$INSTANCE_SUFFIX" ]]; then
    echo "❌ Suffix is required for alternate tunnels."
    exit 1
  fi
fi

if [[ "$MAIN_INSTANCE" != "true" ]]; then
  DEFAULT_SUFFIX="-$INSTANCE_SUFFIX"
fi

DEFAULT_TUNNEL_NAME="foundry${DEFAULT_SUFFIX}"
read -p "Enter tunnel name to check [$DEFAULT_TUNNEL_NAME]: " INPUT_NAME
TUNNEL_NAME="${INPUT_NAME:-$DEFAULT_TUNNEL_NAME}"
CONFIG_FILE="/etc/cloudflared/${TUNNEL_NAME}.yml"

# === Header ===
echo ""
echo "╭──────────────────────────────────────────────╮"
echo "│ 🔍 Checking Cloudflare Tunnel Status: $TUNNEL_NAME"
echo "╰──────────────────────────────────────────────╯"

# === Step 2: Check cloudflared ===
if ! command -v cloudflared > /dev/null 2>&1; then
  echo "❌ cloudflared is not installed. Please run the tunnel setup first."
  exit 1
fi

# === Step 3: Show all tunnels ===
echo ""
echo "📋 Existing Cloudflare Tunnels:"
echo "--------------------------------"
cloudflared tunnel list || {
  echo "⚠️ Unable to list tunnels. Are you logged in?"
  exit 1
}

# === Step 4: Show config details ===
echo ""
if [[ -f "$CONFIG_FILE" ]]; then
  echo "🧾 Tunnel config found at: $CONFIG_FILE"
  echo ""
  awk '
    /^tunnel:/         { print "🔑 Tunnel ID:     " $2 }
    /credentials-file/ { print "🔐 Credentials:   " $2 }
    /hostname:/        { print "🌐 Hostname:      " $2 }
    /service:/         { print "🔁 Service Route: " $2 }
  ' "$CONFIG_FILE"
else
  echo "⚠️ No config file found at: $CONFIG_FILE"
fi

echo ""
echo "🧪 To verify DNS and systemd status, run:"
echo "    ./cloudflare/tools/cloudflare-tunnel-verify.sh"
echo ""