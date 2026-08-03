# A1-BS: Bash Specialist Review — psc-adv-0001

| Field | Value |
|-------|-------|
| Agent | bash-specialist |
| Timestamp | 2026-07-29T00:00:00Z |
| Step | A1-BS |
| Verdict | CONDITIONAL PASS |
| Severity | 85 |

## Reference Validation

| Primary Claim | Reference Provided | Authority Level | Verified? | Correctly Applied? |
|--------------|-------------------|-----------------|-----------|-------------------|
| `set -euo pipefail` strict mode | [Spec: Bash Manual, §4.3.1 The Set Builtin] | 1 | ✓ | ✓ — all three scripts set it at the top |
| `IFS=$'\n\t'` for safe word splitting | [Spec: Bash Manual, §5.1 Bourne Shell Variables] | 1 | ✓ | ✓ — all three scripts set it |
| `$*` vs `"$@"` argument expansion | [Spec: Bash Manual, §3.4.2 Special Parameters] | 1 | ✓ | ✗ — dev-twin.sh:334 uses `$*` where `"$@"` is needed |
| `(( expr ))` exit status trap | [Spec: Bash Manual, §6.5 Shell Arithmetic] | 1 | ✓ | ✓ — all arithmetic in safe contexts (for-loop, `$((...))`, `if`/`while` conditions) |
| `sort -V` version sort | [Source: GNU Coreutils Manual, §7.1 sort] | 2 | ✓ | ⚠ — GNU extension, acceptable for Ubuntu-only target |
| `mktemp` temp file creation | [Spec: POSIX.1-2017, mktemp] | 1 | ✓ | ✓ — used correctly, but no trap cleanup |
| `cp -a` archive mode | [Source: macOS cp(1) man page] | 2 | ✓ | ✓ — BSD `cp -a` supported on macOS |
| `readonly` with `${VAR:-default}` pattern | [Spec: Bash Manual, §4.2 Bash Builtin Commands] | 1 | ✓ | ✓ — correct injection-safe config pattern |
| `"${arr[@]+"${arr[@]}"}"` empty-array guard | [Source: ShellCheck SC2145] | 3 | ✓ | ✓ — correct `set -u` guard for optional arrays |
| `trap` for ERR/EXIT/INT/TERM | [Spec: Bash Manual, §4.1 Bourne Shell Builtins] | 1 | ✓ | ✗ — no trap handlers in any of the three scripts |

## Findings

### F-BS-001: `$*` in `_run_as_floci_guest` loses argument boundaries

| Field | Value |
|-------|-------|
| Confidence | 85 |
| Severity | HIGH |
| File | mock-server/dev-twin.sh |
| Line | 334 |
| Category | quoting |

**Description:** The `_run_as_floci_guest` function uses `$*` inside a double-quoted `bash -c` string:

```bash
limactl shell "$DEV_TWIN_NAME" -- bash -c \
    "sudo -u floci env ... $*" 2>/dev/null
```

`$*` expands to all positional parameters joined by the first character of `IFS` (newline, since `IFS=$'\n\t'`). This loses argument boundaries — if the function were ever called with multiple arguments containing spaces, the command would break. For example, `_run_as_floci_guest echo "hello world"` would produce `echo\nhello world` inside `bash -c`, executing `echo` then `hello world` as separate commands.

**Current mitigation:** All callers pass a single string argument (e.g., `_run_as_floci_guest 'systemctl --user start floci.service'`), so the bug is latent. However, the function is documented as `_run_as_floci_guest <cmd...>` (line 324), suggesting it accepts a command and separate arguments — which would trigger the bug.

**Contrast with `in-vm/lib/assert.sh:233`:** The guest-side `run_as_floci_guest` correctly uses `"$@"` because it runs commands directly (not through `bash -c`).

**Recommendation:** Either:
1. (Preferred) Use `printf '%q ' "$@"` to safely escape arguments for `bash -c`:
   ```bash
   local cmd
   cmd="$(printf 'sudo -u floci env HOME=/home/floci ... %q ' "$@")"
   limactl shell "$DEV_TWIN_NAME" -- bash -c "$cmd" 2>/dev/null
   ```
2. Or document that the function accepts exactly one string argument and rename the parameter comment to `_run_as_floci_guest <command_string>`.

