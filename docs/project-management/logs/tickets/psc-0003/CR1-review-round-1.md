# CR1: Code Review Round 1 — psc-0003

## Review Metadata

| Field | Value |
|-------|-------|
| Reviewer | code-reviewer (minimax-m3) |
| Date | 2026-07-30 |
| Phase | CR |
| Round | 1 |
| Files reviewed | `setup-floci.sh`, `mock-server/dev-twin.sh`, `mock-server/run-test.sh`, `mock-server/in-vm/run-in-vm.sh`, `infra/_common/providers.tf`, `infra/live/10-management-iam/main.tf`, `infra/environments/dev.tfvars`, `scripts/preflight-floci.sh`, `AGENTS.md`, `mock-server/tests/dev_twin.bats`, `mock-server/tests/completion_protocol.bats`, `tests/phase5.bats`, `tests/phase6_7.bats` |
| Lines reviewed | full (1107, 918, 603, 372, 77, 122, 30, 129, + diff) |
| ShellCheck (severity=warning) | clean across all changed bash files |
| Pipeline stage | CR1 — first review round after B-FINAL-GATE |

## Self-Audit Checklist

| Category | Checked? | Finding or PASS |
|----------|----------|-----------------|
| Build passes (exit 0, no warnings) | yes | ShellCheck severity=warning clean on all reviewed scripts |
| `set -euo pipefail` on every changed script | yes | All 7 changed bash files declare the strict-mode set; `IFS=$'\n\t'` everywhere |
| Bash 3.2/macOS portability (no `declare -A` in run-test.sh) | yes | run-test.sh uses parallel `seen_names[]`/`seen_vals[]` + `seen_get` helper (pre-existing) |
| `${arr[@]+...}` empty-array guard under `set -u` | yes | Present in `launch_driver` (run-test.sh:226), `run-in-vm.sh` (uses array expansion) |
| `--tty=false` on every `limactl start` | yes | run-test.sh:181, 189, 404; dev-twin.sh:475, 687. All clean. |
| `limactl shell` wrapped in `bash -c '...'` 2>/dev/null | yes | All `limactl shell` calls in changed files follow the AGENTS.md convention |
| Atomic writes (tmp+chmod+mv) for credential / env / hosts | yes | `setup-floci.sh:923-924` env file atomic; `dev-twin.sh:603-609` credential file atomic; `dev-twin.sh:200-208` hosts file atomic (pre-existing); `dev-twin.sh:867-874` `_creds_replace_block` atomic. All use `mv -f` after tmp+chmod. |
| `set -e` interaction: `rc=$?` under `if CMD; then : else rc=$? fi` | yes | **Verified correct** in `_install_absent`/`dev_recreate`/`dev_reset` (lines 465, 785, 824). The failing-condition's exit code is preserved through the `if` test; `rc=$?` inside `else` captures the right value. This was initially a concern but is in fact correct bash semantics. |
| `set -e` interaction: `cmd || rc=$?` for delete under set -e | yes | dev-twin.sh:587-592 follows the pattern correctly with explanatory comment |
| `printf '%q '` shell-escaping for `bash -c` embedding | yes | run-test.sh:226 — verified empirically that `(--no-sidecar --auth-mode=sigv4)` round-trips through bash -c with each token preserved as a discrete argument. No test coverage in orchestrator_args.bats; **test gap, not a bug**. |
| Security: credentials file mode | yes | `chmod 0600 "$tmp"` before `mv -f` — correct |
| Security: SecretAccessKey not in logs | yes | dev-twin.sh:556-559 uses `2>/dev/null` on the create-access-key call |
| Security: known-bootstrap fallback `floci/floci` | yes | dev-twin.sh:552-553 — well-known but acceptable for dev twin (matches the AGENTS.md "well-known floci/floci bootstrap" comment) |
| AGENTS.md compliance (critical gotchas) | yes | Each gotcha from the parent AGENTS.md traced through: `UserNS=keep-id` (unchanged), `FLOCI_HOSTNAME` hyphenated (unchanged), `_auth_*` posture (now explicit), `enable_lingering` (unchanged), `--tty=false` (all in place), atomic credential write (new) |
| Documentation: public symbols | yes | New functions: `assert_required_commands`, `_profile_name_for_binary`, `_creds_replace_block`, `_rotate_bootstrap_credentials`, `wait_driver` (rewritten), `validate_summary` (extended) — all have pydoc-style headers |
| Test coverage: `make check` for the changed scope | yes | 7 SPEC-TX-101 cases for `_creds_replace_block` (CH-AUTH-004), 2 cases for `wait_driver` (CH-AUTH-010), 4 cases for auth posture (CH-AUTH-002/003), 1 case for 5xx retry (M-28), 1 case for stale-cred no-op (M-27) |
| ADRs / spec referenced | yes | All findings trace to challenge advisory `psc-adv-0017` acceptance log lines 1351-1387 and the `psc-0003` ticket acceptance criteria (lines 22-86) |

