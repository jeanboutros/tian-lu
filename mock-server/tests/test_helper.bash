#!/usr/bin/env bash
# Shared setup for mock-server bats tests.
MOCK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export MOCK_ROOT
export ASSERT_LIB="${MOCK_ROOT}/in-vm/lib/assert.sh"
export ORCHESTRATOR="${MOCK_ROOT}/run-test.sh"
export DRIVER="${MOCK_ROOT}/in-vm/run-in-vm.sh"
export STUB_BIN="${MOCK_ROOT}/tests/stubs/bin"

setup_stub_env() {
  TEST_TMP="$(mktemp -d)"
  export TEST_TMP
  export STUB_LOG="${TEST_TMP}/stub.log"
  : >"$STUB_LOG"
  export PATH="${STUB_BIN}:${PATH}"
}

teardown_stub_env() {
  [[ -n "${TEST_TMP:-}" && -d "${TEST_TMP:-}" ]] && rm -rf "${TEST_TMP}"
}

stub_calls() {
  grep -E "^$1( |$)" "${STUB_LOG}" || true
}

export DEV_SCRIPT="${MOCK_ROOT}/dev-twin.sh"
