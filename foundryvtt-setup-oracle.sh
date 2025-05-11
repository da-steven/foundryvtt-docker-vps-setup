#!/bin/bash

FOUNDRY_PORT=30000
INSTALL_DIR="/opt/foundryvtt"
DATA_DIR="$INSTALL_DIR/data"

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
sudo mkdir -p "$DATA_DIR"
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

# === Step 6: Download Foundry zip with retry ===
echo "=== Downloading Foundry VTT... ==="
cd "$INSTALL_DIR"
ATTEMPT=0
MAX_RETRIES=3
while true; do
    curl -L --retry 3 --retry-delay 5 --connect-timeout 10 --max-time 300 "$DOWNLOAD_URL" --output foundryvtt.zip
    if [[ $? -eq 0 && -f "foundryvtt.zip" ]]; then
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
                echo "Aborting setup."
                exit 1
            fi
        fi
    fi
done

# === Step 7: Extract Foundry and clean up ===
echo "=== Extracting Foundry ==="
unzip foundryvtt.zip -d .
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

# === Step 10: Prepare for Cloudflare Tunnel ===
echo ""
echo "💡 Next Step: Set up Cloudflare Tunnel to expose Foundry securely over HTTPS."
echo "Follow the instructions in the README ..."