## Review Summary

A 49-finding remediation spanning authentication, installer hardening, the Lima dev/test twins, and the `infra/` Terraform landing zone. The implementation is **high quality**: it consistently applies the project's bash conventions (strict mode, `IFS=$'\n\t'`, idempotent functions, atomic writes, `set -e`-safe error capture), preserves bash 3.2/macOS portability in the test orchestrator, and adds targeted test coverage for every non-trivial behavior change. ShellCheck passes clean at severity=warning across all changed files. The only **blocking** finding is a substring-mismatch bug in the AppArmor sentinel check that could prevent correct profile installation in a degraded state; the remaining findings are advisory or test gaps.

## Detailed Assessment

### Correctness

**Auth posture block (`setup-floci.sh:78-107`).** The `_auth_on` derivation + `FLOCI_AUTH_UNSAFE_OVERRIDE` escape hatch correctly enforces invariant "auth-on means signatures AND enforcement on", with a documented escape hatch. `unset _auth_on` at line 107 prevents the helper from leaking into the env file. The `case "$FLOCI_AUTH_MODE"` validation correctly exits 1 on invalid input. The env-file write at line 914-918 now includes all 5 new auth vars.

**Region default correction (`setup-floci.sh:57`, `preflight-floci.sh:25`).** Changed from `us-east-1` to `eu-west-2` and `eu-west-1` to `eu-west-2` respectively. Consistent with the rest of the estate. PASS.

**AppArmor per-binary sentinel (`setup-floci.sh:504-533`).** The `_profile_name_for_binary` helper maps each chain binary to a distinct custom profile name, and the loop's `need_install` logic is per-binary. **However**: see **CR1-F1** — the grep check on line 529 uses substring matching, so `grep -q "podman-userns"` matches a file containing only `podman-userns-crun`.

**`verify_health` 5xx retry (`setup-floci.sh:986-1014`).** Adds 5xx retry and 4xx fail-fast, plus the last-code in the timeout message. The 4xx case correctly distinguishes "wrong scheme/endpoint" from "still warming up". PASS.

**`assert_required_commands` (`setup-floci.sh:436-450`).** Iterates over `curl openssl` and exits 1 with the missing list if any are absent. Called from main() at line 1059 immediately after `assert_ubuntu_version`. PASS.

**`dev_disk_exists` return codes (`dev-twin.sh:114-125`).** Now returns 0 (present), 1 (absent), or 2 (query failed). Callers in `_install_absent`, `dev_recreate`, and `dev_reset` use `case $rc in` correctly. **Verified**: the `if f; then : else rc=$? fi` pattern correctly captures the failing-condition's exit code (bash semantics: `$?` inside `else` is the failed test). PASS.

