# A1-SW: Software Engineer Review — psc-adv-0001

| Field | Value |
|-------|-------|
| Agent | software-engineer |
| Timestamp | 2026-07-29T18:30:00Z |
| Step | A1-SW |
| Verdict | CONDITIONAL PASS |

## Findings

### F-SW-001: `FLOCI_AUTH_MODE` design is sound but `FLOCI_SERVICES_IAM_ENABLED` interaction is undocumented

| Field | Value |
|-------|-------|
| Confidence | 85 |
| Severity | HIGH |
| File | docs/design/authentication-plan.md |
| Category | gap |

**Description:** The `FLOCI_AUTH_MODE` parameter correctly collapses three independent toggles into two coherent states (`off` and `sigv4`), preventing the dangerous `sig=on, enforcement=off` crypto-theater combination. However, the design does not address `FLOCI_SERVICES_IAM_ENABLED` (default `true` per [docs/scraped/environment-variables.md:160](../scraped/environment-variables.md)). The IAM service itself must be enabled for enforcement to work. If a user or future script sets `FLOCI_SERVICES_IAM_ENABLED=false` while `FLOCI_AUTH_MODE=sigv4`, the three auth vars would be `true` but the IAM service would be disabled — a silent failure where SigV4 verification and policy enforcement are configured but the IAM service that evaluates them is off. The `FLOCI_AUTH_MODE` case statement does not set `FLOCI_SERVICES_IAM_ENABLED`.

**Recommendation:** In the `sigv4` branch of the `FLOCI_AUTH_MODE` case statement, explicitly set `FLOCI_SERVICES_IAM_ENABLED=true`. Document this interaction in the auth plan §4.2. This is a one-line addition to the case statement and a paragraph in the design doc.

---

### F-SW-002: `setup-floci.sh` does not yet implement `FLOCI_AUTH_MODE` — auth plan is a design, not implemented

| Field | Value |
|-------|-------|
| Confidence | 90 |
| Severity | HIGH |
| File | setup-floci.sh |
| Category | gap |

**Description:** The authentication plan (§6.1–§6.3) specifies concrete code changes to `setup-floci.sh`: add the `FLOCI_AUTH_MODE` case statement to the config block, write the three auth vars to the env file, and update `print_summary` with a conditional auth message. None of these changes exist in the current `setup-floci.sh` (verified by grep — no `FLOCI_AUTH_MODE`, `FLOCI_AUTH_VALIDATE_SIGNATURES`, or `FLOCI_SERVICES_IAM` references exist in the script except the hardcoded risk message at line 946). The `print_summary` at line 946 still prints the old hardcoded "RISK: Floci is UNAUTHENTICATED by default" message unconditionally. The auth plan is a design document describing intended changes, not a reflection of current state. This is a gap between design and implementation.

**Recommendation:** The auth plan should be treated as a Phase A design artifact that feeds into a Phase B implementation ticket. The current `setup-floci.sh` is architecturally sound as-is (the design patterns are correct), but the auth plan's code changes need a separate implementation ticket. The auth plan should explicitly state its implementation status (e.g., "Status: Design — not yet implemented in setup-floci.sh").

---

### F-SW-003: `general_app_boundary` is a `data` source, not a `resource` — cannot be referenced by `platform_admin` condition

| Field | Value |
|-------|-------|
| Confidence | 95 |
| Severity | CRITICAL |
| File | infra/live/10-management-iam/main.tf:28, 60, 66 |
| Category | feasibility |

**Description:** The `platform_admin` policy document references `aws_iam_policy.general_app_boundary.arn` in two places (line 28: condition value, line 60: Deny resource). However, `general_app_boundary` is defined as a `data "aws_iam_policy_document"` (line 66), not an `aws_iam_policy` resource. There is no `resource "aws_iam_policy" "general_app_boundary"` block in this file. A `data.aws_iam_policy_document` is a Terraform data source that produces a JSON policy document — it has no `.arn` attribute. The reference `aws_iam_policy.general_app_boundary.arn` would fail at `terraform plan` with "Reference to undeclared resource" because no resource with that local name exists. This is confirmed by `infra/AGENTS.md` which states: "`general_app_boundary` is `data`-only (no `aws_iam_policy` resource). Stub until Phase 1."

The `platform_admin` policy itself IS a resource (`resource "aws_iam_policy" "platform_admin"` at line 94), but it references a non-existent resource in its own policy document. This is a circular dependency even if fixed: `platform_admin`'s policy document references `general_app_boundary.arn`, but `general_app_boundary` would need to be created first.