**Reference:** [Spec: Bash Manual, §3.4.2 Special Parameters] — `$*` expands to a single word with IFS-joined values; `"$@"` expands to separate words, each individually quoted.

---

### F-BS-002: No trap cleanup for temp files in setup-floci.sh

| Field | Value |
|-------|-------|
| Confidence | 80 |
| Severity | HIGH |
| File | setup-floci.sh |
| Line | 466, 760 |
| Category | defensive-programming |

**Description:** `setup-floci.sh` creates temporary files but has no `trap` handler for cleanup on `EXIT`, `INT`, or `TERM`:

- Line 466: `tmp_profile="${APPARMOR_USERNS_PROFILE}.tmp.$$"` — written, `chmod`'d, then `mv -f`'d to the final location. If the script is killed between creation and the `mv`, the `.tmp.$$` file is left in `/etc/apparmor.d/`.
- Line 760: `tmp_hosts="${HOSTS_FILE}.tmp.$$"` — written, compared with `cmp -s`, then either `rm -f`'d (if identical) or `mv -f`'d to `/etc/hosts`. If killed between creation and the `cmp`/`mv`, the `.tmp.$$` file is left in `/etc/`.

The `.tmp` sidecars for the Quadlet and env file (lines 275, 822) are written inside `$FLOCI_HOME` via `run_as_floci`, so they're less critical — but still lack cleanup.

**Recommendation:** Add a trap handler at the top of `main()`:

```bash
cleanup_temp_files() {
  rm -f "${APPARMOR_USERNS_PROFILE}.tmp.$$" "${HOSTS_FILE}.tmp.$$" 2>/dev/null || true
}
trap cleanup_temp_files EXIT INT TERM
```

**Reference:** [Spec: Bash Manual, §4.1 Bourne Shell Builtins — trap] — "If a sigspec is EXIT (0) the command arg is executed on exit from the shell."

---

### F-BS-003: No trap cleanup for mktemp files in dev-twin.sh

| Field | Value |
|-------|-------|
| Confidence | 80 |
| Severity | HIGH |
| File | mock-server/dev-twin.sh |
| Line | 68, 195, 251, 445 |
| Category | defensive-programming |

**Description:** `dev-twin.sh` creates temporary files with `mktemp` but has no `trap` handler:

- Line 68: `lsof_err="$(mktemp /tmp/lsof-err.XXXXXX)"` — cleaned up manually on lines 71, 76, 79, but if the function returns between `mktemp` and cleanup (e.g., `return 1` on line 77), the file leaks.
- Lines 195, 251: `tmpfile="$(mktemp /tmp/dev-twin-hosts.XXXXXX)"` — cleaned up manually, but early returns (e.g., line 199, 254) could leak if `rm -f` is skipped.
- Line 445: `tmpfile="$(mktemp /tmp/exec-condition.XXXXXX)"` — cleaned up on line 450, but if `limactl copy` or `limactl shell` fails before line 450, the file leaks.

**Recommendation:** Add a trap at the top of `main()`:

```bash
cleanup_mktemp() {
  rm -f /tmp/lsof-err.* /tmp/dev-twin-hosts.* /tmp/exec-condition.* 2>/dev/null || true
}
trap cleanup_mktemp EXIT INT TERM
```

Or, more precisely, accumulate temp file paths in a global array and clean them individually.

**Reference:** [Spec: Bash Manual, §4.1 Bourne Shell Builtins — trap]

---

### F-BS-004: No trap cleanup in run-test.sh

| Field | Value |
|-------|-------|
| Confidence | 75 |
| Severity | MODERATE |
| File | mock-server/run-test.sh |
| Line | 1-563 (entire file) |
| Category | defensive-programming |

**Description:** `run-test.sh` has no `trap` handlers at all — no ERR trap for stack backtraces, no EXIT/INT/TERM trap for cleanup. The script manages a background process (`DRIVER_SHELL_PID`) and evidence directories, but if killed mid-execution:

- The background `limactl shell` process (line 194-196) may continue running orphaned.
- The evidence staging directory (`$STAGING`) may contain partial files.
- The Lima twin may be left in an inconsistent state.

The `teardown()` function (line 503) handles normal cleanup but is only called at the end of `main()`. If the script receives SIGINT or SIGTERM, `teardown()` is never invoked.

**Recommendation:** Add signal handlers:

