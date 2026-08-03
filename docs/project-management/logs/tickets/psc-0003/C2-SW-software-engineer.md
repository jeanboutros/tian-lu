# C2-SW: Software Engineer Verification — psc-0003

| Field | Value |
|-------|-------|
| Agent | software-engineer |
| Timestamp | 2026-07-30T23:30:00Z |
| Step | C2-SW |
| Phase | C |
| Ticket | psc-0003 |
| Source requirements | A1-SW-software-engineer.md (14 SPECs) |
| Verdict | CONDITIONAL PASS |

---

## Self-Audit Checklist

| Category | Checked? | Finding or PASS |
|----------|----------|-----------------|
| Build passes (exit 0, no warnings) | N/A — bash/Terraform, no compilation | N/A |
| Typed enums / vocabulary types (no raw integers in API) | N/A — bash/Terraform, not C++ | N/A |
| Documentation on new public symbols | yes | PASS — all changed files have inline comments explaining the change rationale |
| Spec/datasheet fidelity (fields match spec) | yes | PASS — all findings cross-referenced against A1 SPECs, AWS IAM docs, Floci scraped docs, bash manual |
| Module boundary (no platform headers in shared modules) | N/A — bash/Terraform | N/A |
| Reserved/padding fields handled | N/A | N/A |
| No magic numbers in doc examples | N/A | N/A |
| Buffer safety (bounded copies) | N/A | N/A |
| AGENTS.md compliance | yes | PASS — all findings mapped to acceptance criteria; no application code written; dependencies on other specialists declared |
| Conventional commit ready | N/A — Phase C verification | N/A |

---

## Reference Validation