**Recommendation:** Add `resource "aws_iam_policy" "general_app_boundary" { name = "general_app_boundary"; policy = data.aws_iam_policy_document.general_app_boundary.json }` before the `platform_admin` policy document. The `platform_admin` data source can then reference `aws_iam_policy.general_app_boundary.arn`. This is a standard Terraform pattern and fixes the reference error. The `infra/AGENTS.md` note about this being a "stub" should be updated to reflect the fix.

---

### F-SW-004: Provider version mismatch between `_common/versions.tf` and `10-management-iam/providers.tf`

| Field | Value |
|-------|-------|
| Confidence | 90 |
| Severity | HIGH |
| File | infra/_common/versions.tf:17 vs infra/live/10-management-iam/providers.tf:7 |
| Category | architecture |

**Description:** `_common/versions.tf` pins the AWS provider at `>= 5.95.0, < 7.0.0`, but `10-management-iam/providers.tf` hardcodes `version = ">= 6.56.0"` (no upper bound). This is acknowledged in `infra/AGENTS.md` ("reconcile before adding downstream stages, or `terraform init` will fail with a constraint conflict in the first stage that copies both files"). The `10-management-iam` stage currently has no `versions.tf` copied from `_common/` — it inlines the provider version in `providers.tf`. When downstream stages copy both `_common/versions.tf` and a `providers.tf` that references the `_common` template, the constraint `>= 5.95.0, < 7.0.0` from `versions.tf` will conflict with `>= 6.56.0` from the inline `providers.tf` if the resolved version is between 5.95 and 6.56.

**Recommendation:** Either (a) reconcile `10-management-iam/providers.tf` to use `>= 5.95.0, < 7.0.0` matching `_common/`, or (b) update `_common/versions.tf` to `>= 6.56.0, < 7.0.0` and document the reason for the floor. Option (a) is preferred since the `_common/` template is the canonical source of truth. This should be fixed before Phase 1 implementation begins.

---

### F-SW-005: `dev.tfvars` `default_tags` duplicates `Project`/`ManagedBy` and contains invalid `Environment` value

| Field | Value |
|-------|-------|
| Confidence | 85 |
| Severity | HIGH |
| File | infra/environments/dev.tfvars:24-29 |
| Category | architecture |

**Description:** The `dev.tfvars` `default_tags` map includes `Project = "tianlu"`, `Environment = "development"`, and `ManagedBy = "terraform"`. However, `10-management-iam/providers.tf` line 33 already merges `{Project="tianlu", Environment=var.environment, ManagedBy="terraform"}` into `default_tags`. The `providers.tf` merge uses `var.environment` (which is `"dev"` from the tfvars), but the tfvars also sets `Environment = "development"` — a different value. This creates a duplicate-key conflict in the `merge()` call: Terraform will error on `terraform plan` with "Duplicate key" for `Project`, `Environment`, and `ManagedBy`. This is acknowledged in `infra/AGENTS.md` as a "KNOWN BUG."

Additionally, the `providers.tf` merge at line 33 is `merge({}, var.default_tags)` — the empty first argument means the merge is effectively just `var.default_tags`. The canonical `Project`/`Environment`/`ManagedBy` tags from the `_common/providers.tf` template are not being injected. The `10-management-iam/providers.tf` deviates from the `_common/` template pattern.

**Recommendation:** Remove `Project`, `Environment`, and `ManagedBy` from `dev.tfvars` `default_tags`. Fix the `providers.tf` merge to inject the canonical trio: `merge({Project = "tianlu", Environment = var.environment, ManagedBy = "terraform"}, var.default_tags)`. This matches the `_common/providers.tf` template pattern and the `infra/AGENTS.md` guidance.

---

### F-SW-006: `secret_key` variable is required but has no default and no documentation on how to supply it

| Field | Value |
|-------|-------|
| Confidence | 80 |
| Severity | HIGH |
| File | infra/live/10-management-iam/variables.tf:8-11 |
| Category | gap |

**Description:** The `secret_key` variable is declared as `type = string` with `sensitive = true` but no `default` value. This means `terraform apply` will prompt interactively for it, or fail in non-interactive contexts (CI, scripts). The `dev.tfvars` file does not include a `secret_key` value. The `infra/README.md` apply instructions do not mention how to supply the secret key. In `auth_mode=off`, the secret can be any non-empty string (e.g., `test`), but in `auth_mode=sigv4`, it must be the actual deployer credential. The design documents (auth plan §6.9, landing-zone §10.1) reference `FLOCI_BOOTSTRAP_SECRET` and `DEV_BOOTSTRAP_SECRET` but the Terraform variable is `secret_key` — the mapping between these names is not documented.

