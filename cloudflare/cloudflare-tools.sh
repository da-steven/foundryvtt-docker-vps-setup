#!/bin/bash

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_PATH="$TOOL_DIR/tools"

SETUP_SCRIPT="$TOOLS_PATH/cloudflare-tunnel-setup.sh"
TEARDOWN_SCRIPT="$TOOLS_PATH/cloudflare-tunnel-teardown.sh"
STATUS_SCRIPT="$TOOLS_PATH/cloudflare-tunnel-status.sh"
VERIFY_SCRIPT="$TOOLS_PATH/cloudflare-tunnel-verify.sh"

# Ensure sub-scripts are executable
chmod +x "$SETUP_SCRIPT" "$TEARDOWN_SCRIPT" "$STATUS_SCRIPT" "$VERIFY_SCRIPT" 2>/dev/null || true

print_header() {
  echo ""
  echo "╭──────────────────────────────────────────────╮"
  echo "│ ⚙️  Cloudflare Tunnel Tools Menu"
  echo "╰──────────────────────────────────────────────╯"
}

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
}

# === Flag Handling ===
if [[ "$1" =~ ^--(setup|teardown|status|verify|help)$ ]]; then
  case "$1" in
    --setup)
      bash "$SETUP_SCRIPT"
      exit $?
      ;;
    --teardown)
      bash "$TEARDOWN_SCRIPT"
      exit $?
      ;;
    --status)
      bash "$STATUS_SCRIPT"
      exit $?
      ;;
    --verify)
      bash "$VERIFY_SCRIPT"
      exit $?
      ;;
    --help)
      echo ""
      echo "📘 Usage: ./cloudflare-tools.sh [OPTION]"
      echo ""
      echo "Optional flags:"
      echo "  --setup       Run Cloudflare Tunnel setup"
      echo "  --teardown    Remove a tunnel and its config"
      echo "  --status      Show configured tunnel(s)"
      echo "  --verify      Check DNS/systemd/HTTP status"
      echo "  --help        Show this help message"
      echo ""
      echo "Without any flags, an interactive menu will appear."
      exit 0
      ;;
  esac
fi

# === Interactive Mode ===
while true; do
  clear
  print_header
  show_menu
  read -p "Choose an option [1-5]: " CHOICE
  echo ""

  case "$CHOICE" in
    1)
      bash "$SETUP_SCRIPT"
      ;;
    2)
      bash "$TEARDOWN_SCRIPT"
      ;;
    3)
      bash "$STATUS_SCRIPT"
      ;;
    4)
      bash "$VERIFY_SCRIPT"
      ;;
    5)
      echo "👋 Exiting Cloudflare tools."
      echo ""
      exit 0
      ;;
    *)
      echo "❓ Invalid option. Please enter a number from 1 to 5."
      ;;
  esac

  echo ""
  read -p "Press Enter to return to the menu..." _
done