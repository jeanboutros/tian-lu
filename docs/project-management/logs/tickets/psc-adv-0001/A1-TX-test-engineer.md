# A1-TX: Test Engineer Review — psc-adv-0001

## Findings

### F-TX-001: `_rotate_bootstrap_credentials` has zero unit test coverage
| Field | Value |
|-------|-------|
| Confidence | 90 |
| Severity | CRITICAL |
| File | `docs/design/authentication-plan.md` §6.5, `mock-server/dev-twin.sh` (not yet implemented) |
| Category | test-coverage |

**Description:** The auth plan §6.5 defines `_rotate_bootstrap_credentials` — a 50-line function with three code paths (fresh install, dev-recreate, rotation failure), JSON parsing via `grep -o`/`sed`, partial-failure handling (create succeeds, delete fails), and credential file persistence. §6.11 lists zero tests for this function. The rotation logic is the most security-sensitive code in the auth plan — a bug here leaves the well-known `floci`/`floci` credential active without detection.

**Recommendation:** Add tests to `mock-server/tests/dev_twin.bats`:
- `_rotate_bootstrap_credentials` on fresh install: creates new key, deletes old, persists to `DEV_CREDENTIALS_FILE`
- `_rotate_bootstrap_credentials` on dev-recreate: uses existing rotated creds from `DEV_CREDENTIALS_FILE`, not `floci`/`floci`
- `_rotate_bootstrap_credentials` fallback: when `create-access-key` fails, falls back to bootstrap creds with warning
- `_rotate_bootstrap_credentials` partial failure: when `delete-access-key` fails, emits WARNING, does not suppress
- `_rotate_bootstrap_credentials` file permissions: `DEV_CREDENTIALS_FILE` is mode 0600

---

### F-TX-002: `run-in-vm.sh` auth-mode support has no test coverage
| Field | Value |
|-------|-------|
| Confidence | 85 |
| Severity | HIGH |
| File | `docs/design/authentication-plan.md` §6.10, §7, `mock-server/in-vm/run-in-vm.sh` |
| Category | test-coverage |

**Description:** The auth plan §6.10 and §7 define the test-twin auth-on path: `run-test.sh` accepts `--auth-mode=sigv4`, passes `AUTH_MODE` to the guest driver, `run-in-vm.sh` passes `FLOCI_AUTH_MODE=sigv4` to the installer and overrides container env vars on `podman exec aws` calls. None of this has test coverage. The `run-in-vm.sh` driver has no unit tests at all — it is only exercised by the full Lima twin, which defaults to `auth_mode=off`. The `sigv4` path would only be tested when someone manually runs `make twin-test --auth-mode=sigv4`.

**Recommendation:**
- Add `--auth-mode` flag parsing tests to `mock-server/tests/orchestrator_args.bats`
- Add a `run-in-vm.sh` test (or extend the existing harness) that verifies `AUTH_MODE=sigv4` → `FLOCI_AUTH_MODE=sigv4` is passed to the installer invocation
- Add a test verifying `podman exec` calls include `-e AWS_ACCESS_KEY_ID=floci -e AWS_SECRET_ACCESS_KEY=floci` when `AUTH_MODE=sigv4`

---

### F-TX-003: `run-test.sh` `launch_driver` background process not killed on timeout
| Field | Value |
|-------|-------|
| Confidence | 75 |
| Severity | MODERATE |
| File | `mock-server/run-test.sh` lines 184-197, 551-554 |
| Category | harness-robustness |

**Description:** `launch_driver` backgrounds the `limactl shell` command and captures its PID in `DRIVER_SHELL_PID`. When `poll_sentinel` times out (line 551-554), `main()` calls `wait "${DRIVER_SHELL_PID:-}"` to reap the transport, but does not `kill` it first. If `limactl shell` is hung (e.g., Lima SSH connection stuck), `wait` will block indefinitely — the script never exits. The `wait` on line 553 has no timeout.

