# A2-Challenger-TX: Dual-Model Challenge — psc-adv-0001

| Field | Value |
|-------|-------|
| Model | glm-5.2 |
| Phase | A2 |
| Primary Output | A1-TX test-engineer review: 15 findings (F-TX-001..015) covering auth-plan test coverage, harness robustness, edge cases, CI readiness, and preflight gaps; verdict CONDITIONAL PASS. |

> Method: every agreement/disagreement below was verified by reading the cited source (`mock-server/run-test.sh`, `mock-server/dev-twin.sh`, `docs/design/authentication-plan.md`, `setup-floci.sh`, `Makefile`, `.github/workflows/test.yml`, `mock-server/tests/`). Line numbers were checked against the working tree, not the primary's claims.

## Agreements

Findings I agree with after source verification (no change to primary position):

- **F-TX-001** (`_rotate_bootstrap_credentials` zero coverage) — AGREE. The auth plan §6.11 test list does NOT mention `_rotate_bootstrap_credentials` at all; the plan lists tests for `dev_env`, `print_summary`, `phase5` env-file, and invalid auth mode, but the rotation helper itself — the most security-sensitive function — has no planned tests. The primary correctly identified this as a plan-level omission, not just an implementation gap. Confidence 90 is appropriate.
- **F-TX-002** (run-in-vm.sh auth-mode no coverage) — AGREE on substance. `run-in-vm.sh` (357 lines) has zero function-level unit tests; `grep` confirms no test sources its functions. `orchestrator_args.bats` has no `--auth-mode`/`AUTH_MODE`/`sigv4` references. The sigv4 path would only run under a manual `make twin-test --auth-mode=sigv4`.
- **F-TX-003** (`launch_driver` not killed on timeout) — AGREE. Verified: `run-test.sh` line 553 `wait "${DRIVER_SHELL_PID:-}" 2>/dev/null || true` has no preceding `kill` and no timeout. If `limactl shell` hangs, `wait` blocks indefinitely. The `wait_driver` path (line 229) has the same shape but at least runs on the success path. The failure path is the real risk.
- **F-TX-004** (JSON parsing fragile) — AGREE. Verified `auth-plan.md` lines 340-341 use `grep -o ... | head -1 | sed ...`. The `2>/dev/null` on the `podman exec` (line 339) does suppress stderr. The recommendation to validate emptiness post-parse is sound.
- **F-TX-008** (path validation edge cases untested) — AGREE. Verified `setup-floci.sh` line 120 validates against newlines, colons, whitespace, quotes, backslashes, `%`; `phase5.bats` line 274 only tests relative-path rejection. The other invalid classes are untested.
- **F-TX-011** (invalid `FLOCI_AUTH_MODE` untested) — AGREE. §6.11 explicitly lists this test; it does not exist. Verified the `case` statement in §4.2 (plan lines 132-145).
- **F-TX-012** (`write_env_file` auth vars untested) — AGREE. §6.11 lists the env-file tests; none implemented. Verified.
- **F-TX-013** (`print_summary` sigv4 message untested) — AGREE. §6.11 lists it; only the off-mode test exists. Verified.
- **F-TX-014** (`dev_env` sed-replace untested) — AGREE. §6.11 lists "replaces existing `[floci-dev]` block"; the existing `dev_twin.bats` test only covers `~/.aws/config` profile idempotency, not `~/.aws/credentials` block replacement.
- **F-TX-015** (preflight-floci.sh has no tests) — AGREE on the coverage fact: `tests/preflight.bats` does not exist. The auth plan §6.9 changes `aws_admin` and adds no test plan entry for it. Verified.

## Disagreements

### D-TX-001: F-TX-007 is factually wrong — harness tests ARE in CI
| Field | Value |
|-------|-------|
| Primary Finding | F-TX-007 |
| Confidence | 92 |
| Severity | HIGH (misleading false-positive in a review) |
| Primary Position | Claims `make test` runs only `tests/*.bats`; harness suite `mock-server/tests/*.bats` is NOT in CI; `make check` excludes harness tests. |
| Challenger Position | False. The `Makefile` `test` target (lines 42-44) is:
  ```
  test:
      bats tests/
      bats mock-server/tests/
  ```
  Both `bats tests/` AND `bats mock-server/tests/` run under `make test`. CI (`.github/workflows/test.yml`) runs `make test`, so all 7 harness `.bats` files (`assert_helpers`, `completion_protocol`, `dev_template`, `dev_twin`, `orchestrator_args`, `pinned_user`, `semantic_convergence`) execute on every push/PR. The primary's claim that "harness regressions are only caught when someone runs the harness tests locally" is incorrect, and the recommended `make harness-test` target is redundant — `make test` already covers it. The primary did not read the Makefile before asserting. |
