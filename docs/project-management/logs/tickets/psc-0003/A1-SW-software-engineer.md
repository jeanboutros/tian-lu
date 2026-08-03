# A1-SW: Software Engineer Requirements — psc-0003

| Field | Value |
|-------|-------|
| Agent | software-engineer |
| Timestamp | 2026-07-30T23:00:00Z |
| Step | A1-SW |
| Phase | A |
| Ticket | psc-0003 |
| Source advisory | psc-adv-0017-challenge-review |
| Verdict | CONDITIONAL PASS |

## Self-Audit Checklist

| Category | Checked? | Finding or PASS |
|----------|----------|-----------------|
| Build passes (exit 0, no warnings) | N/A — Phase A, no code written | N/A |
| Typed enums / vocabulary types (no raw integers in API) | N/A — bash/Terraform, not C++ | N/A |
| Documentation on new public symbols | N/A — Phase A requirements analysis | N/A |
| Spec/datasheet fidelity (fields match spec) | yes | All findings cross-referenced against advisory source lines, AWS IAM docs, Terraform source, Floci scraped docs |
| Module boundary (no platform headers in shared modules) | N/A — bash/Terraform | N/A |
| Reserved/padding fields handled | N/A | N/A |
| No magic numbers in doc examples | N/A | N/A |
| Buffer safety (bounded copies) | N/A | N/A |
| AGENTS.md compliance | yes | PASS — all findings mapped to acceptance criteria; dependencies on other specialists declared; no application code written |
| Conventional commit ready | N/A — Phase A | N/A |

## Reference Validation

| Primary Claim | Reference Provided | Authority Level | Verified? | Correctly Applied? |
|--------------|-------------------|-----------------|-----------|-------------------|
| CH-AUTH-001: 12-digit AKID account selection | `docs/scraped/multi-account.md:9-10,60` | 2 (official Floci docs) | ✓ | ✓ |
| CH-AUTH-001: SigV4 requires secret resolution | `docs/scraped/multi-account.md:60` | 2 | ✓ | ✓ |
| CH-AUTH-002: ${VAR:-default} allows override | Verified via bash execution in advisory §Verification | 1 (executed) | ✓ | ✓ |
| CH-AUTH-003: IAM_ENABLED vs ENFORCEMENT_ENABLED | `docs/scraped/environment-variables.md:160-161` | 2 | ✓ | ✓ |
| CH-AUTH-004: sed range delete destroys terminating line | Verified via execution in advisory §Verification | 1 (executed) | ✓ | ✓ |
| CH-AUTH-005: errexit kills on bare simple command | bash manual, verified in advisory | 1 (executed) | ✓ | ✓ |
| CH-AUTH-008: IFS=$'\n\t' does not split on spaces | Verified via execution in advisory §Verification | 1 (executed) | ✓ | ✓ |
| CH-AUTH-009: bash 3.2 empty array expansion | Verified via execution in advisory §Verification | 1 (executed) | ✓ | ✓ |
| CH-LZ-001: IAM absent-key evaluation | AWS IAM docs: policy variables with no value | 1 (official AWS docs) | ✓ | ✓ |
| CH-LZ-001: EQUIVALENT_TO_NULL_FALSE | AWS IAM Access Analyzer policy check reference | 1 (official AWS docs) | ✓ | ✓ |
| CH-LZ-001: DeleteGroupPermissionsBoundary not an IAM action | AWS IAM API reference | 1 (official AWS docs) | ✓ | ✓ |
| CH-LZ-005: backend region vs provider region | `backend.hcl.example:12` vs `dev.tfvars:13` | 3 (project files) | ✓ | ✓ |
| CH-LZ-006: force_path_style deprecated | Terraform S3 backend source (Go) | 1 (official source) | ✓ | ✓ |
| CH-LZ-008: governance tags gutted from stage 10 | `10-management-iam/providers.tf:32-36` | 3 (project files) | ✓ | ✓ |
| CH-LZ-009: provider constraint divergence | `10-management-iam/providers.tf:5-8` vs `_common/versions.tf:15-18` | 3 (project files) | ✓ | ✓ |
| CH-LZ-010: backend key missing env prefix | `10-management-iam/providers.tf:11-15` vs landing-zone §9 | 3 (project files) | ✓ | ✓ |
| CH-LZ-011: merge order allows override | `_common/providers.tf:46-50` | 3 (project files) | ✓ | ✓ |
| CH-LZ-012: wrong mechanism in comment | `dev.tfvars:26-29` | 3 (project files) | ✓ | ✓ |
| CH-LZ-013: secret_key has no documented supply path | `_common/providers.tf:12-15` | 3 (project files) | ✓ | ✓ |

