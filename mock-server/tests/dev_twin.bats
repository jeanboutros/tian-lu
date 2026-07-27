#!/usr/bin/env bats

load test_helper

setup() {
  setup_stub_env
  export DEV_HOSTS_FILE="${TEST_TMP}/hosts"
  printf '127.0.0.1 localhost\n192.168.1.5 someother\n' > "$DEV_HOSTS_FILE"
}

teardown() {
  teardown_stub_env
}

# ---------------------------------------------------------------------------
# expand_required_ports
# ---------------------------------------------------------------------------
@test "expand_required_ports includes 4566" {
  run bash -c "source '$DEV_SCRIPT'; expand_required_ports | grep -xq 4566"
  [ "$status" -eq 0 ]
}

@test "expand_required_ports excludes 9200" {
  run bash -c "source '$DEV_SCRIPT'; expand_required_ports | grep -xq 9200"
  [ "$status" -ne 0 ]
}

@test "expand_required_ports includes 9169" {
  run bash -c "source '$DEV_SCRIPT'; expand_required_ports | grep -xq 9169"
  [ "$status" -eq 0 ]
}

@test "expand_required_ports includes ElastiCache 6379" {
  run bash -c "source '$DEV_SCRIPT'; expand_required_ports | grep -xq 6379"
  [ "$status" -eq 0 ]
}

