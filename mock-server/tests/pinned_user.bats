#!/usr/bin/env bats

load test_helper

setup() {
  setup_stub_env
}

teardown() {
  teardown_stub_env
}

@test "static: floci-twin.yaml contains name: floci-runner and uid: 1001" {
  run grep -c 'name: floci-runner' "$MOCK_ROOT/lima/floci-twin.yaml"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
  run grep -c 'uid: 1001' "$MOCK_ROOT/lima/floci-twin.yaml"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

@test "static: floci-dev.yaml contains name: floci-runner and uid: 1001" {
  run grep -c 'name: floci-runner' "$MOCK_ROOT/lima/floci-dev.yaml"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
  run grep -c 'uid: 1001' "$MOCK_ROOT/lima/floci-dev.yaml"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

@test "assert_pinned_user passes when whoami=floci-runner and only floci-runner in uid range" {
  STUB_OUT_WHOAMI="floci-runner"
  STUB_OUT_GETENT="floci-runner:x:1001:1001::/home/floci-runner:/bin/bash"
  export STUB_OUT_WHOAMI STUB_OUT_GETENT
  run bash -c '
    source "$ASSERT_LIB"
    FAIL_REASON=""
    assert_pinned_user
  '
  [ "$status" -eq 0 ]
}

@test "assert_pinned_user fails when whoami returns host username" {
  STUB_OUT_WHOAMI="ukcci1jbo"
  STUB_OUT_GETENT="ukcci1jbo:x:1001:1001::/home/ukcci1jbo:/bin/bash"
  export STUB_OUT_WHOAMI STUB_OUT_GETENT
  run bash -c '
    source "$ASSERT_LIB"
    FAIL_REASON=""
    assert_pinned_user || printf "%s" "$FAIL_REASON"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"floci-runner"* ]]
}

@test "assert_pinned_user fails when a second non-system user exists alongside floci-runner" {
  STUB_OUT_WHOAMI="floci-runner"
  STUB_OUT_GETENT="$(printf 'floci-runner:x:1001:1001::/home/floci-runner:/bin/bash\nubuntu:x:1000:1000::/home/ubuntu:/bin/bash')"
  export STUB_OUT_WHOAMI STUB_OUT_GETENT
  run bash -c '
    source "$ASSERT_LIB"
    FAIL_REASON=""
    assert_pinned_user || printf "%s" "$FAIL_REASON"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"floci-runner"* ]]
}
