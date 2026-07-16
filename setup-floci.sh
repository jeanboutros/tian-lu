#!/usr/bin/env bash
#
# setup-floci.sh
#
# Setup Floci (AWS emulator) on Ubuntu Server using rootless Podman.
#
# Creates a dedicated "floci" user with a locked password, installs rootless
# Podman if missing, configures Floci with persistent storage and TLS, creates
# a hardened systemd user service with lingering, and opens firewall ports
# to the trusted LAN subnet.
#
# Idempotent: safe to run multiple times without corrupting existing state.
#
# Usage:
#   sudo ./setup-floci.sh                    # non-interactive, auto-detect LAN /24
#   sudo ./setup-floci.sh --interactive      # pause at each phase for inspection
#   sudo ./setup-floci.sh --firewall-scope=rfc1918   # open to all RFC1918
#
# Requirements:
#   - Ubuntu 24.04+ (tested on 26.04 LTS)
#   - Root or sudo privileges for the setup phase
#
# See REVIEW.md for design rationale and challenger review findings.

set -euo pipefail
IFS=$'\n\t'

# ============================================================================
# CONFIGURATION
# ============================================================================

# --- User ---
readonly FLOCI_USER="floci"
readonly FLOCI_HOME="/home/floci"
readonly FLOCI_SHELL="/bin/bash"
readonly FLOCI_HOME_PERMS="0700"

# --- Rootless Podman ---
readonly SUBUID_START="100000"
readonly SUBUID_COUNT="262144"
readonly PODMAN_NETWORK="floci-net"

# --- Floci image ---
readonly FLOCI_IMAGE="floci/floci:1.5.33-compat"

# --- Floci configuration ---
readonly FLOCI_HOSTNAME="tianlu-floci"
readonly FLOCI_BASE_URL="https://tianlu-floci:4566"
readonly FLOCI_DEFAULT_REGION="eu-west-1"
readonly FLOCI_DEFAULT_ACCOUNT_ID="000000000000"
readonly FLOCI_STORAGE_MODE="persistent"
readonly FLOCI_STORAGE_PERSISTENT_PATH="/app/data"
readonly FLOCI_HOST_PERSISTENT_PATH="${FLOCI_HOME}/floci-data"
readonly FLOCI_TLS_ENABLED="true"
readonly FLOCI_TLS_SELF_SIGNED="true"

# --- Ports (container -p mappings) ---
readonly FLOCI_PORTS_CONTAINER=(
  "4566:4566"
  "6379-6399:6379-6399"
  "7001-7099:7001-7099"
)

# --- Ports (UFW firewall rules) ---
readonly FLOCI_PORTS_FIREWALL=(
  "4566"
  "6379:6399"
  "7001:7099"
  "5100:5199"
  "6500:6599"
  "9400:9499"
  "2200:2299"
  "9169"
)

# --- Firewall scope ---
# Default: auto-detect server's LAN /24 subnet from the default-route interface.
# Override with --firewall-scope=rfc1918 to open to all RFC1918 ranges.
# NOTE: If the server's IP changes (e.g. moved to a different network), the
# firewall rules become stale. Re-run the script to re-detect, or fix a static
# IP via /etc/netplan/ to avoid this. See docs/design/solution-design.md §9.4.
FIREWALL_SCOPE="auto"
UFW_TRUSTED_SUBNETS=()
readonly UFW_RFC1918_SUBNETS=(
  "10.0.0.0/8"
  "172.16.0.0/12"
  "192.168.0.0/16"
)

# --- Paths ---
readonly FLOCI_ENV_DIR="${FLOCI_HOME}/.config/floci"
readonly FLOCI_ENV_FILE="${FLOCI_ENV_DIR}/floci.env"
readonly FLOCI_DATA_DIR="${FLOCI_HOME}/floci-data"
readonly SYSTEMD_USER_DIR="${FLOCI_HOME}/.config/systemd/user"
readonly FLOCI_SERVICE_FILE="${SYSTEMD_USER_DIR}/floci.service"

# --- Interactive mode ---
# When --interactive is set and stdin is a TTY, the script pauses at each
# phase boundary. This allows inspection between phases (e.g. viewing
# curl output after the service starts, checking user creation, etc.).
# Without --interactive, or when stdin is not a TTY, all phases run
# continuously.
INTERACTIVE="false"

# ============================================================================
# PHASES
# ============================================================================
#
# Phase 1: Preflight       — assert_root, assert_ubuntu, detect_hostname_ip
# Phase 2: User setup      — create_floci_user, lock_password, configure_subuid_subgid
# Phase 3: Podman setup    — install_podman, enable_lingering, configure_xdg_runtime, start_podman_socket
# Phase 4: Network & image — create_podman_network, pull_floci_image
# Phase 5: Floci config    — create_data_dir, add_hosts_entry, generate_presign_secret, write_env_file, write_systemd_unit
# Phase 6: Start & verify  — enable_systemd_service, configure_firewall, verify_health
# Phase 7: Summary         — print_summary

# ============================================================================
# FUNCTIONS
# ============================================================================

# (Implementation pending approval.)

# ============================================================================
# MAIN
# ============================================================================

echo "setup-floci.sh — skeleton pending implementation."