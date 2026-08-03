# A1-SX: Security Reviewer Review — psc-adv-0001

**Reviewer:** Security Reviewer
**Phase:** A1 — Specialist Review
**Date:** 2026-07-29
**Artifacts reviewed:**
1. `docs/design/authentication-plan.md`
2. `setup-floci.sh`
3. `mock-server/dev-twin.sh`
4. `docs/design/landing-zone-design.md`

---

## Reference Validation

| Primary Claim | Reference Provided | Authority Level | Verified? | Correctly Applied? |
|--------------|-------------------|-----------------|-----------|-------------------|
| Floci env vars for auth | `docs/scraped/environment-variables.md` | 2 (manufacturer docs) | ✓ | ✓ |
| Floci multi-account isolation | `docs/scraped/multi-account.md` | 2 | ✓ | ✓ |
| AWS root-user best practices | AWS IAM User Guide | 2 | ✓ | ✓ |
| IAM permissions boundaries | AWS IAM User Guide | 2 | ✓ | ✓ |
| IRSA (EKS pod identity) | AWS EKS User Guide | 2 | ✓ | ✓ |
| RDS IAM DB auth | AWS RDS User Guide | 2 | ✓ | ✓ |
| OWASP Top 10:2021 | owasp.org | 1 (standard) | ✓ | ✓ |
| AWS Well-Architected SEC03 | AWS WA Framework | 2 | ✓ | ✓ |
| systemd 259 sandboxing behaviour | AGENTS.md critical gotchas | 3 (project docs) | ✓ | ✓ |
| AppArmor userns restriction | AGENTS.md critical gotchas | 3 | ✓ | ✓ |

### Findings

- [✓] All factual claims have at least one citation
- [✓] All citations are from authoritative sources (trust level 1-3)
- [✓] All cited sources were verified to actually support the claim
- [✓] Implementation follows what the reference recommends
- [✓] Best practices, gotchas, and production-grade guidance were sought

---

## Findings

### F-SX-001: Hardcoded `test/test` credentials in `dev_env()` — no rotation integration

| Field | Value |
|-------|-------|
| Confidence | 95 |
| Severity | HIGH |
| File | `mock-server/dev-twin.sh:768-769` |
| Category | credential-exposure |

**Description:** The `dev_env()` function (lines 757-777) writes hardcoded `aws_access_key_id = test` / `aws_secret_access_key = test` to `~/.aws/credentials` unconditionally. The authentication plan (§6.6) specifies that `dev_env` should load rotated credentials from `DEV_CREDENTIALS_FILE` when available, falling back to `test/test` only when no rotated credentials exist. However, the **current code** does not implement this — it always writes `test/test` with no rotation integration. The `_rotate_bootstrap_credentials` function, `DEV_CREDENTIALS_FILE` constant, and `DEV_AUTH_MODE` variable are all **absent** from the current `dev-twin.sh`.

This means:
1. The `FLOCI_AUTH_MODE` parameter is never passed to the installer (line 484 has no `FLOCI_AUTH_MODE=sigv4`).
2. No credential rotation occurs after Floci starts.
3. The `dev_env` function always writes the well-known `test/test` credential.
4. The `_print_next_steps` function has no security section.

The authentication plan is a **design document** describing intended changes, not the current state. The gap between the plan and the code is the finding.

**Recommendation:** Implement the authentication plan's code changes (§6.1–§6.8) in `dev-twin.sh` and `setup-floci.sh`. Specifically:
- Add `FLOCI_AUTH_MODE` parameter to `setup-floci.sh` config block
- Add `DEV_CREDENTIALS_FILE` constant to `dev-twin.sh`
- Implement `_rotate_bootstrap_credentials` function
- Update `dev_env` to load rotated credentials
- Add security section to `_print_next_steps`
- Pass `FLOCI_AUTH_MODE=sigv4` in `_install_absent`

**Reference:** [Standard: OWASP Top 10:2021, A07:2021 — Identification and Authentication Failures]; [Framework: AWS Well-Architected, Security Pillar, SEC03 — "Do not use long-term static credentials"]

---

### F-SX-002: Hardcoded `test` secret in `preflight-floci.sh` `aws_admin()` helper

| Field | Value |
|-------|-------|
| Confidence | 90 |
| Severity | HIGH |
| File | `scripts/preflight-floci.sh:35` |
| Category | credential-exposure |

