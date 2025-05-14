#!/bin/bash

FOUNDRY_PORT=30000
INSTALL_DIR="/opt/foundryvtt"
DATA_DIR="$INSTALL_DIR/data"
MAX_RETRIES=3
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLOUDFLARE_TOOLS="$SCRIPT_DIR/cloudflare/tools/cloudflare-tunnel-setup.sh"
USE_BUILDKIT=0
FORCE_DOWNLOAD=0

# Make sure utility scripts are executable
chmod +x "$CLOUDFLARE_TOOLS" 2>/dev/null || true

# === Check for --force-download flag ===
if [[ "$1" == "--force-download" ]]; then
  FORCE_DOWNLOAD=1
fi

print_header() {
  echo ""
  echo "╭──────────────────────────────────────────────╮"
  echo "│ 🎲 Foundry VTT Docker Setup Script"
  echo "╰──────────────────────────────────────────────╯"
}

# === Step 1: System update ===
echo "=== Updating system packages ==="
sudo apt update && sudo apt upgrade -y

# === Step 2: Install dependencies ===
echo "=== Installing Docker and required tools ==="
sudo apt install -y docker.io docker-compose unzip curl

# === Step 3: Enable Docker and check group ===
echo "🔧 Enabling Docker service..."
sudo systemctl enable --now docker

if ! groups "$USER" | grep -qw docker; then
    echo ""
    echo "🔐 You are not in the 'docker' group. Adding you now..."
    sudo usermod -aG docker "$USER"
    echo "⚠️ Please log out and back in (or run 'newgrp docker') before re-running this script."
    exit 1
fi

# === Step 4: Create install directory ===
echo ""
echo "📁 Creating installation directories"
echo "Install Directory: $INSTALL_DIR"
echo "Data Directory: $DATA_DIR"

if ! sudo mkdir -p "$DATA_DIR"; then
    echo "❌ Failed to create $DATA_DIR"
    exit 1
fi

if ! sudo chown -R "$USER:$USER" "$INSTALL_DIR"; then
    echo "❌ Failed to change ownership of $INSTALL_DIR"
    exit 1
fi

# === Step 5: Download Foundry VTT ===
cd "$INSTALL_DIR"

if [[ ! -f "foundryvtt.zip" || "$FORCE_DOWNLOAD" -eq 1 ]]; then
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

    echo "⬇️  Downloading Foundry VTT..."
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
else
    echo "📦 Foundry zip already exists — skipping download (use --force-download to re-download)."
fi

# === Step 6: Extract and validate ===
if [[ ! -f "$INSTALL_DIR/resources/app/main.mjs" ]]; then
    echo "📂 Extracting Foundry..."
    unzip -q foundryvtt.zip -d "$INSTALL_DIR" && rm foundryvtt.zip

    if [[ ! -f "$INSTALL_DIR/resources/app/main.mjs" ]]; then
        echo "❌ Foundry failed to extract correctly. Expected file not found:"
        echo "   $INSTALL_DIR/resources/app/main.mjs"
        exit 1
    fi
else
    echo "✅ Foundry already extracted — skipping unzip."
fi

# === Step 7: Check or install BuildKit ===
if ! docker buildx version > /dev/null 2>&1; then
    echo "⚠️  Docker BuildKit is not currently available."
    read -p "Would you like to install and enable BuildKit now? (y/n): " ENABLE_BUILDKIT

    if [[ "$ENABLE_BUILDKIT" =~ ^[Yy]$ ]]; then
        echo "🔧 Installing buildx plugin..."
        mkdir -p ~/.docker/cli-plugins
        curl -sSL https://github.com/docker/buildx/releases/latest/download/buildx-v0.11.2.linux-amd64 \
          -o ~/.docker/cli-plugins/docker-buildx && chmod +x ~/.docker/cli-plugins/docker-buildx

        if docker buildx version > /dev/null 2>&1; then
            echo "✅ BuildKit installed."
            USE_BUILDKIT=1
        else
            echo "❌ BuildKit installation failed."
            read -p "Continue using legacy builder? (y/n): " CONTINUE
            [[ ! "$CONTINUE" =~ ^[Yy]$ ]] && exit 1
        fi
    else
        echo "⚠️ Continuing with the legacy builder (deprecated)."
    fi
else
    echo "✅ BuildKit is already available."
    USE_BUILDKIT=1
fi

# === Step 8: Docker setup ===
echo "🐳 Creating Dockerfile and docker-compose.yml..."

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

# === Step 9: Build + start container ===
cd "$INSTALL_DIR"
echo "🚀 Building and launching Foundry..."

if [[ "$USE_BUILDKIT" -eq 1 ]]; then
    DOCKER_BUILDKIT=1 docker-compose up -d --build
else
    docker-compose up -d --build
fi

if [[ $? -ne 0 ]]; then
    echo ""
    echo "❌ Docker container failed to start. Check logs with:"
    echo "   docker-compose logs"
    exit 1
else
    echo ""
    echo "✅ Foundry is now running at http://localhost:$FOUNDRY_PORT"
fi

# === Step 10: Offer to run Cloudflare Tunnel script ===
echo ""
read -p "Would you like to run the Cloudflare Tunnel setup now? (y/n): " TUNNEL_NOW
if [[ "$TUNNEL_NOW" =~ ^[Yy]$ ]]; then
    echo "🚪 Launching cloudflare-tunnel-setup.sh..."
    "$CLOUDFLARE_TOOLS"
else
    echo ""
    echo "ℹ️ You can run the tunnel setup later with:"
    echo "    ./cloudflare/cloudflare-tools.sh"
    echo "Make sure you're in your scripts repo directory when you do."
    echo ""
    echo "🎉 Setup complete. Foundry is running locally at: http://localhost:$FOUNDRY_PORT"
fi