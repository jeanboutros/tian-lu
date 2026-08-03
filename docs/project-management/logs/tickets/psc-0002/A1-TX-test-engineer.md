# A1-TX: Test Engineer Requirements — psc-0002

| Field | Value |
|-------|-------|
| Agent | test-engineer |
| Timestamp | 2026-07-30T00:00:00Z |
| Step | A1-TX |
| Verdict | APPROVED |
| Coverage | 13/13 findings have test specifications |

## Test Specifications

### SPEC-TX-001: Rotation unit tests
**Source:** F-TX-001
**Test file:** `mock-server/tests/dev_twin.bats` (new tests appended)
**Pattern:** Source `$DEV_SCRIPT` directly; override `_run_as_floci_guest`, `mkdir`, `chmod`, `printf` with logging stubs. Use `STUB_LOG` for command tracking.

**Test cases:**

1. **`_rotate_bootstrap_credentials: fresh install — uses floci/floci, creates new key, deletes old, persists`**
   - Precondition: `DEV_CREDENTIALS_FILE` does not exist.
   - Stub `_run_as_floci_guest` to return a synthetic `create-access-key` JSON response containing `"AccessKeyId": "AKIA_ROTATED"` and `"SecretAccessKey": "abc123"`.
   - Assert: first `_run_as_floci_guest` call uses `-e AWS_ACCESS_KEY_ID=floci -e AWS_SECRET_ACCESS_KEY=floci`.
   - Assert: second `_run_as_floci_guest` call is `delete-access-key` with `--access-key-id floci`.
   - Assert: `DEV_CREDENTIALS_FILE` is written with `DEV_BOOTSTRAP_AKID=AKIA_ROTATED` and `DEV_BOOTSTRAP_SECRET=abc123`.
   - Assert: `chmod 0600` is called on `DEV_CREDENTIALS_FILE`.

2. **`_rotate_bootstrap_credentials: dev-recreate — uses existing rotated creds from DEV_CREDENTIALS_FILE`**
   - Precondition: `DEV_CREDENTIALS_FILE` exists with `DEV_BOOTSTRAP_AKID=AKIA_OLD` and `DEV_BOOTSTRAP_SECRET=oldsecret`.
   - Stub `_run_as_floci_guest` to return a synthetic `create-access-key` JSON with `"AccessKeyId": "AKIA_NEW"` and `"SecretAccessKey": "newsecret"`.
   - Assert: first `_run_as_floci_guest` call uses `-e AWS_ACCESS_KEY_ID=AKIA_OLD -e AWS_SECRET_ACCESS_KEY=oldsecret` (NOT `floci`/`floci`).
   - Assert: `delete-access-key` call uses `--access-key-id AKIA_OLD`.
   - Assert: `DEV_CREDENTIALS_FILE` is overwritten with `AKIA_NEW`/`newsecret`.

3. **`_rotate_bootstrap_credentials: fallback — create-access-key fails, uses bootstrap creds with warning`**
   - Precondition: `DEV_CREDENTIALS_FILE` does not exist.
   - Stub `_run_as_floci_guest` to return empty string (simulating `create-access-key` failure).
   - Assert: function returns 0 (does not abort).
   - Assert: stderr contains `WARNING: could not rotate bootstrap credentials`.
   - Assert: `DEV_BOOTSTRAP_AKID=floci` and `DEV_BOOTSTRAP_SECRET=floci` are set (fallback values).
   - Assert: `DEV_CREDENTIALS_FILE` is NOT written (no `printf` to that path).

4. **`_rotate_bootstrap_credentials: partial failure — create succeeds, delete fails, emits WARNING`**
   - Precondition: `DEV_CREDENTIALS_FILE` does not exist.
   - Stub `_run_as_floci_guest` to return synthetic `create-access-key` JSON on first call, then return non-zero on second call (simulating `delete-access-key` failure).
   - Assert: function returns 0 (does not abort on delete failure).
   - Assert: stderr contains `WARNING: could not delete old key floci — it is still active`.
   - Assert: `DEV_CREDENTIALS_FILE` IS written with the new rotated creds (create succeeded).
   - Assert: `chmod 0600` is called on `DEV_CREDENTIALS_FILE`.