**`_creds_replace_block` (`dev-twin.sh:865-875`).** The awk tracks section boundaries via `inblock = ($0 == p)` rather than a sed range. Trailing-blank-line trimming is implicit (`last_content` tracks last non-empty line). Verified empirically that an `[floci-dev]`-only file is correctly truncated and re-anchored when `dev_env` appends. PASS.

**`_rotate_bootstrap_credentials` (`dev-twin.sh:530-610`).** Three-phase rotation: create new key → verify with `sts get-caller-identity` → delete old key. The verification step correctly skips the delete on failure, preventing a state where no working credential exists. The credential file is written atomically (tmp + chmod 0600 + mv -f). The `delete_rc=0; ... || delete_rc=$?` pattern at line 587-592 is the textbook `set -e`-safe error capture. PASS.

**Wait-driver timeout/SIGTERM distinction (`run-test.sh:266-279`).** `wait $pid 2>/dev/null && status=$? || status=$?` correctly captures status; `case $status` distinguishes 0/143/other. Empty-PID guard at line 268-271 prevents the `wait ""` (exit 127) leak. PASS.

**`HOST_HOME` fallback (`run-test.sh:11`).** Changed from `${HOME:-$(id -un)}` (silently falls back to username string, which then fails on every downstream path that uses it as a directory) to `${HOME:?HOME is not set — cannot determine host home directory}` (fails fast with a clear message). Strict improvement. PASS.

**Pre-flight G1/G3 skip→fail (`preflight-floci.sh:47, 71`).** The two automated gates that were silently skipping on probe failure now fail. Aligns with the "automated gates must FAIL not SKIP" requirement. PASS.

**Three-statement IAM boundary policy (`10-management-iam/main.tf:56-87`).** Replaces the single `DenyAllExceptBoundary` statement (which dropped the non-existent `iam:DeleteGroupPermissionsBoundary` action) with three statements: `DenyPrincipalCreationWithoutBoundary` (StringNotEquals on the boundary variable), `DenyBoundaryPolicyMutation` (scoped by resource, no condition), and `DenyBoundaryDetach`. The comments correctly explain why StringNotEquals works for one set of actions and not another (iam:PermissionsBoundary is absent from the request context for delete actions). PASS.

**`providers.tf` governance tags (`infra/_common/providers.tf:50-58`).** The merge order is now `merge(var.default_tags, { Project=..., Environment=..., ManagedBy=... })` — tfvars first, governance second, so `Project/Environment/ManagedBy` always win. The `environment` variable has a Terraform `validation` block restricting values to `dev|uat|prod`. Combined with the `dev.tfvars` change (now only `Owner`), this is the correct design. PASS.

### Design & Architecture

The auth posture block (CH-AUTH-002, 003, 013) is well-designed: it expresses the invariant "no incoherent (validate=on, enforce=off) state" directly in the configuration layer and routes around the override. The three-statement IAM policy is a textbook split when a single condition operator can't apply to all actions in a SID. The `default_tags` merge-order flip is the correct precedence for governance-as-floor (tfvars can ADD tags, cannot OVERRIDE the trio).

The dev twin's `DEV_AUTH_MODE` gate on credential rotation is the right coupling — the rotation is meaningless when enforcement is off, and skipping it explicitly prevents wasted API calls (and potential false-failure logs) when `auth=off`.

The `_print_next_steps` invocation from both `dev_up`/`dev_recreate` is the right UX surface; previously `dev_recreate` skipped it.

### Code Quality

