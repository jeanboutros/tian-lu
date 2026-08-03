# A1-SX: Security Reviewer Requirements — psc-0003

| Field | Value |
|-------|-------|
| Agent | security-reviewer |
| Timestamp | 2026-07-30T23:00:00Z |
| Step | A1-SX |
| Verdict | CONDITIONAL PASS |
| Severity | 9 |

## Self-Audit Checklist

| Category | Checked? | Finding or PASS |
|----------|----------|-----------------|
| Build passes (exit 0, no warnings) | N/A — Phase A, no code to build | PASS — design review only |
| Typed enums / vocabulary types (no raw integers in API) | N/A — bash/Terraform, not C++ | PASS — not applicable to this domain |
| Documentation on new public symbols | N/A — Phase A requirements | PASS — requirements analysis, not implementation |
| Spec/datasheet fidelity (fields match spec) | yes | PASS — all claims verified against `docs/scraped/`, AWS IAM docs, Terraform source |
| Module boundary (no platform headers in shared modules) | N/A — not a C/C++ project | PASS |
| Reserved/padding fields handled | N/A | PASS |
| No magic numbers in doc examples | N/A | PASS |
| Buffer safety (bounded copies) | yes | PASS — CH-AUTH-004 (sed range delete), CH-AUTH-007 (atomic write), CH-AUTH-008 (word-splitting) all address buffer/data-safety |
| AGENTS.md compliance | yes | PASS — all findings cite authoritative sources, follow flag-protocol format |
| Conventional commit ready | N/A — Phase A | PASS |

## Security Requirements Analysis

### SPEC-SX-001 — CH-AUTH-001: SigV4 + 12-digit AKID incompatibility

**Security impact assessment:**
The estate's entire IAM security model depends on SigV4 signature validation. The current design uses 12-digit AKIDs (`111111111111`) to select the environment account, but Floci's multi-account resolution treats 12-digit AKIDs as account identifiers and does NOT validate their secrets by default (`docs/scraped/multi-account.md:60`). Under `FLOCI_AUTH_VALIDATE_SIGNATURES=true`, Floci must resolve a secret for the presented AKID to verify the signature — but `111111111111` was never minted by Floci IAM, so no secret is bound to it. The rotated deployer key (`AKIA…`) is non-12-digit, so it resolves to `FLOCI_DEFAULT_ACCOUNT_ID` (`000000000000`), not the dev account.

**Security impact:** The only credential that can authenticate under `sigv4` resolves to account `000000000000`, while the estate declares dev to be `111111111111`. Either the estate silently relocates to `000000000000` (invalidating all ARN-based claims in landing-zone §4.2), or requests are rejected outright and no Terraform stage applies. There is no escape via `iam create-access-key`: the AKID is server-generated, so a key whose ID is literally `111111111111` cannot be minted.

**Required changes:**
1. Move the account axis from the AKID to installer configuration — one Floci instance per environment, with `FLOCI_DEFAULT_ACCOUNT_ID` set per-environment.
2. Change `_common/providers.tf` so `access_key` is the deployer's real AKID (rotated, sourced from `DEV_CREDENTIALS_FILE`), not `var.account_id`. Keep `var.account_id` as the assertion target — add a `data.aws_caller_identity` + `precondition` that fails the plan when the resolved account id does not equal `var.account_id`.
3. Update `preflight-floci.sh` accordingly: the AKID must be the deployer key, not `DEV_AKID`; `DEV_AKID` becomes the expected account id the gates assert against.
4. Update landing-zone §4.1/§4.2 to state that under `sigv4` the environment is selected by the instance's `FLOCI_DEFAULT_ACCOUNT_ID`, not by the client's AKID.
5. Run the three-outcome probe to determine whether a 12-digit AKID with a wrong secret is (a) rejected, (b) accepted and namespaced to the AKID value, or (c) accepted and mapped to `FLOCI_DEFAULT_ACCOUNT_ID`. Outcome (b) would mean the estate's headline security claim is unenforced.

**Verification method:**
```sh
AWS_ACCESS_KEY_ID=111111111111 AWS_SECRET_ACCESS_KEY=wrong-on-purpose \
  aws --endpoint-url http://localhost:4566 --region eu-west-2 sts get-caller-identity
```
Record the result in the gaps register.