5. **`_rotate_bootstrap_credentials: file permissions — DEV_CREDENTIALS_FILE is mode 0600`**
   - Precondition: `DEV_CREDENTIALS_FILE` does not exist.
   - Stub `_run_as_floci_guest` to return synthetic `create-access-key` JSON.
   - Use a real `mkdir` and `chmod` (not stubbed) for the credential file path.
   - Assert: after rotation, `stat -c '%a' "$DEV_CREDENTIALS_FILE"` (or `stat -f '%A'`) returns `600`.

---

### SPEC-TX-002: Rotation gated off in auth_mode=off
**Source:** M-TX-001
**Test file:** `mock-server/tests/dev_twin.bats` (new test)
**Pattern:** Source `$DEV_SCRIPT`; override `_install_absent` to track whether `_rotate_bootstrap_credentials` is called.

**Test case:**

1. **`_install_absent: does NOT call _rotate_bootstrap_credentials when FLOCI_AUTH_MODE is not sigv4`**
   - Override `_rotate_bootstrap_credentials` to write `ROTATION_CALLED` to `STUB_LOG` and return 0.
   - Override `_health_check`, `dev_env`, `managed_hosts_add`, `_install_exec_condition`, `_guest_ufw_baseline`, `_wait_running`, `verify_disk_mount`, `preflight_ports` as no-ops.
   - Call `_install_absent` (which currently does NOT pass `FLOCI_AUTH_MODE=sigv4` — the default path).
   - Assert: `ROTATION_CALLED` does NOT appear in `STUB_LOG`.

---

### SPEC-TX-003: Stale DEV_CREDENTIALS_FILE not consumed in off mode
**Source:** M-TX-002
**Test file:** `mock-server/tests/dev_twin.bats` (new test)
**Pattern:** Source `$DEV_SCRIPT`; test `dev_env` directly.

**Test case:**

1. **`dev_env: ignores DEV_CREDENTIALS_FILE when auth_mode is off (no FLOCI_AUTH_MODE=sigv4 context)`**
   - Precondition: `DEV_CREDENTIALS_FILE` exists with `DEV_BOOTSTRAP_AKID=AKIA_STALE` and `DEV_BOOTSTRAP_SECRET=stalesecret`.
   - Call `dev_env` (which currently has no auth-mode awareness — it always writes `test/test`).
   - Assert: `~/.aws/credentials` contains `aws_access_key_id = test` and `aws_secret_access_key = test`.
   - Assert: `~/.aws/credentials` does NOT contain `AKIA_STALE` or `stalesecret`.
   - Note: This test validates the current behavior. When §6.6 is implemented (credential loading from `DEV_CREDENTIALS_FILE`), this test must be updated to verify the gating logic — `dev_env` should only consume `DEV_CREDENTIALS_FILE` when `DEV_AUTH_MODE=sigv4`.

---

### SPEC-TX-004: run-in-vm.sh auth-mode tests and --auth-mode flag parsing
**Source:** F-TX-002
**Test files:** `mock-server/tests/orchestrator_args.bats` (flag parsing) + new `mock-server/tests/run_in_vm.bats` (driver behavior)

**Test cases (orchestrator_args.bats):**

1. **`--auth-mode=off sets AUTH_MODE=off`**
   - Source `$ORCHESTRATOR`; call `parse_args --auth-mode=off`.
   - Assert: `$AUTH_MODE` is `off`.

2. **`--auth-mode=sigv4 sets AUTH_MODE=sigv4`**
   - Source `$ORCHESTRATOR`; call `parse_args --auth-mode=sigv4`.
   - Assert: `$AUTH_MODE` is `sigv4`.

3. **`--auth-mode=invalid reports a failure reason`**
   - Source `$ORCHESTRATOR`; call `parse_args --auth-mode=invalid` with `set +e`.
   - Assert: exit status is 1.
   - Assert: `$FAIL_REASON` contains `auth-mode` or `invalid`.

