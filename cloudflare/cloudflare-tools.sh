#!/bin/bash

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SETUP_SCRIPT="$TOOL_DIR/tools/cloudflare-tunnel-setup.sh"
TEARDOWN_SCRIPT="$TOOL_DIR/tools/cloudflare-tunnel-teardown.sh"
STATUS_SCRIPT="$TOOL_DIR/tools/cloudflare-tunnel-status.sh" 

# Make sure sub-scripts are executable
chmod +x "$SETUP_SCRIPT" "$TEARDOWN_SCRIPT" "$STATUS_SCRIPT" 2>/dev/null || true

show_menu() {
  echo ""
  echo "🛡️  Cloudflare Tunnel Tools"
  echo "---------------------------"
  echo "1) Setup Cloudflare Tunnel"
  echo "2) Teardown Cloudflare Tunnel"
  echo "3) Show Tunnel Status"
  echo "4) Exit"
  echo ""
  read -p "Choose an option [1-3]: " CHOICE
}

while true; do
  show_menu
  case "$CHOICE" in
    1)
      if [[ -f "$SETUP_SCRIPT" ]]; then
        bash "$SETUP_SCRIPT"
      else
        echo "❌ Setup script not found: $SETUP_SCRIPT"
      fi
      ;;
    2)
      if [[ -f "$TEARDOWN_SCRIPT" ]]; then
        bash "$TEARDOWN_SCRIPT"
      else
        echo "❌ Teardown script not found: $TEARDOWN_SCRIPT"
      fi
      ;;
    3)
      if [[ -f "$STATUS_SCRIPT" ]]; then
        bash "$STATUS_SCRIPT"
      else
        echo "❌ Status script not found: $STATUS_SCRIPT"
      fi
      ;;
    4)
      echo "👋 Exiting Cloudflare tools."
      exit 0
      ;;
    *)
      echo "❓ Invalid option. Please enter 1, 2, or 3."
      ;;
  esac
done
