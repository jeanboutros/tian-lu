#!/usr/bin/env bats
#
# Unit 1 tests: write_quadlet_unit and enable_systemd_service.

load test_helper

setup() {
  setup_stub_env
  # Export variables that setup-floci.sh CONFIG block reads as overrides.
  export FLOCI_HOME
  export FLOCI_HOST_PERSISTENT_PATH="${FLOCI_HOME}/floci-data"
  export FLOCI_DATA_DIR="${FLOCI_HOME}/floci-data"
  export QUADLET_UNIT_DIR="${FLOCI_HOME}/.config/containers/systemd"
  export FLOCI_QUADLET_FILE="${QUADLET_UNIT_DIR}/floci.container"

  # Make the id stub return a numeric UID so run_as_floci constructs valid
  # XDG_RUNTIME_DIR/DBUS_SESSION_BUS_ADDRESS paths.
  export STUB_OUT_ID="1001"

  # Per-test override bin dir — prepend to PATH so we can provide transparent
  # wrappers for mkdir/tee/chmod/cp without touching the shared STUB_BIN
  # (writing to a symlink that points to ../_stub would overwrite _stub).
  TEST_BIN="${TEST_TMP}/bin"
  mkdir -p "$TEST_BIN"

  # Resolve real binary paths BEFORE TEST_BIN is on PATH so we always find the
  # genuine system binaries and not any wrapper we are about to install.
  # Use explicit /bin or /usr/bin prefixes where needed to avoid resolving to
  # shell builtins (e.g. `command -v test` returns "test" on macOS, not a path).
  REAL_MKDIR="$(command -v mkdir)"
  REAL_TEE="$(command -v tee)"
  REAL_CHMOD="$(command -v chmod)"
  REAL_CP="$(command -v cp)"
  REAL_MV="$(command -v mv)"
  export REAL_MKDIR REAL_TEE REAL_CHMOD REAL_CP REAL_MV

  export PATH="${TEST_BIN}:${PATH}"
}

teardown() {
  teardown_stub_env
}

# ---------------------------------------------------------------------------
# _setup_real_fs_cmds: install transparent wrappers in TEST_BIN for the
# filesystem commands called by write_quadlet_unit (via sudo → run_as_floci).
# These wrappers log to STUB_LOG and then exec the real system binary so the
# file is actually created on disk (required for content/mode assertions).
#
# The wrappers reference ${REAL_*} variables that were captured before TEST_BIN
# was added to PATH — this ensures the wrappers always call the real binaries
# regardless of PATH ordering.
# ---------------------------------------------------------------------------
_setup_real_fs_cmds() {
  # mkdir wrapper
  cat >"${TEST_BIN}/mkdir" <<'EOF'
#!/usr/bin/env bash
set -u
[[ -n "${STUB_LOG:-}" ]] && printf 'mkdir %s\n' "$*" >>"$STUB_LOG"
exec "${REAL_MKDIR}" "$@"
EOF
  chmod +x "${TEST_BIN}/mkdir"

  # tee wrapper — must actually write stdin to the target file.
  cat >"${TEST_BIN}/tee" <<'EOF'
#!/usr/bin/env bash
set -u
[[ -n "${STUB_LOG:-}" ]] && printf 'tee %s\n' "$*" >>"$STUB_LOG"
exec "${REAL_TEE}" "$@"
EOF
  chmod +x "${TEST_BIN}/tee"

  # chmod wrapper
  cat >"${TEST_BIN}/chmod" <<'EOF'
#!/usr/bin/env bash
set -u
[[ -n "${STUB_LOG:-}" ]] && printf 'chmod %s\n' "$*" >>"$STUB_LOG"
exec "${REAL_CHMOD}" "$@"
EOF
  chmod +x "${TEST_BIN}/chmod"

  # cp wrapper — log only (backup check; cp is only called on second run).
  cat >"${TEST_BIN}/cp" <<'EOF'
#!/usr/bin/env bash
set -u
[[ -n "${STUB_LOG:-}" ]] && printf 'cp %s\n' "$*" >>"$STUB_LOG"
exec "${REAL_CP}" "$@"
EOF
  chmod +x "${TEST_BIN}/cp"

  # mv wrapper — used for the atomic rename step.
  cat >"${TEST_BIN}/mv" <<'EOF'
#!/usr/bin/env bash
set -u
[[ -n "${STUB_LOG:-}" ]] && printf 'mv %s\n' "$*" >>"$STUB_LOG"
exec "${REAL_MV}" "$@"
EOF
  chmod +x "${TEST_BIN}/mv"

  # Note: no wrapper for `test` — `command -v test` returns the shell builtin
  # name on macOS, not an absolute path.  When the sudo stub does `exec test`,
  # it finds the real /bin/test binary in PATH without an intermediate wrapper.
}