**OWASP/security principle mapping:**
- OWASP A07:2021 — Identification and Authentication Failures. The credential that selects the account cannot authenticate under the mode that enforces authentication.
- Security principle: Defense in depth. The account-selection mechanism and the authentication mechanism are coupled in a way that makes them mutually exclusive.
- Security principle: Secure-by-default. The default `FLOCI_DEFAULT_ACCOUNT_ID=000000000000` silently relocates resources to an unexpected account.

**Confidence:** 90 (Critical) — CITED + INFERRED. The incompatibility is documented in Floci's own docs; the probe will confirm the exact behaviour.

---

### SPEC-SX-002 — CH-AUTH-002: FLOCI_AUTH_UNSAFE_OVERRIDE escape hatch security review

**Security impact assessment:**
The current §4.2 `${VAR:-default}` pattern lets an exported sub-variable override the mode independently. `FLOCI_AUTH_MODE=off FLOCI_AUTH_VALIDATE_SIGNATURES=true` produces `signatures=true enforcement=false` — the exact "crypto theater" state that §4.1 marks as "worse than leaving both off" and §8.3 claims is impossible. This is a **privilege-escalation-by-environment-variable** vulnerability: any process that can set environment variables in the installer's execution context can force the forbidden posture.

The proposed fix introduces `FLOCI_AUTH_UNSAFE_OVERRIDE=1` as an explicit, named escape hatch. This is a **defense-in-depth improvement**: the override is now gated behind a deliberately scary variable name that must be explicitly set, rather than being reachable through any inherited or mistyped export.

**Security review of the escape hatch itself:**
- The override is **opt-in only** — default `0` means the posture is unconditionally derived from `FLOCI_AUTH_MODE`.
- The override is **documented as unsafe** in the variable name and the code comment.
- The override is **test-gated** — a bats case must prove the hole is closed: `FLOCI_AUTH_MODE=off` + `FLOCI_AUTH_VALIDATE_SIGNATURES=true` must yield `false` in the env file.
- The `_auth_*` helpers are `unset` after use, preventing leakage into the shell environment.

**Residual risk:** The escape hatch itself is a deliberate backdoor. It exists for testing and must never be set in production. The risk is accepted because:
1. It requires an explicit, named variable (`FLOCI_AUTH_UNSAFE_OVERRIDE=1`), not an accidental export.
2. The production installer (`setup-floci.sh` direct invocation) never sets it.
3. The dev twin and test twin are the only consumers, and they are development tools.

**Required changes:**
1. Rewrite §4.2 to derive posture unconditionally from `FLOCI_AUTH_MODE` with the `FLOCI_AUTH_UNSAFE_OVERRIDE` gate.
2. Add a bats case proving the hole is closed.
3. `unset _auth_*` helpers after use.

**Verification method:**
```sh
# Must produce signatures=false enforcement=false (not true/false)
FLOCI_AUTH_MODE=off FLOCI_AUTH_VALIDATE_SIGNATURES=true bash -c '<new §4.2 block>'
```
Bats test: assert `FLOCI_AUTH_VALIDATE_SIGNATURES=false` in the env file when `FLOCI_AUTH_MODE=off`.

**OWASP/security principle mapping:**
- OWASP A01:2021 — Broken Access Control. An environment variable can override the security posture.
- OWASP A05:2021 — Security Misconfiguration. The `${VAR:-default}` pattern creates an unintended configuration surface.
- Security principle: Secure-by-default. The new design makes the secure posture the only reachable state without an explicit override.
- Security principle: Least privilege. The escape hatch is the minimum necessary deviation for testing.

**Confidence:** 95 (Critical) — VERIFIED. The forbidden posture was demonstrated with a live bash execution.

---

### SPEC-SX-003 — CH-AUTH-003: FLOCI_SERVICES_IAM_ENABLED=true in both branches

**Security impact assessment:**
`FLOCI_SERVICES_IAM_ENABLED` (default `true`) is the IAM *service* on/off switch. Setting it `false` in `off` mode disables IAM entirely — not just enforcement, but the entire IAM API surface. This means:
- `preflight-floci.sh` G1 cannot create its probe user → G1 SKIPs (compounding CH-LZ-004).
- `infra/live/10-management-iam` cannot apply at all.
- Any stage referencing a role ARN fails.

The `off` mode should disable *enforcement* (no policy evaluation), not the IAM *service* (no IAM API at all). The IAM service must remain available so that the landing-zone Terraform stages can create IAM resources even when enforcement is off — this is the "trusted-LAN dev" use case where IAM is modeled but not enforced.

