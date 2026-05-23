#!/bin/bash
# Captive Portal Rescue
# Saves your connection from DHCP DNS leaks and VPN blocks on public Wi-Fi captive portals.
# Supports NetworkManager-based systems with systemd-resolved.

# --- Configuration ---
# Set to true to enable extra debug output
DEBUG=false
# Optional legacy hosts entries to clean up (e.g. from previous manual workarounds)
CLEANUP_HOSTS=("guest.chipublib.org")

# Help menu
show_help() {
    echo "Usage: $(basename "$0") [options]"
    echo "Saves your connection from DHCP DNS leaks and VPN blocks on public Wi-Fi captive portals."
    echo ""
    echo "Options:"
    echo "  -r, --restore    Restore the active Wi-Fi connection to default automatic DNS"
    echo "  -h, --help       Show this help message"
    exit 0
}

# Parse options
RESTORE_MODE=false
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -r|--restore) RESTORE_MODE=true; shift ;;
        -h|--help) show_help ;;
        *) echo "Unknown option: $1"; show_help ;;
    esac
done

# 1. Identify active Wi-Fi connection and interface
ACTIVE_CON=$(nmcli -t -f NAME,TYPE con show --active | grep -iE "wifi|802-11-wireless" | cut -d: -f1 | head -n 1)
DEVICE_NAME=$(nmcli -t -f DEVICE,TYPE connection show --active | grep -iE ":802-11-wireless|:wifi" | cut -d: -f1 | head -n 1)

if [ -z "$ACTIVE_CON" ] || [ -z "$DEVICE_NAME" ]; then
    echo "❌ Error: No active Wi-Fi connection found."
    exit 1
fi

echo "📶 Found active Wi-Fi: '$ACTIVE_CON' on device '$DEVICE_NAME'"

# --- RESTORE MODE ---
if [ "$RESTORE_MODE" = true ]; then
    echo "🔄 Restoring connection profile to automatic DHCP DNS..."
    nmcli connection modify "$ACTIVE_CON" ipv4.ignore-auto-dns no ipv4.dns ""
    nmcli connection modify "$ACTIVE_CON" ipv6.ignore-auto-dns no ipv6.dns ""
    
    echo "🔄 Re-activating connection to apply changes..."
    nmcli connection up "$ACTIVE_CON"
    
    echo "🧹 Flushing systemd-resolved cache (requires sudo)..."
    sudo resolvectl flush-caches
    
    echo "✅ Connection restored to default automatic settings."
    exit 0
fi

# --- FIX MODE ---

# 2. Extract DHCP DNS servers from the lease
# Fallback pattern for nmcli versions
DHCP_DNS=$(nmcli -g DHCP4.OPTION device show "$DEVICE_NAME" | grep -oP '(?:^|[|])\s*domain_name_servers = \K[^|]+' | xargs)

if [ "$DEBUG" = true ]; then
    echo "📥 DHCP raw DNS servers: $DHCP_DNS"
fi

# Filter to ONLY internal/private IPs (RFC 1918)
INTERNAL_DNS=""
for ip in $DHCP_DNS; do
    if [[ "$ip" =~ ^10\. || "$ip" =~ ^192\.168\. || "$ip" =~ ^172\.(1[6-9]|2[0-9]|3[0-1])\. ]]; then
        if [ -z "$INTERNAL_DNS" ]; then
            INTERNAL_DNS="$ip"
        else
            INTERNAL_DNS="$INTERNAL_DNS,$ip"
        fi
    fi
done

if [ -z "$INTERNAL_DNS" ]; then
    echo "⚠️ No internal DNS servers found in DHCP lease! Falling back to Gateway."
    GATEWAY_IP=$(nmcli -g IP4.GATEWAY device show "$DEVICE_NAME" | head -n 1)
    if [ -z "$GATEWAY_IP" ]; then
        GATEWAY_IP=$(ip route show default | awk '{print $3}')
    fi
    INTERNAL_DNS="$GATEWAY_IP"
fi

echo "🔍 Filtered internal DNS servers to use: $INTERNAL_DNS"

# 3. Apply internal DNS and disable automatic DNS for both IPv4 and IPv6 to prevent leaks
echo "⚙️ Configuring NetworkManager to ignore public DNS..."
nmcli connection modify "$ACTIVE_CON" ipv4.ignore-auto-dns yes
nmcli connection modify "$ACTIVE_CON" ipv4.dns "$INTERNAL_DNS"
nmcli connection modify "$ACTIVE_CON" ipv6.ignore-auto-dns yes # Prevent IPv6 DNS leaks

echo "🔄 Re-activating connection to apply changes..."
nmcli connection up "$ACTIVE_CON"

# 4. Cleanup any broken custom hosts mapping from older workarounds
for host in "${CLEANUP_HOSTS[@]}"; do
    if grep -q "$host" /etc/hosts; then
        echo "🧹 Cleaning up legacy portal mapping '$host' from /etc/hosts (requires sudo)..."
        sudo sed -i "/$host/d" /etc/hosts
    fi
done

# 5. Flush systemd-resolved
echo "🧹 Flushing systemd-resolved cache (requires sudo)..."
sudo resolvectl flush-caches

# 6. Check Tailscale / VPN status
if ip addr show tailscale0 >/dev/null 2>&1; then
    echo "⚠️ WARNING: Tailscale is active and might block captive portals."
    echo "👉 If the login page does not load, run 'tailscale down'."
fi

# 7. Diagnostics and Portal Trigger
echo "🌐 Checking connection status..."
# Try to reach neverssl.com (HTTP-only) to see if we get redirected or fail
HTTP_STATUS=$(curl -o /dev/null -s -w "%{http_code}" --connect-timeout 3 http://neverssl.com)

if [ "$HTTP_STATUS" = "200" ]; then
    # Double check if we are actually online by querying a check string
    CANARY=$(curl -s --connect-timeout 3 http://detectportal.firefox.com/success.txt)
    if [[ "$CANARY" =~ "success" ]]; then
        echo "✅ You are already online!"
        exit 0
    fi
fi

echo "🚀 Triggering captive portal via http://neverssl.com..."
xdg-open "http://neverssl.com" 2>/dev/null || echo "👉 Please open http://neverssl.com manually."
echo "💡 Tip: If it fails, ensure 'DNS over HTTPS' is OFF in your browser."
