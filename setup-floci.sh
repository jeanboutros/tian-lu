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

# --- /etc/hosts ---
readonly HOSTS_FILE="${HOSTS_FILE:-/etc/hosts}"

# --- Docker log rotation (Floci env file) ---
readonly FLOCI_LOG_MAX_SIZE="${FLOCI_LOG_MAX_SIZE:-10m}"
readonly FLOCI_LOG_MAX_FILE="${FLOCI_LOG_MAX_FILE:-3}"

# --- OS / preflight ---
readonly OS_RELEASE_FILE="${OS_RELEASE_FILE:-/etc/os-release}"
readonly MIN_UBUNTU_VERSION="${MIN_UBUNTU_VERSION:-24.04}"

# --- Systemd user manager poll ---
readonly USER_MANAGER_POLL_TRIES="${USER_MANAGER_POLL_TRIES:-30}"
readonly USER_MANAGER_POLL_SLEEP="${USER_MANAGER_POLL_SLEEP:-1}"

# --- XDG runtime dir base ---
readonly XDG_RUNTIME_BASE="${XDG_RUNTIME_BASE:-/run/user}"

# --- AppArmor / userns ---
readonly USERNS_SYSCTL_FILE="${USERNS_SYSCTL_FILE:-/proc/sys/kernel/apparmor_restrict_unprivileged_userns}"
readonly APPARMOR_PROFILES_FILE="${APPARMOR_PROFILES_FILE:-/sys/kernel/security/apparmor/profiles}"
readonly APPARMOR_PROFILE_DIR="${APPARMOR_PROFILE_DIR:-/etc/apparmor.d}"
readonly APPARMOR_USERNS_PROFILE="${APPARMOR_USERNS_PROFILE:-${APPARMOR_PROFILE_DIR}/podman-userns}"

# --- Container runtime binaries ---
readonly PODMAN_BIN="${PODMAN_BIN:-/usr/bin/podman}"
readonly CRUN_BIN="${CRUN_BIN:-/usr/bin/crun}"
readonly PASTA_BIN="${PASTA_BIN:-/usr/bin/pasta}"

# --- Sub{uid,gid} files ---
readonly SUBUID_FILE="${SUBUID_FILE:-/etc/subuid}"
readonly SUBGID_FILE="${SUBGID_FILE:-/etc/subgid}"

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

# ----------------------------------------------------------------------------
# Phase 1 functions
# ----------------------------------------------------------------------------

# assert_root_or_sudo: effective UID must be 0.
assert_root_or_sudo() {
  if [[ "$(id -u)" -ne 0 ]]; then
    printf 'ERROR: must run as root (use sudo)\n' >&2
    exit 1
  fi
}

# assert_ubuntu_version: require Ubuntu >= MIN_UBUNTU_VERSION.
assert_ubuntu_version() {
  if [[ ! -f "$OS_RELEASE_FILE" ]]; then
    printf 'ERROR: %s not found — cannot verify OS\n' "$OS_RELEASE_FILE" >&2
    exit 1
  fi

  local os_id=""
  local os_version=""

  while IFS='=' read -r key val; do
    # Strip surrounding quotes from value.
    val="${val%\"}"
    val="${val#\"}"
    case "$key" in
      ID)         os_id="$val" ;;
      VERSION_ID) os_version="$val" ;;
    esac
  done <"$OS_RELEASE_FILE"

  # Accept only the exact ID "ubuntu" (all Ubuntu flavours report ID=ubuntu).
  case "$os_id" in
    ubuntu) : ;;
    *)
      printf 'ERROR: unsupported OS "%s" — Ubuntu %s+ required\n' \
        "$os_id" "$MIN_UBUNTU_VERSION" >&2
      exit 1
      ;;
  esac

  if [[ -z "$os_version" ]]; then
    printf 'ERROR: could not parse VERSION_ID from %s\n' "$OS_RELEASE_FILE" >&2
    exit 1
  fi

  # Compare versions using sort -V: the minimum of the two must equal MIN.
  local lowest
  lowest="$(printf '%s\n%s\n' "$MIN_UBUNTU_VERSION" "$os_version" \
    | sort -V | head -n1)"
  if [[ "$lowest" != "$MIN_UBUNTU_VERSION" ]]; then
    printf 'ERROR: Ubuntu %s is too old — %s+ required\n' \
      "$os_version" "$MIN_UBUNTU_VERSION" >&2
    exit 1
  fi
}

