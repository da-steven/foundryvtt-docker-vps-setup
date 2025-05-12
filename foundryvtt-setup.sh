#!/bin/bash

FOUNDRY_PORT=30000
INSTALL_DIR="/opt/foundryvtt"
DATA_DIR="$INSTALL_DIR/data"
MAX_RETRIES=3

# === Step 1: System update ===
echo "=== Updating system packages ==="
sudo apt update && sudo apt upgrade -y

# === Step 2: Install dependencies ===
echo "=== Installing Docker and required tools ==="
sudo apt install -y docker.io docker-compose unzip curl

# === Step 3: Enable Docker on boot ===
sudo systemctl enable --now docker

# === Step 4: Create directory structure ===
echo "=== Creating directories ==="
echo "Data Directory: $DATA_DIR"
sudo mkdir -p "$DATA_DIR"
echo "Install Directory: $INSTALL_DIR"
sudo chown -R $USER:$USER "$INSTALL_DIR"

# === Step 5: Prompt for Foundry Download URL ===
while true; do
    echo ""
    read -p "Enter your Foundry VTT timed download URL (Node.js version): " DOWNLOAD_URL_RAW
    DOWNLOAD_URL=$(echo "$DOWNLOAD_URL_RAW" | xargs) # Trim whitespace

    echo ""
    echo "You entered:"
    echo "---------------------------------------"
    echo "$DOWNLOAD_URL"
    echo "---------------------------------------"
    read -p "Is this correct? (y/n): " CONFIRM
    if [[ "$CONFIRM" == "y" || "$CONFIRM" == "Y" ]]; then
        break
    fi
done

# === Step 6: Download Foundry zip ===
echo "=== Downloading Foundry VTT... ==="
cd "$INSTALL_DIR"
ATTEMPT=0
while true; do
    curl -L --retry 3 --retry-delay 5 --connect-timeout 10 --max-time 300 "$DOWNLOAD_URL" --output foundryvtt.zip
    if [[ $? -eq 0 && -f "foundryvtt.zip" ]]; then
        echo "✅ Download succeeded."
        break
    else
        echo "❌ Download failed. Attempt $((++ATTEMPT)) of $MAX_RETRIES."
        if [[ $ATTEMPT -ge $MAX_RETRIES ]]; then
            read -p "Try entering a new URL? (y to retry, anything else to abort): " RETRY_INPUT
            if [[ "$RETRY_INPUT" == "y" || "$RETRY_INPUT" == "Y" ]]; then
                read -p "Enter new download URL: " DOWNLOAD_URL_RAW
                DOWNLOAD_URL=$(echo "$DOWNLOAD_URL_RAW" | xargs)
                ATTEMPT=0
            else
                echo "⛔ Aborting setup."
                exit 1
            fi
        fi
    fi
done

# === Step 7: Extract Foundry and clean up ===
echo "=== Extracting Foundry ==="
unzip -q foundryvtt.zip -d "$INSTALL_DIR"
rm foundryvtt.zip

# === Step 8: Create Dockerfile and Compose ===
echo "=== Creating Docker environment ==="

cat <<EOF > "$INSTALL_DIR/Dockerfile"
FROM node:20-slim
WORKDIR /foundry
COPY . /foundry
EXPOSE $FOUNDRY_PORT
CMD ["node", "resources/app/main.mjs", "--dataPath=/data"]
EOF

cat <<EOF > "$INSTALL_DIR/docker-compose.yml"
version: '3.8'
services:
  foundry:
    build: .
    container_name: foundryvtt
    ports:
      - "127.0.0.1:$FOUNDRY_PORT:$FOUNDRY_PORT"
    volumes:
      - $DATA_DIR:/data
    restart: unless-stopped
EOF

# === Step 9: Start Foundry ===
cd "$INSTALL_DIR"
docker-compose up -d --build

echo ""
echo "✅ Foundry is now running at http://localhost:$FOUNDRY_PORT"

# === Step 10: Prompt to chain tunnel setup ===
echo ""
read -p "Would you like to run the Cloudflare Tunnel setup now? (y/n): " TUNNEL_NOW
if [[ "$TUNNEL_NOW" == "y" || "$TUNNEL_NOW" == "Y" ]]; then
    echo "Launching cloudflare-tunnel-setup.sh..."
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    "$SCRIPT_DIR/cloudflare-tunnel-setup.sh"
else
    echo ""
    echo "You can run the tunnel setup later with:"
    echo "    ./cloudflare-tunnel-setup.sh"
    echo "Make sure you're in your scripts repo directory when you do."
    echo ""
    echo "🎉 Setup complete. Foundry is running locally at: http://localhost:30000"
fi