**Recommendation:** Add a `kill "$DRIVER_SHELL_PID" 2>/dev/null || true` before the `wait` on the failure path, or wrap the `wait` with a timeout (e.g., `timeout 30 wait "${DRIVER_SHELL_PID:-}" 2>/dev/null || true`). This ensures the orchestrator always terminates.

---

### F-TX-004: `_rotate_bootstrap_credentials` JSON parsing is fragile
| Field | Value |
|-------|-------|
| Confidence | 80 |
| Severity | HIGH |
| File | `docs/design/authentication-plan.md` §6.5 lines 340-341 |
| Category | edge-case |

**Description:** The rotation function parses `aws iam create-access-key` JSON output using `grep -o '"AccessKeyId": *"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/'`. This is fragile:
- If the JSON contains nested quotes or escaped characters, the regex fails
- If Floci changes the JSON key naming (e.g., camelCase vs PascalCase), parsing silently produces empty strings
- If the output contains multiple JSON objects (e.g., debug output mixed in), `head -1` may pick the wrong one
- The `2>/dev/null` on the `podman exec` call (line 339) suppresses stderr, so if the AWS CLI emits a warning to stderr, it's lost

**Recommendation:** Use `jq` for JSON parsing if available in the container, or at minimum add a validation step after parsing: if `new_akid` or `new_sk` is empty but the command exited 0, emit a specific error message ("JSON parsing failed") rather than silently falling through to the generic "could not rotate" warning. The `2>/dev/null` on line 339 should be removed or redirected to a log file — suppressing stderr hides diagnostics.

---

### F-TX-005: `dev-recreate` rotation with corrupted `DEV_CREDENTIALS_FILE` is unrecoverable
| Field | Value |
|-------|-------|
| Confidence | 70 |
| Severity | MODERATE |
| File | `docs/design/authentication-plan.md` §6.5 lines 324-329 |
| Category | edge-case |

**Description:** On `dev-recreate`, `_rotate_bootstrap_credentials` checks if `DEV_CREDENTIALS_FILE` exists and sources it. If the file exists but is corrupted (empty, malformed, or contains invalid variable assignments), the `source` may fail silently or produce empty `DEV_BOOTSTRAP_AKID`/`DEV_BOOTSTRAP_SECRET`. The fallback `${DEV_BOOTSTRAP_AKID:-floci}` then uses `floci`/`floci` — but those credentials were deleted on the first rotation. The `create-access-key` call will fail with an auth error, and the function falls back to the same deleted credentials. The user is stuck.

**Recommendation:** After sourcing `DEV_CREDENTIALS_FILE`, validate that `DEV_BOOTSTRAP_AKID` and `DEV_BOOTSTRAP_SECRET` are non-empty and look like valid credential formats (AKID starts with `AKIA`, secret is reasonable length). If validation fails, emit a specific error and instruct the user to run `dev-reset` to start fresh.

---

### F-TX-006: `publish_evidence` repo mirror copy not validated
| Field | Value |
|-------|-------|
| Confidence | 65 |
| Severity | LOW |
| File | `mock-server/run-test.sh` lines 278-286 |
| Category | harness-robustness |

**Description:** `publish_evidence` copies evidence to two locations: the canonical cache (`~/.cache/tianlu-twin/evidence/<ts>/`) and a repo convenience mirror (`mock-server/evidence/<ts>/`). The manifest is validated (`sha256sum -c`) against the cache copy only (line 272). The repo mirror copy (line 283) is not validated. If the `cp` to the repo mirror fails silently (e.g., disk full, permission error on the second copy), the mirror could be corrupt while the cache is valid. Since the mirror is git-ignored and convenience-only, this is low severity.

**Recommendation:** Either validate the repo mirror copy with `sha256sum -c` as well, or document that the cache is authoritative and the mirror is best-effort. The latter is simpler and matches the existing AGENTS.md convention.

---

### F-TX-007: `mock-server/tests/` harness suite not run in CI
| Field | Value |
|-------|-------|
| Confidence | 80 |
| Severity | HIGH |
| File | `.github/workflows/test.yml`, `Makefile` |
| Category | ci-readiness |

