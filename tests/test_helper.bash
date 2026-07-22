#!/usr/bin/env bash
#
# Shared setup for bats tests. `load test_helper` from any .bats file.

# Repo root (tests/ lives one level below it).
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export REPO_ROOT
export SCRIPT="${REPO_ROOT}/setup-floci.sh"
export STUB_BIN="${REPO_ROOT}/tests/stubs/bin"

# setup_stub_env: create a scratch HOME/root, a fresh STUB_LOG, and put the
# command stubs first on PATH. Call from a test's setup().
setup_stub_env() {
  TEST_TMP="$(mktemp -d)"
  export TEST_TMP
  export FLOCI_HOME="${TEST_TMP}/home/floci"
  mkdir -p "$FLOCI_HOME"
  export STUB_LOG="${TEST_TMP}/stub.log"
  : >"$STUB_LOG"
  export PATH="${STUB_BIN}:${PATH}"
}

# teardown_stub_env: remove the scratch dir. Call from a test's teardown().
teardown_stub_env() {
  if [[ -n "${TEST_TMP:-}" && -d "${TEST_TMP}" ]]; then
    rm -rf "${TEST_TMP}"
  fi
}

# stub_calls <name>: print the logged invocations for command <name>.
stub_calls() {
  grep -E "^$1( |\$)" "${STUB_LOG}" || true
}