**Recommendation:** Add `secret_key` to `dev.tfvars` with a documented default for `auth_mode=off` (e.g., `secret_key = "test"`). Document in `infra/README.md` that for `auth_mode=sigv4`, the user must override this with the rotated deployer secret. Alternatively, add a `terraform.tfvars.example` file showing the pattern. The variable name `secret_key` should be cross-referenced with `FLOCI_BOOTSTRAP_SECRET`/`DEV_BOOTSTRAP_SECRET` in the auth plan.

---

### F-SW-007: `setup-floci.sh` design patterns are architecturally sound

| Field | Value |
|-------|-------|
| Confidence | 95 |
| Severity | N/A (positive finding) |
| File | setup-floci.sh |
| Category | architecture |

**Description:** The installer demonstrates strong architectural patterns:

1. **Idempotency by design:** Every function checks state before acting (`getent passwd` before `useradd`, `podman network inspect` before `network create`, `systemctl is-active` before `start`). The `add_hosts_entry` function uses a managed marker block with awk-based strip-and-replace, making "block already correct" and "stale block" converge on the same code path.

2. **Atomic writes:** `write_env_file` and `write_quadlet_unit` both use the `.tmp` sidecar + `chmod` + `mv -f` pattern, ensuring a mid-write crash never leaves a truncated target file. The `add_hosts_entry` function uses the same pattern for `/etc/hosts`.

3. **Privilege model:** Clear separation — root for system operations (useradd, apt, ufw, apparmor_parser), `run_as_floci` helper for all Podman/systemd user operations. The helper correctly sets `HOME`, `USER`, `PATH`, `XDG_RUNTIME_DIR`, and `DBUS_SESSION_BUS_ADDRESS`.

4. **Configuration injection:** All parameters use `${VAR:-default}` form, making the script testable (bats can inject overrides by exporting before sourcing). Values are frozen with `readonly` immediately after.

5. **Sourceable guard:** `if [[ "${BASH_SOURCE[0]}" == "${0}" ]]` at line 1018 allows bats to load functions without executing `main`.

6. **Defensive validation:** `FLOCI_HOST_PERSISTENT_PATH` is validated for absolute path and safe characters (no newlines, colons, whitespace, quotes, backslashes, or `%`).

7. **Backup-before-overwrite:** Both `write_env_file` and `write_quadlet_unit` back up existing files to `.bak` before overwriting.

These patterns are consistent, well-documented, and follow the project's bash-scripting conventions. No architectural concerns.

---

### F-SW-008: Landing-zone IAM delegation model is correct but `platform-admin` is a policy without a principal

| Field | Value |
|-------|-------|
| Confidence | 85 |
| Severity | HIGH |
| File | infra/live/10-management-iam/main.tf |
| Category | gap |

**Description:** The `10-management-iam` stage creates `aws_iam_policy.platform_admin` (the policy document defining what `platform-admin` can do) but does not create the IAM user, group, or role that would hold this policy. The landing-zone design (§5.1) describes `platform-admin` as "an assumable administrative identity (group + user + role)" but the Terraform code only creates the policy. The `infra/AGENTS.md` acknowledges this: "no users/roles/groups" and "Stub until Phase 1." However, the auth plan (§3.1, §3.3) describes the lifecycle as `floci-deployer → platform-admin → app roles` and implies `platform-admin` is a concrete identity that supersedes the deployer. Without the IAM user/role resources, the `platform-admin` concept exists only as a policy document — there is no principal to assume it.

**Recommendation:** The `10-management-iam` stage should create at minimum an `aws_iam_user "platform_admin"` and attach the policy. The auth plan should note that `platform-admin` is not yet materialized in Terraform. This is a Phase 1 implementation task, not a design flaw, but the gap between design documents (which speak of `platform-admin` as if it exists) and Terraform code (which has only the policy) should be explicitly documented in the auth plan §3.3.

---

### F-SW-009: `FLOCI_AUTH_MODE` case statement uses `readonly` inside a `case` branch — works in bash but is unconventional

| Field | Value |
|-------|-------|
| Confidence | 70 |
| Severity | MODERATE |
| File | docs/design/authentication-plan.md:133-148 |
| Category | design |

