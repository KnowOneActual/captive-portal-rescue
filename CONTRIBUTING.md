# Contributing to Captive Portal Rescue

First off, thank you for taking the time to contribute! Contributions from the community help make this tool more reliable, robust, and compatible across different Linux distributions.

---

## 🛠️ Local Development & Environment Setup

Since `captive-portal-rescue.sh` is a shell script, setting up a development environment is straightforward:

1. **Clone the Repository:**
   ```bash
   git clone https://github.com/KnowOneActual/captive-portal-rescue.git
   cd captive-portal-rescue
   ```
2. **Make the script executable:**
   ```bash
   chmod +x captive-portal-rescue.sh
   ```

### Code Quality & Linting

We use [ShellCheck](https://www.shellcheck.net/) to verify script syntax, catch common mistakes, and enforce shell scripting best practices.

1. **Install ShellCheck locally:**
   - **Ubuntu/Debian:** `sudo apt install shellcheck`
   - **Fedora/RHEL:** `sudo dnf install shellcheck`
   - **Arch Linux:** `sudo pacman -S shellcheck`
   - **macOS:** `brew install shellcheck`

2. **Run ShellCheck on the script:**
   ```bash
   shellcheck captive-portal-rescue.sh
   ```

*Note: The script must pass ShellCheck with zero warnings before a pull request can be merged. The CI pipeline will automatically run ShellCheck on all PRs.*

---

## 🧪 Testing Your Changes

Because captive portals rely on local network setups and OS environment configurations (NetworkManager and systemd-resolved), manual verification is the primary way to test changes.

1. **Dry-Run & Debugging:**
   You can set the `DEBUG=true` flag inside `captive-portal-rescue.sh` to log detailed output.
2. **Verification checklist:**
   - Connect to a public network containing a captive portal.
   - Run the script and verify that it correctly identifies the active Wi-Fi profile.
   - Verify that local DNS is successfully locked to the gateway/internal IPs.
   - Verify that the portal loads in your default browser.
   - Run with `--restore` and verify that your custom/previous DNS settings are correctly reapplied.

---

## 📥 Submitting a Pull Request

1. **Create a branch:**
   ```bash
   git checkout -b feature/your-feature-name
   ```
2. **Commit your changes:**
   Keep commit messages descriptive and focused (e.g. `fix: handle legacy nmcli version output in DHCP check`).
3. **Update the Changelog:**
   Add a brief note about your changes under the `[Unreleased]` section of the [CHANGELOG.md](CHANGELOG.md).
4. **Push and Open a PR:**
   Push your branch to your fork and submit a PR to our `main` branch. Ensure the GitHub Actions lint checks pass!