**Required changes:**
1. `FLOCI_SERVICES_IAM_ENABLED=true` in both branches, or omit it entirely and let the image default (`true`) stand.
2. Only `FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED` tracks the mode.
3. Correct §6.2's note and SPEC-TX-006 case-3 direction — the assertion should be `=true` in *both* modes, not mode-dependent.

**Verification method:**
- Bats test: assert `FLOCI_SERVICES_IAM_ENABLED=true` in the env file for both `off` and `sigv4` modes.
- Twin test: verify `preflight-floci.sh` G1 can create its probe user in `off` mode.

**OWASP/security principle mapping:**
- OWASP A05:2021 — Security Misconfiguration. Disabling the IAM service when only enforcement was intended.
- Security principle: Least privilege. The `off` mode should reduce enforcement, not remove the ability to model IAM.

**Confidence:** 92 (Critical) — CITED. The variable's purpose is documented at `docs/scraped/environment-variables.md:160-161`.

---

### SPEC-SX-004 — CH-AUTH-004: Credential file sed range delete destroying user's AWS profiles

**Security impact assessment:**
`sed '/^\[tianlu-floci-dev\]/,/^\[/d'` deletes the range **inclusive of its terminating line** — the next profile's header. The following profile's key lines survive without their header, becoming orphaned. After the append, those orphaned keys sit above `[tianlu-floci-dev]` and are silently absorbed by whatever section precedes them. The file is then `chmod 0600`'d.

**Security impact:** Silent data loss in a file outside the project's ownership (`~/.aws/credentials`). The user's real AWS credentials (e.g., production `[default]` profile) are destroyed. The AWS CLI rejects the malformed file, and the user has no indication that their credentials were corrupted rather than the Floci endpoint being unreachable.

**Required changes:**
1. Replace the `sed` range delete with an `awk` section-aware rewrite that tracks section boundaries explicitly.
2. Use atomic write: write to `.tmp`, `chmod 0600` the tmp, `mv -f`.
3. Add 7 bats cases:
   - `[tianlu-floci-dev]` followed by `[default]` → `[default]` header and both keys survive verbatim.
   - `[tianlu-floci-dev]` as the last section → replaced cleanly, no residue.
   - `[tianlu-floci-dev]` absent → block appended, all pre-existing profiles byte-identical.
   - Two pre-existing unrelated profiles surrounding the managed block → both intact.
   - File absent → created with mode 0600, single block.
   - Idempotency: two consecutive runs produce byte-identical output.
   - Resulting file mode is 0600 and the first non-blank line is a section header.

**Verification method:**
Bats tests as specified above. The `awk` rewrite must be verified against the exact failure mode demonstrated in the advisory.

**OWASP/security principle mapping:**
- OWASP A01:2021 — Broken Access Control. Destroying the user's AWS credentials can grant or deny access to real AWS resources.
- Security principle: Least privilege. The script must not touch profiles it does not own.

**Confidence:** 98 (Critical) — VERIFIED. The data-loss mechanism was demonstrated with a live execution.

---

### SPEC-SX-005 — CH-AUTH-005: Delete-failure handler unreachable under set -e

**Security impact assessment:**
Under `errexit` (`set -e`), a bare simple command returning non-zero terminates the shell. The `delete_rc=$?` line is unreachable on precisely the path it exists to handle — when `delete-access-key` fails. The WARNING that §9.3 lists as the remediation for "partial-failure leaves well-known key active" never prints.

**Security impact:** If `create-access-key` succeeds but `delete-access-key` fails, the well-known `floci`/`floci` credential remains active alongside the new rotated key. The user is never warned. This is a **silent credential leak** — the old key is still usable by anyone who knows the public `floci`/`floci` values, and the rotation appears to have succeeded.

**Required changes:**
```bash
delete_rc=0
_run_as_floci_guest "podman exec … iam delete-access-key …" || delete_rc=$?
```
Audit the rest of §6.5 for the same pattern before implementation.

**Verification method:**
- Bats test: stub `delete-access-key` to fail; assert the WARNING is emitted and `delete_rc` is non-zero.
- Code audit: grep §6.5 for bare simple commands that can fail.

**OWASP/security principle mapping:**
- OWASP A07:2021 — Identification and Authentication Failures. A stale credential remains active after rotation.
- Silent failure pattern: The error handler is unreachable — a classic silent-failure anti-pattern (Pattern 2: Unchecked Return Values, adapted for bash `errexit` semantics).