| Primary Claim | Reference Provided | Authority Level | Verified? | Correctly Applied? |
|--------------|-------------------|-----------------|-----------|-------------------|
| SPEC-SW-001: FLOCI_DEFAULT_ACCOUNT_ID configurable | `setup-floci.sh:55` — `${FLOCI_DEFAULT_ACCOUNT_ID:-000000000000}` | 3 (project file) | ✓ | ✓ |
| SPEC-SW-001: providers.tf access_key uses var.account_id | `_common/providers.tf:40` — `access_key = var.account_id` | 3 (project file) | ✓ | ⚠ — see F1 |
| SPEC-SW-002: FLOCI_AUTH_MODE case statement | `setup-floci.sh:80-93` — case + UNSAFE_OVERRIDE | 3 (project file) | ✓ | ✓ |
| SPEC-SW-002: _auth_on unset after use | `setup-floci.sh:104` — `unset _auth_on` | 3 (project file) | ✓ | ✓ |
| SPEC-SW-003: FLOCI_SERVICES_IAM_ENABLED=true in both branches | `setup-floci.sh:97` — `${FLOCI_SERVICES_IAM_ENABLED:-true}` | 3 (project file) | ✓ | ✓ |
| SPEC-SW-004: §6.10a–d split | Not in scope of changed files — docs-only | N/A | N/A | N/A |
| SPEC-SW-005: FLOCI_AUTH_MODE emitted to env file | `setup-floci.sh:911` — `FLOCI_AUTH_MODE=${FLOCI_AUTH_MODE}` | 3 (project file) | ✓ | ✓ |
| SPEC-SW-005: dev_status surfaces auth mode | `dev-twin.sh:733-752` — dev_status function | 3 (project file) | ⚠ — see F2 |
| SPEC-SW-006: Three-statement Deny form | `10-management-iam/main.tf:56-87` — DenyPrincipalCreationWithoutBoundary, DenyBoundaryPolicyMutation, DenyBoundaryDetach | 3 (project file) | ✓ | ✓ |
| SPEC-SW-006: iam:DeleteGroupPermissionsBoundary removed | `10-management-iam/main.tf` — not present | 3 (project file) | ✓ | ✓ |
| SPEC-SW-007: backend.hcl region = eu-west-2 | `backend.hcl copy.example:18` — `region = "eu-west-2"` | 3 (project file) | ✓ | ✓ |
| SPEC-SW-007: dev.tfvars region = eu-west-2 | `dev.tfvars:13` — `region = "eu-west-2"` | 3 (project file) | ✓ | ✓ |
| SPEC-SW-007: dev-twin.sh DEV_REGION = eu-west-2 | `dev-twin.sh:24` — `DEV_REGION="${DEV_REGION:-eu-west-2}"` | 3 (project file) | ✓ | ✓ |
| SPEC-SW-007: setup-floci.sh FLOCI_DEFAULT_REGION | `setup-floci.sh:54` — `FLOCI_DEFAULT_REGION="${FLOCI_DEFAULT_REGION:-eu-west-1}"` | 3 (project file) | ⚠ — see F3 |
| SPEC-SW-007: preflight-floci.sh REGION | `preflight-floci.sh:25` — `REGION="${AWS_DEFAULT_REGION:-us-east-1}"` | 3 (project file) | ⚠ — see F4 |
| SPEC-SW-008: backend.hcl.example two-flag form | `backend.hcl copy.example:2-3` — `-backend-config=../../_common/backend-dev.hcl -backend-config="key=..."` | 3 (project file) | ✓ | ✓ |
| SPEC-SW-009: Governance trio in _common/providers.tf | `_common/providers.tf:52-58` — merge with Project, Environment, ManagedBy | 3 (project file) | ✓ | ✓ |
| SPEC-SW-009: Governance trio in 10-management-iam/providers.tf | `10-management-iam/providers.tf:52-58` — same merge | 3 (project file) | ✓ | ✓ |
| SPEC-SW-009: dev.tfvars default_tags has only Owner | `dev.tfvars:24-29` — only Owner, with correct comment | 3 (project file) | ✓ | ✓ |
| SPEC-SW-009: sns and sqs in stage endpoints | `10-management-iam/providers.tf:74-75` — sns and sqs present | 3 (project file) | ✓ | ✓ |
| SPEC-SW-010: _common/versions.tf aws >= 6.56.0 | `_common/versions.tf:15` — `version = ">= 6.56.0"` | 3 (project file) | ⚠ — see F5 |
| SPEC-SW-010: 10-management-iam/versions.tf matches | `10-management-iam/versions.tf:15` — `version = ">= 6.56.0"` | 3 (project file) | ⚠ — see F5 |
| SPEC-SW-011: backend.tf has no key | `10-management-iam/backend.tf:4-6` — `backend "s3" {}` with no key | 3 (project file) | ✓ | ✓ |
| SPEC-SW-012: merge order reversed (governance wins) | `_common/providers.tf:53` — `merge(var.default_tags, {Project, Environment, ManagedBy})` | 3 (project file) | ✓ | ✓ |
| SPEC-SW-012: environment validation block | `_common/providers.tf:12-15` — `validation { condition = contains(["dev", "uat", "prod"], var.environment) }` | 3 (project file) | ✓ | ✓ |
| SPEC-SW-013: dev.tfvars comment corrected | `dev.tfvars:26-29` — "merge precedence means the providers.tf values silently override" | 3 (project file) | ✓ | ✓ |
| SPEC-SW-014: install.sh removed | `glob install.sh` — no results | 3 (project file) | ✓ | ✓ |
| SPEC-SW-014: TF_VAR_secret_key story in §10.1 | Not in scope of changed files — docs-only | N/A | N/A | N/A |
| SPEC-SW-014: §3 scaffolding qualified | Not in scope of changed files — docs-only | N/A | N/A | N/A |
| SPEC-SW-014: §12 presign cross-link | Not in scope of changed files — docs-only | N/A | N/A | N/A |

---

## SPEC-by-SPEC Verification

### SPEC-SW-001: Per-environment FLOCI_DEFAULT_ACCOUNT_ID

