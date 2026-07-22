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

# CONFIG values below are consumed by phase functions that are implemented
# incrementally (one unit per commit); until every function lands, some appear
# unused to shellcheck. This file-wide SC2034 disable is TEMPORARY and is
# removed in the final unit once all config values are wired in.
# shellcheck disable=SC2034

set -euo pipefail
IFS=$'\n\t'

# ============================================================================
# CONFIGURATION
# ============================================================================
#
# Every scalar parameter uses the `${VAR:-default}` form so tests can inject
# overrides (e.g. a tmp HOME/root) by exporting the variable before sourcing
# this script. Values are frozen with `readonly` immediately after.

# --- User ---
readonly FLOCI_USER="${FLOCI_USER:-floci}"
readonly FLOCI_HOME="${FLOCI_HOME:-/home/floci}"
readonly FLOCI_SHELL="${FLOCI_SHELL:-/bin/bash}"
readonly FLOCI_HOME_PERMS="${FLOCI_HOME_PERMS:-0700}"

# --- Rootless Podman ---
readonly SUBUID_START="${SUBUID_START:-100000}"
readonly SUBUID_COUNT="${SUBUID_COUNT:-262144}"
readonly PODMAN_NETWORK="${PODMAN_NETWORK:-floci-net}"

# --- Floci image ---
readonly FLOCI_IMAGE="${FLOCI_IMAGE:-floci/floci:1.5.33-compat}"

# --- Floci configuration ---
readonly FLOCI_HOSTNAME="${FLOCI_HOSTNAME:-tianlu-floci}"
readonly FLOCI_BASE_URL="${FLOCI_BASE_URL:-https://tianlu-floci:4566}"
readonly FLOCI_DEFAULT_REGION="${FLOCI_DEFAULT_REGION:-eu-west-1}"
readonly FLOCI_DEFAULT_ACCOUNT_ID="${FLOCI_DEFAULT_ACCOUNT_ID:-000000000000}"
readonly FLOCI_STORAGE_MODE="${FLOCI_STORAGE_MODE:-persistent}"
readonly FLOCI_STORAGE_PERSISTENT_PATH="${FLOCI_STORAGE_PERSISTENT_PATH:-/app/data}"
readonly FLOCI_HOST_PERSISTENT_PATH="${FLOCI_HOST_PERSISTENT_PATH:-${FLOCI_HOME}/floci-data}"
readonly FLOCI_TLS_ENABLED="${FLOCI_TLS_ENABLED:-true}"
readonly FLOCI_TLS_SELF_SIGNED="${FLOCI_TLS_SELF_SIGNED:-true}"

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
# IP via /etc/netplan/ to avoid this. See docs/design/solution-design.md §10.4.
FIREWALL_SCOPE="${FIREWALL_SCOPE:-auto}"
UFW_TRUSTED_SUBNETS=()
readonly UFW_RFC1918_SUBNETS=(
  "10.0.0.0/8"
  "172.16.0.0/12"
  "192.168.0.0/16"
)

# --- Paths ---
readonly FLOCI_ENV_DIR="${FLOCI_ENV_DIR:-${FLOCI_HOME}/.config/floci}"
readonly FLOCI_ENV_FILE="${FLOCI_ENV_FILE:-${FLOCI_ENV_DIR}/floci.env}"
readonly FLOCI_DATA_DIR="${FLOCI_DATA_DIR:-${FLOCI_HOME}/floci-data}"
readonly QUADLET_UNIT_DIR="${QUADLET_UNIT_DIR:-${FLOCI_HOME}/.config/containers/systemd}"
readonly FLOCI_QUADLET_FILE="${FLOCI_QUADLET_FILE:-${QUADLET_UNIT_DIR}/floci.container}"

# --- Interactive mode ---
# When --interactive is set and stdin is a TTY, the script pauses at each
# phase boundary. This allows inspection between phases (e.g. viewing
# curl output after the service starts, checking user creation, etc.).
# Without --interactive, or when stdin is not a TTY, all phases run
# continuously.
INTERACTIVE="${INTERACTIVE:-false}"

# ============================================================================
# PHASES
# ============================================================================
#
# Phase 1: Preflight       — assert_root, assert_ubuntu, detect_hostname_ip
# Phase 2: User setup      — create_floci_user, lock_password, configure_subuid_subgid
# Phase 3: Podman setup    — install_podman, enable_lingering, configure_xdg_runtime, start_podman_socket
# Phase 4: Network & image — create_podman_network, pull_floci_image
# Phase 5: Floci config    — create_data_dir, add_hosts_entry, generate_presign_secret, write_env_file, write_quadlet_unit
# Phase 6: Start & verify  — enable_systemd_service, configure_firewall, verify_health
# Phase 7: Summary         — print_summary

