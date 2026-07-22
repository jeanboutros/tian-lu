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
  [ "$output" = "${TEST_TMP}/x|${TEST_TMP}/x/.config/floci/floci.env|floci/floci:1.5.33-compat" ]
}

@test "executing the script runs main" {
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"implementation in progress"* ]]
}
