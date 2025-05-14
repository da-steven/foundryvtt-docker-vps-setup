#!/bin/bash

TUNNEL_NAME="foundry"
CONFIG_FILE="/etc/cloudflared/config.yml"

print_header() {
  echo ""
  echo "╭──────────────────────────────────────────────╮"
  echo "│ 🔍 Verifying Cloudflare Tunnel: $TUNNEL_NAME"
  echo "╰──────────────────────────────────────────────╯"
}

print_header

# Step 1: Check config file
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "❌ Config file not found at $CONFIG_FILE"
  echo "   Expected after service install."
  exit 1
fi

# Step 2: Extract hostname and credentials
HOSTNAME=$(awk '/- hostname:/ { print $3; exit }' "$CONFIG_FILE")
UUID=$(awk -F: '/tunnel:/ { gsub(/ /,"",$2); print $2; exit }' "$CONFIG_FILE")
CREDENTIAL_FILE=$(awk -F: '/credentials-file:/ { gsub(/ /,"",$2); print $2; exit }' "$CONFIG_FILE")

if [[ -z "$HOSTNAME" || -z "$UUID" || -z "$CREDENTIAL_FILE" ]]; then
  echo "❌ Failed to extract hostname, UUID, or credentials-file from config."
  exit 1
fi

if [[ ! -f "$CREDENTIAL_FILE" ]]; then
  echo "❌ Credentials file missing: $CREDENTIAL_FILE"
  echo "   You may need to re-run 'cloudflared tunnel login' and 'tunnel create'."
  exit 1
fi

echo "✅ Configured hostname: $HOSTNAME"
echo "✅ Tunnel UUID: $UUID"
echo "✅ Credentials file found."

# Step 3: Check DNS (Note: Cloudflare flattens proxied CNAMEs to A/AAAA)
echo ""
echo "🌐 Checking public DNS A/AAAA records for: $HOSTNAME"
A_RESULT=$(dig +short "$HOSTNAME" A)
AAAA_RESULT=$(dig +short "$HOSTNAME" AAAA)

if [[ -n "$A_RESULT" || -n "$AAAA_RESULT" ]]; then
  echo "✅ DNS is resolving to Cloudflare Anycast IPs (expected with proxied CNAME)."
  echo "🔎 A record(s): $A_RESULT"
  echo "🔎 AAAA record(s): $AAAA_RESULT"
else
  echo "❌ DNS record missing or unresolved for: $HOSTNAME"
  echo "    Tip: Manually check at https://www.whatsmydns.net/#A/$HOSTNAME"
  exit 1
fi

# Step 4: Check tunnel service
echo ""
echo "🛠️ Checking cloudflared systemd service..."
if systemctl is-active --quiet cloudflared; then
  echo "✅ cloudflared service is active."
else
  echo "❌ cloudflared service is not running."
  echo "   Start with: sudo systemctl start cloudflared"
  exit 1
fi

if systemctl is-enabled --quiet cloudflared; then
  echo "✅ cloudflared is enabled on boot."
else
  echo "⚠️  cloudflared is not enabled on boot. Enable with:"
  echo "    sudo systemctl enable cloudflared"
fi

# Step 5: Verify tunnel response
echo ""
echo "🌐 Testing HTTPS response from https://$HOSTNAME"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "https://$HOSTNAME")

if [[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "302" ]]; then
  echo "✅ Foundry tunnel is online and responding (HTTP $HTTP_CODE)"
else
  echo "⚠️  Tunnel responded with HTTP $HTTP_CODE. Check Foundry status or tunnel logs."
fi

echo ""
echo "🎯 Verification complete."
echo "🔗 You can test global DNS propagation at: https://www.whatsmydns.net/#A/$HOSTNAME"
echo "🔗 You can check tunnel logs with: journalctl -u cloudflared"