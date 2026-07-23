#!/usr/bin/env bats

load test_helper

setup() {
  setup_stub_env
}

teardown() {
  teardown_stub_env
}

@test "assert_eq succeeds for equal values" {
  run bash -c 'source "$ASSERT_LIB"; assert_eq expected expected equality'
  [ "$status" -eq 0 ]
}

@test "assert_eq records a reason for unequal values" {
  run bash -c 'source "$ASSERT_LIB"; if assert_eq expected actual equality; then exit 1; fi; printf "%s" "$FAIL_REASON"'
  [ "$status" -eq 0 ]
  [ "$output" = "FAILED equality: expected expected got actual" ]
}

@test "assert_contains succeeds for contained text" {
  run bash -c 'source "$ASSERT_LIB"; assert_contains needle hayneedlestack contains'
  [ "$status" -eq 0 ]
}

@test "assert_contains records a reason for absent text" {
  run bash -c 'source "$ASSERT_LIB"; if assert_contains needle haystack contains; then exit 1; fi; printf "%s" "$FAIL_REASON"'
  [ "$status" -eq 0 ]
  [ "$output" = "FAILED contains: expected to contain needle in haystack" ]
}

@test "assert_http_200 succeeds on the first stubbed response" {
  export STUB_OUT_CURL=200

  run bash -c 'source "$ASSERT_LIB"; assert_http_200 https://tianlu-floci:4566/_floci/init health 1 0'
  [ "$status" -eq 0 ]
  [[ "$(stub_calls curl)" == *"curl -sk --resolve tianlu-floci:4566:127.0.0.1"* ]]
}

@test "assert_http_200 records a reason after its retry budget" {
  export STUB_OUT_CURL=000

  run bash -c 'source "$ASSERT_LIB"; if assert_http_200 https://tianlu-floci:4566/_floci/init health 1 0; then exit 1; fi; printf "%s" "$FAIL_REASON"'
  [ "$status" -eq 0 ]
  [ "$output" = "FAILED health: expected HTTP 200 from https://tianlu-floci:4566/_floci/init after 1 tries" ]
}

@test "redact_secret masks a presign secret" {
  run bash -c 'source "$ASSERT_LIB"; printf "%s\n" "FLOCI_AUTH_PRESIGN_SECRET=0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" | redact_secret'
  [ "$status" -eq 0 ]
  [ "$output" = "FLOCI_AUTH_PRESIGN_SECRET=REDACTED" ]
}

@test "redact_secret preserves bare hexadecimal text" {
  run bash -c 'source "$ASSERT_LIB"; printf "%s\n" abc123 | redact_secret'
  [ "$status" -eq 0 ]
  [ "$output" = "abc123" ]
}

@test "redact_secret masks a non-hex presign secret" {
  run bash -c 'source "$ASSERT_LIB"; printf "%s\n" "FLOCI_AUTH_PRESIGN_SECRET=not-hex" | redact_secret'
  [ "$status" -eq 0 ]
  [ "$output" = "FLOCI_AUTH_PRESIGN_SECRET=REDACTED" ]
}

@test "snapshot_state writes its canonical evidence sections" {
  run bash -c 'source "$ASSERT_LIB"; snapshot_state "$TEST_TMP/snapshot.txt"'
  [ "$status" -eq 0 ]
  [[ "$(<"${TEST_TMP}/snapshot.txt")" == *"### /etc/hosts managed block"* ]]
  [[ "$(<"${TEST_TMP}/snapshot.txt")" == *"### ufw status numbered"* ]]
  [[ "$(<"${TEST_TMP}/snapshot.txt")" == *"### loginctl show-user floci -p Linger"* ]]
  [ "$(stub_calls ufw)" = "ufw status numbered" ]
  [ "$(stub_calls loginctl)" = "loginctl show-user floci -p Linger" ]
}

@test "hash_state writes a sha256 line for a regular file" {
  printf 'state\n' >"${TEST_TMP}/state.txt"

  run bash -c 'source "$ASSERT_LIB"; hash_state "$TEST_TMP/state.txt" "$TEST_TMP/hash.txt"'
  [ "$status" -eq 0 ]
  [[ "$(<"${TEST_TMP}/hash.txt")" =~ ^[0-9a-f]{64}\ \ state.txt$ ]]
}

@test "hash_state excludes backup files" {
  printf 'state\n' >"${TEST_TMP}/state.bak"

  run bash -c 'source "$ASSERT_LIB"; hash_state "$TEST_TMP/state.bak" "$TEST_TMP/hash.txt"'
  [ "$status" -eq 0 ]
  [ ! -e "${TEST_TMP}/hash.txt" ]
}

@test "write_sentinel atomically leaves a DONE file" {
  run bash -c 'source "$ASSERT_LIB"; write_sentinel "$TEST_TMP/DONE"'
  [ "$status" -eq 0 ]
  [ -f "${TEST_TMP}/DONE" ]
  [ "$(<"${TEST_TMP}/DONE")" = "DONE" ]
  [ ! -e "${TEST_TMP}/DONE.tmp" ]
}

@test "run_as_floci_guest constructs the exact floci environment" {
  run bash -c 'source "$ASSERT_LIB"; run_as_floci_guest true'
  [ "$status" -eq 0 ]
  expected='sudo -u floci env HOME=/home/floci USER=floci PATH=/usr/local/bin:/usr/bin:/bin XDG_RUNTIME_DIR=/run/user/1001 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1001/bus -- true'
  [ "$(stub_calls sudo)" = "$expected" ]
}
