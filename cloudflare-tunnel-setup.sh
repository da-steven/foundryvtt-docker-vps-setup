#!/bin/bash

TUNNEL_NAME="foundry"
CONFIG_DIR="/home/ubuntu/.cloudflared"
CONFIG_FILE="$CONFIG_DIR/config.yml"
CREDENTIAL_FILE="$CONFIG_DIR/${TUNNEL_NAME}.json"

# === Step 1: Install cloudflared ===
echo "Installing cloudflared..."
sudo apt install -y cloudflared

# === Step 2: Login to Cloudflare ===
echo ""
echo "You will now log in to Cloudflare in your browser..."
cloudflared tunnel login

# === Step 3: Create the tunnel ===
echo "Creating tunnel: $TUNNEL_NAME"
cloudflared tunnel create "$TUNNEL_NAME"

# === Step 4: Prompt for domain with trimming and confirmation ===
while true; do
    echo ""
    read -p "Enter the full domain you want to use for Foundry (e.g., foundry.yoursite.com): " DOMAIN_RAW
    VTT_DOMAIN=$(echo "$DOMAIN_RAW" | xargs) # Trim whitespace

    echo ""
    echo "You entered: $VTT_DOMAIN"
    read -p "Is this correct? (y/n): " CONFIRM
    if [[ "$CONFIRM" == "y" || "$CONFIRM" == "Y" ]]; then
        break
    fi
done

# === Step 5: Create config file ===
echo "Writing Cloudflare Tunnel config to $CONFIG_FILE"

mkdir -p "$CONFIG_DIR"
cat <<EOF > "$CONFIG_FILE"
tunnel: $TUNNEL_NAME
credentials-file: $CREDENTIAL_FILE

ingress:
  - hostname: $VTT_DOMAIN
    service: http://localhost:30000
  - service: http_status:404
EOF

# === Step 6: Run tunnel ===
echo ""
echo "Starting the tunnel..."
cloudflared tunnel run "$TUNNEL_NAME" &

# === Step 7: Offer to install as a service ===
echo ""
read -p "Do you want to install Cloudflare Tunnel as a background service? (y/n): " SETUP_SERVICE
if [[ "$SETUP_SERVICE" == "y" || "$SETUP_SERVICE" == "Y" ]]; then
    echo "Installing tunnel as a system service..."
    sudo cloudflared service install
    echo "✅ Tunnel will start on reboot."
else
    echo "You can manually start the tunnel with:"
    echo "    cloudflared tunnel run $TUNNEL_NAME"
fi

echo ""
echo "✅ Cloudflare Tunnel is set up!"
echo "🎯 Visit https://$VTT_DOMAIN to access Foundry VTT (after DNS propagation)."
