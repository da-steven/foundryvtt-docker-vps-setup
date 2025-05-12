# CHANGELOG
- All notable changes to this repo are documented in this file.
- The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [unreleased]

### Added
- `cloudflare/tools/cloudflare-tunnel-setup.sh`: Improves setup script using Cloudflare's official APT repository, domain validation, and optional service install.
- `cloudflare/tools/cloudflare-tunnel-teardown.sh`: Safely deletes tunnels, removes config files, and optionally uninstalls `cloudflared`.
- `cloudflare/tools/cloudflare-tunnel-status.sh`: Displays tunnel list, current config file status, and validates `cloudflared` presence.
- `cloudflare/cloudflare-tools.sh`: Menu-based wrapper for tunnel setup, teardown, and status tools.

### Changed
- `foundryvtt-setup.sh`:
  - Corrects path handling to launch tunnel setup from the `scripts` repo instead of `/opt`.
  - Skips download prompt if `foundryvtt.zip` is already present unless `--force-download` is passed.
  - Adds support for detecting and optionally installing Docker BuildKit (`buildx`), with fallback to legacy builder.
  - Improves final success checks to avoid misleading success messages after a failed container build.
- `cloudflare/tools/cloudflare-tunnel-setup.sh`:
  - Resolves and uses absolute path to `cloudflared` to prevent PATH-related errors after install.
  - Adds a post-install sanity check to confirm `cloudflared` is usable before continuing.
  - Runs the tunnel via resolved binary to ensure reliability.
  - Adds validation and status check when installing as a `systemd` service:
    - Confirms whether the service is running (`active`)
    - Confirms whether the service is enabled to start on boot
- Replaced APT-based install with direct binary install from GitHub to ensure compatibility with Ubuntu 24.04 (Noble) and future distros.
  - Downloads the latest `cloudflared-linux-amd64`.
  - Installs to `/usr/local/bin` and verifies installation path.

---

## Initial Commit
- Scaffolds WIP `foundryvtt-setup-oracle.sh` script.

---