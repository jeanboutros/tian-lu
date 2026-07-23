#!/usr/bin/env bats
#
# Unit tests for Phase 1 and Phase 2 functions:
#   assert_root_or_sudo, assert_ubuntu_version, assert_userns_allowed,
#   detect_hostname_and_ip, parse_args,
#   create_floci_user, lock_floci_password, configure_subuid_subgid.

load test_helper

# ---------------------------------------------------------------------------
# _run_fn: source the script with injectable overrides and run one function.
#
# Usage: _run_fn "VAR=val ..." "fn_call [args]"
#
# Each test runs the script in a fresh bash -c subshell so that `readonly`
# CONFIG vars do not collide between tests.
# ---------------------------------------------------------------------------
_run_fn() {
  local overrides="$1"
  local fn_call="$2"
  bash -c "
    export PATH='${PATH}'
    export STUB_LOG='${STUB_LOG}'
    ${overrides}
    source '${SCRIPT}'
    ${fn_call}
  "
}

setup() {
  setup_stub_env
}

teardown() {
  teardown_stub_env
}

# ===========================================================================
# assert_root_or_sudo
# ===========================================================================

@test "assert_root_or_sudo: passes when id -u returns 0" {
  run _run_fn "export STUB_OUT_ID=0" "assert_root_or_sudo"
  [ "$status" -eq 0 ]
}

@test "assert_root_or_sudo: exits 1 when id -u returns 1000" {
  run _run_fn "export STUB_OUT_ID=1000" "assert_root_or_sudo"
  [ "$status" -eq 1 ]
  [[ "$output" == *"must run as root"* ]]
}

# ===========================================================================
# assert_ubuntu_version
# ===========================================================================

@test "assert_ubuntu_version: accepts ubuntu 24.04" {
  local osfile="${TEST_TMP}/os-release-2404"
  printf 'ID=ubuntu\nVERSION_ID="24.04"\n' >"$osfile"
  run _run_fn "export OS_RELEASE_FILE='${osfile}'" "assert_ubuntu_version"
  [ "$status" -eq 0 ]
}

@test "assert_ubuntu_version: accepts ubuntu 26.04" {
  local osfile="${TEST_TMP}/os-release-2604"
  printf 'ID=ubuntu\nVERSION_ID="26.04"\n' >"$osfile"
  run _run_fn "export OS_RELEASE_FILE='${osfile}'" "assert_ubuntu_version"
  [ "$status" -eq 0 ]
}

@test "assert_ubuntu_version: rejects ubuntu 22.04" {
  local osfile="${TEST_TMP}/os-release-2204"
  printf 'ID=ubuntu\nVERSION_ID="22.04"\n' >"$osfile"
  run _run_fn "export OS_RELEASE_FILE='${osfile}'" "assert_ubuntu_version"
  [ "$status" -eq 1 ]
  [[ "$output" == *"too old"* ]]
}

@test "assert_ubuntu_version: rejects non-ubuntu ID" {
  local osfile="${TEST_TMP}/os-release-debian"
  printf 'ID=debian\nVERSION_ID="12"\n' >"$osfile"
  run _run_fn "export OS_RELEASE_FILE='${osfile}'" "assert_ubuntu_version"
  [ "$status" -eq 1 ]
  [[ "$output" == *"unsupported OS"* ]]
}

@test "assert_ubuntu_version: fails when os-release file is missing" {
  run _run_fn "export OS_RELEASE_FILE='${TEST_TMP}/no-such-file'" \
    "assert_ubuntu_version"
  [ "$status" -eq 1 ]
}

# ===========================================================================
# assert_userns_allowed
# ===========================================================================

@test "assert_userns_allowed: no-op when USERNS_SYSCTL_FILE does not exist" {
  run _run_fn \
    "export USERNS_SYSCTL_FILE='${TEST_TMP}/no-sysctl-file'" \
    "assert_userns_allowed"
  [ "$status" -eq 0 ]
  # apparmor_parser must NOT have been called.
  run grep "apparmor_parser" "$STUB_LOG"
  [ "$status" -ne 0 ]
}

@test "assert_userns_allowed: no-op when sysctl value is 0" {
  local sysctl_file="${TEST_TMP}/userns-sysctl"
  printf '0\n' >"$sysctl_file"
  run _run_fn \
    "export USERNS_SYSCTL_FILE='${sysctl_file}'" \
    "assert_userns_allowed"
  [ "$status" -eq 0 ]
  run grep "apparmor_parser" "$STUB_LOG"
  [ "$status" -ne 0 ]
}