**Description:** The proposed `FLOCI_AUTH_MODE` case statement (auth plan §4.2) uses `readonly FLOCI_AUTH_VALIDATE_SIGNATURES="false"` inside a `case` branch. In bash, `readonly` inside a conditional branch works — the variable is made readonly at the point of assignment. However, this is unconventional: `readonly` is typically used at the top level of a script, and using it inside a `case` means the variable is only declared readonly on one code path. If the script is sourced by bats for testing, the `readonly` flag persists across test runs and can cause "readonly variable" errors on subsequent assignments. The existing `setup-floci.sh` pattern is to declare all config variables with `readonly` at the top level using the `${VAR:-default}` form, which is test-friendly because bats can export overrides before sourcing.

**Recommendation:** Move the three auth vars to the top-level config block with the `${VAR:-default}` pattern, and have the `FLOCI_AUTH_MODE` case statement set non-readonly variables that the top-level block then freezes. Alternatively, use a different pattern: compute the values in the case statement into local variables, then declare the readonly versions at the top level referencing those locals. This is a moderate concern — the current design works but deviates from the established script convention and may cause test friction.

---

### F-SW-010: Credential rotation design has a TOCTOU race between `create-access-key` and `delete-access-key`

| Field | Value |
|-------|-------|
| Confidence | 75 |
| Severity | MODERATE |
| File | docs/design/authentication-plan.md:339-353 |
| Category | design |

**Description:** The rotation flow in `_rotate_bootstrap_credentials` (auth plan §6.5) creates a new access key, then deletes the old one. Between these two operations, both keys are simultaneously valid. If the script or VM crashes after `create-access-key` succeeds but before `delete-access-key` completes, the old key remains active alongside the new one. The design handles this with a WARNING on delete failure (line 355-359), but a crash (SIGKILL, power loss, OOM) would leave no warning. This is a TOCTOU (time-of-check-to-time-of-use) race at the process level, not a security vulnerability — both keys authenticate as the same principal (`floci-deployer`), so the blast radius is limited to credential sprawl, not privilege escalation.

**Recommendation:** Document this as an accepted risk in the auth plan §5.4 (fallback section). The mitigation is already present: `dev-reset` deletes the credentials file, and a fresh `dev-up` rotates again. The risk is low because (a) both keys belong to the same principal, (b) the dev twin is a local development environment, and (c) `dev-reset` provides a clean recovery path. No code change needed.

---

### F-SW-011: `setup-floci.sh` `print_summary` hardcodes auth risk message — will be stale after `FLOCI_AUTH_MODE` implementation

| Field | Value |
|-------|-------|
| Confidence | 80 |
| Severity | HIGH |
| File | setup-floci.sh:946-949 |
| Category | gap |

**Description:** The current `print_summary` at line 946 unconditionally prints "RISK: Floci is UNAUTHENTICATED by default (FLOCI_AUTH_VALIDATE_SIGNATURES=false)." After the `FLOCI_AUTH_MODE` implementation (auth plan §6.3), this should be conditional: print a different message when `FLOCI_AUTH_VALIDATE_SIGNATURES=true`. The auth plan §6.3 specifies the replacement text. This is a known gap — the auth plan explicitly addresses it — but it's worth flagging because the current script's summary message will be misleading once `FLOCI_AUTH_MODE=sigv4` is implemented. The risk message is correct for the current default (`off`), but the implementation ticket for the auth plan must include the `print_summary` update.

**Recommendation:** Ensure the Phase B implementation ticket for the auth plan includes the `print_summary` conditional update from auth plan §6.3. This is a straightforward code change with no architectural implications.

---

### F-SW-012: Landing-zone design's "enforced vs. modeled" table is a strong architectural pattern

| Field | Value |
|-------|-------|
| Confidence | 90 |
| Severity | N/A (positive finding) |
| File | docs/design/landing-zone-design.md:28-42 |
| Category | architecture |

**Description:** The landing-zone design's §1.1 table explicitly distinguishes between controls that Floci *enforces* (IAM, k3s NetworkPolicy, real PostgreSQL) and controls that are *modeled* (VPC/SG/TGW as Terraform records with no data-plane effect). This is architecturally critical because it prevents the common mistake of assuming VPC security groups provide network isolation on Floci when they don't. The design correctly identifies IAM as the primary enforced security boundary and layers Kubernetes NetworkPolicy for pod-to-pod traffic. The "design rule" at line 39-42 — "author the intent in Terraform exactly as it would appear in real AWS, and layer the enforced equivalent alongside it" — is a principled approach that makes promotion to real AWS a matter of swapping modeled resources for native counterparts. This pattern should be preserved in all future design documents.

---

## Self-Audit Checklist