# assert_userns_allowed: ensure AppArmor permits rootless user namespaces.
#
# If the kernel sysctl that restricts unprivileged userns is absent or not set
# to 1, nothing needs to be done.  If it is 1, install (or verify already
# installed) a permitting AppArmor profile for the Podman binary chain.
#
# HARD PROHIBITIONS: this function MUST NOT write to USERNS_SYSCTL_FILE,
# run sysctl to disable the restriction, or emit apparmor=unconfined.
assert_userns_allowed() {
  # Restriction not in force — nothing to do.
  if [[ ! -f "$USERNS_SYSCTL_FILE" ]]; then
    return 0
  fi

  local sysctl_val
  sysctl_val="$(tr -d '[:space:]' <"$USERNS_SYSCTL_FILE")"
  if [[ "$sysctl_val" != "1" ]]; then
    return 0
  fi

  # Value is 1: check if the permitting profile is already loaded.
  if [[ -f "$APPARMOR_PROFILES_FILE" ]] \
    && grep -q 'podman-userns' "$APPARMOR_PROFILES_FILE"; then
    return 0
  fi

  # Install the AppArmor profile.
  mkdir -p "$APPARMOR_PROFILE_DIR"

  local tmp_profile
  tmp_profile="${APPARMOR_USERNS_PROFILE}.tmp.$$"

  # Write the mandatory podman block (specifiers literal, not shell-expanded
  # except for the path token in the profile line).
  {
    printf 'abi <abi/4.0>,\n'
    printf 'include <tunables/global>\n'
    printf '\n'
    printf 'profile podman-userns %s flags=(unconfined) {\n' "$PODMAN_BIN"
    printf '  userns,\n'
    printf '  include if exists <local/podman-userns>\n'
    printf '}\n'
  } >"$tmp_profile"

  # Optional crun block (only if the binary exists on disk).
  if [[ -f "$CRUN_BIN" ]]; then
    {
      printf '\nprofile podman-userns-crun %s flags=(unconfined) {\n' "$CRUN_BIN"
      printf '  userns,\n'
      printf '}\n'
    } >>"$tmp_profile"
  fi

  # Optional pasta block.
  if [[ -f "$PASTA_BIN" ]]; then
    {
      printf '\nprofile podman-userns-pasta %s flags=(unconfined) {\n' "$PASTA_BIN"
      printf '  userns,\n'
      printf '}\n'
    } >>"$tmp_profile"
  fi

  chmod 0644 "$tmp_profile"
  mv -f "$tmp_profile" "$APPARMOR_USERNS_PROFILE"

  apparmor_parser -r "$APPARMOR_USERNS_PROFILE"
}

# detect_hostname_and_ip: set globals SERVER_IP and SERVER_LAN_SUBNET.
detect_hostname_and_ip() {
  # Primary: extract the token after "src" from the ip-route output using awk
  # (awk does its own whitespace splitting, immune to global IFS=$'\n\t').
  SERVER_IP="$(ip route get 1.1.1.1 2>/dev/null \
    | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1); exit}}')"

  # Fallback: first field from hostname -I (also via awk for IFS-safety).
  if [[ -z "$SERVER_IP" ]]; then
    SERVER_IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
  fi

  if [[ -z "$SERVER_IP" ]]; then
    printf 'ERROR: could not detect server IP address\n' >&2
    exit 1
  fi

  # Compute /24 subnet: replace 4th octet with 0.
  # IFS='.' read is a per-command prefix — safe regardless of global IFS.
  local octet1 octet2 octet3
  IFS='.' read -r octet1 octet2 octet3 _ <<< "$SERVER_IP"
  SERVER_LAN_SUBNET="${octet1}.${octet2}.${octet3}.0/24"

  export SERVER_IP SERVER_LAN_SUBNET
}

# parse_args: parse command-line arguments.
parse_args() {
  local arg
  for arg in "$@"; do
    case "$arg" in
      --interactive)
        INTERACTIVE=true
        ;;
      --firewall-scope=auto)
        FIREWALL_SCOPE=auto
        ;;
      --firewall-scope=rfc1918)
        FIREWALL_SCOPE=rfc1918
        ;;
      --firewall-scope=*)
        printf 'ERROR: unknown firewall scope "%s" (use auto or rfc1918)\n' \
          "${arg#--firewall-scope=}" >&2
        exit 2
        ;;
      *)
        printf 'ERROR: unknown argument "%s"\n' "$arg" >&2
        exit 2
        ;;
    esac
  done
}