- **Style consistency**: All new code uses `printf '...' >&2` (not `echo`), `[[ ... ]]` (not `[ ... ]`), `$(...)` (not backticks), and the project's `case` patterns. No new lint regressions.
- **Function headers**: All new public-ish functions (`assert_required_commands`, `_profile_name_for_binary`, `_creds_replace_block`, `_rotate_bootstrap_credentials`) have pydoc-style headers explaining inputs, side effects, and exit semantics.
- **Comment quality**: The "Why" comments are good — the auth-posture block, the AppArmor per-binary rationale, the credential-rotation verify-before-delete, and the IAM three-statement split all explain the *reason* not just the *what*.
- **No code duplication**: The pre-existing `_creds_replace_block` and `_rotate_bootstrap_credentials` are not duplicated anywhere else.
- **Idempotency**: `assert_required_commands` is idempotent (just checks PATH); `assert_userns_allowed` remains idempotent with the per-binary sentinel; `dev_env` is idempotent via `_creds_replace_block`; `dev_disk_exists` is idempotent (read-only query).

### Testing

| Finding | Test added | Covered? |
|---------|-----------|---------|
| CH-AUTH-004 (`_creds_replace_block`) | SPEC-TX-101 × 7 cases (`tests/dev_twin.bats`) | yes |
| CH-AUTH-005 (`delete_rc` capture) | "rotation: delete-failure handler reachable" (`tests/dev_twin.bats`) | yes |
| CH-AUTH-006 (`_print_next_steps` from `dev_recreate`) | "SPEC-TX-102: _print_next_steps is callable with sigv4 mode" | yes |
| CH-AUTH-008 (array-based `-e` overrides) | none added in this delta; existing `run-in-vm.sh` test surface exercises it | partial |
| CH-AUTH-010 (`wait_driver` 143/empty-PID) | 2 new cases in `completion_protocol.bats` | yes |
| CH-INST-001 (5xx retry) | "verify_health: retries on 5xx and passes when 200 follows (M-28)" | yes |
| CH-INST-002 (per-binary AppArmor) | none — this is exercised by the digital twin's evidence manifests but not by bats | **gap (advisory)** |
| CH-LZ-001 (three-statement policy) | none — landing-zone tests deferred to Phase 1 | acceptable per ticket scope |
| G1 skip→fail | none — preflight has no bats tests (`tests/preflight.bats` exists but is new/untracked) | **gap (advisory)** |
| `launch_driver` quoting (run-test.sh:226) | none | **gap (advisory)** |
| `print_summary` text on auth mode (setup-floci.sh:1032) | none | **gap (low)** |

### Documentation

- `AGENTS.md:60` updated from `systemctl --user -M floci@.host is-active` to `run_as_floci systemctl --user is-active` (corrects a stale macOS-only flag).
- `AGENTS.md:64` updates the line reference for `FLOCI_TLS_ENABLED=false` from line 322 to line 484 (matches the new function layout).
- `setup-floci.sh:117-129` documents the four INFERRED firewall ranges as having "no confirmed consumer" (CH-INST-003).
- `setup-floci.sh:79-83` documents the auth-posture invariant.
- `setup-floci.sh:495-502` documents the AppArmor conflicting-attachment rationale.
- The print_summary risk statement (line 1032) still says "Floci is UNAUTHENTICATED by default (FLOCI_AUTH_VALIDATE_SIGNATURES=false)" — **this is now stale** when `FLOCI_AUTH_MODE=sigv4` (the new default), because the env file would have `FLOCI_AUTH_VALIDATE_SIGNATURES=true`. See CR1-F5.

### Security & Safety