| Recommendation | Withdraw F-TX-007. The CI gap it describes does not exist. If the intent was to argue for *separate* harness-test reporting/telemetry, that is a different (and advisory) finding, not a HIGH-severity CI-readiness gap. |

### D-TX-002: F-TX-009 overstates "unconditional" overwrite and mis-locates the real bug
| Field | Value |
|-------|-------|
| Primary Finding | F-TX-009 |
| Confidence | 78 |
| Severity | MODERATE (mechanism mischaracterized) |
| Primary Position | The journal check "unconditionally sets `ordering_result='FAIL'` if journal lines are out of order," even overriding a valid systemctl PASS on parse failure. |
| Challenger Position | Verified `run-test.sh` lines 398-402:
  ```
  if [[ -z "$journal_socket_line" || -z "$journal_service_line" || ${journal_socket_line%%:*} -ge ${journal_service_line%%:*} ]]; then
    ordering_result='FAIL'
  fi
  ```
  This is a **conditional**, not "unconditional." The primary's own recommendation ("only set FAIL when both lines exist AND misordered") is actually what the *first two clauses* already do — they only downgrade to FAIL when a line is *missing*. The genuine bug is subtler: when `journal_socket_line` is empty (parse failure), the test sets FAIL and discards the systemctl PASS — but that is the **opposite** of the primary's described mechanism ("unconditionally ... if out of order"). The primary's framing ("unconditionally ... if out of order") is self-contradictory and led to a recommendation that partially matches existing behavior. The real issue is the empty-line fallback-to-FAIL, which the primary did mention but buried. |
| Recommendation | Re-state F-TX-009 as: "journal check downgrades a systemctl PASS to FAIL whenever either journal line is unparseable (empty). Fix: when either line is missing, preserve the systemctl-based `ordering_result` (do not overwrite), and only set FAIL when both lines are present and socket_line ≥ service_line." Confidence should drop to ~70 given the mischaracterization. |

### D-TX-003: F-TX-005 overstates `source` "silent failure" under `set -e`
| Field | Value |
|-------|-------|
| Primary Finding | F-TX-005 |
| Confidence | 68 (primary said 70) |
| Severity | MODERATE (mechanism partly wrong) |
| Primary Position | "`source` may fail silently or produce empty `DEV_BOOTSTRAP_AKID`/`DEV_BOOTSTRAP_SECRET`." |
| Challenger Position | `dev-twin.sh` line 2 is `set -euo pipefail`. A `source` of a file with a **syntax error** aborts the script immediately (non-zero exit), it does not "fail silently." The only way `source` "produces empty vars" is if the file has *valid syntax but no assignments* (e.g., empty file, or comments only) — that case is real and the `${DEV_BOOTSTRAP_AKID:-floci}` fallback does silently downgrade to the deleted `floci`/`floci` creds. So the underlying recovery hazard is real, but the "source may fail silently" mechanism is inaccurate for the malformed-syntax case. The recommendation (validate AKID/secret format after source) is correct and still applies. |
| Recommendation | Keep the finding but reframe: under `set -e`, a syntactically malformed `DEV_CREDENTIALS_FILE` aborts hard; the silent-downgrade risk is specifically the *empty-but-valid* file (or one missing the two vars). Add a post-`source` non-empty + format check (`AKIA` prefix, secret length). Lower confidence to ~68. |

### D-TX-004: F-TX-010 cites the wrong line for stderr suppression
| Field | Value |
|-------|-------|
| Primary Finding | F-TX-010 |
| Confidence | 55 (primary said 60) |
| Severity | LOW (citation error, substance intact) |
| Primary Position | "stderr from `_run_as_floci_guest` is suppressed (`2>/dev/null` on line 334)." |
| Challenger Position | The `2>/dev/null` is on the `limactl shell` invocation inside `_run_as_floci_guest` (`dev-twin.sh` line 337), not "line 334" and not on the `systemctl` command itself. The functional effect (systemctl stderr is lost when start fails) is still real, but the citation is wrong, which weakens auditability. |
| Recommendation | Fix the line reference to 337 and clarify the suppression is at the `limactl shell` boundary (which captures all guest stderr), not a per-command redirect. The logging recommendation stands. |

## One-Sided Findings (Primary Missed)

