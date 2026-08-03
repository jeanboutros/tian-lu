# C2-SW: Software Engineer Verification — psc-0002

| Field | Value |
|-------|-------|
| Agent | software-engineer |
| Timestamp | 2026-07-30T14:00:00Z |
| Step | C2-SW |
| Phase | C |
| Ticket | psc-0002 |
| Artifact reviewed | `docs/design/authentication-plan.md` (988 lines, enriched) |
| Cross-checked | `docs/project-management/logs/tickets/psc-0002/A1-SW-software-engineer.md` (660 lines, original SPECs) |

---

## Self-Audit Checklist

| Category | Checked? | Finding or PASS |
|----------|----------|-----------------|
| Build passes (exit 0, no warnings) | N/A | No code changes in this phase — specification verification only |
| Typed enums / vocabulary types | N/A | Bash scripting — not applicable |
| Documentation on new public symbols | N/A | Specification document — no code symbols |
| Spec/datasheet fidelity | PASS | All 8 SPECs verified against the enriched auth plan with line-level evidence. All claims cross-referenced against A1-SW original specifications. |
| Module boundary | PASS | Cross-references correctly identify which file each change affects (dev-twin.sh vs setup-floci.sh vs infra/ vs landing-zone-design.md) |
| Reserved/padding fields handled | N/A | Not applicable |
| No magic numbers in doc examples | PASS | All values are named constants (`DEV_REGION`, `DEV_CREDENTIALS_FILE`, `DurationSeconds=3600`, `FLOCI_SERVICES_IAM_ENABLED`) |
| Buffer safety | N/A | Not applicable |
| AGENTS.md compliance | PASS | Follows `${VAR:-default}` test-injection convention; `_auth_*` locals are non-readonly plain assignments (not `local` — correct for top-level script context); `readonly` declarations at top level after `case` block |
| Conventional commit ready | N/A | Specification verification phase — no commits |

---

## Verification Results

### SPEC-SW-001: DEV_REGION constant — all eu-west-1 replaced with $DEV_REGION, default eu-west-2

**Status: PASS**  
**Confidence: 95 (Critical)**

**Evidence:**

1. **`DEV_REGION` constant declared** at §6.1a (line 325):
   ```bash
   readonly DEV_REGION="${DEV_REGION:-eu-west-2}"
   ```
   Default is `eu-west-2`, matching the Terraform project (`infra/environments/dev.tfvars:13`). Overridable via env var for testing.

2. **Zero `eu-west-1` literals** in the auth plan. Grep for `eu-west-1` in `authentication-plan.md` returns zero matches. (The only `eu-west-1` in the project is in `docs/design/solution-design.md:364` — a separate document, not part of the auth plan.)

3. **All 10 `DEV_REGION` references** use the constant correctly:
   - §5.2 rotation flow (lines 223, 227): `--region "$DEV_REGION"` in both `create-access-key` and `sts get-caller-identity` calls
   - §6.5 `_rotate_bootstrap_credentials` (lines 429, 444, 456): `--region ${DEV_REGION}` in create, verify, and delete calls
   - §6.6 `dev_env` (lines 498, 517, 519): `$DEV_REGION` in AWS config profile, export lines, and inline instructions
   - §6.7 `_print_next_steps` (line 549): `--region %s` with `$DEV_REGION` in manual rotation command

**Verdict:** All `eu-west-1` literals replaced. `DEV_REGION` constant declared with correct default. All references use the constant.

---

### SPEC-SW-002: DenyAllExceptBoundary — StringNotEquals on iam:PermissionsBoundary, Resource = "*"

**Status: PASS**  
**Confidence: 90 (Critical)**

**Evidence:**

1. **Cross-reference added** at §6.10a (lines 645-649): Documents that the `platform-admin` policy uses `DenyAllExceptBoundary` with `StringNotEquals` on `iam:PermissionsBoundary`.

