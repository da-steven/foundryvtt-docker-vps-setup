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

---

## Initial Commit
- Scaffolds WIP `foundryvtt-setup-oracle.sh` script.

---