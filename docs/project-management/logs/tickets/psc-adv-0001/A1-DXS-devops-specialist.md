# A1-DXS: DevOps Specialist Review — psc-adv-0001

**Agent:** devops-specialist
**Timestamp:** 2026-07-29T22:00:00Z
**Phase:** A1
**Ticket:** psc-adv-0001
**Artifacts reviewed:** `mock-server/run-test.sh`, `mock-server/dev-twin.sh`, `setup-floci.sh`, `docs/design/landing-zone-design.md`, `.github/workflows/test.yml`, `Makefile`

---

## Reference Validation

| Claim / Decision | Source | Verification |
|-----------------|--------|-------------|
| GitHub Actions workflow syntax | [Source: https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions, accessed 2026-07-29] | Verified — workflow YAML structure conforms |
| GitHub Actions security hardening | [Source: https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions, accessed 2026-07-29] | Verified — multiple gaps found (see findings) |
| Quadlet `.container` unit format | [Source: https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html, accessed 2026-07-29] | Verified — Quadlet structure in `setup-floci.sh` matches spec |
| systemd service hardening directives | [Source: https://www.freedesktop.org/software/systemd/man/latest/systemd.exec.html, accessed 2026-07-29] | Verified — hardening subset in Quadlet is correct for rootless context |
| Terraform S3 backend + DynamoDB locking | [Source: https://developer.hashicorp.com/terraform/language/settings/backends/s3, accessed 2026-07-29] | Verified — design matches documented pattern |
| CI/CD pipeline design principles | [Source: ci-cd-pipeline skill, §Pipeline Design Principles] | Applied as review framework |
| Deployment safety — reversible deploys | [Source: reliability-scalability skill, §7] | Applied as review framework |
| Observability — health checks | [Source: observability skill, §6] | Applied as review framework |

---

## Findings

### F-DXS-001: CI workflow lacks security hardening — no permissions restriction, no action pinning, no concurrency control

| Field | Value |
|-------|-------|
| Confidence | 90 |
| Severity | HIGH |
| File | `.github/workflows/test.yml:1-21` |
| Category | ci-readiness |

**Description:** The CI workflow at `.github/workflows/test.yml` has no `permissions` block, meaning `GITHUB_TOKEN` defaults to read/write for all scopes. The `actions/checkout@v7` action uses a floating major-version tag (`@v7`) rather than a pinned commit SHA. There is no `concurrency` group, so multiple pushes to the same PR can produce overlapping runs that waste runner minutes and produce confusing results. There is no `CODEOWNERS` file to gate workflow changes, and no `.github/dependabot.yml` to auto-update actions.

Per the GitHub Actions security hardening guide [Source: https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions], workflows should set `permissions: contents: read` as the minimum, pin third-party actions to full-length commit SHAs, and use concurrency groups to cancel redundant runs.

**Recommendation:**
1. Add `permissions: contents: read` at the workflow level.
2. Pin `actions/checkout` to a full commit SHA: `actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2` (or the latest v4.x SHA).
3. Add `concurrency: { group: ${{ github.workflow }}-${{ github.ref }}, cancel-in-progress: true }`.
4. Create `.github/dependabot.yml` with `package-ecosystem: "github-actions"` for weekly updates.
5. Create a `CODEOWNERS` file covering `.github/workflows/`.

---

### F-DXS-002: No Dependabot configuration for GitHub Actions — actions will never receive automated version updates

| Field | Value |
|-------|-------|
| Confidence | 85 |
| Severity | HIGH |
| File | (missing) `.github/dependabot.yml` |
| Category | ci-readiness |

**Description:** The repository has no `.github/dependabot.yml` file. Without Dependabot configured for the `github-actions` package ecosystem, action versions will never receive automated update PRs. This means security patches, bug fixes, and new features in `actions/checkout` and any future actions added to the workflow will be missed indefinitely. Per the GitHub Actions security hardening guide, Dependabot should be configured for all action dependencies [Source: https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions#keeping-your-actions-up-to-date-with-dependabot].

**Recommendation:** Create `.github/dependabot.yml`:
```yaml
version: 2
updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
    groups:
      actions:
        patterns:
          - "*"
```

---

### F-DXS-003: `run-test.sh` cannot run in CI — Lima/QEMU/arm64 dependency is a hard blocker for automated integration testing

| Field | Value |
|-------|-------|
| Confidence | 80 |
| Severity | HIGH |
| File | `mock-server/run-test.sh:49-61` |
| Category | ci-readiness |

**Description:** `run-test.sh` requires Lima + QEMU on an Apple Silicon (arm64) host (lines 55-60). GitHub Actions `ubuntu-latest` runners are x86_64 and do not have Lima or QEMU with hardware acceleration. The AGENTS.md documents this explicitly ("CI covers lint+unit only"), so this is a known limitation, not a bug. However, it means the most valuable test — the full digital-twin integration test — is a **manual-only pre-push gate** with no automated enforcement. A developer can push without running `make twin-test`, and CI will not catch regressions that only surface in the twin.

The `make ci-test` target (Makefile:55-68) runs lint+unit inside disposable Podman containers on both ubuntu:24.04 and ubuntu:26.04, which is a good partial mitigation — it catches host-filesystem-dependent test bugs. But it does not exercise the installer end-to-end.

**Recommendation:**
1. Document the pre-push gate enforcement more prominently — consider a Git pre-push hook (in addition to the existing pre-commit hook) that runs `make twin-test` or at least warns.
2. Investigate whether GitHub Actions `macos-15` (arm64) runners could run the twin — they have Apple Silicon and could potentially run Lima+QEMU, though this would be slow and expensive.
3. Accept the limitation but add a CI check that verifies the twin was run recently (e.g., check the timestamp of the latest evidence directory and fail CI if it's older than N days).

---

### F-DXS-004: `wait_driver` has a silent false-positive when `DRIVER_SHELL_PID` is empty

| Field | Value |
|-------|-------|
| Confidence | 85 |
| Severity | HIGH |
| File | `mock-server/run-test.sh:227-235` |
| Category | ci-readiness |

**Description:** The `wait_driver` function at lines 227-235 calls `wait "${DRIVER_SHELL_PID:-}"`. If `DRIVER_SHELL_PID` is empty (e.g., `launch_driver` failed before setting it, or the variable was cleared by an error path), the `${DRIVER_SHELL_PID:-}` expansion produces an empty string, and `wait ""` in bash returns exit code 0 immediately. The function then returns 0 — a false positive that claims the driver exited successfully when it never ran.

The `main` function at line 553 has a fallback `wait` on the failure path, but this only runs when `launch_driver && poll_sentinel` fails. If `launch_driver` succeeds but `DRIVER_SHELL_PID` is somehow empty (e.g., a subshell race), the success path at line 541 calls `wait_driver` and gets a false positive.

**Recommendation:** Add a guard at the top of `wait_driver`:
```bash
if [[ -z "${DRIVER_SHELL_PID:-}" ]]; then
  FAIL_REASON="driver PID not set — launch_driver may have failed silently"
  return 1
fi
```

---

### F-DXS-005: `dev_env` writes to the user's real `~/.aws/credentials` file — risk of credential leakage to real AWS

| Field | Value |
|-------|-------|
| Confidence | 75 |
| Severity | MODERATE |
| File | `mock-server/dev-twin.sh:757-777` |
| Category | environment-management |

**Description:** The `dev_env` function at lines 757-777 appends a `[floci-dev]` profile with `aws_access_key_id = test` and `aws_secret_access_key = test` to the user's real `~/.aws/credentials` file. While these are test credentials for Floci (not real AWS), the pattern of writing to the shared credentials file is risky:

1. If the user has real AWS credentials in the same file, a misconfigured `AWS_PROFILE` or a script that iterates all profiles could accidentally use the Floci test credentials against real AWS endpoints.
2. The `ca_bundle =` (empty) setting in the config profile disables TLS certificate verification for this profile — if the profile is accidentally used against a real AWS endpoint, it would accept any certificate.
3. There is no cleanup path — `dev_reset` removes the `/etc/hosts` entry but does NOT remove the AWS profile.

**Recommendation:**
1. Consider using a separate credentials file (e.g., `~/.aws/floci-credentials`) and pointing `AWS_SHARED_CREDENTIALS_FILE` at it, rather than polluting the main credentials file.
2. At minimum, add a `dev_env_remove` function that cleans up the profile, and call it from `dev_reset`.
3. Add a prominent warning in the `dev_env` output that these credentials must never be used against real AWS endpoints.

---

### F-DXS-006: `configure_firewall` never removes stale UFW rules — scope changes leave orphaned rules

| Field | Value |
|-------|-------|
| Confidence | 80 |
| Severity | HIGH |
| File | `setup-floci.sh:865-901` |
| Category | deployment-strategy |

**Description:** The `configure_firewall` function at lines 865-901 adds UFW `allow` rules for the current `FIREWALL_SCOPE` but never removes rules from a previous scope. If the script is first run with `--firewall-scope=auto` (which opens ports to the detected LAN /24), and then re-run with `--firewall-scope=rfc1918`, the old LAN /24 rules remain in place alongside the new RFC1918 rules. The old rules are now stale — if the server's IP changes, the old /24 subnet may no longer be correct, but the rules persist.

The idempotency check at line 895 (`grep -E "(^|[[:space:]])${port}/" | grep -qF "$subnet"`) only checks if a rule for the *current* subnet exists — it never enumerates existing rules to find and remove ones that no longer match the current scope.

**Recommendation:** Add a cleanup pass before adding new rules: enumerate all existing UFW rules matching the Floci port ranges, compare against the current trusted subnets, and `ufw delete` any that don't match. Alternatively, use UFW's `insert` with rule numbers and manage them explicitly, or document that changing `--firewall-scope` requires a manual `ufw reset` first.

---

### F-DXS-007: No rollback mechanism — installer failure leaves partial state with no automated recovery

| Field | Value |
|-------|-------|
| Confidence | 70 |
| Severity | MODERATE |
| File | `setup-floci.sh:967-1015` |
| Category | deployment-strategy |

**Description:** The installer is idempotent (safe to re-run) but has no rollback mechanism. If it fails mid-way through Phase 5 (e.g., `write_quadlet_unit` succeeds but `enable_systemd_service` fails), the system is left in a partially-configured state. The `.bak` files exist for the Quadlet and env file, but there is no automated restore. The operator must manually identify what was changed and revert it.

Per the reliability-scalability skill [§7], every deploy should be reversible within 5 minutes. While this is a setup script rather than a continuous deployment, the principle applies: a failed installation should leave the system in a known state.

**Recommendation:**
1. Add a `--rollback` flag that reads the `.bak` files and restores them, stops the service, and removes any resources created by the current run.
2. At minimum, document the manual rollback steps in the error output when the script fails.
3. Consider a transaction log: write each completed phase to a state file, and on failure, report which phases succeeded and which failed.

---

### F-DXS-008: `pull_floci_image` never updates a pinned image — stale images persist indefinitely

| Field | Value |
|-------|-------|
| Confidence | 75 |
| Severity | MODERATE |
| File | `setup-floci.sh:711-716` |
| Category | deployment-strategy |

**Description:** The `pull_floci_image` function at lines 711-716 checks if the image exists locally via `podman image inspect` and skips the pull if found. This means once `docker.io/floci/floci:1.5.33-compat` is pulled, it is never refreshed — even if the tag is updated upstream with a patch release. The image is pinned to a specific version tag (`1.5.33-compat`), which is good for reproducibility, but the tag could be re-pointed (e.g., a `-compat` variant rebuild). The current behaviour means the image is effectively frozen at first-pull.

This is a deliberate design choice (pinned image for reproducibility), but it should be documented explicitly: the image is never updated after initial pull, and updating requires manual `podman pull` or deleting the local image before re-running the script.

**Recommendation:** Document this behaviour in the script header and in `REVIEW.md`. Consider adding a `--refresh-image` flag that forces a re-pull.

---

### F-DXS-009: Landing zone design has no CI/CD pipeline for Terraform — all applies are manual

| Field | Value |
|-------|-------|
| Confidence | 80 |
| Severity | HIGH |
| File | `docs/design/landing-zone-design.md:400-418` |
| Category | iac |

**Description:** The landing zone design at §10.2 describes manual `terraform init` and `terraform apply` commands for each stage. There is no CI/CD pipeline for automated planning, validation, or application of Terraform changes. For an educational project this is acceptable, but the design document should acknowledge this gap and describe what a production CI/CD pipeline would look like:

- Automated `terraform plan` on PR
- Manual approval gate before `terraform apply`
- State locking via DynamoDB (already designed)
- Plan output stored as PR comment
- Drift detection on schedule

The pre-flight gates (`scripts/preflight-floci.sh`) are also manual — they must be run before any `terraform apply`, but there's no enforcement.

**Recommendation:** Add a §10.4 "CI/CD pipeline (future)" section to the landing zone design that describes the intended pipeline structure. Even if not implemented now, documenting the target state prevents ad-hoc pipeline design later.

---

### F-DXS-010: `00-backend-bootstrap` uses local state with no backup strategy — orphaned resources on state loss

| Field | Value |
|-------|-------|
| Confidence | 75 |
| Severity | MODERATE |
| File | `docs/design/landing-zone-design.md:371-373` |
| Category | iac |

**Description:** The bootstrap stage at §9 uses local state (`terraform.tfstate` on disk) because it creates the S3 bucket and DynamoDB table that subsequent stages use for remote state. This is the standard bootstrap pattern, but it creates a single point of failure: if the local state file is lost (deleted, corrupted, machine failure), the S3 bucket and DynamoDB table become orphaned — they exist but are no longer managed by Terraform. Recreating them would require manual intervention or state import.

The design does not mention any backup strategy for the bootstrap state file (e.g., committing it to the repo, copying to a secondary location, or migrating it to the S3 backend after creation).

**Recommendation:** Add a note in §9 about bootstrap state backup: after `00-backend-bootstrap` is applied, copy `terraform.tfstate` to a secure location (or commit it to the repo if the bucket/table names are not sensitive). Alternatively, document the `terraform import` commands needed to recover if the state is lost.

---

### F-DXS-011: `terraform_remote_state` couples stages tightly — upstream output changes force full downstream re-plan

| Field | Value |
|-------|-------|
| Confidence = 65 |
| Severity | LOW |
| File | `docs/design/landing-zone-design.md:99-101` |
| Category | iac |

**Description:** The design at §3 uses `terraform_remote_state` data sources to consume upstream stage outputs. This is a valid pattern but creates tight coupling: any change to an upstream stage's outputs requires re-planning all downstream stages, even if the downstream stage doesn't use the changed output. In production Terraform estates, this is often mitigated by using a combination of `terraform_remote_state` (for critical dependencies) and `data` sources (for discoverable resources like VPC IDs via tags).

For an educational project with 7 stages this is manageable, but the design should acknowledge the coupling and note that in a larger estate, `data` sources with tag-based lookup would reduce the blast radius of output changes.

**Recommendation:** Add a note in §3.2 about the coupling trade-off and the `data` source alternative for larger estates.

---

### F-DXS-012: `_install_exec_condition` adds a dev-twin-only Quadlet override that doesn't exist in production

| Field | Value |
|-------|-------|
| Confidence | 80 |
| Severity | HIGH |
| File | `mock-server/dev-twin.sh:442-451` |
| Category | environment-management |

**Description:** The `_install_exec_condition` function at lines 442-451 writes an `ExecCondition` to `/home/floci/.config/systemd/user/floci.service.d/mount-condition.conf` that checks whether the data disk is mounted before starting the service. This override exists ONLY in the dev twin — the production installer (`setup-floci.sh`) does not create it. If someone copies the Quadlet or service configuration from the dev twin to a production server, the `ExecCondition` would fail (no `/mnt/lima-floci-dev-data` mount on a real server), and the service would not start.

This is a configuration drift between dev and production that is not documented in the AGENTS.md gotchas.

**Recommendation:**
1. Document this dev-only override in the AGENTS.md Critical gotchas section.
2. Add a comment in `_install_exec_condition` explaining that this is dev-twin-specific and must not be copied to production.
3. Consider using a dev-specific environment variable to gate this behaviour rather than hardcoding the mount path.

---

### F-DXS-013: `_resume_health_check` resets failed service inside poll loop — can mask genuine boot failures

| Field | Value |
|-------|-------|
| Confidence | 70 |
| Severity | MODERATE |
| File | `mock-server/dev-twin.sh:503-521` |
| Category | operations |

**Description:** The `_resume_health_check` function at lines 503-521 checks `_floci_service_state` on every poll iteration and calls `_reset_floci_service` + `systemctl --user start floci.service` if the service is in `failed` state. This means if the service is genuinely broken (not just an AppArmor boot-race), the function will reset and restart it on every iteration for up to `DEV_RESUME_HEALTH_TRIES` (150) × `DEV_RESUME_HEALTH_SLEEP` (2s) = 300 seconds. This could mask a real failure by continuously restarting a broken service, and the operator would only see "health: Floci did not return HTTP 200 after resume" after 5 minutes with no indication of how many restarts were attempted.

The test twin's `wait_for_reboot_health` (run-test.sh:308-343) has the same pattern but only resets once (the fallback path at lines 325-330 runs once, not in a loop). The dev twin's loop-based reset is more aggressive.

**Recommendation:** Add a counter to limit the number of resets (e.g., reset at most once, matching the test twin's behaviour). Log each reset attempt so the operator can see how many occurred.

---

### F-DXS-014: Port range 5100-5199 is in firewall rules but explicitly excluded from container `-p` mappings — documented but fragile

| Field | Value |
|-------|-------|
| Confidence | 60 |
| Severity | LOW |
| File | `setup-floci.sh:76-92` |
| Category | operations |

**Description:** The `FLOCI_PORTS_FIREWALL` array at lines 83-92 includes ports 5100-5199 (ECR sidecar range), but the `FLOCI_PORTS_CONTAINER` array at lines 76-80 does NOT include them. The AGENTS.md gotchas document this: "Do NOT add ports 5100-5199 to the container's `-p` flags. ECR sidecar binds directly on the host." This is correct behaviour, but the asymmetry between the two port lists is a maintenance hazard — someone updating the port ranges might add 5100-5199 to `FLOCI_PORTS_CONTAINER` without understanding the ECR sidecar constraint.

**Recommendation:** Add a comment above `FLOCI_PORTS_CONTAINER` explicitly stating why 5100-5199 is excluded, referencing the AGENTS.md gotcha. Consider adding a runtime check that verifies 5100-5199 is NOT in `FLOCI_PORTS_CONTAINER`.

---

### F-DXS-015: No structured logging or metrics from the installer or test harness — operational visibility is ad-hoc

| Field | Value |
|-------|-------|
| Confidence | 65 |
| Severity | LOW |
| File | `setup-floci.sh`, `mock-server/run-test.sh`, `mock-server/dev-twin.sh` |
| Category | operations |

**Description:** The installer and test harness scripts use `printf`/`echo` for output with no structured format (no timestamps, no log levels, no machine-parseable output). The test harness produces a `summary.md` with a criterion/status table and a `manifest.sha256` for evidence integrity — this is good. But the installer itself has no structured output: success/failure is determined by exit code only, with ad-hoc `ERROR:` messages on stderr.

For a production deployment tool, structured logging (JSON lines with timestamp, level, phase, message) would enable:
- Automated parsing of installer output in CI
- Correlation of installer runs across multiple servers
- Alerting on specific failure modes

For the current scope (single-server setup script), this is acceptable but should be on the roadmap if the project scales to multi-server deployments.

**Recommendation:** No immediate action required. Flag as a future improvement if the project moves toward multi-server or automated deployment.

---

### F-DXS-016: `run-test.sh` has no overall timeout — a hung twin blocks indefinitely

| Field | Value |
|-------|-------|
| Confidence | 75 |
| Severity | MODERATE |
| File | `mock-server/run-test.sh:526-559` |
| Category | ci-readiness |

**Description:** The `main` function at lines 526-559 chains `ensure_twin && launch_driver && poll_sentinel` with individual timeouts for each phase (`FRESH_BUDGET`, `SERVICE_HEALTH_BUDGET`, `REBOOT_HEALTH_BUDGET`), but there is no overall timeout for the entire run. If the twin VM hangs in a state where `limactl` commands block indefinitely (e.g., QEMU process stuck, 9p mount hung), the script will hang forever with no automatic termination. In a CI context, the CI platform's job timeout would eventually kill it, but for local runs there's no upper bound.

**Recommendation:** Add an overall timeout using `timeout` or a background watchdog:
```bash
# At the top of main():
( sleep "$OVERALL_TIMEOUT" && kill -ALRM $$ ) &
WATCHDOG_PID=$!
trap 'kill "$WATCHDOG_PID" 2>/dev/null' EXIT
```
Or wrap the entire `main` call in `timeout 3600 ./mock-server/run-test.sh ...`.

---

## Self-Audit Checklist

| Category | Checked? | Finding or PASS |
|----------|----------|-----------------|
| Build passes (exit 0, no warnings) | N/A | No build step for shell scripts — lint passes via `make lint` |
| Typed enums / vocabulary types | N/A | Shell scripts — not applicable |
| Documentation on new public symbols | N/A | Shell scripts — not applicable |
| Spec/datasheet fidelity | N/A | Not a hardware project |
| Module boundary | N/A | Shell scripts — not applicable |
| Reserved/padding fields handled | N/A | Not applicable |
| No magic numbers in doc examples | N/A | Not applicable |
| Buffer safety | PASS | No unbounded reads from external data in reviewed scripts |
| AGENTS.md compliance | PASS | All findings reference AGENTS.md gotchas where relevant |
| Conventional commit ready | N/A | Review phase — no commit |
| CI/CD pipeline design principles | PASS — with findings | Pipeline exists but has security gaps (F-DXS-001, F-DXS-002) |
| Deployment strategy review | PASS — with findings | Idempotent installer, no rollback (F-DXS-007) |
| Infrastructure-as-code review | PASS — with findings | Layered Terraform, manual applies (F-DXS-009, F-DXS-010) |
| Observability review | PASS — with findings | Health checks present, no structured logging (F-DXS-015) |
| Environment management | PASS — with findings | Dev/twin separation good, credential risk (F-DXS-005) |

---

## Verdict

**VERDICT: CONDITIONAL PASS**

**SEVERITY: 90** (highest finding: F-DXS-001 — CI workflow lacks security hardening)

**Rationale:** The artifacts are well-designed for their current scope (single-server setup, local development, educational landing zone). The installer's idempotency is thorough, the Quadlet integration is correct, the dev/twin environment separation is clean, and the evidence collection with manifest validation is robust. However, there are concrete gaps that should be addressed:

**Blocking findings (confidence ≥80):**
- F-DXS-001 (90): CI workflow lacks `permissions`, action pinning, concurrency control
- F-DXS-002 (85): No Dependabot for GitHub Actions
- F-DXS-003 (80): Twin test cannot run in CI — manual-only gate
- F-DXS-004 (85): `wait_driver` false-positive when PID is empty
- F-DXS-006 (80): UFW rules never cleaned up on scope change
- F-DXS-009 (80): No CI/CD pipeline for Terraform
- F-DXS-012 (80): Dev-twin-only Quadlet override not documented as dev-specific

**Advisory findings (confidence <80):**
- F-DXS-005 (75): `dev_env` writes to real `~/.aws/credentials`
- F-DXS-007 (70): No rollback mechanism
- F-DXS-008 (75): Pinned image never refreshed
- F-DXS-010 (75): Bootstrap state has no backup strategy
- F-DXS-011 (65): `terraform_remote_state` coupling
- F-DXS-013 (70): `_resume_health_check` resets in loop
- F-DXS-014 (60): Port range asymmetry is fragile
- F-DXS-015 (65): No structured logging
- F-DXS-016 (75): No overall timeout on twin run

**ROUTING:** code-architect (for CI workflow fixes, F-DXS-001, F-DXS-002), bash-specialist (for F-DXS-004, F-DXS-006), docs-writer (for F-DXS-009, F-DXS-012 documentation)

---

## Flags

### Flag: task — CI workflow security hardening

| Field | Value |
|-------|-------|
| Type | `task` |
| Priority | `high` |
| Raised by | DevOps Specialist |
| Blocking | `no` |
| Reference | psc-adv-0001, F-DXS-001, F-DXS-002 |

**Description:** The CI workflow at `.github/workflows/test.yml` needs security hardening: permissions restriction, action pinning, concurrency control, Dependabot configuration, and CODEOWNERS coverage.

**Evidence:** See F-DXS-001 and F-DXS-002 above.

**Suggested action:** Create a follow-up task to harden the CI workflow per the recommendations in F-DXS-001 and F-DXS-002.

### Flag: task — UFW rule cleanup on scope change

| Field | Value |
|-------|-------|
| Type | `task` |
| Priority | `medium` |
| Raised by | DevOps Specialist |
| Blocking | `no` |
| Reference | psc-adv-0001, F-DXS-006 |

**Description:** `configure_firewall` in `setup-floci.sh` never removes stale UFW rules when the firewall scope changes.

**Evidence:** See F-DXS-006 above.

**Suggested action:** Add UFW rule cleanup logic or document the manual reset requirement.

### Flag: advisory — dev-twin AWS credentials in shared file

| Field | Value |
|-------|-------|
| Type | `advisory` |
| Priority | `medium` |
| Raised by | DevOps Specialist |
| Blocking | `no` |
| Reference | psc-adv-0001, F-DXS-005 |

**Description:** `dev_env` writes Floci test credentials to the user's real `~/.aws/credentials` file, creating a risk of accidental use against real AWS endpoints.

**Evidence:** See F-DXS-005 above.

**Suggested action:** Use a separate credentials file or add cleanup on `dev_reset`.
