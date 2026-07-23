#!/usr/bin/env bats

load test_helper

setup() {
  setup_stub_env
}

teardown() {
  teardown_stub_env
}

@test "--fresh selects a fresh non-keep run" {
  run bash -c 'source "$ORCHESTRATOR"; parse_args --fresh; printf "%s|%s" "$FRESH" "$KEEP"'
  [ "$status" -eq 0 ]
  [ "$output" = "true|false" ]
}

@test "--keep enables twin reuse" {
  run bash -c 'source "$ORCHESTRATOR"; parse_args --keep; printf "%s" "$KEEP"'
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
}

@test "--destroy enables teardown" {
  run bash -c 'source "$ORCHESTRATOR"; parse_args --destroy; printf "%s" "$DESTROY"'
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
}

@test "--no-sidecar skips the sidecar test" {
  run bash -c 'source "$ORCHESTRATOR"; parse_args --no-sidecar; printf "%s" "$NO_SIDECAR"'
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
}

@test "--reboot-test enables reboot verification" {
  run bash -c 'source "$ORCHESTRATOR"; parse_args --reboot-test; printf "%s" "$REBOOT_TEST"'
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
}

@test "--evidence-dir stores its supplied path" {
  run bash -c 'source "$ORCHESTRATOR"; parse_args --evidence-dir=/tmp/x; printf "%s" "$EVIDENCE_DIR_OVERRIDE"'
  [ "$status" -eq 0 ]
  [ "$output" = "/tmp/x" ]
}

@test "an empty --evidence-dir reports a failure reason" {
  run bash -c 'source "$ORCHESTRATOR"; set +e; parse_args --evidence-dir=; status=$?; printf "%s|%s" "$status" "$FAIL_REASON"'
  [ "$status" -eq 0 ]
  [ "$output" = "1|usage: --evidence-dir requires a path" ]
}

@test "--help prints usage and returns its help status" {
  run bash -c 'source "$ORCHESTRATOR"; set +e; parse_args --help; exit $?'
  [ "$status" -eq 2 ]
  [[ "$output" == Usage:* ]]
}

@test "-h prints usage and returns its help status" {
  run bash -c 'source "$ORCHESTRATOR"; set +e; parse_args -h; exit $?'
  [ "$status" -eq 2 ]
  [[ "$output" == Usage:* ]]
}

@test "an unknown argument reports a failure reason" {
  run bash -c 'source "$ORCHESTRATOR"; set +e; parse_args --unknown >/dev/null 2>&1; status=$?; printf "%s|%s" "$status" "$FAIL_REASON"'
  [ "$status" -eq 0 ]
  [ "$output" = "1|usage: unknown argument --unknown" ]
}

@test "the limactl double logs instead of invoking Lima" {
  run limactl --version
  [ "$status" -eq 0 ]
  [ "$(stub_calls limactl)" = "limactl --version" ]
}
