#!/bin/bash

# Load environment variables
UTILS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../utils" && pwd)"
ENV_LOADER="$UTILS_DIR/load-env.sh"

if [[ ! -f "$ENV_LOADER" ]]; then
  echo "❌ Could not find required: $ENV_LOADER"
  exit 1
fi

source "$ENV_LOADER"

print_header() {
  echo ""
  echo "╭──────────────────────────────────────────────╮"
  echo "│  💥 Teardown Cloudflare Tunnel"
  echo "╰──────────────────────────────────────────────╯"
}
print_header

# === Prompt for instance suffix if needed ===
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
read -p "Enter the tunnel name to teardown [$DEFAULT_TUNNEL_NAME]: " INPUT_NAME
TUNNEL_NAME="${INPUT_NAME:-$DEFAULT_TUNNEL_NAME}"
CONFIG_SRC_DIR="$HOME/.cloudflared"
CONFIG_FILE="/etc/cloudflared/${TUNNEL_NAME}.yml"
CREDENTIAL_FILE_UUID=$(cloudflared tunnel list 2>/dev/null | awk -v name="$TUNNEL_NAME" '$2 == name { print $1 }')
CREDENTIAL_FILE_FALLBACK="$CONFIG_SRC_DIR/${TUNNEL_NAME}.json"
SERVICE_NAME="cloudflared@$TUNNEL_NAME"

# === Confirm ===
echo ""
echo "⚠️  WARNING: This will permanently delete the Cloudflare Tunnel: $TUNNEL_NAME"
echo "It will stop any services, delete the tunnel from Cloudflare, and remove config files."
read -p "Are you sure you want to proceed? (y/n): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
  echo "Aborted by user."
  exit 0
fi

# === Step 1: Stop systemd service ===
echo "🛑 Stopping cloudflared systemd service..."
sudo systemctl stop "$SERVICE_NAME" 2>/dev/null || true
sudo systemctl disable "$SERVICE_NAME" 2>/dev/null || true

# === Step 2: Kill manual background runs ===
pkill -f "cloudflared tunnel run $TUNNEL_NAME" 2>/dev/null || true

# === Step 3: Delete tunnel from Cloudflare ===
echo "❌ Deleting tunnel '$TUNNEL_NAME' from Cloudflare..."
if cloudflared tunnel list 2>/dev/null | grep -qw "$TUNNEL_NAME"; then
  cloudflared tunnel delete "$TUNNEL_NAME"
else
  echo "ℹ️ Tunnel not found in remote list — skipping remote deletion."
fi

# === Step 4: Remove local config and credentials ===
echo "🧹 Removing local config and credential files..."
sudo rm -f "$CONFIG_FILE"

if [[ -n "$CREDENTIAL_FILE_UUID" && -f "$CONFIG_SRC_DIR/$CREDENTIAL_FILE_UUID.json" ]]; then
  rm -f "$CONFIG_SRC_DIR/$CREDENTIAL_FILE_UUID.json"
elif [[ -f "$CREDENTIAL_FILE_FALLBACK" ]]; then
  rm -f "$CREDENTIAL_FILE_FALLBACK"
fi

# === Step 5: Optionally uninstall cloudflared ===
read -p "Do you want to uninstall cloudflared from this machine? (y/n): " UNINSTALL
if [[ "$UNINSTALL" =~ ^[Yy]$ ]]; then
  echo "📦 Uninstalling cloudflared..."
  sudo apt remove -y cloudflared
  sudo rm -f /etc/apt/sources.list.d/cloudflared.list
  sudo rm -f /usr/share/keyrings/cloudflare-main.gpg
  sudo apt update
else
  echo "✅ cloudflared remains installed. You can recreate this tunnel later."
fi

# === Final ===
echo ""
echo "✅ Teardown complete for: $TUNNEL_NAME"