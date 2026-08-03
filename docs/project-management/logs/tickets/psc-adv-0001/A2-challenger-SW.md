# A2-Challenger-SW: Dual-Model Challenge — psc-adv-0001

**Agent:** software-engineer-challenger (glm-5.2)
**Timestamp:** 2026-07-29T23:00:00Z
**Phase:** A2
**Ticket:** psc-adv-0001
**Primary review challenged:** `docs/project-management/logs/tickets/psc-adv-0001/A1-SW-software-engineer.md`
**Artifacts cross-checked:** `setup-floci.sh`, `docs/design/authentication-plan.md`, `docs/design/landing-zone-design.md`, `infra/live/10-management-iam/main.tf`, `infra/live/10-management-iam/providers.tf`, `infra/live/10-management-iam/variables.tf`, `infra/_common/providers.tf`, `infra/_common/versions.tf`, `infra/environments/dev.tfvars`, `infra/AGENTS.md`, `infra/live/00-backend-bootstrap/main.tf`, `docs/scraped/environment-variables.md`

---

## Reference Validation

| Primary Claim | Reference Provided | Authority Level | Verified? | Correctly Applied? |
|--------------|-------------------|-----------------|-----------|-------------------|
| Floci auth env vars | docs/scraped/environment-variables.md:21,160-162 | 2 (official scraped docs) | ✓ | ✓ |
| `FLOCI_SERVICES_IAM_ENABLED` default `true` | docs/scraped/environment-variables.md:160 | 2 | ✓ | ✓ |
| `general_app_boundary` is `data`-only (no resource) | infra/AGENTS.md (KNOWN BUG) | 8 (project-internal) | ✓ | ✓ — independently confirmed: `infra/live/10-management-iam/main.tf:66` is `data "aws_iam_policy_document"`, no `resource "aws_iam_policy" "general_app_boundary"` exists |
| Provider version mismatch acknowledged | infra/AGENTS.md (reconcile note) | 8 | ✓ | ✓ — confirmed: `_common/versions.tf:17` = `>= 5.95.0, < 7.0.0`; `10-management-iam/providers.tf:7` = `>= 6.56.0` |
| `dev.tfvars` `default_tags` duplicate bug acknowledged | infra/AGENTS.md (KNOWN BUG) | 8 | ✓ | Partial — see D-SW-002 & D-SW-004 |

### Reference Validation Findings

- [✓] All factual claims have at least one citation
- [✓] All citations are from authoritative sources (trust level 1-8)
- [✓] All cited sources were verified to actually support the claim — every file:line reference in the primary was independently re-read and confirmed
- [✓] Implementation follows what the reference recommends (where applicable)
- [✗] Best practices, gotchas, and production-grade guidance were sought — **the primary missed several architectural and correctness issues** (see One-Sided Findings): a region-inconsistency bug that breaks SigV4, a permissions-boundary Deny-statement logic flaw, a backend-config hardcoding, and an invalid-value (`Environment = "development"`) observation. The primary's review was thorough on what it covered but one-sided on auth/Terraform runtime correctness.

---

## Agreements

Findings where the primary's position is correct and I concur after independent verification:

