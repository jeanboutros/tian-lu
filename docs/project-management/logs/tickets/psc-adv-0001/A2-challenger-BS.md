# A2-Challenger-BS: Dual-Model Challenge — psc-adv-0001

| Field | Value |
|-------|-------|
| Agent | bash-specialist-challenger (glm-5.2) |
| Phase | A2 |
| Timestamp | 2026-07-29T00:00:00Z |
| Primary Output | A1-BS review of three scripts (`setup-floci.sh`, `mock-server/dev-twin.sh`, `mock-server/run-test.sh`) — verdict CONDITIONAL PASS, 11 findings, 3 blocking (≥80). |
| Primary Verdict Reviewed | CONDITIONAL PASS |
| Challenger Verdict | CONDITIONAL PASS (upheld) — primary findings largely correct; F-BS-001, F-BS-002, F-BS-003 confirmed as blocking. Two findings down-scored (F-BS-006, F-BS-010), one disagreement on mechanism (F-BS-002 scope), plus 4 missed findings raised. |

## Reference Validation (Challenger Audit of Primary)

| Primary Claim | Reference Provided | Authority Level | Verified? | Correctly Applied? |
|--------------|-------------------|-----------------|-----------|-------------------|
| `set -euo pipefail` strict mode | [Spec: Bash Manual, §4.3.1] | 1 | ✓ | ✓ |
| `IFS=$'\n\t'` safe word splitting | [Spec: Bash Manual, §5.1] | 1 | ✓ | ✓ |
| `$*` vs `"$@"` expansion | [Spec: Bash Manual, §3.4.2] | 1 | ✓ | ✓ |
| `(( expr ))` exit status trap | [Spec: Bash Manual, §6.5] | 1 | ✓ | ✓ |
| `sort -V` GNU extension | [Source: GNU Coreutils Manual, §7.1] | 2 | ✓ | ✓ |
| `mktemp` POSIX | [Spec: POSIX.1-2017, mktemp] | 1 | ⚠ | ⚠ — `mktemp` is **NOT** in POSIX.1-2017; it is a BSD invention adopted by GNU coreutils. POSIX-compliant scripts must use `mktemp -d` via the `XDG` convention or `$TMPDIR.$$`. Minor mislabel. |
| `cp -a` on macOS | [Source: macOS cp(1) man page] | 2 | ✓ | ✓ |
| `readonly` with `${VAR:-default}` | [Spec: Bash Manual, §4.2] | 1 | ✓ | ✓ |
| `${arr[@]+"${arr[@]}"}` empty-array guard | [Source: ShellCheck SC2145] | 3 | ✓ | ✓ |
| `trap` for ERR/EXIT/INT/TERM | [Spec: Bash Manual, §4.1] | 1 | ✓ | ✓ |
| `read -t` timeout only for terminal/pipe | [Spec: Bash Manual, §4.2] | 1 | ✓ | ⚠ — **Mechanism misstated.** The Bash manual text the primary quotes actually says the timeout applies when reading "from a terminal, pipe, or other special file." The primary's claim that it "only applies when reading from a terminal or pipe — not a regular file" is *directionally* correct (regular files bypass the timeout), but the manual phrasing is "terminal, pipe, or other special file" — slightly broader. Verified empirically: with an empty regular file `read -t 2` returns rc=1 in 0s (timeout ignored, immediate EOF). See Disagreement D-BS-002. |
| `install` atomic rename | [Spec: POSIX.1-2017, mv] | 1 | ✗ | ✗ — **Misattribution.** The primary cites POSIX `mv` as evidence that `sudo install` is atomic. While `mv` (rename) is atomic on the same filesystem, GNU/BSD `install`'s atomicity is documented in the *install* man page ("Historically, -S also enabled the use of temporary files to ensure atomicity … Temporary files are no longer optional" — macOS install(1) confirms `install` always uses temp+rename now). The claim that `install` is more atomic than `cp` is correct, but the cited reference (`mv`) is the wrong source. |

