# B2-8: APPLY Unit 8 — Test Harness Fixes

| Field | Value |
|-------|-------|
| Agent | code-architect |
| Timestamp | 2026-07-30T00:00:00Z |
| Step | B2-8 |
| Ticket | psc-0003 |
| Target file | mock-server/run-test.sh |

## Unit descriptions

| # | Unit | Description |
|---|------|-------------|
| 1 | CH-TWIN-001 | Precondition verdict routing — `assert_preconditions` sets `FAIL_REASON` + returns instead of calling `die`; moved inside guarded block in `main()` |
| 2 | CH-TWIN-002 | `sidecar-delta` added to `mandatory` array in `validate_summary()` |
| 3 | CH-TWIN-003 | Journal line-number ordering check dropped from `run_reboot_test()`; `After=`/`Requires=` assertions remain as the real evidence |
| 4 | CH-TWIN-004 | Stale-sentinel `rm -f` line removed — sentinels live in `$STAGING`, not `$HOST_EVIDENCE_MOUNT`; `rm -rf "$STAGING"` already handles cleanup |
| 5 | CH-TWIN-005 | Evidence-dir split documented in `usage()` — `--evidence-dir` relocates final copy only; 9p staging path is fixed in Lima template |
| 6 | CH-TWIN-006 | `--fresh`/`--keep` semantics resolved — `--fresh` implies `--destroy`; mutual exclusion enforced; `usage()` updated with multi-line help |
| 7 | CH-TWIN-007 | `HOST_HOME` fallback fixed — uses `${HOME:?}` instead of `$(id -un)`; `wait` empty-PID verified consistent with `wait_driver()` guard |

## Build result

| Check | Result |
|-------|--------|
| shellcheck | PASS — exit 0, zero warnings |
| bash -n | PASS — syntax OK |

## Files changed

| File | Lines changed |
|------|---------------|
| mock-server/run-test.sh | +18 / -17 (net +1, 603 lines total) |

## Detailed changes

### Unit 1: CH-TWIN-001 — Precondition verdict routing

**Before:** `assert_preconditions` called `die` which exits directly with no machine-readable verdict. Called unconditionally before the guarded block in `main()`.

**After:**
- `assert_preconditions` sets `FAIL_REASON` and returns 1 instead of calling `die`
- Moved inside the guarded `if assert_preconditions && make_evidence_dir && ...` chain in `main()`
- On failure, `FAIL_REASON` is set and `print_verdict` emits `TWIN: FAIL: <reason>`

### Unit 2: CH-TWIN-002 — sidecar-delta in mandatory array

**Before:** `sidecar-delta` was not in the `mandatory` array, so the special-case `if [[ "$c" == "sidecar-delta" && "$NO_SIDECAR" == true ]]` at line 502 was dead code.

**After:** `sidecar-delta` added to `mandatory` array. The special case is now live — when `--no-sidecar` is passed, `sidecar-delta` accepts `SKIPPED` or `PASS`; otherwise it requires `PASS`.

### Unit 3: CH-TWIN-003 — Drop journal ordering check

**Before:** `run_reboot_test()` compared `grep -n` line numbers of `podman.socket` vs `floci.service` in the journal, overriding `ordering_result` to `FAIL` if the socket line appeared after the service line. Journal line order is not activation order.

**After:**
- Removed `journal_socket_line` and `journal_service_line` local variables
- Removed the `grep -n` comparison block (lines 425-430)
- Journal is still captured as `reboot-journal.log` for evidence
- Comment added: "ordering is proven by After=/Requires= above"
- The `After=`/`Requires=` property assertions at lines 429-435 remain as the real ordering evidence

### Unit 4: CH-TWIN-004 — Fix stale-sentinel cleanup path

**Before:** `rm -f "${HOST_EVIDENCE_MOUNT}/$SENTINEL_NAME" "${HOST_EVIDENCE_MOUNT}/FAILED"` — sentinels live in `$STAGING`, not `$HOST_EVIDENCE_MOUNT`.

**After:** Removed the redundant `rm -f` line. `rm -rf "$STAGING"` on the previous line already removes all sentinels. `SENTINEL_NAME` is still used in `publish_evidence` to exclude the sentinel from the manifest.

### Unit 5: CH-TWIN-005 — Document evidence-dir split

**Before:** `usage()` had a single-line printf with no explanation of the evidence directory split.

**After:** Added doc comment explaining that `--evidence-dir` relocates the final host copy only; the 9p staging path (`/opt/twin-evidence` in guest) is fixed because it's declared in the Lima template.

### Unit 6: CH-TWIN-006 — Resolve --fresh/--keep semantics

**Before:** `--fresh` set `KEEP=false` but did not set `DESTROY=true`. `--keep` was silently ignored if `--fresh` was already passed. No mutual exclusion.

**After:**
- Added `KEEP_EXPLICIT=false` tracker to distinguish default from explicit `--keep`
- `--fresh` sets `DESTROY=true` and errors if `KEEP_EXPLICIT` is true
- `--keep` sets `KEEP_EXPLICIT=true` and errors if `FRESH` is true
- `usage()` updated with multi-line help showing each flag and the mutual exclusion note
- Per D-22 (challenger win): `--fresh` implies `--destroy`; `--keep` is the default; they are mutually exclusive

### Unit 7: CH-TWIN-007 — Fix robustness gaps

**Before:** `HOST_HOME="${HOME:-$(id -un)}"` — falls back to a username where a path is required.

**After:** `HOST_HOME="${HOME:?HOME is not set — cannot determine host home directory}"` — fails with a clear error if `HOME` is unset.

**wait empty-PID verification:** Both locations are already consistent:
- `wait_driver()` (line 268): guards with `[[ -z "${DRIVER_SHELL_PID:-}" ]]` before calling `wait`
- Failure-path reap (line 593): uses `${DRIVER_SHELL_PID:-}` with `2>/dev/null || true`

## Acceptance criteria coverage

| AC | Status | Evidence |
|----|--------|----------|
| CH-TWIN-001: Precondition failures route through FAIL_REASON + print_verdict | PASS | `assert_preconditions` sets `FAIL_REASON` + returns 1; called inside guarded `if` chain in `main()` |
| CH-TWIN-002: sidecar-delta in mandatory array | PASS | `sidecar-delta` in `mandatory` array; special case at line 516 is live |
| CH-TWIN-003: Journal ordering check dropped | PASS | `grep -n` comparison removed; `After=`/`Requires=` assertions remain |
| CH-TWIN-004: Stale-sentinel cleanup path fixed | PASS | Redundant `rm -f` targeting wrong path removed |
| CH-TWIN-005: Evidence-dir split documented | PASS | Doc comment added to `usage()` |
| CH-TWIN-006: --fresh/--keep semantics resolved | PASS | Mutual exclusion enforced; `--fresh` implies `--destroy`; `usage()` updated |
| CH-TWIN-007: Robustness gaps fixed | PASS | `HOST_HOME` uses `${HOME:?}`; `wait` empty-PID verified consistent |
| Build: shellcheck exit 0, zero warnings | PASS | `shellcheck mock-server/run-test.sh` exit 0, no output |
| Build: bash -n syntax check | PASS | `bash -n mock-server/run-test.sh` exit 0 |