4. **`--auth-mode with no value reports a failure reason`**
   - Source `$ORCHESTRATOR`; call `parse_args --auth-mode=` with `set +e`.
   - Assert: exit status is 1.
   - Assert: `$FAIL_REASON` is non-empty.

5. **`default AUTH_MODE is off when --auth-mode is not passed`**
   - Source `$ORCHESTRATOR`; call `parse_args` (no auth-mode flag).
   - Assert: `$AUTH_MODE` is `off` (or unset, defaulting to `off`).

**Test cases (run_in_vm.bats — new file):**

6. **`run-in-vm.sh: AUTH_MODE=off does NOT pass FLOCI_AUTH_MODE to installer`**
   - Source `$DRIVER`; override `sudo bash "$SETUP_SCRIPT"` to log the env vars it receives.
   - Call `step_run1` with `AUTH_MODE=off`.
   - Assert: the installer invocation does NOT include `FLOCI_AUTH_MODE=sigv4`.

7. **`run-in-vm.sh: AUTH_MODE=sigv4 passes FLOCI_AUTH_MODE=sigv4 to installer`**
   - Source `$DRIVER`; override `sudo bash "$SETUP_SCRIPT"` to log the env vars it receives.
   - Call `step_run1` with `AUTH_MODE=sigv4`.
   - Assert: the installer invocation includes `FLOCI_AUTH_MODE=sigv4`.

8. **`run-in-vm.sh: AUTH_MODE=sigv4 adds -e AWS_ACCESS_KEY_ID=floci -e AWS_SECRET_ACCESS_KEY=floci to podman exec aws calls`**
   - Source `$DRIVER`; override `run_as_floci_guest` to log its arguments.
   - Call `step_run1` with `AUTH_MODE=sigv4`.
   - Assert: the s3-smoke `podman exec` call includes `-e AWS_ACCESS_KEY_ID=floci -e AWS_SECRET_ACCESS_KEY=floci`.

9. **`run-in-vm.sh: AUTH_MODE=off does NOT add credential overrides to podman exec aws calls`**
   - Source `$DRIVER`; override `run_as_floci_guest` to log its arguments.
   - Call `step_run1` with `AUTH_MODE=off`.
   - Assert: the s3-smoke `podman exec` call does NOT include `-e AWS_ACCESS_KEY_ID=floci`.

---

### SPEC-TX-005: FLOCI_AUTH_MODE invalid-value test
**Source:** F-TX-011
**Test file:** `tests/phase5.bats` (new test appended)
**Pattern:** Use `_run_fn` subshell pattern; test the config block's case statement.

**Test case:**

1. **`FLOCI_AUTH_MODE: invalid value exits 1 with error message`**
   - Call `_run_fn "export FLOCI_AUTH_MODE=invalid" "true"`.
   - Assert: exit status is 1.
   - Assert: stderr contains `FLOCI_AUTH_MODE must be "off" or "sigv4"`.

---

### SPEC-TX-006: write_env_file auth-var emission tests
**Source:** F-TX-012
**Test file:** `tests/phase5.bats` (new tests appended)
**Pattern:** Use `_run_fn` subshell pattern; test `write_env_file` output.

**Test cases:**

1. **`write_env_file: sigv4 mode (default) emits all three auth vars as true`**
   - Call `_run_fn "export STUB_OUT_OPENSSL='deadbeefcafe'" "generate_presign_secret; write_env_file"`.
   - Assert: `FLOCI_ENV_FILE` contains `FLOCI_AUTH_VALIDATE_SIGNATURES=true`.
   - Assert: `FLOCI_ENV_FILE` contains `FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED=true`.
   - Assert: `FLOCI_ENV_FILE` contains `FLOCI_SERVICES_IAM_SEED_DEPLOYER_PRINCIPAL=true`.

