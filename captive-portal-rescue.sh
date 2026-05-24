#!/bin/bash
# Captive Portal Rescue
# Saves your connection from DHCP DNS leaks and VPN blocks on public Wi-Fi captive portals.
# Supports NetworkManager-based systems with systemd-resolved.

# --- Configuration ---
# Set to true to enable extra debug output
DEBUG=false
# Optional legacy hosts entries to clean up (e.g. from previous manual workarounds)
CLEANUP_HOSTS=("guest.chipublib.org")

# State directory for backups
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/captive-portal-rescue"

# --- Helper Functions ---

# Help menu
show_help() {
    echo "Usage: $(basename "$0") [options]"
    echo "Saves your connection from DHCP DNS leaks and VPN blocks on public Wi-Fi captive portals."
    echo ""
    echo "Options:"
    echo "  -r, --restore    Restore the active Wi-Fi connection to its original DNS configuration"
    echo "  -s, --status     Show current connection details, custom DNS state, and VPN info"
    echo "  -h, --help       Show this help message"
    exit 0
}

# Filter to ONLY internal/private IPs (RFC 1918)
filter_internal_dns() {
    local dhcp_dns="$1"
    local internal_dns=""
    for ip in $dhcp_dns; do
        if [[ "$ip" =~ ^10\. || "$ip" =~ ^192\.168\. || "$ip" =~ ^172\.(1[6-9]|2[0-9]|3[0-1])\. ]]; then
            if [ -z "$internal_dns" ]; then
                internal_dns="$ip"
            else
                internal_dns="$internal_dns,$ip"
            fi
        fi
    done
    echo "$internal_dns"
}

