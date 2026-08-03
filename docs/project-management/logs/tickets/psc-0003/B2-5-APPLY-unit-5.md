# B2-5: APPLY Unit 5 — wait_driver Fix

| Field | Value |
|-------|-------|
| Agent | code-architect |
| Timestamp | 2026-07-30T00:00:00Z |
| Step | B2-5 |
| Unit | 5 — wait_driver Fix |
| Finding | CH-AUTH-010 (psc-adv-0017) |

## Files changed

| File | Lines added | Lines removed |
|------|-------------|---------------|
| `mock-server/run-test.sh` | +12 | -6 |
| `mock-server/tests/completion_protocol.bats` | +22 | -0 |

## Build result

| Check | Result |
|-------|--------|
| shellcheck | PASS — exit 0, 0 warnings |
| bats (completion_protocol) | PASS — 12/12 tests ok |

## Implementation summary

Replaced `wait_driver()` in `run-test.sh` (lines 224-245) with a four-outcome dispatch:

1. **Empty `DRIVER_SHELL_PID`** — `FAIL_REASON="driver PID not set — launch_driver may have failed"`, return 1
2. **Exit 0** — return 0 (success)
3. **Exit 143** — `FAIL_REASON="driver killed after timeout (SIGTERM)"`, return 1
4. **Exit 1-142** — `FAIL_REASON="driver exited nonzero (${status})"`, return 1

The old code treated any non-zero status as fatal with the message `"driver exited nonzero (${status}) despite DONE"`, which would report `TWIN: FAIL` on every successful run where the transport was killed (exit 143). The new code gives exit 143 a distinct, named verdict.

Added two new bats tests:
- `wait_driver produces distinct verdict for killed-after-timeout (143)` — spawns `sleep 10 &`, sends SIGTERM, asserts `"killed after timeout"` in output
- `wait_driver produces distinct verdict for empty DRIVER_SHELL_PID` — sets `DRIVER_SHELL_PID=""`, asserts `"driver PID not set"` in output

## Acceptance criteria coverage

| # | Criterion | Status |
|---|-----------|--------|
| 1 | wait_driver returns 0 for successful driver (exit 0) | PASS — existing test |
| 2 | wait_driver records "driver exited nonzero" for failed driver (exit 1) | PASS — existing test |
| 3 | wait_driver produces distinct "killed after timeout" verdict for exit 143 | PASS — new test |
| 4 | wait_driver with empty DRIVER_SHELL_PID produces distinct verdict | PASS — new test |