# ----------------------------------------------------------------------------
# Phase 2 functions
# ----------------------------------------------------------------------------

# create_floci_user: idempotent user creation.
create_floci_user() {
  if getent passwd "$FLOCI_USER" >/dev/null 2>&1; then
    return 0
  fi
  useradd --create-home --home-dir "$FLOCI_HOME" --shell "$FLOCI_SHELL" "$FLOCI_USER"
  chmod "$FLOCI_HOME_PERMS" "$FLOCI_HOME"
}

# lock_floci_password: idempotent password lock.
lock_floci_password() {
  local status_output
  status_output="$(passwd -S "$FLOCI_USER" 2>/dev/null || true)"
  # Second field of passwd -S output is the lock status: L = locked.
  local status_field
  status_field="$(printf '%s\n' "$status_output" | awk '{print $2}')"
  if [[ "$status_field" == "L" ]]; then
    return 0
  fi
  passwd -l "$FLOCI_USER"
}

# configure_subuid_subgid: allocate non-overlapping subuid/subgid ranges.
configure_subuid_subgid() {
  local map_file
  for map_file in "$SUBUID_FILE" "$SUBGID_FILE"; do
    # Idempotency: skip if the user's line already exists.
    if [[ -f "$map_file" ]] && grep -q "^${FLOCI_USER}:" "$map_file"; then
      continue
    fi

    # Find a non-overlapping candidate start >= SUBUID_START.
    local candidate
    candidate="$SUBUID_START"
    local changed=1
    local range_end
    local candidate_end

    # Iterate until no overlap is found.
    while [[ "$changed" -eq 1 ]]; do
      changed=0
      if [[ -f "$map_file" ]]; then
        while IFS=: read -r _user range_start range_count; do
          # Skip malformed lines.
          [[ -z "$range_start" || -z "$range_count" ]] && continue
          range_end=$(( range_start + range_count ))
          candidate_end=$(( candidate + SUBUID_COUNT ))
          # Check overlap: [candidate, candidate_end) overlaps [range_start, range_end)
          if [[ "$candidate" -lt "$range_end" && "$candidate_end" -gt "$range_start" ]]; then
            candidate="$range_end"
            changed=1
          fi
        done <"$map_file"
      fi
    done

    printf '%s:%d:%d\n' "$FLOCI_USER" "$candidate" "$SUBUID_COUNT" >>"$map_file"
  done
}

# ----------------------------------------------------------------------------
# Phase 3 functions
# ----------------------------------------------------------------------------

# install_podman: idempotent — skip if podman is already on PATH.
install_podman() {
  if command -v podman >/dev/null 2>&1; then
    return 0
  fi
  apt-get update
  apt-get install -y podman uidmap
}

# enable_lingering: enable systemd lingering for $FLOCI_USER and wait for the
# user manager to reach default.target (two-stage poll per §9.1).
enable_lingering() {
  local uid
  uid="$(id -u "$FLOCI_USER")"

  # Idempotency: skip enable if linger is already on.
  local linger_out
  linger_out="$(loginctl show-user "$FLOCI_USER" --property=Linger 2>/dev/null || true)"
  if printf '%s\n' "$linger_out" | grep -q 'Linger=yes'; then
    : # already enabled — fall through to the readiness poll
  else
    loginctl enable-linger "$FLOCI_USER"
  fi

  # Two-stage readiness poll (§9.1).
  local ready=0 i
  for (( i=1; i<=USER_MANAGER_POLL_TRIES; i++ )); do
    if systemctl is-active --quiet "user@${uid}.service" \
       && run_as_floci systemctl --user is-active --quiet default.target; then
      ready=1; break
    fi
    sleep "$USER_MANAGER_POLL_SLEEP"
  done
  if [[ "$ready" -ne 1 ]]; then
    printf 'ERROR: user manager for %s not ready\n' "$FLOCI_USER" >&2
    exit 1
  fi
}