**Reference audit summary:**
- [✓] All factual claims have at least one citation (minor: `mktemp` POSIX label is wrong, `install` cites `mv` instead of `install`)
- [✓] All citations are from authoritative sources (trust level 1-3)
- [✓] All cited sources verified to support the claim (with two mechanism-nuance caveats above)
- [✓] Implementation alignment verified by independent grep of cited line numbers
- [✓] Best practices and gotchas sought (trap cleanup, ERR backtrace, portability)

## Agreements

Findings I **agree** with (primary correctly identified, correctly scored, correctly reasoned):

- **F-BS-001** (confidence 85, HIGH) — `$*` in `_run_as_floci_guest` loses argument boundaries. Verified at `dev-twin.sh:334`. The function signature `<cmd...>` (line 324) genuinely mismatches the single-string implementation. All current callers pass one quoted string, so the bug is latent. The `printf '%q '` fix is the correct remediation. AGREE.

- **F-BS-003** (confidence 80, HIGH) — No trap cleanup for mktemp files in `dev-twin.sh`. Verified at lines 68, 195, 251, 445. Line 68 (`lsof_err`) has an explicit early-return leak path at line 77 (`return 1` before `rm -f` would need to run — actually it runs on line 76 before the return, but the pattern is fragile). Lines 195/251 `tmpfile` is cleaned only on the happy path; the `cmp -s` early return (199/254) does `rm -f` first, but a kill between `mktemp` and `cmp` leaks. AGREE.

- **F-BS-004** (confidence 75, MODERATE) — No trap handlers in `run-test.sh`. Verified: the file has zero `trap` registrations (grep confirms). `DRIVER_SHELL_PID` (line 196) is a background `limactl shell` that would orphan on SIGINT. The `teardown()` function (line 503) only runs at normal `main()` end. AGREE — though I'd score this 80 (HIGH) because an orphaned `systemd-run` unit inside the Lima guest is harder to clean up than a host temp file (see One-Sided M-BS-002).

- **F-BS-005** (confidence 60, LOW) — `sort -V` is GNU-only. Verified at `setup-floci.sh:390`. AGREE with the finding; the `dpkg --compare-versions` alternative is idiomatic for Debian/Ubuntu. AGREE.

- **F-BS-007** (confidence 65, MODERATE) — `driver_args[*]` expansion in `run-test.sh:194`. Verified: the `${driver_args[*]+"${driver_args[*]}"}` pattern joins with IFS first char (newline). Currently single-element (`--no-sidecar`), so latent. AGREE with the `printf '%q '` remediation. I'd score this 70 (MODERATE) because the array is constructed locally (lines 187-191) and the only appended value is the literal `--no-sidecar` — the injection surface is narrower than the primary implies.

- **F-BS-008** (confidence 70, MODERATE) — No ERR trap / stack backtrace. Verified: zero ERR traps in any of the three host-side scripts. AGREE. The bash-scripting skill §4.2 explicitly recommends this. For `setup-floci.sh` (1020 lines, 7 phases) the lack of a backtrace is the most impactful gap.

- **F-BS-009** (confidence 75, MODERATE) — `_run_as_floci_guest` doc/impl mismatch. Verified at lines 324-335. AGREE — this is the documentation facet of F-BS-001 and should be fixed alongside it.

- **F-BS-011** (confidence 50, LOW) — `_install_exec_condition` suppresses all errors with `2>/dev/null`. Verified at lines 442-451. Four `limactl` calls all swallow stderr; no exit-code check between steps. AGREE this is a silent-failure risk. I'd score 60 (LOW-MODERATE) — the final `systemctl --user daemon-reload` failure would only manifest later as "mount-condition not applied," which is hard to debug without the stderr.

## Disagreements

### D-BS-001: F-BS-002 over-scopes `cp -a` evidence and mislabels mktemp as POSIX