| Acceptance Criterion | Status | Evidence |
|---------------------|--------|----------|
| FLOCI_DEFAULT_ACCOUNT_ID configurable per environment | ✓ PASS | `setup-floci.sh:55` — `${FLOCI_DEFAULT_ACCOUNT_ID:-000000000000}` — overridable via env var |
| _common/providers.tf access_key uses deployer's real AKID, not var.account_id | ⚠ CONDITIONAL | `_common/providers.tf:40` — `access_key = var.account_id`. The SPEC requires `access_key` to be the **deployer's real AKID** (rotated, sourced from DEV_CREDENTIALS_FILE), not `var.account_id`. Currently `var.account_id` is still used as the access key. See Finding F1. |
| data.aws_caller_identity precondition asserts var.account_id | ✗ NOT IMPLEMENTED | No `data.aws_caller_identity` or `precondition` block found in any `.tf` file under `infra/`. See Finding F1. |
| Landing-zone §4.1/§4.2 updated | N/A — docs-only, not in changed files | |
| Three-outcome probe executed | N/A — runtime, not in changed files | |
| preflight-floci.sh G1 uses deployer credentials | ✗ NOT IMPLEMENTED | `preflight-floci.sh:35` — `aws_admin()` uses `DEV_AKID` (default `111111111111`) as the access key, not a deployer credential. See Finding F1. |

**Verdict: CONDITIONAL PASS** — The `FLOCI_DEFAULT_ACCOUNT_ID` is correctly made configurable. However, the `access_key = var.account_id` pattern in `_common/providers.tf` was not changed to use the deployer's real AKID, and the `data.aws_caller_identity` precondition was not added. These are the core architectural changes SPEC-SW-001 required. See Finding F1.

---

### SPEC-SW-002: Rewrite §4.2 with FLOCI_AUTH_UNSAFE_OVERRIDE

| Acceptance Criterion | Status | Evidence |
|---------------------|--------|----------|
| FLOCI_AUTH_MODE=off + FLOCI_AUTH_VALIDATE_SIGNATURES=true yields false | ✓ PASS | `setup-floci.sh:80-93` — case statement derives `_auth_on="false"` for `off` mode; without `FLOCI_AUTH_UNSAFE_OVERRIDE=1`, the derived variables are set to `$_auth_on` unconditionally (lines 91-92) |
| FLOCI_AUTH_UNSAFE_OVERRIDE=1 allows individual override | ✓ PASS | `setup-floci.sh:87-89` — when override is 1, uses `${VAR:-$_auth_on}` form |
| _auth_on unset after use | ✓ PASS | `setup-floci.sh:104` — `unset _auth_on` |
| §4.2 code block updated | N/A — docs-only | |
| §6.1 code block updated | N/A — docs-only | |

**Verdict: APPROVED** — The implementation matches the SPEC exactly. The case statement, UNSAFE_OVERRIDE guard, and unset pattern are all correct.

---

### SPEC-SW-003: FLOCI_SERVICES_IAM_ENABLED=true in both branches

| Acceptance Criterion | Status | Evidence |
|---------------------|--------|----------|
| FLOCI_SERVICES_IAM_ENABLED is true in both modes | ✓ PASS | `setup-floci.sh:97` — `${FLOCI_SERVICES_IAM_ENABLED:-true}` — single assignment, not mode-dependent |
| §6.2 note corrected | N/A — docs-only | |
| SPEC-TX-006 case-3 corrected | N/A — test-only | |
| preflight-floci.sh G1 can create probe user in both modes | ✓ PASS | `preflight-floci.sh:45` — `aws_admin iam create-user` — uses `DEV_AKID` as access key; IAM service is always enabled |

**Verdict: APPROVED** — The implementation correctly sets `FLOCI_SERVICES_IAM_ENABLED=true` unconditionally, independent of auth mode.

---

### SPEC-SW-004: Split §6.10a–d into changelog/appendix

| Acceptance Criterion | Status | Evidence |
|---------------------|--------|----------|
| §6.10a–d no longer mixes pending and landed changes | N/A — docs-only, not in changed files | |
| Landed changes in clearly marked appendix | N/A — docs-only | |
| Pending changes in clearly marked section | N/A — docs-only | |