2. **`write_env_file: off mode emits all three auth vars as false`**
   - Call `_run_fn "export FLOCI_AUTH_MODE=off; export STUB_OUT_OPENSSL='deadbeefcafe'" "generate_presign_secret; write_env_file"`.
   - Assert: `FLOCI_ENV_FILE` contains `FLOCI_AUTH_VALIDATE_SIGNATURES=false`.
   - Assert: `FLOCI_ENV_FILE` contains `FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED=false`.
   - Assert: `FLOCI_ENV_FILE` contains `FLOCI_SERVICES_IAM_SEED_DEPLOYER_PRINCIPAL=false`.

3. **`write_env_file: sigv4 mode does NOT emit FLOCI_SERVICES_IAM_ENABLED (separate var)`**
   - Call `_run_fn "export STUB_OUT_OPENSSL='deadbeefcafe'" "generate_presign_secret; write_env_file"`.
   - Assert: `FLOCI_ENV_FILE` does NOT contain `FLOCI_SERVICES_IAM_ENABLED` (this is a distinct Floci var, not part of the auth-mode trio).

4. **`write_env_file: auth vars are absent when FLOCI_AUTH_MODE is unset (backward compat)`**
   - Call `_run_fn "export STUB_OUT_OPENSSL='deadbeefcafe'; unset FLOCI_AUTH_MODE" "generate_presign_secret; write_env_file"`.
   - Assert: `FLOCI_ENV_FILE` does NOT contain `FLOCI_AUTH_VALIDATE_SIGNATURES`.
   - Assert: `FLOCI_ENV_FILE` does NOT contain `FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED`.
   - Assert: `FLOCI_ENV_FILE` does NOT contain `FLOCI_SERVICES_IAM_SEED_DEPLOYER_PRINCIPAL`.
   - Note: This test validates backward compatibility — if `FLOCI_AUTH_MODE` is not set, no auth vars are written (the Floci container uses its own defaults). This test may need updating if the default changes.

---

### SPEC-TX-007: print_summary sigv4 message content test
**Source:** F-TX-013
**Test file:** `tests/phase6_7.bats` (new tests appended)
**Pattern:** Use `_run_fn` subshell pattern; test `print_summary` output.

**Test cases:**

1. **`print_summary: sigv4 mode prints IAM signature validation ON message`**
   - Call `_run_fn "export FIREWALL_SCOPE=rfc1918" "FLOCI_AUTH_VALIDATE_SIGNATURES=true; FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED=true; UFW_TRUSTED_SUBNETS=(10.0.0.0/8 172.16.0.0/12 192.168.0.0/16); print_summary"`.
   - Assert: output contains `IAM signature validation` or `sigv4 mode`.
   - Assert: output contains `floci-deployer`.
   - Assert: output does NOT contain `UNAUTHENTICATED` or `RISK`.

2. **`print_summary: off mode prints UNAUTHENTICATED risk warning`**
   - Call `_run_fn "export FIREWALL_SCOPE=rfc1918" "FLOCI_AUTH_VALIDATE_SIGNATURES=false; FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED=false; UFW_TRUSTED_SUBNETS=(10.0.0.0/8 172.16.0.0/12 192.168.0.0/16); print_summary"`.
   - Assert: output contains `UNAUTHENTICATED` or `RISK`.
   - Assert: output contains `trusted subnet` or `trusted network`.
   - Assert: output does NOT contain `floci-deployer`.

3. **`print_summary: sigv4 mode prints bootstrap admin credential note`**
   - Call `_run_fn "export FIREWALL_SCOPE=rfc1918" "FLOCI_AUTH_VALIDATE_SIGNATURES=true; FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED=true; UFW_TRUSTED_SUBNETS=(10.0.0.0/8); print_summary"`.
   - Assert: output contains `Bootstrap admin` or `floci-deployer`.
   - Assert: output contains `AKID=floci` or `secret=floci`.

---