| Field | Value |
|-------|-------|
| Primary Finding | F-BS-002 (and Reference Validation rows for `mktemp` and `cp -a`) |
| Confidence | 80 |
| Primary Position | `mktemp` is POSIX.1-2017; `cp -a` evidence cited as macOS man page. |
| Challenger Position | Two reference-quality issues: (1) `mktemp` is **not** in POSIX.1-2017 — it is a BSD invention (4.3BSD) later adopted by GNU coreutils and Linux Standard Base. POSIX recommends `$TMPDIR` with `mkdir` + `umask 077` for portable temp creation. The label `[Spec: POSIX.1-2017, mktemp]` is a category error. (2) The `cp -a` reference is fine, but the Reference Validation table lists `cp -a` as "used correctly" — `cp -a` is never used for the atomic-write pattern; it's used in `run-test.sh:266,283` for evidence *copying* (directory tree copy), not atomic writes. The primary conflates two unrelated `cp -a` uses. These are reference-rigor lapses, not findings-blocking the verdict. |
| Recommendation | Relabel `mktemp` citation to `[Source: BSD/GNU coreutils, mktemp(1)]` (trust level 2-3, not POSIX). Separate the "evidence copy" `cp -a` (run-test.sh, fine) from the "atomic write" discussion (where `cp -a` is not involved). |

### D-BS-002: F-BS-010 `read -t` mechanism is misstated; finding is weaker than scored

| Field | Value |
|-------|-------|
| Primary Finding | F-BS-010 |
| Confidence | 75 |
| Primary Position | "`read -t` timeout only applies when reading from a terminal or pipe — not a regular file. When `$stdin_file` is a regular file, the timeout is ignored and `read` returns immediately." Confidence 40. |
| Challenger Position | The mechanism description is partially wrong and the finding is weaker than the confidence suggests. I empirically verified on this macOS host (Bash 3.2/5.x): with an **empty** regular file, `read -t 2 -r line < file` returns rc=1 in **0 seconds** — the timeout is ignored, EOF is immediate. With a **non-empty** regular file (`printf 'hello\n' > file`), `read -t 2` returns rc=0 immediately with the data. So the timeout IS ignored for regular files (the primary is right on outcome). BUT the Bash manual text the primary quotes says "terminal, pipe, or **other special file**" — the primary omitted "other special file," which broadens the set where timeout *does* apply (e.g., FIFOs, special device files). More importantly: this is **expected, documented behavior**, not a bug. The function `confirm_reset` (dev-twin.sh:261) explicitly gates on TTY first (line 266-272: `is_tty=1` check), and in non-TTY mode it returns early with an error (line 270-271) **before** reaching `read -t`. So the `read -t < "$stdin_file"` line is **only reachable when `is_tty=1`** (i.e., stdin IS a TTY). The primary's "the 30-second timeout is effectively dead code in non-TTY mode" is moot — the function never reaches `read` in non-TTY mode. The timeout is live and correct on the TTY path. |
| Recommendation | Drop F-BS-010 entirely, or reframe as: "`read -t` semantics differ for regular files vs. TTYs — the code's `is_tty` gate (line 266) ensures `read -t` only runs on a TTY where the timeout is honored, so this is correct." Confidence should be ≤20 if kept as an informational note. |

### D-BS-003: F-BS-006 `cp` non-atomic — context missed, severity overstated