| ID | Finding | Agreement | Notes |
|----|---------|-----------|-------|
| F-SW-001 | `FLOCI_AUTH_MODE` design sound; `FLOCI_SERVICES_IAM_ENABLED` interaction undocumented | AGREE | Verified: `authentication-plan.md:131-148` case statement sets the three auth vars but never sets `FLOCI_SERVICES_IAM_ENABLED`. `environment-variables.md:160` confirms IAM service default `true`, so the *immediate* risk is latent, but the interaction must be documented. The recommendation to set it explicitly in the `sigv4` branch is correct and defense-in-depth. Confidence 85 is appropriate. |
| F-SW-002 | Auth plan not yet implemented in `setup-floci.sh` | AGREE | Verified: `grep FLOCI_AUTH_MODE setup-floci.sh` returns only line 946 (the hardcoded risk message). No `FLOCI_AUTH_MODE`, `FLOCI_AUTH_VALIDATE_SIGNATURES`, or `FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED` references in the config block (lines 58-66). The design→implementation gap is real. Confidence 90 is appropriate. |
| F-SW-003 | `general_app_boundary` is `data`, not `resource` — `platform_admin` references fail | AGREE | Verified independently: `main.tf:66` is `data "aws_iam_policy_document" "general_app_boundary"`; `main.tf:28` and `main.tf:60` reference `aws_iam_policy.general_app_boundary.arn` which has no resource definition. This is a hard `terraform plan` failure. The CRITICAL/95 severity is correct. **However, the primary's recommendation (add the resource) has a subtle ordering flaw — see D-SW-003.** |
| F-SW-004 | Provider version mismatch between `_common/versions.tf` and `10-management-iam/providers.tf` | AGREE | Verified: `_common/versions.tf:17` = `>= 5.95.0, < 7.0.0`; `10-management-iam/providers.tf:7` = `>= 6.56.0` (no upper bound, no `versions.tf` in the stage). `infra/AGENTS.md` confirms the reconciliation requirement. The conflict is real for any stage that copies both. Confidence 90 is appropriate. |
| F-SW-006 | `secret_key` required, no default, undocumented | AGREE | Verified: `variables.tf:8-11` declares `secret_key` with `sensitive = true`, no default. `dev.tfvars` has no `secret_key`. `infra/README.md` apply instructions (lines 48-50) do not mention it. Interactive prompt / CI failure is real. Confidence 80 is appropriate. The name-mapping documentation gap (`secret_key` ↔ `FLOCI_BOOTSTRAP_SECRET`/`DEV_BOOTSTRAP_SECRET`) is a valid observation. |
| F-SW-007 | `setup-floci.sh` design patterns are architecturally sound | AGREE | Verified across `setup-floci.sh`: idempotency guards (e.g. `getent` before `useradd`), atomic writes (`write_env_file:822-841` uses `.tmp` + `chmod` + `mv -f`), privilege separation (`run_as_floci`), `${VAR:-default}` config injection (lines 58-66), sourceable guard (line 1018), path validation (line 116). The positive finding is well-evidenced. |
| F-SW-008 | `platform-admin` is a policy without a principal | AGREE | Verified: `main.tf:94` creates `aws_iam_policy.platform_admin` but no `aws_iam_user`/`aws_iam_role`/`aws_iam_group` resource exists. `infra/AGENTS.md` confirms "no users/roles/groups." The auth plan §3.1 speaks of `platform-admin` as a concrete identity. The design↔code gap is real. Confidence 85 is appropriate. |
| F-SW-010 | Credential rotation TOCTOU race (create-then-delete) | AGREE | Verified: `authentication-plan.md:336-353` — `create-access-key` (line 336) then `delete-access-key` (line 350) with no atomicity. The primary correctly classifies this as credential-sprawl (same principal) not privilege-escalation. The accepted-risk + `dev-reset` recovery rationale is sound. Confidence 75 (advisory) is appropriate. |
| F-SW-011 | `print_summary` hardcoded auth message will be stale | AGREE | Verified: `setup-floci.sh:946-949` unconditionally prints the `auth_mode=off` risk message. Auth plan §6.3 specifies the conditional replacement. The gap is real and the recommendation (include in Phase B ticket) is correct. Confidence 80 is appropriate. |
| F-SW-012 | "enforced vs. modeled" table is a strong architectural pattern | AGREE | Verified: `landing-zone-design.md:28-42` — the table cleanly separates enforced (IAM, k3s, PostgreSQL) from modeled (VPC/SG/TGW) controls. The "author intent in Terraform, layer enforced equivalent alongside" rule (line 39-42) is a principled promotion path. The positive finding is well-evidenced. |

---

## Disagreements

### D-SW-001: F-SW-009 — `readonly` inside `case` is a genuine testability bug, not merely "unconventional"; severity understated