# ---------------------------------------------------------------------------
# _source_and_run: source the script with all overrides in scope.
# ---------------------------------------------------------------------------
_source_and_run() {
  bash -c "export FLOCI_HOME='${FLOCI_HOME}'; \
           export FLOCI_HOST_PERSISTENT_PATH='${FLOCI_HOST_PERSISTENT_PATH}'; \
           export FLOCI_DATA_DIR='${FLOCI_DATA_DIR}'; \
           export QUADLET_UNIT_DIR='${QUADLET_UNIT_DIR}'; \
           export FLOCI_QUADLET_FILE='${FLOCI_QUADLET_FILE}'; \
           export STUB_LOG='${STUB_LOG}'; \
           export STUB_OUT_ID='${STUB_OUT_ID}'; \
           export REAL_MKDIR='${REAL_MKDIR}'; \
           export REAL_TEE='${REAL_TEE}'; \
           export REAL_CHMOD='${REAL_CHMOD}'; \
           export REAL_CP='${REAL_CP}'; \
           export REAL_MV='${REAL_MV}'; \
           export PATH='${PATH}'; \
           source '${SCRIPT}'; \
           $1"
}

# ===========================================================================
# Test group 1: write_quadlet_unit — file creation and content
# ===========================================================================

@test "write_quadlet_unit creates FLOCI_QUADLET_FILE" {
  _setup_real_fs_cmds
  run _source_and_run "write_quadlet_unit"
  [ "$status" -eq 0 ]
  [ -f "$FLOCI_QUADLET_FILE" ]
}

@test "write_quadlet_unit sets file mode to 0644" {
  _setup_real_fs_cmds
  _source_and_run "write_quadlet_unit"
  local mode
  mode="$(stat -c '%a' "$FLOCI_QUADLET_FILE" 2>/dev/null || stat -f '%A' "$FLOCI_QUADLET_FILE")"
  [ "$mode" = "644" ]
}

@test "write_quadlet_unit file contains ContainerName=tianlu-floci" {
  _setup_real_fs_cmds
  _source_and_run "write_quadlet_unit"
  grep -q "ContainerName=tianlu-floci" "$FLOCI_QUADLET_FILE"
}

@test "write_quadlet_unit file contains Network=floci-net" {
  _setup_real_fs_cmds
  _source_and_run "write_quadlet_unit"
  grep -q "Network=floci-net" "$FLOCI_QUADLET_FILE"
}

@test "write_quadlet_unit file contains Image=docker.io/floci/floci:1.5.33-compat" {
  _setup_real_fs_cmds
  _source_and_run "write_quadlet_unit"
  grep -q "Image=docker.io/floci/floci:1.5.33-compat" "$FLOCI_QUADLET_FILE"
}

@test "write_quadlet_unit file contains all three PublishPort lines" {
  _setup_real_fs_cmds
  _source_and_run "write_quadlet_unit"
  grep -q "PublishPort=4566:4566" "$FLOCI_QUADLET_FILE"
  grep -q "PublishPort=6379-6399:6379-6399" "$FLOCI_QUADLET_FILE"
  grep -q "PublishPort=7001-7099:7001-7099" "$FLOCI_QUADLET_FILE"
}

@test "write_quadlet_unit file contains Podman socket Volume ending in :z" {
  _setup_real_fs_cmds
  _source_and_run "write_quadlet_unit"
  grep -q "Volume=%t/podman/podman.sock:/var/run/docker.sock:z" "$FLOCI_QUADLET_FILE"
}

@test "write_quadlet_unit file contains data Volume ending in :z" {
  _setup_real_fs_cmds
  _source_and_run "write_quadlet_unit"
  grep -q "Volume=${FLOCI_HOME}/floci-data:/app/data:z" "$FLOCI_QUADLET_FILE"
}