@test "assert_userns_allowed: no-op when value=1 and profile already loaded" {
  local sysctl_file="${TEST_TMP}/userns-sysctl"
  local profiles_file="${TEST_TMP}/apparmor-profiles"
  printf '1\n' >"$sysctl_file"
  printf 'podman-userns (enforce)\n' >"$profiles_file"
  run _run_fn \
    "export USERNS_SYSCTL_FILE='${sysctl_file}';
     export APPARMOR_PROFILES_FILE='${profiles_file}'" \
    "assert_userns_allowed"
  [ "$status" -eq 0 ]
  run grep "apparmor_parser" "$STUB_LOG"
  [ "$status" -ne 0 ]
}

@test "assert_userns_allowed: installs profile and calls apparmor_parser when value=1 and not loaded" {
  local sysctl_file="${TEST_TMP}/userns-sysctl"
  local profile_dir="${TEST_TMP}/apparmor.d"
  local profile_file="${profile_dir}/podman-userns"
  # APPARMOR_PROFILES_FILE intentionally absent (no loaded profiles).
  local profiles_file="${TEST_TMP}/no-apparmor-profiles"

  printf '1\n' >"$sysctl_file"

  # PODMAN_BIN points to an existing tmp file (binary "exists on disk").
  local fake_podman="${TEST_TMP}/podman"
  touch "$fake_podman"

  # CRUN_BIN and PASTA_BIN point to non-existent paths — blocks should be omitted.
  local fake_crun="${TEST_TMP}/crun-nonexistent"
  local fake_pasta="${TEST_TMP}/pasta-nonexistent"

  run _run_fn \
    "export USERNS_SYSCTL_FILE='${sysctl_file}';
     export APPARMOR_PROFILES_FILE='${profiles_file}';
     export APPARMOR_PROFILE_DIR='${profile_dir}';
     export APPARMOR_USERNS_PROFILE='${profile_file}';
     export PODMAN_BIN='${fake_podman}';
     export CRUN_BIN='${fake_crun}';
     export PASTA_BIN='${fake_pasta}'" \
    "assert_userns_allowed"
  [ "$status" -eq 0 ]

  # apparmor_parser -r must have been called.
  grep -q "apparmor_parser -r" "$STUB_LOG"

  # Profile file must exist.
  [ -f "$profile_file" ]

  # Profile must contain the exact podman block header.
  grep -q 'profile podman-userns' "$profile_file"

  # Profile must contain userns grant.
  grep -q 'userns,' "$profile_file"

  # crun and pasta blocks must NOT be present (binaries don't exist).
  run grep "podman-userns-crun" "$profile_file"
  [ "$status" -ne 0 ]
  run grep "podman-userns-pasta" "$profile_file"
  [ "$status" -ne 0 ]

  # HARD PROHIBITION checks.
  # No sysctl call in stub log.
  run grep "sysctl" "$STUB_LOG"
  [ "$status" -ne 0 ]

  # No apparmor=unconfined in the profile file.
  run grep "apparmor=unconfined" "$profile_file"
  [ "$status" -ne 0 ]

  # USERNS_SYSCTL_FILE content must still be 1 (untouched).
  local sysctl_val
  sysctl_val="$(cat "$sysctl_file")"
  [[ "$sysctl_val" == "1" ]]
}

@test "assert_userns_allowed: profile file contains exact podman block" {
  local sysctl_file="${TEST_TMP}/userns-sysctl"
  local profile_dir="${TEST_TMP}/apparmor.d"
  local profile_file="${profile_dir}/podman-userns"
  local profiles_file="${TEST_TMP}/no-apparmor-profiles"
  local fake_podman="${TEST_TMP}/podman"

  printf '1\n' >"$sysctl_file"
  touch "$fake_podman"

  _run_fn \
    "export USERNS_SYSCTL_FILE='${sysctl_file}';
     export APPARMOR_PROFILES_FILE='${profiles_file}';
     export APPARMOR_PROFILE_DIR='${profile_dir}';
     export APPARMOR_USERNS_PROFILE='${profile_file}';
     export PODMAN_BIN='${fake_podman}';
     export CRUN_BIN='${TEST_TMP}/crun-nonexistent';
     export PASTA_BIN='${TEST_TMP}/pasta-nonexistent'" \
    "assert_userns_allowed"

  # Exact required lines.
  grep -q 'abi <abi/4.0>,' "$profile_file"
  grep -q 'include <tunables/global>' "$profile_file"
  grep -q 'flags=(unconfined)' "$profile_file"
  grep -q 'include if exists <local/podman-userns>' "$profile_file"
}

# ===========================================================================
# parse_args
# ===========================================================================

