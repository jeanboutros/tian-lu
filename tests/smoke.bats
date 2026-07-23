#!/usr/bin/env bats
#
# Unit 0 smoke tests: the script must be sourceable, expose main(), honour
# config overrides, and run main() when executed directly.

load test_helper

setup() {
  setup_stub_env
}

teardown() {
  teardown_stub_env
}

@test "sourcing does not execute main" {
  run bash -c "source '${SCRIPT}'; echo SOURCED_OK"
  [ "$status" -eq 0 ]
  [[ "$output" == *"SOURCED_OK"* ]]
  [[ "$output" != *"implementation in progress"* ]]
}

@test "main is defined after sourcing" {
  run bash -c "source '${SCRIPT}'; declare -F main >/dev/null && echo HAS_MAIN"
  [ "$status" -eq 0 ]
  [[ "$output" == *"HAS_MAIN"* ]]
}

@test "config constants resolve and honour overrides" {
  run bash -c "FLOCI_HOME='${TEST_TMP}/x'; source '${SCRIPT}'; printf '%s|%s|%s' \"\$FLOCI_HOME\" \"\$FLOCI_ENV_FILE\" \"\$FLOCI_IMAGE\""
  [ "$status" -eq 0 ]
  [ "$output" = "${TEST_TMP}/x|${TEST_TMP}/x/.config/floci/floci.env|docker.io/floci/floci:1.5.33-compat" ]
}

@test "executing the script runs main" {
  # Running as non-root now hits assert_root_or_sudo (the first Phase 1
  # check main() reaches) and exits non-zero with a root/sudo error on
  # stderr, instead of the old placeholder echo. STUB_OUT_ID is forced to a
  # non-zero UID so `id -u` deterministically reports "not root" regardless
  # of the UID bats itself is actually running as.
  export STUB_OUT_ID="1000"
  run bash "${SCRIPT}"
  [ "$status" -ne 0 ]
  [[ "$output" == *"root"* || "$output" == *"sudo"* ]]
}