### M-TX-001: `_rotate_bootstrap_credentials` is never invoked in `auth_mode=off` — no test for the gating that prevents rotation when unneeded
| Field | Value |
|-------|-------|
| Confidence | 82 |
| Description | The auth plan §6.5 defines `_rotate_bootstrap_credentials` and §6.4 shows `dev-twin.sh` passes `FLOCI_AUTH_MODE=sigv4` at install, and `_install_absent` calls `_rotate_bootstrap_credentials` after `_health_check`. But the plan does not specify (and the primary did not flag) what happens to rotation in **`auth_mode=off`**: in off mode there is no `floci-deployer` user with an access key to rotate, and the well-known `floci`/`floci` bootstrap is the Floci default that should NOT be deleted. If `_rotate_bootstrap_credentials` runs unconditionally in off mode, it will (a) fail the `create-access-key` call (no deployer user) and fall back to `floci`/`floci`, or worse (b) succeed against a different user and delete the working bootstrap. The plan §6.4/§6.5 must gate rotation on `DEV_AUTH_MODE=sigv4`, and there must be a test asserting rotation is a **no-op** (or not called) in off mode. Neither the plan's §6.11 test list nor F-TX-001 covers this. |
| Recommended Action | Add to `mock-server/tests/dev_twin.bats`: (1) `_rotate_bootstrap_credentials` is not called when `DEV_AUTH_MODE=off`; (2) when called in off mode (defensive), it does NOT issue `delete-access-key` against `floci`/`floci`. Flag to the auth-plan author that §6.5 needs an explicit mode guard. |

### M-TX-002: No test that `DEV_CREDENTIALS_FILE` is NOT created/overwritten in `auth_mode=off`
| Field | Value |
|-------|-------|
| Confidence | 80 |
| Description | `_rotate_bootstrap_credentials` writes `DEV_CREDENTIALS_FILE` (mode 0600) on success. In off mode this file should never exist (no rotation). If a leftover file from a prior sigv4 run persists into an off-mode `dev-recreate`, the §6.5 branch `if [[ -f "$DEV_CREDENTIALS_FILE" ]]` sources it and uses rotated creds — but in off mode the container env vars are `test/test` (baked-in), so the rotated creds would fail auth, and the fallback to `floci`/`floci` (deleted) would also fail. There is no test that off mode does not consume a stale `DEV_CREDENTIALS_FILE`, and no plan entry for it. F-TX-005 touched the corrupted-file case but missed the cross-mode-staleness case. |
| Recommended Action | Add a test: pre-existing `DEV_CREDENTIALS_FILE` + `DEV_AUTH_MODE=off` → rotation is skipped, file is ignored (not sourced), and `floci`/`floci` or `test/test` is used per the off-mode contract. Clarify in §6.5 whether `_rotate_bootstrap_credentials` should `rm -f` a stale file in off mode. |

### M-TX-003: `wait_driver` (success path, line 229) has the same un-killed-wait defect as F-TX-003 but was not flagged
| Field | Value |
|-------|-------|
| Confidence | 72 |
| Description | F-TX-003 flags only the failure path (line 553). The success path `wait_driver` (line 229) is `wait "${DRIVER_SHELL_PID:-}" 2>/dev/null || status=$?` — also no `kill` before `wait`, also no timeout. If the driver hangs *after* publishing the DONE sentinel but before its shell exits (e.g., the `systemd-run --wait` reaper stalls), `wait_driver` blocks indefinitely on the success path too, and `poll_sentinel` already returned success. The primary's F-TX-003 is asymmetric: it only covers the timeout/failure branch. |
| Recommended Action | Apply the same `kill`-before-`wait` (or `timeout`-wrapped `wait`) to `wait_driver` on line 229, and add a harness test for both success- and failure-path hang. Extend F-TX-003 to cover both branches. |

### M-TX-004: No test for `chmod 0600` failure on `DEV_CREDENTIALS_FILE` (filesystem-full / read-only mount)
| Field | Value |
|-------|-------|
| Confidence | 62 |
| Description | `_rotate_bootstrap_credentials` ends with `chmod 0600 "$DEV_CREDENTIALS_FILE"`. Under `set -e`, if `chmod` fails (e.g., the `~/.cache/tianlu-twin` mount is read-only, or the data disk is full after the `printf >`), the function aborts *after* the new key was created and the old key was deleted — leaving the user with a rotated key that was never persisted and a deleted old key. This is a worse outcome than F-TX-005's corrupted-file scenario (a permanent lockout with no recovery file). Neither the plan nor F-TX-001/005 cover the post-rotation persistence-failure path. |
| Recommended Action | Add a test: `chmod` failure (stub returns 1) → function emits a specific CRITICAL error naming the unpersisted new AKID (so the user can recover manually) and returns non-zero, rather than aborting silently under `set -e`. Recommend the plan write the creds file *before* deleting the old key, or write-then-verify-then-delete ordering. |

