#!/usr/bin/env bats
#
# Unit tests for Phase 3 and Phase 4 functions:
#   install_podman, enable_lingering, configure_xdg_runtime_dir,
#   start_podman_socket, create_podman_network, pull_floci_image.

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
# install_podman
# ===========================================================================

@test "install_podman: skips apt-get when podman is already on PATH" {
  # STUB_BIN is on PATH and contains the podman symlink -> command -v podman succeeds.
  run _run_fn "" "install_podman"
  [ "$status" -eq 0 ]
  run grep "apt-get" "$STUB_LOG"
  [ "$status" -ne 0 ]
}

@test "install_podman: calls apt-get update and install when podman not on PATH" {
  # Build a scratch bin that has ONLY the commands install_podman needs, but
  # deliberately excludes 'podman' so that command -v podman fails inside the
  # subshell regardless of whether podman is installed on the host.
  # Using scratch_bin ALONE (no system dirs appended) guarantees
  # host-independence: a host-installed podman on any system PATH dir cannot
  # leak in.
  local scratch_bin="${TEST_TMP}/scratch_bin"
  mkdir -p "$scratch_bin"

  # Write a self-contained apt-get stub that logs invocations to $STUB_LOG.
  # It uses only bash builtins (printf, export) so it works with scratch_bin
  # as the sole PATH entry and needs no transitive dependencies (no basename,
  # tr, etc.).  Shebang uses absolute /bin/bash — not /usr/bin/env bash —
  # so the kernel resolves the interpreter without searching PATH.
  printf '%s\n' '#!/bin/bash' \
    '[ -n "${STUB_LOG:-}" ] && printf "apt-get %s\n" "$*" >>"$STUB_LOG"' \
    'exit 0' \
    > "${scratch_bin}/apt-get"
  chmod +x "${scratch_bin}/apt-get"

  # install_podman uses: command -v (builtin), apt-get.
  # No other external binary is needed — scratch_bin alone is sufficient.

  # PATH: scratch_bin ONLY — no system dirs, no STUB_BIN.
  # This ensures: no podman anywhere on PATH -> command -v podman fails.
  local isolated_path="${scratch_bin}"

  # Note: we pass STUB_LOG explicitly; the scratch apt-get stub logs there.
  bash -c "
    export PATH='${isolated_path}'
    export STUB_LOG='${STUB_LOG}'
    source '${SCRIPT}'
    install_podman
  "
  status=$?
  [ "$status" -eq 0 ]
  grep -q "apt-get update" "$STUB_LOG"
  grep -q "apt-get install" "$STUB_LOG"
  grep -q "podman" "$STUB_LOG"
  grep -q "uidmap" "$STUB_LOG"
}

# ===========================================================================
# enable_lingering
# ===========================================================================

@test "enable_lingering: idempotent when Linger=yes (skips enable-linger)" {
  # loginctl show-user returns Linger=yes -> must NOT call enable-linger.
  # systemctl is-active=0 -> poll succeeds immediately.
  run _run_fn \
    "export STUB_OUT_LOGINCTL='Linger=yes';
     export STUB_RC_SYSTEMCTL_IS_ACTIVE=0;
     export STUB_OUT_ID='1001';
     export USER_MANAGER_POLL_TRIES=1;
     export USER_MANAGER_POLL_SLEEP=0" \
    "enable_lingering"
  [ "$status" -eq 0 ]
  run grep "enable-linger" "$STUB_LOG"
  [ "$status" -ne 0 ]
  # Assert the two-stage readiness poll (§9.1) actually ran: both systemctl
  # is-active checks must appear in the log, proving the poll was not skipped.
  grep -q 'is-active --quiet user@1001.service' "$STUB_LOG"
  grep -q 'is-active --quiet default.target' "$STUB_LOG"
}

@test "enable_lingering: calls loginctl enable-linger when Linger=no" {
  run _run_fn \
    "export STUB_OUT_LOGINCTL='Linger=no';
     export STUB_RC_SYSTEMCTL_IS_ACTIVE=0;
     export STUB_OUT_ID='1001';
     export USER_MANAGER_POLL_TRIES=1;
     export USER_MANAGER_POLL_SLEEP=0" \
    "enable_lingering"
  [ "$status" -eq 0 ]
  grep -q "loginctl enable-linger floci" "$STUB_LOG"
}