# configure_xdg_runtime_dir: verify the XDG runtime directory exists for
# $FLOCI_USER.  After lingering + poll it must already exist; its absence is
# a precondition failure (podman.socket cannot start without it).
configure_xdg_runtime_dir() {
  local uid
  uid="$(id -u "$FLOCI_USER")"
  local xdg="${XDG_RUNTIME_BASE}/${uid}"
  if [[ ! -d "$xdg" ]]; then
    printf 'ERROR: XDG_RUNTIME_DIR %s does not exist\n' "$xdg" >&2
    exit 1
  fi
}

# start_podman_socket: idempotent — enable --now only if the socket is not
# already active.  podman.socket is a distro-shipped unit (not a Quadlet
# transient), so `enable --now` is correct here.
start_podman_socket() {
  if run_as_floci systemctl --user is-active --quiet podman.socket; then
    return 0
  fi
  run_as_floci systemctl --user enable --now podman.socket
}

# ----------------------------------------------------------------------------
# Phase 4 functions
# ----------------------------------------------------------------------------

# create_podman_network: idempotent — skip if the named network already exists.
#
# Why bare `podman network create "$PODMAN_NETWORK"` (no --subnet / DNS flags)
# satisfies design §5.2: on netavark-backed Podman (Ubuntu 24.04+), any
# user-defined (named) network automatically gets aardvark-dns for per-
# container DNS resolution and assigns reachable IPs by default — unlike the
# rootless default bridge, which does not.  Hardcoding a --subnet risks range
# collisions with other networks; netavark's defaults are collision-resistant.
create_podman_network() {
  if run_as_floci podman network inspect "$PODMAN_NETWORK" >/dev/null 2>&1; then
    return 0
  fi
  run_as_floci podman network create "$PODMAN_NETWORK"
}

# pull_floci_image: idempotent — skip if the image is already present locally.
pull_floci_image() {
  if run_as_floci podman image inspect "$FLOCI_IMAGE" >/dev/null 2>&1; then
    return 0
  fi
  run_as_floci podman pull "$FLOCI_IMAGE"
}

# ----------------------------------------------------------------------------
# Phase 5 functions
# ----------------------------------------------------------------------------

# create_data_directory: ensure the persistent data dir exists, owned by
# floci, mode 0700. Idempotent: mkdir -p is a no-op if the dir already
# exists, and re-applying chmod 0700 is harmless.
create_data_directory() {
  run_as_floci mkdir -p "$FLOCI_DATA_DIR"
  run_as_floci chmod 0700 "$FLOCI_DATA_DIR"
}

# add_hosts_entry: ensure $HOSTS_FILE contains "127.0.0.1 $FLOCI_HOSTNAME"
# inside a managed marker block, so host-side tooling can resolve the
# hostname without dnsmasq (§5.5).
#
# The file is root-owned and edited as root directly (NOT via run_as_floci).
#
# Idempotency: any existing managed block for this hostname (correct or
# stale) is stripped via an awk BEGIN..END range delete, and a fresh block is
# always appended. This makes "block already correct" and "stale block"
# converge on the same code path — re-running never duplicates the block,
# and all other /etc/hosts content is preserved exactly. The write is atomic:
# content is built in a temp file, mode is set, then `mv -f` replaces the
# target — /etc/hosts is never truncated in place.
add_hosts_entry() {
  local marker_begin="# BEGIN ${FLOCI_HOSTNAME} (managed by setup-floci.sh)"
  local marker_end="# END ${FLOCI_HOSTNAME} (managed by setup-floci.sh)"
  local desired_line="127.0.0.1 ${FLOCI_HOSTNAME}"

  local preserved=""
  if [[ -f "$HOSTS_FILE" ]]; then
    preserved="$(awk -v b="$marker_begin" -v e="$marker_end" '
      { line=$0; sub(/\r$/,"",line) }
      line==b {inblock=1; next}
      line==e {inblock=0; next}
      inblock {next}
      {print}
    ' "$HOSTS_FILE")"
  fi

  local tmp_hosts
  tmp_hosts="${HOSTS_FILE}.tmp.$$"

  {
    if [[ -n "$preserved" ]]; then
      printf '%s\n' "$preserved"
      printf '\n'
    fi
    printf '%s\n' "$marker_begin"
    printf '%s\n' "$desired_line"
    printf '%s\n' "$marker_end"
  } >"$tmp_hosts"

  if [[ -f "$HOSTS_FILE" ]] && cmp -s "$tmp_hosts" "$HOSTS_FILE"; then
    rm -f "$tmp_hosts"
    return 0
  fi

  chmod 0644 "$tmp_hosts"
  mv -f "$tmp_hosts" "$HOSTS_FILE"
}

