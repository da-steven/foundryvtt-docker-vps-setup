# CHANGELOG
- All notable changes to this repo are documented in this file.
- The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [unreleased]

### Added
- `cloudflare-tunnel-setup.sh`: Automates Cloudflare Tunnel setup for HTTPS access to Foundry VTT, including domain prompt with whitespace trimming and confirmation.

### Changed
- `foundryvtt-setup-oracle.sh`: 
  - Assumes fixed install path (`/opt/foundryvtt`) for use alongside a portable `scripts/` repo.
  - Added robust prompt and validation for Foundry download URL.
  - Appends logic to prompt user to optionally run `cloudflare-tunnel-setup.sh` after installation completes.

---

## Initial Commit
- Scaffolds WIP `foundryvtt-setup-oracle.sh` script.

---