**Confidence:** 95 (Critical) — VERIFIED. Bash `errexit` semantics are deterministic.

---

### SPEC-SX-006 — CH-AUTH-007: Non-atomic credential file write

**Security impact assessment:**
`printf … > "$DEV_CREDENTIALS_FILE"` then `chmod 0600` has two windows:
1. A crash mid-write leaves a truncated file.
2. The file exists at umask permissions (typically 0644 or 0022) until the `chmod`.

**Security impact:** The truncated case fails quietly in the worst direction. §6.6 sources the file and `${DEV_BOOTSTRAP_AKID:-test}` falls back to `test/test` — so the user gets signature failures against a `sigv4` Floci with no indication that their credential cache is corrupt. The permissions window exposes the rotated secret to other users on the system for the duration between `printf` and `chmod`.

Additionally, `source` on this file *executes* it — any shell injection in the credential values would be executed. Parse instead (`while IFS='=' read -r k v`).

**Required changes:**
1. Write to `.tmp`, `chmod 0600` the tmp, `mv -f` (mirroring `setup-floci.sh:822-841`).
2. Parse the file with `read` instead of `source` (also removes SC1090 suppressions).

**Verification method:**
- Bats test: verify the file is never visible at non-0600 permissions (check the tmp file permissions before the `mv`).
- Bats test: verify truncated-write recovery (simulate by writing partial content to the tmp, then `mv`).

**OWASP/security principle mapping:**
- OWASP A04:2021 — Insecure Design. Non-atomic file writes create TOCTOU windows.
- OWASP A05:2021 — Security Misconfiguration. Credential file exposed at umask permissions.
- Security principle: Defense in depth. Atomic writes + correct permissions from birth.

**Confidence:** 90 (Critical) — VERIFIED. The correct pattern already exists in `setup-floci.sh:822-841`.

---

### SPEC-SX-007 — CH-AUTH-014: Presign-secret threat model

**Security impact assessment:**
`FLOCI_AUTH_PRESIGN_SECRET` mints presigned S3 URLs that **bypass the IAM layer** the entire authentication plan is about. This matters more here than in a generic deployment because the Terraform state bucket is S3 (landing-zone §9) — a presign capability over the state bucket is equivalent to administrative access to the entire estate.

**Specific threats:**
1. **IAM bypass:** A presigned URL for `s3://tf-state-dev/dev/10-management-iam/terraform.tfstate` with `PUT` permission allows an attacker to overwrite the Terraform state without any IAM authentication. The state file contains all resource ARNs, secrets, and the full infrastructure graph.
2. **Secret persistence:** `generate_presign_secret`'s reuse-if-exists behaviour (`setup-floci.sh:793-801`) means the secret survives every re-install until explicitly rotated. There is no rotation path documented.
3. **Secret exposure:** The secret is written to the env file (`setup-floci.sh:835`) at mode 0600, but it is not marked as sensitive in any documentation, and there is no warning in `print_summary` about its power.

**Required changes:**
1. Add a threat model section to `authentication-plan.md` documenting:
   - What the presign secret protects (S3 presigned URL integrity).
   - What it bypasses (IAM authentication and authorization).
   - The blast radius (full S3 access, including Terraform state).
2. Add a rotation path: document how to rotate the presign secret and what breaks (existing presigned URLs become invalid).
3. Add a note that `generate_presign_secret`'s reuse-if-exists behaviour means the secret survives re-installs.
4. Cross-link from landing-zone §12 (security model summary) to note that presigned URLs bypass IAM.
5. Consider adding a `print_summary` warning when `FLOCI_AUTH_PRESIGN_SECRET` is in use alongside `sigv4` mode.

**Verification method:**
- Documentation review: verify the threat model section exists and covers the three threats above.
- Gap register entry: record that presigned URLs are an IAM bypass.

**OWASP/security principle mapping:**
- OWASP A01:2021 — Broken Access Control. Presigned URLs bypass the IAM authorization layer.
- OWASP A04:2021 — Insecure Design. The presign secret is a static, long-lived credential with no rotation path.
- Security principle: Defense in depth. The IAM layer is the primary boundary; presigned URLs create a parallel, unguarded path.

