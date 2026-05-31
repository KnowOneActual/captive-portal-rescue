# Roadmap 🗺️

This document outlines the planned future improvements and features for **Captive Portal Rescue**.

---

## 📋 Planned Features

### 1. Proxy Detection & Diagnostics
* **Problem:** Active local or corporate proxy settings (`http_proxy`, `https_proxy`, `all_proxy`) intercept HTTP traffic, which blocks captive portal redirects and breaks connectivity detection.
* **Goal:** Detect these active proxy environment variables during `--status` checks and the rescue process, and warn the user/provide instructions to temporarily disable them.

### 2. `resolvectl` Dynamic DNS Override (Fallback/No-Sudo Mode)
* **Problem:** Some enterprise or restricted Linux environments do not allow users to modify persistent NetworkManager connection profiles (`nmcli connection modify` fails).
* **Goal:** Implement a fallback mechanism using `resolvectl dns <interface> <dns>` to temporarily inject the captive portal DNS for the active link. This bypasses profile modifications and avoids needing persistent configuration changes.

### 3. Interactive VPN Helper
* **Problem:** VPN tunnels (Tailscale, Mullvad, WireGuard) route traffic away from the local gateway, which is the primary reason captive portal logins fail.
* **Goal:** Automatically prompt the user when a VPN is active during rescue, offer to temporarily disable it (e.g. running `tailscale down`), and restore its status automatically when `--restore` is run.
