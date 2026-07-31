#!/usr/bin/env bats

load test_helper

setup() {
  setup_stub_env
}

teardown() {
  teardown_stub_env
}

@test "poll_sentinel returns 0 when DONE file exists" {
  mkdir -p "$TEST_TMP/staging"
  printf 'DONE\n' > "$TEST_TMP/staging/DONE"
  run bash -c '
    source "$ORCHESTRATOR"
    STAGING="'"$TEST_TMP/staging"'"
    FRESH=false
    poll_sentinel
  '
  [ "$status" -eq 0 ]
}

@test "poll_sentinel returns 1 when FAILED file exists" {
  mkdir -p "$TEST_TMP/staging"
  printf 'some error\n' > "$TEST_TMP/staging/FAILED"
  run bash -c '
    source "$ORCHESTRATOR"
    STAGING="'"$TEST_TMP/staging"'"
    FRESH=false
    set +e
    poll_sentinel
    echo "status=$?"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"driver failed"* || "$output" == *"status=1"* ]]
}

@test "poll_sentinel does NOT treat summary.md as completion" {
  mkdir -p "$TEST_TMP/staging"
  printf '| run1-exit-0 | PASS |\n' > "$TEST_TMP/staging/summary.md"
  HEALTH_POLL_TRIES=2 run bash -c '
    source "$ORCHESTRATOR"
    STAGING="'"$TEST_TMP/staging"'"
    FRESH=false
    SERVICE_HEALTH_BUDGET=1
    FRESH_BUDGET=1
    poll_sentinel
  '
  [ "$status" -ne 0 ]
}

@test "wait_driver returns 0 for a successful driver" {
  run bash -c '
    source "$ORCHESTRATOR"
    true &
    DRIVER_SHELL_PID=$!
    wait_driver
  '
  [ "$status" -eq 0 ]
}

@test "wait_driver records a reason for a failed driver" {
  run bash -c '
    source "$ORCHESTRATOR"
    false &
    DRIVER_SHELL_PID=$!
    wait_driver || printf "%s" "$FAIL_REASON"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"driver exited nonzero"* ]]
}

@test "wait_driver produces distinct verdict for killed-after-timeout (143)" {
  run bash -c '
    source "$ORCHESTRATOR"
    sleep 10 &
    DRIVER_SHELL_PID=$!
    kill -TERM "$DRIVER_SHELL_PID" 2>/dev/null || true
    wait_driver || printf "%s" "$FAIL_REASON"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"killed after timeout"* ]]
}

@test "wait_driver produces distinct verdict for empty DRIVER_SHELL_PID" {
  run bash -c '
    source "$ORCHESTRATOR"
    DRIVER_SHELL_PID=""
    wait_driver || printf "%s" "$FAIL_REASON"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"driver PID not set"* ]]
}

@test "validate_summary returns 0 for all-PASS summary" {
  if (( BASH_VERSINFO[0] < 4 )); then
    skip "validate_summary requires Bash 4 or newer"
  fi
  mkdir -p "$TEST_TMP/final"
  cat > "$TEST_TMP/final/summary.md" <<'EOF'
# Lima digital-twin evidence summary

| Criterion | Status |
| --- | --- |
| preflight-ok | PASS |
| run1-exit-0 | PASS |
| floci-service-active | PASS |
| health-200 | PASS |
| s3-smoke | PASS |
| sidecar-delta | PASS |
| run2-exit-0 | PASS |
| idempotency-hosts | PASS |
| idempotency-subuid | PASS |
| idempotency-hashes | PASS |
| reboot-health-200 | PENDING |
| reboot-ordering | PENDING |
EOF
  run bash -c '
    source "$ORCHESTRATOR"
    FINAL="'"$TEST_TMP/final"'"
    NO_SIDECAR=false
    REBOOT_TEST=false
    validate_summary
  '
  [ "$status" -eq 0 ]
}

