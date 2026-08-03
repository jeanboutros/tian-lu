# A2 Challenger: Bash Specialist — psc-0003

| Field | Value |
|-------|-------|
| Model | glm-5.2 (Bash Specialist Challenger) |
| Phase | A2 — Dual-Model Challenge |
| Primary Output | A1-BS: 20 SPEC-BS findings (SPEC-BS-001…020), CONDITIONAL PASS, severity 8, covering CH-AUTH-002/005/007/008/009/011, CH-INST-001/002/004, CH-DEV-001…006, CH-TWIN-001/002/004/007, CH-LZ-004 |
| Primary Verdict | CONDITIONAL PASS |
| Challenger Verdict | CONDITIONAL PASS |

## Reference Validation

| Primary Claim | Reference Provided | Authority Level | Verified? | Correctly Applied? |
|--------------|-------------------|-----------------|-----------|-------------------|
| `errexit` behaviour on bare simple commands | [Spec: Bash manual, §4.3.1 "The Set Builtin", `-e`] | 2 (manufacturer) | ✓ | ✓ — verified: bare `false` under `set -e` exits the shell; `delete_rc=$?` is unreachable |
| `IFS=$'\n\t'` does not split on spaces | [Spec: POSIX Shell, §2.6 "Word Expansions"] | 1 (spec) | ✓ | ✓ — verified: `set -- $V` yields 1 argument |
| bash 3.2 `${a[@]}` under `set -u` is unbound | tested on macOS `/bin/bash` 3.2.57 | 2 | ✓ | ✓ — verified: `a[@]: unbound variable` |
| **`printf '%q '` is bash 4.0+** | [Spec: Bash manual, §4.2, `printf`] | 2 | ✗ | **✗ FALSE** — `printf '%q'` works on bash 3.2.57 (verified: `printf "[%q] " "a b"` → `[a\ b]`). The `%q` format specifier predates bash 4.0. This is a factual error in the References table and it undermines the SPEC-BS-005 recommendation rationale. |
| `command -v` is POSIX-compliant | [Spec: POSIX.1-2017, `command` utility] | 1 | ✓ | ✓ |
| `case` glob patterns are POSIX | [Spec: POSIX Shell, §2.9.4] | 1 | ✓ | ✓ |
| Atomic file write pattern | `setup-floci.sh:822–841` (repo) | 8 (repo) | ✓ | ✓ — the `.tmp` + `chmod` + `mv -f` pattern is present in `write_env_file` |
| `||` as condition context suppressing `errexit` | [Spec: Bash manual, §4.3.1] | 2 | ✓ | ✓ — verified: `false || rc=$?` executes the handler |

**Findings:**
- [✓] All factual claims have at least one citation
- [✓] All citations are from authoritative sources (trust level 1-8)
- [✗] **One cited source is misattributed** — `printf '%q'` is NOT bash 4.0+; it works on bash 3.2.57. See Disagreement D1.
- [✓] Implementation alignment not assessed (Phase A — design review)
- [✓] Best practices and gotchas were reasonably sought, with gaps — see One-Sided Findings

## Agreements

The challenger agrees with the primary on the following:

| # | Finding | Agreement |
|---|---------|-----------|
| A1 | SPEC-BS-001 (CH-AUTH-002) | The `${VAR:-default}` form on individual auth sub-variables reopens the forbidden `(signatures=on, enforcement=off)` state. The escape-hatch pattern (`FLOCI_AUTH_UNSAFE_OVERRIDE`) is sound. The `unset _auth_on` cleanup is correct. Confidence in the finding is appropriate. |
| A2 | SPEC-BS-002 (CH-AUTH-005) | The `delete_rc=$?` after a bare command is unreachable under `set -e`. **Independently verified** on bash 3.2.57: a script with `set -euo pipefail` + `false` + `delete_rc=$?` exits at `false` without reaching the assignment. The `|| delete_rc=$?` fix is correct and the `delete_rc=0` initialization is a necessary detail the primary correctly notes. |
| A3 | SPEC-BS-003 (CH-AUTH-007) | Non-atomic credential file write creates a truncation + permissions window. The `.tmp` + `chmod` + `mv -f` pattern is the correct fix and matches the existing `write_env_file` convention. The `source`-vs-`parse` security observation is valid — `source` executes the file. The parse sketch (`while IFS='=' read -r k v`) is **verified correct**: `read -r k v` splits on the first `=` and puts the remainder in `v`, so secrets containing `=` would survive (though current secrets are hex with no `=`). |
| A4 | SPEC-BS-004 (CH-AUTH-008) | Unquoted `$AWS_CREDS_ENV` under `IFS=$'\n\t'` collapses to one argument — **independently verified**: `IFS=$'\n\t'; V="-e A=1 -e B=2"; set -- $V` yields `count=1`. The array-based fix is correct. |
| A5 | SPEC-BS-006 (CH-AUTH-011) | No `DEV_AUTH_MODE` constant; rotation ungated. The `readonly DEV_AUTH_MODE="${DEV_AUTH_MODE:-sigv4}"` + early-return fix is correct and idiomatic. |
| A6 | SPEC-BS-007 (CH-INST-001) | `verify_health` aborts on any transient non-200. The `[5][0-9][0-9]` glob for 5xx retry is POSIX-correct. The `last_code` capture for the timeout message is a valuable diagnostic improvement. |
| A7 | SPEC-BS-008 (CH-INST-002) | The single-string `grep -q 'podman-userns'` sentinel fails on 26.04 because the system podman profile means the block is never written. Per-binary sentinel is the correct fix. |
| A8 | SPEC-BS-009 (CH-INST-004) | Missing `curl`/`openssl` preflight. The `command -v` assertion is POSIX-compliant and the array-based missing-command collection is idiomatic bash. |
| A9 | SPEC-BS-010 (CH-DEV-001) | `dev_recreate` prints no next steps. Simple function-call fix is correct. |
| A10 | SPEC-BS-011 (CH-DEV-002) | Resume paths never refresh the AWS profile. Adding `dev_env` to Running/Stopped branches is correct; the idempotency note is important. |
| A11 | SPEC-BS-012 (CH-DEV-003) | `dev_disk_exists` conflates absent with query-failed. Return code `2` for query failure is the standard convention. Caller branching update is correct. |
| A12 | SPEC-BS-013 (CH-DEV-004) | `DEV_DISK_NAME` configurable but mount path hardcoded. `readonly DEV_DISK_MOUNT="${DEV_DISK_MOUNT:-/mnt/lima-${DEV_DISK_NAME}}"` is the correct derivation. |
| A13 | SPEC-BS-014 (CH-DEV-005) | Fresh install has shorter health budget than resume. Unifying on `_resume_health_check` is correct. |
| A14 | SPEC-BS-015 (CH-DEV-006) | Redundant inner `main` guard makes `main` untestable from bats. Dropping the inner guard is correct — the outer guard at line 799 is the standard pattern. |
| A15 | SPEC-BS-016 (CH-TWIN-001) | Precondition failures skip the machine-readable verdict. Routing through `FAIL_REASON` + `return 1` is correct. |
| A16 | SPEC-BS-017 (CH-TWIN-002) | `sidecar-delta` not in `mandatory` array. Adding it is correct; the special case becomes live. |
| A17 | SPEC-BS-018 (CH-TWIN-004) | Stale-sentinel cleanup targets wrong directory. Dropping the redundant `rm -f` (since `rm -rf "$STAGING"` handles it) is the simpler correct fix. |
| A18 | SPEC-BS-019 (CH-TWIN-007) | Empty `DRIVER_SHELL_PID` yields spurious 127. The `[[ -n ]]` guard is correct. `HOST_HOME` falling back to a username is a real bug. |
| A19 | SPEC-BS-020 (CH-LZ-004) | G1 degrading to SKIP where the design promises a hard stop. Distinguishing automated gates (fail) from manual gates (skip) is the correct model. |

## Disagreements

