#!/bin/bash

TUNNEL_NAME="foundry"
CONFIG_DIR="$HOME/.cloudflared"
CONFIG_FILE="$CONFIG_DIR/config.yml"
CREDENTIAL_FILE="$CONFIG_DIR/${TUNNEL_NAME}.json"

# === Step 1: Install cloudflared (with architecture detection) ===
echo "🔧 Installing cloudflared..."

ARCH=$(uname -m)
CLOUDFLARED_BIN="/usr/local/bin/cloudflared"

if ! command -v cloudflared > /dev/null 2>&1; then
    echo "📦 Downloading latest cloudflared release for architecture: $ARCH"

    if [[ "$ARCH" == "x86_64" ]]; then
        DOWNLOAD_URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64"
    elif [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
        DOWNLOAD_URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64"
    else
        echo "❌ Unsupported architecture: $ARCH"
        exit 1
    fi

    curl -L "$DOWNLOAD_URL" -o cloudflared
    chmod +x cloudflared
    sudo mv cloudflared "$CLOUDFLARED_BIN"
else
    echo "✅ cloudflared is already installed."
fi

# === Step 1.5: Validate cloudflared is in PATH ===
CLOUDFLARED="$(command -v cloudflared)"
if [[ -z "$CLOUDFLARED" ]]; then
    echo "❌ cloudflared was not found in PATH after install. Try restarting your shell or running 'hash -r'."
    exit 1
fi

# === Step 2: Login to Cloudflare ===
echo ""
echo "🌐 You will now log in to Cloudflare in your browser..."
"$CLOUDFLARED" tunnel login

# === Step 3: Create the tunnel ===
echo "🚧 Creating tunnel: $TUNNEL_NAME"
"$CLOUDFLARED" tunnel create "$TUNNEL_NAME"

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
"$CLOUDFLARED" tunnel run "$TUNNEL_NAME" &

# === Step 7: Offer to install as a system service ===
echo ""
read -p "Do you want to install Cloudflare Tunnel as a system service (auto-start)? (y/n): " SETUP_SERVICE
if [[ "$SETUP_SERVICE" =~ ^[Yy]$ ]]; then
    echo "🛠️ Installing tunnel as a background service..."
    sudo "$CLOUDFLARED" service install

    echo ""
    echo "🔍 Checking service status..."
    SERVICE_NAME="cloudflared.service"

    if systemctl is-active --quiet "$SERVICE_NAME"; then
        echo "✅ Service is currently active (running)."
    else
        echo "⚠️ Service is not running. You can start it with:"
        echo "    sudo systemctl start $SERVICE_NAME"
    fi

    if systemctl is-enabled --quiet "$SERVICE_NAME"; then
        echo "✅ Service is enabled to start on boot."
    else
        echo "⚠️ Service is not enabled. You can enable it with:"
        echo "    sudo systemctl enable $SERVICE_NAME"
    fi
else
    echo ""
    echo "ℹ️ You can manually start the tunnel anytime with:"
    echo "    $CLOUDFLARED tunnel run $TUNNEL_NAME"
fi

echo ""
echo "✅ Cloudflare Tunnel setup complete!"
echo "🎯 Visit https://$VTT_DOMAIN to access Foundry VTT (after DNS updates)."