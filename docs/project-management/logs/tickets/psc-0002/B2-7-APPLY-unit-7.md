# B2-7: APPLY Unit 7 — psc-0002

| Field | Value |
|-------|-------|
| Agent | code-architect |
| Timestamp | 2026-07-30T15:30:00Z |
| Step | B2-7 |
| Unit | 7 — §6.10 code block update (BS-007) |
| Build result | PASS — bash -n on extracted launch_driver function |

## Changes

### §6.10 — launch_driver code block (SPEC-BS-007)
Added the `launch_driver` function with fixed `driver_args` expansion to §6.10, after the s3-smoke example.

**Before:** The auth plan did not show the `launch_driver` function body.

**After:** Added the complete function using `printf '%q ' "${driver_args[@]}"` for safe argument quoting:
```bash
launch_driver() {
  local -a driver_args=()
  if [[ "$NO_SIDECAR" == true ]]; then
    driver_args+=(--no-sidecar)
  fi
  if [[ -n "${AUTH_MODE:-}" ]]; then
    driver_args+=(--auth-mode="$AUTH_MODE")
  fi
  (
    local driver_args_quoted
    driver_args_quoted="$(printf '%q ' "${driver_args[@]}")"
    limactl shell "$TWIN_NAME" -- bash -c \
      "sudo systemd-run --quiet --wait --unit=tianlu-driver -- /opt/tianlu/mock-server/in-vm/run-in-vm.sh ${driver_args_quoted}" 2>/dev/null
  ) &
  DRIVER_SHELL_PID=$!
}
```

Added explanatory text about why `printf '%q '` is used instead of `${driver_args[*]}`.

## Acceptance criteria

- [x] No `${driver_args[*]}` expansion in code block
- [x] Uses `printf '%q ' "${driver_args[@]}"` for safe argument quoting
- [x] `${arr[@]+...}` guard removed (not needed with `printf '%q '` on empty array)
- [x] `DRIVER_SHELL_PID=$!` present after background subshell