@test "parse_args: --interactive sets INTERACTIVE=true" {
  run _run_fn "" \
    "parse_args --interactive; printf '%s\n' \"\$INTERACTIVE\""
  [ "$status" -eq 0 ]
  [[ "$output" == *"true"* ]]
}

@test "parse_args: --firewall-scope=rfc1918 sets FIREWALL_SCOPE" {
  run _run_fn "" \
    "parse_args --firewall-scope=rfc1918; printf '%s\n' \"\$FIREWALL_SCOPE\""
  [ "$status" -eq 0 ]
  [[ "$output" == *"rfc1918"* ]]
}

@test "parse_args: --firewall-scope=bogus exits 2" {
  run _run_fn "" "parse_args --firewall-scope=bogus"
  [ "$status" -eq 2 ]
}

@test "parse_args: unknown flag --nope exits 2" {
  run _run_fn "" "parse_args --nope"
  [ "$status" -eq 2 ]
}

# ===========================================================================
# create_floci_user
# ===========================================================================

@test "create_floci_user: skips when getent returns 0 (user exists)" {
  # getent rc=0 means user found — no useradd should be called.
  run _run_fn \
    "export STUB_RC_GETENT=0" \
    "create_floci_user"
  [ "$status" -eq 0 ]
  run grep "useradd" "$STUB_LOG"
  [ "$status" -ne 0 ]
}

@test "create_floci_user: calls useradd with correct flags when user absent" {
  # getent rc=2 means user not found.
  run _run_fn \
    "export STUB_RC_GETENT=2;
     export FLOCI_HOME='${TEST_TMP}/home/floci';
     export FLOCI_SHELL='/bin/bash';
     export FLOCI_USER='floci'" \
    "create_floci_user"
  [ "$status" -eq 0 ]
  grep -q "useradd" "$STUB_LOG"
  grep -q -- "--create-home" "$STUB_LOG"
  grep -q -- "--home-dir" "$STUB_LOG"
}

# ===========================================================================
# lock_floci_password
# ===========================================================================

@test "lock_floci_password: skips when passwd -S shows L (already locked)" {
  run _run_fn \
    "export STUB_OUT_PASSWD='floci L 01/01/2025 0 99999 7 -1'" \
    "lock_floci_password"
  [ "$status" -eq 0 ]
  # passwd -l must NOT have been called.
  run grep "passwd -l" "$STUB_LOG"
  [ "$status" -ne 0 ]
}

@test "lock_floci_password: calls passwd -l when not locked" {
  run _run_fn \
    "export STUB_OUT_PASSWD='floci P 01/01/2025 0 99999 7 -1'" \
    "lock_floci_password"
  [ "$status" -eq 0 ]
  grep -q "passwd -l" "$STUB_LOG"
}

# ===========================================================================
# configure_subuid_subgid
# ===========================================================================

@test "configure_subuid_subgid: writes floci:100000:262144 to empty tmp files" {
  local subuid="${TEST_TMP}/subuid"
  local subgid="${TEST_TMP}/subgid"
  # Files do not exist yet.
  run _run_fn \
    "export SUBUID_FILE='${subuid}';
     export SUBGID_FILE='${subgid}';
     export FLOCI_USER='floci';
     export SUBUID_START=100000;
     export SUBUID_COUNT=262144" \
    "configure_subuid_subgid"
  [ "$status" -eq 0 ]
  grep -q "^floci:100000:262144$" "$subuid"
  grep -q "^floci:100000:262144$" "$subgid"
}

@test "configure_subuid_subgid: is a no-op when floci line already present" {
  local subuid="${TEST_TMP}/subuid"
  local subgid="${TEST_TMP}/subgid"
  printf 'floci:100000:262144\n' >"$subuid"
  printf 'floci:100000:262144\n' >"$subgid"

  run _run_fn \
    "export SUBUID_FILE='${subuid}';
     export SUBGID_FILE='${subgid}';
     export FLOCI_USER='floci';
     export SUBUID_START=100000;
     export SUBUID_COUNT=262144" \
    "configure_subuid_subgid"
  [ "$status" -eq 0 ]
  # File should still contain exactly one line.
  local lines
  lines="$(wc -l <"$subuid")"
  [ "$lines" -eq 1 ]
}

@test "configure_subuid_subgid: picks non-overlapping range when 100000 is taken" {
  local subuid="${TEST_TMP}/subuid"
  local subgid="${TEST_TMP}/subgid"
  # Another user already occupies [100000, 100000+262144).
  printf 'otheruser:100000:262144\n' >"$subuid"
  printf 'otheruser:100000:262144\n' >"$subgid"

  run _run_fn \
    "export SUBUID_FILE='${subuid}';
     export SUBGID_FILE='${subgid}';
     export FLOCI_USER='floci';
     export SUBUID_START=100000;
     export SUBUID_COUNT=262144" \
    "configure_subuid_subgid"
  [ "$status" -eq 0 ]

  # floci's range should start at 100000+262144=362144, not 100000.
  grep -q "^floci:362144:262144$" "$subuid"
  grep -q "^floci:362144:262144$" "$subgid"
}