@test "enable_lingering: poll completes fast when is-active returns 0 immediately" {
  # With sleep stub (no-op) and is-active=0 the poll succeeds on first iteration.
  run _run_fn \
    "export STUB_OUT_LOGINCTL='Linger=yes';
     export STUB_RC_SYSTEMCTL_IS_ACTIVE=0;
     export STUB_OUT_ID='1001';
     export USER_MANAGER_POLL_TRIES=30;
     export USER_MANAGER_POLL_SLEEP=0" \
    "enable_lingering"
  [ "$status" -eq 0 ]
}

@test "enable_lingering: exits non-zero when user manager never becomes ready" {
  # is-active always returns non-zero -> poll exhausts and script exits 1.
  run _run_fn \
    "export STUB_OUT_LOGINCTL='Linger=yes';
     export STUB_RC_SYSTEMCTL_IS_ACTIVE=3;
     export STUB_OUT_ID='1001';
     export USER_MANAGER_POLL_TRIES=2;
     export USER_MANAGER_POLL_SLEEP=0" \
    "enable_lingering"
  [ "$status" -ne 0 ]
  [[ "$output" == *"not ready"* ]]
}

# ===========================================================================
# configure_xdg_runtime_dir
# ===========================================================================

@test "configure_xdg_runtime_dir: succeeds when runtime dir exists" {
  local xdg_base="${TEST_TMP}/run/user"
  mkdir -p "${xdg_base}/1001"
  run _run_fn \
    "export STUB_OUT_ID='1001';
     export XDG_RUNTIME_BASE='${xdg_base}'" \
    "configure_xdg_runtime_dir"
  [ "$status" -eq 0 ]
}

@test "configure_xdg_runtime_dir: exits non-zero when runtime dir absent" {
  local xdg_base="${TEST_TMP}/run/user"
  # Do NOT create the directory.
  run _run_fn \
    "export STUB_OUT_ID='1001';
     export XDG_RUNTIME_BASE='${xdg_base}'" \
    "configure_xdg_runtime_dir"
  [ "$status" -ne 0 ]
  [[ "$output" == *"does not exist"* ]]
}

# ===========================================================================
# start_podman_socket
# ===========================================================================

@test "start_podman_socket: skips enable when socket is already active" {
  # systemctl is-active returns 0 -> already running, no enable call.
  run _run_fn \
    "export STUB_RC_SYSTEMCTL_IS_ACTIVE=0;
     export STUB_OUT_ID='1001'" \
    "start_podman_socket"
  [ "$status" -eq 0 ]
  run grep "enable" "$STUB_LOG"
  [ "$status" -ne 0 ]
}

@test "start_podman_socket: calls enable --now podman.socket when not active" {
  # systemctl is-active returns 3 (inactive) -> enable --now must be called.
  run _run_fn \
    "export STUB_RC_SYSTEMCTL_IS_ACTIVE=3;
     export STUB_OUT_ID='1001'" \
    "start_podman_socket"
  [ "$status" -eq 0 ]
  grep -q "enable --now podman.socket" "$STUB_LOG"
}

# ===========================================================================
# create_podman_network
# ===========================================================================

@test "create_podman_network: skips when network already exists" {
  # podman network inspect rc=0 -> network exists, no create call.
  run _run_fn \
    "export STUB_RC_PODMAN_NETWORK_INSPECT=0;
     export STUB_OUT_ID='1001'" \
    "create_podman_network"
  [ "$status" -eq 0 ]
  run grep "network create" "$STUB_LOG"
  [ "$status" -ne 0 ]
}

@test "create_podman_network: creates network when inspect fails" {
  # podman network inspect rc=1 -> network absent, create must be called.
  run _run_fn \
    "export STUB_RC_PODMAN_NETWORK_INSPECT=1;
     export STUB_OUT_ID='1001'" \
    "create_podman_network"
  [ "$status" -eq 0 ]
  grep -q "network create floci-net" "$STUB_LOG"
}

# ===========================================================================
# pull_floci_image
# ===========================================================================

@test "pull_floci_image: skips when image already present" {
  # podman image inspect rc=0 -> image present, no pull call.
  run _run_fn \
    "export STUB_RC_PODMAN_IMAGE_INSPECT=0;
     export STUB_OUT_ID='1001'" \
    "pull_floci_image"
  [ "$status" -eq 0 ]
  run grep "podman pull" "$STUB_LOG"
  [ "$status" -ne 0 ]
}

@test "pull_floci_image: pulls image when not present" {
  # podman image inspect rc=1 -> image absent, pull must be called.
  run _run_fn \
    "export STUB_RC_PODMAN_IMAGE_INSPECT=1;
     export STUB_OUT_ID='1001'" \
    "pull_floci_image"
  [ "$status" -eq 0 ]
  grep -q "pull docker.io/floci/floci:1.5.33-compat" "$STUB_LOG"
}