### M-TX-005: `_print_next_steps` security-warning test (plan §6.11) is listed but the primary's F-TX set omits it
| Field | Value |
|-------|-------|
| Confidence | 70 |
| Description | §6.11 explicitly lists: "`_print_next_steps` includes security warning when `DEV_CREDENTIALS_FILE` exists" and "`dev_reset` deletes `DEV_CREDENTIALS_FILE`". The primary's 15 findings cover `dev_env` (F-TX-014) but never mention the `_print_next_steps` warning test or the `dev_reset` cleanup test, both of which are in the plan's own test list and unimplemented. This is a gap in the gap-list: the primary under-enumerated the plan's stated tests. |
| Recommended Action | Add two findings (or fold into F-TX-014): unimplemented `_print_next_steps` warning test, and unimplemented `dev_reset` deletes-credentials-file test. Both are security-relevant (the warning prevents the user from assuming `floci`/`floci` still works; the reset test ensures no credential residue after teardown). |

### M-TX-006: No coverage for the §7.3 test-matrix `s3-smoke` / Lambda-sidecar auth-on override
| Field | Value |
|-------|-------|
| Confidence | 68 |
| Description | §7.3 defines a test matrix where `auth_mode=sigv4` changes `podman exec aws` calls to include `-e AWS_ACCESS_KEY_ID=floci -e AWS_SECRET_ACCESS_KEY=floci`. The primary's F-TX-002 mentions `podman exec` overrides but frames it only as "no test coverage" for `run-in-vm.sh`. It misses that the §7.3 matrix is a **cross-cutting** concern: the same `podman exec -e ...` override must appear in the s3-smoke step, the Lambda sidecar step, and the G1 preflight — and a single test asserting the override pattern is applied consistently across all three would catch a regression where one step is patched but another is forgotten. The primary's F-TX-002 recommendation only mentions one `podman exec` test. |
| Recommended Action | Add a parametrized harness test asserting that for `AUTH_MODE=sigv4`, every `podman exec ... aws` invocation in `run-in-vm.sh` (s3-smoke, lambda sidecar, G1) carries the `-e AWS_ACCESS_KEY_ID`/`-e AWS_SECRET_ACCESS_KEY` overrides. Reference §7.3 as the authoritative source. |

## Recommendations

1. **Correct the record on F-TX-007.** It is a false positive that, if left standing, would misdirect effort toward a non-existent CI gap and erode trust in the review. The Makefile runs both test directories under `make test`, which CI invokes. Withdraw or reclassify as advisory-only (e.g., "consider splitting installer vs harness test reporting").

2. **Re-characterize F-TX-009 and F-TX-005** per D-TX-002 / D-TX-003 so the mechanisms are accurate. A review finding with a wrong mechanism invites a fix that does not address the real bug.

3. **Add the mode-gating tests (M-TX-001, M-TX-002).** These are the most consequential misses: the auth plan's central safety property is "off mode does nothing security-sensitive," and there is no planned test for it. Rotation running in off mode, or a stale creds file being consumed in off mode, would both silently break the off-mode contract. Flag to the auth-plan author that §6.5 needs an explicit `DEV_AUTH_MODE` guard.

4. **Reorder `_rotate_bootstrap_credentials` write-then-delete (M-TX-004).** The current order (create new → delete old → persist new) can lose both keys on a persistence failure. Recommend persist-then-delete; add a test for the `chmod`/write failure path.

5. **Promote M-TX-005 and M-TX-006 to findings.** The primary under-counted the plan's own §6.11 test list (missing `_print_next_steps` and `dev_reset` tests) and under-scoped the §7.3 matrix to a single `podman exec` test.

6. **Apply the `kill`-before-`wait` fix symmetrically** (M-TX-003) to both `wait_driver` (success path) and the failure-path `wait` in `main`. F-TX-003 should be broadened, not left as a failure-path-only finding.

7. **Self-audit note:** the primary's self-audit checklist row "AGENTS.md compliance — PASS — all findings reference specific files and lines" is itself inaccurate for F-TX-007 (Makefile not read) and F-TX-010 (wrong line). The self-audit should have caught the F-TX-007 Makefile claim by opening the Makefile. Recommend the primary add a "re-opened cited file" step to its self-audit before signing off.