**Confidence:** 80 (High) — CITED. The mechanism is documented in `docs/scraped/environment-variables.md:22`; the blast radius is inferred from the S3 state backend design.

---

### SPEC-SX-008 — CH-LZ-001: DenyAllExceptBoundary unconditional deny

**Security impact assessment:**
The `DenyAllExceptBoundary` statement uses `StringNotEquals` on `iam:PermissionsBoundary` with `resources = ["*"]`. Per AWS IAM documentation, `iam:PermissionsBoundary` is present in the request context only for operations that *attach* a boundary (`CreateRole`, `CreateUser`, `PutRolePermissionsBoundary`, `PutUserPermissionsBoundary`). It is **absent** for `DeletePolicy`, `DeletePolicyVersion`, `DeleteRolePermissionsBoundary`, `DeleteUserPermissionsBoundary`. When the key is absent (null), inverted condition operators like `StringNotEquals` **match** the null value — so the Deny fires unconditionally on every one of those calls.

**Security impact:** The statement is equivalent to having no condition at all — it is an unconditional deny on `Resource = "*"`. `platform-admin` can never delete any policy or policy version, anywhere. `terraform destroy` on stage 10 fails. `terraform apply` fails once a customer-managed policy reaches the five-version limit and needs `DeletePolicyVersion`. The delegated-administration ceiling that landing-zone §5.1 and §12 describe does not exist in either direction: creation without a boundary is *not* denied (no statement covers `iam:CreateRole` at all), and boundary removal is unconditionally denied.

Additionally, `iam:DeleteGroupPermissionsBoundary` is not a valid IAM API action — permissions boundaries apply to users and roles only.

**Required changes:**
1. Replace the single `DenyAllExceptBoundary` with three separate statements:
   - **DenyPrincipalCreationWithoutBoundary:** `StringNotEquals` on `iam:PermissionsBoundary` for `CreateRole`, `CreateUser`, `PutRolePermissionsBoundary`, `PutUserPermissionsBoundary` — this is the only set where the condition key is present and the inverted operator is meaningful.
   - **DenyBoundaryPolicyMutation:** Deny `DeletePolicy`, `DeletePolicyVersion`, `CreatePolicyVersion`, `SetDefaultPolicyVersion` on the boundary policy ARN — no condition, scoped by resource.
   - **DenyBoundaryDetach:** Deny `DeleteRolePermissionsBoundary`, `DeleteUserPermissionsBoundary` on `*` — no condition.
2. Drop the non-existent `iam:DeleteGroupPermissionsBoundary` action.
3. Add a G6 negative test: mint a role with a boundary denying `s3:*`, attach an identity policy allowing `s3:ListAllMyBuckets`, assume it, and require the call to be **denied**.

**Verification method:**
- G6 gate: the negative test described above.
- IAM Access Analyzer: the `EQUIVALENT_TO_NULL_FALSE` check would flag the current statement.

**OWASP/security principle mapping:**
- OWASP A01:2021 — Broken Access Control. The guardrail became a blanket deny that breaks legitimate operations.
- OWASP A04:2021 — Insecure Design. The condition was applied to actions where the key is absent, making it inert in the wrong direction.
- Security principle: Defense in depth. The three-statement form separates concerns by whether the condition key exists in the request context.

**Confidence:** 92 (Critical) — CITED. AWS IAM documentation explicitly documents the absent-key matching behaviour for inverted operators.

---

### SPEC-SX-009 — CH-LZ-002: Permissions-boundary evaluation unverified; G6 gate needed

**Security impact assessment:**
Landing-zone §1.1 lists API authorization as **Enforced**, and §5.2/§12 build the escalation ceiling on the permissions boundary being the effective-permission intersection. However, `docs/scraped/environment-variables.md:161` promises only "enforce IAM policies on API calls" — permissions-boundary evaluation is a distinct IAM feature from identity-policy evaluation. Nothing in `docs/scraped/` states that Floci implements it, and no gate in §10.1 tests it.

**Security impact:** If Floci evaluates identity policies but ignores boundaries, §5.1–§5.2 are *modeled*, not enforced — and that is the single most important security claim in the design. The consequence is exactly the "false demo" class that §10.1 exists to prevent: the `platform-admin` could create a role without the boundary, or a role with a boundary could exceed its ceiling, and no gate would detect it.