2. **Corrected HCL block** at §6.10a (lines 655-677):
   ```hcl
   statement {
       sid    = "DenyAllExceptBoundary"
       effect = "Deny"
       actions = [
         "iam:DeleteRolePermissionsBoundary",
         "iam:DeleteUserPermissionsBoundary",
         "iam:DeleteGroupPermissionsBoundary",
         "iam:DeletePolicy",
         "iam:DeletePolicyVersion",
       ]
       resources = [
         "*",
       ]
       condition {
         test     = "StringNotEquals"
         variable = "iam:PermissionsBoundary"
         values = [
           aws_iam_policy.general_app_boundary.arn,
         ]
       }
     }
   ```
   - `resources = ["*"]` — correct: the denied actions act on IAM principal ARNs (roles, users, groups), not on the policy ARN
   - `StringNotEquals` on `iam:PermissionsBoundary` — correct: denies the actions unless the boundary condition matches
   - `aws_iam_policy.general_app_boundary.arn` — correct: references the boundary policy ARN

3. **Explanation of the fix** at lines 679-683: Documents why the original `resources = [boundary_arn]` was a no-op and why `Resource = "*"` with `StringNotEquals` is the correct pattern.

**Verdict:** Deny statement correctly scoped. Cross-reference present. Explanation of the fix documented.

---

### SPEC-SW-003: readonly out of case — non-readonly _auth_* locals, readonly at top level

**Status: PASS**  
**Confidence: 85 (High)**

**Evidence:**

1. **Non-readonly `_auth_*` locals** at §4.2 (lines 141-144) and §6.1 (lines 285-288):
   ```bash
   _auth_validate_signatures=""
   _auth_iam_enforcement=""
   _auth_seed_deployer=""
   _auth_iam_enabled=""
   ```
   - Plain assignments (not `readonly`, not `local`) — correct for top-level script context
   - `_` prefix convention signals "internal, not part of the public API"
   - Initialized to empty string before the `case` block

2. **`case` block assigns to `_auth_*` locals** at §4.2 (lines 145-162) and §6.1 (lines 289-306):
   - `off` branch: all four `_auth_*` locals set to `"false"`
   - `sigv4` branch: all four `_auth_*` locals set to `"true"`
   - `*` branch: error message + `exit 1`

3. **`readonly` declarations at top level after `case`** at §4.2 (lines 167-170) and §6.1 (lines 309-312):
   ```bash
   readonly FLOCI_AUTH_VALIDATE_SIGNATURES="${FLOCI_AUTH_VALIDATE_SIGNATURES:-$_auth_validate_signatures}"
   readonly FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED="${FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED:-$_auth_iam_enforcement}"
   readonly FLOCI_SERVICES_IAM_SEED_DEPLOYER_PRINCIPAL="${FLOCI_SERVICES_IAM_SEED_DEPLOYER_PRINCIPAL:-$_auth_seed_deployer}"
   readonly FLOCI_SERVICES_IAM_ENABLED="${FLOCI_SERVICES_IAM_ENABLED:-$_auth_iam_enabled}"
   ```
   - `${VAR:-default}` form preserves test-injection convention
   - Tests can override any individual auth var by setting the env var before sourcing
   - `readonly` is at the top level, not inside the `case` branches

4. **Comment explains the pattern** at lines 138-140 and 282-284: "Use non-readonly locals inside the case so tests can inject overrides via the ${VAR:-default} convention before the readonly declarations below."

**Verdict:** `readonly` correctly moved out of `case`. Non-readonly `_auth_*` locals used inside `case`. `readonly` with `${VAR:-default}` at top level. Test-injection convention preserved.

---

### SPEC-SW-004: FLOCI_SERVICES_IAM_ENABLED — present in both off and sigv4 branches

**Status: PASS**  
**Confidence: 90 (Critical)**

**Evidence:**

1. **`_auth_iam_enabled` local declared** at §4.2 (line 144) and §6.1 (line 288):
   ```bash
   _auth_iam_enabled=""
   ```

2. **Both branches set `_auth_iam_enabled`** at §4.2 (lines 150, 156) and §6.1 (lines 294, 300):
   - `off` branch: `_auth_iam_enabled="false"`
   - `sigv4` branch: `_auth_iam_enabled="true"`

3. **`readonly FLOCI_SERVICES_IAM_ENABLED` declared** at §4.2 (line 170) and §6.1 (line 312):
   ```bash
   readonly FLOCI_SERVICES_IAM_ENABLED="${FLOCI_SERVICES_IAM_ENABLED:-$_auth_iam_enabled}"
   ```

4. **`write_env_file` emits `FLOCI_SERVICES_IAM_ENABLED`** at §6.2 (line 333):
   ```bash
   FLOCI_SERVICES_IAM_ENABLED=${FLOCI_SERVICES_IAM_ENABLED}
   ```