@test "configure_subuid_subgid: two out-of-order ranges force outer re-scan, picks 362144" {
  local subuid="${TEST_TMP}/subuid"
  local subgid="${TEST_TMP}/subgid"
  # Ranges (unsorted): [624288,886432) and [100000,362144).
  # Correct first non-overlapping slot starting from 100000 is 362144.
  printf 'other2:624288:262144\nother1:100000:262144\n' >"$subuid"
  printf 'other2:624288:262144\nother1:100000:262144\n' >"$subgid"

  run _run_fn \
    "export SUBUID_FILE='${subuid}';
     export SUBGID_FILE='${subgid}';
     export FLOCI_USER='floci';
     export SUBUID_START=100000;
     export SUBUID_COUNT=262144" \
    "configure_subuid_subgid"
  [ "$status" -eq 0 ]
  grep -q "^floci:362144:262144$" "$subuid"
  grep -q "^floci:362144:262144$" "$subgid"
}

# ===========================================================================
# detect_hostname_and_ip
# ===========================================================================

@test "detect_hostname_and_ip: primary path extracts src IP from ip-route output" {
  run _run_fn \
    "export STUB_OUT_IP='1.1.1.1 via 192.168.1.1 dev eth0 src 192.168.1.50 uid 0'" \
    "detect_hostname_and_ip; printf 'SERVER_IP=%s\n' \"\$SERVER_IP\"; printf 'SERVER_LAN_SUBNET=%s\n' \"\$SERVER_LAN_SUBNET\""
  [ "$status" -eq 0 ]
  [[ "$output" == *"SERVER_IP=192.168.1.50"* ]]
  [[ "$output" == *"SERVER_LAN_SUBNET=192.168.1.0/24"* ]]
}

@test "detect_hostname_and_ip: fallback uses hostname -I when ip returns empty" {
  run _run_fn \
    "export STUB_OUT_IP='';
     export STUB_OUT_HOSTNAME='10.0.0.7 10.0.0.8'" \
    "detect_hostname_and_ip; printf 'SERVER_IP=%s\n' \"\$SERVER_IP\"; printf 'SERVER_LAN_SUBNET=%s\n' \"\$SERVER_LAN_SUBNET\""
  [ "$status" -eq 0 ]
  [[ "$output" == *"SERVER_IP=10.0.0.7"* ]]
  [[ "$output" == *"SERVER_LAN_SUBNET=10.0.0.0/24"* ]]
}

@test "detect_hostname_and_ip: exits non-zero when both ip and hostname return empty" {
  run _run_fn \
    "export STUB_OUT_IP='';
     export STUB_OUT_HOSTNAME=''" \
    "detect_hostname_and_ip"
  [ "$status" -ne 0 ]
  [[ "$output" == *"could not detect server IP"* ]]
}

# ===========================================================================
# lock_floci_password (additional cases)
# ===========================================================================

@test "lock_floci_password: calls passwd -l when status field is NP (not locked)" {
  run _run_fn \
    "export STUB_OUT_PASSWD='floci NP 01/01/2020 0 99999 7 -1'" \
    "lock_floci_password"
  [ "$status" -eq 0 ]
  grep -q "passwd -l" "$STUB_LOG"
}

@test "lock_floci_password: calls passwd -l when passwd -S fails (empty status)" {
  # passwd -S fails (rc=1 via || true → empty output); status_field is not "L"
  # so passwd -l is called. passwd -l also exits 1 here making the function
  # exit non-zero, so we only assert the stub log shows the call was made.
  run _run_fn \
    "export STUB_RC_PASSWD=1" \
    "lock_floci_password"
  grep -q "passwd -l" "$STUB_LOG"
}

# ===========================================================================
# assert_ubuntu_version (tightened ID match)
# ===========================================================================

@test "assert_ubuntu_version: rejects ID=notubuntu (tightened exact match)" {
  local osfile="${TEST_TMP}/os-release-notubuntu"
  printf 'ID=notubuntu\nVERSION_ID="24.04"\n' >"$osfile"
  run _run_fn "export OS_RELEASE_FILE='${osfile}'" "assert_ubuntu_version"
  [ "$status" -eq 1 ]
  [[ "$output" == *"unsupported OS"* ]]
}