**Description:** The CI workflow (`.github/workflows/test.yml`) runs `make lint` and `make test`. `make test` runs only the installer unit tests (`tests/*.bats`). The harness test suite (`mock-server/tests/*.bats` — 7 files covering orchestrator args, dev twin, assert helpers, completion protocol, pinned user, semantic convergence, dev template) is NOT run in CI. The `make check` target also excludes harness tests. This means harness regressions (e.g., a change to `dev-twin.sh` that breaks `managed_hosts_add` idempotency) are only caught when someone runs the harness tests locally — which is not enforced by any pre-commit or pre-push hook.

**Recommendation:** Add a `make harness-test` target that runs `mock-server/tests/*.bats` and include it in CI (or at minimum in `make check`). The harness tests use stubs and do not require Lima/QEMU, so they can run in CI on `ubuntu-latest`.

---

### F-TX-008: `FLOCI_HOST_PERSISTENT_PATH` validation missing edge-case tests
| Field | Value |
|-------|-------|
| Confidence | 70 |
| Severity | MODERATE |
| File | `setup-floci.sh` lines 115-116, `tests/phase5.bats` |
| Category | test-coverage |

**Description:** `setup-floci.sh` line 116 validates `FLOCI_HOST_PERSISTENT_PATH` against newlines, colons, whitespace, quotes, backslashes, and `%` characters. The existing test (`phase5.bats` line 274) only tests relative path rejection. None of the other invalid character classes are tested: paths containing spaces, tabs, newlines, colons, double quotes, backslashes, or percent signs.

**Recommendation:** Add parametrized tests for each invalid character class. Example: `export FLOCI_HOST_PERSISTENT_PATH='/path/with space'` → exits 1 with "must not contain".

---

### F-TX-009: `run_reboot_test` journal ordering check unconditionally overwrites systemctl result
| Field | Value |
|-------|-------|
| Confidence | 70 |
| Severity | MODERATE |
| File | `mock-server/run-test.sh` lines 375-402 |
| Category | harness-robustness |

