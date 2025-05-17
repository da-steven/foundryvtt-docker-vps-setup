#!/bin/bash
# ------------------------------------------------------------------------------
# load-env.sh
# ------------------------------------------------------------------------------
# Centralized environment loader for Foundry VTT setup and tunnel scripts.
# Supports:
# - .env.defaults (required defaults)
# - .env.local (optional user overrides)
# - Multi-instance support via MAIN_INSTANCE and INSTANCE_SUFFIX
# ------------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

ENV_DEFAULTS="$SCRIPT_DIR/.env.defaults"
ENV_LOCAL="$SCRIPT_DIR/.env.local"

# === Load environment files ===
if [[ -f "$ENV_DEFAULTS" ]]; then
  source "$ENV_DEFAULTS"
else
  echo "❌ Missing required file: $ENV_DEFAULTS"
  exit 1
fi

if [[ -f "$ENV_LOCAL" ]]; then
  source "$ENV_LOCAL"
fi

# === Validate required install path ===
if [[ "$MAIN_INSTANCE" == "true" ]]; then
  if [[ -z "$FOUNDRY_MAIN_INSTALL_DIR" ]]; then
    echo "❌ MAIN_INSTANCE=true, but FOUNDRY_MAIN_INSTALL_DIR is not set."
    exit 1
  fi
else
  if [[ -z "$FOUNDRY_ALT_BASE_DIR" ]]; then
    echo "❌ MAIN_INSTANCE=false, but FOUNDRY_ALT_BASE_DIR is not set."
    exit 1
  fi
  if [[ -z "$INSTANCE_SUFFIX" ]]; then
    echo "❌ Missing INSTANCE_SUFFIX for alt install. You must define this before sourcing load-env.sh."
    exit 1
  fi
fi

# === Resolve FOUNDRY_CONTAINER_NAME and restart policy ===
if [[ "$MAIN_INSTANCE" == "true" ]]; then
  FOUNDRY_CONTAINER_NAME="${FOUNDRY_CONTAINER_NAME:-foundryvtt}"
  DOCKER_RESTART_POLICY="${MAIN_DOCKER_RESTART_POLICY:-unless-stopped}"
else
  FOUNDRY_CONTAINER_NAME="foundryvtt-$INSTANCE_SUFFIX"
  DOCKER_RESTART_POLICY="${ALT_DOCKER_RESTART_POLICY:-no}"
fi

# === Resolve data dir ===
if [[ "$MAIN_INSTANCE" == "true" ]]; then
  DATA_DIR="${FOUNDRY_DATA_DIR:-$HOME/foundryvtt-data}"
else
  DATA_DIR="${FOUNDRY_DATA_DIR:-$HOME/foundryvtt-data}-$INSTANCE_SUFFIX"
fi

# === Final exports for all scripts ===
export FOUNDRY_PORT="${FOUNDRY_PORT:-30000}"
export FOUNDRY_CONTAINER_NAME
export DOCKER_RESTART_POLICY
export DATA_DIR