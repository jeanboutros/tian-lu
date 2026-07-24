#!/usr/bin/env bats

load test_helper

setup() {
  setup_stub_env
}

teardown() {
  teardown_stub_env
}

@test "identical snapshots produce an empty semantic convergence diff" {
  printf 'canonical state\n' >"${TEST_TMP}/run1.txt"
  cp "${TEST_TMP}/run1.txt" "${TEST_TMP}/run2.txt"

  run diff -u "${TEST_TMP}/run1.txt" "${TEST_TMP}/run2.txt"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "different snapshots produce a non-empty semantic convergence diff" {
  printf 'run one\n' >"${TEST_TMP}/run1.txt"
  printf 'run two\n' >"${TEST_TMP}/run2.txt"

  run diff -u "${TEST_TMP}/run1.txt" "${TEST_TMP}/run2.txt"
  [ "$status" -eq 1 ]
  [ -n "$output" ]
}

@test "hash_state skips a backup file during semantic convergence" {
  printf 'backup\n' >"${TEST_TMP}/env-hash.bak"

  run bash -c 'source "$ASSERT_LIB"; hash_state "$TEST_TMP/env-hash.bak" "$TEST_TMP/hash.txt"'
  [ "$status" -eq 0 ]
  [ ! -e "${TEST_TMP}/hash.txt" ]
}

@test "hash_state records the regular snapshot hash and basename" {
  printf 'snapshot\n' >"${TEST_TMP}/env-hash.txt"

  run bash -c 'source "$ASSERT_LIB"; hash_state "$TEST_TMP/env-hash.txt" "$TEST_TMP/hash.txt"'
  [ "$status" -eq 0 ]
  [[ "$(<"${TEST_TMP}/hash.txt")" =~ ^[0-9a-f]{64}\ \ env-hash.txt$ ]]
}
