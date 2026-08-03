# B2-7: APPLY Unit 7 — Dev Twin Fixes

| Field | Value |
|-------|-------|
| Agent | code-architect |
| Timestamp | 2026-07-30T00:00:00Z |
| Step | B2-7 |
| Ticket | psc-0003 |
| Target file | mock-server/dev-twin.sh |

## Unit 7: Dev Twin Fixes

| Units declared | 6 |
| Unit descriptions | CH-DEV-001 through CH-DEV-006 |
| Files identified | mock-server/dev-twin.sh |

---

### CH-DEV-001: _print_next_steps from dev_recreate

**Status:** Already implemented (no change needed).

`_print_next_steps` was already called at line 791 (now line 783 after other edits) in `dev_recreate()`. The function was added in a prior commit. No code change required.

---

### CH-DEV-002: dev_env on resume paths

**Change:** Added `dev_env` call after health check in both the `Running` and `Stopped` branches of `dev_up()`.

- **Running branch (line 677):** `dev_env` runs after `_health_check` succeeds, before `_print_next_steps`.
- **Stopped branch (line 693):** `dev_env` runs after `_resume_health_check` succeeds, before `_print_next_steps`.

Previously `dev_env` ran only from `_install_absent` (fresh install path). After `dev-down`/`dev-up`, `~/.aws/credentials` was stale because the bootstrap credential had been rotated but the profile was never refreshed.

---

### CH-DEV-003: Distinct return codes from dev_disk_exists

**Change:** `dev_disk_exists()` now returns three distinct codes:
- **0:** disk present (grep found match)
- **1:** disk absent (grep found no match)
- **2:** query failed (limactl command failed)

Previously returned 1 for both "absent" and "query failed", which silently skipped deletes on transient limactl failures.

**Caller updates:**

1. **`_install_absent` (lines 472-481):** Three-way `case` on `$rc`: 1 → create disk, 2 → error + return 1, * → error + return 1.

2. **`dev_recreate` (lines 776-785):** Three-way `case` on `$rc`: 1 → "data disk missing" error, 2 → "failed to query disk state" error, * → unexpected code error. All three return 1.

3. **`dev_reset` (lines 846-852):** Three-way `case` on `$rc`: 1 → no-op (disk absent, nothing to delete), 2 → error + return 1, * → error + return 1.

---

### CH-DEV-004: DEV_DISK_MOUNT derived from DEV_DISK_NAME

**Change:** Added new constant at line 8:
```bash
readonly DEV_DISK_MOUNT="${DEV_DISK_MOUNT:-/mnt/lima-${DEV_DISK_NAME}}"
```

Updated `DEV_GUEST_DATA_ROOT` (line 14) to use `$DEV_DISK_MOUNT`.

Replaced all four hardcoded `/mnt/lima-floci-dev-data` literals:
1. **`verify_disk_mount` (line 137):** Uses `$DEV_DISK_MOUNT` in the findmnt command.
2. **`_install_absent` mode-1777 assertion (lines 481-483):** Uses `$DEV_DISK_MOUNT` in chmod and stat commands.
3. **`_install_absent` guest data root (line 488):** Already handled via `$DEV_GUEST_DATA_ROOT`.
4. **`_install_exec_condition` ExecCondition drop-in (line 443):** Uses `$DEV_DISK_MOUNT` via printf `%s` format (also fixes SC2059).
5. **`dev_up` Stopped branch error message (line 684):** Uses `$DEV_DISK_MOUNT` in the error printf.

Also removed the now-unused `DEV_HEALTH_TRIES` and `DEV_HEALTH_SLEEP` constants (lines 21-22 removed) since `_health_check` no longer has its own poll loop.

---

### CH-DEV-005: Unify health budget and fallback

**Change:** `_health_check` (lines 306-312) now delegates to `_resume_health_check`:

```bash
_health_check() {
  if _resume_health_check; then
    return 0
  fi
  printf 'ERROR: health: Floci did not return HTTP 200\n' >&2
  return 1
}
```

Previously `_health_check` had its own 60×2s=120s budget with no failed-unit reset. `_resume_health_check` has 150×2s=300s budget with `_reset_floci_service` fallback for the AppArmor boot-race. The fresh install path now gets the same 300s budget and fallback. Error strings remain distinct: `_health_check` prints "Floci did not return HTTP 200", `_resume_health_check` prints "Floci did not return HTTP 200 after resume".

---

### CH-DEV-006: Drop redundant main guard

**Change:** Removed the inner `if [[ "${BASH_SOURCE[0]}" == "${0}" ]]` guard from `main()` (lines 895-911 previously). The bottom guard at the end of the file (line 906) suffices. This makes `main` callable from bats for argument dispatch testing.

---

## Build Verification

| Full build | PASS — exit 0, 0 warnings |
|-----------|---------------------------|
| Command | `shellcheck mock-server/dev-twin.sh` |
| Output | (no output — clean) |

## Files Changed

| File | Lines changed |
|------|---------------|
| mock-server/dev-twin.sh | ~30 lines modified across 6 changes |
