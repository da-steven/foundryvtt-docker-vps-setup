#!/bin/bash

TUNNEL_NAME="foundry"
CONFIG_DIR="$HOME/.cloudflared"
CONFIG_FILE="$CONFIG_DIR/config.yml"
CREDENTIAL_FILE="$CONFIG_DIR/${TUNNEL_NAME}.json"

# === Step 1: Install cloudflared ===
echo "🔧 Installing cloudflared..."

if ! command -v cloudflared > /dev/null 2>&1; then
    echo "Fetching Cloudflare's package signing key..."
    curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | sudo tee /usr/share/keyrings/cloudflare-main.gpg > /dev/null

    echo "Adding Cloudflare APT repository..."
    echo 'deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared stable main' \
      | sudo tee /etc/apt/sources.list.d/cloudflared.list

    sudo apt update
    sudo apt install -y cloudflared
else
    echo "✅ cloudflared is already installed."
fi

# === Step 2: Login to Cloudflare ===
echo ""
echo "🌐 You will now log in to Cloudflare in your browser..."
cloudflared tunnel login

# === Step 3: Create the tunnel ===
echo "🚧 Creating tunnel: $TUNNEL_NAME"
cloudflared tunnel create "$TUNNEL_NAME"

# === Step 4: Prompt for domain with trim and confirm ===
while true; do
    echo ""
    read -p "Enter the full domain you want to use for Foundry (e.g., foundry.yoursite.com): " DOMAIN_RAW
    VTT_DOMAIN=$(echo "$DOMAIN_RAW" | xargs)

    echo ""
    echo "You entered: $VTT_DOMAIN"
    read -p "Is this correct? (y/n): " CONFIRM
    if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
        break
    fi
done

# === Step 5: Create Cloudflared config file ===
echo "📝 Writing Cloudflare Tunnel config to $CONFIG_FILE"
mkdir -p "$CONFIG_DIR"

cat <<EOF > "$CONFIG_FILE"
tunnel: $TUNNEL_NAME
credentials-file: $CREDENTIAL_FILE

ingress:
  - hostname: $VTT_DOMAIN
    service: http://localhost:30000
  - service: http_status:404
EOF

# === Step 6: Run tunnel interactively ===
echo ""
echo "🚀 Starting the tunnel interactively..."
cloudflared tunnel run "$TUNNEL_NAME" &

# === Step 7: Offer to install as a service ===
echo ""
read -p "Do you want to install Cloudflare Tunnel as a system service (auto-start)? (y/n): " SETUP_SERVICE
if [[ "$SETUP_SERVICE" =~ ^[Yy]$ ]]; then
    echo "🛠️ Installing tunnel as a background service..."
    sudo cloudflared service install
    echo "✅ Tunnel will now start automatically on reboot."
else
    echo "ℹ️ You can manually start the tunnel anytime with:"
    echo "    cloudflared tunnel run $TUNNEL_NAME"
fi

echo ""
echo "✅ Cloudflare Tunnel setup complete!"
echo "🎯 Visit https://$VTT_DOMAIN to access Foundry VTT (after DNS updates)."