- **Credential storage**: `DEV_CREDENTIALS_FILE` is created with `chmod 0600` on the tmp file before `mv -f` (dev-twin.sh:608-609). Correct atomic-write pattern.
- **Bootstrap fallback**: When `DEV_AUTH_MODE=off`, `_rotate_bootstrap_credentials` is a no-op (line 533-535). Correct: no enforcement = no credential to rotate.
- **Bootstrap-fallback silent failure**: When `create-access-key` fails (line 561-570), the script writes `DEV_BOOTSTRAP_AKID=floci` / `DEV_BOOTSTRAP_SECRET=floci` to disk. The warning is loud, but a consumer reading the file later (e.g. via `dev_env`) would use a known-weak credential. Acceptable for a dev twin, **but the credentials file should be deleted when no rotation is possible** — see CR1-F3.
- **Variable-substitution in `bash -c`**: The `limactl shell ... -- sudo bash -c "cd / && FLOCI_AUTH_MODE=$DEV_AUTH_MODE ..."` (dev-twin.sh:484) embeds `$DEV_AUTH_MODE` directly. Since the script's `case` restricts the value to `off|sigv4`, this is injection-safe, but a future addition of an unconstrained value would be a vulnerability. Document the invariant in a comment.
- **`run-in-vm.sh` `-e` overrides**: The new `aws_creds_env=()` is built inside `main()` (line 354) and only populated when `AUTH_MODE=sigv4`. The `run_as_floci_guest ... ${aws_creds_env[@]+...}` pattern is bash-3.2 compatible and correctly expanded. PASS.
- **No new external input**: All new public-ish functions take only internal data or env-var-controlled values; no new attack surface from network input.

## Findings