| Field | Value |
|-------|-------|
| Primary Finding | F-SW-009 |
| Confidence | 88 |
| Primary Position | `readonly` inside a `case` branch is "unconventional" and "may cause test friction"; severity MODERATE (70). Recommends moving vars to the top-level config block with `${VAR:-default}`. |
| Challenger Position | The primary **under-diagnoses** the problem. The issue is not stylistic — it is a concrete testability *bug* given the project's own conventions. `setup-floci.sh` uses `readonly VAR="${VAR:-default}"` at the top level (lines 59-60) **specifically so bats can `export VAR=override` before sourcing** (AGENTS.md: "so tests can inject overrides by exporting before sourcing"). The auth plan's pattern (`authentication-plan.md:132-148`) does `readonly FLOCI_AUTH_MODE="${FLOCI_AUTH_MODE:-off}"` then `readonly FLOCI_AUTH_VALIDATE_SIGNATURES="false"` *inside* the `case`. In bats, sourcing the script runs the `case` once; a second test in the same file that sets `FLOCI_AUTH_MODE=sigv4` and re-sources will hit `bash: FLOCI_AUTH_MODE: readonly variable` and abort the whole file — the `${VAR:-default}` override mechanism is **broken** for the three auth vars because the `readonly` is hit on the *first* source. The project's own test plan (auth plan §6.11) explicitly requires "Add test: `FLOCI_AUTH_MODE=sigv4` → all three vars `true`" and "invalid → exits 1", which **cannot both run in one bats file** under the proposed pattern without `unset` + subshells. The primary's MODERATE/70 understates this — it should be HIGH/80+ because it blocks the auth plan's own stated test requirements. |
| Recommendation | Adopt the primary's first alternative verbatim: compute values into *non-readonly* locals inside the `case`, then declare the three `readonly` vars at the top level referencing those locals — OR use a subshell/function scope so bats can isolate. More importantly, the auth plan §4.2 code block must be **rewritten** before implementation, not deferred, because the §6.11 test design depends on the fix. |

---

### D-SW-002: F-SW-005 — the "duplicate-key conflict" mechanism is mis-stated; `merge()` does NOT error on duplicate keys, it silently overrides

| Field | Value |
|-------|-------|
| Primary Finding | F-SW-005 |
| Confidence | 82 |
| Primary Position | "Terraform will error on `terraform plan` with 'Duplicate key' for `Project`, `Environment`, and `ManagedBy`." Recommends removing the trio from tfvars and fixing the `merge()`. |
| Challenger Position | The *symptom* is wrong. Terraform's `merge()` function does **not** error on duplicate map keys — later maps in the argument list silently overwrite earlier ones ([HashiCorp Terraform `merge` docs](https://developer.hashicorp.com/terraform/language/functions/merge): "If more than one given map … is defined with the same key, the value from the last map is used."). `merge({Project="tianlu", Environment=var.environment, ManagedBy="terraform"}, var.default_tags)` with `var.default_tags` containing `Project/Environment/ManagedBy` will **silently** let the tfvars values win. The actual bug is *worse than stated*: it is a **silent value override**, not a loud plan error. `Environment = "development"` (dev.tfvars:27) would silently override `Environment = "dev"` (the `var.environment` value) — and "development" ≠ "dev", breaking any ABAC tag-match query that keys on `Environment == var.environment`. The primary correctly identified the *existence* of the bug (confirmed by infra/AGENTS.md KNOWN BUG note) and the *fix* (remove trio from tfvars), but the *failure mode* is silent, which is a more dangerous class of defect. The primary's claim "Terraform will error … with 'Duplicate key'" is an **incorrectly-applied reference** — no authoritative source supports it, and the official `merge` docs contradict it. |
| Recommendation | Keep the primary's fix (remove `Project`/`Environment`/`ManagedBy` from `dev.tfvars`), but **correct the rationale** in the finding: the failure mode is *silent tag drift* breaking ABAC tag-match queries, not a plan-time error. The auth plan / landing-zone ABAC queries (`landing-zone-design.md` §5) rely on `Environment` tag consistency; a silent `development`/`dev` mismatch would make the lesson silently false. This is HIGH, not just HIGH-for-duplicate — the silent nature raises the severity. |

---

### D-SW-003: F-SW-003 recommendation has a circular-dependency ordering flaw the primary itself noted then ignored

