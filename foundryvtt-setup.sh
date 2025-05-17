#!/bin/bash

# === Setup ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLOUDFLARE_TOOLS="$SCRIPT_DIR/cloudflare/tools/cloudflare-tunnel-setup.sh"
USE_BUILDKIT=0
FORCE_DOWNLOAD=0
MAX_RETRIES=3

# Load environment variables
UTILS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/utils" && pwd)"
ENV_LOADER="$UTILS_DIR/load-env.sh"

if [[ ! -f "$ENV_LOADER" ]]; then
  echo "❌ Could not find required: $ENV_LOADER"
  exit 1
fi

source "$ENV_LOADER"


# Make sure utility scripts are executable
chmod +x "$CLOUDFLARE_TOOLS" 2>/dev/null || true

# === Handle CLI args ===
if [[ "$1" == "--force-download" ]]; then
  FORCE_DOWNLOAD=1
fi

# === Resolve Install Path ===
if [[ "$MAIN_INSTANCE" == "true" ]]; then
  INSTALL_DIR="${FOUNDRY_MAIN_INSTALL_DIR:-/opt/FoundryVTT/foundry-main}"
  echo "📦 MAIN install mode enabled (MAIN_INSTANCE=true)"
  echo "    → App install path: $INSTALL_DIR"
elif [[ -n "$FOUNDRY_ALT_BASE_DIR" ]]; then
  echo "📦 ALTERNATE install mode (MAIN_INSTANCE=false)"
  read -p "Enter a unique suffix for this install (e.g. dev, v13): " INSTANCE_SUFFIX
  INSTANCE_SUFFIX=$(echo "$INSTANCE_SUFFIX" | xargs)

  if [[ -z "$INSTANCE_SUFFIX" ]]; then
    echo "❌ You must enter a suffix for alternate installs."
    exit 1
  fi

  INSTALL_DIR="$FOUNDRY_ALT_BASE_DIR/foundry-$INSTANCE_SUFFIX"
  echo "    → App install path: $INSTALL_DIR"
else
  echo "❌ No install path configured. Please set either FOUNDRY_MAIN_INSTALL_DIR or FOUNDRY_ALT_BASE_DIR in .env."
  exit 1
fi

# === Resolve Data Directory ===
if [[ "$MAIN_INSTANCE" == "true" ]]; then
  DATA_DIR="${FOUNDRY_DATA_DIR:-$HOME/foundryvtt-data}"
  FOUNDRY_CONTAINER_NAME="${FOUNDRY_CONTAINER_NAME:-foundryvtt}"
  DOCKER_RESTART_POLICY="${MAIN_DOCKER_RESTART_POLICY}"
else
  DATA_DIR="${FOUNDRY_DATA_DIR:-$HOME/foundryvtt-data}-$INSTANCE_SUFFIX"
  FOUNDRY_CONTAINER_NAME="foundryvtt-$INSTANCE_SUFFIX"
  DOCKER_RESTART_POLICY="${ALT_DOCKER_RESTART_POLICY}"
fi

# === Set Port ===
FOUNDRY_PORT="${FOUNDRY_PORT:-30000}"

# === Show resolved paths ===
echo "---------------------------------------"
echo "📁 Install Directory: $INSTALL_DIR"
echo "📁 Data Directory:    $DATA_DIR"
echo "🌐 Port:              $FOUNDRY_PORT"
echo "🔧 Container Name:    $FOUNDRY_CONTAINER_NAME"
echo "🔄 Restart Policy:    $DOCKER_RESTART_POLICY"
echo "---------------------------------------"
echo ""
read -p "Continue with these settings? (y/n): " CONTINUE
if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
  echo "⛔ Aborting by user request."
  exit 1
fi

# === System Update ===
echo "=== Updating system packages ==="
sudo apt update && sudo apt upgrade -y

# === Install Dependencies ===
echo "=== Installing Docker and required tools ==="
sudo apt install -y docker.io docker-compose unzip curl

# === Docker Enable and User Group ===
echo "🔧 Enabling Docker service..."
sudo systemctl enable --now docker

if ! groups "$USER" | grep -qw docker; then
  echo "🔐 You are not in the 'docker' group. Adding you now..."
  sudo usermod -aG docker "$USER"
  echo "⚠️ Please log out and back in (or run 'newgrp docker') before re-running this script."
  exit 1