# Detect active VPN interfaces
detect_vpn_interfaces() {
    if command -v ip &>/dev/null; then
        ip -o link show | awk -F': ' '{print $2}' | grep -E '^(tailscale|tun|wg|mullvad|cscotun|fortissl)' | xargs
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Parse options
    RESTORE_MODE=false
    STATUS_MODE=false
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            -r|--restore) RESTORE_MODE=true; shift ;;
            -s|--status) STATUS_MODE=true; shift ;;
            -h|--help) show_help ;;
            *) echo "Unknown option: $1"; show_help ;;
        esac
    done

    # Ensure nmcli is installed
    if ! command -v nmcli &>/dev/null; then
        echo "❌ Error: NetworkManager (nmcli) is not installed or not in PATH."
        exit 1
    fi

    # 1. Identify active Wi-Fi connection and interface
    ACTIVE_CON_UUID=$(nmcli -t -f UUID,TYPE con show --active | grep -iE "wifi|802-11-wireless" | cut -d: -f1 | head -n 1)
    DEVICE_NAME=$(nmcli -t -f DEVICE,TYPE connection show --active | grep -iE ":802-11-wireless|:wifi" | cut -d: -f1 | head -n 1)

    if [ -z "$ACTIVE_CON_UUID" ] || [ -z "$DEVICE_NAME" ]; then
        echo "❌ Error: No active Wi-Fi connection found."
        exit 1
    fi

    ACTIVE_CON_NAME=$(nmcli -g connection.id connection show "$ACTIVE_CON_UUID" 2>/dev/null)
    STATE_FILE="$STATE_DIR/${ACTIVE_CON_UUID}.state"

    # --- STATUS MODE ---
    if [ "$STATUS_MODE" = true ]; then
        echo "📋 Captive Portal Rescue Status"
        echo "=================================================="
        echo "📶 Active Wi-Fi:      $ACTIVE_CON_NAME"
        echo "🆔 Connection UUID:  $ACTIVE_CON_UUID"
        echo "🔌 Device Interface:  $DEVICE_NAME"
        
        IGNORE4=$(nmcli -g ipv4.ignore-auto-dns connection show "$ACTIVE_CON_UUID" 2>/dev/null || echo "unknown")
        DNS4=$(nmcli -g ipv4.dns connection show "$ACTIVE_CON_UUID" 2>/dev/null || echo "")
        IGNORE6=$(nmcli -g ipv6.ignore-auto-dns connection show "$ACTIVE_CON_UUID" 2>/dev/null || echo "unknown")
        DNS6=$(nmcli -g ipv6.dns connection show "$ACTIVE_CON_UUID" 2>/dev/null || echo "")
        
        echo "⚙️  Profile DNS settings:"
        echo "   - Ignore IPv4 Auto-DNS: $IGNORE4"
        echo "   - IPv4 DNS:             ${DNS4:-(none/automatic)}"
        echo "   - Ignore IPv6 Auto-DNS: $IGNORE6"
        echo "   - IPv6 DNS:             ${DNS6:-(none/automatic)}"
        
        if [ "$IGNORE4" = "yes" ] && [ -n "$DNS4" ]; then
            echo "🛡️  Rescue Status:      RESCUED (custom local gateway DNS applied)"
        else
            echo "🛡️  Rescue Status:      NORMAL (default/unaltered configuration)"
        fi
        
        VPN_IFS=$(detect_vpn_interfaces)
        if [ -n "$VPN_IFS" ]; then
            echo "⚠️  VPN Interfaces:     ACTIVE ($VPN_IFS)"
        else
            echo "🔒 VPN Interfaces:     None active"
        fi
        
        echo "🌐 Connectivity Check:"
        HTTP_STATUS=$(curl -o /dev/null -s -w "%{http_code}" --connect-timeout 3 http://neverssl.com)
        if [ "$HTTP_STATUS" = "200" ]; then
            CANARY=$(curl -s --connect-timeout 3 http://detectportal.firefox.com/success.txt)
            if [[ "$CANARY" =~ "success" ]]; then
                echo "   - Internet Access:   ONLINE"
            else
                echo "   - Internet Access:   PORTAL REDIRECTED / HIJACKED (Action required)"
            fi
        else
            echo "   - Internet Access:   OFFLINE (HTTP Status: $HTTP_STATUS or connection timeout)"
        fi
        echo "=================================================="
        exit 0
    fi

    # --- RESTORE MODE ---
    if [ "$RESTORE_MODE" = true ]; then
        if [ -f "$STATE_FILE" ]; then
            echo "💾 Found saved connection state. Restoring original settings..."
            # Source the state file
            # shellcheck disable=SC1090
            source "$STATE_FILE"
            
            echo "⚙️ Restoring DNS configuration..."
            nmcli connection modify "$ACTIVE_CON_UUID" \
                ipv4.ignore-auto-dns "$ORIG_IPV4_IGNORE" \
                ipv4.dns "$ORIG_IPV4_DNS" \
                ipv6.ignore-auto-dns "$ORIG_IPV6_IGNORE" \
                ipv6.dns "$ORIG_IPV6_DNS"
                
            rm -f "$STATE_FILE"
        else
            echo "🔄 No saved state found. Restoring connection profile to default automatic DHCP DNS..."
            nmcli connection modify "$ACTIVE_CON_UUID" ipv4.ignore-auto-dns no ipv4.dns ""
            nmcli connection modify "$ACTIVE_CON_UUID" ipv6.ignore-auto-dns no ipv6.dns ""
        fi
        
        echo "🔄 Re-activating connection to apply changes..."
        nmcli connection up "$ACTIVE_CON_UUID"
        
        if command -v resolvectl &>/dev/null && systemctl is-active --quiet systemd-resolved 2>/dev/null; then
            echo "🧹 Flushing systemd-resolved cache (requires sudo)..."
            sudo resolvectl flush-caches
        fi
        
        echo "✅ Connection restored."
        exit 0
    fi

    # --- FIX MODE ---

    echo "📶 Active Wi-Fi: '$ACTIVE_CON_NAME' (UUID: $ACTIVE_CON_UUID) on device '$DEVICE_NAME'"

    # 2. Extract DHCP DNS servers from the lease
    DHCP_DNS=$(nmcli -g DHCP4.OPTION device show "$DEVICE_NAME" 2>/dev/null | grep -oP '(?:^|[|])\s*domain_name_servers = \K[^|]+' | xargs)

    if [ "$DEBUG" = true ]; then
        echo "📥 DHCP raw DNS servers: $DHCP_DNS"
    fi

    INTERNAL_DNS=$(filter_internal_dns "$DHCP_DNS")

    if [ -z "$INTERNAL_DNS" ]; then
        echo "⚠️ No internal DNS servers found in DHCP lease! Falling back to Gateway."
        GATEWAY_IP=$(nmcli -g IP4.GATEWAY device show "$DEVICE_NAME" 2>/dev/null | head -n 1)
        if [ -z "$GATEWAY_IP" ]; then
            GATEWAY_IP=$(ip route show default 2>/dev/null | awk '{print $3}')
        fi
        INTERNAL_DNS="$GATEWAY_IP"
    fi

    echo "🔍 Filtered internal DNS servers to use: $INTERNAL_DNS"

    # 3. Backup current settings before modifying
    mkdir -p "$STATE_DIR"
    if [ ! -f "$STATE_FILE" ]; then
        echo "💾 Backing up current connection DNS configuration..."
        ORIG_IPV4_IGNORE=$(nmcli -g ipv4.ignore-auto-dns connection show "$ACTIVE_CON_UUID" 2>/dev/null || echo "no")
        ORIG_IPV4_DNS=$(nmcli -g ipv4.dns connection show "$ACTIVE_CON_UUID" 2>/dev/null || echo "")
        ORIG_IPV6_IGNORE=$(nmcli -g ipv6.ignore-auto-dns connection show "$ACTIVE_CON_UUID" 2>/dev/null || echo "no")
        ORIG_IPV6_DNS=$(nmcli -g ipv6.dns connection show "$ACTIVE_CON_UUID" 2>/dev/null || echo "")
        
        cat <<EOF > "$STATE_FILE"
ORIG_IPV4_IGNORE='$ORIG_IPV4_IGNORE'
ORIG_IPV4_DNS='$ORIG_IPV4_DNS'
ORIG_IPV6_IGNORE='$ORIG_IPV6_IGNORE'
ORIG_IPV6_DNS='$ORIG_IPV6_DNS'
EOF
    else
        echo "ℹ️ State file already exists. Skipping backup to preserve original pre-rescue configuration."
    fi

    # 4. Apply internal DNS and disable automatic DNS for both IPv4 and IPv6 to prevent leaks
    echo "⚙️ Configuring NetworkManager to ignore public DNS..."
    nmcli connection modify "$ACTIVE_CON_UUID" ipv4.ignore-auto-dns yes ipv4.dns "$INTERNAL_DNS" ipv6.ignore-auto-dns yes

    echo "🔄 Re-activating connection to apply changes..."
    nmcli connection up "$ACTIVE_CON_UUID"

    # 5. Cleanup any broken custom hosts mapping from older workarounds
    for host in "${CLEANUP_HOSTS[@]}"; do
        if grep -q "$host" /etc/hosts; then
            echo "🧹 Cleaning up legacy portal mapping '$host' from /etc/hosts (requires sudo)..."
            sudo sed -i "/$host/d" /etc/hosts
        fi
    done

    # 6. Flush systemd-resolved
    if command -v resolvectl &>/dev/null && systemctl is-active --quiet systemd-resolved 2>/dev/null; then
        echo "🧹 Flushing systemd-resolved cache (requires sudo)..."
        sudo resolvectl flush-caches
    fi

    # 7. Check VPN status
    VPN_IFS=$(detect_vpn_interfaces)
    if [ -n "$VPN_IFS" ]; then
        echo "⚠️ WARNING: VPN interface(s) active: $VPN_IFS"
        echo "👉 VPNs route traffic away from the local gateway and can block captive portals."
        echo "👉 If the login page does not load, please temporarily disable your VPN (e.g. 'tailscale down')."
    fi

    # 8. Diagnostics and Portal Trigger
    echo "🌐 Checking connection status..."
    HTTP_STATUS=$(curl -o /dev/null -s -w "%{http_code}" --connect-timeout 3 http://neverssl.com)

    if [ "$HTTP_STATUS" = "200" ]; then
        CANARY=$(curl -s --connect-timeout 3 http://detectportal.firefox.com/success.txt)
        if [[ "$CANARY" =~ "success" ]]; then
            echo "✅ You are already online!"
            exit 0
        fi
    fi

    echo "🚀 Triggering captive portal via http://neverssl.com..."
    xdg-open "http://neverssl.com" 2>/dev/null || echo "👉 Please open http://neverssl.com manually."
    echo "💡 Tip: If it fails, ensure 'DNS over HTTPS' is OFF in your browser."
fi
