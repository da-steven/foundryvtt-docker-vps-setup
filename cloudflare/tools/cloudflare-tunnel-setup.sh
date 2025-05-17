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
  echo -e "\n\033[1;36m╭──────────────────────────────────────────────╮"
  echo -e   "│ 🛠️  Cloudflare Tunnel Setup (Local Mode)        │"
  echo -e   "╰──────────────────────────────────────────────╯\033[0m"
}
print_header

# === Step 1: Check cloudflared binary ===
echo "🔍 Checking for cloudflared..."
if ! command -v cloudflared > /dev/null 2>&1; then
  echo "❌ cloudflared not found. Please install manually:"
  echo "   https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install/"
  exit 1
fi
CLOUDFLARED_BIN="$(command -v cloudflared)"
echo "✅ cloudflared found at: $CLOUDFLARED_BIN"

# === Step 2: Check for Cloudflare login ===
CONFIG_SRC_DIR="$HOME/.cloudflared"
CONFIG_DEST_DIR="/etc/cloudflared"
if [[ ! -f "$CONFIG_SRC_DIR/cert.pem" ]]; then
  echo "🌐 No cert.pem found — launching Cloudflare login..."
  cloudflared tunnel login || {
    echo "❌ Login failed. Exiting."
    exit 1
  }
else
  echo "✅ cert.pem found"
fi

# === Step 3: Resolve instance context ===
if [[ "$MAIN_INSTANCE" != "true" ]]; then
  if [[ -z "$INSTANCE_SUFFIX" ]]; then
    read -p "Enter a suffix for this alternate install (e.g. dev, v13): " INSTANCE_SUFFIX
    INSTANCE_SUFFIX=$(echo "$INSTANCE_SUFFIX" | xargs)
    if [[ -z "$INSTANCE_SUFFIX" ]]; then
      echo "❌ Suffix is required for alternate instances."
      exit 1
    fi
  fi
  DEFAULT_SUFFIX="-$INSTANCE_SUFFIX"
else
  DEFAULT_SUFFIX=""
fi

# === Step 4: Prompt for tunnel name ===
DEFAULT_TUNNEL_NAME="foundry${DEFAULT_SUFFIX}"
read -p "Enter a unique tunnel name [$DEFAULT_TUNNEL_NAME]: " INPUT_TUNNEL_NAME
TUNNEL_NAME="${INPUT_TUNNEL_NAME:-$DEFAULT_TUNNEL_NAME}"

# === Step 5: Detect existing tunnel ===
if cloudflared tunnel list | grep -qw "$TUNNEL_NAME"; then
  echo "⚠️ Tunnel '$TUNNEL_NAME' already exists."
  read -p "Re-use this tunnel and overwrite its config? (y/n): " REUSE
  [[ ! "$REUSE" =~ ^[Yy]$ ]] && exit 1
else
  echo "🚧 Creating new tunnel: $TUNNEL_NAME"
  cloudflared tunnel create "$TUNNEL_NAME" || {
    echo "❌ Failed to create tunnel."
    exit 1
  }
fi

# === Step 6: Get UUID and verify credentials ===
TUNNEL_UUID=$(cloudflared tunnel list | awk -v name="$TUNNEL_NAME" '$2 == name { print $1 }')
if [[ -z "$TUNNEL_UUID" ]]; then
  echo "❌ Could not determine tunnel UUID."
  exit 1
fi
CREDENTIAL_FILE="$CONFIG_SRC_DIR/$TUNNEL_UUID.json"
if [[ ! -f "$CREDENTIAL_FILE" ]]; then
  echo "❌ Credential file not found: $CREDENTIAL_FILE"
  exit 1
fi

# === Step 7: Prompt for port ===
read -p "Enter the local Foundry port for this instance (e.g., 30000): " FOUNDRY_PORT
FOUNDRY_PORT=$(echo "$FOUNDRY_PORT" | xargs)
if ss -tuln | grep -q ":$FOUNDRY_PORT "; then
  echo "❌ Port $FOUNDRY_PORT is already in use."
  exit 1
fi

# === Step 8: Prompt for domain ===
BASE_DOMAIN=$(echo "${TUNNEL_HOSTNAME:-example.com}" | sed -E 's/^[^.]+\.(.+)$/\1/')
DEFAULT_HOSTNAME="${TUNNEL_NAME}.${BASE_DOMAIN}"
read -p "Enter the public subdomain to route to Foundry [$DEFAULT_HOSTNAME]: " INPUT_HOST
TUNNEL_HOSTNAME="${INPUT_HOST:-$DEFAULT_HOSTNAME}"

# === Step 9: Write config file ===
CONFIG_FILE="$CONFIG_DEST_DIR/${TUNNEL_NAME}.yml"
echo "📄 Writing config to $CONFIG_FILE"
sudo mkdir -p "$CONFIG_DEST_DIR"
sudo tee "$CONFIG_FILE" > /dev/null <<EOF
tunnel: $TUNNEL_UUID
credentials-file: $CREDENTIAL_FILE

ingress:
  - hostname: $TUNNEL_HOSTNAME
    service: http://localhost:$FOUNDRY_PORT
  - service: http_status:404
EOF

# === Step 10: Create DNS record ===
echo "🌐 Creating DNS route: $TUNNEL_HOSTNAME → $TUNNEL_UUID.cfargotunnel.com"
cloudflared tunnel route dns "$TUNNEL_NAME" "$TUNNEL_HOSTNAME" || {
  echo "❌ DNS route failed. You may need to delete an existing record manually."
  exit 1
}

# === Step 11: Install and start systemd service ===
echo "🛠️ Installing systemd service: cloudflared@$TUNNEL_NAME"
sudo cloudflared --config "$CONFIG_FILE" --origincert "$CONFIG_SRC_DIR/cert.pem" service install
sudo systemctl enable "cloudflared@$TUNNEL_NAME"
sudo systemctl restart "cloudflared@$TUNNEL_NAME"

sleep 2
if systemctl is-active --quiet "cloudflared@$TUNNEL_NAME"; then
  echo "✅ Tunnel is active and running as: cloudflared@$TUNNEL_NAME"
else
  echo "❌ Tunnel service failed. Check logs:"
  echo "   journalctl -u cloudflared@$TUNNEL_NAME"
fi

# === Final Instructions ===
echo ""
echo "🎉 Cloudflare tunnel setup complete!"
echo "🔗 Access Foundry: https://$TUNNEL_HOSTNAME"
echo "🧪 Check DNS: https://www.whatsmydns.net/#A/$TUNNEL_HOSTNAME"