#!/bin/bash
# Unit Tests for Captive Portal Rescue parsing logic

# Path to the script under test
SCRIPT_PATH="$(dirname "$0")/../captive-portal-rescue.sh"

if [ ! -f "$SCRIPT_PATH" ]; then
    echo "❌ Error: Could not find script at $SCRIPT_PATH"
    exit 1
fi

# Source the script (only imports functions, does not execute main due to BASH_SOURCE check)
# shellcheck disable=SC1090
source "$SCRIPT_PATH"

failed=0
total=0

# Helper assertion function
assert_equals() {
    local expected="$1"
    local actual="$2"
    local test_name="$3"
    total=$((total + 1))
    
    if [ "$expected" = "$actual" ]; then
        echo "✅ PASS: $test_name"
    else
        echo "❌ FAIL: $test_name"
        echo "   Expected: '$expected'"
        echo "   Actual:   '$actual'"
        failed=$((failed + 1))
    fi
}

echo "🏃 Running unit tests..."
echo "----------------------------------------"

# --- Test filter_internal_dns ---

# Test 1: Mixed public and private IPs
res1=$(filter_internal_dns "192.168.1.1 8.8.8.8 10.0.0.1")
assert_equals "192.168.1.1,10.0.0.1" "$res1" "filter_internal_dns: Mixed public and private IPs"

# Test 2: Only public IPs
res2=$(filter_internal_dns "8.8.8.8 1.1.1.1 9.9.9.9")
assert_equals "" "$res2" "filter_internal_dns: Only public IPs"

# Test 3: Only private IPs
res3=$(filter_internal_dns "10.50.2.1 192.168.100.254")
assert_equals "10.50.2.1,192.168.100.254" "$res3" "filter_internal_dns: Only private IPs"

# Test 4: RFC 1918 172.16.x.x range boundary checks
res4=$(filter_internal_dns "172.15.254.254 172.16.0.1 172.31.255.255 172.32.0.1")
assert_equals "172.16.0.1,172.31.255.255" "$res4" "filter_internal_dns: 172.16-31 range boundary checks"

# Test 5: Empty input
res5=$(filter_internal_dns "")
assert_equals "" "$res5" "filter_internal_dns: Empty input"


# --- Test detect_vpn_interfaces ---

# Mock ip command to return specific links
# shellcheck disable=SC2329
ip() {
    echo "1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536"
    echo "2: wlp2s0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500"
    echo "3: tailscale0: <POINTOPOINT,MULTICAST,NOARP,UP,LOWER_UP> mtu 1280"
    echo "4: wg-mullvad: <POINTOPOINT,NOARP,UP,LOWER_UP> mtu 1420"
    echo "5: docker0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500"
    echo "6: tun0: <POINTOPOINT,MULTICAST,NOARP,UP,LOWER_UP> mtu 1500"
}

# Run the test
res_vpn=$(detect_vpn_interfaces)
assert_equals "tailscale0 wg-mullvad tun0" "$res_vpn" "detect_vpn_interfaces: Matches multiple VPN types"

# Mock ip command to return no VPN links
# shellcheck disable=SC2329
ip() {
    echo "1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536"
    echo "2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500"
    echo "3: wlan0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500"
}

res_no_vpn=$(detect_vpn_interfaces)
assert_equals "" "$res_no_vpn" "detect_vpn_interfaces: No VPN active"

# Clean up mock by unsetting it
unset -f ip

# --- Summary ---
echo "----------------------------------------"
if [ "$failed" -eq 0 ]; then
    echo "🎉 SUCCESS: All $total tests passed!"
    exit 0
else
    echo "❌ FAILURE: $failed of $total tests failed!"
    exit 1
fi