```bash
cleanup_on_signal() {
  wait "${DRIVER_SHELL_PID:-}" 2>/dev/null || true
  teardown
  exit 1
}
trap cleanup_on_signal INT TERM
```

**Reference:** [Spec: Bash Manual, §4.1 Bourne Shell Builtins — trap]

---

### F-BS-005: `sort -V` is a GNU extension

| Field | Value |
|-------|-------|
| Confidence | 60 |
| Severity | LOW |
| File | setup-floci.sh |
| Line | 390 |
| Category | portability |

**Description:** Line 390 uses `sort -V` (version sort) to compare Ubuntu version numbers:

```bash
lowest="$(printf '%s\n%s\n' "$MIN_UBUNTU_VERSION" "$os_version" \
    | sort -V | head -n1)"
```

`sort -V` is a GNU coreutils extension not available on BSD/macOS `sort`. On macOS, this would produce `sort: invalid option -- V`.

**Mitigation:** The script targets Ubuntu only (line 20: "Ubuntu 24.04+"), where GNU coreutils is the default. This is acceptable but should be documented as a portability constraint.

**Recommendation:** Add a comment noting the GNU dependency, or use an alternative like `dpkg --compare-versions` (available on Debian/Ubuntu):

```bash
if dpkg --compare-versions "$os_version" ge "$MIN_UBUNTU_VERSION"; then
  : # version OK
else
  printf 'ERROR: Ubuntu %s is too old...\n' "$os_version" >&2
  exit 1
fi
```

**Reference:** [Source: GNU Coreutils Manual, §7.1 sort] — `-V` is a GNU extension for natural version number sorting.

---

### F-BS-006: Non-atomic `cp` for /etc/hosts in dev-twin.sh

| Field | Value |
|-------|-------|
| Confidence | 70 |
| Severity | MODERATE |
| File | mock-server/dev-twin.sh |
| Line | 163 |
| Category | atomicity |

**Description:** The `_write_hosts_file` function uses `cp` for non-`/etc/hosts` paths:

```bash
_write_hosts_file() {
  local tmpfile="$1" hosts_file="$2"
  if [[ "$hosts_file" == "/etc/hosts" ]]; then
    sudo install -m 0644 -o root -g wheel "$tmpfile" "$hosts_file"
  else
    cp "$tmpfile" "$hosts_file"    # <-- non-atomic
  fi
}
```

`cp` is not atomic — if the script is killed mid-copy, the destination file is truncated. The `sudo install` path (line 161) is better because `install` creates a temp file and renames atomically on most systems. The `cp` path (line 163) is used for test overrides (`DEV_HOSTS_FILE` set to a temp path), so the risk is low, but the pattern is inconsistent.

**Recommendation:** Use `mv` instead of `cp` since `$tmpfile` is a temp file that will be deleted anyway:

```bash
mv "$tmpfile" "$hosts_file"
```

Or use `install` consistently (it works without sudo for user-owned files).

**Reference:** [Spec: POSIX.1-2017, mv] — `mv` between files on the same filesystem is atomic (rename).

---

### F-BS-007: `driver_args[*]` expansion loses argument boundaries

| Field | Value |
|-------|-------|
| Confidence | 65 |
| Severity | MODERATE |
| File | mock-server/run-test.sh |
| Line | 194 |
| Category | quoting |

**Description:** The `launch_driver` function expands `driver_args` with `[*]` inside a `bash -c` string:

```bash
limactl shell "$TWIN_NAME" -- bash -c \
  "sudo systemd-run ... -- /opt/tianlu/mock-server/in-vm/run-in-vm.sh ${driver_args[*]+"${driver_args[*]}"}" 2>/dev/null
```

`[*]` joins array elements with the first character of `IFS` (newline). With the current single-element array (`--no-sidecar`), this works. But if `driver_args` ever contained an argument with spaces (e.g., `--flag "value with spaces"`), the expansion would break.

**Recommendation:** Use `printf '%q '` to safely escape array elements for `bash -c`:

```bash
local args_str
args_str="$(printf '%q ' "${driver_args[@]+"${driver_args[@]}"}")"
limactl shell "$TWIN_NAME" -- bash -c \
  "sudo systemd-run ... -- /opt/tianlu/mock-server/in-vm/run-in-vm.sh ${args_str}" 2>/dev/null
```