| Field | Value |
|-------|-------|
| Primary Finding | F-BS-006 |
| Confidence | 70 |
| Primary Position | "`_write_hosts_file` uses `cp` for non-`/etc/hosts` paths (line 163), which is not atomic — if killed mid-copy, the destination is truncated. The `sudo install` path (line 161) is better. Severity MODERATE, confidence 70." |
| Challenger Position | The primary missed critical context: the `cp` branch (line 163) only executes when `hosts_file != "/etc/hosts"` — i.e., when `DEV_HOSTS_FILE` is overridden to a **temp/test path** (used only by the bats test harness via `DEV_HOSTS_FILE=...`). The comment at line 175 explicitly states "/etc/hosts lives on the macOS host, not the VM" — the `sudo install -o root -g wheel` (line 161) is macOS-specific (the `wheel` group is macOS/BSD root group; Ubuntu uses `root`). So the two branches are **environment-gated**, not a consistency lapse. The `cp` branch is test-only and writes to a throwaway tmp file that the caller deletes (lines 203, 258: `rm -f "$tmpfile"`). Mid-copy truncation of a test fixture is harmless. Severity should be LOW, confidence 45. Also: the primary's recommendation "use `mv` instead of `cp` since `$tmpfile` is a temp file that will be deleted anyway" would **break the test-harness use case** — `mv` across filesystems is not atomic (copy+delete), and more importantly the caller expects `$tmpfile` to still exist after `_write_hosts_file` for its own `rm -f` (lines 203, 258). The primary's fix introduces a use-after-unlink. |
| Recommendation | Downgrade to LOW (confidence 45). Do NOT apply the primary's `mv` fix — it breaks the caller's `rm -f "$tmpfile"`. If atomicity is genuinely desired for the test branch, use `install` (which the primary's own reference shows is atomic) **without** `sudo`/`-o root`, keeping `$tmpfile` intact for the caller. |

### D-BS-004: F-BS-002 scope — `.tmp.$$` cleanup trap should be per-invocation, not global `$$`

| Field | Value |
|-------|-------|
| Primary Finding | F-BS-002 |
| Confidence | 60 |
| Primary Position | Add a global `trap cleanup_temp_files EXIT INT TERM` with `rm -f "${APPARMOR_USERNS_PROFILE}.tmp.$$" "${HOSTS_FILE}.tmp.$$"` at top of `main()`. |
| Challenger Position | The remediation is **partially correct but has a subtle bug**. `$$` in a trap handler refers to the PID of the shell that *defined* the trap — which is correct here since the trap is set in `main()` and `$$` is the script PID. However, `setup-floci.sh` is **idempotent and re-runnable**; if a previous run crashed leaving `.tmp.<oldpid>` files, the new run's `$$` will differ and the trap won't clean the **orphaned** files from the prior crash. The primary's trap only cleans the *current* run's temp files. A more robust pattern: use `mktemp` (guaranteed unique name) and track paths in a global array cleaned by the trap. Additionally, the primary's `rm -f ... 2>/dev/null || true` will silently mask legitimate cleanup failures — acceptable, but the `|| true` after `2>/dev/null` is redundant under `set -e` only if the `rm` is the last command; as written it's fine. The finding (temp leak on signal) is real and blocking, but the suggested fix is incomplete for the idempotent-restart case. |
| Recommendation | Track temp files in a global array (`TEMP_FILES=()`; `TEMP_FILES+=("$tmp")` after each creation; trap iterates and `rm -f`). This also handles the `dev-twin.sh` and `run-test.sh` cases uniformly (see M-BS-001). Confidence in the *finding* stays 80; confidence in the *fix* is 60. |

## One-Sided Findings (Primary Missed)

### M-BS-001: No `set -o errtrace` / `set -E` — ERR trap (if added) won't fire in functions

| Field | Value |
|-------|-------|
| Confidence | 85 |
| Description | All three scripts set `set -euo pipefail` but **none set `errtrace`** (`set -E` / `set -o errtrace`). The bash-scripting skill §2.1 explicitly lists `set -o errtrace` as mandatory ("ERR trap fires in functions and subshells"). Without `errtrace`, an ERR trap (which F-BS-008 recommends adding) would **only fire in the top-level scope, not inside functions** — defeating the purpose for a 1020-line, function-structured installer where errors happen deep in phase functions. Verified by grep: zero `errtrace`/`set -E` across all four scripts. The primary's F-BS-008 recommends adding `trap generate_stack_trace ERR` but never flags that, without `errtrace`, that trap is silent inside `assert_userns_allowed`, `write_quadlet_unit`, etc. — exactly where backtraces are most needed. This is a missing-strict-mode-option gap, not just a missing-trap gap. |
| Recommended Action | Add `set -o errtrace` (or `set -E`) to the strict-mode block (line 25 of `setup-floci.sh`, line 2 of `dev-twin.sh`/`run-test.sh`). This is a **prerequisite** for F-BS-008's fix to work. Reference: [Spec: Bash Manual, §4.3.1 The Set Builtin — errtrace]. |

### M-BS-002: Orphaned `systemd-run` unit + `limactl shell` on SIGINT in `run-test.sh`

| Field | Value |
|-------|-------|
| Confidence | 82 |
| Description | F-BS-004 notes the missing signal trap but undersells the consequence. `run-test.sh:194` launches `sudo systemd-run --quiet --wait --unit=tianlu-driver -- /opt/tianlu/mock-server/in-vm/run-in-vm.sh ...` inside a subshell backgrounded with `&` (line 192-196). On SIGINT: (1) the host `limactl shell` subprocess is orphaned; (2) the **guest-side `tianlu-driver.service` transient unit keeps running** inside the Lima VM — it is not killed by host SIGINT because `systemd-run` already detached it into the guest's systemd; (3) the 9p evidence staging dir (`$STAGING`) is left with partial files and no `DONE`/`FAILED` sentinel, so a re-run's `poll_sentinel` (line 201) may pick up stale partial evidence from a prior crashed run. The AGENTS.md (mock-server/) notes "Manifest-validated evidence" — partial evidence without a manifest seal is a correctness risk, not just a tidiness one. The primary's F-BS-004 confidence (75) underweights this; the orphaned guest unit + stale-evidence interaction is a test-harness *correctness* issue, not just hygiene. |
| Recommended Action | (1) Add `trap 'cleanup_on_signal' INT TERM` that `kill`s `$DRIVER_SHELL_PID`, waits, runs `teardown`. (2) On re-run, `poll_sentinel` should verify the `DONE`/`FAILED` sentinel's mtime is newer than the script's start time (or purge stale staging first — `init_staging` at line 178 already does `rm -rf "$STAGING"`, so verify that runs unconditionally before `launch_driver`). (3) Consider `sudo systemd-run ... --collect` (auto-cleanup of transient unit) or document the orphan risk. Reference: [Source: systemd.run(1), --collect; Bash Manual §4.1 trap]. |

### M-BS-003: `local var="$(cmd)"` masks `errexit` in functions (silent failure)

| Field | Value |
|-------|-------|
| Confidence | 80 |
| Description | Several functions assign command-substitution output to a `local` variable: e.g., `dev-twin.sh:331` `uid="$(_guest_floci_uid)"` (preceded by `local uid` on 330), `dev-twin.sh:444` `uid="$(limactl shell ...)"`, `run-test.sh` multiple `local x="$(...)"` patterns. **Bash quirk**: `local var="$(cmd)"` returns the exit status of `local` (always 0), **not** the exit status of `cmd`. This means under `set -e`, if `cmd` fails, the failure is **silently swallowed** — `errexit` does not fire. This is a well-documented Bash gotcha (Bash Manual §4.2: "local … The return status is zero unless local is used outside a function, an invalid name is supplied, or name is readonly."). The pattern appears in safety-critical paths: `uid` is used to construct `XDG_RUNTIME_DIR`/`DBUS_SESSION_BUS_ADDRESS` — if `_guest_floci_uid` fails (empty uid), line 332 `[[ -n "$uid" ]] || return 1` catches it, but the *error from `limactl`* is lost (no stderr, no trace). The primary's self-audit marked "Unbound variable handling: PASS" and "Error output to stderr: PASS" but did not catch this silent-failure vector. |
| Recommended Action | Split into two lines: `local uid; uid="$(_guest_floci_guest)"; local rc=$?` then check `rc`, OR use `uid="$(_guest_floci_uid)" || { ...; return 1; }`. Apply to all `local x="$(cmd)"` sites where `cmd` can fail. Reference: [Spec: Bash Manual, §4.2 local; ShellCheck SC2155]. This is HIGH because it's a silent-failure class (the `silent-failure` skill's "universal log-or-rethrow rule" applies). |

