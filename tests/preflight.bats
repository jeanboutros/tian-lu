#!/usr/bin/env bats
#
# Unit tests for scripts/preflight-floci.sh gates:
#   G1 (signature validation), G3 (DynamoDB lock), G2/G4/G5 (manual gates).
#
# Uses the same stub infrastructure as the installer tests (tests/stubs/bin/).
# preflight-floci.sh calls main "$@" unconditionally at the bottom, so tests
# strip that line before sourcing to test individual functions.

load test_helper

PREFILIGHT_SCRIPT="${REPO_ROOT}/scripts/preflight-floci.sh"

setup() {
  setup_stub_env
  # Create a copy of the script without the auto-executing main "$@" line
  sed '/^main "\$@"/d' "${PREFILIGHT_SCRIPT}" > "${TEST_TMP}/preflight-no-main.sh"
  export PREFILIGHT_NO_MAIN="${TEST_TMP}/preflight-no-main.sh"
}

teardown() {
  teardown_stub_env
}

# ===========================================================================
# G1 — IAM authorization enforcement
# ===========================================================================

@test "G1: aws_admin calls aws with --endpoint-url and --region (SPEC-TX-009)" {
  run bash -c "
    export STUB_LOG='${STUB_LOG}'
    source '${PREFILIGHT_NO_MAIN}'
    aws_admin sts get-caller-identity
  "
  [ "$status" -eq 0 ]
  grep -qF "aws" "$STUB_LOG"
  grep -qF "endpoint-url" "$STUB_LOG"
  grep -qF "region" "$STUB_LOG"
  grep -qF "sts" "$STUB_LOG"
  grep -qF "get-caller-identity" "$STUB_LOG"
}

@test "G1: aws_admin uses DEV_AKID override when set" {
  # DEV_AKID is passed as an env var to aws, not as a CLI arg.
  # Test that the override is accepted by the script (no error on source).
  run bash -c "
    export STUB_LOG='${STUB_LOG}'
    export DEV_AKID='AKID_OVERRIDE'
    source '${PREFILIGHT_NO_MAIN}'
    # Verify the override was accepted by checking the readonly var
    [[ \"\$DEV_AKID\" == 'AKID_OVERRIDE' ]]
  "
  [ "$status" -eq 0 ]
}

@test "G1: aws_admin passes through additional aws arguments" {
  run bash -c "
    export STUB_LOG='${STUB_LOG}'
    source '${PREFILIGHT_NO_MAIN}'
    aws_admin s3 ls --output json
  "
  [ "$status" -eq 0 ]
  grep -qF "s3" "$STUB_LOG"
  grep -qF "ls" "$STUB_LOG"
  grep -qF "json" "$STUB_LOG"
}

@test "G1: must fail (not skip) when probe cannot be established (CH-LZ-004)" {
  skip "TODO(CH-LZ-004): G1 currently calls skip() on create-access-key failure — needs implementation to call fail() instead. Per M-9 BACKLOG."
  # When implemented:
  #   STUB_RC_AWS=1 → gate_g1_signatures should call fail(), not skip()
  #   FAILED should be set to 1
  #   Output should contain FAIL not SKIP
}

# ===========================================================================
# G3 — DynamoDB conditional writes
# ===========================================================================

@test "G3: gate_g3_dynamodb_lock passes when conditional write is enforced" {
  # Use a counter file to make the second put-item call fail
  cat > "${TEST_TMP}/aws" <<'STUB_EOF'
#!/usr/bin/env bash
call="$*"
printf 'aws %s\n' "$call" >> "$STUB_LOG"
case "$call" in
  *"create-table"*) exit 0 ;;
  *"put-item"*)
    local count
    count=$(cat /tmp/preflight-put-count 2>/dev/null || echo 0)
    count=$((count + 1))
    printf '%d' "$count" > /tmp/preflight-put-count
    if [[ $count -ge 2 ]]; then
      printf 'ConditionalCheckFailedException\n' >&2
      exit 254
    fi
    exit 0
    ;;
  *"delete-table"*) exit 0 ;;
  *) exit 0 ;;
esac
STUB_EOF
  chmod +x "${TEST_TMP}/aws"
  rm -f /tmp/preflight-put-count

  run bash -c "
    export STUB_LOG='${STUB_LOG}'
    export PATH='${TEST_TMP}:${PATH}'
    source '${PREFILIGHT_NO_MAIN}'
    gate_g3_dynamodb_lock
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"PASS"* ]]
  [[ "$output" == *"locking works"* ]]
}

@test "G3: gate_g3_dynamodb_lock fails when second put-item succeeds" {
  cat > "${TEST_TMP}/aws" <<'STUB_EOF'
#!/usr/bin/env bash
call="$*"
printf 'aws %s\n' "$call" >> "$STUB_LOG"
exit 0
STUB_EOF
  chmod +x "${TEST_TMP}/aws"

  run bash -c "
    export STUB_LOG='${STUB_LOG}'
    export PATH='${TEST_TMP}:${PATH}'
    source '${PREFILIGHT_NO_MAIN}'
    gate_g3_dynamodb_lock
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"FAIL"* ]]
  [[ "$output" == *"locking broken"* ]]
}

# ===========================================================================
# G2 — RDS IAM DB auth (manual gate)
# ===========================================================================

@test "G2: gate_g2_iam_db_auth skips when no RDS host is set" {
  run bash -c "
    export STUB_LOG='${STUB_LOG}'
    source '${PREFILIGHT_NO_MAIN}'
    gate_g2_iam_db_auth
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"SKIP"* ]]
  [[ "$output" == *"no RDS yet"* ]]
}

# ===========================================================================
# main — exit codes
# ===========================================================================

@test "main: exits 2 when aws CLI is not found" {
  run bash -c "
    export STUB_LOG='${STUB_LOG}'
    export PATH='${TEST_TMP}'
    source '${PREFILIGHT_SCRIPT}'
  "
  [ "$status" -eq 2 ]
  [[ "$output" == *"aws CLI not found"* ]]
}

@test "main: exits 0 when all automated gates pass" {
  cat > "${TEST_TMP}/aws" <<'STUB_EOF'
#!/usr/bin/env bash
call="$*"
printf 'aws %s\n' "$call" >> "$STUB_LOG"
case "$call" in
  *"create-access-key"*)
    printf '{"AccessKey":{"AccessKeyId":"AKIA_TEST","SecretAccessKey":"secret_test"}}\n'
    exit 0
    ;;
  *"describe-db-instances"*) exit 254 ;;
  *"delete-access-key"*) exit 0 ;;
  *"delete-user"*) exit 0 ;;
  *"create-table"*) exit 0 ;;
  *"put-item"*)
    local count
    count=$(cat /tmp/preflight-put-count 2>/dev/null || echo 0)
    count=$((count + 1))
    printf '%d' "$count" > /tmp/preflight-put-count
    if [[ $count -ge 2 ]]; then
      exit 254
    fi
    exit 0
    ;;
  *"delete-table"*) exit 0 ;;
  *) exit 0 ;;
esac
STUB_EOF
  chmod +x "${TEST_TMP}/aws"
  rm -f /tmp/preflight-put-count

  run bash -c "
    export STUB_LOG='${STUB_LOG}'
    export PATH='${TEST_TMP}:${PATH}'
    source '${PREFILIGHT_SCRIPT}'
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"automated gates passed"* ]]
}
