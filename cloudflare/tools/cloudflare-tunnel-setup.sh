#!/bin/bash

TUNNEL_NAME="foundry"
CONFIG_SRC_DIR="$HOME/.cloudflared"
CONFIG_DEST_DIR="/etc/cloudflared"
CONFIG_FILE="$CONFIG_DEST_DIR/config.yml"
TUNNEL_UUID=""

print_header() {
  echo -e "\n\033[1;36m╭──────────────────────────────────────────────╮"
  echo -e   "│ 🛠️  Cloudflare Tunnel Setup (Local Mode)        │"
  echo -e   "╰──────────────────────────────────────────────╯\033[0m"
}

print_header

# === Step 1: Ensure cloudflared is installed ===
echo "🔍 Checking for cloudflared..."
if ! command -v cloudflared > /dev/null 2>&1; then
  echo "❌ cloudflared not found. Please install it manually from: https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install"
  exit 1
fi
CLOUDFLARED_BIN="$(command -v cloudflared)"
echo "✅ cloudflared found at: $CLOUDFLARED_BIN"

# === Step 2: Ensure user has authenticated ===
echo "🔐 Checking for cert.pem..."
if [[ ! -f "$CONFIG_SRC_DIR/cert.pem" ]]; then
  echo -e "\n🌐 Launching Cloudflare login."
  echo "👉 Please select your ROOT domain (e.g., dungeonhours.com), NOT a subdomain."
  cloudflared tunnel login || {
    echo "❌ Login failed. Exiting."
    exit 1
  }
else
  echo "✅ Found cert.pem"
fi

# === Step 3: Create the tunnel if needed ===
echo "\n🔧 Checking for existing tunnel credentials..."
if [[ ! -f "$CONFIG_SRC_DIR/${TUNNEL_NAME}.json" ]]; then
  echo "🚧 Creating tunnel: $TUNNEL_NAME"
  cloudflared tunnel create "$TUNNEL_NAME" || {
    echo "❌ Failed to create tunnel. It may already exist remotely."
    echo "   Run \"cloudflared tunnel list\" and use \"cloudflared tunnel token <UUID>\" if needed."
    exit 1
  }
else
  echo "✅ Found existing tunnel credentials: ${TUNNEL_NAME}.json"
fi

# Extract UUID
TUNNEL_UUID=$(cloudflared tunnel list | awk -v name="$TUNNEL_NAME" '$2 == name { print $1 }')
CREDENTIAL_FILE_SRC="$CONFIG_SRC_DIR/${TUNNEL_UUID}.json"
if [[ ! -f "$CREDENTIAL_FILE_SRC" ]]; then
  echo "🔁 Credentials file for tunnel is not named ${TUNNEL_NAME}.json. Trying UUID..."
  if [[ -f "$CONFIG_SRC_DIR/${TUNNEL_NAME}.json" ]]; then
    mv "$CONFIG_SRC_DIR/${TUNNEL_NAME}.json" "$CREDENTIAL_FILE_SRC"
    echo "✅ Renamed to match tunnel UUID."
  else
    echo "❌ Could not locate a usable credential file."
    exit 1
  fi
fi

# === Step 4: Prompt for subdomain to use ===
echo ""
while true; do
  read -p "Enter the full subdomain (e.g., foundry.yourdomain.com): " DOMAIN_RAW
  TUNNEL_DOMAIN=$(echo "$DOMAIN_RAW" | xargs)

  echo "You entered: $TUNNEL_DOMAIN"
  read -p "Is this correct? (y/n): " CONFIRM
  [[ "$CONFIRM" =~ ^[Yy]$ ]] && break
done

# === Step 5: Write config.yml ===
echo "📄 Writing config to $CONFIG_FILE"
sudo mkdir -p "$CONFIG_DEST_DIR"
echo "tunnel: $TUNNEL_UUID" | sudo tee "$CONFIG_FILE" > /dev/null
{
  echo "credentials-file: $CREDENTIAL_FILE_SRC"
  echo ""
  echo "ingress:"
  echo "  - hostname: $TUNNEL_DOMAIN"
  echo "    service: http://localhost:30000"
  echo "  - service: http_status:404"
} | sudo tee -a "$CONFIG_FILE" > /dev/null

# === Step 6: Route DNS ===
echo "🌐 Creating DNS CNAME route: $TUNNEL_DOMAIN -> $TUNNEL_UUID.cfargotunnel.com"
cloudflared tunnel route dns "$TUNNEL_NAME" "$TUNNEL_DOMAIN" || {
  echo "❌ Could not create DNS route. You may need to delete existing A/AAAA/CNAME record from Cloudflare."
  exit 1
}

# === Step 7: Install as a systemd service ===
echo "🛠️ Installing systemd service..."
sudo cloudflared service install \
  --config "$CONFIG_FILE" \
  --origincert "$CONFIG_SRC_DIR/cert.pem" || {
    echo "❌ Failed to install cloudflared service."
    exit 1
  }

sudo systemctl enable cloudflared
sudo systemctl restart cloudflared

sleep 2
if systemctl is-active --quiet cloudflared; then
  echo "✅ cloudflared tunnel is running as a service."
else
  echo "❌ cloudflared did not start. Check logs with: journalctl -u cloudflared"
fi

# === Step 8: Post-setup instructions ===
echo ""
echo "🎉 Tunnel setup complete."
echo "🔗 Visit: https://$TUNNEL_DOMAIN"
echo "🧪 Check DNS propagation: https://www.whatsmydns.net/#CNAME/$TUNNEL_DOMAIN"
echo ""