| Field | Value |
|-------|-------|
| Primary Finding | F-SW-003 |
| Confidence | 80 |
| Primary Position | "Add `resource "aws_iam_policy" "general_app_boundary" { … policy = data.aws_iam_policy_document.general_app_boundary.json }` before the `platform_admin` policy document." Then notes "This is a circular dependency even if fixed" but does not resolve it. |
| Challenger Position | The primary **identifies the circular dependency and then drops it**. The dependency is real but *not circular* — it is a linear ordering constraint, and the primary's own recommendation already resolves it but fails to say so clearly. `data.aws_iam_policy_document.general_app_boundary` (pure computation, no AWS call) → `resource aws_iam_policy.general_app_boundary` (creates the policy, produces `.arn`) → `data.aws_iam_policy_document.platform_admin` (can now interpolate `aws_iam_policy.general_app_boundary.arn`) → `resource aws_iam_policy.platform_admin`. There is **no cycle**: the `platform_admin` *data source* references the `general_app_boundary` *resource*; the `general_app_boundary` data source does not reference `platform_admin`. The primary's phrase "circular dependency even if fixed" is **incorrect** — it conflates "reference ordering" with "circular dependency" and unnecessarily muddies a clean fix. The fix is correct; the "circular" framing is wrong and could mislead the implementer into thinking Terraform's graph resolver will choke (it won't — Terraform handles this DAG trivially). |
| Recommendation | Keep the primary's resource-addition fix. **Strike the "circular dependency" sentence** — it is a linear DAG: `general_app_boundary data → general_app_boundary resource → platform_admin data → platform_admin resource`. The implementer should place the `general_app_boundary` resource block immediately after its data source (after `main.tf:92`) and before the `platform_admin` data source (`main.tf:5`). No `depends_on` needed. |

---

### D-SW-004: F-SW-005 second paragraph — the `merge({}, var.default_tags)` observation is correct but the primary understates the template-deviation severity

| Field | Value |
|-------|-------|
| Primary Finding | F-SW-005 (second paragraph) |
| Confidence | 78 |
| Primary Position | "`providers.tf` merge at line 33 is `merge({}, var.default_tags)` — the empty first argument means the merge is effectively just `var.default_tags`. The canonical trio … is not being injected. Deviates from the `_common/` template." |
| Challenger Position | The primary correctly identifies the deviation (`10-management-iam/providers.tf:33-34` = `merge({}, var.default_tags)` vs `_common/providers.tf:46-50` = `merge({Project…, Environment…, ManagedBy…}, var.default_tags)`), but treats it as a secondary note inside F-SW-005. This is actually a **distinct, standalone architectural violation** of the `infra/AGENTS.md` convention (line 30: the `merge({Project…, Environment…, ManagedBy…}, var.default_tags)` pattern is *mandated*). The stage silently dropped the canonical trio injection — which means even if the tfvars duplicate is fixed, this stage will **still** produce untagged resources (only `Owner` would survive). This deserves its own finding, not a sub-clause. Burying it inside F-SW-005 risks the fix being partial (tfvars fixed, `merge({}` not fixed → resources tagged only with `Owner`). |
| Recommendation | Split this into a separate finding (the `merge({}, …)` template deviation) so the Phase B ticket tracks both fixes independently: (1) remove trio from `dev.tfvars`, (2) restore the canonical trio in `10-management-iam/providers.tf:33` to match `_common/providers.tf:46-50`. Both must land or resources are mistagged. |

---

## One-Sided Findings (Primary Missed)

### M-SW-001: Region inconsistency between auth plan (`eu-west-1`) and Terraform/dev.tfvars (`eu-west-2`) breaks SigV4 verification