**Reference:** [Spec: Bash Manual, §3.4.2 Special Parameters] — `[*]` vs `[@]` expansion behavior.

---

### F-BS-008: No ERR trap / stack backtrace in any script

| Field | Value |
|-------|-------|
| Confidence | 70 |
| Severity | MODERATE |
| File | setup-floci.sh, dev-twin.sh, run-test.sh |
| Line | N/A (absent) |
| Category | defensive-programming |

**Description:** None of the three scripts register an ERR trap for call-stack backtraces. Per the bash-scripting skill (§4.2), scripts SHOULD print a call stack trace when an unexpected error occurs. This is especially valuable for `setup-floci.sh` (996 lines, 7 phases) where an error deep in a phase function would otherwise produce only "command failed" with no context about which function or line triggered it.

The `in-vm/run-in-vm.sh` guest driver does have ERR trap handling (lines 73, 343), but the host-side orchestrators do not.

**Recommendation:** Add to all three scripts:

```bash
generate_stack_trace() {
  local error_code=$? i
  printf '[%s] ERROR: command failed with status %d at line %d\n' \
    "$(date +%Y-%m-%dT%H:%M:%S%z)" "$error_code" "${BASH_LINENO[0]}" >&2
  for ((i = 1; i < ${#BASH_LINENO[@]}; i++)); do
    printf '  File "%s", line %d, in %s\n' \
      "${BASH_SOURCE[i]}" "${BASH_LINENO[i-1]}" "${FUNCNAME[i]}" >&2
  done
}
trap generate_stack_trace ERR
```

**Reference:** [Spec: Bash Manual, §4.1 Bourne Shell Builtins — trap] and bash-scripting skill §4.2.

---

### F-BS-009: `_run_as_floci_guest` function signature is misleading

| Field | Value |
|-------|-------|
| Confidence | 75 |
| Severity | MODERATE |
| File | mock-server/dev-twin.sh |
| Line | 324-335 |
| Category | code-quality |

**Description:** The function is documented as:

```bash
# _run_as_floci_guest <cmd...>
# Run a command as the floci user inside the guest...
```

The `<cmd...>` notation suggests it accepts a command and separate arguments (like `run_as_floci_guest systemctl --user start floci.service`). However, the implementation uses `$*` inside a `bash -c` string, which only works correctly with a single string argument. All callers pass a single quoted string.

This is a documentation-implementation mismatch that could lead to incorrect usage.

**Recommendation:** Either:
1. Fix the implementation to support multiple arguments (see F-BS-001), or
2. Update the documentation to `_run_as_floci_guest <command_string>` and add a comment: "Accepts exactly one argument: a shell command string to execute inside the guest."

---

### F-BS-010: `read -t` with file redirection ignores timeout

| Field | Value |
|-------|-------|
| Confidence | 40 |
| Severity | LOW |
| File | mock-server/dev-twin.sh |
| Line | 276 |
| Category | portability |

**Description:** The `confirm_reset` function uses `read -t` with a file redirection:

```bash
read -t "$timeout" -r response < "$stdin_file" || rc=$?
```

Per the Bash manual, `read -t` timeout only applies when reading from a terminal or pipe — not when reading from a regular file. When `$stdin_file` is a regular file (the default `/dev/stdin` when not a TTY), the timeout is ignored and `read` returns immediately with whatever data is available (or EOF). This means the 30-second timeout is effectively dead code in non-TTY mode.

**Recommendation:** This is acceptable for a dev tool. If strict timeout enforcement is needed, use a background process with `sleep` + `kill` or `timeout` from coreutils.

**Reference:** [Spec: Bash Manual, §4.2 Bash Builtin Commands — read] — "If timeout is 0, read returns immediately, without trying to read any data. ... If timeout is not 0, and the shell is reading from a terminal, pipe, or other special file, read times out."

---

### F-BS-011: `_install_exec_condition` suppresses all errors

| Field | Value |
|-------|-------|
| Confidence | 50 |
| Severity | LOW |
| File | mock-server/dev-twin.sh |
| Line | 442-451 |
| Category | defensive-programming |

