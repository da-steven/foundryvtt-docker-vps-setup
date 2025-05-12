#!/bin/bash

TUNNEL_NAME="foundry"
CONFIG_DIR="$HOME/.cloudflared"
CONFIG_FILE="$CONFIG_DIR/config.yml"
CREDENTIAL_FILE="$CONFIG_DIR/${TUNNEL_NAME}.json"

echo "⚠️  WARNING: This will permanently delete the Cloudflare Tunnel '$TUNNEL_NAME'."
echo "It will also stop any running tunnel processes and remove local configs."

read -p "Are you sure you want to proceed? (y/n): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
  echo "Aborted."
  exit 0
fi

# === Step 1: Stop running tunnels ===
echo "🛑 Stopping running cloudflared processes..."
pkill -f "cloudflared tunnel run $TUNNEL_NAME" 2>/dev/null || true
sudo systemctl stop cloudflared 2>/dev/null || true

# === Step 2: Delete tunnel from Cloudflare ===
if cloudflared tunnel list | grep -qw "$TUNNEL_NAME"; then
  echo "❌ Deleting tunnel '$TUNNEL_NAME' from Cloudflare..."
  cloudflared tunnel delete "$TUNNEL_NAME"
else
  echo "ℹ️ Tunnel '$TUNNEL_NAME' not found in cloudflared list — skipping delete."
fi

# === Step 3: Remove local config and credentials ===
echo "🧹 Removing local config and credential files..."
rm -f "$CONFIG_FILE"
rm -f "$CREDENTIAL_FILE"

# === Step 4: Optional uninstall ===
read -p "Do you want to uninstall cloudflared from this machine? (y/n): " UNINSTALL
if [[ "$UNINSTALL" =~ ^[Yy]$ ]]; then
  echo "📦 Uninstalling cloudflared and cleaning APT config..."
  sudo apt remove -y cloudflared
  sudo rm -f /etc/apt/sources.list.d/cloudflared.list
  sudo rm -f /usr/share/keyrings/cloudflare-main.gpg
  sudo apt update
else
  echo "✅ cloudflared left installed. You can recreate the tunnel later."
fi

echo ""
echo "✅ Tunnel teardown complete."