| Field | Value |
|-------|-------|
| Confidence | 90 |
| Description | The auth plan's `_rotate_bootstrap_credentials` (`authentication-plan.md:338,352`) and `dev_env` (lines 394, 413, 415) hardcode `--region eu-west-1` and `AWS_DEFAULT_REGION=eu-west-1`. But `dev.tfvars:13` sets `region = "eu-west-2"`, `_common/providers.tf:18` defaults to `eu-west-2`, and `setup-floci.sh`'s `FLOCI_DEFAULT_REGION` flows into the Floci env file. AWS SigV4 **signs the region into the signature** ([AWS SigV4 docs](https://docs.aws.amazon.com/general/latest/gr/sigv4-create-canonical-request.html): the `CredentialScope` includes the region). When `FLOCI_AUTH_MODE=sigv4`, a `podman exec aws --region eu-west-1` call signs for `eu-west-1`, but if Floci's IAM region context is `eu-west-2` (from the installer env file / Terraform), the signature's region scope will **not match** and SigV4 verification fails with `InvalidSignatureException` / region mismatch. The entire §6.5 rotation flow would fail at the very first `create-access-key` call in sigv4 mode — which is the *primary new capability* the auth plan introduces. The primary's F-SW-001, F-SW-009, F-SW-010 all review the auth plan's structure but none caught that the region literal is wrong. This is a **runtime-correctness blocker** for the auth plan's central feature. |
| Recommended Action | Replace all `eu-west-1` literals in `authentication-plan.md` §6.5/§6.6/§6.7 with a single `DEV_REGION` constant (default `eu-west-2`) sourced from the same place as `dev.tfvars:region`, and ensure `setup-floci.sh`'s `FLOCI_DEFAULT_REGION` and the rotation's `--region` agree. Add a test asserting the rotation's region equals `FLOCI_DEFAULT_REGION`. Flag this as a design-blocker for the auth plan before Phase B implementation. |

---

### M-SW-002: `platform_admin` Deny statement (main.tf:49-63) protects only the boundary policy ARN, not the actions it claims to deny — logic flaw

| Field | Value |
|-------|-------|
| Confidence | 82 |
| Description | `main.tf:49-63` `DenyAllExceptBoundary` statement denies `iam:DeleteRolePermissionsBoundary`, `iam:DeleteUserPermissionsBoundary`, `iam:DeleteGroupPermissionsBoundary`, `iam:DeletePolicy`, `iam:DeletePolicyVersion` — but the `resources` block (line 59-61) lists **only** `aws_iam_policy.general_app_boundary.arn`. IAM permission statement `resources` for these actions is the **resource being acted on**, not the boundary. `iam:DeleteRolePermissionsBoundary` acts on a *role* ARN, `iam:DeleteUserPermissionsBoundary` acts on a *user* ARN, `iam:DeletePolicy` acts on the *policy being deleted*. By scoping the Deny `resources` to the boundary policy ARN only, this statement: (a) does NOT prevent deletion of *other* policies (any policy can be deleted because the Deny resource doesn't match them), and (b) does NOT prevent removal of a permissions boundary from a user/role (the boundary-removal actions act on user/role ARNs, never on the boundary policy ARN, so the Deny never matches). The statement is effectively a no-op for its stated purpose. The correct IAM pattern (per [AWS IAM permissions-boundary docs](https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies_boundaries.html#access_policies_boundaries-delegated-admin)) is either `resources = ["*"]` with the Deny, or a condition-based Deny on `iam:PermissionsBoundary`. The primary's F-SW-003 found the `data`-vs-`resource` bug but missed that the Deny statement's resource scoping is semantically wrong even after the ARN is fixed. |
| Recommended Action | Rewrite the `DenyAllExceptBoundary` statement's `resources` to `["*"]` (Deny statements on `iam:` actions typically need `*` because the acted-on resource varies), OR restructure as a `StringNotEquals` condition on `iam:PermissionsBoundary` matching the boundary ARN. Add a unit test (or `terraform plan` + manual policy simulation via `aws iam simulate-principal-policy`) asserting a platform-admin **cannot** delete an arbitrary policy and **cannot** strip a boundary from a user. Flag as HIGH — the delegated-administration guardrail is currently non-functional. |

---

### M-SW-003: `10-management-iam/providers.tf` hardcodes S3 backend `bucket = "tf-state-dev"` — breaks environment promotion and contradicts the `_common` convention

| Field | Value |
|-------|-------|
| Confidence | 85 |
| Description | `10-management-iam/providers.tf:12` hardcodes `bucket = "tf-state-dev"`. But `infra/AGENTS.md` (line 22) and `00-backend-bootstrap/main.tf:97` establish the bucket name as `tf-state-${var.environment}` (i.e., `tf-state-dev` for dev, `tf-state-uat` for uat). `infra/AGENTS.md` (line 22) states the backend wiring pattern is `terraform init -backend-config=../../_common/backend.hcl -backend-config="key=dev/<NN-stage>/terraform.tfstate"` — i.e., the bucket should come from `_common/backend.hcl`, not be hardcoded in `providers.tf`. The hardcoded `tf-state-dev` means: (a) promoting to `uat`/`prod` requires editing `providers.tf` (violating the "stage code unchanged" promotion rule, `infra/AGENTS.md` line 23), and (b) it diverges from the documented backend-config-on-init pattern. The primary's F-SW-004 reviewed provider *version* mismatch but did not review backend *config* correctness. |
| Recommended Action | Remove the inline `backend "s3" { … }` block from `10-management-iam/providers.tf` and use the documented `terraform init -backend-config=../../_common/backend.hcl -backend-config="key=dev/10-management-iam/terraform.tfstate"` pattern (matching `infra/README.md:48-49`). Update `infra/README.md` apply instructions to include the `-backend-config` for the `10-management-iam` stage. Flag as HIGH — environment promotion is a stated design goal (`landing-zone-design.md` §environment=account) and this hardcoding silently breaks it. |

---

### M-SW-004: `dev.tfvars` `Environment = "development"` is an invalid value distinct from the duplicate-key issue — it would break ABAC even if deduplication worked

| Field | Value |
|-------|-------|
| Confidence | 80 |
| Description | Even setting aside D-SW-002 (the `merge` silent-override), `dev.tfvars:27` sets `Environment = "development"` while `environment = "dev"` (line 10) and `infra/AGENTS.md` (line 40) explicitly says "Do NOT set `Environment = "dev"` directly" and that the value must come from `var.environment`. The value `"development"` is not any of `dev`/`uat`/`prod` — it is a fourth, undocumented environment label. Any ABAC tag-match condition (`aws:ResourceTag/Environment` == `aws:PrincipalTag/Environment`) would fail because principals are tagged `Environment=dev` (from the `merge` using `var.environment="dev"`) while resources get `development` (from the tfvars override). The primary's F-SW-005 flagged the duplicate but framed it as a generic duplicate-key issue and missed that the *specific value* `development` is itself invalid independently of deduplication. The `infra/AGENTS.md` KNOWN BUG note correctly says "remove `Environment`" but the primary did not call out the value-level invalidity. |
| Recommended Action | In addition to removing the trio from `dev.tfvars` (D-SW-002), add a `terraform validate`-time guard or a `validation` block on a `default_tags`-derived local asserting `Environment ∈ {dev,uat,prod}`. Document in `infra/README.md` that `Environment` is injected by `providers.tf` from `var.environment` and must never appear in tfvars. Flag as HIGH — silent ABAC breakage. |

---

### M-SW-005: Auth plan §6.5 rotation does not verify the new key works before deleting the old one — delete-before-verify ordering risk

| Field | Value |
|-------|-------|
| Confidence | 72 |
| Description | `authentication-plan.md:336-353`: `create-access-key` succeeds → parse `new_akid`/`new_sk` → immediately `delete-access-key` (line 350) on the old key. There is **no verification step** between create and delete — the script never confirms the new credentials actually authenticate (e.g. a `sts get-caller-identity` or `iam list-access-keys` call using `new_akid`/`new_sk`) before irrevocably deleting the old key. If `create-access-key` returns a malformed/partial response that passes the `grep`/`sed` parse but is not actually usable (e.g. Floci returns the JSON but the key is in a not-yet-active state, or the secret has trailing characters stripped by the regex), the script deletes the only working credential and persists a broken one — locking the dev twin out of `floci-deployer` with no recovery short of `dev-reset` (which wipes Floci state). The primary's F-SW-010 covered the create-then-delete TOCTOU *race* but framed it as accepted risk; it did not flag the stronger defect: **delete happens with zero confirmation the new key is usable**. The blast radius is "total lockout" not "credential sprawl." |
| Recommended Action | Insert a verification call between create and delete: `podman exec -e AWS_ACCESS_KEY_ID=$new_akid -e AWS_SECRET_ACCESS_KEY=$new_sk tianlu-floci aws sts get-caller-identity` (or `iam list-access-keys --user-name floci-deployer`). Only proceed to `delete-access-key` if verification returns the deployer principal. If verification fails, keep the old key, emit a WARNING, and do not persist the broken new creds. This converts a lockout risk into a no-op. Flag as MODERATE-HIGH (advisory for dev twin, but the pattern would be dangerous if copied to a real-AWS promotion). |

---

## Recommendations

1. **Rewrite auth plan §4.2 code block before implementation (D-SW-001).** The `readonly`-inside-`case` pattern breaks the project's own `${VAR:-default}` test-injection convention and makes the §6.11 test plan unimplementable in a single bats file. This is a design-doc fix, not just an implementation detail — it should not wait for Phase B.

2. **Fix the region inconsistency (M-SW-001) in the auth plan now.** `eu-west-1` vs `eu-west-2` is a SigV4-region-mismatch blocker for the rotation flow — the auth plan's headline feature. This is the highest-impact missed finding.

3. **Correct F-SW-005's failure-mode rationale (D-SW-002) and split out the `merge({})` deviation (D-SW-004).** The "Duplicate key error" claim is contradicted by the official `merge` docs; the real failure mode is silent ABAC tag drift. Two independent fixes (tfvars trio removal + `providers.tf` merge restoration) must be tracked separately or one will be missed.

4. **Re-author the `DenyAllExceptBoundary` statement (M-SW-002).** The current `resources = [boundary.arn]` makes the Deny a no-op for boundary-removal actions. This is a non-functional guardrail masquerading as a security control — the most dangerous class of defect for an educational IAM-delegation demo.

5. **Strike the "circular dependency" framing in F-SW-003 (D-SW-003).** It is a linear DAG; the "circular" label could mislead the implementer. The fix is correct as stated.

6. **Add delete-before-verify gap (M-SW-005) to the auth plan §6.5 as an explicit design step.** One `sts get-caller-identity` call converts a lockout risk into a safe no-op.

7. **Backend-config hardcoding (M-SW-003) should be fixed alongside F-SW-004** since both are in `10-management-iam/providers.tf`. A single Phase B ticket covering provider-version + backend-config + merge-trio restoration avoids three separate touches to the same file.

### Confidence Summary

| Finding | Confidence | Type |
|---------|-----------|------|
| D-SW-001 | 88 | Disagreement — severity understated |
| D-SW-002 | 82 | Disagreement — failure mode mis-stated (contradicts official docs) |
| D-SW-003 | 80 | Disagreement — "circular" framing incorrect |
| D-SW-004 | 78 | Disagreement — distinct violation buried in a sub-clause |
| M-SW-001 | 90 | Missed — runtime blocker for auth plan's central feature |
| M-SW-002 | 82 | Missed — non-functional guardrail |
| M-SW-003 | 85 | Missed — environment-promotion breakage |
| M-SW-004 | 80 | Missed — invalid value independent of dedup |
| M-SW-005 | 72 | Missed — lockout-risk ordering |

### Blocking findings (confidence ≥80): D-SW-001, D-SW-002, D-SW-003, M-SW-001, M-SW-002, M-SW-003, M-SW-004
### Advisory findings (confidence <80): D-SW-004, M-SW-005

---

## Verdict on the Primary Review

The primary A1-SW review is **architecturally sound and well-evidenced on what it covers** — F-SW-003, F-SW-004, F-SW-007, F-SW-012 are accurate and well-referenced. However, it has **two correctness errors** (D-SW-002 contradicts the official `merge` docs; D-SW-003 mislabels a DAG as circular), **one severity understatement** (D-SW-001), and **missed five findings**, two of which are runtime blockers (M-SW-001 region mismatch breaks the rotation; M-SW-002 makes the Deny guardrail a no-op) and one of which (M-SW-003) breaks the stated environment-promotion design goal.

**Challenger verdict: CONDITIONAL PASS with required rework.** The primary's CONDITIONAL PASS stands, but the blocking list should expand to include M-SW-001 (region) and M-SW-002 (Deny logic) — both are design-level defects in the artifacts under review, not implementation details. F-SW-005's rationale must be corrected before it misleads the Phase B implementer. D-SW-001's severity must be raised so the auth plan §4.2 code block is rewritten before implementation, not during it.