| # | Finding | Confidence | Challenger Position | Reasoning & Evidence |
|---|---------|-----------|---------------------|----------------------|
| D1 | SPEC-BS-005 (CH-AUTH-009) — `printf '%q'` version claim | 95 | **The reference table claim "printf '%q' format specifier introduced in bash 4.0" is FALSE.** `printf '%q'` works on bash 3.2.57. Verified directly: `/bin/bash --version` → `GNU bash, version 3.2.57(1)-release`; `/bin/bash -c 'printf "%q\n" "hello world"'` → `hello\ world`. The `%q` format specifier has been in bash since well before 4.0. | [Spec: Bash manual, §4.2 "Bash Builtin Commands", `printf` — the manual documents `%q` without a version gate; it is available in the bash 3.2 that ships with macOS.](The primary's own recommendation to "add `(( BASH_VERSINFO[0] >= 4 ))` precondition because `printf '%q'` requires bash 4+" is built on a false premise. The guard retention is still correct — but for a different reason: `${a[@]}` under `set -u` is unbound on 3.2, not `printf '%q'. The recommendation should be reframed: keep the guard for empty-array safety on 3.2; `printf '%q'` itself is 3.2-safe. **Impact:** If implementation proceeds with the stated rationale, the bash-4+ precondition would be added unnecessarily, breaking macOS `/bin/bash` compatibility that is NOT required by `printf '%q'`.) |
| D2 | SPEC-BS-005 — bash-4+ precondition recommendation | 80 | **The recommendation to add `(( BASH_VERSINFO[0] >= 4 ))` precondition to `run-test.sh` should be reconsidered.** `run-test.sh` already uses `declare -A` (associative arrays) at line 22 of `run-in-vm.sh` (the guest driver), which IS bash 4+. But `run-test.sh` itself (host orchestrator) deliberately avoids `declare -A` — it uses parallel indexed arrays with a comment "bash 3.2 (macOS /bin/bash) has no associative arrays" (line 455-456). This is evidence the project explicitly supports bash 3.2 for the host-side orchestrator. | The existing codebase went to effort to remain 3.2-compatible on the host side (parallel arrays, `${arr[@]+…}` guards). Adding a bash-4+ precondition would contradict that deliberate design choice. The correct recommendation: keep the guard (already present at line 194), do NOT add a version precondition, and document that `run-test.sh` targets bash 3.2+ on the host. The `printf '%q'` improvement is 3.2-safe and can be adopted without a version gate. |
| D3 | SPEC-BS-005 — `[*]` vs `[@]` in the existing guard | 90 | **The primary's code sketch changes `${driver_args[*]+"${driver_args[*]}"}` to `${driver_args[@]+"${driver_args[@]}"}` but does not call out that this is a SECOND bug fix, distinct from the guard retention.** The existing line 194 uses `[*]` which, under `IFS=$'\n\t'`, joins elements with the first IFS char (newline) producing a single field on re-split for multi-element arrays. Verified: `IFS=$'\n\t'; a=("x" "y z"); s="${a[*]+${a[*]}}"; set -- $s` → count=1. The `[@]` form preserves element boundaries: count=2. | The primary bundles two fixes (guard retention + `[*]`→`[@]`) under one SPEC but only justifies the guard. The `[*]`→`[@]` change is independently necessary for correctness when `driver_args` has 2+ elements (e.g., `--no-sidecar --auth-mode=sigv4`). The primary should split this into two findings or explicitly document that both changes are required. |

## One-Sided Findings

These are bash-specific issues the primary BS missed entirely.

| # | ID | Confidence | Severity | File:Line | Description | Suggested Fix |
|---|----|-----------|----------|-----------|-------------|---------------|
| O1 | M-BS-001 | 88 | High | `setup-floci.sh:115-116` | **`FLOCI_HOST_PERSISTENT_PATH` validation runs BEFORE `readonly FLOCI_HOST_PERSISTENT_PATH` on line 114, but the path is used to set `FLOCI_DATA_DIR` on line 111 and validated on 115-116.** The ordering is: line 58 sets it (non-readonly), line 111 derives `FLOCI_DATA_DIR`, line 114 makes it readonly, lines 115-116 validate it. If validation fails on line 116, `exit 1` fires — but `FLOCI_DATA_DIR` was already set from an invalid path. This is not a live bug (exit prevents use) but it is fragile ordering: validation should precede derivation. More importantly, **line 116's character-class validation uses a long chain of `[[ ]]` glob negations** (`!=$'\n'* && ! *:* ...`) which is hard to audit and could miss edge cases. A `case`-based allowlist or `printf '%s' "$path" \| grep -qE '^[A-Za-z0-9/_.-]+$'` would be more maintainable and auditable. | Reorder: validate before deriving `FLOCI_DATA_DIR`; consider a positive-character-class allowlist instead of a chain of negations. |
| O2 | M-BS-002 | 85 | High | `setup-floci.sh:528` | **`IFS='.' read -r octet1 octet2 octet3 _ <<< "$SERVER_IP"` uses a here-string (`<<<`), which is a bashism.** The primary's portability assessments repeatedly state "no portability impact" but never note that `<<<` is bash-specific. This is consistent with the script's `#!/usr/bin/env bash` shebang and is acceptable, but the primary's blanket "None" portability assessments would be more accurate as "N/A — bash-only feature, consistent with shebang." The same applies to `IFS=$'\n\t'` (line 26) which is a `$'...'` ANSI-C quoting bashism. The primary should distinguish "no portability impact given the bash target" from "no portability impact at all." | No code change needed; refine portability assessment language to acknowledge bash-only constructs. |
| O3 | M-BS-003 | 82 | High | `setup-floci.sh:604-619` (`configure_subuid_subgid`) | **The overlap-detection loop uses `[[ "$candidate" -lt "$range_end" && "$candidate_end" -gt "$range_start" ]]` with arithmetic comparison on variables that may contain non-numeric values.** If `/etc/subuid` contains a malformed line where `range_start` or `range_count` is non-numeric (the `[[ -z ... ]]` guard on line 609 catches empty but not non-numeric), the `[[ -lt ]]` comparison produces a bash error ("integer expression expected") which under `set -e` would abort. The `IFS=: read -r _user range_start range_count` on line 607 reads arbitrary file content. A defensive `[[ "$range_start" =~ ^[0-9]+$ && "$range_count" =~ ^[0-9]+$ ]]` guard before the arithmetic would harden this. | Add a numeric-validation guard before the `-lt`/`-gt` comparison in the overlap loop. |
| O4 | M-BS-004 | 80 | High | `setup-floci.sh:512-513` (`detect_hostname_and_ip`) | **`SERVER_IP="$(ip route get 1.1.1.1 2>/dev/null \| awk '{...}' \|\| true)"` — the `\|\| true` suppresses ALL failures including `awk` parse failures, leaving `SERVER_IP` empty silently.** The subsequent `[[ -z "$SERVER_IP" ]]` check on line 516 catches this, but the `|| true` masks the distinction between "ip route failed" and "awk produced no output." This is a silent-failure pattern the bash-scripting skill explicitly warns against. A more precise pattern would separate the command from the parse: capture `ip route` output, then parse separately with error reporting. | Replace the `|| true` with a more targeted error path, or add a diagnostic when `ip route` succeeds but `awk` yields empty. |
| O5 | M-BS-005 | 78 | Moderate | `dev-twin.sh:334` (`_run_as_floci_guest`) | **`_run_as_floci_guest` passes `"$*"` (all args joined) into a single `bash -c` string.** This is the same word-splitting class as CH-AUTH-008 (SPEC-BS-004) but in a different function. If any argument contains a single quote, the inner `bash -c '...'` breaks. The function builds: `sudo -u floci env ... $*` — unquoted `$*` inside a double-quoted `bash -c` string. Arguments with spaces or special chars (`$`, backticks) would be re-interpreted by the inner shell. This is a **command injection vector** if any caller passes user-controlled data. Current call sites pass static strings (e.g., `'systemctl --user start floci.service'`), but the pattern is a latent trap. | Use `printf '%q'` to shell-escape each argument, or pass arguments as positional parameters to `bash -c '...' "$@"` rather than joining into the script string. |
| O6 | M-BS-006 | 75 | Moderate | `setup-floci.sh:790-804` (`generate_presign_secret`) | **`PRESIGN_SECRET="$(openssl rand -hex 32)"` — no error check on `openssl` failure.** If `openssl` is absent or fails (e.g., `openssl rand` errors), `PRESIGN_SECRET` is empty and `write_env_file` writes `FLOCI_AUTH_PRESIGN_SECRET=` (empty) to the env file. An empty presign secret means all presigned URLs are accepted with no signature verification — a security bypass. The primary's SPEC-BS-009 adds `openssl` to the preflight, which mitigates the "absent" case, but does NOT add a post-generation `[[ -n "$PRESIGN_SECRET" ]]` assertion for the "present but failed" case. | Add `[[ -n "$PRESIGN_SECRET" ]] \|\| { printf 'ERROR: failed to generate presign secret\n' >&2; exit 1; }` after the `openssl rand` call. |
| O7 | M-BS-007 | 72 | Moderate | `setup-floci.sh:268-273` (`write_quadlet_unit`) | **`publish_ports` is built by string concatenation in a `for` loop with `$'\n'` joins, then trimmed with `${publish_ports%$'\n'}`.** This works but is fragile — if the `FLOCI_PORTS_CONTAINER` array is empty, `publish_ports` is empty and the trim is a no-op (fine). But the heredoc at line 288 inserts `${publish_ports}` on its own line unconditionally; an empty value produces a blank line in the Quadlet file. ShellCheck SC2086 would flag the unquoted expansion. A more robust approach builds the port lines as an array and joins, or guards the line with a conditional. | Guard the `${publish_ports}` line: only emit it if non-empty, or build via array join. |
| O8 | M-BS-008 | 70 | Moderate | `run-test.sh:229` (`wait_driver`) | **`wait "${DRIVER_SHELL_PID:-}" 2>/dev/null \|\| status=$?` — the `2>/dev/null` suppresses the "wait: <empty>: no such job" error but the `|| status=$?` captures 127.** The primary's SPEC-BS-019 fixes the empty-PID case, but the primary misses that the existing `2>/dev/null` also suppresses legitimate wait errors (e.g., the job was already reaped by a signal). The `|| status=$?` pattern means ANY non-zero wait exit (not just the empty-PID 127) sets `status`, and the subsequent `[[ "$status" -ne 0 ]]` treats it as "driver exited nonzero despite DONE." A killed-by-signal driver (status 143) would be misattributed as a failure — which is exactly the CH-AUTH-010 concern the primary notes but does not fix in SPEC-BS-019. | After fixing the empty-PID guard, also distinguish signal-kill (128+N) from genuine non-zero exit, per CH-AUTH-010. |
| O9 | M-BS-009 | 68 | Low | `setup-floci.sh:653-661` (`enable_lingering`) | **`for (( i=1; i<=USER_MANAGER_POLL_TRIES; i++ )); do` — the C-style for loop is a bashism.** Acceptable given the shebang, but the primary's portability assessments should note this. More importantly, `(( i++ ))` under `errexit` returns exit status 1 when `i` is 0 (the arithmetic-zero trap from the bash-scripting skill §2.2). Here `i` starts at 1 so `i++` evaluates to 1 (non-zero, exit 0) — safe by luck of the starting value. If anyone changes the start to 0, `set -e` would abort the loop on the first iteration. | Either start at 1 (current, safe) and document why, or use `(( i++ )) \|\| true` defensively. |
| O10 | M-BS-010 | 65 | Low | `dev-twin.sh:82-89` (`preflight_ports`) | **`conflicts="${conflicts}${port}\n"` builds a string with literal `\n` (backslash-n, not newline) then later uses `printf '%b'` to interpret it.** This works but is obscure — `printf '%b'` interprets backslash escapes, which is a deliberate but non-obvious choice. A clearer pattern would append to an array and join with newlines, or use `printf -v`. The current pattern is correct but hard to maintain. | Consider array-based accumulation for clarity; no functional change needed. |

## Recommendations

| # | Recommendation | Confidence | Priority | Links |
|---|---------------|-----------|----------|-------|
| R1 | **Correct the `printf '%q'` version claim in the References table.** It is NOT bash 4.0+; it works on 3.2.57. Reframe SPEC-BS-005's recommendation: the guard is needed for empty-array `set -u` safety on 3.2, not for `printf '%q'. | 95 | High | D1 |
| R2 | **Reconsider the bash-4+ precondition recommendation.** The existing codebase deliberately supports bash 3.2 on the host side (parallel arrays, guards). Do not add a version precondition unless the project explicitly decides to drop 3.2 support. | 80 | Medium | D2 |
| R3 | **Split SPEC-BS-005 into two findings:** (a) guard retention for `set -u` empty-array safety, (b) `[*]`→`[@]` for multi-element array correctness under `IFS=$'\n\t'. These are independent bugs with independent justifications. | 90 | High | D3 |
| R4 | **Add a post-generation assertion for `PRESIGN_SECRET`.** SPEC-BS-009 adds the preflight but not the runtime check. An empty secret is a security bypass. | 80 | High | O6 |
| R5 | **Add numeric validation to `configure_subuid_subgid` overlap loop.** Non-numeric `/etc/subuid` content would abort under `set -e` with an opaque "integer expression expected" error. | 82 | High | O3 |
| R6 | **Document the `_run_as_floci_guest` injection surface.** The `"$*"` join into `bash -c` is a latent trap. At minimum, document that callers must not pass untrusted data; ideally, refactor to use positional parameters. | 78 | Medium | O5 |
| R7 | **Refine portability assessments.** Replace blanket "None" with "N/A — bash-only construct (`<<<`/`$'...'`/`(( ))`), consistent with `#!/usr/bin/env bash` shebang" for accuracy. | 72 | Low | O2 |
| R8 | **Address the `wait_driver` signal-kill misattribution** jointly with CH-AUTH-010, which the primary notes but does not resolve in SPEC-BS-019. | 70 | Medium | O8 |

## Verdict

**CONDITIONAL PASS**

### Rationale

The primary BS analysis is thorough, well-structured, and largely correct. All 20 findings have concrete code sketches, portability assessments, and acceptance criteria. The `set -e` / `errexit` analysis (SPEC-BS-002) is correct and independently verified. The `IFS` word-splitting analysis (SPEC-BS-004) is correct and verified. The array-guard analysis (SPEC-BS-005) reaches the right conclusion (retain the guard) but for a partially wrong reason (the `printf '%q'` version claim is false).

### Blocking Findings (confidence ≥80)

- **D1 (conf 95):** The `printf '%q'` version claim is a factual error in the References table. It must be corrected before implementation, because the false premise drives the bash-4+ precondition recommendation (D2), which would break the project's deliberate bash-3.2 host-side compatibility.
- **D2 (conf 80):** The bash-4+ precondition recommendation contradicts the existing codebase's deliberate 3.2 support (parallel arrays at run-test.sh:455-456). Must be resolved before implementation.
- **R3 (conf 90):** SPEC-BS-005 bundles two independent fixes; both must be implemented but the second (`[*]`→`[@]`) is currently undocumented and could be missed.
- **O3 (conf 82):** Unvalidated arithmetic on file-read content in `configure_subuid_subgid` — a real `set -e` abort path.
- **O6 (conf 80):** Missing post-generation assertion for `PRESIGN_SECRET` — a security bypass if `openssl` fails at runtime (preflight doesn't cover runtime failure).

### Advisory Findings (confidence <80)

- O1, O4, O5, O7-O10 — robustness, clarity, and latent-trap observations that do not block but should be tracked.

### Conditions

1. **Correct the `printf '%q'` reference** (D1) — this is a factual error that must be fixed before the References table is used to drive implementation decisions.
2. **Resolve the bash-version precondition question** (D2) — do not add a bash-4+ gate to `run-test.sh` without explicitly deciding to drop the existing 3.2 compatibility effort.
3. **Split SPEC-BS-005** (R3) — document the `[*]`→`[@]` change as an independent correctness fix.
4. **Add `PRESIGN_SECRET` post-generation assertion** (O6/R4) — the preflight (SPEC-BS-009) is necessary but not sufficient.
5. **Add numeric validation to the subuid overlap loop** (O3/R5) — defends against malformed `/etc/subuid` content.
