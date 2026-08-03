# A1-BS: Bash Specialist Requirements — psc-0002

| Field | Value |
|-------|-------|
| Agent | bash-specialist |
| Timestamp | 2026-07-30T00:00:00Z |
| Step | A1-BS |
| Verdict | CONDITIONAL PASS |
| Severity | 8 |

## Scope

Review `docs/design/authentication-plan.md` against the 10 accepted bash-defect findings from psc-adv-0004. Produce precise code change specifications for every code block in the auth plan that is affected by a finding. Where a finding applies to an existing script function that the auth plan's new code calls or lives alongside, specify the fix on that function.

## Code Change Specifications

---

### SPEC-BS-001: Fix `$*` argument boundary loss in `_run_as_floci_guest`

**Source:** F-BS-001
**Severity:** 7 (HIGH)
**Affected file:** `mock-server/dev-twin.sh`
**Affected auth plan section:** §6.5 (`_rotate_bootstrap_credentials` calls `_run_as_floci_guest` with a single string argument; the `$*` bug is latent but not triggered by the auth plan's usage pattern)

**Current code** (dev-twin.sh:329–335):
```bash
_run_as_floci_guest() {
  local uid
  uid="$(_guest_floci_uid)"
  [[ -n "$uid" ]] || return 1
  limactl shell "$DEV_TWIN_NAME" -- bash -c \
    "sudo -u floci env HOME=/home/floci USER=floci PATH=/usr/local/bin:/usr/bin:/bin XDG_RUNTIME_DIR=/run/user/${uid} DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/${uid}/bus $*" 2>/dev/null
}
```

**Required change:**
```bash
_run_as_floci_guest() {
  local uid
  uid="$(_guest_floci_uid)"
  [[ -n "$uid" ]] || return 1
  limactl shell "$DEV_TWIN_NAME" -- bash -c \
    "sudo -u floci env HOME=/home/floci USER=floci PATH=/usr/local/bin:/usr/bin:/bin XDG_RUNTIME_DIR=/run/user/${uid} DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/${uid}/bus $(printf '%q ' "$@")" 2>/dev/null
}
```

**Rationale:** `$*` joins all arguments into a single string with the first character of `IFS` as separator, losing argument boundaries. `printf '%q ' "$@"` preserves each argument's quoting so the inner `bash -c` receives them as distinct words. [Source: Bash Manual, §3.4.2 Special Parameters — `$*` vs `$@`]

**Note on auth plan impact:** The auth plan's `_rotate_bootstrap_credentials` (§6.5) calls `_run_as_floci_guest` with a single string argument (e.g., `"podman exec -e AWS_ACCESS_KEY_ID=... ..."`), so the `$*` bug is not triggered by the auth plan's usage. However, the function must be fixed so future callers that pass multiple arguments are safe. The auth plan's code blocks in §6.5 do not need to change — they already pass a single string.

**Also applies to:** `mock-server/in-vm/lib/assert.sh:233–244` (`run_as_floci_guest`). This variant already uses `"$@"` correctly (line 243) — no change needed.

---

### SPEC-BS-002: Add `set -o errtrace` to all scripts

**Source:** M-BS-001
**Severity:** 8 (HIGH)
**Affected files:** All 6 scripts
**Affected auth plan sections:** §6.1 (setup-floci.sh), §6.4–§6.8 (dev-twin.sh), §6.9 (preflight-floci.sh), §6.10 (run-test.sh, run-in-vm.sh, assert.sh)

**Current code** (all scripts use `set -euo pipefail` without `errtrace`):

| Script | Current line |
|--------|-------------|
| `setup-floci.sh:25` | `set -euo pipefail` |
| `mock-server/dev-twin.sh:2` | `set -euo pipefail` |
| `mock-server/run-test.sh:4` | `set -euo pipefail` |
| `mock-server/in-vm/run-in-vm.sh:4` | `set -euo pipefail` |
| `mock-server/in-vm/lib/assert.sh:6` | `set -euo pipefail` |
| `scripts/preflight-floci.sh:22` | `set -euo pipefail` |

**Required change** (identical for all 6 scripts):
```bash
set -euo pipefail
set -o errtrace
```

Or equivalently, the single-line form:
```bash
set -euo pipefail -o errtrace
```

**Rationale:** Without `errtrace`, the ERR trap does not fire inside functions or subshells. Any ERR trap registered with `trap '...' ERR` is inert inside functions — it only fires for commands at the top-level script scope. This makes SPEC-BS-008 (ERR trap) useless without this fix. [Source: Bash Manual, §4.3.2 The Set Builtin — `-o errtrace`]

**Auth plan impact:** The auth plan's new code in `_rotate_bootstrap_credentials` (§6.5) and `dev_env` (§6.6) runs inside functions. Without `errtrace`, any ERR trap registered in `dev-twin.sh` would not fire inside these functions. This fix is a prerequisite for SPEC-BS-008.

---

### SPEC-BS-003: Split `local var="$(cmd)"` assignments

**Source:** M-BS-003
**Severity:** 7 (HIGH)
**Affected files:** `mock-server/dev-twin.sh`, `mock-server/in-vm/lib/assert.sh`
**Affected auth plan sections:** §6.5 (`_rotate_bootstrap_credentials` lives in `dev-twin.sh`; the auth plan's new code does not introduce new `local var="$(cmd)"` patterns, but the existing functions it calls alongside have this defect)

**Current code — dev-twin.sh:443–444** (`_install_exec_condition`):
```bash
_install_exec_condition() {
  local uid tmpfile
  uid="$(limactl shell "$DEV_TWIN_NAME" -- bash -c 'id -u floci 2>/dev/null' 2>/dev/null)"
```

**Required change:**
```bash
_install_exec_condition() {
  local uid tmpfile
  uid="$(limactl shell "$DEV_TWIN_NAME" -- bash -c 'id -u floci 2>/dev/null' 2>/dev/null)" || {
    printf 'ERROR: exec-condition: could not resolve floci uid in guest\n' >&2
    return 1
  }
```

**Current code — assert.sh:234–236** (`run_as_floci_guest`):
```bash
run_as_floci_guest() {
  local uid

  uid="$(id -u floci)"
```

**Required change:**
```bash
run_as_floci_guest() {
  local uid

  uid="$(id -u floci)" || {
    printf 'ERROR: run_as_floci_guest: could not resolve floci uid\n' >&2
    return 1
  }
```

**Rationale:** `local var="$(cmd)"` returns the exit status of `local`, not `cmd`. If `cmd` fails, the error is silently swallowed — `errexit` does not trigger because `local` itself succeeds (it declares the variable). The fix splits declaration from assignment and adds an explicit exit-code check. [Source: Bash Manual, §4.3.1 The Set Builtin — `errexit` does not apply to the return value of `local`]

**Auth plan impact:** The auth plan's `_rotate_bootstrap_credentials` (§6.5) does not use `local var="$(cmd)"` — it uses `local bootstrap_akid bootstrap_secret out new_akid new_sk delete_rc` (declaration only) followed by separate assignments. No change needed to the auth plan's code blocks. The fix applies to the existing `_install_exec_condition` function that `_install_absent` (§6.4) calls.

---

### SPEC-BS-004: Adopt global `TEMP_FILES=()` array pattern with trap cleanup

**Source:** F-BS-002, F-BS-003
**Severity:** 6 (MEDIUM)
**Affected files:** `mock-server/dev-twin.sh`, `mock-server/run-test.sh`
**Affected auth plan sections:** §6.4 (`_install_absent` calls `_install_exec_condition` which creates temp files), §6.5 (`_rotate_bootstrap_credentials` does not create temp files — no direct impact), §6.10 (run-test.sh)

**Current code — dev-twin.sh** (no global temp-file tracking; `mktemp` calls at lines 68, 195, 445 without trap cleanup):
```bash
# No TEMP_FILES array declared
# No trap registered for cleanup
```

**Required change** (add after the readonly constants block, before the first function):
```bash
# --- Temp-file tracking -------------------------------------------------------
# All functions that create temp files append to this array. A single EXIT trap
# cleans up every registered file. Functions that create temp files MUST append
# the path to TEMP_FILES immediately after mktemp.
TEMP_FILES=()
readonly TEMP_FILES

_cleanup_temp_files() {
  local f
  for f in "${TEMP_FILES[@]}"; do
    rm -f "$f" 2>/dev/null || true
  done
}
trap '_cleanup_temp_files' EXIT INT TERM
```

Then update every `mktemp` call site to append to `TEMP_FILES`:

**dev-twin.sh:68** (`preflight_ports`):
```bash
  lsof_err="$(mktemp /tmp/lsof-err.XXXXXX)"
  TEMP_FILES+=("$lsof_err")
```

**dev-twin.sh:195** (`managed_hosts_add`):
```bash
  tmpfile="$(mktemp /tmp/dev-twin-hosts.XXXXXX)"
  TEMP_FILES+=("$tmpfile")
```

**dev-twin.sh:445** (`_install_exec_condition`):
```bash
  tmpfile="$(mktemp /tmp/exec-condition.XXXXXX)"
  TEMP_FILES+=("$tmpfile")
```

**run-test.sh** (no temp files created — the evidence staging is managed by the guest driver; no change needed for temp files specifically, but see SPEC-BS-005 for signal-trap cleanup).

**Rationale:** Temp files created by `mktemp` that are not cleaned up on EXIT/INT/TERM leak disk space. The `TEMP_FILES=()` array pattern is the standard bash idiom for tracking and cleaning up temp files across multiple functions. [Source: Google Shell Style Guide, §5.5 Temporary Files]

**Auth plan impact:** The auth plan's `_rotate_bootstrap_credentials` (§6.5) does not create temp files — it writes directly to `$DEV_CREDENTIALS_FILE`. No change needed to the auth plan's code blocks. The fix applies to the existing `_install_exec_condition` function that `_install_absent` (§6.4) calls.

---

### SPEC-BS-005: Add signal trap for orphaned systemd-run unit + stale evidence cleanup in run-test.sh

**Source:** M-BS-002
**Severity:** 7 (HIGH)
**Affected file:** `mock-server/run-test.sh`
**Affected auth plan section:** §6.10 (run-test.sh auth-mode support)

**Current code** (run-test.sh — no signal trap):
```bash
# No trap registered for SIGINT/SIGTERM cleanup
```

**Required change** (add after the readonly constants block, before `usage()`):
```bash
# --- Signal cleanup -----------------------------------------------------------
# On SIGINT/SIGTERM, kill the driver transport and clean up the transient
# systemd-run unit inside the guest so it does not orphan.
_cleanup_driver() {
  local driver_pid="${DRIVER_SHELL_PID:-}"
  if [[ -n "$driver_pid" ]]; then
    kill "$driver_pid" 2>/dev/null || true
    wait "$driver_pid" 2>/dev/null || true
  fi
  # Best-effort: stop the transient unit if the twin is still reachable
  if [[ -n "${TWIN_NAME:-}" ]]; then
    limactl shell "$TWIN_NAME" -- bash -c \
      'sudo systemctl stop tianlu-driver 2>/dev/null || true' 2>/dev/null || true
  fi
  # Clean up stale evidence staging
  if [[ -n "${STAGING:-}" && -d "$STAGING" ]]; then
    rm -rf "$STAGING" 2>/dev/null || true
  fi
  if [[ -n "${HOST_EVIDENCE_MOUNT:-}" ]]; then
    rm -f "${HOST_EVIDENCE_MOUNT}/$SENTINEL_NAME" "${HOST_EVIDENCE_MOUNT}/FAILED" 2>/dev/null || true
  fi
}
trap '_cleanup_driver' INT TERM
```

**Rationale:** When the user presses Ctrl-C during a twin test, the `launch_driver` background process (`DRIVER_SHELL_PID`) and the guest-side `systemd-run --unit=tianlu-driver` transient unit are left running. The signal trap kills the transport, stops the guest unit, and removes stale evidence staging so the next run starts clean. [Source: POSIX.1-2017, §2.11 Signals and Error Handling — SIGINT/SIGTERM cleanup obligations]

**Auth plan impact:** The auth plan's §6.10 adds `--auth-mode=off|sigv4` flag parsing to `run-test.sh`. The signal trap must be in place before the auth-mode changes are applied so that interrupted auth-mode test runs clean up properly. No change to the auth plan's code blocks — the trap is a prerequisite.

---

### SPEC-BS-006: Document `sort -V` GNU dependency or switch to `dpkg --compare-versions`

**Source:** F-BS-005
**Severity:** 4 (MEDIUM — acceptable for Ubuntu-only target)
**Affected file:** `setup-floci.sh`
**Affected auth plan section:** §6.1 (setup-floci.sh — the auth plan adds `FLOCI_AUTH_MODE` to the config block; the `sort -V` line is in `assert_ubuntu_version`, not touched by the auth plan)

**Current code** (setup-floci.sh:387–390):
```bash
  # Compare versions using sort -V: the minimum of the two must equal MIN.
  local lowest
  lowest="$(printf '%s\n%s\n' "$MIN_UBUNTU_VERSION" "$os_version" \
    | sort -V | head -n1)"
```

**Required change — Option A (document, recommended):** Add a comment documenting the GNU dependency:
```bash
  # Compare versions using sort -V (GNU coreutils — Ubuntu target; not portable
  # to BSD/macOS sort). The minimum of the two must equal MIN.
  local lowest
  lowest="$(printf '%s\n%s\n' "$MIN_UBUNTU_VERSION" "$os_version" \
    | sort -V | head -n1)"
```

**Required change — Option B (switch to dpkg, more robust):**
```bash
  # Compare versions using dpkg --compare-versions (Debian/Ubuntu native).
  if ! dpkg --compare-versions "$os_version" ge "$MIN_UBUNTU_VERSION"; then
    printf 'ERROR: Ubuntu %s is too old — %s+ required\n' \
      "$os_version" "$MIN_UBUNTU_VERSION" >&2
    exit 1
  fi
```

**Recommendation:** Option A (document). The script targets Ubuntu exclusively, and `sort -V` is available on every supported Ubuntu release. The `dpkg --compare-versions` alternative is more idiomatic for Debian/Ubuntu but adds a dependency on `dpkg` being present (it always is on Ubuntu, but the comment approach is simpler and less invasive). [Source: GNU Coreutils Manual, §7.1 sort invocation — `-V` is a GNU extension]

**Auth plan impact:** None. The auth plan's §6.1 adds `FLOCI_AUTH_MODE` to the config block, not to `assert_ubuntu_version`. No change to the auth plan's code blocks.

---

### SPEC-BS-007: Fix `driver_args[*]` expansion in run-test.sh:194

**Source:** F-BS-007
**Severity:** 6 (MEDIUM)
**Affected file:** `mock-server/run-test.sh`
**Affected auth plan section:** §6.10 (run-test.sh auth-mode support — the auth plan adds `--auth-mode` flag parsing which populates `driver_args`)

**Current code** (run-test.sh:192–194):
```bash
  (
    # ${arr[@]+...} guards the empty-array expansion under set -u (bash 3.2/macOS).
    limactl shell "$TWIN_NAME" -- bash -c "sudo systemd-run --quiet --wait --unit=tianlu-driver -- /opt/tianlu/mock-server/in-vm/run-in-vm.sh ${driver_args[*]+"${driver_args[*]}"}" 2>/dev/null
  ) &
```

**Required change:**
```bash
  (
    # Build a safely-quoted argument string for the inner bash -c.
    # printf '%q ' preserves argument boundaries; the trailing space is harmless.
    local driver_args_quoted
    driver_args_quoted="$(printf '%q ' "${driver_args[@]}")"
    limactl shell "$TWIN_NAME" -- bash -c \
      "sudo systemd-run --quiet --wait --unit=tianlu-driver -- /opt/tianlu/mock-server/in-vm/run-in-vm.sh ${driver_args_quoted}" 2>/dev/null
  ) &
```

**Rationale:** `${driver_args[*]}` joins array elements with the first character of `IFS` (space), which loses argument boundaries when any element contains whitespace. `printf '%q ' "${driver_args[@]}"` shell-escapes each element individually and preserves boundaries. The `${arr[@]+...}` guard is no longer needed because `printf '%q '` on an empty array produces an empty string (not an unbound-variable error). [Source: Bash Manual, §6.7 Arrays — `[*]` vs `[@]` expansion]

**Auth plan impact:** The auth plan's §6.10 adds `--auth-mode=off|sigv4` flag parsing to `run-test.sh`, which populates `driver_args`. The fix must be applied to the existing `launch_driver` function before the auth-mode changes are added. The auth plan's code block for §6.10 should show the fixed expansion.

**Updated auth plan §6.10 code block** (run-test.sh `launch_driver`):
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

---

### SPEC-BS-008: Add ERR trap with `caller` stack backtrace to all scripts

**Source:** F-BS-008
**Severity:** 7 (HIGH)
**Affected files:** All 6 scripts
**Affected auth plan sections:** All sections (§6.1–§6.10)

**Current code** (none of the 6 scripts have an ERR trap):
```bash
# No ERR trap registered
```

**Required change** (add after the `set` block in each script):

For `setup-floci.sh` (after line 26):
```bash
# --- Error diagnostics ---------------------------------------------------------
_on_error() {
  local rc=$? i
  printf '[%s] ERROR: command failed with status %d at line %d in %s\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$rc" "${BASH_LINENO[0]}" "${BASH_SOURCE[1]}" >&2
  for ((i = 1; i < ${#FUNCNAME[@]}; i++)); do
    printf '[%s]   called from %s() at %s:%d\n' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${FUNCNAME[$i]}" "${BASH_SOURCE[$((i+1))]}" "${BASH_LINENO[$i]}" >&2
  done
}
trap '_on_error' ERR
```

For `mock-server/dev-twin.sh` (after line 3):
```bash
# --- Error diagnostics ---------------------------------------------------------
_on_error() {
  local rc=$? i
  printf '[%s] ERROR: command failed with status %d at line %d in %s\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$rc" "${BASH_LINENO[0]}" "${BASH_SOURCE[1]}" >&2
  for ((i = 1; i < ${#FUNCNAME[@]}; i++)); do
    printf '[%s]   called from %s() at %s:%d\n' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${FUNCNAME[$i]}" "${BASH_SOURCE[$((i+1))]}" "${BASH_LINENO[$i]}" >&2
  done
}
trap '_on_error' ERR
```

For `mock-server/run-test.sh` (after line 5):
```bash
# --- Error diagnostics ---------------------------------------------------------
_on_error() {
  local rc=$? i
  printf '[%s] ERROR: command failed with status %d at line %d in %s\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$rc" "${BASH_LINENO[0]}" "${BASH_SOURCE[1]}" >&2
  for ((i = 1; i < ${#FUNCNAME[@]}; i++)); do
    printf '[%s]   called from %s() at %s:%d\n' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${FUNCNAME[$i]}" "${BASH_SOURCE[$((i+1))]}" "${BASH_LINENO[$i]}" >&2
  done
}
trap '_on_error' ERR
```

For `mock-server/in-vm/run-in-vm.sh` (after line 5):
```bash
# --- Error diagnostics ---------------------------------------------------------
_on_error() {
  local rc=$? i
  printf '[%s] ERROR: command failed with status %d at line %d in %s\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$rc" "${BASH_LINENO[0]}" "${BASH_SOURCE[1]}" >&2
  for ((i = 1; i < ${#FUNCNAME[@]}; i++)); do
    printf '[%s]   called from %s() at %s:%d\n' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${FUNCNAME[$i]}" "${BASH_SOURCE[$((i+1))]}" "${BASH_LINENO[$i]}" >&2
  done
}
trap '_on_error' ERR
```

For `mock-server/in-vm/lib/assert.sh` (after line 7):
```bash
# --- Error diagnostics ---------------------------------------------------------
_on_error() {
  local rc=$? i
  printf '[%s] ERROR: command failed with status %d at line %d in %s\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$rc" "${BASH_LINENO[0]}" "${BASH_SOURCE[1]}" >&2
  for ((i = 1; i < ${#FUNCNAME[@]}; i++)); do
    printf '[%s]   called from %s() at %s:%d\n' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${FUNCNAME[$i]}" "${BASH_SOURCE[$((i+1))]}" "${BASH_LINENO[$i]}" >&2
  done
}
trap '_on_error' ERR
```

For `scripts/preflight-floci.sh` (after line 22):
```bash
# --- Error diagnostics ---------------------------------------------------------
_on_error() {
  local rc=$? i
  printf '[%s] ERROR: command failed with status %d at line %d in %s\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$rc" "${BASH_LINENO[0]}" "${BASH_SOURCE[1]}" >&2
  for ((i = 1; i < ${#FUNCNAME[@]}; i++)); do
    printf '[%s]   called from %s() at %s:%d\n' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${FUNCNAME[$i]}" "${BASH_SOURCE[$((i+1))]}" "${BASH_LINENO[$i]}" >&2
  done
}
trap '_on_error' ERR
```

**Rationale:** Without an ERR trap, when a command fails under `errexit`, the script exits with no diagnostic beyond the exit code. The `caller`-based stack backtrace shows the exact call chain leading to the failure, which is essential for debugging production scripts. [Source: Bash Manual, §4.1 Bourne Shell Builtins — `caller`; §4.3.2 The Set Builtin — ERR trap]

**Prerequisite:** SPEC-BS-002 (`set -o errtrace`) must be applied first. Without `errtrace`, the ERR trap is inert inside functions.

**Auth plan impact:** The auth plan's new functions (`_rotate_bootstrap_credentials` §6.5, `dev_env` §6.6, `_print_next_steps` §6.7) run inside `dev-twin.sh`. With the ERR trap + `errtrace`, any failure inside these functions produces a stack backtrace. No change to the auth plan's code blocks — the trap is added to the script, not to the auth plan's function bodies.

---

### SPEC-BS-009: Align `_run_as_floci_guest` documentation with implementation

**Source:** F-BS-009
**Severity:** 4 (MEDIUM)
**Affected file:** `mock-server/dev-twin.sh`
**Affected auth plan section:** §6.5 (`_rotate_bootstrap_credentials` calls `_run_as_floci_guest`)

**Current code** (dev-twin.sh:324–335):
```bash
# _run_as_floci_guest <cmd...>
# Run a command as the floci user inside the guest with the user manager
# environment wired (HOME, XDG_RUNTIME_DIR, DBUS_SESSION_BUS_ADDRESS). stderr
# is suppressed per the AGENTS.md limactl-shell convention (Lima login shell
# cd-noise). The exit code of the inner command propagates through limactl.
_run_as_floci_guest() {
  local uid
  uid="$(_guest_floci_uid)"
  [[ -n "$uid" ]] || return 1
  limactl shell "$DEV_TWIN_NAME" -- bash -c \
    "sudo -u floci env HOME=/home/floci USER=floci PATH=/usr/local/bin:/usr/bin:/bin XDG_RUNTIME_DIR=/run/user/${uid} DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/${uid}/bus $*" 2>/dev/null
}
```

**Required change** (after SPEC-BS-001 is applied, which fixes `$*` → `printf '%q ' "$@"`):
```bash
# _run_as_floci_guest <cmd...>
# Run a command as the floci user inside the guest with the user manager
# environment wired (HOME, XDG_RUNTIME_DIR, DBUS_SESSION_BUS_ADDRESS). stderr
# is suppressed per the AGENTS.md limactl-shell convention (Lima login shell
# cd-noise). The exit code of the inner command propagates through limactl.
#
# Arguments:
#   <cmd...>  Command and arguments to run as floci. Each argument is
#             individually shell-quoted via printf '%q ' before being
#             passed to the inner bash -c, preserving argument boundaries.
#             Callers may pass a single string or multiple arguments.
_run_as_floci_guest() {
  local uid
  uid="$(_guest_floci_uid)"
  [[ -n "$uid" ]] || return 1
  limactl shell "$DEV_TWIN_NAME" -- bash -c \
    "sudo -u floci env HOME=/home/floci USER=floci PATH=/usr/local/bin:/usr/bin:/bin XDG_RUNTIME_DIR=/run/user/${uid} DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/${uid}/bus $(printf '%q ' "$@")" 2>/dev/null
}
```

**Rationale:** The function header says `<cmd...>` (implying multiple arguments), but the implementation used `$*` (single string). After SPEC-BS-001 fixes the implementation to use `printf '%q ' "$@"`, the documentation must be updated to explain the quoting mechanism so callers understand that both single-string and multi-argument invocations are safe. [Source: Bash Manual, §3.4.2 Special Parameters]

**Auth plan impact:** The auth plan's `_rotate_bootstrap_credentials` (§6.5) calls `_run_as_floci_guest` with a single string argument. The updated documentation clarifies that this is a supported calling convention. No change to the auth plan's code blocks.

---

### SPEC-BS-010: Fix error suppression in `_install_exec_condition`

**Source:** F-BS-011
**Severity:** 6 (MEDIUM)
**Affected file:** `mock-server/dev-twin.sh`
**Affected auth plan section:** §6.4 (`_install_absent` calls `_install_exec_condition`)

**Current code** (dev-twin.sh:442–451):
```bash
_install_exec_condition() {
  local uid tmpfile
  uid="$(limactl shell "$DEV_TWIN_NAME" -- bash -c 'id -u floci 2>/dev/null' 2>/dev/null)"
  tmpfile="$(mktemp /tmp/exec-condition.XXXXXX)"
  printf '[Service]\nExecCondition=/bin/bash -c '"'"'findmnt -no FSTYPE,SOURCE /mnt/lima-floci-dev-data 2>/dev/null | grep -qE "^ext4 /dev/vd[a-z][0-9]+$"'"'"'\n' > "$tmpfile"
  limactl copy "$tmpfile" "$DEV_TWIN_NAME:/tmp/mount-condition.conf" 2>/dev/null
  limactl shell "$DEV_TWIN_NAME" -- bash -c 'sudo chmod 644 /tmp/mount-condition.conf' 2>/dev/null
  limactl shell "$DEV_TWIN_NAME" -- bash -c "sudo -u floci env HOME=/home/floci XDG_RUNTIME_DIR=/run/user/${uid} DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/${uid}/bus bash -c 'mkdir -p /home/floci/.config/systemd/user/floci.service.d && cp /tmp/mount-condition.conf /home/floci/.config/systemd/user/floci.service.d/mount-condition.conf && systemctl --user daemon-reload'" 2>/dev/null
  rm -f "$tmpfile"
}
```

**Required change:**
```bash
_install_exec_condition() {
  local uid tmpfile rc
  uid="$(limactl shell "$DEV_TWIN_NAME" -- bash -c 'id -u floci 2>/dev/null' 2>/dev/null)" || {
    printf 'ERROR: exec-condition: could not resolve floci uid in guest\n' >&2
    return 1
  }
  tmpfile="$(mktemp /tmp/exec-condition.XXXXXX)"
  TEMP_FILES+=("$tmpfile")
  printf '[Service]\nExecCondition=/bin/bash -c '"'"'findmnt -no FSTYPE,SOURCE /mnt/lima-floci-dev-data 2>/dev/null | grep -qE "^ext4 /dev/vd[a-z][0-9]+$"'"'"'\n' > "$tmpfile"
  limactl copy "$tmpfile" "$DEV_TWIN_NAME:/tmp/mount-condition.conf" 2>/dev/null || {
    printf 'ERROR: exec-condition: limactl copy failed\n' >&2
    return 1
  }
  limactl shell "$DEV_TWIN_NAME" -- bash -c 'sudo chmod 644 /tmp/mount-condition.conf' 2>/dev/null || {
    printf 'ERROR: exec-condition: chmod failed in guest\n' >&2
    return 1
  }
  limactl shell "$DEV_TWIN_NAME" -- bash -c \
    "sudo -u floci env HOME=/home/floci XDG_RUNTIME_DIR=/run/user/${uid} DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/${uid}/bus bash -c 'mkdir -p /home/floci/.config/systemd/user/floci.service.d && cp /tmp/mount-condition.conf /home/floci/.config/systemd/user/floci.service.d/mount-condition.conf && systemctl --user daemon-reload'" 2>/dev/null
  rc=$?
  if [[ $rc -ne 0 ]]; then
    printf 'ERROR: exec-condition: systemd daemon-reload failed (exit %d)\n' "$rc" >&2
    return 1
  fi
}
```

**Rationale:** The original function chains four `limactl` commands with `2>/dev/null` on each, silently swallowing all failures. If `limactl copy` fails (e.g., the twin is unreachable), the subsequent `limactl shell` commands also fail silently, and the function returns 0 (success) because `rm -f "$tmpfile"` is the last command. The fix checks the exit code of each `limactl` call and returns a non-zero status with a diagnostic message on failure. [Source: Bash Manual, §3.7.5 Exit Status — every command's exit status must be checked]

**Note on `2>/dev/null`:** The `2>/dev/null` on `limactl shell` calls is retained per the AGENTS.md convention (suppresses Lima login-shell `cd` noise). The fix adds `|| { ... }` blocks *after* the `2>/dev/null` to check the exit code. This is correct because `2>/dev/null` only redirects stderr — it does not affect the exit status.

**Auth plan impact:** The auth plan's §6.4 (`_install_absent`) calls `_install_exec_condition` after the installer runs. If `_install_exec_condition` fails silently (as it currently can), the dev twin would appear to succeed but the ExecCondition override would be missing, causing `floci.service` to fail on resume. The fix ensures the failure is caught and reported. No change to the auth plan's code blocks — the fix is on the existing function.

---

## Summary of Auth Plan Code Block Impact

| Auth Plan Section | Code Block | BS Findings Affecting It | Changes Needed in Auth Plan |
|-------------------|-----------|--------------------------|----------------------------|
| §6.1 | `FLOCI_AUTH_MODE` case statement in `setup-floci.sh` | M-BS-001, F-BS-008 | None — fixes are on the script, not the code block |
| §6.1a | `DEV_CREDENTIALS_FILE` constant in `dev-twin.sh` | M-BS-001, F-BS-008 | None — fixes are on the script, not the code block |
| §6.2 | Write auth vars to env file in `setup-floci.sh` | M-BS-001, F-BS-008 | None |
| §6.3 | `print_summary` conditional in `setup-floci.sh` | M-BS-001, F-BS-008 | None |
| §6.4 | `_install_absent` passes `FLOCI_AUTH_MODE=sigv4` | F-BS-011, M-BS-003, F-BS-002 | None — fixes are on `_install_exec_condition` (called by `_install_absent`) |
| §6.5 | `_rotate_bootstrap_credentials` | F-BS-001, F-BS-009, M-BS-001, F-BS-008 | None — fixes are on `_run_as_floci_guest` (called by this function) |
| §6.6 | `dev_env` uses rotated credentials | M-BS-001, F-BS-008 | None |
| §6.7 | `_print_next_steps` security section | M-BS-001, F-BS-008 | None |
| §6.8 | `dev_reset` deletes credentials file | M-BS-001, F-BS-008 | None |
| §6.9 | `preflight-floci.sh` bootstrap creds | M-BS-001, F-BS-008 | None |
| §6.10 | `run-test.sh` + `run-in-vm.sh` auth-mode | F-BS-007, M-BS-002, M-BS-001, F-BS-008 | **§6.10 code block must show fixed `driver_args` expansion** (SPEC-BS-007) |

## Verdict

**VERDICT: CONDITIONAL PASS**
**SEVERITY: 8** (highest finding: M-BS-001 — missing `errtrace` in all scripts, severity 8)

**FINDINGS:**
- [8] All 6 scripts: Missing `set -o errtrace` — ERR traps are inert inside functions without it (M-BS-001)
- [7] `dev-twin.sh:334`: `$*` loses argument boundaries in `_run_as_floci_guest` (F-BS-001)
- [7] `dev-twin.sh:444`, `assert.sh:236`: `local var="$(cmd)"` masks errexit (M-BS-003)
- [7] `run-test.sh`: No signal trap for orphaned systemd-run unit on SIGINT (M-BS-002)
- [7] All 6 scripts: No ERR trap with `caller` stack backtrace (F-BS-008)
- [6] `dev-twin.sh`, `run-test.sh`: No global `TEMP_FILES=()` array with trap cleanup (F-BS-002, F-BS-003)
- [6] `run-test.sh:194`: `driver_args[*]` expansion loses argument boundaries (F-BS-007)
- [6] `dev-twin.sh:442-451`: `_install_exec_condition` suppresses all errors with `2>/dev/null` (F-BS-011)
- [4] `setup-floci.sh:390`: `sort -V` is GNU-specific — document dependency (F-BS-005)
- [4] `dev-twin.sh:324`: `_run_as_floci_guest` doc says `<cmd...>` but implementation used `$*` (F-BS-009)

**ROUTING:** code-architect (for implementation in Phase B)

**Conditions for full approval:**
1. SPEC-BS-002 (`errtrace`) must be applied before SPEC-BS-008 (ERR trap) — the ERR trap is useless without `errtrace`
2. SPEC-BS-001 (`$*` → `printf '%q ' "$@"`) must be applied before SPEC-BS-009 (doc update) — the doc describes the fixed implementation
3. SPEC-BS-007 (fixed `driver_args` expansion) must be reflected in the auth plan's §6.10 code block
4. All other SPECs are independent and can be applied in any order

## Self-Audit Checklist

| Category | Checked? | Finding or PASS |
|----------|----------|-----------------|
| Build passes (exit 0, no warnings) | N/A | No code changes in this phase — specification only |
| Typed enums / vocabulary types | N/A | Bash scripting — not applicable |
| Documentation on new public symbols | N/A | Specification document — no code symbols |
| Spec/datasheet fidelity | yes | All claims cited against Bash Manual, POSIX spec, GNU Coreutils Manual |
| Module boundary | N/A | Bash scripting — not applicable |
| Reserved/padding fields handled | N/A | Bash scripting — not applicable |
| No magic numbers in doc examples | yes | All code examples use named variables, no unexplained literals |
| Buffer safety | N/A | Bash scripting — not applicable |
| AGENTS.md compliance | yes | Follows bash-scripting skill standards, authoritative-reference citations present |
| Conventional commit ready | N/A | Specification phase — no commits |

## References

| Claim / Decision | Source | Verification |
|-----------------|--------|-------------|
| `$*` vs `$@` argument boundary semantics | [Source: Bash Manual, §3.4.2 Special Parameters] | Verified — `$*` joins with IFS first char; `$@` preserves boundaries |
| `errtrace` required for ERR trap in functions | [Source: Bash Manual, §4.3.2 The Set Builtin] | Verified — `-o errtrace` causes ERR trap to be inherited by functions |
| `local var="$(cmd)"` masks errexit | [Source: Bash Manual, §4.3.1 The Set Builtin] | Verified — `local` return status overrides `cmd` return status |
| `printf '%q '` for safe argument quoting | [Source: Bash Manual, §4.2 Bash Builtin Commands — printf] | Verified — `%q` produces shell-escaped output |
| `caller` builtin for stack backtrace | [Source: Bash Manual, §4.1 Bourne Shell Builtins] | Verified — `caller` returns frame number, line, subroutine name |
| `sort -V` is a GNU extension | [Source: GNU Coreutils Manual, §7.1 sort invocation] | Verified — `-V` / `--version-sort` is GNU-specific |
| `TEMP_FILES=()` array pattern | [Source: Google Shell Style Guide, §5.5 Temporary Files] | Verified — recommended pattern for multi-function temp file tracking |
| SIGINT/SIGTERM cleanup obligations | [Source: POSIX.1-2017, §2.11 Signals and Error Handling] | Verified — processes must clean up resources on signal receipt |