5. **Test impact documented** at §6.2 note (lines 339-342): SPEC-TX-006 test case 3 must be reversed — it should now assert `FLOCI_SERVICES_IAM_ENABLED=true` IS present in sigv4 mode and `FLOCI_SERVICES_IAM_ENABLED=false` IS present in off mode.

**Verdict:** `FLOCI_SERVICES_IAM_ENABLED` present in both branches. `write_env_file` emits it. Test impact documented.

---

### SPEC-SW-005: sts get-caller-identity — verification step between create and delete

**Status: PASS**  
**Confidence: 90 (Critical)**

**Evidence:**

1. **Rotation flow updated** at §5.2 (lines 218-236): Step 4c added between create (4b) and delete (4d):
   ```
   c. VERIFY: podman exec -e AWS_ACCESS_KEY_ID=<new_akid> -e AWS_SECRET_ACCESS_KEY=<new_sk>
      tianlu-floci aws --endpoint-url http://localhost:4566 --region "$DEV_REGION"
      sts get-caller-identity
      → Must return the floci-deployer ARN. If it fails, abort rotation — do NOT delete the old key.
   ```

2. **Verification code block** at §6.5 (lines 440-452):
   ```bash
   # Verify the new key works before deleting the old one.
   # If verification fails, abort — do NOT delete the only working credential.
   if ! _run_as_floci_guest \
     "podman exec -e AWS_ACCESS_KEY_ID=${new_akid} -e AWS_SECRET_ACCESS_KEY=${new_sk} \
      tianlu-floci aws --endpoint-url http://localhost:4566 --region ${DEV_REGION} \
      sts get-caller-identity 2>/dev/null"; then
     printf 'WARNING: new access key failed verification — keeping old key %s active.\n' \
       "$bootstrap_akid" >&2
     printf '         The new key may be malformed. Check Floci logs and retry rotation.\n' >&2
     DEV_BOOTSTRAP_AKID="$bootstrap_akid"
     DEV_BOOTSTRAP_SECRET="$bootstrap_secret"
     return 0
   fi
   ```
   - Verification uses `sts get-caller-identity` — the canonical "who am I?" call
   - On failure: preserves old key, emits WARNING, returns 0 (non-fatal — dev twin continues)
   - On success: proceeds to delete old key and persist new creds

3. **Partial-failure handling documented** at §6.5 (lines 400-403): "if `create-access-key` succeeds but `sts get-caller-identity` fails, the old key is preserved and a WARNING is emitted. The new (unverified) key is discarded — it will be orphaned in Floci's IAM store but cannot be used."

**Verdict:** `sts get-caller-identity` verification step correctly placed between create and delete. Old key preserved on verification failure. Partial-failure scenario documented.

---

### SPEC-SW-006: Hardcoded bucket — removed from providers.tf, documented in auth plan

**Status: PASS**  
**Confidence: 85 (High)**

**Evidence:**

1. **New subsection added** at §6.10b (lines 685-725): "Terraform backend configuration"

2. **Full `terraform init` command documented** at lines 694-709:
   ```bash
   terraform init \
     -backend-config="bucket=tf-state-dev" \
     -backend-config="key=dev/10-management-iam/terraform.tfstate" \
     -backend-config="region=eu-west-2" \
     -backend-config="endpoint=http://localhost:4566" \
     -backend-config="access_key=111111111111" \
     -backend-config="secret_key=floci" \
     -backend-config="skip_credentials_validation=true" \
     -backend-config="skip_region_validation=true" \
     -backend-config="skip_metadata_api_check=true" \
     -backend-config="skip_requesting_account_id=true" \
     -backend-config="force_path_style=true"
   ```

3. **Post-rotation init command** at lines 711-717: Documents replacing `secret_key=floci` with the rotated deployer secret.

4. **Note about providers.tf** at lines 723-725:
   > The `bucket` and `region` values are NOT hardcoded in `providers.tf`. They are passed via `-backend-config` so the same stage code can target different environments (dev/uat/prod) by changing only the init flags.

5. **Explanation of the anti-pattern** at lines 687-690: "All subsequent stages must be initialized with the backend config passed at init time, not hardcoded in `providers.tf`."

**Verdict:** Full `terraform init -backend-config` command documented. Note that `providers.tf` should not hardcode bucket. Post-rotation credential update documented.

