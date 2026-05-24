# Captive Portal Rescue 📶

A smart, zero-configuration CLI tool to bypass/fix broken public Wi-Fi captive portals (such as libraries, hotels, and cafes) on Linux systems using NetworkManager and systemd-resolved.

## The Problem

Many Linux developers configure custom static DNS servers (e.g., Cloudflare `1.1.1.1` or Google `8.8.8.8`), enable DNS-over-HTTPS (DoH), or run VPN mesh networks like Tailscale or WireGuard.

Public Wi-Fi captive portals rely on **DNS hijacking** to redirect your initial browser requests to their login/landing page. Custom DNS and VPN configs block this redirection. As a result:

- Your system connects to the Wi-Fi.
- The portal redirection fails (resulting in DNS timeout or SSL errors).
- You cannot access the login page and cannot get online.

## How it Works

`captive-portal-rescue.sh` automates the temporary restoration of the local network configuration:

1. **Active Wi-Fi Detection:** Auto-detects the active NetworkManager Wi-Fi interface and profile (using `nmcli`).
2. **DNS Leak Protection (IPv4 & IPv6):** Temporarily configures the profile to ignore automatic DNS and binds DNS lookup exclusively to the internal gateway IP assigned by the captive portal's DHCP lease. It also disables auto IPv6 DNS to prevent leaks.
3. **resolved Cache Clearing:** Flushes the `systemd-resolved` DNS cache (using `resolvectl flush-caches`).
4. **VPN Warnings:** Detects and flags active VPN tunnels (like Tailscale) that route traffic and break portals.
5. **Connectivity Canary:** Checks connection status using the Firefox captive portal canary (`detectportal.firefox.com`).
6. **Trigger Portal:** Forces redirection using HTTP-only `neverssl.com` and launches your default browser.
7. **Easy Restore:** Restores your automatic/custom profile DNS configurations in one command.

---

## Installation

### Quick Run (without installing)

```bash
curl -fsSL https://raw.githubusercontent.com/KnowOneActual/captive-portal-rescue/main/captive-portal-rescue.sh | bash
```

### Direct Download / Install

1. Clone the repository or download the script:
   ```bash
   git clone https://github.com/KnowOneActual/captive-portal-rescue.git
   cd captive-portal-rescue
   ```
2. Make the script executable:
   ```bash
   chmod +x captive-portal-rescue.sh
   ```
3. (Optional) Install it globally:
   ```bash
   sudo ln -s "$(pwd)/captive-portal-rescue.sh" /usr/local/bin/captive-rescue
   ```

---

## Usage

### 🚀 Fix the Captive Portal

Run the script to point your active connection to the captive portal DNS and launch the login page:

```bash
captive-rescue
```

_(Or `./captive-portal-rescue.sh` if not installed globally)._

### 🔄 Restore Custom Settings

Once you successfully log in and are online, restore your original DNS and connection settings:

```bash
captive-rescue --restore
```

_(Or `./captive-portal-rescue.sh --restore`)._

---

## Troubleshooting 🔍

If you run into issues or the captive portal page still doesn't load after running the rescue script, see the [Wi-Fi Captive Portal Troubleshooting Guide](docs/troubleshooting.md) for step-by-step diagnostic workflows, DNS leak checks, and data collection playbooks.

---

## Requirements & Compatibility

- **OS:** Linux (Fedora, Ubuntu, Debian, Arch Linux, etc.)
- **Network Manager:** `NetworkManager` (`nmcli` command line utility)
- **DNS Resolver:** `systemd-resolved` (`resolvectl` command line utility)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