@test "validate_summary returns 1 when mandatory criterion is FAIL" {
  if (( BASH_VERSINFO[0] < 4 )); then
    skip "validate_summary requires Bash 4 or newer"
  fi
  mkdir -p "$TEST_TMP/final"
  cat > "$TEST_TMP/final/summary.md" <<'EOF'
# Lima digital-twin evidence summary

| Criterion | Status |
| --- | --- |
| preflight-ok | PASS |
| run1-exit-0 | FAIL |
| floci-service-active | PASS |
| health-200 | PASS |
| s3-smoke | PASS |
| sidecar-delta | PASS |
| run2-exit-0 | PASS |
| idempotency-hosts | PASS |
| idempotency-subuid | PASS |
| idempotency-hashes | PASS |
| reboot-health-200 | PENDING |
| reboot-ordering | PENDING |
EOF
  run bash -c '
    source "$ORCHESTRATOR"
    FINAL="'"$TEST_TMP/final"'"
    NO_SIDECAR=false
    REBOOT_TEST=false
    validate_summary || printf "%s" "$FAIL_REASON"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"run1-exit-0"* ]]
}

@test "validate_summary accepts reboot-health-200=PENDING with reboot-ordering=PASS under --reboot-test" {
  if (( BASH_VERSINFO[0] < 4 )); then
    skip "validate_summary requires Bash 4 or newer"
  fi
  mkdir -p "$TEST_TMP/final"
  cat > "$TEST_TMP/final/summary.md" <<'EOF'
# Lima digital-twin evidence summary

| Criterion | Status |
| --- | --- |
| preflight-ok | PASS |
| run1-exit-0 | PASS |
| floci-service-active | PASS |
| health-200 | PASS |
| s3-smoke | PASS |
| sidecar-delta | PASS |
| run2-exit-0 | PASS |
| idempotency-hosts | PASS |
| idempotency-subuid | PASS |
| idempotency-hashes | PASS |
| reboot-health-200 | PENDING |
| reboot-ordering | PASS |
EOF
  run bash -c '
    source "$ORCHESTRATOR"
    FINAL="'"$TEST_TMP/final"'"
    NO_SIDECAR=false
    REBOOT_TEST=true
    validate_summary
  '
  [ "$status" -eq 0 ]
}

@test "validate_summary rejects reboot-ordering=PENDING under --reboot-test" {
  if (( BASH_VERSINFO[0] < 4 )); then
    skip "validate_summary requires Bash 4 or newer"
  fi
  mkdir -p "$TEST_TMP/final"
  cat > "$TEST_TMP/final/summary.md" <<'EOF'
# Lima digital-twin evidence summary

| Criterion | Status |
| --- | --- |
| preflight-ok | PASS |
| run1-exit-0 | PASS |
| floci-service-active | PASS |
| health-200 | PASS |
| s3-smoke | PASS |
| sidecar-delta | PASS |
| run2-exit-0 | PASS |
| idempotency-hosts | PASS |
| idempotency-subuid | PASS |
| idempotency-hashes | PASS |
| reboot-health-200 | PENDING |
| reboot-ordering | PENDING |
EOF
  run bash -c '
    source "$ORCHESTRATOR"
    FINAL="'"$TEST_TMP/final"'"
    NO_SIDECAR=false
    REBOOT_TEST=true
    validate_summary || printf "%s" "$FAIL_REASON"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"reboot-ordering"* ]]
}

@test "validate_summary rejects duplicate criterion rows" {
  if (( BASH_VERSINFO[0] < 4 )); then
    skip "validate_summary requires Bash 4 or newer"
  fi
  mkdir -p "$TEST_TMP/final"
  cat > "$TEST_TMP/final/summary.md" <<'EOF'
| Criterion | Status |
| --- | --- |
| preflight-ok | PASS |
| run1-exit-0 | PASS |
| reboot-health-200 | PENDING |
| reboot-health-200 | PASS |
EOF
  run bash -c '
    source "$ORCHESTRATOR"
    FINAL="'"$TEST_TMP/final"'"
    NO_SIDECAR=false
    REBOOT_TEST=false
    validate_summary || printf "%s" "$FAIL_REASON"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"duplicate"* ]]
}