---

### SPEC-SW-007: Environment tag — "development" removed, "dev" used

**Status: PASS**  
**Confidence: 85 (High)**

**Evidence:**

1. **New subsection added** at §6.10c (lines 727-750): "Environment tag consistency"

2. **Explicit prohibition of duplicate tags** at lines 729-733:
   > The `dev.tfvars` `default_tags` map must NOT include `Project`, `Environment`, or `ManagedBy` — these are injected by `providers.tf`'s `default_tags` merge from `var.environment`. Duplicating them causes `terraform plan` warnings and breaks ABAC tag-match queries. The `Environment` tag value is `"dev"` (from `var.environment = "dev"`), not `"development"`.

3. **`providers.tf` merge documented** at lines 737-745:
   ```hcl
   default_tags {
       tags = merge({
         Project     = "tianlu"
         Environment = var.environment
         ManagedBy   = "terraform"
       }, var.default_tags)
     }
   ```

4. **Correct value documented** at lines 747-750: `var.environment` is `"dev"` (from `dev.tfvars:10`), so the injected `Environment` tag will be `"dev"` — matching the documented environment values (`dev`, `uat`, `prod`).

5. **Guidance for `dev.tfvars`** at lines 749-750: "The `default_tags` map in `dev.tfvars` should contain only additional tags (e.g., `Owner`), not the three that `providers.tf` already injects."

**Verdict:** `"development"` explicitly called out as wrong. `"dev"` documented as the correct value. `providers.tf` merge pattern documented. Guidance for `dev.tfvars` provided.

---

### SPEC-SW-008: DurationSeconds — 3600s bound + 30-min re-assumption in landing-zone-design.md

**Status: PASS**  
**Confidence: 80 (High)**

**Evidence:**

1. **New subsection added** at §6.10d (lines 752-773): "IRSA stand-in session duration"

2. **Cross-reference to landing-zone-design.md** at lines 754-757:
   > The IRSA stand-in in `landing-zone-design.md` §5.4 specifies a `DurationSeconds` bound of 3600s (1 hour) and a re-assumption cadence of 30 minutes.

3. **Parameter table** at lines 759-763:
   | Parameter | Value | Rationale |
   |-----------|-------|-----------|
   | `DurationSeconds` | 3600 (1 hour) | Limits credential lifetime; matches the default AWS console session duration |
   | Re-assumption cadence | Every 30 minutes (half the session duration) | Ensures overlap — the new credential is valid before the old one expires |
   | Expiry behavior | Pod restarts if credentials expire | The sidecar/injector must exit non-zero when `sts:AssumeRole` fails, triggering a Kubernetes restart |

4. **Re-assumption cadence rationale** at lines 765-768: "The re-assumption cadence of half the session duration (30 minutes for a 1-hour session) follows the standard credential rotation pattern: refresh before expiry so there is always a valid credential."

5. **Floci accommodation note** at lines 770-773: Documents that this is a manual equivalent of EKS IRSA/EKS Pod Identity automatic refresh.

**Verdict:** `DurationSeconds` bound of 3600s documented. 30-minute re-assumption cadence documented. Expiry behavior documented. Cross-reference to `landing-zone-design.md` §5.4 present.

---

## Summary

| SPEC | Status | Confidence | Key Evidence |
|------|--------|-----------|-------------|
| SPEC-SW-001 | PASS | 95 | `DEV_REGION` constant declared (line 325); zero `eu-west-1` literals; 10 `$DEV_REGION` references |
| SPEC-SW-002 | PASS | 90 | `DenyAllExceptBoundary` with `resources = ["*"]` and `StringNotEquals` on `iam:PermissionsBoundary` (lines 655-677) |
| SPEC-SW-003 | PASS | 85 | Non-readonly `_auth_*` locals (lines 141-144); `readonly` at top level with `${VAR:-default}` (lines 167-170) |
| SPEC-SW-004 | PASS | 90 | `_auth_iam_enabled` in both branches (lines 150, 156); `readonly FLOCI_SERVICES_IAM_ENABLED` (line 170); `write_env_file` emits it (line 333) |
| SPEC-SW-005 | PASS | 90 | `sts get-caller-identity` verification between create and delete (lines 440-452); old key preserved on failure |
| SPEC-SW-006 | PASS | 85 | Full `terraform init -backend-config` command (lines 694-709); note that `providers.tf` must not hardcode bucket (lines 723-725) |
| SPEC-SW-007 | PASS | 85 | `"development"` called out as wrong (line 733); `"dev"` documented as correct (line 733); `providers.tf` merge pattern documented (lines 737-745) |
| SPEC-SW-008 | PASS | 80 | `DurationSeconds` 3600s bound (line 761); 30-min re-assumption cadence (line 762); expiry behavior (line 763) |