# ============================================================================
# FUNCTIONS
# ============================================================================

# run_as_floci: privilege-drop helper — run a command as $FLOCI_USER with the
# rootless environment properly set.
#
# Sets HOME, USER, PATH, XDG_RUNTIME_DIR, and DBUS_SESSION_BUS_ADDRESS so that
# rootless Podman and systemd --user find the correct per-user directories under
# /run/user/<UID>. Stdin is preserved so callers can pipe into tee or other
# commands that read stdin.
#
# Usage: run_as_floci <cmd> [args...]
run_as_floci() {
  local uid
  uid="$(id -u "$FLOCI_USER")"
  sudo -u "$FLOCI_USER" env \
    HOME="$FLOCI_HOME" \
    USER="$FLOCI_USER" \
    PATH="/usr/local/bin:/usr/bin:/bin" \
    XDG_RUNTIME_DIR="/run/user/${uid}" \
    DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${uid}/bus" \
    -- "$@"
}

# write_quadlet_unit: render the Quadlet .container file for the Floci service.
#
# Idempotent: if the target file already exists it is backed up to
# ${FLOCI_QUADLET_FILE}.bak before being overwritten (per §13 of the design).
# The file is written as $FLOCI_USER (run_as_floci tee) so ownership follows
# naturally without requiring root-only install(1) flags. Mode is set to 0644.
#
# The write is atomic: content is written to a .tmp sidecar, mode is set on
# the tmp file, then an atomic rename (mv -f) replaces the final target.
# A mid-write crash therefore never leaves a truncated .container file.
#
# The existence check for the backup guard runs via run_as_floci to avoid an
# identity/visibility mismatch — the file is owned by $FLOCI_USER and may not
# be readable by root.
#
# %h and %t are Quadlet specifiers expanded at runtime by systemd — they must
# appear literally in the file and must NOT be shell-expanded here.
write_quadlet_unit() {
  run_as_floci mkdir -p "$QUADLET_UNIT_DIR"

  if run_as_floci test -f "$FLOCI_QUADLET_FILE"; then
    run_as_floci cp "$FLOCI_QUADLET_FILE" "${FLOCI_QUADLET_FILE}.bak"
  fi

  run_as_floci tee "${FLOCI_QUADLET_FILE}.tmp" >/dev/null <<EOF
[Unit]
Description=Floci (AWS emulator) rootless container
After=podman.socket
Requires=podman.socket
StartLimitIntervalSec=60
StartLimitBurst=5

[Container]
Image=${FLOCI_IMAGE}
ContainerName=${FLOCI_HOSTNAME}
Network=${PODMAN_NETWORK}
EnvironmentFile=%h/.config/floci/floci.env
PublishPort=4566:4566
PublishPort=6379-6399:6379-6399
PublishPort=7001-7099:7001-7099
Volume=%t/podman/podman.sock:/var/run/docker.sock:z
Volume=%h/floci-data:/app/data:z

[Service]
NoNewPrivileges=true
ProtectSystem=strict
ReadWritePaths=%h %t
PrivateTmp=true
PrivateDevices=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6 AF_NETLINK
LockPersonality=true
RestrictRealtime=true
RestrictSUIDSGID=true
SystemCallArchitectures=native
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF

  run_as_floci chmod 0644 "${FLOCI_QUADLET_FILE}.tmp"
  run_as_floci mv -f "${FLOCI_QUADLET_FILE}.tmp" "$FLOCI_QUADLET_FILE"
}

# enable_systemd_service: activate the Quadlet-generated floci.service.
#
# Quadlet-generated units are TRANSIENT — systemctl enable returns "Unit is
# transient or generated" and fails. Boot autostart is already declared by
# [Install] WantedBy=default.target inside the .container file, which Quadlet
# materialises on daemon-reload. The script therefore only needs `start`.
#
# Sequence:
#   1. daemon-reload — Quadlet regenerates floci.service from the .container.
#   2. Idempotent start — if is-active returns 0 the service is already running
#      and we return immediately; otherwise `start` brings it up.
enable_systemd_service() {
  run_as_floci systemctl --user daemon-reload

  if run_as_floci systemctl --user is-active --quiet floci.service; then
    return 0
  fi

  run_as_floci systemctl --user start floci.service
}

# (Phase functions are implemented incrementally, one unit per commit.)

# ============================================================================
# MAIN
# ============================================================================

# main: entry point. Phase wiring is added in the final unit; for now this is
# a placeholder so the script is runnable and sourceable for tests.
main() {
  echo "setup-floci.sh — implementation in progress."
}

# Only run main when executed directly, not when sourced (e.g. by bats tests).
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