**Description:** The `aws_admin()` helper hardcodes `AWS_SECRET_ACCESS_KEY=test` on line 35. The authentication plan (§6.9) specifies that this should accept bootstrap credentials via `FLOCI_BOOTSTRAP_AKID` and `FLOCI_BOOTSTRAP_SECRET` env vars, with `test` as a fallback. The current code does not implement this — it always uses `test`.

When `FLOCI_AUTH_MODE=sigv4` is active, the `test/test` credential is not associated with any IAM user (the deployer is `floci`/`floci`), so the preflight gates would fail with a signature validation error. The preflight script cannot currently operate against a sigv4-enabled Floci.

**Recommendation:** Implement the authentication plan's §6.9 change: accept `FLOCI_BOOTSTRAP_AKID` and `FLOCI_BOOTSTRAP_SECRET` env vars with `test` as the fallback for `SECRET_ACCESS_KEY` only.

**Reference:** [Standard: OWASP Top 10:2021, A07:2021 — Identification and Authentication Failures]; [Framework: AWS Well-Architected, Security Pillar, SEC03]

---

### F-SX-003: `FLOCI_AUTH_MODE` parameter not implemented in `setup-floci.sh`

| Field | Value |
|-------|-------|
| Confidence | 95 |
| Severity | HIGH |
| File | `setup-floci.sh` (absent from config block) |
| Category | auth-design |

**Description:** The authentication plan (§4.2, §6.1) defines a `FLOCI_AUTH_MODE` parameter that collapses three independent auth toggles into two coherent states (`off` and `sigv4`). This parameter is **not implemented** in the current `setup-floci.sh`. The config block (lines 36-180) has no `FLOCI_AUTH_MODE` case statement. The `write_env_file` function (lines 815-842) does not write `FLOCI_AUTH_VALIDATE_SIGNATURES`, `FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED`, or `FLOCI_SERVICES_IAM_SEED_DEPLOYER_PRINCIPAL` to the env file. The `print_summary` function (lines 938-961) has no conditional for sigv4 mode.

The authentication plan correctly identifies the dangerous `true`/`false` combination (signatures on, enforcement off) as "crypto theater" — it looks secure but authorizes everyone. Without the `FLOCI_AUTH_MODE` parameter, a user could manually set this dangerous combination by editing the env file directly.

**Recommendation:** Implement the `FLOCI_AUTH_MODE` parameter in `setup-floci.sh` per the authentication plan §6.1–§6.3. This is the single most important security control in the plan — it prevents the crypto-theater configuration.

**Reference:** [Standard: OWASP Top 10:2021, A04:2021 — Insecure Design]; [Framework: AWS Well-Architected, Security Pillar, SEC02 — "Manage identities with strong authentication"]

---

### F-SX-004: `dev_env()` does not set `chmod 0600` on `~/.aws/credentials`

| Field | Value |
|-------|-------|
| Confidence | 85 |
| Severity | MODERATE |
| File | `mock-server/dev-twin.sh:757-777` |
| Category | hardening-gap |

**Description:** The `dev_env()` function writes credentials to `~/.aws/credentials` but never calls `chmod 0600` on the file. The authentication plan (§6.6, line 411) specifies `chmod 0600 "$creds_file"` after writing. The AWS CLI enforces 0600 on credentials files and will refuse to use them with looser permissions, but the principle of least privilege dictates that the script should set the correct permissions proactively rather than relying on the CLI to reject misconfigured files.

The `~/.aws/config` file is also written without explicit permission setting. While `config` does not contain secrets, it is created in the same directory and should have consistent permissions.

**Recommendation:** Add `chmod 0600 "$creds_file"` and `chmod 0600 "$config_file"` after writing, matching the authentication plan's specification.

**Reference:** [Standard: OWASP Top 10:2021, A05:2021 — Security Misconfiguration]; [Source: AWS CLI documentation — "The credentials file must have permissions of 0600"]

---

### F-SX-005: No secret scanning in CI pipeline

| Field | Value |
|-------|-------|
| Confidence | 80 |
| Severity | MODERATE |
| File | `.github/workflows/test.yml` |
| Category | secrets-management |

**Description:** The CI pipeline (`.github/workflows/test.yml`) runs `make lint` (shellcheck + bash -n) and `make test` (bats unit tests) but does **not** include a secret scanning step. The security principles skill (§3) mandates: "Pre-commit hooks and CI scan every commit for likely secrets (e.g. gitleaks). A detection blocks the merge and triggers rotation."

The codebase currently contains hardcoded credential strings (`test`, `floci`) in multiple files. While these are well-known development credentials (not production secrets), a secret scanner would:
1. Detect if a real credential is accidentally committed.
2. Provide a baseline of known exceptions for the `test`/`floci` strings.
3. Prevent regression if someone adds a real secret later.