### SPEC-TX-008: dev_env sed-replace and credential-rotation tests
**Source:** F-TX-014
**Test file:** `mock-server/tests/dev_twin.bats` (new tests appended)
**Pattern:** Source `$DEV_SCRIPT`; test `dev_env` with real filesystem operations.

**Test cases:**

1. **`dev_env: replaces existing [floci-dev] block — no stale creds from previous mode`**
   - Precondition: `~/.aws/credentials` already contains a `[floci-dev]` block with `aws_access_key_id = oldkey` and `aws_secret_access_key = oldsecret`.
   - Precondition: `DEV_CREDENTIALS_FILE` exists with `DEV_BOOTSTRAP_AKID=AKIA_NEW` and `DEV_BOOTSTRAP_SECRET=newsecret`.
   - Call `dev_env`.
   - Assert: `~/.aws/credentials` contains `aws_access_key_id = AKIA_NEW` and `aws_secret_access_key = newsecret`.
   - Assert: `~/.aws/credentials` does NOT contain `oldkey` or `oldsecret`.
   - Assert: exactly one `[floci-dev]` section exists in the credentials file.

2. **`dev_env: sed -i.bak creates and removes backup file (portable BSD/GNU sed)`**
   - Precondition: `~/.aws/credentials` already contains a `[floci-dev]` block.
   - Call `dev_env`.
   - Assert: no `.bak` file remains (`~/.aws/credentials.bak` does not exist).

3. **`dev_env: loads rotated credentials from DEV_CREDENTIALS_FILE when it exists`**
   - Precondition: `DEV_CREDENTIALS_FILE` exists with `DEV_BOOTSTRAP_AKID=AKIA_ROTATED` and `DEV_BOOTSTRAP_SECRET=rotatedsecret`.
   - Call `dev_env`.
   - Assert: `~/.aws/credentials` contains `aws_access_key_id = AKIA_ROTATED` and `aws_secret_access_key = rotatedsecret`.

4. **`dev_env: falls back to test/test when DEV_CREDENTIALS_FILE does not exist`**
   - Precondition: `DEV_CREDENTIALS_FILE` does not exist.
   - Call `dev_env`.
   - Assert: `~/.aws/credentials` contains `aws_access_key_id = test` and `aws_secret_access_key = test`.

5. **`dev_env: credentials file is mode 0600`**
   - Call `dev_env`.
   - Assert: `stat -c '%a' ~/.aws/credentials` (or `stat -f '%A'`) returns `600`.

---

### SPEC-TX-009: preflight-floci.sh aws_admin credential handling tests
**Source:** F-TX-015
**Test file:** new `tests/preflight.bats`
**Pattern:** Source `scripts/preflight-floci.sh`; stub `aws` to log its env vars. Use `TEST_TMP` for isolation.

**Test cases:**

1. **`aws_admin: uses DEV_AKID and test secret by default`**
   - Source `$PREFLIGHT_SCRIPT`; override `aws` to print `AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY` and exit 0.
   - Call `aws_admin iam get-user`.
   - Assert: `AWS_ACCESS_KEY_ID` is `$DEV_AKID` (default `111111111111`).
   - Assert: `AWS_SECRET_ACCESS_KEY` is `test`.

2. **`aws_admin: uses FLOCI_BOOTSTRAP_AKID override when set`**
   - Source `$PREFLIGHT_SCRIPT`; override `aws` to print env vars.
   - Call with `FLOCI_BOOTSTRAP_AKID=AKIA_CUSTOM aws_admin iam get-user`.
   - Assert: `AWS_ACCESS_KEY_ID` is `AKIA_CUSTOM`.

3. **`aws_admin: uses FLOCI_BOOTSTRAP_SECRET override when set`**
   - Source `$PREFLIGHT_SCRIPT`; override `aws` to print env vars.
   - Call with `FLOCI_BOOTSTRAP_SECRET=customsecret aws_admin iam get-user`.
   - Assert: `AWS_SECRET_ACCESS_KEY` is `customsecret`.