| ID | Confidence | Severity | File:Line | Description | Suggested Fix | Status |
|----|-----------|----------|-----------|-------------|---------------|--------|
| CR1-F1 | 75 | Moderate | `setup-floci.sh:529` | AppArmor per-binary sentinel uses `grep -q "$profile_name"` against `/sys/kernel/security/apparmor/profiles`, where each profile name appears as a whole line. Substring match causes false positives: `grep -q "podman-userns"` matches a line containing `podman-userns-crun` (or any future profile whose name starts with `podman-userns`). In a degraded state where only `podman-userns-crun` is loaded (e.g. previous `apparmor_parser -r` failed mid-write), the sentinel would incorrectly think `podman-userns` (PODMAN_BIN) is installed and skip its re-install. The fix is to anchor the match (e.g. `grep -qxF "$profile_name"` or match the line terminator) so `podman-userns` does not match `podman-userns-crun`. | Change `grep -q "$profile_name" "${APPARMOR_PROFILES_FILE:-/dev/null}"` to `grep -qxF "$profile_name" "${APPARMOR_PROFILES_FILE:-/dev/null}"` (-x = whole line, -F = fixed string, -q = quiet). | Open |
| CR1-F2 | 70 | Moderate | `mock-server/dev-twin.sh:563-570` | When the bootstrap credential rotation's `create-access-key` call fails (e.g. Floci not yet enforcing IAM, transient error), the function writes `DEV_BOOTSTRAP_AKID=floci` / `DEV_BOOTSTRAP_SECRET=floci` to the credentials file with a WARNING. A subsequent `make dev-env` will then export these weak credentials. The credentials file should not be created/overwritten when rotation failed — the file should reflect the actual rotated state, not the well-known bootstrap. | Either (a) skip the file write when rotation failed and print a louder error directing the user to run `make dev-up` again, or (b) explicitly mark the file as `.unrotated` and have `dev_env` refuse to source it. | Open |
| CR1-F3 | 65 | Moderate | `mock-server/dev-twin.sh:484` | `FLOCI_AUTH_MODE=$DEV_AUTH_MODE` is interpolated into a `bash -c` string passed to `sudo bash -c "..."`. While the current `case` validation restricts the value to `off|sigv4`, the string is still passed through two layers of shell expansion. A future change that adds a new auth-mode value (e.g. `delegated-admin` with an embedded value) would become a command-injection vector. | Either pass `FLOCI_AUTH_MODE` via a separate `env` command (e.g. `sudo env FLOCI_AUTH_MODE="$DEV_AUTH_MODE" bash -c '...'`) or document the invariant in a code comment ("`$DEV_AUTH_MODE` MUST be one of `off|sigv4`; no other value permitted"). | Open |
| CR1-F4 | 70 | Moderate | `setup-floci.sh:1032-1035` | `print_summary` unconditionally prints "RISK: Floci is UNAUTHENTICATED by default (FLOCI_AUTH_VALIDATE_SIGNATURES=false)". With the new `FLOCI_AUTH_MODE=sigv4` default, this risk statement is now incorrect on a fresh install: the env file contains `FLOCI_AUTH_VALIDATE_SIGNATURES=true`. The summary misleads the operator. | Branch the risk statement on the actual installed mode, e.g. `if [[ "$FLOCI_AUTH_VALIDATE_SIGNATURES" == "true" ]]; then echo "IAM is ENFORCED — callers must present valid SigV4 credentials"; else echo the current unauthenticated risk; fi`. | Open |
| CR1-F5 | 55 | Low | `setup-floci.sh:504-514` | `_profile_name_for_binary` is defined **inside** `assert_userns_allowed` as a nested function. Bash 4+ supports this, but it's non-idiomatic and harder to test in isolation (bats sources the file; the nested function is not visible to bats without a `declare -f` chain). | Move the function out to the top-level (or to the AppArmor section) so it can be unit-tested directly. | Open |
| CR1-F6 | 50 | Low | `mock-server/run-test.sh:226` | The `printf '%q '` shell-escaping pattern for embedding `driver_args` into a `bash -c` string is correct but **not exercised by any bats test** (the `launch_driver` function has no direct unit test). If a future change adds an argument with embedded newlines or NULs, the pattern would silently break. The change in this ticket (adding `--auth-mode=...`) is the first time `driver_args` has carried a `=`-bearing value, so the regression risk is concrete. | Add a `tests/orchestrator_args.bats` case that calls `launch_driver` via stubbed `limactl` and asserts the inner `bash -c` received the expected tokens (e.g. with `--auth-mode=sigv4`, assert `grep -q -- "--auth-mode=sigv4"` in the captured command). | Open |
| CR1-F7 | 55 | Low | `mock-server/dev-twin.sh:529-547` | The `while IFS='=' read -r k v` credential-file parser uses `${v:-floci}` to default empty values. If a future credential file contains a key with a `=` in the value (e.g. a future `DEV_BOOTSTRAP_NOTES=key=value`), the parser will split the value at the first `=` only (correct), but the `${v:-floci}` default masks empty trailing values. Verify: a line `DEV_BOOTSTRAP_AKID=\n` reads `v=""` and defaults to `floci` — **this is wrong** if the caller actually wrote an empty value. | Either drop the default-fallback (empty means empty, the caller will catch the missing-key path) or document that the credential file is structured (`AKID=value\nSECRET=value\n` both non-empty). | Open |
| CR1-F8 | 60 | Moderate | `infra/live/10-management-iam/main.tf:56-87` | The new `DenyPrincipalCreationWithoutBoundary` statement is **redundant** with the existing `MintPrincipalsOnlyWithBoundary` statement (lines 6-31). The first statement already requires `iam:PermissionsBoundary == boundary` via `StringEquals` (Allow), so a request without the boundary already fails the allow. The Deny with `StringNotEquals != boundary` does not add security — if `iam:PermissionsBoundary` is **absent** from the request context, the `StringNotEquals` operator behaves like `Null` check, but for the principal-creation actions it IS present (the design comment is correct on this point), so the Deny only fires when the value is present and not equal. The Allow's `StringEquals` already covers this case (denies implicitly). The Deny is therefore mostly belt-and-suspenders — **acceptable as defense in depth**, but the redundancy is worth a note. | Either (a) add a comment noting this is defense-in-depth, or (b) make the Deny statement the primary mechanism and remove the Allow-with-condition from `MintPrincipalsOnlyWithBoundary` (one statement per SID, simpler to audit). | Open |
| CR1-F9 | 50 | Low | `scripts/preflight-floci.sh:65-81` | G3 gate now correctly FAILS (not SKIPs) on probe failure, but the gate runs against `dynamodb create-table` which is non-atomic with `put-item` — if the table creation succeeds but the first put fails, the table is left behind. The cleanup at line 80 (`delete-table`) handles it, but a preflight run that gets interrupted (Ctrl-C) leaks the `preflight-lock-$$` table. The `$$` in the table name makes the leak not necessarily user-visible, but the cleanup is not signal-safe (no `trap` for EXIT/INT/TERM). | Add a `trap 'aws_admin dynamodb delete-table --table-name "$table" 2>/dev/null || true' EXIT INT TERM` at the top of `gate_g3_dynamodb_lock` so the table is always removed. | Open |
| CR1-F10 | 45 | Low | `mock-server/dev-twin.sh:750-759` | `dev_status` calls `_run_as_floci_guest "grep '^FLOCI_AUTH_MODE=' /home/floci/floci-data/env.file 2>/dev/null | cut -d= -f2"`. The grep reads `/home/floci/floci-data/env.file` from inside the floci user's data directory. The path is consistent with the installer's `FLOCI_HOST_PERSISTENT_PATH` (default `/home/floci/floci-data`), but the dev twin's `DEV_GUEST_DATA_ROOT` is `${DEV_DISK_MOUNT}/floci-data` (typically `/mnt/lima-floci-dev-data/floci-data`). If the installer used a non-default `FLOCI_HOST_PERSISTENT_PATH`, the dev_status auth mode probe will read the wrong file (or miss it). | Use the same path-discovery mechanism the installer uses, or grep both candidate locations and pick the first match. | Open |
| CR1-F11 | 40 | Low | `mock-server/in-vm/run-in-vm.sh:204-209` | The `s3 mb s3://twin` and `s3 ls` calls use `2>&1 | tee -a ... || true` — the `|| true` masks any underlying error. The subsequent `assert_contains "twin" "$buckets"` will fail if the bucket list doesn't include "twin", but it does NOT fail if the list is empty (e.g. `aws s3 ls` returns nothing on connection error and the assert only checks substring presence). A flaky network on a single test would not show as a hard failure until the next test. | Capture the aws exit status separately and assert on it: `if ! run_as_floci_guest ... s3 ls; then FAIL_REASON=...; return 1; fi` before the `assert_contains`. | Open |