**Required changes:**
1. Add gate G6: mint a role with a boundary denying `s3:*`, attach an identity policy allowing `s3:ListAllMyBuckets`, assume it, and require the call to be **denied**.
2. Until G6 passes, §1.1's row must read "Enforced (identity policies); boundary evaluation unverified".
3. §5.2/§12 must be qualified with the same caveat.
4. Record as a gap-register entry.

**Verification method:**
G6 gate execution against a live `sigv4` Floci. The test is falsifiable: if the `s3:ListAllMyBuckets` call succeeds despite the boundary denying `s3:*`, boundary evaluation is not enforced.

**OWASP/security principle mapping:**
- OWASP A01:2021 — Broken Access Control. The permissions boundary — the primary escalation ceiling — may not be enforced.
- OWASP A04:2021 — Insecure Design. A security control is claimed as enforced without verification.
- Security principle: Trust but verify. Every "Enforced" row in a fidelity table needs a named gate.

**Confidence:** 85 (High) — INFERRED. Absence of evidence; the probe will confirm or refute.

---

### SPEC-SX-010 — CH-LZ-004: G1 degrades to SKIP where design promises hard stop

**Security impact assessment:**
If `create-access-key` fails (line 46-48 of `preflight-floci.sh`), G1 calls `skip` and returns. `skip` does not set `FAILED`, so `main` reports "automated gates passed" and exits 0. Landing-zone §10.1:398 states G1 is "a hard stop."

**Security impact:** Under `sigv4` with the default credentials (`$DEV_AKID` + `test`), the `create-access-key` call always fails (per CH-AUTH-001) — so the gate the design calls a hard stop reports success on precisely the configuration it exists to police. Compounded by CH-AUTH-003: with `IAM_ENABLED=false` in `off` mode, it also always skips. This is a **false-negative security gate** — the most dangerous kind, because it creates confidence in a control that is not functioning.

**Required changes:**
1. G1 must `fail` when it cannot establish the probe — an unestablished gate is not a passed gate.
2. Distinguish "IAM unreachable" from "IAM reachable and permissive" in the failure message.
3. Make `main` exit non-zero on any SKIP among the automated gates (G1, G3) while leaving the manual-notes gates (G2, G4, G5) as SKIP.

**Verification method:**
- Bats test: stub `create-access-key` to fail; assert G1 reports FAIL (not SKIP) and `main` exits non-zero.
- Twin test: run `preflight-floci.sh` against a `sigv4` Floci with the current default credentials; assert it fails (not passes).

**OWASP/security principle mapping:**
- OWASP A09:2021 — Security Logging and Monitoring Failures. A security gate reports success when it cannot function.
- Security principle: Fail-secure. A gate that cannot establish its precondition must fail closed, not open.

**Confidence:** 95 (Critical) — VERIFIED. The `skip` function's behaviour is deterministic from the source.

---

### SPEC-SX-011 — CH-LZ-007: S3 conditional PutObject unverified (use_lockfile alternative)

**Security impact assessment:**
Landing-zone §9 offers `use_lockfile = true` (S3-native locking) as an alternative to DynamoDB locking. S3-native locking uses a conditional `PutObject` with `IfNoneMatch: "*"` — a distinct capability from the DynamoDB conditional write that G3 verifies. Nothing establishes that Floci's S3 honours `IfNoneMatch`, and an ignored header means two concurrent `terraform apply` operations both acquire the lock and corrupt state.

**Security impact:** Concurrent writes to the Terraform state file without locking → state corruption → potential resource orphanage or destruction. The state file is the single source of truth for the entire infrastructure estate.

**Required changes:**
1. Add gate G3b: `aws s3api put-object --if-none-match '*'` twice; the second must fail with `PreconditionFailed`.
2. Until G3b passes, mark `use_lockfile` as unverified in §9 and `backend.hcl.example`, and state that it must not be used.

**Verification method:**
G3b gate execution against a live Floci S3 endpoint.

**OWASP/security principle mapping:**
- OWASP A08:2021 — Software and Data Integrity Failures. State corruption from missing locking.
- Security principle: Trust but verify. An offered alternative must be verified before it can be used.

**Confidence:** 90 (Critical) — CITED. The `IfNoneMatch` mechanism is documented in the Terraform S3 backend source.

---

### SPEC-SX-012 — CH-LZ-011: default_tags merge order allows tfvars override of governance tags