**Description:** The `_install_exec_condition` function suppresses stderr on all `limactl` calls with `2>/dev/null`. If any step fails (e.g., `limactl copy` fails because the VM isn't ready, or `systemctl --user daemon-reload` fails), the error is silently swallowed. The function has no return-value checks between steps.

**Recommendation:** At minimum, check the exit code of the critical `limactl copy` and the final `systemctl --user daemon-reload`:

```bash
limactl copy "$tmpfile" "$DEV_TWIN_NAME:/tmp/mount-condition.conf" 2>/dev/null || {
  printf 'ERROR: exec-condition: failed to copy mount-condition.conf\n' >&2
  rm -f "$tmpfile"
  return 1
}
```

---

## Self-Audit Checklist

| Category | Checked? | Finding or PASS |
|----------|----------|-----------------|
| Build passes (exit 0, no warnings) | yes | `shellcheck --severity=warning` returns zero findings on all three scripts |
| Strict mode present | yes | PASS — all three scripts set `set -euo pipefail` + `IFS=$'\n\t'` at the top |
| Arithmetic safety | yes | PASS — all `(( expr ))` in safe contexts (for-loop, `$((...))`, `if`/`while` conditions) |
| Unbound variable handling | yes | PASS — `${VAR:-default}` used throughout; `${VAR:?message}` not needed for this use case |
| Guard clauses | yes | PASS — preconditions checked at function entry (e.g., `assert_root_or_sudo`, `assert_ubuntu_version`, `assert_preconditions`) |
| Binary dependency verification | yes | PASS — `command -v podman` (line 631), `command -v limactl` (line 52), `command -v lsof` (line 432) |
| Error output to stderr | yes | PASS — all error messages use `>&2` |
| Timestamped logging | yes | CONDITIONAL — no timestamped logging function; errors use plain `printf` to stderr. Acceptable for installer scripts. |
| Stack backtrace on error | no | FINDING — F-BS-008: no ERR trap in any of the three scripts |
| Function documentation headers | yes | PASS — complex functions have pydoc-style headers (e.g., `run_as_floci`, `write_quadlet_unit`, `assert_userns_allowed`) |
| Signal cleanup | no | FINDING — F-BS-002, F-BS-003, F-BS-004: no trap handlers for temp file cleanup or signal handling |
| Subprocess monitoring | yes | PASS — `run-test.sh` uses `wait` with `DRIVER_SHELL_PID` (line 229); `dev-twin.sh` has no background processes |
| No bashisms in /bin/sh scripts | yes | N/A — all scripts use `#!/usr/bin/env bash`, not `/bin/sh` |
| Portability validated | yes | CONDITIONAL — F-BS-005: `sort -V` is GNU-only, acceptable for Ubuntu target |
| Tests exist | yes | PASS — `tests/` directory with bats tests; `make lint` + `make test` + `make twin-test` |
| Tests cover error paths | yes | PASS — test stubs exercise idempotency and error branches |
| External commands mocked | yes | PASS — `tests/stubs/bin/` mocks podman, systemctl, etc. |
| Input sanitization | yes | PASS — `FLOCI_HOST_PERSISTENT_PATH` validated on line 116; no user input beyond CLI flags |
| No secrets in output | yes | PASS — `PRESIGN_SECRET` written to env file (mode 0600), never echoed |
| Least privilege | yes | PASS — `run_as_floci` drops privileges; `sudo` used only for system-level operations |
| ShellCheck passes | yes | PASS — `shellcheck --severity=warning` returns zero findings on all three scripts |

## Verdict

**CONDITIONAL PASS**

**Rationale:** All three scripts are well-structured, follow strict mode, pass ShellCheck with zero warnings, and demonstrate strong defensive patterns (atomic writes, idempotency, privilege dropping, `set -u` safe array expansion). The findings are concentrated in two areas: (1) missing trap handlers for temp file cleanup and error backtraces (defensive gaps, not correctness bugs), and (2) the `$*` vs `"$@"` issue in `_run_as_floci_guest` (latent bug, not currently triggered by any caller).

**Blocking findings (confidence ≥80):**
- F-BS-001: `$*` in `_run_as_floci_guest` (85) — argument boundary loss
- F-BS-002: No trap cleanup in setup-floci.sh (80) — temp file leak on signal
- F-BS-003: No trap cleanup in dev-twin.sh (80) — temp file leak on signal

**Advisory findings (confidence <80):**
- F-BS-004 through F-BS-011 — all moderate/low severity, documented above

**Routing:** CONDITIONAL PASS — blocking findings should be addressed by code-architect before the next pipeline phase. Advisory findings are logged for tracking.