4. **`aws_admin: passes through additional aws arguments`**
   - Source `$PREFLIGHT_SCRIPT`; override `aws` to print all arguments after `--`.
   - Call `aws_admin iam create-user --user-name testuser`.
   - Assert: the aws stub receives `iam create-user --user-name testuser`.

---

### SPEC-TX-010: Cross-cutting podman exec -e overrides in sigv4 mode
**Source:** M-TX-006
**Test file:** new `mock-server/tests/run_in_vm.bats`
**Pattern:** Source `$DRIVER`; parametrize `AUTH_MODE` across test cases. Override `run_as_floci_guest` to log all arguments.

**Test cases:**

1. **`run-in-vm.sh: AUTH_MODE=sigv4 — s3 mb uses -e overrides`**
   - Source `$DRIVER`; set `AUTH_MODE=sigv4`; override `run_as_floci_guest` to log to `STUB_LOG`.
   - Execute the s3-smoke block from `step_run1`.
   - Assert: the `podman exec ... aws s3 mb` call includes `-e AWS_ACCESS_KEY_ID=floci -e AWS_SECRET_ACCESS_KEY=floci`.

2. **`run-in-vm.sh: AUTH_MODE=sigv4 — s3 ls uses -e overrides`**
   - Same pattern as above.
   - Assert: the `podman exec ... aws s3 ls` call includes `-e AWS_ACCESS_KEY_ID=floci -e AWS_SECRET_ACCESS_KEY=floci`.

3. **`run-in-vm.sh: AUTH_MODE=sigv4 — Lambda sidecar podman exec uses -e overrides`**
   - Source `$DRIVER`; set `AUTH_MODE=sigv4`; override `run_as_floci_guest` to log.
   - Execute the Lambda sidecar block from `step_sidecar`.
   - Assert: the `podman exec tianlu-floci bash -c '... aws lambda create-function ...'` call includes `-e AWS_ACCESS_KEY_ID=floci -e AWS_SECRET_ACCESS_KEY=floci`.

4. **`run-in-vm.sh: AUTH_MODE=off — s3 mb does NOT use -e overrides`**
   - Source `$DRIVER`; set `AUTH_MODE=off`; override `run_as_floci_guest` to log.
   - Execute the s3-smoke block.
   - Assert: the `podman exec ... aws s3 mb` call does NOT include `-e AWS_ACCESS_KEY_ID=floci`.

5. **`run-in-vm.sh: AUTH_MODE=off — Lambda sidecar does NOT use -e overrides`**
   - Source `$DRIVER`; set `AUTH_MODE=off`; override `run_as_floci_guest` to log.
   - Execute the Lambda sidecar block.
   - Assert: the `podman exec tianlu-floci bash -c '... aws lambda ...'` call does NOT include `-e AWS_ACCESS_KEY_ID=floci`.

---

### SPEC-TX-011: chmod failure test for DEV_CREDENTIALS_FILE persistence
**Source:** M-TX-004
**Test file:** `mock-server/tests/dev_twin.bats` (new test)
**Pattern:** Source `$DEV_SCRIPT`; stub `chmod` to fail on the credential file path.

**Test case:**

1. **`_rotate_bootstrap_credentials: chmod failure on DEV_CREDENTIALS_FILE is detected`**
   - Precondition: `DEV_CREDENTIALS_FILE` does not exist.
   - Stub `_run_as_floci_guest` to return synthetic `create-access-key` JSON.
   - Stub `chmod` to return 1 when the argument matches `DEV_CREDENTIALS_FILE`.
   - Assert: function returns non-zero OR emits a WARNING about permissions.
   - Assert: the file content was written (the `printf` to `DEV_CREDENTIALS_FILE` succeeded) but the permissions may be wrong — the test verifies the error is surfaced, not silently swallowed.

---

### SPEC-TX-012: Replace grep/sed JSON parsing with jq
**Source:** F-TX-004
**Type:** Code change (not a test), but tests must verify the new behavior.
**Test file:** `mock-server/tests/dev_twin.bats` (update SPEC-TX-001 tests)

**Test specification:**