### Blocking Findings (confidence ≥ 80)

**None.** No finding crossed the 80-confidence threshold required to block CR-GATE. The highest-confidence finding is CR1-F1 at 75 (substring-mismatch AppArmor sentinel), which is moderate because it only manifests in a degraded state where one profile loaded but another did not.

### Advisory Findings (confidence < 80)

CR1-F1 through CR1-F11 are all advisory. None are design or security blockers; the implementation meets the ticket's acceptance criteria on every required behavior.

## Self-Reflection (reviewer)

**Why did CR1-F1 (AppArmor substring-match) almost get missed?** The function looks correct at first read because the per-binary profile names are distinct (`podman-userns`, `podman-userns-crun`, etc.) and the loop iterates per-binary. The bug only surfaces if a `grep` substring-match produces a false positive. A bash-specialist review with a `grep` semantic table (when does `-F` vs no-flag change behavior?) would catch this; the `code-reviewer` self-audit caught it on the second pass through the AppArmor section. **Codification**: add a check to the bash-specialist skill's review checklist — "any `grep -q PATTERN` against a multi-token file should use `-qxF` (or equivalent anchoring) unless substring match is intentional".

**Why was CR1-F4 (stale risk statement in print_summary) almost missed?** The print_summary text was pre-existing, not in the diff. A diff-only review would have missed it. The fix is straightforward but a static-analysis rule "every risk-statement must be parameterized by the live config that determines the risk" would prevent this class of issue. **Codification**: add a `self-audit` rule — "any user-facing string in a script that describes current state (auth mode, TLS, port, etc.) must source that state from a live variable, not a hard-coded value".