**Security impact assessment:**
`merge({Project, Environment = var.environment, ManagedBy}, var.default_tags)` puts `var.default_tags` **second**, so it wins. A `dev.tfvars` with `Environment = "production"` would silently override the governance tag — no plan warning, no error. This is how `Environment = "development"` overrode `var.environment = "dev"` in the first place.

**Security impact:** ABAC conditions in landing-zone §5.3 match on the `Environment` tag. A mistagged resource could be accessible to the wrong environment's policies, or excluded from the correct environment's policies. The override is silent — `merge` precedence produces no diagnostic.

**Required changes:**
1. Reverse the merge order: `merge(var.default_tags, {Project = "tianlu", Environment = var.environment, ManagedBy = "terraform"})` — governance tags always win.
2. Add `environment` variable validation: `condition = contains(["dev", "uat", "prod"], var.environment)`.

**Verification method:**
- Terraform plan: verify that a `dev.tfvars` with `Environment = "production"` in `default_tags` still produces `Environment = "dev"` on resources.
- Lint check: verify the validation rejects invalid environment values.

**OWASP/security principle mapping:**
- OWASP A01:2021 — Broken Access Control. Tag-based access control can be silently bypassed.
- OWASP A05:2021 — Security Misconfiguration. Merge order creates an unintended override surface.
- Security principle: Secure-by-default. Governance tags must be immutable by downstream configuration.

**Confidence:** 95 (Critical) — VERIFIED. Terraform `merge` semantics are deterministic.

---

## Cross-Cutting Security Concerns

### 1. Credential Lifecycle Management

The estate has **five distinct credential types**, each with different lifecycle requirements:

| Credential | Location | Rotation | Current State |
|-----------|----------|----------|---------------|
| `floci`/`floci` (bootstrap) | Floci image | Rotated immediately by dev twin | Public knowledge; rotation specified but buggy (CH-AUTH-005) |
| Rotated deployer key | `DEV_CREDENTIALS_FILE` | Per-recreate | Non-atomic write (CH-AUTH-007); no host-side recording of mode (CH-AUTH-013) |
| `FLOCI_AUTH_PRESIGN_SECRET` | Floci env file | None documented | Survives re-installs; no rotation path (CH-AUTH-014) |
| `secret_key` (Terraform provider) | `TF_VAR_secret_key` | Must track deployer rotation | No documented command supplies it (CH-LZ-013) |
| `test`/`test` (off mode) | Multiple scripts | N/A | Hardcoded in `preflight-floci.sh:35`, `dev-twin.sh:769` |

**Requirement:** Every credential must have a documented rotation path, a known blast radius, and a verification step that the new credential works before the old one is deleted.

### 2. IAM Condition Key Safety

CH-META-002 establishes a standing rule: **any IAM `Condition` on a service-specific key must state which actions populate that key, and any Deny intended as a ceiling needs a negative test before it counts as landed.** This applies to:
- `iam:PermissionsBoundary` in `DenyAllExceptBoundary` (CH-LZ-001)
- Any future condition on `aws:RequestedRegion`, `ec2:SourceInstanceARN`, etc.

### 3. Environment Variable Injection Surface

CH-AUTH-002 and CH-META-003 establish that the installer's environment variable surface is an attack vector. The `${VAR:-default}` pattern, while convenient for testing, creates unintended override surfaces. The `FLOCI_AUTH_UNSAFE_OVERRIDE` pattern is the correct mitigation: explicit, named, documented, and test-gated.

### 4. Security Gate Reliability

CH-LZ-004 establishes that a security gate that can silently degrade to SKIP is worse than no gate at all — it creates false confidence. All automated security gates (G1, G3, G3b, G6) must:
- **Fail closed** when they cannot establish their precondition.
- **Distinguish** "unreachable" from "reachable and permissive" in their output.
- **Exit non-zero** on any failure or unestablished precondition.

## Verdict

**VERDICT: CONDITIONAL PASS**

**SEVERITY: 9** (High risk — CH-AUTH-001 and CH-LZ-001 are blockers for the landing zone deployment)