**Description:** `run_reboot_test` checks Quadlet ordering via two methods: (1) `systemctl show` to verify `After=podman.socket` and `Requires=podman.socket` (lines 376-391), and (2) journal log line ordering (lines 394-402). The systemctl check sets `ordering_result` to PASS or FAIL. The journal check then **unconditionally** sets `ordering_result='FAIL'` if the journal lines are out of order (line 401), even if the systemctl check passed. This means a journal parsing failure (e.g., `grep` doesn't find the expected lines due to log format changes) would override a valid systemctl PASS. The journal check should only set FAIL if it can definitively prove misordering, not on parse failure.

**Recommendation:** Change line 400-402 to only set `ordering_result='FAIL'` when journal lines are definitively found AND misordered (i.e., both lines exist and socket line number ≥ service line number). If either line is missing, leave the systemctl-based result unchanged.

---

### F-TX-010: `_resume_health_check` suppresses start failures with `|| true`
| Field | Value |
|-------|-------|
| Confidence | 60 |
| Severity | LOW |
| File | `mock-server/dev-twin.sh` line 515 |
| Category | harness-robustness |

**Description:** `_resume_health_check` line 515: `_run_as_floci_guest 'systemctl --user start floci.service' || true`. The `|| true` suppresses the exit code of the start command. If the service fails to start after the reset-failed fallback, the poll loop continues but will eventually time out. The timeout will catch the failure, but the diagnostic information (why did start fail?) is lost because stderr from `_run_as_floci_guest` is suppressed (`2>/dev/null` on line 334).

**Recommendation:** Log the start failure to stderr before suppressing: `_run_as_floci_guest 'systemctl --user start floci.service' || { printf 'WARNING: floci.service start failed after reset\n' >&2; true; }`. This preserves the diagnostic while not blocking the poll loop.

---

### F-TX-011: No test for `FLOCI_AUTH_MODE` invalid value error message
| Field | Value |
|-------|-------|
| Confidence | 85 |
| Severity | HIGH |
| File | `docs/design/authentication-plan.md` §4.2, `tests/phase5.bats` |
| Category | test-coverage |

**Description:** The auth plan §4.2 defines a `case` statement that rejects invalid `FLOCI_AUTH_MODE` values with a specific error message. §6.11 lists this as a test to add ("invalid `FLOCI_AUTH_MODE` → exits 1"), but the test does not yet exist. Without this test, a typo in the mode value (e.g., `FLOCI_AUTH_MODE=sigv4` misspelled) would silently fall through to the `*)` case, but the error message content and exit code are unverified.

**Recommendation:** Add to `tests/phase5.bats`:
- `FLOCI_AUTH_MODE=invalid` → exits 1 with message containing "must be \"off\" or \"sigv4\""
- `FLOCI_AUTH_MODE=` (empty) → exits 1 (or falls through to default `off` — clarify intended behavior)

---

### F-TX-012: No test for `write_env_file` emitting auth vars based on mode
| Field | Value |
|-------|-------|
| Confidence | 85 |
| Severity | HIGH |
| File | `docs/design/authentication-plan.md` §6.2, `tests/phase5.bats` |
| Category | test-coverage |

**Description:** The auth plan §6.2 adds three auth vars to `write_env_file`. §6.11 lists tests for the default `off` mode (all three vars `false` in env file) and `sigv4` mode (all three `true`). Neither test exists yet. The existing `write_env_file` test (§12 keys) verifies 15 keys but does not include the auth vars. Without these tests, the auth vars could be silently omitted from the env file, or written with incorrect values.

**Recommendation:** Add to `tests/phase5.bats`:
- `FLOCI_AUTH_MODE=off` → env file contains `FLOCI_AUTH_VALIDATE_SIGNATURES=false`, `FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED=false`, `FLOCI_SERVICES_IAM_SEED_DEPLOYER_PRINCIPAL=false`
- `FLOCI_AUTH_MODE=sigv4` → env file contains all three vars set to `true`
- Verify the three auth vars are NOT present when `FLOCI_AUTH_MODE` is not set at all (backward compatibility — the installer currently doesn't write them)

---

### F-TX-013: No test for `print_summary` sigv4 message content
| Field | Value |
|-------|-------|
| Confidence | 85 |
| Severity | HIGH |
| File | `docs/design/authentication-plan.md` §6.3, `tests/phase6_7.bats` |
| Category | test-coverage |

**Description:** The auth plan §6.3 replaces the current `print_summary` RISK message with a conditional: sigv4 mode prints auth-ON message with bootstrap admin info and rotation instructions; off mode prints the existing UNAUTHENTICATED warning. §6.11 lists tests for both branches. Neither test exists yet. The existing `print_summary` test (phase6_7.bats line 232) only checks for the off-mode message.

**Recommendation:** Add to `tests/phase6_7.bats`:
- `FLOCI_AUTH_MODE=sigv4` → `print_summary` output contains "signature validation + policy enforcement are ON", "floci-deployer", "bounded platform-admin"
- `FLOCI_AUTH_MODE=sigv4` → `print_summary` output does NOT contain "UNAUTHENTICATED"
- `FLOCI_AUTH_MODE=off` → `print_summary` output contains "UNAUTHENTICATED" (existing test, verify still passes)

---

### F-TX-014: `dev_env` sed replace of existing `[floci-dev]` block has no test
| Field | Value |
|-------|-------|
| Confidence | 80 |
| Severity | HIGH |
| File | `docs/design/authentication-plan.md` §6.6, `mock-server/tests/dev_twin.bats` |
| Category | test-coverage |

**Description:** The auth plan §6.6 changes `dev_env` to use `sed -i.bak '/^\[floci-dev\]/,/^\[/d'` to replace existing credential blocks instead of only appending if missing. This prevents stale credentials from a previous auth mode from persisting. §6.11 lists a test for this ("`dev_env` replaces existing `[floci-dev]` block"), but the test does not exist. The current `dev_env` test (dev_twin.bats line 500) only verifies idempotent profile creation in `~/.aws/config`, not credential replacement in `~/.aws/credentials`.

**Recommendation:** Add to `mock-server/tests/dev_twin.bats`:
- `dev_env` with pre-existing `[floci-dev]` block containing old credentials → old block is removed, new block with rotated creds is written
- `dev_env` with pre-existing `[floci-dev]` block → only one `[floci-dev]` block exists after (no duplication)
- `dev_env` with `DEV_CREDENTIALS_FILE` present → writes rotated creds, not `test/test`
- `dev_env` without `DEV_CREDENTIALS_FILE` → falls back to `test/test`

---

### F-TX-015: `preflight-floci.sh` `aws_admin` env var override has no test
| Field | Value |
|-------|-------|
| Confidence | 75 |
| Severity | MODERATE |
| File | `docs/design/authentication-plan.md` §6.9, `scripts/preflight-floci.sh` |
| Category | test-coverage |

**Description:** The auth plan §6.9 changes `aws_admin` in `preflight-floci.sh` to accept `FLOCI_BOOTSTRAP_AKID` and `FLOCI_BOOTSTRAP_SECRET` env vars, with fallback to `DEV_AKID` and `test`. There are no tests for `preflight-floci.sh` at all — it is not covered by the bats unit test suite or the harness test suite. The G1 preflight gate (signature validation) is a hard stop for the `infra/` Terraform project, so a regression in `aws_admin` credential handling would block the landing-zone workflow.

**Recommendation:** Add a `tests/preflight.bats` test file covering:
- `aws_admin` uses `FLOCI_BOOTSTRAP_AKID`/`FLOCI_BOOTSTRAP_SECRET` when set
- `aws_admin` falls back to `DEV_AKID`/`test` when bootstrap vars are unset
- `aws_admin` passes `--endpoint-url` and `--region` correctly

---

## Self-Audit Checklist

| Category | Checked? | Finding or PASS |
|----------|----------|-----------------|
| Build passes (exit 0, no warnings) | yes | N/A — review-only, no code changes |
| Typed enums / vocabulary types | yes | N/A — bash scripts, not applicable |
| Documentation on new public symbols | yes | N/A — no new symbols |
| Spec/datasheet fidelity | yes | N/A — no datasheet references |
| Module boundary | yes | N/A — no platform headers |
| Reserved/padding fields handled | yes | N/A — no serialisation |
| No magic numbers in doc examples | yes | N/A — no doc examples |
| Buffer safety | yes | N/A — no buffer operations |
| AGENTS.md compliance | yes | PASS — all findings reference specific files and lines |
| Conventional commit ready | yes | N/A — review output, not a commit |

## Verdict

**CONDITIONAL PASS**

**Rationale:** The auth plan's test strategy (§6.11) correctly identifies the test files and test categories needed, but the listed tests are specifications, not implementations — none exist yet. This is expected at Phase A (design phase). The findings above identify 15 concrete gaps: 6 test-coverage gaps in the auth plan's own test list (F-TX-001, F-TX-002, F-TX-011, F-TX-012, F-TX-013, F-TX-014), 4 harness robustness issues in the existing test infrastructure (F-TX-003, F-TX-006, F-TX-009, F-TX-010), 2 edge cases in the planned rotation logic (F-TX-004, F-TX-005), 1 CI readiness gap (F-TX-007), 1 installer test gap (F-TX-008), and 1 preflight test gap (F-TX-015).

**Blocking findings (confidence ≥80):** F-TX-001, F-TX-002, F-TX-004, F-TX-007, F-TX-011, F-TX-012, F-TX-013, F-TX-014 — these must be addressed before the auth plan implementation can be considered test-complete.

**Advisory findings (confidence <80):** F-TX-003, F-TX-005, F-TX-006, F-TX-008, F-TX-009, F-TX-010, F-TX-015 — these should be tracked and addressed but do not block Phase A approval.

**Coverage:** 0/15 planned tests have been implemented (all are specifications in §6.11). The existing test suites (installer unit tests, harness tests) have good coverage of current functionality but zero coverage of the auth plan changes.
