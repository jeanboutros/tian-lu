#!/usr/bin/env bats

load test_helper

# Every path dev-twin.sh can DELETE or REWRITE is redirected into TEST_TMP here, for the
# whole file, rather than per-test.
#
# This is not defensive styling. `dev_reset` runs `rm -f "$DEV_ACCOUNT_SECRET_FILE"` and
# `rm -rf "$DEV_AWS_DIR"`; a dev_reset test that forgot either override deleted the
# developer's real dev-twin credentials under ~/.cache/tianlu-floci — from a plain
# `make test`. Exactly that happened once. A per-test override is one omission away from
# happening again, so the sandbox lives here.
setup() {
  setup_stub_env
  export DEV_HOSTS_FILE="${TEST_TMP}/hosts"
  printf '127.0.0.1 localhost\n192.168.1.5 someother\n' > "$DEV_HOSTS_FILE"

  # HOME first, so anything derived from it that is added later lands here by default;
  # then each path spelled out, so a reader can see what is sandboxed without deriving it.
  # Both must agree — the values below are exactly what the script's defaults produce.
  export HOME="${TEST_TMP}"
  export DEV_AWS_DIR="${TEST_TMP}/.cache/tianlu-floci/aws"
  export DEV_ACCOUNT_SECRET_FILE="${TEST_TMP}/.cache/tianlu-floci/dev/account.secret"
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

@test "_print_next_steps includes manual hosts command when DEV_HOSTS_SKIPPED=1" {
  run bash -c "
    source '$DEV_SCRIPT'
    DEV_HOSTS_SKIPPED=1 _print_next_steps
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"Next steps"* ]]
  [[ "$output" == *"eval \"\$(make dev-env-export)\""* ]]
  [[ "$output" == *"make dev-status"* ]]
  [[ "$output" == *"make dev-shell"* ]]
  [[ "$output" == *"make dev-down"* ]]
  [[ "$output" == *"127.0.0.1 tianlu-floci"* ]]
}

@test "_print_next_steps omits manual command when DEV_HOSTS_SKIPPED is unset" {
  run bash -c "
    source '$DEV_SCRIPT'
    _print_next_steps
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"Next steps"* ]]
  [[ "$output" != *"You skipped"* ]]
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
    managed_hosts_add() { :; }
    _print_next_steps() { :; }
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
    export DEV_RESUME_HEALTH_TRIES=1
    export DEV_USER_MANAGER_TRIES=1
    source '$DEV_SCRIPT'
    assert_preconditions() { :; }
    dev_instance_state() { printf 'Stopped\\n'; }
    verify_disk_mount() { return 0; }
    _wait_user_manager() { :; }
    _ensure_service() { :; }
    managed_hosts_add() { :; }
    _print_next_steps() { :; }
    dev_up 2>&1
  "
  [ "$status" -eq 0 ]
  grep -q 'limactl start --tty=false floci-dev' "$STUB_LOG"
  ! grep -q 'setup-floci.sh' "$STUB_LOG"
}

@test "dev_up Stopped path: _ensure_service called after _wait_user_manager" {
  STUB_LOG="${STUB_LOG}" STUB_OUT_LIMACTL='floci-dev Running' STUB_OUT_CURL='200' \
  DEV_START_BUDGET_RESUME=1 DEV_RESUME_HEALTH_TRIES=1 DEV_USER_MANAGER_TRIES=1 \
  DEV_SCRIPT="$DEV_SCRIPT" \
  run bash -c '
    source "$DEV_SCRIPT"
    assert_preconditions() { :; }
    dev_instance_state() { printf "Stopped\n"; }
    verify_disk_mount() { return 0; }
    _wait_user_manager() { printf "WAIT_USER_MANAGER\n" >> "$STUB_LOG"; }
    _ensure_service() { printf "ENSURE_SERVICE\n" >> "$STUB_LOG"; }
    managed_hosts_add() { :; }
    _print_next_steps() { :; }
    dev_up 2>&1
  '
  [ "$status" -eq 0 ]
  local wait_line ensure_line
  wait_line=$(grep -n 'WAIT_USER_MANAGER' "$STUB_LOG" | head -1 | cut -d: -f1)
  ensure_line=$(grep -n 'ENSURE_SERVICE' "$STUB_LOG" | head -1 | cut -d: -f1)
  (( wait_line > 0 && ensure_line > wait_line ))
}