**FINDINGS:**
| Severity | ID | Description |
|----------|-----|-------------|
| 9 | SPEC-SX-001 | CH-AUTH-001: SigV4 + 12-digit AKID incompatibility — the credential that selects the account cannot authenticate under the mode that enforces authentication |
| 9 | SPEC-SX-002 | CH-AUTH-002: Environment variable injection allows the forbidden `signatures=on, enforcement=off` posture |
| 9 | SPEC-SX-003 | CH-AUTH-003: `FLOCI_SERVICES_IAM_ENABLED=false` in `off` mode disables the IAM API surface entirely |
| 9 | SPEC-SX-004 | CH-AUTH-004: `sed` range delete destroys the user's other AWS profiles — silent data loss outside project ownership |
| 9 | SPEC-SX-005 | CH-AUTH-005: Delete-failure handler unreachable under `set -e` — silent credential leak |
| 9 | SPEC-SX-006 | CH-AUTH-007: Non-atomic credential file write — TOCTOU permissions window and truncation risk |
| 8 | SPEC-SX-007 | CH-AUTH-014: Presign-secret bypasses IAM; no threat model, no rotation path; state bucket is S3 |
| 9 | SPEC-SX-008 | CH-LZ-001: `DenyAllExceptBoundary` is an unconditional deny — `StringNotEquals` matches null key |
| 8 | SPEC-SX-009 | CH-LZ-002: Permissions-boundary evaluation claimed as enforced but never gated |
| 9 | SPEC-SX-010 | CH-LZ-004: G1 degrades to SKIP where design promises hard stop — false-negative security gate |
| 9 | SPEC-SX-011 | CH-LZ-007: S3 conditional PutObject unverified — `use_lockfile` alternative may corrupt state |
| 9 | SPEC-SX-012 | CH-LZ-011: `default_tags` merge order allows tfvars to silently override governance tags |

**ROUTING:** code-architect (for implementation of all SPEC-SX requirements in Phase B)

**RATIONALE:** All 12 findings in the SX scope are accepted by the user and must be remediated. The CONDITIONAL PASS reflects that the requirements are well-specified and the fixes are clearly defined, but the severity-9 findings (CH-AUTH-001, CH-LZ-001, CH-LZ-004) are blockers that must be resolved before the landing zone can be deployed on Floci. The three-outcome probe for CH-AUTH-001 is a prerequisite — outcome (b) would require rewriting the estate's headline security claims.

**BLOCKING FINDINGS (confidence ≥80):** All 12 findings are blocking. The highest-severity items (9) are SPEC-SX-001, SPEC-SX-002, SPEC-SX-003, SPEC-SX-004, SPEC-SX-005, SPEC-SX-006, SPEC-SX-008, SPEC-SX-010, SPEC-SX-011, SPEC-SX-012.

## References

| Claim / Decision | Source | Verification |
|-----------------|--------|-------------|
| Floci 12-digit AKID account resolution | `docs/scraped/multi-account.md:9-10,60` | CITED — "If the AKID is exactly 12 digits, it is used as the account ID… Floci does not validate signatures by default" |
| `FLOCI_SERVICES_IAM_ENABLED` default and purpose | `docs/scraped/environment-variables.md:160-161` | CITED — IAM service on/off switch, default `true`; enforcement is separate variable |
| IAM absent-key evaluation for inverted operators | [AWS IAM: Policy variables with no value](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_variables.html) | CITED — "Inverted condition operators like StringNotEquals… do match against a null value" |
| IAM policy check `EQUIVALENT_TO_NULL_FALSE` | [AWS IAM: Access Analyzer policy checks](https://docs.aws.amazon.com/IAM/latest/UserGuide/access-analyzer-reference-policy-checks.html) | CITED |
| Permissions boundaries apply to users and roles only | [AWS IAM: PutUserPermissionsBoundary API](https://docs.aws.amazon.com/IAM/latest/APIReference/API_PutUserPermissionsBoundary.html) | CITED — no group permissions boundary API |
| Terraform S3 backend `use_lockfile` conditional PutObject | `internal/backend/remote-state/s3/client.go`, hashicorp/terraform | CITED — `IfNoneMatch: "*"` |
| Terraform `merge` function precedence | [Terraform: merge function](https://developer.hashicorp.com/terraform/language/functions/merge) | CITED — later arguments override earlier |
| Bash `errexit` semantics for bare simple commands | [Bash manual: set -e](https://www.gnu.org/software/bash/manual/html_node/The-Set-Builtin.html) | VERIFIED — bare command returning non-zero terminates shell |
| `FLOCI_AUTH_PRESIGN_SECRET` | `docs/scraped/environment-variables.md:22` | CITED — presigned URL verification secret |
| `generate_presign_secret` reuse-if-exists | `setup-floci.sh:793-801` | VERIFIED — static analysis of source |