### Findings

- [✓] All factual claims have at least one citation
- [✓] All citations are from authoritative sources (trust level 1-3)
- [✓] All cited sources were verified to actually support the claim
- [✓] Implementation follows what the reference recommends
- [✓] Best practices, gotchas, and production-grade guidance were sought

---

## Requirements Analysis

### Scope: SW-relevant findings from psc-adv-0017-challenge-review

The following findings fall within the Software Engineer's domain: architecture, API surface, type design, module boundaries, configuration coherence, and structural integrity. Each finding is analysed for its architectural implications, required changes, acceptance criteria, and dependencies on other specialists.

---

### SPEC-SW-001: CH-AUTH-001 — Per-environment FLOCI_DEFAULT_ACCOUNT_ID

**Current state (what's wrong):**
The authentication plan and landing zone assume that a 12-digit AKID (`111111111111`) selects the dev account. However, under `FLOCI_AUTH_VALIDATE_SIGNATURES=true`, Floci must resolve a secret for the presented AKID to verify the signature. The only credential that can authenticate under `sigv4` is the rotated `floci-deployer` key, whose AKID is non-12-digit (server-generated), so it resolves to `FLOCI_DEFAULT_ACCOUNT_ID` = `000000000000` — not `111111111111`. The account axis is on the AKID, but the AKID that works under auth is not the one that selects the right account. This is a fundamental architectural contradiction.

**Required change:**
1. Move the account axis from the AKID to installer configuration: `FLOCI_DEFAULT_ACCOUNT_ID` becomes the per-environment selector. The dev instance's default account is `111111111111`.
2. Change `_common/providers.tf` so `access_key` is the **deployer's real AKID** (rotated, sourced from `DEV_CREDENTIALS_FILE`), not `var.account_id`. Keep `var.account_id` as the assertion target — add a `data.aws_caller_identity` + `precondition` that fails the plan when the resolved account id does not equal `var.account_id`.
3. Update `preflight-floci.sh` accordingly: the AKID must be the deployer key; `DEV_AKID` becomes the expected account id the gates assert against.
4. Update landing-zone §4.1/§4.2 to state that under `sigv4` the environment is selected by the instance's `FLOCI_DEFAULT_ACCOUNT_ID`, not by the client's AKID. Record the trade-off in the gaps register: the "three accounts on one instance" demonstration is not available with auth on.
5. Run the three-outcome probe to validate the fix.

**Acceptance criteria:**
- `FLOCI_DEFAULT_ACCOUNT_ID` is configurable per environment in the installer invocation
- `_common/providers.tf` `access_key` uses the deployer's real AKID, not `var.account_id`
- A `data.aws_caller_identity` precondition asserts `var.account_id` matches the resolved account
- Landing-zone §4.1/§4.2 updated with the new account-selection mechanism
- Three-outcome probe executed and result recorded in gaps register
- `preflight-floci.sh` G1 uses deployer credentials, not `DEV_AKID` as the access key

**Dependencies:**
- **SX (Security Reviewer):** Validate the caller-identity precondition is correct and the SigV4 probe outcome is properly interpreted
- **DX (Docs Writer):** Update landing-zone §4.1/§4.2 and gaps register
- **BS (Bash Specialist):** Review installer invocation changes for `FLOCI_DEFAULT_ACCOUNT_ID` injection
- **DO (DevOps Specialist):** Review Terraform provider wiring changes

**Confidence:** 90 (Critical — blocks all auth-dependent work)

---

### SPEC-SW-002: CH-AUTH-002 — Rewrite §4.2 with FLOCI_AUTH_UNSAFE_OVERRIDE

**Current state (what's wrong):**
The current §4.2 uses `${VAR:-default}` on each individual auth sub-variable after the `case` statement. This allows an exported `FLOCI_AUTH_VALIDATE_SIGNATURES=true` to override the mode-derived value even when `FLOCI_AUTH_MODE=off`, producing the forbidden `signatures=true, enforcement=false` state. §8.3's claim that "the installer only allows both-on or both-off" is false as specified.

**Required change:**
Derive the posture unconditionally from `FLOCI_AUTH_MODE`. Expose one explicit, named escape hatch (`FLOCI_AUTH_UNSAFE_OVERRIDE=1`) for tests that need an incoherent combination. The fix from the advisory:

```bash
readonly FLOCI_AUTH_MODE="${FLOCI_AUTH_MODE:-sigv4}"
case "$FLOCI_AUTH_MODE" in
  off)   _auth_on="false" ;;
  sigv4) _auth_on="true"  ;;
  *) printf 'ERROR: FLOCI_AUTH_MODE must be "off" or "sigv4" (got: %s)\n' "$FLOCI_AUTH_MODE" >&2
     exit 1 ;;
esac
if [[ "${FLOCI_AUTH_UNSAFE_OVERRIDE:-0}" == "1" ]]; then
  readonly FLOCI_AUTH_VALIDATE_SIGNATURES="${FLOCI_AUTH_VALIDATE_SIGNATURES:-$_auth_on}"
  readonly FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED="${FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED:-$_auth_on}"
else
  readonly FLOCI_AUTH_VALIDATE_SIGNATURES="$_auth_on"
  readonly FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED="$_auth_on"
fi
unset _auth_on
```

**Acceptance criteria:**
- `FLOCI_AUTH_MODE=off` + `FLOCI_AUTH_VALIDATE_SIGNATURES=true` yields `false` in the env file (bats case proves hole closed)
- `FLOCI_AUTH_UNSAFE_OVERRIDE=1` allows individual override for tests
- `_auth_on` (and all `_auth_*` helpers) are `unset` after use — not left in the shell
- §4.2 code block in `authentication-plan.md` updated
- §6.1 code block in `authentication-plan.md` updated (same code, different location)

**Dependencies:**
- **TX (Test Engineer):** Write the bats case proving the hole is closed
- **BS (Bash Specialist):** Review the readonly/unset pattern for correctness under `set -u`

**Confidence:** 95 (Critical — the forbidden state is reachable as specified)

---

### SPEC-SW-003: CH-AUTH-003 — FLOCI_SERVICES_IAM_ENABLED=true in both branches

**Current state (what's wrong):**
The current §4.2 sets `FLOCI_SERVICES_IAM_ENABLED=false` in `off` mode. This variable is the IAM *service* on/off switch (default `true`), not the enforcement switch. Setting it `false` disables IAM entirely — `preflight-floci.sh` G1 cannot create its probe user, and any stage referencing a role ARN fails. The enforcement variable is `FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED`.

**Required change:**
`FLOCI_SERVICES_IAM_ENABLED=true` in both branches, or omit it entirely and let the image default (`true`) stand. Only `FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED` tracks the mode. Correct §6.2's note and SPEC-TX-006 case-3 direction — the assertion should be `=true` in *both* modes, not mode-dependent.

**Acceptance criteria:**
- `FLOCI_SERVICES_IAM_ENABLED` is `true` (or absent, defaulting to `true`) in both `off` and `sigv4` modes
- §6.2 note corrected: no longer claims `IAM_ENABLED` is mode-dependent
- SPEC-TX-006 case-3 corrected: asserts `FLOCI_SERVICES_IAM_ENABLED=true` in both modes
- `preflight-floci.sh` G1 can create its probe user in both modes

**Dependencies:**
- **TX (Test Engineer):** Update SPEC-TX-006 case-3
- **SX (Security Reviewer):** Confirm that IAM service enabled with enforcement off is the correct posture for `off` mode

**Confidence:** 92 (Critical — breaks preflight G1 and all IAM-dependent stages in off mode)

---

### SPEC-SW-004: CH-AUTH-012 — Split §6.10a–d into changelog/appendix

**Current state (what's wrong):**
§6.10a documents the `DenyAllExceptBoundary` statement as a pending change, but it is already landed in `infra/live/10-management-iam/main.tf:49-69`. A section headed "Explicit code changes" that mixes pending specifications with landed history is not safely executable — an implementer cannot tell which blocks to apply. Compounded by the fact that this landed change is defective (CH-LZ-001).

**Required change:**
Split §6.10a–d into two sections:
1. A "Changes already applied" appendix listing the landed changes (with their current state and known defects)
2. A "Pending changes" section listing only the changes that still need implementation

**Acceptance criteria:**
- §6.10a–d no longer mixes pending and landed changes
- Landed changes are in a clearly marked appendix with their current state
- Pending changes are in a clearly marked section with implementation instructions
- No implementer can confuse "already done" with "needs doing"

**Dependencies:**
- **DX (Docs Writer):** Restructure the document sections

**Confidence:** 100 (Process — the document is actively misleading)

---

### SPEC-SW-005: CH-AUTH-013 — Emit FLOCI_AUTH_MODE to env file; surface in dev_status

**Current state (what's wrong):**
`write_env_file` emits the three derived auth variables (`FLOCI_AUTH_VALIDATE_SIGNATURES`, `FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED`, `FLOCI_SERVICES_IAM_SEED_DEPLOYER_PRINCIPAL`) but not `FLOCI_AUTH_MODE` itself. Nothing on the host records which posture it was installed with. `dev_status`, `preflight-floci.sh`, and the §6.7 next-steps block all need that input. §4.4's claim that "the env file retains the value from the original install" is only true of the derived variables.

**Required change:**
Emit `FLOCI_AUTH_MODE` to the env file (as a comment or variable). Have `dev_status` surface it so the operator can see the installed posture.

**Acceptance criteria:**
- `FLOCI_AUTH_MODE` is written to `floci.env` during `write_env_file`
- `dev_status` displays the current auth mode
- §4.4's claim is accurate: the env file retains the mode from the original install

**Dependencies:**
- **BS (Bash Specialist):** Review env file format change
- **DX (Docs Writer):** Update §4.4 if needed

**Confidence:** 95 (High — operator-visible gap)

---

### SPEC-SW-006: CH-LZ-001 — Replace DenyAllExceptBoundary with three-statement form

**Current state (what's wrong):**
The `DenyAllExceptBoundary` statement in `infra/live/10-management-iam/main.tf:49-69` uses `StringNotEquals` on `iam:PermissionsBoundary` with `resources = ["*"]`. Per AWS IAM documentation, inverted condition operators **match** a null value, and `iam:PermissionsBoundary` is absent from the request context for `iam:DeletePolicy`, `iam:DeletePolicyVersion`, `iam:DeleteRolePermissionsBoundary`, and `iam:DeleteUserPermissionsBoundary`. The Deny therefore fires unconditionally on every one of those calls — `terraform destroy` on stage 10 fails, and `terraform apply` fails once a policy reaches the five-version limit.

Additionally, `iam:DeleteGroupPermissionsBoundary` is not a real IAM API action — permissions boundaries apply to users and roles only.

**Required change:**
Replace the single `DenyAllExceptBoundary` statement with three separate statements, each scoped to the actions where the condition key is actually present or absent:

1. **DenyPrincipalCreationWithoutBoundary** — `StringNotEquals` on `iam:PermissionsBoundary` for actions where the key IS present: `iam:CreateRole`, `iam:CreateUser`, `iam:PutRolePermissionsBoundary`, `iam:PutUserPermissionsBoundary`. Resources: `["*"]`.
2. **DenyBoundaryPolicyMutation** — No condition (key is absent). Deny `iam:DeletePolicy`, `iam:DeletePolicyVersion`, `iam:CreatePolicyVersion`, `iam:SetDefaultPolicyVersion` on `resources = [aws_iam_policy.general_app_boundary.arn]`.
3. **DenyBoundaryDetach** — No condition (key is absent). Deny `iam:DeleteRolePermissionsBoundary`, `iam:DeleteUserPermissionsBoundary` on `resources = ["*"]`.

Drop `iam:DeleteGroupPermissionsBoundary` (not a real action).

**Acceptance criteria:**
- `DenyAllExceptBoundary` replaced with three-statement form
- `iam:DeleteGroupPermissionsBoundary` removed
- `terraform destroy` on stage 10 succeeds
- `terraform apply` succeeds when a policy needs version rotation
- G6 negative test added (per CH-LZ-002): mint a role with a boundary denying `s3:*`, attach an identity policy allowing `s3:ListAllMyBuckets`, assume it, and require the call to be **denied**

**Dependencies:**
- **SX (Security Reviewer):** Validate the three-statement form correctly enforces the escalation ceiling; design G6 negative test
- **DO (DevOps Specialist):** Verify `terraform destroy` and `terraform apply` with policy version rotation
- **TX (Test Engineer):** Implement G6 negative test

**Confidence:** 92 (Critical — the current statement is an unconditional deny that breaks terraform operations)

---

### SPEC-SW-007: CH-LZ-005 — Align backend region with tfvars region; unify five region literals

**Current state (what's wrong):**
Five distinct region values are live across the stack:
- `infra/_common/backend.hcl.example:12` — `us-east-1`
- `infra/environments/dev.tfvars:13` — `eu-west-2`
- `setup-floci.sh:54` — `eu-west-1` (FLOCI_DEFAULT_REGION)
- `scripts/preflight-floci.sh:25` — `us-east-1`
- `dev-twin.sh:766` — `eu-west-1`

The state bucket is created by stage 00 under the provider region and read by every other stage under the backend region. A mismatch means resources created in one region are invisible to clients querying another, and ARNs embed the wrong region.

**Required change:**
Single source of truth per environment. `backend.hcl` region must equal the tfvars region. `setup-floci.sh`'s `FLOCI_DEFAULT_REGION` and `preflight-floci.sh`'s `REGION` must match the environment they target. All five sites must use the same region value for a given environment.

**Acceptance criteria:**
- `backend.hcl.example` region matches `dev.tfvars` region (both `eu-west-2`)
- `setup-floci.sh` `FLOCI_DEFAULT_REGION` is `eu-west-2` (or configurable per environment)
- `preflight-floci.sh` `REGION` is `eu-west-2` (or configurable per environment)
- `dev-twin.sh` `DEV_REGION` is `eu-west-2`
- No hardcoded region literals diverge from the environment's region

**Dependencies:**
- **DO (DevOps Specialist):** Verify backend region alignment doesn't break state access
- **BS (Bash Specialist):** Review region changes in shell scripts

**Confidence:** 92 (High — resource visibility and ARN correctness)

---

### SPEC-SW-008: CH-LZ-006 — Reduce §6.10b to -backend-config=../../_common/backend.hcl + per-stage key

**Current state (what's wrong):**
Auth plan §6.10b prescribes a full CLI `-backend-config` invocation with nine flags including deprecated `force_path_style` and `endpoint` (superseded by `use_path_style` and `endpoints` map). The `endpoints` map cannot be expressed via `-backend-config="key=value"` — which is why the repo already has `backend.hcl.example` using the modern form. Landing-zone §10.2 already documents the correct pattern.

**Required change:**
Reduce §6.10b to the two per-stage overrides and parameterise the rest inside `backend.hcl`:

```bash
terraform init \
  -backend-config=../../_common/backend.hcl \
  -backend-config="key=dev/10-management-iam/terraform.tfstate"
```

**Acceptance criteria:**
- §6.10b prescribes the two-flag form, not the nine-flag form
- `backend.hcl.example` carries all static backend config
- The `-backend-config` invocation matches landing-zone §10.2

**Dependencies:**
- **DO (DevOps Specialist):** Verify the two-flag form works for all stages
- **DX (Docs Writer):** Update §6.10b

**Confidence:** 95 (High — the current form is inoperable for `endpoints`)

---

### SPEC-SW-009: CH-LZ-008 — Restore governance tags in _common/providers.tf; Owner is general tag

**Current state (what's wrong):**
The governance tag trio (`Project`, `Environment`, `ManagedBy`) was removed from `infra/live/10-management-iam/providers.tf` (the stage provider) during the psc-adv-0002 remediation, not just from `dev.tfvars`. The stage's `default_tags` block now reads `merge({}, var.default_tags)` — an empty merge. Stage 10 tags every resource with `Owner` only. No `Environment` tag exists, so landing-zone §5.3's ABAC model has nothing to match on. The template (`_common/providers.tf`) still carries the trio, so template and stage have diverged — the exact failure mode §3.1 exists to prevent.

Additionally, the stage's `endpoints` block drops `sns` and `sqs` relative to the template.

**Required change:**
1. Restore the governance trio in `_common/providers.tf` template (already present — verify it's correct)
2. Restore the governance trio in `10-management-iam/providers.tf` (or symlink to the template)
3. `Owner` is a general tag — `dev.tfvars` carries only `Owner`; the trio is injected by the provider
4. Add a lint check that every `infra/live/*/providers.tf` matches `_common/providers.tf`
5. Restore `sns` and `sqs` in the stage's `endpoints` block

**Acceptance criteria:**
- `_common/providers.tf` `default_tags` merge includes `Project`, `Environment`, `ManagedBy`
- `10-management-iam/providers.tf` `default_tags` merge includes the same trio
- `dev.tfvars` `default_tags` contains only `Owner` (no `Project`/`Environment`/`ManagedBy`)
- Lint check exists that verifies stage providers match the template
- `sns` and `sqs` endpoints present in stage provider

**Dependencies:**
- **DO (DevOps Specialist):** Implement the lint check; verify template-stage consistency
- **DX (Docs Writer):** Update landing-zone §3.1 if the symlink approach is adopted

**Confidence:** 98 (Critical — governance tags are silently absent from the only applied stage)

---

### SPEC-SW-010: CH-LZ-009 — Unify provider constraints to >= 6.56.0 with upper bound

**Current state (what's wrong):**
Three different AWS provider version constraints across the codebase:
- `infra/live/10-management-iam/providers.tf:5-8` — `>= 6.56.0` (no upper bound)
- `infra/_common/versions.tf:15-18` — `>= 5.95.0, < 7.0.0`
- `infra/live/00-backend-bootstrap/main.tf:16-19` — `>= 5.95.0, < 7.0.0`

The stage-10 constraint has no upper bound — a future 7.x major would be selected automatically. The `versions.tf:13-14` note about EKS v21 requiring `>= 6.0` was resolved in the stage but never propagated back to the template. This contradicts §3.1's "keep pins identical across stages."

**Required change:**
1. Decide the floor: `>= 6.56.0` (matching the stage-10 constraint, which was presumably chosen for EKS v21 compatibility)
2. Add an upper bound: `< 7.0.0` (matching the template)
3. Apply `>= 6.56.0, < 7.0.0` in `_common/versions.tf`
4. Propagate to all stages
5. Delete the `versions.tf:13-14` note (resolved)
6. Record the decision in landing-zone §7

**Acceptance criteria:**
- All stages use `aws >= 6.56.0, < 7.0.0`
- `_common/versions.tf` is the canonical source
- No stage has a different constraint
- The `versions.tf:13-14` note is removed
- Landing-zone §7 records the version decision

**Dependencies:**
- **DO (DevOps Specialist):** Verify EKS v21 compatibility with `>= 6.56.0`; propagate to all stages

**Confidence:** 95 (High — unbounded constraint is a supply-chain risk)

---

### SPEC-SW-011: CH-LZ-010 — Omit key from providers.tf to force -backend-config override

**Current state (what's wrong):**
`infra/live/10-management-iam/providers.tf:14` hardcodes `key = "10-management-iam/terraform.tfstate"` — no `<env>/` prefix. Landing-zone §9 specifies `<env>/<stage>/terraform.tfstate`. An `init` without the `-backend-config="key=…"` override silently writes state to an unprefixed key. Promotion to uat/prod then collides on the same object.

**Required change:**
Omit `key` entirely from `providers.tf` — consistent with how `bucket` and `region` are handled (passed via `-backend-config`). A missing required value fails loudly; a wrong default fails silently.

**Acceptance criteria:**
- `10-management-iam/providers.tf` does not contain a `key` in the `backend "s3"` block
- `terraform init` without `-backend-config="key=…"` fails with a clear error
- The `-backend-config` invocation in §6.10b (per SPEC-SW-008) supplies the key

**Dependencies:**
- **DO (DevOps Specialist):** Verify init fails cleanly without the key override

**Confidence:** 95 (High — silent state collision on promotion)

---

### SPEC-SW-012: CH-LZ-011 — Reverse default_tags merge order; add environment validation

**Current state (what's wrong):**
`_common/providers.tf:46-50` uses `merge({Project, Environment = var.environment, ManagedBy}, var.default_tags)` — `var.default_tags` is **second**, so it wins. This is how `Environment = "development"` overrode `var.environment = "dev"` silently, with no plan warning. Removing the duplicates from `dev.tfvars` fixes today's symptom but leaves the hazard armed for any future tfvars file.

**Required change:**
Reverse the merge order so governance tags cannot be overridden, and add environment validation:

```hcl
default_tags {
  tags = merge(var.default_tags, {
    Project     = "tianlu"
    Environment = var.environment
    ManagedBy   = "terraform"
  })
}

variable "environment" {
  type = string
  validation {
    condition     = contains(["dev", "uat", "prod"], var.environment)
    error_message = "environment must be one of dev, uat, prod (see landing-zone-design.md §4.1)."
  }
}
```

**Acceptance criteria:**
- `var.default_tags` is merged FIRST, so the governance trio always wins
- `var.environment` has a validation block restricting to `dev`, `uat`, `prod`
- A tfvars file setting `Environment = "development"` in `default_tags` cannot override the provider-injected value
- The merge order is documented in a comment explaining why

**Dependencies:**
- **DO (DevOps Specialist):** Verify the merge order change doesn't break existing applies
- **SX (Security Reviewer):** Confirm the ABAC tag-match conditions in §5.3 are protected

**Confidence:** 95 (High — silent tag override is a security boundary bypass)

---

### SPEC-SW-013: CH-LZ-012 — Correct mechanism in dev.tfvars comment and §6.10c

**Current state (what's wrong):**
`dev.tfvars:26-29` states that duplicating `Project`/`Environment`/`ManagedBy` in `default_tags` *"causes terraform plan warnings (duplicate key)"*. It does not — `merge` silently lets the later map win (per CH-LZ-011). The wrong mechanism is committed as a code comment, where it will teach the next maintainer that the failure is loud when it is silent. The same error appears in auth plan §6.10c:731.

**Required change:**
Correct both the `dev.tfvars` comment and auth plan §6.10c to state the real mechanism: `merge` precedence, silent override, no diagnostic.

**Acceptance criteria:**
- `dev.tfvars` comment states the real mechanism (merge precedence, silent override)
- Auth plan §6.10c states the real mechanism
- Neither comment claims "terraform plan warnings" for duplicate keys in a merge

**Dependencies:**
- **DX (Docs Writer):** Update both comments

**Confidence:** 95 (High — wrong mechanism in a code comment is a teaching hazard)

---

### SPEC-SW-014: CH-LZ-013 — Remove root install.sh; add TF_VAR_secret_key story to §10.1

**Current state (what's wrong):**
1. `install.sh` in the repo root is an "OpenAgents Control Installer" for opencode — 52 KB, untracked, unrelated to this project, sitting beside `setup-floci.sh`. It pollutes the repo root.
2. `_common/providers.tf:12-15` declares `secret_key` as `sensitive` with no default. `dev.tfvars` does not set it, and landing-zone §10.2's commands do not pass it. Terraform prompts interactively; any non-TTY run hangs. This is also the seam where rotation lands, so it needs an explicit story: `TF_VAR_secret_key` sourced from `DEV_CREDENTIALS_FILE`, documented in §10.1 next to the preflight step.
3. §3 lists `modules/workload-spoke/` and stages 20–60 as present-tense scaffolding; only `00` and `10` exist. Same class as psc-adv-0002 M-DX-002.
4. §12 lists IAM as the primary boundary without noting that `FLOCI_AUTH_PRESIGN_SECRET` mints presigned S3 URLs that skip it — material because the Terraform state bucket is S3 (§9). Cross-link to CH-AUTH-014.

**Required change:**
1. Remove `install.sh` from the repo root
2. Add `TF_VAR_secret_key` sourcing story to landing-zone §10.1: source from `DEV_CREDENTIALS_FILE` after rotation
3. Qualify §3's unbuilt scaffolding as future/planned
4. Cross-link presign secret to CH-AUTH-014 in §12

**Acceptance criteria:**
- `install.sh` is removed from the repository
- Landing-zone §10.1 documents how `TF_VAR_secret_key` is supplied (from `DEV_CREDENTIALS_FILE`)
- §3 marks unbuilt stages as planned/future
- §12 cross-links to CH-AUTH-014 for presign-secret IAM bypass

**Dependencies:**
- **DX (Docs Writer):** Update landing-zone §3, §10.1, §12
- **DO (DevOps Specialist):** Verify `TF_VAR_secret_key` sourcing works in practice

**Confidence:** 90 (High — multiple documentation and hygiene gaps)

---

## Architectural Assessment

### Architecture Impact Summary

The findings in scope touch three architectural layers:

1. **Authentication configuration surface (CH-AUTH-001, 002, 003, 013):** The `FLOCI_AUTH_MODE` parameter is the correct architectural abstraction — a single enum that collapses a dangerous 2×2 matrix into two coherent states. The defects are in the implementation of that abstraction: the `${VAR:-default}` escape hatch (CH-AUTH-002), the conflation of IAM service vs. enforcement (CH-AUTH-003), and the missing account-axis wiring (CH-AUTH-001). The architectural fix is to make the abstraction watertight: derive posture unconditionally from the mode, keep the IAM service always on, and move the account selector from the AKID to the installer config.

2. **Terraform provider and backend coherence (CH-LZ-005, 006, 008, 009, 010, 011, 012):** The `_common/` template pattern is architecturally sound — a single source of truth for provider configuration, version constraints, and backend wiring. The defects are in drift between the template and the stage, and in the merge-order hazard that allows a tfvars file to silently override governance tags. The architectural fix is to enforce the template as canonical (lint check), reverse the merge order so governance tags are immutable, and add validation on the `environment` variable.

3. **IAM policy design (CH-LZ-001):** The `DenyAllExceptBoundary` statement is architecturally unsound because it applies an inverted condition operator to a key that is absent from the request context for most of the denied actions. The architectural fix is to split the statement by whether the condition key exists in the request context — three statements, each scoped to the actions where the key's presence/absence is known.

### SOLID Assessment

| Principle | Assessment |
|-----------|-----------|
| **S**ingle Responsibility | The `FLOCI_AUTH_MODE` parameter has a single responsibility: collapse the auth matrix into two coherent states. The defects are in the implementation, not the design. |
| **O**pen/Closed | The `_common/` template pattern is open for extension (new stages copy the template) but was not closed for modification (stage 10 diverged). The lint check (CH-LZ-008) closes this. |
| **L**iskov Substitution | N/A — no interface hierarchy in scope |
| **I**nterface Segregation | The `FLOCI_AUTH_MODE` parameter is minimal — two values, one escape hatch. The `FLOCI_AUTH_UNSAFE_OVERRIDE` is correctly segregated from the normal path. |
| **D**ependency Inversion | The `_common/` template is the abstraction; stages depend on it. The drift (CH-LZ-008, 009, 010) is a dependency inversion violation — the stage should not independently redefine what the template defines. |

### Module Boundary Assessment

| Boundary | Status | Finding |
|----------|--------|---------|
| `setup-floci.sh` ↔ `dev-twin.sh` | Clean | Auth mode passed via env var at invocation boundary |
| `_common/providers.tf` ↔ stage `providers.tf` | **Drifted** | CH-LZ-008, 009, 010 — stage diverged from template |
| `authentication-plan.md` ↔ `setup-floci.sh` | **Inconsistent** | CH-AUTH-002, 003 — plan specifies behaviour the code doesn't enforce |
| `landing-zone-design.md` ↔ `infra/` | **Inconsistent** | CH-LZ-001, 005, 008 — design claims not matched by implementation |
| `backend.hcl.example` ↔ `dev.tfvars` | **Drifted** | CH-LZ-005 — region mismatch |

---

## Verdict

**VERDICT: CONDITIONAL PASS**

**Rationale:** All 14 findings in the SW scope are correctly identified, well-evidenced, and have clear architectural fixes. No finding is rejected or disputed. The CONDITIONAL PASS reflects that three findings (CH-LZ-008, CH-LZ-009, CH-LZ-010) are **not yet decided by the user** — they were discovered after the review session and are not covered by "all other are okay." The requirements analysis for these three is complete and ready for user decision, but the pipeline cannot proceed to Phase B until the user rules on them.

**Blocking findings (confidence ≥80):** None — all findings are accepted or awaiting user decision. The three undecided findings (CH-LZ-008, 009, 010) are architectural defects with confidence ≥95 but are not "blocking" in the gate sense — they are blocked on user decision, not on technical disagreement.

**Advisory findings (confidence <80):** None.

**Routing:** Output to supreme-leader for A-GATE synthesis. The three undecided findings (CH-LZ-008, 009, 010) must be presented to the user for decision before Phase B can begin.

## Dependencies on Other Specialists

| Specialist | Findings Dependent | Nature of Dependency |
|-----------|-------------------|---------------------|
| **SX (Security Reviewer)** | CH-AUTH-001, CH-AUTH-003, CH-LZ-001, CH-LZ-011 | Validate SigV4 probe interpretation, IAM service posture, three-statement policy form, ABAC tag protection |
| **TX (Test Engineer)** | CH-AUTH-002, CH-AUTH-003, CH-LZ-001 | Bats case for auth hole, SPEC-TX-006 update, G6 negative test |
| **DX (Docs Writer)** | CH-AUTH-001, CH-AUTH-012, CH-AUTH-013, CH-LZ-006, CH-LZ-012, CH-LZ-013 | Update landing-zone §4.1/§4.2, §3, §10.1, §12; restructure §6.10a–d; correct mechanism comments; update gaps register |
| **BS (Bash Specialist)** | CH-AUTH-001, CH-AUTH-002, CH-AUTH-013, CH-LZ-005 | Review installer invocation changes, readonly/unset pattern, env file format, region literal changes |
| **DO (DevOps Specialist)** | CH-AUTH-001, CH-LZ-001, CH-LZ-005, CH-LZ-006, CH-LZ-008, CH-LZ-009, CH-LZ-010, CH-LZ-011, CH-LZ-013 | Review Terraform provider wiring, backend config, version constraints, lint check, TF_VAR_secret_key sourcing |
