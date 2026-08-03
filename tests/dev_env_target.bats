#!/usr/bin/env bats
#
# The root Makefile's dev-env / dev-env-export targets.
#
# These exist because `eval "$(make dev-env-export)"` is documented in five places, and it is
# broken by two edits that both look harmless in review:
#
#   1. dropping the `@` — make then echoes the recipe line onto stdout, so eval runs
#      `mock-server/dev-twin.sh env` as its first statement and the script executes twice;
#   2. folding the two targets back into one and passing the flag as `make dev-env --
#      --export` — `--` ends make's option parsing, so `--export` is parsed as a GOAL, never
#      reaches the script, and make exits 2.
#
# Both were live defects. The script itself is stubbed here: what is under test is the
# Makefile wiring, not dev-twin.sh.

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  TEST_TMP="$(mktemp -d)"
  STUB="${TEST_TMP}/dev-twin-stub.sh"
  cat > "$STUB" <<'STUBEOF'
#!/usr/bin/env bash
printf 'ARGS=%s\n' "$*" >> "$STUB_LOG"
printf 'export STUB_SAW_ARGS=%q\n' "$*"
STUBEOF
  chmod +x "$STUB"
  export STUB_LOG="${TEST_TMP}/stub.log"
  : > "$STUB_LOG"
}

teardown() {
  [[ -n "${TEST_TMP:-}" && -d "$TEST_TMP" ]] && rm -rf "$TEST_TMP"
}

# MAKEFLAGS/MFLAGS are cleared: this runs under `make test`, and an inherited jobserver flag
# makes the nested make warn on stderr.
#
# --no-print-directory: the harness invokes make with -C (bats runs from tests/), and GNU
# Make 4.x prints "make: Entering/Leaving directory" to STDOUT for -C. Those lines would
# break the eval-safety assertions (a non-export line on stdout) and the eval itself
# (eval would try to run "make: Entering directory ..." as a command). Real users run
# `make dev-env-export` from the repo root, so the targets never see this; it is purely a
# test-harness artifact.
run_make() {
  run env -u MAKEFLAGS -u MFLAGS STUB_LOG="$STUB_LOG" \
    make --no-print-directory -C "$REPO_ROOT" "$@" DEV_TWIN_SCRIPT="$STUB"
}

@test "dev-env-export passes --export through to the script" {
  run_make dev-env-export
  [ "$status" -eq 0 ]
  grep -q '^ARGS=env --export$' "$STUB_LOG"
}

@test "dev-env does NOT pass --export" {
  run_make dev-env
  [ "$status" -eq 0 ]
  grep -q '^ARGS=env$' "$STUB_LOG"
}

@test "dev-env-export stdout is only export lines (recipe is @-silenced)" {
  run_make dev-env-export
  [ "$status" -eq 0 ]
  [ -n "$output" ]
  # An un-silenced recipe would put the command line itself on stdout, and eval would run it.
  run bash -c "printf '%s\n' '$output' | grep -cv '^export '"
  [ "$output" = "0" ]
}

@test "dev-env stdout is only what the script printed (recipe is @-silenced)" {
  run_make dev-env
  [ "$status" -eq 0 ]
  ! [[ "$output" == *"dev-twin-stub.sh"* ]]
}

@test "eval of dev-env-export output runs the script exactly once" {
  run env -u MAKEFLAGS -u MFLAGS STUB_LOG="$STUB_LOG" bash -c "
    eval \"\$(make --no-print-directory -C '$REPO_ROOT' dev-env-export DEV_TWIN_SCRIPT='$STUB')\"
    printf '%s\n' \"\$STUB_SAW_ARGS\"
  "
  [ "$status" -eq 0 ]
  [ "$output" = "env --export" ]
  [ "$(grep -c '^ARGS=' "$STUB_LOG")" -eq 1 ]
}