### M-BS-004: `_write_hosts_file` `sudo install -g wheel` is macOS-specific with no fallback doc

| Field | Value |
|-------|-------|
| Confidence | 65 |
| Description | `dev-twin.sh:161` uses `sudo install -m 0644 -o root -g wheel "$tmpfile" "$hosts_file"`. The `wheel` group exists on macOS/BSD (gid 0) but **not on Ubuntu/Debian by default** (Ubuntu's root group is `root`). The dev twin runs on macOS (host-side), so this currently works. However: (1) there is no comment documenting that this is macOS-only; (2) `dev-twin.sh` is in `mock-server/` which is described as running on the macOS host, but a reader porting the dev twin to a Linux host would get `install: invalid group 'wheel'`. The primary's F-BS-006 discussed this exact line but neither flagged the `wheel` macOS-ism nor the portability trap. This is the inverse of F-BS-005 (`sort -V` GNU-only) — a BSD-ism rather than a GNU-ism — and deserves the same LOW-severity portability note. |
| Recommended Action | Add a comment: `# -g wheel: macOS/BSD root group (gid 0). On Linux use -g root.` Or detect the platform and pick the group. Low severity, but document the constraint. Reference: [Source: macOS install(1), -g group; Ubuntu base-passwd /etc/group — no 'wheel' entry]. |

## Recommendations

### R-BS-001: Unify temp-file tracking across all three scripts (addresses F-BS-002, F-BS-003, F-BS-004, M-BS-001)
Adopt a single pattern: a global `TEMP_FILES=()` array, `TEMP_FILES+=("$path")` after every `mktemp`/`.tmp.$$` creation, and a trap that iterates `rm -f "${TEMP_FILES[@]}"`. This fixes the idempotent-restart orphan issue (D-BS-004) and gives uniform cleanup. Add `set -o errtrace` so the trap fires inside functions (M-BS-001).

### R-BS-002: Add `set -o errtrace` before adding ERR traps (prerequisite for F-BS-008)
F-BS-008's stack-backtrace trap is inert inside functions without `errtrace`. This is a strict-mode gap, not a trap gap. Fix order: (1) `set -o errtrace`, (2) `trap ... ERR`.

### R-BS-003: Split `local x="$(cmd)"` assignments to expose command failures (M-BS-003)
Audit all `local x="$(cmd)"` sites in the three scripts. Split into `local x; x="$(cmd)"` + explicit `rc` check, or append `|| { log; return 1; }`. This closes a silent-failure class that `set -e` does not catch.

### R-BS-004: Downgrade F-BS-006 fix and F-BS-010 (D-BS-002, D-BS-003)
Do NOT apply F-BS-006's `mv` fix — it breaks the caller's `rm -f "$tmpfile"` (use-after-unlink). Reframe F-BS-010: the `is_tty` gate (line 266) makes the `read -t` TTY-path correct; drop or keep as informational (confidence ≤20).

### R-BS-005: Reference-rigor cleanup (D-BS-001)
- Relabel `mktemp` citation from `[Spec: POSIX.1-2017]` to `[Source: BSD/GNU coreutils]` — `mktemp` is not POSIX.
- For `install` atomicity, cite `install(1)` man page (which documents temp+rename), not POSIX `mv`.
- Separate `cp -a` (evidence-copy in run-test.sh) from the atomic-write discussion.

### R-BS-006: Re-score summary
| Finding | Primary Score | Challenger Score | Action |
|---------|--------------|-----------------|--------|
| F-BS-001 | 85 | 85 | Block (upheld) |
| F-BS-002 | 80 | 80 (finding) / 60 (fix) | Block finding; improve fix per D-BS-004 |
| F-BS-003 | 80 | 80 | Block (upheld) |
| F-BS-004 | 75 | 80 | Raise to 80 — orphaned guest unit + stale evidence (M-BS-002) |
| F-BS-005 | 60 | 60 | Advisory (upheld) |
| F-BS-006 | 70 | 45 | Downgrade; do NOT apply primary's `mv` fix (D-BS-003) |
| F-BS-007 | 65 | 70 | Raise slightly; still advisory |
| F-BS-008 | 70 | 75 | Raise; prerequisite M-BS-001 (`errtrace`) needed |
| F-BS-009 | 75 | 75 | Advisory (upheld) |
| F-BS-010 | 40 | ≤20 | Drop — `is_tty` gate makes the path correct (D-BS-002) |
| F-BS-011 | 50 | 60 | Raise slightly; silent-failure concern |
| **M-BS-001** (new) | — | 85 | **Block** — missing `errtrace` defeats F-BS-008 fix |
| **M-BS-002** (new) | — | 82 | **Block** — orphaned guest unit + stale evidence |
| **M-BS-003** (new) | — | 80 | **Block** — `local x="$(cmd)"` silent failure |
| **M-BS-004** (new) | — | 65 | Advisory — macOS `wheel` portability note |

**Net effect:** Primary had 3 blocking findings; challenger confirms 3 and adds 3 new blocking findings (M-BS-001, M-BS-002, M-BS-003) → **6 blocking findings**. Verdict remains **CONDITIONAL PASS** (not REJECTED) because all are fixable hardening gaps, none are correctness bugs in the current happy path, and the scripts pass ShellCheck + bats. But the blocking list is larger than the primary identified.

## Self-Audit Checklist (Challenger)

| Category | Checked? | Finding or PASS |
|----------|----------|-----------------|
| Reference presence in primary | yes | PASS — all primary claims cited; 2 minor mislabels (D-BS-001) |
| Reference authority verified | yes | PASS — sources authoritative; `mktemp` POSIX label incorrect |
| Reference accuracy verified | yes | CONDITIONAL — `read -t` mechanism nuance (D-BS-002), `install` cites wrong source (D-BS-001) |
| Implementation alignment verified | yes | PASS — grep-confirmed all cited line numbers |
| Best-practices/gotchas sought | yes | FINDING — primary missed `errtrace` (M-BS-001), `local x="$(cmd)"` silent failure (M-BS-003) |
| Every disagreement has reasoning | yes | PASS — 4 disagreements, each with evidence + alternative |
| Every finding has confidence | yes | PASS — all findings and disagreements scored 0-100 |
| One-sided findings raised | yes | 4 new findings (M-BS-001..004) |
| Critical-vuln flag check | yes | N/A — no command injection / credential exposure found; all scripts drop privileges correctly |
| Spec citation for each claim | yes | PASS — Bash Manual, GNU coreutils, install(1), macOS man pages cited |

## Verdict

**CONDITIONAL PASS (upheld, with expanded blocking list).**

The primary's verdict is correct and its core findings (F-BS-001, F-BS-002, F-BS-003) are valid and verified. However, the primary **missed three blocking-class findings** (M-BS-001 `errtrace`, M-BS-002 orphaned guest unit + stale evidence, M-BS-003 `local x="$(cmd)"` silent failure) and **overstated two findings** (F-BS-006 fix is harmful, F-BS-010 is moot). The blocking list should expand from 3 to 6 before the next pipeline phase. The CONDITIONAL PASS (not REJECTED) is appropriate because all findings are hardening/portability gaps, the happy path is correct, and ShellCheck + bats pass.