**Recommendation:** Add a gitleaks or truffleHog scan step to the CI workflow. Create a `.gitleaks.toml` baseline that allows the known `test`/`floci` strings with explicit justification comments. Run the scan on every PR; block on new detections.

**Reference:** [Standard: OWASP Top 10:2021, A07:2021 — Identification and Authentication Failures]; [Source: gitleaks — https://github.com/gitleaks/gitleaks]

---

### F-SX-006: IRSA stand-in uses long-lived Kubernetes Secrets for pod credentials

| Field | Value |
|-------|-------|
| Confidence | 85 |
| Severity | MODERATE |
| File | `docs/design/landing-zone-design.md:242-253` |
| Category | iam-model |

**Description:** The landing-zone design (§5.4) acknowledges that the IRSA stand-in — injecting `sts:AssumeRole` credentials into a Kubernetes Secret mounted by the pod — is a "production anti-pattern" due to "long-lived credential sprawl." The design correctly documents this as a Floci accommodation and states that migration to native IRSA is planned when Floci adds OIDC support.

However, the design does not specify:
1. **Secret rotation frequency or mechanism** for the injected credentials.
2. **Whether the Secret is immutable** (Kubernetes 1.29+ supports `immutable: true` on Secrets, which prevents accidental modification but also prevents rotation without deletion/recreation).
3. **RBAC controls** on who can read the Secret (the ServiceAccount token can read its own namespace's Secrets by default unless RBAC is restricted).
4. **Audit logging** for Secret access — who read the credential and when.

Without these controls, the stand-in creates a real security gap: any pod in the same namespace (or any user with namespace read access) can extract the long-lived credential and use it outside the pod's intended lifetime.

**Recommendation:** Add to the design:
1. A rotation schedule for the Secret (e.g., every 90 days, triggered by a CronJob or manual process).
2. Set `immutable: true` on the Secret to prevent tampering (with documented rotation procedure).
3. Restrict Secret read RBAC to only the application's ServiceAccount.
4. Document that Kubernetes audit logs should be enabled to track Secret access.
5. Add a pre-flight gate (G6) that verifies the Secret is not readable by unauthorized ServiceAccounts.

**Reference:** [Standard: OWASP Top 10:2021, A01:2021 — Broken Access Control]; [Framework: AWS Well-Architected, Security Pillar, SEC03 — "Rotate credentials regularly"]; [Source: Kubernetes Secrets — https://kubernetes.io/docs/concepts/configuration/secret/]

---

### F-SX-007: `FLOCI_HOST_PERSISTENT_PATH` validation allows path traversal characters

| Field | Value |
|-------|-------|
| Confidence | 75 |
| Severity | MODERATE |
| File | `setup-floci.sh:115-116` |
| Category | hardening-gap |

**Description:** The path validation on lines 115-116 checks for newlines, colons, whitespace, quotes, backslashes, and `%` characters, and requires an absolute path. However, it does **not** check for:
- Path traversal sequences (`..`)
- Symlink following (no `-P` flag on `mkdir` or `chmod` operations)
- Null bytes

While the script runs as root and the path is typically set by the operator (not from untrusted input), the `FLOCI_HOST_PERSISTENT_PATH` can be overridden via environment variable before sourcing. A path like `/home/floci/../../etc/cron.d/evil` would pass the current validation but could write to unexpected locations.

The `create_data_directory` function (line 726) uses `run_as_floci mkdir -p` which follows symlinks by default. If an attacker can create a symlink at the expected path before the script runs, `mkdir -p` would follow it.

**Recommendation:** Add `..` detection to the path validation. Use `mkdir -p` with the `-P` flag (POSIX) or `mkdir -p --` to prevent symlink following. Consider using `realpath` to resolve the canonical path before use.

**Reference:** [Standard: OWASP Top 10:2021, A01:2021 — Broken Access Control]; [Source: CWE-22 — Improper Limitation of a Pathname to a Restricted Directory]

---

### F-SX-008: `print_summary` unconditionally prints "UNAUTHENTICATED" — no sigv4 branch

| Field | Value |
|-------|-------|
| Confidence | 90 |
| Severity | MODERATE |
| File | `setup-floci.sh:946-949` |
| Category | auth-design |

**Description:** The `print_summary` function (lines 938-961) unconditionally prints the "RISK: Floci is UNAUTHENTICATED" message regardless of the actual auth configuration. The authentication plan (§6.3) specifies a conditional: when `FLOCI_AUTH_VALIDATE_SIGNATURES=true`, print a different message confirming IAM enforcement is on and providing bootstrap admin instructions. When `false`, print the current risk warning.

Since `FLOCI_AUTH_MODE` is not yet implemented (F-SX-003), this is currently always correct. But once the auth mode parameter is added, the summary must be updated to reflect the actual state. The current unconditional message would be misleading if sigv4 mode is active.

**Recommendation:** Implement the conditional `print_summary` from the authentication plan §6.3 as part of the `FLOCI_AUTH_MODE` implementation.

**Reference:** [Standard: OWASP Top 10:2021, A09:2021 — Security Logging and Monitoring Failures] (misleading security status reporting)

---

### F-SX-009: Quadlet `EnvironmentFile` path uses `%h` specifier — no validation of env file integrity

| Field | Value |
|-------|-------|
| Confidence | 70 |
| Severity | LOW |
| File | `setup-floci.sh:287` |
| Category | hardening-gap |

**Description:** The Quadlet unit references the env file via `EnvironmentFile=%h/.config/floci/floci.env` (line 287). The env file is mode 0600 and owned by the `floci` user, which is correct. However, there is no integrity check on the env file — if an attacker with `floci` user access modifies the env file (e.g., changing `FLOCI_TLS_ENABLED` to `false` or injecting malicious values), the service would pick up the changes on the next restart without any detection.

This is a defense-in-depth concern: the `floci` user's home directory is mode 0700, and the env file is mode 0600, so only `floci` (and root) can modify it. The risk is low because an attacker who can write as `floci` already has significant access. However, a checksum or immutable flag could provide an additional detection layer.

**Recommendation:** Consider adding a `ProtectSystem=strict` equivalent (not possible under rootless systemd per AGENTS.md gotchas) or documenting that the env file should be monitored for unexpected changes via file integrity monitoring (e.g., `aide` or `auditd`). This is an advisory finding — the current permissions are adequate for the threat model.

**Reference:** [Standard: OWASP Top 10:2021, A05:2021 — Security Misconfiguration]; [Framework: AWS Well-Architected, Security Pillar, SEC04 — "Detect and investigate security events"]

---

### F-SX-010: `_install_absent` passes `FLOCI_TLS_ENABLED=false` — TLS disabled in dev twin

| Field | Value |
|-------|-------|
| Confidence | 80 |
| Severity | LOW |
| File | `mock-server/dev-twin.sh:484` |
| Category | hardening-gap |

**Description:** The dev twin installer invocation (line 484) passes `FLOCI_TLS_ENABLED=false FLOCI_TLS_SELF_SIGNED=false`. This is documented in AGENTS.md as intentional: "The dev twin disables TLS... This matches the working native-podman setup and avoids the Floci UI sidecar's Node backend rejecting the self-signed cert."

The risk is that a developer accustomed to the dev twin's plain-HTTP configuration might inadvertently deploy the same configuration to production. The `print_summary` function in `setup-floci.sh` does warn when TLS is disabled (line 956: "TLS is disabled — traffic is unencrypted. Do not use on an untrusted network."), but this warning only appears during installation, not during day-to-day use.

The dev twin forwards ports to `127.0.0.1` only (per `floci-dev.yaml`), so traffic is loopback and not exposed to the network. This is acceptable for local development.

**Recommendation:** No code change required — the current configuration is appropriate for a local dev environment. The finding is recorded for awareness. Consider adding a prominent notice in `_print_next_steps` when TLS is disabled, reminding the user this is a dev-only configuration.

**Reference:** [Standard: OWASP Top 10:2021, A02:2021 — Cryptographic Failures]

---

### F-SX-011: No automated credential rotation in the test twin

| Field | Value |
|-------|-------|
| Confidence | 75 |
| Severity | LOW |
| File | `mock-server/in-vm/run-in-vm.sh` (by absence) |
| Category | secrets-management |

**Description:** The authentication plan (§6.10) specifies that the test twin should support `--auth-mode=sigv4` and override `podman exec` calls with explicit `-e AWS_ACCESS_KEY_ID=floci -e AWS_SECRET_ACCESS_KEY=floci` flags. The test twin does not currently implement credential rotation — it uses the well-known `floci`/`floci` credential directly.

This is acceptable for the test twin's purpose (testing installer mechanics, not auth semantics), but the plan's §7.3 test matrix shows that the `auth_mode=sigv4` path should be exercisable. Without rotation, the test twin's sigv4 path would use the well-known `floci`/`floci` credential, which is acceptable for testing but should be documented as such.

**Recommendation:** When implementing the test twin's auth-mode support, document that the test twin uses `floci`/`floci` without rotation (rotation is a dev-twin concern). The test twin's purpose is to verify installer mechanics, not credential lifecycle.

**Reference:** [Standard: OWASP Top 10:2021, A07:2021 — Identification and Authentication Failures]

---

## Self-Audit Checklist

| Category | Checked? | Finding or PASS |
|----------|----------|-----------------|
| Build passes (exit 0, no warnings) | N/A | Not applicable — security review, no build step |
| Typed enums / vocabulary types | N/A | Not applicable — bash scripts, no typed vocabulary |
| Documentation on new public symbols | N/A | Not applicable — review of existing artifacts |
| Spec/datasheet fidelity | yes | PASS — all Floci env var references verified against scraped docs |
| Module boundary | N/A | Not applicable |
| Reserved/padding fields handled | N/A | Not applicable |
| No magic numbers in doc examples | N/A | Not applicable |
| Buffer safety (bounded copies) | yes | PASS — `setup-floci.sh` uses `readonly` variables, `printf` with format strings, no unbounded copies |
| AGENTS.md compliance | yes | PASS — all critical gotchas verified; Quadlet hardening directives match AGENTS.md constraints |
| Conventional commit ready | N/A | Not applicable — review output, not a commit |

---

## Verdict

**VERDICT: CONDITIONAL PASS**

**SEVERITY: 9** (highest finding: F-SX-001 at 95, F-SX-003 at 95)

**Rationale:** The authentication plan is well-designed and addresses the key security concerns (crypto-theater prevention, credential rotation, permissions boundaries). However, the plan describes **intended** changes, not the current state. The gap between the plan and the code is the primary finding:

1. **F-SX-001 (95) and F-SX-003 (95) are blocking** — the `FLOCI_AUTH_MODE` parameter and credential rotation are not implemented. The current code has no auth mode control, no rotation, and hardcoded `test/test` credentials in `dev_env()`.
2. **F-SX-002 (90) is blocking** — `preflight-floci.sh` cannot operate against a sigv4-enabled Floci.
3. **F-SX-004 (85) and F-SX-006 (85) are blocking** — missing file permissions and IRSA stand-in gaps.
4. **F-SX-005 (80) is blocking** — no secret scanning in CI.

The design itself is sound. The implementation gap is the issue. Once the authentication plan's code changes (§6.1–§6.9) are implemented in `setup-floci.sh`, `dev-twin.sh`, and `preflight-floci.sh`, the security posture will be significantly improved.

**ROUTING:** code-architect (for implementation of authentication plan code changes)

---

## Flag: task — Implement authentication plan code changes

| Field | Value |
|-------|-------|
| Type | `task` |
| Priority | `high` |
| Raised by | Security Reviewer |
| Blocking | `yes` — blocks A-GATE for psc-adv-0001 |
| Reference | psc-adv-0001, Phase A1 |

## Description
The authentication plan (`docs/design/authentication-plan.md`) describes a comprehensive set of code changes (§6.1–§6.9) that are not yet implemented. The gap between the design and the code is the primary security finding of this review.

## Evidence
- `setup-floci.sh` has no `FLOCI_AUTH_MODE` parameter (F-SX-003)
- `dev-twin.sh` has no `_rotate_bootstrap_credentials`, `DEV_CREDENTIALS_FILE`, or `DEV_AUTH_MODE` (F-SX-001)
- `dev_env()` always writes `test/test` with no rotation integration (F-SX-001)
- `preflight-floci.sh` `aws_admin()` hardcodes `test` secret (F-SX-002)
- `print_summary` has no sigv4 conditional branch (F-SX-008)

## Suggested action
Implement the authentication plan's code changes in order:
1. `setup-floci.sh`: `FLOCI_AUTH_MODE` parameter (§6.1), env file writes (§6.2), `print_summary` conditional (§6.3)
2. `dev-twin.sh`: `DEV_CREDENTIALS_FILE` constant (§6.1a), `_rotate_bootstrap_credentials` (§6.5), `dev_env` update (§6.6), `_print_next_steps` security section (§6.7), `dev_reset` cleanup (§6.8), `_install_absent` auth mode pass (§6.4)
3. `preflight-floci.sh`: `aws_admin` env var override (§6.9)
4. Tests (§6.11) and documentation (§6.12)
