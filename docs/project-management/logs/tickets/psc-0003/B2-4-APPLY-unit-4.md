# B2-4: APPLY Unit 4 — Guest Driver Array Fixes

| Field | Value |
|-------|-------|
| Agent | code-architect |
| Timestamp | 2026-07-30T00:00:00Z |
| Step | B2-4 |
| Ticket | psc-0003 |
| Unit | 4 — Guest Driver Array Fixes |

## PLAN

| Units declared | 2 |
| Unit descriptions | 1. `mock-server/in-vm/run-in-vm.sh` — array-based credential overrides; 2. `mock-server/run-test.sh` — retain array guard, fix `[*]` → `[@]` |
| Files identified | `mock-server/in-vm/run-in-vm.sh`, `mock-server/run-test.sh` |

## APPLY

### Unit 1: `mock-server/in-vm/run-in-vm.sh`

| Build result | PASS — exit 0, 0 warnings |
| Files changed | `mock-server/in-vm/run-in-vm.sh` (+15 lines, -2 lines) |

**Changes:**

1. **Added `AUTH_MODE` variable and `aws_creds_env` array** (lines 20, 23):
   - `AUTH_MODE="off"` — default, overridable via `--auth-mode=`
   - `aws_creds_env=()` — empty array, populated in `main()` when `AUTH_MODE=sigv4`

2. **Added `--auth-mode=` parsing to `parse_args`** (lines 54-63):
   - Validates value is `off` or `sigv4`
   - Rejects unknown values with a clear error message

3. **Updated `usage()`** (line 42):
   - Added `[--auth-mode=off|sigv4]` to usage string

4. **Populated `aws_creds_env` in `main()`** (lines 353-355):
   - After `parse_args`, before evidence staging
   - `if [[ "$AUTH_MODE" == "sigv4" ]]; then aws_creds_env=(-e AWS_ACCESS_KEY_ID=floci -e AWS_SECRET_ACCESS_KEY=floci); fi`

5. **Updated s3-smoke step** (lines 206, 208):
   - `podman exec` → `podman exec ${aws_creds_env[@]+"${aws_creds_env[@]}"} tianlu-floci`
   - Both `s3 mb` and `s3 ls` calls updated
   - `${arr[@]+...}` guard ensures empty array doesn't trigger `set -u` on bash 3.2

6. **Updated Lambda step** (line 232):
   - `podman exec tianlu-floci bash -c` → `podman exec ${aws_creds_env[@]+"${aws_creds_env[@]}"} tianlu-floci bash -c`
   - `-e` flags inserted before `bash`, not inside the heredoc script

### Unit 2: `mock-server/run-test.sh`

| Build result | PASS — exit 0, 0 warnings |
| Files changed | `mock-server/run-test.sh` (+12 lines, -3 lines) |

**Changes:**

1. **Added `AUTH_MODE` variable** (line 19):
   - `AUTH_MODE="off"` — default, overridable via `--auth-mode=`

2. **Added `--auth-mode=` parsing to `parse_args`** (lines 88-96):
   - Validates value is `off` or `sigv4`
   - Rejects unknown values with a clear error message

3. **Updated `usage()`** (line 37):
   - Added `[--auth-mode=off|sigv4]` to usage string

4. **Added `--auth-mode` to `driver_args` in `launch_driver`** (lines 205-207):
   - `if [[ "$AUTH_MODE" != "off" ]]; then driver_args+=(--auth-mode="$AUTH_MODE"); fi`
   - Only passes the flag when mode is not the default `off`

5. **Fixed `[*]` → `[@]` and retained `${arr[@]+...}` guard** (lines 208-210):
   - Changed `${driver_args[*]+"${driver_args[*]}"}` → `${driver_args[@]+"${driver_args[@]}"}`
   - Used `printf '%q '` to produce a single shell-escaped string for embedding in `bash -c`
   - Guard retained for bash 3.2 (macOS `/bin/bash`) compatibility

## VALIDATE

| Full build | PASS — exit 0, 0 warnings |
| AC coverage | 5/5 acceptance criteria satisfied |

### Acceptance criteria verification:

1. ✅ **aws_creds_env is an array, not a string** — declared as `aws_creds_env=()` (line 23), populated as `aws_creds_env=(-e AWS_ACCESS_KEY_ID=floci -e AWS_SECRET_ACCESS_KEY=floci)` (line 354)
2. ✅ **Lambda step: -e flags before bash, not inside heredoc** — `podman exec ${aws_creds_env[@]+"${aws_creds_env[@]}"} tianlu-floci bash -c '...'` (line 232)
3. ✅ **${driver_args[@]+…} guard retained** — `printf '%q ' ${driver_args[@]+"${driver_args[@]}"}` (line 210)
4. ✅ **[*] → [@] for IFS correctness** — `driver_args[@]` used throughout (line 210)
5. ✅ **shellcheck passes on both files** — both exit 0, zero warnings

### Build verification output:

```
$ shellcheck mock-server/in-vm/run-in-vm.sh; echo "EXIT: $?"
EXIT: 0

$ shellcheck mock-server/run-test.sh; echo "EXIT: $?"
EXIT: 0

$ bash -n mock-server/in-vm/run-in-vm.sh; echo "EXIT: $?"
EXIT: 0

$ bash -n mock-server/run-test.sh; echo "EXIT: $?"
EXIT: 0
```

## Design notes

- **`${arr[@]+"${arr[@]}"}` guard**: Required for bash 3.2 (macOS `/bin/bash`) where empty array expansion with `set -u` triggers an unbound variable error. The `+` alternative expansion form only expands when the array is set and non-empty.
- **`printf '%q '` in `launch_driver`**: The `[@]` expansion produces multiple words, which cannot be directly embedded in a double-quoted `bash -c` string. `printf '%q '` produces a single shell-escaped string that is safe for embedding.
- **`--auth-mode` only passed when non-default**: The `if [[ "$AUTH_MODE" != "off" ]]` guard avoids passing `--auth-mode=off` to the guest driver, keeping the default path clean. The guest driver defaults to `off` independently.
- **`-e` flags before `bash`, not inside heredoc**: The Lambda step passes a heredoc-style `bash -c` script. The `-e` flags are `podman exec` flags and must precede the container name, not be embedded in the script.