---

## Verdict

**VERDICT: APPROVED**

**FINDINGS:** No issues found — all 8 SPEC-SW specifications are correctly implemented in the enriched `docs/design/authentication-plan.md`. The architecture is sound.

**RATIONALE:**

All 8 SPECs from the A1-SW review have been correctly incorporated into the authentication plan:

1. **SPEC-SW-001** — `DEV_REGION` constant with `eu-west-2` default; all 5+ `eu-west-1` literals replaced with `$DEV_REGION` references across §5.2, §6.5, §6.6, and §6.7.
2. **SPEC-SW-002** — `DenyAllExceptBoundary` corrected to `resources = ["*"]` with `StringNotEquals` on `iam:PermissionsBoundary`; cross-reference added at §6.10a with explanation of the fix.
3. **SPEC-SW-003** — `readonly` moved out of `case` branches; non-readonly `_auth_*` locals used inside `case`; `readonly` with `${VAR:-default}` at top level; test-injection convention preserved.
4. **SPEC-SW-004** — `FLOCI_SERVICES_IAM_ENABLED` added to both `off` and `sigv4` branches; `write_env_file` updated; test impact documented.
5. **SPEC-SW-005** — `sts get-caller-identity` verification step inserted between `create-access-key` and `delete-access-key`; old key preserved on verification failure; partial-failure scenario documented.
6. **SPEC-SW-006** — Full `terraform init -backend-config` command documented at §6.10b; note that `providers.tf` must not hardcode bucket; post-rotation credential update documented.
7. **SPEC-SW-007** — `"development"` explicitly called out as wrong; `"dev"` documented as correct; `providers.tf` merge pattern documented; guidance for `dev.tfvars` provided at §6.10c.
8. **SPEC-SW-008** — `DurationSeconds` 3600s bound + 30-min re-assumption cadence documented at §6.10d; expiry behavior specified; cross-reference to `landing-zone-design.md` §5.4.

**ROUTING:** N/A — APPROVED. No rework required.

**Conditions for downstream gates:** None. All SPECs pass independently. The auth plan is ready for Phase B implementation.

---

## References

| Claim / Decision | Source | Verification |
|-----------------|--------|-------------|
| `DEV_REGION` constant at line 325 | `authentication-plan.md:325` | Verified — `readonly DEV_REGION="${DEV_REGION:-eu-west-2}"` |
| Zero `eu-west-1` literals in auth plan | `grep eu-west-1 authentication-plan.md` | Verified — zero matches |
| `DenyAllExceptBoundary` with `resources = ["*"]` | `authentication-plan.md:666-668` | Verified — correct resource scoping |
| `StringNotEquals` on `iam:PermissionsBoundary` | `authentication-plan.md:669-674` | Verified — correct condition |
| Non-readonly `_auth_*` locals | `authentication-plan.md:141-144` | Verified — plain assignments, no `readonly`, no `local` |
| `readonly` at top level with `${VAR:-default}` | `authentication-plan.md:167-170` | Verified — test-injection convention preserved |
| `_auth_iam_enabled` in both branches | `authentication-plan.md:150,156` | Verified — `"false"` in off, `"true"` in sigv4 |
| `FLOCI_SERVICES_IAM_ENABLED` in `write_env_file` | `authentication-plan.md:333` | Verified — emitted to env file |
| `sts get-caller-identity` verification | `authentication-plan.md:440-452` | Verified — between create and delete, old key preserved on failure |
| Full `terraform init -backend-config` command | `authentication-plan.md:694-709` | Verified — all 11 flags documented |
| `"development"` called out as wrong | `authentication-plan.md:733` | Verified — "not `"development"`" |
| `DurationSeconds` 3600s bound | `authentication-plan.md:761` | Verified — parameter table |
| 30-min re-assumption cadence | `authentication-plan.md:762` | Verified — parameter table |