**Verdict: N/A** — This SPEC is entirely documentation restructuring. None of the changed files (setup-floci.sh, infra/*.tf, dev.tfvars, backend.hcl.example) are documentation files. This is a Docs Writer (DX) deliverable.

---

### SPEC-SW-005: Emit FLOCI_AUTH_MODE to env file; surface in dev_status

| Acceptance Criterion | Status | Evidence |
|---------------------|--------|----------|
| FLOCI_AUTH_MODE written to floci.env | ✓ PASS | `setup-floci.sh:911` — `FLOCI_AUTH_MODE=${FLOCI_AUTH_MODE}` in the env file heredoc |
| dev_status displays current auth mode | ⚠ CONDITIONAL | `dev-twin.sh:733-752` — `dev_status()` shows instance, disk, service, and health status. It does NOT display the auth mode. See Finding F2. |
| §4.4 claim is accurate | ✓ PASS | The env file now retains `FLOCI_AUTH_MODE` from the original install |

**Verdict: CONDITIONAL PASS** — The env file emission is correct. The `dev_status` function does not surface the auth mode. See Finding F2.

---

### SPEC-SW-006: Replace DenyAllExceptBoundary with three-statement form

| Acceptance Criterion | Status | Evidence |
|---------------------|--------|----------|
| DenyAllExceptBoundary replaced with three-statement form | ✓ PASS | `10-management-iam/main.tf:56-87` — three statements: DenyPrincipalCreationWithoutBoundary (lines 56-69), DenyBoundaryPolicyMutation (lines 74-80), DenyBoundaryDetach (lines 82-87) |
| iam:DeleteGroupPermissionsBoundary removed | ✓ PASS | Not present in the file |
| terraform destroy on stage 10 succeeds | N/A — runtime verification | |
| terraform apply succeeds with policy version rotation | N/A — runtime verification | |
| G6 negative test added | N/A — test-only | |

**Verdict: APPROVED** — The three-statement form matches the SPEC exactly. Statement 1 uses `StringNotEquals` on `iam:PermissionsBoundary` for actions where the key IS present (CreateRole, CreateUser, PutRolePermissionsBoundary, PutUserPermissionsBoundary). Statement 2 denies boundary policy mutation on the specific boundary ARN with no condition (key is absent). Statement 3 denies boundary detach on `*` with no condition. `iam:DeleteGroupPermissionsBoundary` is correctly absent.

---

### SPEC-SW-007: Align backend region with tfvars region; unify five region literals

| Acceptance Criterion | Status | Evidence |
|---------------------|--------|----------|
| backend.hcl.example region matches dev.tfvars region (both eu-west-2) | ✓ PASS | `backend.hcl copy.example:18` — `region = "eu-west-2"`; `dev.tfvars:13` — `region = "eu-west-2"` |
| setup-floci.sh FLOCI_DEFAULT_REGION is eu-west-2 | ⚠ CONDITIONAL | `setup-floci.sh:54` — `FLOCI_DEFAULT_REGION="${FLOCI_DEFAULT_REGION:-eu-west-1}"` — still defaults to `eu-west-1`, not `eu-west-2`. See Finding F3. |
| preflight-floci.sh REGION is eu-west-2 | ⚠ CONDITIONAL | `preflight-floci.sh:25` — `REGION="${AWS_DEFAULT_REGION:-us-east-1}"` — still defaults to `us-east-1`, not `eu-west-2`. See Finding F4. |
| dev-twin.sh DEV_REGION is eu-west-2 | ✓ PASS | `dev-twin.sh:24` — `DEV_REGION="${DEV_REGION:-eu-west-2}"` |
| No hardcoded region literals diverge | ⚠ CONDITIONAL | Two of five sites still diverge. See Findings F3, F4. |

**Verdict: CONDITIONAL PASS** — Three of five region sites are now aligned to `eu-west-2` (backend.hcl, dev.tfvars, dev-twin.sh). Two sites still have different defaults: `setup-floci.sh` defaults to `eu-west-1` and `preflight-floci.sh` defaults to `us-east-1`. See Findings F3, F4.

---

### SPEC-SW-008: Reduce §6.10b to -backend-config=../../_common/backend.hcl + per-stage key

| Acceptance Criterion | Status | Evidence |
|---------------------|--------|----------|
| §6.10b prescribes two-flag form | N/A — docs-only | |
| backend.hcl.example carries all static backend config | ✓ PASS | `backend.hcl copy.example` — contains bucket, region, dynamodb_table, skip_* flags, use_path_style, endpoints |
| -backend-config invocation matches landing-zone §10.2 | ✓ PASS | `backend.hcl copy.example:2-3` — documents `-backend-config=../../_common/backend-dev.hcl -backend-config="key=dev/20-network-hub/terraform.tfstate"` |

**Verdict: APPROVED** — The backend.hcl.example correctly uses the two-flag form with all static config in the file.

---

### SPEC-SW-009: Restore governance tags in _common/providers.tf; Owner is general tag

| Acceptance Criterion | Status | Evidence |
|---------------------|--------|----------|
| _common/providers.tf default_tags merge includes Project, Environment, ManagedBy | ✓ PASS | `_common/providers.tf:52-58` — `merge(var.default_tags, {Project = "tianlu", Environment = var.environment, ManagedBy = "terraform"})` |
| 10-management-iam/providers.tf default_tags merge includes same trio | ✓ PASS | `10-management-iam/providers.tf:52-58` — identical merge |
| dev.tfvars default_tags contains only Owner | ✓ PASS | `dev.tfvars:24-29` — only `Owner = "Jean Boutros"` with correct comment |
| Lint check exists | N/A — not in changed files | |
| sns and sqs endpoints present in stage provider | ✓ PASS | `10-management-iam/providers.tf:74-75` — `sns = var.floci_endpoint`, `sqs = var.floci_endpoint` |

**Verdict: APPROVED** — The governance trio is restored in both template and stage. `dev.tfvars` correctly carries only `Owner`. `sns` and `sqs` endpoints are present.

---

### SPEC-SW-010: Unify provider constraints to >= 6.56.0 with upper bound

| Acceptance Criterion | Status | Evidence |
|---------------------|--------|----------|
| All stages use aws >= 6.56.0, < 7.0.0 | ⚠ CONDITIONAL | `_common/versions.tf:15` — `version = ">= 6.56.0"` — **no upper bound**. `10-management-iam/versions.tf:15` — same. See Finding F5. |
| _common/versions.tf is canonical source | ✓ PASS | Both files are identical |
| No stage has different constraint | ✓ PASS | Both files match |
| versions.tf:13-14 note removed | ✓ PASS | The note about EKS v21 requiring >= 6.0 is no longer present in either file |
| Landing-zone §7 records version decision | N/A — docs-only | |

**Verdict: CONDITIONAL PASS** — The floor is unified at `>= 6.56.0` across both files, and the stale note is removed. However, the SPEC requires an upper bound `< 7.0.0` which is absent. See Finding F5.

---

### SPEC-SW-011: Omit key from providers.tf to force -backend-config override

| Acceptance Criterion | Status | Evidence |
|---------------------|--------|----------|
| 10-management-iam/providers.tf does not contain key in backend "s3" block | ✓ PASS | `10-management-iam/backend.tf:4-6` — `backend "s3" {}` — empty block, no key |
| terraform init without -backend-config="key=…" fails | N/A — runtime verification | |
| -backend-config invocation supplies the key | ✓ PASS | `backend.hcl copy.example:2-3` — documents the key override |

**Verdict: APPROVED** — The backend block is empty (`backend "s3" {}`), forcing the key to be supplied via `-backend-config`. This is the correct pattern.

---

### SPEC-SW-012: Reverse default_tags merge order; add environment validation

| Acceptance Criterion | Status | Evidence |
|---------------------|--------|----------|
| var.default_tags merged FIRST, governance trio always wins | ✓ PASS | `_common/providers.tf:53` — `merge(var.default_tags, {Project, Environment, ManagedBy})` — var.default_tags is first, governance second (wins) |
| var.environment has validation block | ✓ PASS | `_common/providers.tf:12-15` — `validation { condition = contains(["dev", "uat", "prod"], var.environment) }` |
| tfvars file cannot override governance tags | ✓ PASS | Merge order ensures governance keys are last (winning) |
| Merge order documented in comment | ✓ PASS | `_common/providers.tf:51` — "var.default_tags is merged FIRST so governance keys CANNOT be overridden by tfvars" |

**Verdict: APPROVED** — The merge order is correctly reversed, the validation block is present, and the comment explains the rationale.

---

### SPEC-SW-013: Correct mechanism in dev.tfvars comment and §6.10c

| Acceptance Criterion | Status | Evidence |
|---------------------|--------|----------|
| dev.tfvars comment states real mechanism | ✓ PASS | `dev.tfvars:26-29` — "merge precedence means the providers.tf values silently override any duplicate keys in this map, with no diagnostic" |
| Auth plan §6.10c states real mechanism | N/A — docs-only | |
| Neither comment claims "terraform plan warnings" | ✓ PASS | The dev.tfvars comment correctly states "silently override" and "no diagnostic" |

**Verdict: APPROVED** — The dev.tfvars comment correctly describes the merge precedence mechanism.

---

### SPEC-SW-014: Remove root install.sh; add TF_VAR_secret_key story to §10.1

| Acceptance Criterion | Status | Evidence |
|---------------------|--------|----------|
| install.sh removed from repository | ✓ PASS | `glob install.sh` — no results; file does not exist |
| Landing-zone §10.1 documents TF_VAR_secret_key | N/A — docs-only | |
| §3 marks unbuilt stages as planned/future | N/A — docs-only | |
| §12 cross-links to CH-AUTH-014 | N/A — docs-only | |

**Verdict: APPROVED** — `install.sh` is confirmed removed. The remaining acceptance criteria are documentation-only (DX deliverable).

---

## Findings

### Blocking Findings (confidence ≥80)

| ID | Confidence | Severity | File:Line | Description | Suggested Fix |
|----|-----------|----------|-----------|-------------|---------------|
| F1 | 90 | Critical | `_common/providers.tf:40`, `preflight-floci.sh:35` | SPEC-SW-001 requires `access_key` to be the **deployer's real AKID** (rotated, sourced from `DEV_CREDENTIALS_FILE`), not `var.account_id`. Currently `access_key = var.account_id` (the 12-digit account selector). Additionally, no `data.aws_caller_identity` precondition asserts the resolved account matches `var.account_id`. `preflight-floci.sh` G1 still uses `DEV_AKID` (default `111111111111`) as the access key, not a deployer credential. | 1. Change `_common/providers.tf:40` to `access_key = var.deployer_access_key` (new variable, sourced from `DEV_CREDENTIALS_FILE`). 2. Add `data "aws_caller_identity" "current" {}` + `lifecycle { precondition { condition = data.aws_caller_identity.current.account_id == var.account_id } }` to `10-management-iam/main.tf`. 3. Update `preflight-floci.sh` G1 to use deployer credentials. |
| F2 | 85 | High | `dev-twin.sh:733-752` | SPEC-SW-005 requires `dev_status` to surface the current auth mode. The function shows instance, disk, service, and health status but does NOT display `FLOCI_AUTH_MODE`. | Add a line to `dev_status()` that reads `FLOCI_AUTH_MODE` from the env file or queries the Floci config endpoint and prints it. |
| F3 | 85 | High | `setup-floci.sh:54` | SPEC-SW-007 requires `FLOCI_DEFAULT_REGION` to be `eu-west-2` (matching the dev environment). Current default is `eu-west-1`. | Change `FLOCI_DEFAULT_REGION="${FLOCI_DEFAULT_REGION:-eu-west-1}"` to `FLOCI_DEFAULT_REGION="${FLOCI_DEFAULT_REGION:-eu-west-2}"`. |
| F4 | 85 | High | `preflight-floci.sh:25` | SPEC-SW-007 requires `REGION` to be `eu-west-2` (matching the dev environment). Current default is `us-east-1`. | Change `REGION="${AWS_DEFAULT_REGION:-us-east-1}"` to `REGION="${AWS_DEFAULT_REGION:-eu-west-2}"`. |
| F5 | 80 | High | `_common/versions.tf:15`, `10-management-iam/versions.tf:15` | SPEC-SW-010 requires an upper bound `< 7.0.0` on the AWS provider constraint. Both files have `>= 6.56.0` with no upper bound. | Change `version = ">= 6.56.0"` to `version = ">= 6.56.0, < 7.0.0"` in both files. |

### Advisory Findings (confidence <80)

None.

---

## T-ARCH Review

| # | Check | Status | Finding |
|---|-------|--------|---------|
| T-ARCH.1 | Logical consistency | PASS | No internal contradictions in the implementation |
| T-ARCH.2 | Structural soundness | PASS | All files are well-structured with clear comments |
| T-ARCH.3 | Principle alignment | CONDITIONAL | F1 (access_key pattern) violates the architectural principle that the account axis should be on `FLOCI_DEFAULT_ACCOUNT_ID`, not the AKID-as-access-key |
| T-ARCH.4 | Completeness | CONDITIONAL | F2 (dev_status missing auth mode), F3/F4 (region divergence), F5 (missing upper bound) are incomplete implementations |
| T-ARCH.5 | Correct agent routing | PASS | All changes are in the correct files for their domain |

---

## Verdict

**VERDICT: CONDITIONAL PASS**

**Rationale:** 9 of 14 SPECs are fully APPROVED (SW-002, SW-003, SW-006, SW-008, SW-009, SW-011, SW-012, SW-013, SW-014 partial). 1 SPEC is N/A (SW-004 — docs-only). 4 SPECs have blocking findings:

- **SPEC-SW-001 (F1):** The `access_key = var.account_id` pattern was not changed to use deployer credentials, and the `data.aws_caller_identity` precondition is missing. This is the core architectural change the SPEC required. **Confidence: 90.**
- **SPEC-SW-005 (F2):** `dev_status` does not surface the auth mode. **Confidence: 85.**
- **SPEC-SW-007 (F3, F4):** Two of five region sites still diverge from `eu-west-2`. **Confidence: 85.**
- **SPEC-SW-010 (F5):** The AWS provider constraint lacks the required upper bound `< 7.0.0`. **Confidence: 80.**

The implementation is substantially correct — the auth posture derivation (SW-002), IAM service always-on (SW-003), three-statement IAM policy (SW-006), governance tag restoration (SW-009), backend key omission (SW-011), merge order reversal (SW-012), and mechanism comment correction (SW-013) are all implemented exactly as specified. The remaining gaps are well-scoped and have clear fixes.

**Routing:** Output to supreme-leader for C-GATE synthesis. The five blocking findings (F1–F5) must be addressed by the code-architect before the pipeline can proceed to Phase CR.

---

## Dependencies on Other Specialists

| Specialist | Findings Dependent | Nature of Dependency |
|-----------|-------------------|---------------------|
| **SX (Security Reviewer)** | F1 | Validate the caller-identity precondition design and the deployer credential flow |
| **DO (DevOps Specialist)** | F1, F5 | Implement the `data.aws_caller_identity` precondition; verify upper bound constraint; verify region alignment doesn't break state access |
| **BS (Bash Specialist)** | F2, F3, F4 | Implement `dev_status` auth mode display; update region defaults in `setup-floci.sh` and `preflight-floci.sh` |
| **DX (Docs Writer)** | SW-004, SW-014 | Restructure §6.10a–d; update landing-zone §3, §10.1, §12; update §4.1/§4.2 for SPEC-SW-001 |
| **TX (Test Engineer)** | SW-006 | Implement G6 negative test for the three-statement boundary policy |

---

## Self-Reflection

1. **Why were these gaps not caught earlier?** The A1 requirements were produced from a challenger review advisory (psc-adv-0017) that identified 14 distinct architectural defects. The implementation addressed the most visible and well-understood defects (auth posture, IAM policy, governance tags, merge order) but left the more complex cross-cutting changes (deployer credential flow, region unification, version upper bound) partially implemented. The `access_key = var.account_id` pattern is particularly subtle — it works in `off` mode but is architecturally wrong for `sigv4` mode, and the distinction may not have been clear to the implementer.

2. **What procedural safeguard would have caught these?** A pre-implementation checklist mapping each SPEC's acceptance criteria to specific file:line changes would have made the gaps visible before Phase B began. Additionally, the `data.aws_caller_identity` precondition is a Terraform-specific pattern that requires DevOps Specialist review — routing this SPEC to DO during Phase B would have caught the gap.

3. **Knowledge base update:** The lesson that "architectural changes spanning multiple files need a per-file acceptance criteria checklist" should be added to the software-engineering-principles skill. The specific pattern of "access_key should be the deployer credential, not the account selector" should be documented in the infra/ AGENTS.md anti-patterns section.