@test "write_quadlet_unit: uses configurable host persistence path" {
  export FLOCI_HOST_PERSISTENT_PATH=/tmp/custom-data
  _setup_real_fs_cmds
  _source_and_run "write_quadlet_unit"
  grep -q "Volume=/tmp/custom-data:/app/data:z" "$FLOCI_QUADLET_FILE"
}

@test "write_quadlet_unit: host path override wins over FLOCI_DATA_DIR" {
  export FLOCI_HOST_PERSISTENT_PATH=/tmp/canonical
  export FLOCI_DATA_DIR=/tmp/other
  _setup_real_fs_cmds
  _source_and_run "write_quadlet_unit"
  grep -q "Volume=/tmp/canonical:/app/data:z" "$FLOCI_QUADLET_FILE"
}

@test "write_quadlet_unit file contains UserNS keep-id mapping for the Floci image user" {
  _setup_real_fs_cmds
  _source_and_run "write_quadlet_unit"
  grep -q "UserNS=keep-id:uid=1001,gid=1001" "$FLOCI_QUADLET_FILE"
}

@test "write_quadlet_unit file contains EnvironmentFile with %h specifier" {
  _setup_real_fs_cmds
  _source_and_run "write_quadlet_unit"
  grep -q "EnvironmentFile=%h/.config/floci/floci.env" "$FLOCI_QUADLET_FILE"
}

@test "write_quadlet_unit file does NOT contain filesystem-sandbox directives (rootless userns)" {
  _setup_real_fs_cmds
  _source_and_run "write_quadlet_unit"
  # ProtectSystem, ReadWritePaths, PrivateTmp, ProtectKernelTunables,
  # PrivateDevices, ProtectKernelModules, ProtectControlGroups are all
  # excluded — they trigger systemd-executor's implicit userns or capability
  # drops that AppArmor denies in a rootless user unit. RestrictSUIDSGID is
  # excluded — it strips SUID/SGID bits, which breaks Podman's idmapped layer
  # copy under UserNS=keep-id (must preserve SUID on setuid root binaries).
  run grep -E "ProtectSystem=|ReadWritePaths=|PrivateTmp=|ProtectKernelTunables=|PrivateDevices=|ProtectKernelModules=|ProtectControlGroups=|RestrictSUIDSGID=" "$FLOCI_QUADLET_FILE"
  [ "$status" -ne 0 ]
  # The seccomp-based subset that does NOT require namespace creation is kept.
  grep -q "NoNewPrivileges=true" "$FLOCI_QUADLET_FILE"
  grep -q "RestrictAddressFamilies=" "$FLOCI_QUADLET_FILE"
  grep -q "LockPersonality=true" "$FLOCI_QUADLET_FILE"
  grep -q "RestrictRealtime=true" "$FLOCI_QUADLET_FILE"
  grep -q "SystemCallArchitectures=native" "$FLOCI_QUADLET_FILE"
}

@test "write_quadlet_unit emits GAP-014 systemd retry budget" {
  _setup_real_fs_cmds
  _source_and_run "write_quadlet_unit"
  grep -q "StartLimitBurst=8" "$FLOCI_QUADLET_FILE"
  grep -q "StartLimitIntervalSec=180" "$FLOCI_QUADLET_FILE"
  grep -q "^RestartSec=5$" "$FLOCI_QUADLET_FILE"
  grep -q "^RestartSteps=5$" "$FLOCI_QUADLET_FILE"
  grep -q "^RestartMaxDelaySec=30$" "$FLOCI_QUADLET_FILE"
}

@test "write_quadlet_unit honors env var overrides for retry budget" {
  _setup_real_fs_cmds
  export START_LIMIT_BURST=3
  export RESTART_SEC=2
  export RESTART_STEPS=6
  export RESTART_MAX_DELAY_SEC=45
  export START_LIMIT_INTERVAL_SEC=400
  _source_and_run "write_quadlet_unit"
  grep -q "StartLimitBurst=3" "$FLOCI_QUADLET_FILE"
  grep -q "StartLimitIntervalSec=400" "$FLOCI_QUADLET_FILE"
  grep -q "^RestartSec=2$" "$FLOCI_QUADLET_FILE"
  grep -q "^RestartSteps=6$" "$FLOCI_QUADLET_FILE"
  grep -q "^RestartMaxDelaySec=45$" "$FLOCI_QUADLET_FILE"
  unset START_LIMIT_BURST RESTART_SEC RESTART_STEPS RESTART_MAX_DELAY_SEC START_LIMIT_INTERVAL_SEC
}

