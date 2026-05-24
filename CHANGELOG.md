# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