fi

# === Create Directories ===
echo "📁 Creating installation directories..."
mkdir -p "$INSTALL_DIR" "$DATA_DIR"
sudo chown -R "$USER:$USER" "$INSTALL_DIR" "$DATA_DIR"

# === Download Foundry ===
cd "$INSTALL_DIR"

if [[ ! -f "foundryvtt.zip" || "$FORCE_DOWNLOAD" -eq 1 ]]; then
  while true; do
    echo ""
    read -p "Enter your Foundry VTT timed download URL (Node.js version): " DOWNLOAD_URL_RAW
    DOWNLOAD_URL=$(echo "$DOWNLOAD_URL_RAW" | xargs)

    echo "\nYou entered:\n---------------------------------------\n$DOWNLOAD_URL\n---------------------------------------"
    read -p "Is this correct? (y/n): " CONFIRM
    [[ "$CONFIRM" =~ ^[Yy]$ ]] && break
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
        if [[ "$RETRY_INPUT" =~ ^[Yy]$ ]]; then
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

# === Extract ===
if [[ ! -f "$INSTALL_DIR/resources/app/main.mjs" ]]; then
  echo "📂 Extracting Foundry..."
  unzip -q foundryvtt.zip -d "$INSTALL_DIR" && rm foundryvtt.zip
  if [[ ! -f "$INSTALL_DIR/resources/app/main.mjs" ]]; then
    echo "❌ Extraction failed: $INSTALL_DIR/resources/app/main.mjs not found."
    exit 1
  fi
else
  echo "✅ Foundry already extracted — skipping unzip."
fi

# === BuildKit Check ===
if ! docker buildx version > /dev/null 2>&1; then
  echo "⚠️  Docker BuildKit is not available."
  read -p "Install BuildKit now? (y/n): " ENABLE_BUILDKIT
  if [[ "$ENABLE_BUILDKIT" =~ ^[Yy]$ ]]; then
    echo "🔧 Installing buildx plugin..."
    mkdir -p ~/.docker/cli-plugins
    curl -sSL https://github.com/docker/buildx/releases/latest/download/buildx-v0.11.2.linux-amd64 \
      -o ~/.docker/cli-plugins/docker-buildx && chmod +x ~/.docker/cli-plugins/docker-buildx

    docker buildx version > /dev/null 2>&1 && USE_BUILDKIT=1 || {
      echo "❌ BuildKit install failed." && read -p "Continue with legacy builder? (y/n): " CONT && [[ ! "$CONT" =~ ^[Yy]$ ]] && exit 1
    }
  else
    echo "⚠️ Using legacy builder."
  fi
else
  echo "✅ BuildKit is already available."
  USE_BUILDKIT=1
fi

# === Docker Setup ===
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
    container_name: ${FOUNDRY_CONTAINER_NAME}
    ports:
      - "127.0.0.1:$FOUNDRY_PORT:$FOUNDRY_PORT"
    volumes:
      - $DATA_DIR:/data
    restart: ${DOCKER_RESTART_POLICY}
EOF

# === Launch ===
cd "$INSTALL_DIR"
echo "🚀 Launching Docker container..."
if [[ "$USE_BUILDKIT" -eq 1 ]]; then
  DOCKER_BUILDKIT=1 docker-compose up -d --build
else
  docker-compose up -d --build
fi

if [[ $? -ne 0 ]]; then
  echo "❌ Docker container failed to start. Check logs with: docker-compose logs"
  exit 1
else
  echo "✅ Foundry is now running at http://localhost:$FOUNDRY_PORT"
fi

# === Cloudflare Tunnel ===
echo ""
read -p "Would you like to run the Cloudflare Tunnel setup now? (y/n): " TUNNEL_NOW
if [[ "$TUNNEL_NOW" =~ ^[Yy]$ ]]; then
  echo "🚪 Launching Cloudflare tunnel setup..."
  "$CLOUDFLARE_TOOLS"
else
  echo "ℹ️ You can run the tunnel setup later with: ./cloudflare/cloudflare-tools.sh"
fi

# ✅ Done
echo "🎉 Setup complete. Visit http://localhost:$FOUNDRY_PORT"