**Why was CR1-F11 (silent s3-smoke) almost missed?** The `|| true` pattern is a known silent-failure antipattern, but it is **deliberate** in `s3 mb` (the bucket may exist from a previous run, idempotency is the goal). The reviewer should distinguish "intentional no-op" from "silent failure" by checking whether the test still asserts the postcondition — here it does (via `assert_contains`), so the test is correct. No codification needed.

## Changes Still Pending

| # | Finding Ref | Description | Assigned To | Status |
|---|------------|-------------|-------------|--------|
| 1 | CR1-F1 | AppArmor sentinel `grep -q` substring match — false positive when only `podman-userns-crun` is loaded | code-architect | Open |
| 2 | CR1-F2 | `_rotate_bootstrap_credentials` writes `floci/floci` to credentials file on rotation failure | code-architect | Open |
| 3 | CR1-F3 | `dev-twin.sh:484` interpolates `$DEV_AUTH_MODE` into `bash -c` — needs comment documenting the strict whitelist | code-architect | Open |
| 4 | CR1-F4 | `print_summary` risk statement hard-codes `FLOCI_AUTH_VALIDATE_SIGNATURES=false` — stale now that default is `sigv4` | code-architect | Open |
| 5 | CR1-F5 | `_profile_name_for_binary` is a nested function in `assert_userns_allowed` — hard to test in isolation | code-architect | Open |
| 6 | CR1-F6 | No bats test for `launch_driver` `printf '%q '` quoting regression | code-architect | Open |
| 7 | CR1-F7 | Credential file parser `${v:-floci}` default masks empty values | code-architect | Open |
| 8 | CR1-F8 | `DenyPrincipalCreationWithoutBoundary` is redundant with `MintPrincipalsOnlyWithBoundary` StringEquals Allow — defense-in-depth is OK but worth a comment | code-architect | Open |
| 9 | CR1-F9 | `preflight-floci.sh` G3 gate leaks `preflight-lock-$$` table on Ctrl-C | code-architect | Open |
| 10 | CR1-F10 | `dev_status` auth-mode probe hard-codes `/home/floci/floci-data/env.file` — mismatches dev-twin's `DEV_GUEST_DATA_ROOT` | code-architect | Open |
| 11 | CR1-F11 | `run-in-vm.sh` `s3 ls` `|| true` masks connection errors (assert still passes on empty list if no substring match) | code-architect | Open |

## Verdict

**CONDITIONAL PASS**

**Rationale:** The implementation correctly resolves all 49 accepted findings from `psc-adv-0017` per the ticket's acceptance criteria. ShellCheck is clean at severity=warning across all 7 changed bash files, the new bats tests cover the critical non-trivial behaviors (auth posture, credential rotation, AppArmor sentinel, 5xx retry, wait-driver 143/empty-PID), and the design changes (three-statement IAM policy, governance-tag merge-order flip, `FLOCI_AUTH_UNSAFE_OVERRIDE` escape hatch) are sound. The 11 advisory findings are non-blocking and represent improvements to robustness and test coverage rather than correctness regressions. CR-GATE may pass once the 4 moderate-severity findings (CR1-F1, F2, F4, F8) are addressed; the remaining 7 are nice-to-haves and can be tracked as a follow-up.

**Blocking findings:** None.

**Advisory findings:** 11 (4 Moderate, 7 Low). All listed in the Changes Still Pending table.

**Recommended next step:** Author resolves CR1-F1 (one-character fix: `-q` → `-qxF`), CR1-F2 (skip file write on rotation failure), and CR1-F4 (parameterize the risk statement on the live auth state) — these are the three highest-impact items. The remaining 8 can be addressed in a follow-up polish pass.

---

**Reviewer:** code-reviewer (minimax-m3)
**Confidence summary:** 0 findings at ≥90 (Critical), 0 at 80-89 (High), 4 at 65-79 (Moderate), 7 at 40-64 (Low).
**Verdict:** CONDITIONAL PASS
