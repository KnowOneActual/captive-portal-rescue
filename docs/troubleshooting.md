# Wi-Fi Captive Portal Troubleshooting Guide

This guide outlines diagnostic flows, common failure modes, and a data-collection playbook to troubleshoot public Wi-Fi captive portals and DNS leaks on Linux.

---

## 🔍 Captive Portal Diagnostic Checklist

When connecting to a public Wi-Fi network and failing to reach the login/landing portal, run through these check items in order:

### 1. Physical & Link Layer
* **Action:** Ensure you have successfully connected to the Wi-Fi network and received an IP address on your interface.
* **Commands:**
  ```bash
  nmcli device status
  ip addr show dev wlp2s0  # Replace 'wlp2s0' with your active Wi-Fi interface name
  ```
* **Failure State:** If your interface lacks an IP address in the private range (e.g., `10.x.x.x`, `172.16.x.x`–`172.31.x.x`, or `192.168.x.x`), the DHCP negotiation has failed. Try reconnecting to the SSID or cycling your Wi-Fi interface.

### 2. DNS Leak / Custom DNS Check
* **Action:** Inspect the currently active DNS resolvers and compare them against what the DHCP server pushed.
* **Commands:**
  ```bash
  # Check active resolvers handled by systemd-resolved
  resolvectl status
  
  # Extract the DNS servers provided by DHCP
  nmcli -g DHCP4.OPTION device show wlp2s0 | grep -oP '(?:^|[|])\s*domain_name_servers = \K[^|]+'
  ```
* **Failure State:** If public DNS servers (like `8.8.8.8`, `1.1.1.1`, or custom VPN resolvers) are configured as primary resolvers, they will bypass the portal's DNS redirection or fail to resolve local portal-only hostnames (e.g., `guest.chipublib.org`).

### 3. VPN / Tunneling Software
* **Action:** Check if Tailscale, WireGuard, or a corporate/commercial VPN tunnel is running.
* **Commands:**
  ```bash
  ip addr | grep -E "tailscale|tun|wg"
  tailscale status
  ```
* **Failure State:** VPNs route traffic and DNS requests away from the local gateway. If active, they intercept queries or route HTTP traffic through their tunnels, preventing the portal from redirecting your browser to the login page.
* **Fix:** Temporarily disable the VPN (e.g., run `tailscale down` or disconnect your VPN client) until you authenticate.

### 4. Browser DNS-over-HTTPS (DoH)
* **Action:** Verify whether your browser has Secure DNS / DNS-over-HTTPS (DoH) active.
* **Failure State:** DoH sends encrypted DNS queries to servers like Cloudflare or Google over HTTPS (port 443). The captive portal blocks port 443 until you authenticate, causing browser requests to hang or fail without redirecting.
* **Fix:** Temporarily disable DNS-over-HTTPS in your browser settings (usually found under Privacy & Security -> Security -> Enable Secure DNS / DNS-over-HTTPS).

---

## 📊 Data Collection Playbook

If you encounter a captive portal that fails to load even after basic troubleshooting, run these diagnostic steps to gather logs and write targeted fixes.

### 1. Capture Network Configuration State
Generate a diagnostic log summarizing your network's current state:
```bash
{
  echo "=== DATE ==="; date
  echo "=== NETWORK INTERFACES ==="; ip addr
  echo "=== ACTIVE CONNECTIONS ==="; nmcli connection show --active
  echo "=== ROUTING TABLE ==="; ip route show
  echo "=== RESOLV.CONF ==="; cat /etc/resolv.conf
  echo "=== RESOLVCTL STATUS ==="; resolvectl status
  echo "=== DHCP LEASE OPTIONS ==="; nmcli device show
} > ~/wifi_debug_state.log
```

### 2. Capture Network Packets (PCAP)
To watch DNS queries and HTTP redirection requests in real-time, capture packets on your Wi-Fi interface using `tshark` or `tcpdump`:

```bash
# Capture DNS (port 53) and HTTP (port 80) traffic to analyze redirection behavior
sudo tshark -i wlp2s0 -Y "dns || tcp.port == 80" -w ~/wifi_trace.pcapng
```
* **How to run the trace:**
  1. Start the packet capture.
  2. Open your browser in a Private/Incognito window.
  3. Try navigating to `http://neverssl.com`.
  4. Wait for the page to time out or attempt a redirect.
  5. Stop the capture (`Ctrl+C`) and inspect the PCAP.

### 3. Manual Redirection Probing
Test the local gateway's HTTP interception behavior directly:
```bash
# Verify if HTTP requests are intercepted and redirected (look for 302/307 redirects)
curl -Iv http://neverssl.com

# Check if public DNS resolution works
nslookup neverssl.com

# Probe if outbound DNS requests to public servers are blocked (probes port 53 blockage)
nslookup neverssl.com 8.8.8.8
```

---

## 🛠️ Script Fixes & Recovery Options

### Apply Captive Portal Rescue
If custom DNS configurations or leaks are preventing you from reaching the portal:
```bash
# Run the rescue script from the repository root
./captive-portal-rescue.sh
```
*This backs up your active profile's original DNS settings, configures it to temporarily ignore public DNS in favor of the local gateway DNS, and flushes the resolver cache.*

### Check Connection Status
To inspect the rescue state, profile settings, active VPN interfaces, and network connectivity:
```bash
./captive-portal-rescue.sh --status
```

### Restore Custom Settings
Once you successfully log in and are online, precisely restore your connection's original pre-rescue configuration:
```bash
./captive-portal-rescue.sh --restore
```
*This reads the state file generated during the rescue, reapplies your original DNS properties, clears the state file, and flushes the resolver cache.*

### Manual Network Restart
If the network interfaces or NetworkManager become unstable during configuration changes:
```bash
sudo systemctl restart NetworkManager
```