The `_rotate_bootstrap_credentials` function currently parses `create-access-key` JSON output with:
```bash
new_akid="$(printf '%s' "$out" | grep -o '"AccessKeyId": *"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')"
new_sk="$(printf '%s' "$out" | grep -o '"SecretAccessKey": *"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')"
```

This must be replaced with `jq`:
```bash
new_akid="$(printf '%s' "$out" | jq -r '.AccessKey.AccessKeyId')"
new_sk="$(printf '%s' "$out" | jq -r '.AccessKey.SecretAccessKey')"
```

**Test updates required:**

1. **Update SPEC-TX-001 test cases 1-5:** The stubbed `_run_as_floci_guest` must return valid JSON that `jq` can parse (the `create-access-key` response wraps the key in an `.AccessKey` object). Update the synthetic JSON from flat `{"AccessKeyId": "..."}` to `{"AccessKey": {"AccessKeyId": "...", "SecretAccessKey": "..."}}`.

2. **New test: `_rotate_bootstrap_credentials: handles jq parse failure gracefully`**
   - Stub `_run_as_floci_guest` to return malformed JSON (e.g., `{"error": "InternalServerError"}`).
   - Assert: function falls back to the warning path (empty `new_akid`/`new_sk` after `jq` returns null).
   - Assert: stderr contains `WARNING: could not rotate bootstrap credentials`.

3. **New test: `_rotate_bootstrap_credentials: jq dependency is available`**
   - Verify `jq` is listed as a dependency or the function checks `command -v jq` before use.
   - If `jq` is not available, the function should fail with a clear error message.

---

### SPEC-TX-013: Fix wait_driver success-path hang
**Source:** M-TX-003
**Type:** Code fix in `run-test.sh` + test verification.
**Test file:** `mock-server/tests/completion_protocol.bats` (update existing test)