@test "_ensure_service resets failed state before starting" {
  run bash -c "
    export STUB_LOG='${STUB_LOG}'
    source '$DEV_SCRIPT'
    _floci_service_state() { printf 'failed\\n'; }
    _reset_floci_service() { printf 'RESET\\n' >> '${STUB_LOG}'; }
    _run_as_floci_guest() { printf 'RUN:%s\\n' \"\$1\" >> '${STUB_LOG}'; }
    _ensure_service
  "
  [ "$status" -eq 0 ]
  grep -q 'RESET' "$STUB_LOG"
  grep -q 'RUN:systemctl --user start floci.service' "$STUB_LOG"
}

@test "_ensure_service no-op when service already active" {
  run bash -c "
    export STUB_LOG='${STUB_LOG}'
    source '$DEV_SCRIPT'
    _floci_service_state() { printf 'active\\n'; }
    _reset_floci_service() { printf 'UNEXPECTED_RESET\\n' >> '${STUB_LOG}'; }
    _run_as_floci_guest() { printf 'UNEXPECTED_START\\n' >> '${STUB_LOG}'; }
    _ensure_service
  "
  [ "$status" -eq 0 ]
  ! grep -q 'UNEXPECTED_RESET' "$STUB_LOG"
  ! grep -q 'UNEXPECTED_START' "$STUB_LOG"
}

@test "_resume_health_check triggers reset-failed fallback on failed state" {
  run bash -c "
    export STUB_LOG='${STUB_LOG}'
    export STUB_OUT_CURL='000'
    export DEV_RESUME_HEALTH_TRIES=2
    export DEV_RESUME_HEALTH_SLEEP=0
    source '$DEV_SCRIPT'
    _floci_service_state() { printf 'failed\\n'; }
    _reset_floci_service() { printf 'RESET\\n' >> '${STUB_LOG}'; }
    _run_as_floci_guest() { printf 'START\\n' >> '${STUB_LOG}'; }
    _resume_health_check 2>&1
  "
  [ "$status" -ne 0 ]
  grep -q 'RESET' "$STUB_LOG"
  grep -q 'START' "$STUB_LOG"
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

@test "dev_status reads the auth mode from the installer env file" {
  run bash -c "
    export STUB_LOG='${STUB_LOG}'
    source '$DEV_SCRIPT'
    _run_as_floci_guest() { printf 'GUEST_CMD: %s\\n' \"\$*\" >&2; printf 'sigv4\\n'; }
    dev_status 2>&1
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"/home/floci/.config/floci/floci.env"* ]]
  [[ "$output" == *"auth: sigv4"* ]]
}

@test "dev_status reports auth unknown when the env file is unreadable" {
  run bash -c "
    export STUB_LOG='${STUB_LOG}'
    source '$DEV_SCRIPT'
    _run_as_floci_guest() { return 1; }
    dev_status 2>&1
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"auth: unknown"* ]]
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
# dev_env — project-local AWS profile (Option C)
# ---------------------------------------------------------------------------
@test "dev_env --export prints Option C env vars" {
  run bash -c "
    export HOME='${TEST_TMP}'
    source '$DEV_SCRIPT'
    dev_env --export
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"AWS_PROFILE=ns-tianlu-floci-dev"* ]]
  [[ "$output" == *"AWS_CONFIG_FILE="* ]]
  [[ "$output" == *"AWS_SHARED_CREDENTIALS_FILE="* ]]
}

@test "dev_env writes account-root AKID + generated secret to the project-local store" {
  run bash -c "
    export HOME='${TEST_TMP}'
    source '$DEV_SCRIPT'
    dev_env --export >/dev/null
  "
  [ "$status" -eq 0 ]
  local creds="${TEST_TMP}/.cache/tianlu-floci/aws/credentials"
  local cfg="${TEST_TMP}/.cache/tianlu-floci/aws/config"
  [ -f "$creds" ]
  grep -qF '[ns-tianlu-floci-dev]' "$creds"
  grep -qF 'aws_access_key_id = 111111111111' "$creds"
  grep -qE 'aws_secret_access_key = [0-9a-f]{64}' "$creds"
  grep -qF 'endpoint_url = http://tianlu-floci:4566' "$cfg"
  # the host's real ~/.aws must be left untouched
  [ ! -e "${TEST_TMP}/.aws/credentials" ]
}

# ---------------------------------------------------------------------------
# _ensure_account_secret — per-env generated secret
# ---------------------------------------------------------------------------
@test "_ensure_account_secret generates a 0600 64-hex secret and reuses it" {
  run bash -c "
    export HOME='${TEST_TMP}'
    source '$DEV_SCRIPT'
    _ensure_account_secret
    cat \"\$DEV_ACCOUNT_SECRET_FILE\"
    _ensure_account_secret
    cat \"\$DEV_ACCOUNT_SECRET_FILE\"
  "
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" =~ ^[0-9a-f]{64}$ ]]
  [ "${lines[0]}" = "${lines[1]}" ]
  local secret_file="${TEST_TMP}/.cache/tianlu-floci/dev/account.secret"
  local mode
  # GNU stat first (-c), BSD fallback (-f): on Linux `stat -f` means "filesystem"
  # and prints a multi-line dump with exit 0, so a BSD-first order never reaches
  # the -c fallback and the mode assertion fails. Same pattern as tests/phase5.bats.
  mode="$(/usr/bin/stat -c '%a' "$secret_file" 2>/dev/null || /usr/bin/stat -f '%Lp' "$secret_file" 2>/dev/null)"
  [ "$mode" = "600" ] || [ "$mode" = "0600" ]
}