@test "write_quadlet_unit file does not contain ProtectHome" {
  _setup_real_fs_cmds
  _source_and_run "write_quadlet_unit"
  run grep -c "ProtectHome" "$FLOCI_QUADLET_FILE"
  [ "$output" = "0" ]
}

@test "write_quadlet_unit file does not contain PrivateNetwork" {
  _setup_real_fs_cmds
  _source_and_run "write_quadlet_unit"
  run grep -c "PrivateNetwork" "$FLOCI_QUADLET_FILE"
  [ "$output" = "0" ]
}

@test "write_quadlet_unit file does not contain MemoryDenyWriteExecute" {
  _setup_real_fs_cmds
  _source_and_run "write_quadlet_unit"
  run grep -c "MemoryDenyWriteExecute" "$FLOCI_QUADLET_FILE"
  [ "$output" = "0" ]
}

@test "write_quadlet_unit file does not contain RestrictNamespaces" {
  _setup_real_fs_cmds
  _source_and_run "write_quadlet_unit"
  run grep -c "RestrictNamespaces" "$FLOCI_QUADLET_FILE"
  [ "$output" = "0" ]
}

# ===========================================================================
# Test group 2: write_quadlet_unit idempotency — backup on second run
# ===========================================================================

@test "write_quadlet_unit backs up existing file to .bak on second run" {
  _setup_real_fs_cmds

  # First run — creates the file.
  _source_and_run "write_quadlet_unit"
  [ -f "$FLOCI_QUADLET_FILE" ]

  # Second run — must back up the existing file before overwriting.
  _source_and_run "write_quadlet_unit"
  [ -f "${FLOCI_QUADLET_FILE}.bak" ]
}

# ===========================================================================
# Test group 3: enable_systemd_service
#
# The dedicated systemctl stub (tests/stubs/bin/systemctl) allows independent
# per-subcommand exit codes via STUB_RC_SYSTEMCTL_<SUBCOMMAND> variables.
# This lets is-active return non-zero (service not running) while daemon-reload
# and start return 0.
# ===========================================================================

@test "enable_systemd_service calls daemon-reload first" {
  # All systemctl subcommands return 0 (daemon-reload succeeds, is-active
  # returns 0 meaning already running — early return path).
  export STUB_RC_SYSTEMCTL_DAEMON_RELOAD=0
  export STUB_RC_SYSTEMCTL_IS_ACTIVE=0

  run _source_and_run "enable_systemd_service"
  [ "$status" -eq 0 ]
  grep -q "systemctl --user daemon-reload" "$STUB_LOG"
}

@test "enable_systemd_service calls start when service is not active" {
  # daemon-reload succeeds; is-active returns 1 (not running) → start is called.
  export STUB_RC_SYSTEMCTL_DAEMON_RELOAD=0
  export STUB_RC_SYSTEMCTL_IS_ACTIVE=1
  export STUB_RC_SYSTEMCTL_START=0

  run _source_and_run "enable_systemd_service"
  [ "$status" -eq 0 ]

  # daemon-reload must be called.
  grep -q "systemctl --user daemon-reload" "$STUB_LOG"

  # start must be called (this is a real assertion — grep fails the test if absent).
  grep -q "systemctl --user start floci.service" "$STUB_LOG"

  # enable must NOT appear anywhere in the log.
  run grep "enable" "$STUB_LOG"
  [ "$status" -ne 0 ]
}

@test "enable_systemd_service skips start when service is already active" {
  # daemon-reload succeeds; is-active returns 0 (already running) → no start.
  export STUB_RC_SYSTEMCTL_DAEMON_RELOAD=0
  export STUB_RC_SYSTEMCTL_IS_ACTIVE=0

  run _source_and_run "enable_systemd_service"
  [ "$status" -eq 0 ]

  # daemon-reload must be called.
  grep -q "systemctl --user daemon-reload" "$STUB_LOG"

  # start must NOT be called.
  run grep "start floci.service" "$STUB_LOG"
  [ "$status" -ne 0 ]

  # enable must NOT appear anywhere in the log.
  run grep "enable" "$STUB_LOG"
  [ "$status" -ne 0 ]
}
