---
name: Bug Report
about: Create a report to help us fix issues with the rescue script
title: '[BUG] '
labels: bug
assignees: ''
---

**Describe the bug**
A clear and concise description of what the bug is (e.g. script crashes, DNS isn't restored, VPN check fails).

**To Reproduce**
Steps to reproduce the behavior:
1. Connect to Wi-Fi SSID '...'
2. Run script with command '...'
3. See error '...'

**Diagnostics Output**
If possible, please run the diagnostic commands from our Troubleshooting Guide and paste the output of `~/wifi_debug_state.log` here:
```text
(Paste contents of ~/wifi_debug_state.log here)
```

**Environment Info:**
- **Linux Distribution & Version:** (e.g. Fedora 40, Ubuntu 24.04, Arch Linux)
- **NetworkManager Version:** (`nmcli --version`)
- **systemd-resolved Status:** (`systemctl status systemd-resolved`)
- **Active Connection Details:** (e.g. public library portal, hotel portal)

**Additional Context**
Add any other context about the problem here.