@test "dev_env is idempotent — one profile block, secret reused across runs" {
  run bash -c "
    export HOME='${TEST_TMP}'
    source '$DEV_SCRIPT'
    dev_env --export >/dev/null
    cp \"\$DEV_ACCOUNT_SECRET_FILE\" '${TEST_TMP}/secret1'
    dev_env --export >/dev/null
    cp \"\$DEV_ACCOUNT_SECRET_FILE\" '${TEST_TMP}/secret2'
  "
  [ "$status" -eq 0 ]
  local creds="${TEST_TMP}/.cache/tianlu-floci/aws/credentials"
  [ "$(grep -cF '[ns-tianlu-floci-dev]' "$creds")" -eq 1 ]
  cmp -s "${TEST_TMP}/secret1" "${TEST_TMP}/secret2"
}

# ===========================================================================
# _print_next_steps — auth posture
# ===========================================================================
@test "_print_next_steps prints the auth posture note in sigv4 mode" {
  run env DEV_AUTH_MODE=sigv4 bash -c "
    source '$DEV_SCRIPT'
    _print_next_steps
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"Next steps"* ]]
  [[ "$output" == *"make dev-env"* ]]
  [[ "$output" == *"Auth posture"* ]]
  [[ "$output" == *"account-root"* ]]
}

# ===========================================================================
# Unified health budget (M-29 / CH-DEV-005)
# ===========================================================================

@test "health budget: fresh-install health budget matches resume budget (M-29)" {
  run bash -c "
    source '$DEV_SCRIPT'
    # Both _health_check (fresh-install) and _resume_health_check (resume)
    # use the same DEV_RESUME_HEALTH_TRIES * DEV_RESUME_HEALTH_SLEEP budget.
    health_budget=\$(( DEV_RESUME_HEALTH_TRIES * DEV_RESUME_HEALTH_SLEEP ))
    printf '%s\n' \"\$health_budget\"
  "
  [ "$status" -eq 0 ]
  [ "$output" = "300" ]
}

# ===========================================================================
# dev_env — export block and the project-local store
#
# These stay independent of the `aws` CLI and of `openssl`: neither is present in
# the CI containers (make ci-test installs only make/shellcheck/bats/podman), and
# the contract under test is the printed block, not what aws configure wrote.
# The secret file is pre-created so _ensure_account_secret returns early.
# ===========================================================================

_dev_env_setup() {
  mkdir -p "$(dirname "$DEV_ACCOUNT_SECRET_FILE")"
  printf 'cafebabe\n' > "$DEV_ACCOUNT_SECRET_FILE"
}

@test "dev_env --export prints ONLY export lines on stdout (eval safety)" {
  _dev_env_setup
  run bash -c "source '$DEV_SCRIPT'; dev_env --export 2>/dev/null"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
  # Anything else on stdout would be executed by `eval "$(make dev-env-export)"`.
  run bash -c "source '$DEV_SCRIPT'; dev_env --export 2>/dev/null | grep -cv '^export '"
  [ "$output" = "0" ]
}

@test "dev_env --export output is eval-able and sets the three variables" {
  _dev_env_setup
  run bash -c "
    source '$DEV_SCRIPT'
    eval \"\$(dev_env --export 2>/dev/null)\"
    printf '%s\n%s\n%s\n' \"\$AWS_PROFILE\" \"\$AWS_CONFIG_FILE\" \"\$AWS_SHARED_CREDENTIALS_FILE\"
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"ns-tianlu-floci-dev"* ]]
  [[ "$output" == *"${DEV_AWS_DIR}/config"* ]]
  [[ "$output" == *"${DEV_AWS_DIR}/credentials"* ]]
}

@test "dev_env points at the project-local store, never at ~/.aws" {
  _dev_env_setup
  run bash -c "source '$DEV_SCRIPT'; dev_env 2>/dev/null"
  [ "$status" -eq 0 ]
  [[ "$output" == *"${DEV_AWS_DIR}"* ]]
  ! [[ "$output" == *"${HOME}/.aws"* ]]
  [ -d "${DEV_AWS_DIR}" ]
}

# (secret generation/reuse is already covered above by
#  "_ensure_account_secret generates a 0600 64-hex secret and reuses it")

@test "the harness sandboxes every path dev_reset deletes (no real files at risk)" {
  # If any of these ever points outside TEST_TMP again, `make test` deletes the developer's
  # dev-twin credentials. See the comment on setup().
  for v in HOME DEV_HOSTS_FILE DEV_AWS_DIR DEV_ACCOUNT_SECRET_FILE; do
    [[ "${!v}" == "${TEST_TMP}" || "${!v}" == "${TEST_TMP}/"* ]] || {
      printf 'FAIL: %s=%s is outside TEST_TMP\n' "$v" "${!v}" >&2
      return 1
    }
  done
}
