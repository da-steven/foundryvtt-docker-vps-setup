#!/bin/bash

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SETUP_SCRIPT="$TOOL_DIR/tools/cloudflare-tunnel-setup.sh"
TEARDOWN_SCRIPT="$TOOL_DIR/tools/cloudflare-tunnel-teardown.sh"
STATUS_SCRIPT="$TOOL_DIR/tools/cloudflare-tunnel-status.sh" 
VERIFY_SCRIPT="$TOOL_DIR/tools/cloudflare-tunnel-verify.sh"

# Make sure sub-scripts are executable
chmod +x "$SETUP_SCRIPT" "$TEARDOWN_SCRIPT" "$STATUS_SCRIPT" "$VERIFY_SCRIPT" 2>/dev/null || true

show_menu() {
  echo ""
  echo "🛡️  Cloudflare Tunnel Tools"
  echo "---------------------------"
  echo "1) Setup Cloudflare Tunnel"
  echo "2) Teardown Cloudflare Tunnel"
  echo "3) Show Tunnel Status"
  echo "4) Verify Tunnel Connection"
  echo "5) Exit"
  echo ""
  read -p "Choose an option [1-5]: " CHOICE
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
      if [[ -f "$VERIFY_SCRIPT" ]]; then
        bash "$VERIFY_SCRIPT"
      else
        echo "❌ Verify script not found: $VERIFY_SCRIPT"
      fi
      ;;
    5)
      echo "👋 Exiting Cloudflare tools."
      exit 0
      ;;
    *)
      echo "❓ Invalid option. Please enter 1-5."
      ;;
  esac
done