@test "expand_required_ports includes ElastiCache 6399" {
  run bash -c "source '$DEV_SCRIPT'; expand_required_ports | grep -xq 6399"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# preflight_ports
# ---------------------------------------------------------------------------
@test "preflight_ports passes when lsof exits 1 (no listeners)" {
  run bash -c "export STUB_LOG='${STUB_LOG}'; export STUB_RC_LSOF=1; source '$DEV_SCRIPT'; preflight_ports"
  [ "$status" -eq 0 ]
}

@test "preflight_ports fails when lsof exits 2 (error)" {
  run bash -c "export STUB_LOG='${STUB_LOG}'; export STUB_RC_LSOF=2; source '$DEV_SCRIPT'; preflight_ports 2>&1"
  [ "$status" -ne 0 ]
  [[ "$output" == *"lsof"*"command failed"* ]]
}

@test "preflight_ports detects conflict on required port 4566" {
  run bash -c "export STUB_LOG='${STUB_LOG}'; export STUB_OUT_LSOF='p12345
n127.0.0.1:4566'; source '$DEV_SCRIPT'; preflight_ports 2>&1"
  [ "$status" -ne 0 ]
  [[ "$output" == *"4566"* ]]
}

@test "preflight_ports passes when no required ports are in listener list" {
  run bash -c "export STUB_LOG='${STUB_LOG}'; export STUB_OUT_LSOF='p12345
n127.0.0.1:9999'; source '$DEV_SCRIPT'; preflight_ports"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# dev_instance_state
# ---------------------------------------------------------------------------
@test "dev_instance_state returns absent when name not in list" {
  run bash -c "export STUB_LOG='${STUB_LOG}'; export STUB_OUT_LIMACTL='other-vm Running'; source '$DEV_SCRIPT'; dev_instance_state"
  [ "$status" -eq 0 ]
  [ "$output" = "absent" ]
}

@test "dev_instance_state returns Running when name matches" {
  run bash -c "export STUB_LOG='${STUB_LOG}'; export STUB_OUT_LIMACTL='floci-dev Running'; source '$DEV_SCRIPT'; dev_instance_state"
  [ "$status" -eq 0 ]
  [ "$output" = "Running" ]
}

@test "dev_instance_state exits 1 on limactl failure" {
  run bash -c "export STUB_LOG='${STUB_LOG}'; export STUB_RC_LIMACTL=1; source '$DEV_SCRIPT'; dev_instance_state 2>&1"
  [ "$status" -ne 0 ]
  [[ "$output" == *"ERROR"* ]]
}

# ---------------------------------------------------------------------------
# dev_disk_exists
# ---------------------------------------------------------------------------
@test "dev_disk_exists returns 0 when disk name found in json" {
  run bash -c "export STUB_LOG='${STUB_LOG}'; export STUB_OUT_LIMACTL='\"name\":\"floci-dev-data\",\"instance\":\"\"'; source '$DEV_SCRIPT'; dev_disk_exists"
  [ "$status" -eq 0 ]
}

@test "dev_disk_exists returns 1 when disk not found" {
  run bash -c "export STUB_LOG='${STUB_LOG}'; export STUB_OUT_LIMACTL='\"name\":\"other-disk\",\"instance\":\"\"'; source '$DEV_SCRIPT'; dev_disk_exists"
  [ "$status" -eq 1 ]
}

@test "dev_disk_exists exits with ERROR on limactl failure" {
  run bash -c "export STUB_LOG='${STUB_LOG}'; export STUB_RC_LIMACTL=2; source '$DEV_SCRIPT'; dev_disk_exists 2>&1"
  [ "$status" -ne 0 ]
  [[ "$output" == *"ERROR"* ]]
}

# ---------------------------------------------------------------------------
# managed_hosts_add / managed_hosts_remove
# ---------------------------------------------------------------------------
@test "managed_hosts_add adds marker block" {
  run bash -c "
    export STUB_LOG='${STUB_LOG}'
    source '$DEV_SCRIPT'
    managed_hosts_add
    grep -q 'BEGIN tianlu-floci' '$DEV_HOSTS_FILE'
  "
  [ "$status" -eq 0 ]
}

@test "managed_hosts_add preserves unrelated entries" {
  run bash -c "
    export STUB_LOG='${STUB_LOG}'
    source '$DEV_SCRIPT'
    managed_hosts_add
    grep -q '192.168.1.5 someother' '$DEV_HOSTS_FILE'
  "
  [ "$status" -eq 0 ]
}

@test "managed_hosts_add is idempotent (skips sudo if byte-identical)" {
  run bash -c "
    export STUB_LOG='${STUB_LOG}'
    source '$DEV_SCRIPT'
    managed_hosts_add
    managed_hosts_add
    grep -c 'BEGIN tianlu-floci' '$DEV_HOSTS_FILE'
  "
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]
}

@test "managed_hosts_remove removes marker block" {
  run bash -c "
    export STUB_LOG='${STUB_LOG}'
    source '$DEV_SCRIPT'
    managed_hosts_add
    managed_hosts_remove
    if grep -q 'BEGIN tianlu-floci' '$DEV_HOSTS_FILE'; then
      exit 1
    fi
  "
  [ "$status" -eq 0 ]
}

@test "managed_hosts_add fails closed on lone BEGIN marker" {
  printf '# BEGIN tianlu-floci (managed by dev-twin.sh)\n127.0.0.1 localhost\n' > "$DEV_HOSTS_FILE"
  run bash -c "
    export STUB_LOG='${STUB_LOG}'
    source '$DEV_SCRIPT'
    managed_hosts_add 2>&1
  "
  [ "$status" -ne 0 ]
  [[ "$output" == *"malformed"* ]]
}

# ---------------------------------------------------------------------------
# confirm_reset
# ---------------------------------------------------------------------------
@test "confirm_reset passes with CONFIRM=reset" {
  run bash -c "export STUB_LOG='${STUB_LOG}'; CONFIRM=reset source '$DEV_SCRIPT'; CONFIRM=reset confirm_reset"
  [ "$status" -eq 0 ]
}

@test "confirm_reset fails when non-TTY and no CONFIRM" {
  run bash -c "export STUB_LOG='${STUB_LOG}'; source '$DEV_SCRIPT'; DEV_CONFIRM_STDIN_TTY=0 confirm_reset 2>&1"
  [ "$status" -ne 0 ]
  [[ "$output" == *"CONFIRM=reset"* ]]
}

@test "confirm_reset passes with CONFIRM_STDIN_TTY=1 and reset input" {
  echo "reset" > "${TEST_TMP}/confirm_input.txt"
  run bash -c "
    export STUB_LOG='${STUB_LOG}'
    source '$DEV_SCRIPT'
    DEV_CONFIRM_STDIN_TTY=1 DEV_CONFIRM_STDIN_FILE='${TEST_TMP}/confirm_input.txt' DEV_CONFIRM_READ_TIMEOUT=1 confirm_reset
  "
  [ "$status" -eq 0 ]
}

@test "confirm_reset fails with wrong input" {
  echo "RESET" > "${TEST_TMP}/confirm_input.txt"
  run bash -c "
    export STUB_LOG='${STUB_LOG}'
    source '$DEV_SCRIPT'
    DEV_CONFIRM_STDIN_TTY=1 DEV_CONFIRM_STDIN_FILE='${TEST_TMP}/confirm_input.txt' DEV_CONFIRM_READ_TIMEOUT=1 confirm_reset 2>&1
  "
  [ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# assert_identity
# ---------------------------------------------------------------------------
@test "assert_identity rejects DEV_TWIN_NAME=floci-twin" {
  run env STUB_LOG="${STUB_LOG}" DEV_TWIN_NAME=floci-twin bash -c "source '$DEV_SCRIPT'; assert_identity 2>&1"
  [ "$status" -ne 0 ]
  [[ "$output" == *"ERROR"*"identity"* ]]
}

@test "assert_identity passes with default DEV_TWIN_NAME=floci-dev" {
  run bash -c "export STUB_LOG='${STUB_LOG}'; source '$DEV_SCRIPT'; assert_identity"
  [ "$status" -eq 0 ]
}

@test "DEV_TWIN_NAME and TWIN_NAME are different defaults" {
  run bash -c "
    source '$DEV_SCRIPT'
    [[ '$DEV_TWIN_NAME' != 'floci-twin' ]]
  "
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# dev_up state machine
# ---------------------------------------------------------------------------
@test "dev_up Running path: no limactl start, no installer, has curl" {
  run bash -c "
    export STUB_LOG='${STUB_LOG}'
    export STUB_OUT_LIMACTL='floci-dev Running'
    export STUB_OUT_CURL='200'
    source '$DEV_SCRIPT'
    assert_preconditions() { :; }
    dev_up 2>&1
  "
  [ "$status" -eq 0 ]
  ! grep -q 'limactl start' "$STUB_LOG"
  ! grep -q 'setup-floci.sh' "$STUB_LOG"
  grep -q 'curl' "$STUB_LOG"
}

@test "dev_up Stopped path: has limactl start, no installer" {
  run bash -c "
    export STUB_LOG='${STUB_LOG}'
    export STUB_OUT_LIMACTL='floci-dev Running'
    export STUB_OUT_CURL='200'
    export DEV_START_BUDGET_RESUME=1
    export DEV_HEALTH_TRIES=1
    source '$DEV_SCRIPT'
    assert_preconditions() { :; }
    dev_instance_state() { printf 'Stopped\\n'; }
    verify_disk_mount() { return 0; }
    _start_service() { :; }
    dev_up 2>&1
  "
  [ "$status" -eq 0 ]
  grep -q 'limactl start --tty=false floci-dev' "$STUB_LOG"
  ! grep -q 'setup-floci.sh' "$STUB_LOG"
}

@test "dev_up Absent path: disk create before limactl start" {
  run bash -c "
    export STUB_LOG='${STUB_LOG}'
    export STUB_OUT_LIMACTL='floci-dev Running'
    export STUB_OUT_CURL='200'
    export DEV_START_BUDGET_FIRST=1
    export DEV_HEALTH_TRIES=1
    source '$DEV_SCRIPT'
    assert_preconditions() { :; }
    dev_instance_state() { printf 'absent\\n'; }
    dev_disk_exists() { return 1; }
    limactl() {
      printf 'limactl %s\\n' "\$*" >> "\$STUB_LOG"
      [[ "\$*" == list* ]] && printf 'floci-dev Running\\n'
      [[ "\$*" == *stat* ]] && printf '1777\\n'
      return 0
    }
    verify_disk_mount() { return 0; }
    _install_exec_condition() { :; }
    dev_up 2>&1
  "
  [ "$status" -eq 0 ]
  local create_line start_line
  create_line=$(grep -n 'limactl disk create' "$STUB_LOG" | head -1 | cut -d: -f1)
  start_line=$(grep -n 'limactl start' "$STUB_LOG" | head -1 | cut -d: -f1)
  (( create_line < start_line ))
  grep -q 'setup-floci.sh' "$STUB_LOG"
}

# ---------------------------------------------------------------------------
# dev_down
# ---------------------------------------------------------------------------
@test "dev_down on already Stopped prints stopped message" {
  run bash -c "
    export STUB_LOG='${STUB_LOG}'
    source '$DEV_SCRIPT'
    dev_instance_state() { printf 'Stopped\\n'; }
    dev_down 2>&1
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"already stopped"* ]] || [[ "$output" == *"Already"* ]] || [[ "$output" == *"stopped"* ]]
}

@test "dev_down on absent instance exits 0" {
  run bash -c "
    export STUB_LOG='${STUB_LOG}'
    source '$DEV_SCRIPT'
    dev_down 2>&1
  "
  [ "$status" -eq 0 ]
}

@test "dev_down on Installing state exits 1" {
  run bash -c "
    export STUB_LOG='${STUB_LOG}'
    source '$DEV_SCRIPT'
    dev_instance_state() { printf 'Installing\\n'; }
    dev_down 2>&1
  "
  [ "$status" -ne 0 ]
  [[ "$output" == *"ERROR"* ]] || [[ "$output" == *"state"* ]]
}

# ---------------------------------------------------------------------------
# dev_status
# ---------------------------------------------------------------------------
@test "dev_status always exits 0" {
  run bash -c "
    export STUB_LOG='${STUB_LOG}'
    export STUB_RC_LIMACTL=2
    source '$DEV_SCRIPT'
    dev_status 2>&1
  "
  [ "$status" -eq 0 ]
}

@test "dev_status does not call limactl start" {
  run bash -c "
    export STUB_LOG='${STUB_LOG}'
    source '$DEV_SCRIPT'
    dev_status 2>&1
  "
  [ "$status" -eq 0 ]
  ! grep -q 'limactl start' "$STUB_LOG"
}

# ---------------------------------------------------------------------------
# dev_reset
# ---------------------------------------------------------------------------
@test "dev_reset without confirmation exits 1" {
  run bash -c "
    export STUB_LOG='${STUB_LOG}'
    export DEV_CONFIRM_STDIN_TTY=0
    source '$DEV_SCRIPT'
    dev_reset 2>&1
  "
  [ "$status" -ne 0 ]
  ! grep -q 'limactl delete' "$STUB_LOG"
  ! grep -q 'disk delete' "$STUB_LOG"
}

@test "dev_reset with CONFIRM=reset calls limactl delete" {
  run bash -c "
    export STUB_LOG='${STUB_LOG}'
    export CONFIRM=reset
    export STUB_OUT_LIMACTL='floci-dev Running'
    source '$DEV_SCRIPT'
    dev_reset 2>&1 || true
  "
  grep -q 'limactl' "$STUB_LOG"
}

# ---------------------------------------------------------------------------
# dev_shell
# ---------------------------------------------------------------------------
@test "dev_shell on absent exits 1" {
  run bash -c "
    export STUB_LOG='${STUB_LOG}'
    export STUB_OUT_LIMACTL=''
    source '$DEV_SCRIPT'
    assert_preconditions() { :; }
    dev_shell 2>&1
  "
  [ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# dev_env
# ---------------------------------------------------------------------------
@test "dev_env --export prints export lines" {
  run bash -c "
    export HOME='${TEST_TMP}'
    source '$DEV_SCRIPT'
    dev_env --export
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"AWS_PROFILE=floci-dev"* ]]
  [[ "$output" == *"AWS_ENDPOINT_URL"* ]]
}

@test "dev_env creates aws config profile idempotently" {
  run bash -c "
    export HOME='${TEST_TMP}'
    source '$DEV_SCRIPT'
    dev_env --export >/dev/null
    dev_env --export >/dev/null
    grep -c '\\[profile floci-dev\\]' '${TEST_TMP}/.aws/config' | tail -1
  "
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]
}