**Problem:** `wait_driver` calls `wait "${DRIVER_SHELL_PID:-}"` which hangs if the driver process is still running (e.g., the `limactl shell` transport hasn't exited yet after the guest driver wrote `DONE`). The fix is to kill the transport before waiting.

**Code fix (in `run-test.sh`):**
```bash
wait_driver() {
  local status=0
  # Kill the limactl shell transport before waiting — the guest driver has
  # already written DONE, so the transport may still be alive waiting for
  # the shell to exit. Killing it ensures wait returns immediately.
  kill "${DRIVER_SHELL_PID:-}" 2>/dev/null || true
  wait "${DRIVER_SHELL_PID:-}" 2>/dev/null || status=$?
  DRIVER_SHELL_PID=""
  if [[ "$status" -ne 0 ]]; then
    FAIL_REASON="driver exited nonzero (${status}) despite DONE"
    return 1
  fi
}
```

**Test update:**

1. **Update `wait_driver returns 0 for a successful driver` in `completion_protocol.bats`:**
   - The existing test launches `true &` and waits. This test should still pass after the fix because `kill` on an already-exited PID is harmless (`kill` returns non-zero, which is `|| true`-suppressed).
   - Add assertion: `DRIVER_SHELL_PID` is empty after `wait_driver` returns.

2. **New test: `wait_driver kills the transport before waiting (no hang)`**
   - Launch `sleep 999 &` as the driver PID.
   - Call `wait_driver` with a timeout wrapper (e.g., `timeout 5 bash -c '... wait_driver'`).
   - Assert: `wait_driver` returns within the timeout (the `kill` terminates `sleep`).
   - Assert: `DRIVER_SHELL_PID` is empty after return.

---

## Test File Summary

| Test File | New Tests | Modified Tests | Total Specs |
|-----------|-----------|----------------|-------------|
| `tests/phase5.bats` | 5 (SPEC-TX-005, SPEC-TX-006) | 0 | 5 |
| `tests/phase6_7.bats` | 3 (SPEC-TX-007) | 0 | 3 |
| `tests/preflight.bats` (NEW) | 4 (SPEC-TX-009) | 0 | 4 |
| `mock-server/tests/dev_twin.bats` | 12 (SPEC-TX-001, 002, 003, 008, 011) | 0 | 12 |
| `mock-server/tests/orchestrator_args.bats` | 5 (SPEC-TX-004:1-5) | 0 | 5 |
| `mock-server/tests/run_in_vm.bats` (NEW) | 9 (SPEC-TX-004:6-9, SPEC-TX-010) | 0 | 9 |
| `mock-server/tests/completion_protocol.bats` | 1 (SPEC-TX-013) | 1 (SPEC-TX-013 update) | 2 |
| **Total** | **39** | **1** | **40** |

## New Test File Boilerplates

### `tests/preflight.bats`
```bash
#!/usr/bin/env bats
# Unit tests for scripts/preflight-floci.sh: aws_admin credential handling.

load test_helper

PREFLIGHT_SCRIPT="${REPO_ROOT}/scripts/preflight-floci.sh"

setup() {
  setup_stub_env
}

teardown() {
  teardown_stub_env
}
```

### `mock-server/tests/run_in_vm.bats`
```bash
#!/usr/bin/env bats
# Unit tests for in-vm/run-in-vm.sh: auth-mode behavior, podman exec overrides.

load test_helper

setup() {
  setup_stub_env
}

teardown() {
  teardown_stub_env
}
```

## Stub Requirements

### New stubs needed in `mock-server/tests/stubs/bin/`:
- `jq` — symlink to `_stub` (for SPEC-TX-012 tests). Must support `STUB_OUT_JQ` for synthetic JSON parsing output.
- `kill` — symlink to `_stub` (for SPEC-TX-013 tests). Must support `STUB_RC_KILL` for exit code control.

### New stubs needed in `tests/stubs/bin/`:
- `jq` — symlink to `_stub` (if preflight tests need it; currently they don't).

## Implementation Order

The code-architect should implement these tests in the following order to maximize TDD value:

1. **Phase 5 tests first** (SPEC-TX-005, SPEC-TX-006) — these test the installer's config block and env-file writing, which are the foundation of the auth-mode feature.
2. **Phase 6/7 tests** (SPEC-TX-007) — test the summary output, which depends on the config block.
3. **Preflight tests** (SPEC-TX-009) — test the preflight script's credential handling.
4. **Dev-twin rotation tests** (SPEC-TX-001, 002, 003, 008, 011, 012) — test the rotation function and dev_env behavior.
5. **Orchestrator args tests** (SPEC-TX-004:1-5) — test the `--auth-mode` flag parsing.
6. **Run-in-vm tests** (SPEC-TX-004:6-9, SPEC-TX-010) — test the guest driver's auth-mode behavior.
7. **Completion protocol fix** (SPEC-TX-013) — fix and test the `wait_driver` hang.

## Verdict

**VERDICT: APPROVED**
**COVERAGE: 13/13 findings have precise test specifications**
**GAPS: None — all accepted TX-relevant findings are covered**

### Self-Audit Checklist

| Category | Checked? | Finding or PASS |
|----------|----------|-----------------|
| Build passes (exit 0, no warnings) | N/A | No code written — specification only |
| Typed enums / vocabulary types | N/A | Bash project — not applicable |
| Documentation on new public symbols | N/A | Specification document — self-documenting |
| Spec/datasheet fidelity | PASS | All test cases reference specific functions and lines from `authentication-plan.md` |
| Module boundary | PASS | Tests are placed in correct test files matching the module under test |
| Reserved/padding fields handled | N/A | Not applicable |
| No magic numbers in doc examples | PASS | All values are named (e.g., `DEV_CREDENTIALS_FILE`, `FLOCI_AUTH_MODE`) |
| Buffer safety | N/A | Not applicable |
| AGENTS.md compliance | PASS | Follows test conventions from `tests/AGENTS.md` and `mock-server/AGENTS.md` |
| Conventional commit ready | N/A | Specification only — no code to commit |

**ROUTING:** Output to code-architect for incorporation into `authentication-plan.md` §6.11 and §7.