# generate_presign_secret: set global PRESIGN_SECRET.
#
# Reuse-if-exists: if $FLOCI_ENV_FILE already has a non-empty
# FLOCI_AUTH_PRESIGN_SECRET=... line, reuse that value — regenerating would
# invalidate existing pre-signed URLs (§8). Otherwise generate a fresh
# 32-byte hex secret via openssl.
#
# The env file is owned by $FLOCI_USER, so it is read via run_as_floci.
# PRESIGN_SECRET is intentionally NOT readonly — it is set at runtime.
generate_presign_secret() {
  PRESIGN_SECRET=""

  if run_as_floci test -f "$FLOCI_ENV_FILE"; then
    local existing
    existing="$(run_as_floci grep -m1 '^FLOCI_AUTH_PRESIGN_SECRET=' "$FLOCI_ENV_FILE" 2>/dev/null || true)"
    existing="${existing#FLOCI_AUTH_PRESIGN_SECRET=}"
    if [[ -n "$existing" ]]; then
      PRESIGN_SECRET="$existing"
      return 0
    fi
  fi

  PRESIGN_SECRET="$(openssl rand -hex 32)"
}

# write_env_file: render $FLOCI_ENV_FILE (mode 0600, owned floci) atomically,
# mirroring the write_quadlet_unit pattern exactly: mkdir -p the parent dir,
# back up an existing file to .bak before overwriting, tee into a .tmp
# sidecar, chmod the tmp file, then mv -f for an atomic rename.
#
# Requires $PRESIGN_SECRET to already be set (generate_presign_secret runs
# first per §15). FLOCI_DOCKER_DOCKER_HOST is intentionally never emitted —
# the socket is mounted at /var/run/docker.sock inside the container and
# Floci's default handles it (§12).
write_env_file() {
  run_as_floci mkdir -p "$FLOCI_ENV_DIR"

  if run_as_floci test -f "$FLOCI_ENV_FILE"; then
    run_as_floci cp "$FLOCI_ENV_FILE" "${FLOCI_ENV_FILE}.bak"
  fi

  run_as_floci tee "${FLOCI_ENV_FILE}.tmp" >/dev/null <<EOF
FLOCI_HOSTNAME=${FLOCI_HOSTNAME}
FLOCI_BASE_URL=${FLOCI_BASE_URL}
FLOCI_DEFAULT_REGION=${FLOCI_DEFAULT_REGION}
FLOCI_DEFAULT_ACCOUNT_ID=${FLOCI_DEFAULT_ACCOUNT_ID}
FLOCI_STORAGE_MODE=${FLOCI_STORAGE_MODE}
FLOCI_STORAGE_PERSISTENT_PATH=${FLOCI_STORAGE_PERSISTENT_PATH}
FLOCI_STORAGE_HOST_PERSISTENT_PATH=${FLOCI_HOST_PERSISTENT_PATH}
FLOCI_TLS_ENABLED=${FLOCI_TLS_ENABLED}
FLOCI_TLS_SELF_SIGNED=${FLOCI_TLS_SELF_SIGNED}
FLOCI_SERVICES_DOCKER_NETWORK=${PODMAN_NETWORK}
FLOCI_SERVICES_LAMBDA_DOCKER_NETWORK=${PODMAN_NETWORK}
FLOCI_SERVICES_LAMBDA_DOCKER_HOST_OVERRIDE=${FLOCI_HOSTNAME}
FLOCI_AUTH_PRESIGN_SECRET=${PRESIGN_SECRET}
FLOCI_DOCKER_LOG_MAX_SIZE=${FLOCI_LOG_MAX_SIZE}
FLOCI_DOCKER_LOG_MAX_FILE=${FLOCI_LOG_MAX_FILE}
EOF

  run_as_floci chmod 0600 "${FLOCI_ENV_FILE}.tmp"
  run_as_floci mv -f "${FLOCI_ENV_FILE}.tmp" "$FLOCI_ENV_FILE"
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
