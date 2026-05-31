# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.3.0] - 2026-05-31

### Added
- Added a `--plan` / `-p` (dry-run) option to preview NetworkManager connection modifications, hosts cleanup, and cache flushes without applying changes to the system.

## [1.2.1] - 2026-05-29

### Changed
- Refactored connectivity checks in status mode, default mode, and diagnostic mode to use HTTPS (`https://clients3.google.com/generate_204`) bound to the active wireless interface (`--interface`) to prevent false positives when a VPN is active or HTTP check domains are whitelisted.
- Improved status check (`-s`) output to report detailed connectivity states: `ONLINE`, `PORTAL WHITING/LIMITED`, `PORTAL REDIRECTED / HIJACKED`, and `OFFLINE`.

### Fixed
- Fixed a bug where `captive-portal-rescue.sh` incorrectly identified the connection as online and exited early on networks that whitelist HTTP checks or when a VPN is active.
- Fixed `detect_portal_domain` failing to find the portal domain on networks that whitelist `neverssl.com` by adding an interface-bound fallback query to `example.com`.

## [1.2.0] - 2026-05-27

### Added
- Added dynamic captive portal domain detection by querying `http://neverssl.com` and parsing both `Location` headers and HTML meta tags.
- Added DNS server probing using `dig` to verify which DNS servers successfully resolve the portal domain.
- Added settling delay (3 seconds) after re-activating connection (`nmcli connection up`) to allow network configuration to bind.

### Changed
- Refactored connectivity checks to use IPv4-only (`curl -4`) to avoid slow connection delays on networks with unreachable IPv6 setups.
- Moved connectivity check to the start of the fix mode to exit early if already online.
- Modified DNS configuration fallback to configure only the primary (first) RFC 1918 DNS server, preventing DNS poisoning from secondary resolvers.

### Fixed
- Fixed ShellCheck warnings (SC2034 and SC2076) in the main script.

## [1.1.0] - 2026-05-24

### Added
- Added connection status command option (`--status` or `-s`) to inspect active profile settings, VPN interfaces, and connectivity.
- Added state-saving backups for connection DNS profiles; restoring now precisely reverts connection custom DNS settings back to their pre-rescue configuration.
- Added unit and integration tests under `test/test_parsing.sh` to validate helper functions (DNS filtering, VPN detection) using mocked environments.
- Added a comprehensive [Wi-Fi Captive Portal Troubleshooting Guide](docs/troubleshooting.md) for Linux diagnostic flows, packet captures, and manual DNS probing.
- Linked the troubleshooting guide in the [README.md](README.md) under a new **Troubleshooting** section.
- Added GitHub Actions workflow to run `shellcheck` linting automatically on all pull requests and pushes to `main`.
- Added [CONTRIBUTING.md](CONTRIBUTING.md) with guidelines for local development, ShellCheck setup, and PR flows.
- Added [SECURITY.md](SECURITY.md) outlining vulnerability disclosure instructions.
- Added GitHub issue templates for bug reports and feature requests.

### Changed
- Improved active connection targeting by matching via UUID (`ACTIVE_CON_UUID`) instead of connection ID, resolving naming conflicts with spaces, colons, or special characters.
- Expanded active VPN interface detection to include `wg*`, `tun*`, `mullvad`, `cscotun`, and `fortissl`.
- Refactored `captive-portal-rescue.sh` to encapsulate parsing logic in functions, enabling sourcing without execution for unit testing.
- Restructured `resolvectl` cache flushes to run conditionally only if the systemd-resolved service is active.
- Updated `README.md` to recommend bash process substitution for curl pipelines to keep standard input open for interactive sudo prompts.

### Fixed
- Fixed script exiting silently when executing from standard input (e.g., `curl ... | bash`) by allowing an empty `BASH_SOURCE[0]` in the main execution check.
- Fixed the quick run instruction in [README.md](README.md) to pipe the downloaded script into bash for execution instead of just printing it.

### Removed
- Removed the legacy/temporary `temp-files/` directory containing the unpolished troubleshooting draft.

## [1.0.0] - 2026-05-23

### Added
- Initial release of the `captive-portal-rescue.sh` script to fix DNS redirection blocks on public Wi-Fi.
- Added usage instructions and requirement checklist in the `README.md`.
