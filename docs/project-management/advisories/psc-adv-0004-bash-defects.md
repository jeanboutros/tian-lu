# Advisory: Bash Defects Across All Scripts

| Field | Value |
|-------|-------|
| ID | psc-adv-0004-bash-defects |
| Type | advisory |
| Status | awaiting user decision |
| Confidence | 85 |
| Priority | critical |
| Source ticket | psc-adv-0001 |
| Source agent | BS |
| Source file | [A2-dual-model-challenge.md](docs/project-management/logs/tickets/psc-adv-0001/A2-dual-model-challenge.md) |
| Created | 2026-07-30 |

## Description
Systematic bash defects across all three scripts (`setup-floci.sh`, `dev-twin.sh`, `run-test.sh`) that create silent-failure classes, argument boundary loss, and resource leaks.

**Consolidated findings:**

1. **F-BS-001 (conf 85) — `$*` argument boundary loss in `_run_as_floci_guest`**: Using `"$*"` collapses all arguments into a single string, breaking commands with spaces or quoted arguments. Must use `printf '%q ' "$@"` expansion.

2. **M-BS-001 (conf 85) — Missing `set -o errtrace` (prerequisite for ERR traps)**: No script has `set -o errtrace` / `set -E`. Without `errtrace`, an ERR trap only fires in top-level scope, not inside functions — defeating F-BS-008's stack backtrace fix for a 1020-line function-structured installer. **Prerequisite for F-BS-008.**

3. **M-BS-003 (conf 80) — `local var="$(cmd)"` masks `errexit`**: Bash's `local` returns 0 even when `cmd` fails, so `set -e` does not fire. This appears in safety-critical paths (uid construction for `XDG_RUNTIME_DIR`/`DBUS_SESSION_BUS_ADDRESS`). Must split into `local var; var="$(cmd)"` + explicit `rc` check.

4. **F-BS-002 (conf 80) — Missing trap cleanup in `setup-floci.sh`**: Temp files (AppArmor profile `.tmp.$$`) not cleaned on exit/INT/TERM. Challenger refined (D-BS-004): `$$` in trap only cleans current run's temp files; orphaned files from crashed prior runs persist. Fix: global `TEMP_FILES=()` array + trap iterates and `rm -f`.

5. **F-BS-003 (conf 80) — Missing trap cleanup in `dev-twin.sh`**: Same pattern as F-BS-002.

6. **M-BS-002 (conf 82) — Orphaned `systemd-run` unit + `limactl shell` on SIGINT in `run-test.sh`**: Guest-side `tianlu-driver.service` transient unit keeps running inside Lima VM after host SIGINT. Partial evidence without manifest seal is a test-harness *correctness* issue.

7. **F-BS-005 (conf 75) — `sort -V` GNU dependency**: `sort -V` (version sort) is GNU-specific; not portable to BSD `sort`. Use `sort -V` only if `sort --version` shows GNU, or use alternative.

8. **F-BS-007 (conf 70) — `driver_args[*]` expansion issues**: Array expansion without proper quoting can lose empty elements and split incorrectly.

9. **F-BS-008 (conf 70→75) — Missing ERR trap / stack backtrace**: No ERR trap with stack trace for debugging. Requires `errtrace` (M-BS-001) first.

10. **F-BS-011 (conf 65) — `_install_exec_condition` error suppression**: Error suppression masks failures that should be visible.

11. **D-BS-004 (conf 60) — Trap fix incomplete for idempotent restart**: As noted in F-BS-002 challenger refinement, `$$` only cleans current run's temp files.

## Recommended Action
1. Add `set -o errtrace` at top of all three scripts (prerequisite for ERR traps).
2. Replace `"$*"` with `printf '%q ' "$@"` in `_run_as_floci_guest`.
3. Audit all `local x="$(cmd)"` patterns across three scripts; split into `local x; x="$(cmd)"; rc=$?; [ $rc -eq 0 ] || return $rc`.
4. Implement global `TEMP_FILES=()` array pattern in all three scripts; `TEMP_FILES+=("$tmp")` after each temp file creation; trap iterates and `rm -f`.
5. Add signal trap in `run-test.sh` to kill guest `systemd-run` unit and clean evidence on SIGINT.
6. Replace `sort -V` with portable alternative or guard with GNU check.
7. Fix `driver_args[*]` expansion with proper quoting: `"${driver_args[@]}"`.
8. Add ERR trap with stack backtrace (after errtrace is set).
9. Remove error suppression in `_install_exec_condition`; let errors surface.

## User Decision
all okay. I cannot be the judge on bash advanced techniques, so I will defer to the team. I will approve the implementation ticket if the team agrees with the recommended action. The team is the agents that you should spin as a team for consensus and best practices. I auto approve the implementation ticket if the team agrees with the recommended action.

## Decision Rationale

## Implementation Ticket