| Category | Checked? | Finding or PASS |
|----------|----------|-----------------|
| Build passes (exit 0, no warnings) | N/A | No build step — design review only |
| Typed enums / vocabulary types (no raw integers in API) | N/A | Bash scripts, not C++ — not applicable |
| Documentation on new public symbols | yes | Auth plan §6 documents all new functions and code changes with file:line references |
| Spec/datasheet fidelity (fields match spec) | yes | Floci env vars verified against [docs/scraped/environment-variables.md:21,160-162] |
| Module boundary (no platform headers in shared modules) | yes | `setup-floci.sh` is self-contained; `infra/` stages are independent root modules with clear dependency graph |
| Reserved/padding fields handled | N/A | Not applicable to bash/Terraform |
| No magic numbers in doc examples | yes | Auth plan uses named constants (`FLOCI_AUTH_MODE`, `DEV_CREDENTIALS_FILE`); landing-zone uses variables |
| Buffer safety (bounded copies) | N/A | Not applicable to design review |
| AGENTS.md compliance | yes | All findings cite authoritative references; no implementation code written |
| Conventional commit ready | N/A | Design review — no commit |

## Reference Validation

| Primary Claim | Reference Provided | Authority Level | Verified? | Correctly Applied? |
|--------------|-------------------|-----------------|-----------|-------------------|
| Floci auth env vars (`FLOCI_AUTH_VALIDATE_SIGNATURES`, `FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED`, `FLOCI_SERVICES_IAM_SEED_DEPLOYER_PRINCIPAL`) | [docs/scraped/environment-variables.md:21,160-162] | 2 (official scraped docs) | ✓ | ✓ |
| `FLOCI_SERVICES_IAM_ENABLED` default `true` | [docs/scraped/environment-variables.md:160] | 2 | ✓ | ✓ |
| Floci multi-account isolation via 12-digit AKID | [docs/scraped/multi-account.md:158] | 2 | ✓ | ✓ |
| AWS IAM permissions boundaries | [AWS IAM User Guide](https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies_boundaries.html) | 2 | ✓ | ✓ |
| AWS Well-Architected SEC01 (account separation) | [landing-zone-design.md:480] | 2 | ✓ | ✓ |
| Terraform S3 backend + DynamoDB locking | [landing-zone-design.md:502] | 2 | ✓ | ✓ |
| `general_app_boundary` is `data`-only, no `resource` | [infra/AGENTS.md] (KNOWN BUG note) | 8 (project-internal) | ✓ | ✓ |
| Provider version mismatch acknowledged | [infra/AGENTS.md] (reconcile note) | 8 | ✓ | ✓ |
| `dev.tfvars` `default_tags` duplicate bug acknowledged | [infra/AGENTS.md] (KNOWN BUG note) | 8 | ✓ | ✓ |

### Findings

- [✓] All factual claims have at least one citation
- [✓] All citations are from authoritative sources (trust level 1-8)
- [✓] All cited sources were verified to actually support the claim
- [✓] Implementation follows what the reference recommends (where applicable)
- [✓] Best practices, gotchas, and production-grade guidance were sought

## Verdict

**CONDITIONAL PASS**

**Rationale:** The architectural design across all three artifacts is fundamentally sound. The `FLOCI_AUTH_MODE` parameter design correctly prevents dangerous configuration combinations. The landing-zone IAM delegation model (permissions boundary, one-role-per-app, ABAC) follows AWS best practices. The `setup-floci.sh` installer demonstrates strong design patterns (idempotency, atomic writes, privilege separation, configuration injection). 

However, three findings block unconditional approval:

1. **F-SW-003 (CRITICAL, 95):** `general_app_boundary` is a `data` source with no corresponding `resource`, causing `platform_admin` policy references to fail at `terraform plan`. This is a concrete feasibility blocker.

2. **F-SW-002 (HIGH, 90):** The auth plan describes code changes that are not yet implemented in `setup-floci.sh`. The design is correct but the gap between design and implementation must be explicitly tracked.

3. **F-SW-004 (HIGH, 90):** Provider version mismatch between `_common/versions.tf` and `10-management-iam/providers.tf` will cause `terraform init` failures in downstream stages.

The remaining findings (F-SW-001, F-SW-005, F-SW-006, F-SW-008, F-SW-009, F-SW-010, F-SW-011) are advisory or implementation-level concerns that do not block the architectural approval but should be addressed before Phase B implementation.

**Blocking findings (confidence ≥80):** F-SW-001, F-SW-002, F-SW-003, F-SW-004, F-SW-005, F-SW-006, F-SW-008, F-SW-011
**Advisory findings (confidence <80):** F-SW-009, F-SW-010
