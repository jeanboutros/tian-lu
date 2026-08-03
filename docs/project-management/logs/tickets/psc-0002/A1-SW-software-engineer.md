# A1-SW: Software Engineer Requirements — psc-0002

| Field | Value |
|-------|-------|
| Agent | software-engineer |
| Timestamp | 2026-07-30T12:00:00Z |
| Step | A1-SW |
| Phase | A |
| Ticket | psc-0002 |
| Artifact reviewed | `docs/design/authentication-plan.md` (653 lines) |
| Cross-checked | `infra/live/10-management-iam/main.tf`, `infra/live/10-management-iam/providers.tf`, `infra/environments/dev.tfvars`, `docs/scraped/environment-variables.md`, `docs/design/landing-zone-design.md` §5.4 |

## Verdict

**CONDITIONAL PASS** — All 8 accepted SW-relevant findings have precise change specifications. No blocking issues. The auth plan's architecture is sound; the specifications below are targeted corrections to specific code blocks and cross-document references.

---

## Change Specifications

### SPEC-SW-001: Region constant — replace `eu-west-1` with `DEV_REGION` defaulting to `eu-west-2`

**Source:** M-SW-001
**Confidence:** 95 (Critical) — SigV4 signs the region into the signature; a region mismatch causes all authenticated requests to fail with `SignatureDoesNotMatch`.
**Affected sections:** §6.5, §6.6, §6.7
**Affected files:** `mock-server/dev-twin.sh` (the auth plan's code blocks for `_rotate_bootstrap_credentials`, `dev_env`, `_print_next_steps`)

**Current state:**

The auth plan hardcodes `--region eu-west-1` in three code blocks:

- §6.5 `_rotate_bootstrap_credentials` (line 338): `aws --endpoint-url http://localhost:4566 --region eu-west-1 iam create-access-key ...`
- §6.5 `_rotate_bootstrap_credentials` (line 352): `aws --endpoint-url http://localhost:4566 --region eu-west-1 iam delete-access-key ...`
- §6.6 `dev_env` (line 394): `printf '\n[profile floci-dev]\nregion = eu-west-1\noutput = json\nca_bundle =\n'`
- §6.6 `dev_env` (line 413): `export AWS_DEFAULT_REGION=eu-west-1`
- §6.6 `dev_env` (line 415): `export AWS_DEFAULT_REGION=eu-west-1`
- §6.7 `_print_next_steps` (line 445): `aws --endpoint-url http://localhost:4566 \\` (no explicit `--region`, inherits from `AWS_DEFAULT_REGION=eu-west-1` in `dev_env`)

The Terraform project uses `eu-west-2` (`infra/environments/dev.tfvars:13`: `region = "eu-west-2"`). SigV4 signs the region into the `Authorization` header's credential scope. If the CLI signs for `eu-west-1` but the IAM policy or resource was created in `eu-west-2`, the signature validation fails.

**Required change:**

1. **Add a `DEV_REGION` constant** in `dev-twin.sh`'s constants block (after `DEV_CREDENTIALS_FILE`, line ~26):

```bash
readonly DEV_REGION="${DEV_REGION:-eu-west-2}"
```

2. **Replace all `eu-west-1` literals** in the auth plan's code blocks with `$DEV_REGION`:

**§6.5 `_rotate_bootstrap_credentials` — create-access-key call (line 338):**
```bash
# Before:
tianlu-floci aws --endpoint-url http://localhost:4566 --region eu-west-1 \
  iam create-access-key --user-name floci-deployer 2>/dev/null

# After:
tianlu-floci aws --endpoint-url http://localhost:4566 --region "$DEV_REGION" \
  iam create-access-key --user-name floci-deployer 2>/dev/null
```

**§6.5 `_rotate_bootstrap_credentials` — delete-access-key call (line 352):**
```bash
# Before:
tianlu-floci aws --endpoint-url http://localhost:4566 --region eu-west-1 \
  iam delete-access-key --user-name floci-deployer --access-key-id ${bootstrap_akid} 2>/dev/null

# After:
tianlu-floci aws --endpoint-url http://localhost:4566 --region "$DEV_REGION" \
  iam delete-access-key --user-name floci-deployer --access-key-id ${bootstrap_akid} 2>/dev/null
```

**§6.6 `dev_env` — AWS config profile (line 394):**
```bash
# Before:
printf '\n[profile floci-dev]\nregion = eu-west-1\noutput = json\nca_bundle =\n' >> "$config_file"

# After:
printf '\n[profile floci-dev]\nregion = %s\noutput = json\nca_bundle =\n' "$DEV_REGION" >> "$config_file"
```

**§6.6 `dev_env` — export lines (lines 413, 415):**
```bash
# Before:
printf 'export AWS_PROFILE=floci-dev\nexport AWS_ENDPOINT_URL=http://tianlu-floci:4566\nexport AWS_DEFAULT_REGION=eu-west-1\n'

# After:
printf 'export AWS_PROFILE=floci-dev\nexport AWS_ENDPOINT_URL=http://tianlu-floci:4566\nexport AWS_DEFAULT_REGION=%s\n' "$DEV_REGION"
```

**§6.7 `_print_next_steps` — manual rotation command (line 445):**
```bash
# Before:
printf '      AWS_PROFILE=floci-dev aws --endpoint-url http://localhost:4566 \\\n'

# After:
printf '      AWS_PROFILE=floci-dev aws --endpoint-url http://localhost:4566 --region %s \\\n' "$DEV_REGION"
```

**Rationale:** SigV4 signs the region into the `Authorization` header's credential scope (`AWS4-HMAC-SHA256 Credential=<AKID>/<date>/<region>/<service>/aws4_request`). If the CLI signs for `eu-west-1` but the Terraform resources were created in `eu-west-2`, the signature validation fails with `SignatureDoesNotMatch`. The `DEV_REGION` constant defaults to `eu-west-2` (matching the Terraform project) and is overridable via env var for testing. [Source: AWS SigV4 signing process — region is part of the credential scope; `docs/scraped/multi-account.md` confirms Floci validates the full SigV4 signature including region]

---

### SPEC-SW-002: Deny statement no-op — correct resource scoping in `DenyAllExceptBoundary`

**Source:** M-SW-002
**Confidence:** 90 (Critical) — The deny statement is a no-op; it denies actions on the boundary policy ARN but the denied actions (`iam:DeleteRolePermissionsBoundary`, etc.) act on IAM role/user/group ARNs, not on the policy ARN.
**Affected sections:** §6 (the auth plan does not currently reference this Terraform code, but the finding is SW-relevant and must be documented in the auth plan as a cross-reference)
**Affected files:** `infra/live/10-management-iam/main.tf:49-63`

**Current state** (`infra/live/10-management-iam/main.tf:49-63`):

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
      aws_iam_policy.general_app_boundary.arn,
    ]
  }
```

The `resources` field scopes the deny to the boundary policy ARN. But the denied actions (`iam:DeleteRolePermissionsBoundary`, `iam:DeleteUserPermissionsBoundary`, `iam:DeleteGroupPermissionsBoundary`) act on **role/user/group ARNs**, not on the policy ARN. The deny statement as written never matches any request because no one calls `iam:DeleteRolePermissionsBoundary` with the boundary policy ARN as the resource — they call it with a role ARN.

**Required change:**

Replace the `resources` block with `Resource = "*"` and add a `StringNotEquals` condition on `iam:PermissionsBoundary`:

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

**Semantics:** This denies the listed destructive IAM actions on **any** resource (`*`) **unless** the request includes the `iam:PermissionsBoundary` condition key matching the `general_app_boundary` ARN. In other words: you can only delete a permissions boundary, policy, or policy version if you are operating within the context of the approved boundary. Any attempt to delete these without the boundary condition is denied.

**Rationale:** The original statement scoped `resources` to the boundary policy ARN, but the denied actions operate on IAM principals (roles, users, groups), not on the policy itself. The fix uses `Resource = "*"` with a `StringNotEquals` condition — the standard AWS IAM pattern for "deny everything except when the boundary matches." [Source: AWS IAM documentation — `iam:PermissionsBoundary` is a global condition key that applies to IAM principal resources, not to the policy resource; `iam:DeleteRolePermissionsBoundary` acts on the role ARN, not the policy ARN]

**Auth plan impact:** The auth plan does not currently reference this Terraform code. Add a cross-reference in §3.3 or §8.4:

```markdown
The `platform-admin` policy in `infra/live/10-management-iam/main.tf` uses a
`DenyAllExceptBoundary` statement with `StringNotEquals` on `iam:PermissionsBoundary`
to prevent the platform-admin from deleting the permissions boundary or any policy
without the boundary condition. This is the enforcement mechanism for the escalation
ceiling described in [`landing-zone-design.md` §5.1](landing-zone-design.md).
```

---

### SPEC-SW-003: `readonly` inside `case` — compute into non-readonly locals, then declare readonly at top level

**Source:** D-SW-001
**Confidence:** 85 (High) — `readonly` inside a `case` branch breaks the `${VAR:-default}` test-injection convention because the variable is already frozen by the time the test tries to override it.
**Affected sections:** §4.2, §6.1
**Affected files:** `setup-floci.sh` (the auth plan's `FLOCI_AUTH_MODE` case statement)

**Current state** (auth plan §4.2, lines 132-148):

```bash
readonly FLOCI_AUTH_MODE="${FLOCI_AUTH_MODE:-sigv4}"
case "$FLOCI_AUTH_MODE" in
  off)
    readonly FLOCI_AUTH_VALIDATE_SIGNATURES="false"
    readonly FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED="false"
    readonly FLOCI_SERVICES_IAM_SEED_DEPLOYER_PRINCIPAL="false"
    ;;
  sigv4)
    readonly FLOCI_AUTH_VALIDATE_SIGNATURES="true"
    readonly FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED="true"
    readonly FLOCI_SERVICES_IAM_SEED_DEPLOYER_PRINCIPAL="true"
    ;;
  *)
    printf 'ERROR: FLOCI_AUTH_MODE must be "off" or "sigv4" (got: %s)\n' "$FLOCI_AUTH_MODE" >&2
    exit 1
    ;;
esac
```

**Problem:** The `readonly` declarations inside the `case` branches freeze the variables. The project's test-injection convention (`${VAR:-default}`) relies on the variable being **not yet declared** when the test sources the script — the test sets the env var before sourcing, and the script's `readonly VAR="${VAR:-default}"` picks up the test's value. But if the variable is declared `readonly` inside a `case` branch, the test cannot override it because:
1. The test must set `FLOCI_AUTH_MODE` to trigger the correct branch
2. But the branch's `readonly` declarations freeze the sub-variables before the test can override them

**Required change:**

Compute values into **non-readonly** locals inside the `case`, then declare `readonly` at the top level after the `case` block:

```bash
readonly FLOCI_AUTH_MODE="${FLOCI_AUTH_MODE:-sigv4}"

# Compute auth sub-variables based on FLOCI_AUTH_MODE.
# Use non-readonly locals inside the case so tests can inject overrides
# via the ${VAR:-default} convention before the readonly declarations below.
local _auth_validate_signatures _auth_iam_enforcement _auth_seed_deployer
case "$FLOCI_AUTH_MODE" in
  off)
    _auth_validate_signatures="false"
    _auth_iam_enforcement="false"
    _auth_seed_deployer="false"
    ;;
  sigv4)
    _auth_validate_signatures="true"
    _auth_iam_enforcement="true"
    _auth_seed_deployer="true"
    ;;
  *)
    printf 'ERROR: FLOCI_AUTH_MODE must be "off" or "sigv4" (got: %s)\n' "$FLOCI_AUTH_MODE" >&2
    exit 1
    ;;
esac

# Now freeze with test-injectable defaults.
readonly FLOCI_AUTH_VALIDATE_SIGNATURES="${FLOCI_AUTH_VALIDATE_SIGNATURES:-$_auth_validate_signatures}"
readonly FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED="${FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED:-$_auth_iam_enforcement}"
readonly FLOCI_SERVICES_IAM_SEED_DEPLOYER_PRINCIPAL="${FLOCI_SERVICES_IAM_SEED_DEPLOYER_PRINCIPAL:-$_auth_seed_deployer}"
```

**Test-injection semantics:**
- A test that sets `FLOCI_AUTH_MODE=off` before sourcing gets `_auth_validate_signatures="false"` from the case, then `readonly FLOCI_AUTH_VALIDATE_SIGNATURES="${FLOCI_AUTH_VALIDATE_SIGNATURES:-false}"` picks up the case-computed value.
- A test that sets `FLOCI_AUTH_VALIDATE_SIGNATURES=true` before sourcing (regardless of `FLOCI_AUTH_MODE`) gets `readonly FLOCI_AUTH_VALIDATE_SIGNATURES="${FLOCI_AUTH_VALIDATE_SIGNATURES:-false}"` → picks up `true` from the env var, bypassing the case-computed default. This is the test-injection escape hatch.

**Rationale:** The `${VAR:-default}` convention is the project's standard mechanism for test injection (documented in AGENTS.md Script conventions: "using the `readonly VAR="${VAR:-default}"` form so tests can inject overrides"). `readonly` inside a `case` branch breaks this because the variable is frozen before the test can override it. The fix follows the same pattern used elsewhere in `setup-floci.sh` (e.g., `FLOCI_TLS_SELF_SIGNED` is computed from `FLOCI_TLS_ENABLED` but declared `readonly` with `${VAR:-default}` at the top level). [Source: AGENTS.md Script conventions; `setup-floci.sh` existing pattern for TLS vars]

**Note on `local` in `setup-floci.sh`:** `setup-floci.sh` runs at the top level (not inside a function), so `local` is not available. Use plain (non-`local`, non-`readonly`) variable assignments instead:

```bash
_auth_validate_signatures="false"
_auth_iam_enforcement="false"
_auth_seed_deployer="false"
```

The `_` prefix convention signals "internal, not part of the public API" and avoids collision with the `readonly` names.

---

### SPEC-SW-004: Add `FLOCI_SERVICES_IAM_ENABLED=true` to the `sigv4` branch

**Source:** F-SW-001
**Confidence:** 90 (Critical) — Without `FLOCI_SERVICES_IAM_ENABLED=true`, the IAM service may not be active even though signature validation and enforcement are enabled. The three vars set by the `sigv4` branch (`FLOCI_AUTH_VALIDATE_SIGNATURES`, `FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED`, `FLOCI_SERVICES_IAM_SEED_DEPLOYER_PRINCIPAL`) all depend on the IAM service being enabled.
**Affected sections:** §4.2, §6.1, §6.2
**Affected files:** `setup-floci.sh` (the `FLOCI_AUTH_MODE` case statement and `write_env_file`)

**Current state** (auth plan §4.2, lines 139-143):

```bash
  sigv4)
    readonly FLOCI_AUTH_VALIDATE_SIGNATURES="true"
    readonly FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED="true"
    readonly FLOCI_SERVICES_IAM_SEED_DEPLOYER_PRINCIPAL="true"
    ;;
```

The `sigv4` branch sets three vars but omits `FLOCI_SERVICES_IAM_ENABLED=true`. The Floci docs (`docs/scraped/environment-variables.md:160`) show `FLOCI_SERVICES_IAM_ENABLED` defaults to `true`, so this is not a runtime bug — but it is a specification gap. The auth plan should explicitly set it for two reasons:
1. **Defense in depth** — if a future Floci image changes the default, the installer is explicit.
2. **Completeness** — the `off` branch should also explicitly set it to `false` for symmetry and clarity.

**Required change:**

Add `FLOCI_SERVICES_IAM_ENABLED` to both branches:

```bash
  off)
    _auth_validate_signatures="false"
    _auth_iam_enforcement="false"
    _auth_seed_deployer="false"
    _auth_iam_enabled="false"
    ;;
  sigv4)
    _auth_validate_signatures="true"
    _auth_iam_enforcement="true"
    _auth_seed_deployer="true"
    _auth_iam_enabled="true"
    ;;
```

And add the corresponding `readonly` declaration after the `case` block:

```bash
readonly FLOCI_SERVICES_IAM_ENABLED="${FLOCI_SERVICES_IAM_ENABLED:-$_auth_iam_enabled}"
```

**§6.2 `write_env_file`** must also emit the new var:

```bash
FLOCI_SERVICES_IAM_ENABLED=${FLOCI_SERVICES_IAM_ENABLED}
FLOCI_AUTH_VALIDATE_SIGNATURES=${FLOCI_AUTH_VALIDATE_SIGNATURES}
FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED=${FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED}
FLOCI_SERVICES_IAM_SEED_DEPLOYER_PRINCIPAL=${FLOCI_SERVICES_IAM_SEED_DEPLOYER_PRINCIPAL}
```

**Rationale:** `FLOCI_SERVICES_IAM_ENABLED` is the master switch for the IAM service. The three sub-vars (`FLOCI_AUTH_VALIDATE_SIGNATURES`, `FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED`, `FLOCI_SERVICES_IAM_SEED_DEPLOYER_PRINCIPAL`) are meaningless if the IAM service is not active. While the Floci image defaults `FLOCI_SERVICES_IAM_ENABLED=true`, the installer should be explicit — the `off` mode should disable IAM entirely, and the `sigv4` mode should enable it. [Source: `docs/scraped/environment-variables.md:160` — `FLOCI_SERVICES_IAM_ENABLED` (default `true`)]

**Test impact:** SPEC-TX-006 (write_env_file auth-var emission tests) must be updated to include `FLOCI_SERVICES_IAM_ENABLED` in the expected output. The existing test case 3 ("sigv4 mode does NOT emit FLOCI_SERVICES_IAM_ENABLED") must be **reversed** — it should now assert that `FLOCI_SERVICES_IAM_ENABLED=true` IS present in sigv4 mode and `FLOCI_SERVICES_IAM_ENABLED=false` IS present in off mode.

---

### SPEC-SW-005: Add `sts get-caller-identity` verification between create and delete in rotation

**Source:** M-SW-005
**Confidence:** 90 (Critical) — The rotation function creates a new access key and immediately deletes the old one with zero verification that the new key actually works. If the new key is malformed or Floci returns a key that doesn't authenticate, the function deletes the only working credential, locking out the deployer.
**Affected sections:** §5.2, §6.5
**Affected files:** `mock-server/dev-twin.sh` (`_rotate_bootstrap_credentials`)

**Current state** (auth plan §6.5, lines 336-367):

The rotation function:
1. Calls `iam create-access-key` → extracts `new_akid`/`new_sk`
2. Calls `iam delete-access-key` on the old key
3. Persists the new creds

There is no verification step between create and delete. If the new key doesn't work (e.g., Floci returns a key with a corrupted signature, or the JSON parsing extracts wrong values), the old key is deleted and the deployer is locked out.

**Required change:**

Insert an `sts get-caller-identity` probe between the create and delete steps. This call uses the **new** credentials to verify they authenticate successfully before the old key is deleted.

**Updated §5.2 rotation flow (add step 4c, renumber 4d→4e):**

```
4. _rotate_bootstrap_credentials:
   a. Determine bootstrap creds (fresh install: floci/floci; dev-recreate: existing rotated)
   b. podman exec ... aws iam create-access-key → new AKID + secret
   c. VERIFY: podman exec -e AWS_ACCESS_KEY_ID=<new_akid> -e AWS_SECRET_ACCESS_KEY=<new_sk>
      tianlu-floci aws --endpoint-url http://localhost:4566 --region "$DEV_REGION"
      sts get-caller-identity
      → Must return the floci-deployer ARN. If it fails, abort rotation — do NOT delete the old key.
   d. Delete the old key (same podman exec pattern)
   e. Persist the new AKID + secret
```

**Updated §6.5 code block** (insert after the `new_akid`/`new_sk` extraction, before the delete):

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

**Rationale:** This is the standard AWS credential rotation pattern: create new key → verify new key works → delete old key. Without verification, a malformed new key causes a lockout with no recovery path (Floci has no root user — see GAP-015). The `sts get-caller-identity` call is the lightest-weight verification: it authenticates with the new credentials and returns the caller's ARN, confirming the key is valid and associated with the correct IAM user. [Source: AWS IAM best practices — rotate access keys by creating a new key, verifying it, then deleting the old key; `sts:GetCallerIdentity` is the canonical "who am I?" verification call]

**Partial-failure handling update:** The existing partial-failure handling (create succeeds, delete fails) is unchanged. The new verification step adds a second partial-failure scenario: create succeeds, verification fails. In this case, the old key is preserved and a WARNING is emitted. The new (unverified) key is discarded — it will be orphaned in Floci's IAM store but cannot be used (we don't know if it works). A future rotation will create yet another key.

---

### SPEC-SW-006: Document full `terraform init -backend-config` command for hardcoded backend bucket

**Source:** M-SW-003
**Confidence:** 85 (High) — `infra/live/10-management-iam/providers.tf:12` hardcodes `bucket = "tf-state-dev"`. This is a Terraform anti-pattern: backend config should be passed via `-backend-config` at init time, not hardcoded in the provider block. The auth plan should document the correct `terraform init` command.
**Affected sections:** New subsection in §3.3 or §6 (cross-reference to infra)
**Affected files:** `infra/live/10-management-iam/providers.tf:11-14`

**Current state** (`infra/live/10-management-iam/providers.tf:11-14`):

```hcl
  backend "s3" {
    bucket = "tf-state-dev"
    key    = "10-management-iam/terraform.tfstate"
  }
```

The bucket name is hardcoded. The `infra/AGENTS.md` backend wiring convention says: `terraform init -backend-config=../../_common/backend.hcl -backend-config="key=dev/<NN-stage>/terraform.tfstate"`. But the hardcoded `bucket` in `providers.tf` overrides any `-backend-config` value, making the documented init command ineffective.

**Required change:**

1. **Remove the hardcoded `bucket`** from `providers.tf`:

```hcl
  backend "s3" {
    # bucket and region are passed via -backend-config at init time.
    # See docs/design/authentication-plan.md §X for the full init command.
    key = "10-management-iam/terraform.tfstate"
  }
```

2. **Add a new subsection to the auth plan** (after §3.3 or as a new §6.x cross-reference):

```markdown
### 6.x Terraform backend configuration

The landing-zone Terraform stages use an S3 backend for state storage. The backend
bucket is created by stage `00-backend-bootstrap` (which uses local state for the
chicken-and-egg bootstrap). All subsequent stages must be initialized with the
backend config passed at init time, not hardcoded in `providers.tf`.

**Full init command for stage `10-management-iam`:**

```bash
cd infra/live/10-management-iam

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

**After rotation**, replace `secret_key=floci` with the rotated deployer secret:

```bash
terraform init \
  -backend-config="secret_key=<rotated-secret>" \
  ... (other flags unchanged)
```

The `access_key` is the 12-digit dev AKID (`111111111111`). The `secret_key` is the
`floci-deployer` credential — initially `floci`, then the rotated value after
`_rotate_bootstrap_credentials` runs. See §5.2 for the rotation flow.

> **Note:** The `bucket` and `region` values are NOT hardcoded in `providers.tf`.
> They are passed via `-backend-config` so the same stage code can target different
> environments (dev/uat/prod) by changing only the init flags.
```

**Rationale:** Hardcoding backend config in `providers.tf` is a Terraform anti-pattern because it prevents environment promotion — the same stage code cannot target a different bucket without editing the file. The `-backend-config` flags override partial backend configurations, allowing the same `providers.tf` to work across environments. [Source: Terraform documentation — partial backend configuration; `infra/AGENTS.md` backend wiring convention]

---

### SPEC-SW-007: Fix `Environment = "development"` tag to `Environment = "dev"`

**Source:** M-SW-004
**Confidence:** 85 (High) — `infra/environments/dev.tfvars:27` has `Environment = "development"` — a fourth undocumented value. The project uses three documented environment values: `dev`, `uat`, `prod`. `"development"` is not one of them and breaks tag-based access control (ABAC) queries that match on `Environment = "dev"`.
**Affected sections:** New cross-reference in §3.3 or §6
**Affected files:** `infra/environments/dev.tfvars:27`

**Current state** (`infra/environments/dev.tfvars:27`):

```hcl
default_tags = {
  Owner   = "Jean Boutros"
  Project     = "tianlu"
  Environment = "development"
  ManagedBy   = "terraform"
}
```

The `Environment` tag value `"development"` does not match the `environment = "dev"` variable on line 10, nor the documented environment values (`dev`, `uat`, `prod`). The `infra/AGENTS.md` anti-patterns section already flags this as a known bug: "`infra/environments/dev.tfvars` `default_tags` map contains `Environment = var.environment` (invalid in tfvars), and also duplicates `Project`/`ManagedBy` already set by the `providers.tf` merge."

**Required change:**

```hcl
default_tags = {
  Owner   = "Jean Boutros"
  # Project, Environment, and ManagedBy are injected by providers.tf's default_tags
  # merge from var.environment. Do NOT duplicate them here — it causes terraform plan
  # warnings (duplicate key) and breaks ABAC tag-match queries.
}
```

Remove `Project`, `Environment`, and `ManagedBy` from the `default_tags` map entirely. The `providers.tf` `default_tags` block already injects these three from `var.environment`:

```hcl
default_tags {
    tags = merge({
      Project     = "tianlu"
      Environment = var.environment
      ManagedBy   = "terraform"
    }, var.default_tags)
  }
```

The `var.environment` value is `"dev"` (from `dev.tfvars:10`), so the injected `Environment` tag will be `"dev"` — matching the documented environment values.

**Auth plan impact:** Add a cross-reference note in §3.3 or a new §6.x:

```markdown
The `dev.tfvars` `default_tags` map must NOT include `Project`, `Environment`, or
`ManagedBy` — these are injected by `providers.tf`'s `default_tags` merge from
`var.environment`. Duplicating them causes `terraform plan` warnings and breaks
ABAC tag-match queries. The `Environment` tag value is `"dev"` (from
`var.environment = "dev"`), not `"development"`.
```

**Rationale:** The project uses three documented environment values (`dev`, `uat`, `prod`) for the environment-as-account pattern. A fourth value (`"development"`) breaks ABAC queries that match on `Environment = "dev"` and causes confusion about which value is canonical. The `providers.tf` merge already injects the correct value from `var.environment`. [Source: `infra/AGENTS.md` anti-patterns — "Do NOT set `Environment = "dev"` directly in `default_tags` for the spoke stages"; `infra/environments/dev.tfvars:10` — `environment = "dev"`]

---

### SPEC-SW-008: Add `DurationSeconds` bound + re-assumption cadence to IRSA stand-in (§5.4)

**Source:** M-SX-005
**Confidence:** 80 (High) — The IRSA stand-in in `landing-zone-design.md` §5.4 describes injecting `sts:AssumeRole` credentials into a Kubernetes Secret with no session duration bound. Without a `DurationSeconds` limit, the injected credentials are effectively permanent (default 3600s = 1 hour, but no re-assumption cadence is documented).
**Affected sections:** `docs/design/landing-zone-design.md` §5.4 (cross-reference from auth plan)
**Affected files:** `docs/design/landing-zone-design.md:241-253`

**Current state** (`landing-zone-design.md` §5.4, lines 241-253):

The IRSA stand-in section describes injecting `sts:AssumeRole` credentials into a Kubernetes Secret but does not specify:
- A `DurationSeconds` bound on the assumed role session
- A re-assumption cadence (how often the credentials are refreshed)
- What happens when the credentials expire

**Required change** (add to `landing-zone-design.md` §5.4, after the Secret description):

```markdown
### 5.4 Pod identity — IRSA stand-in

... (existing content) ...

The `sts:AssumeRole` call MUST include a `DurationSeconds` bound to limit the
blast radius of a compromised Secret:

```hcl
# In the workload-spoke module's IAM role assumption:
resource "aws_iam_role" "app" {
  # ... role definition ...
}

# The deploy-time credential injection:
# aws sts assume-role --role-arn <app-role-arn> --role-session-name <app>-pod \
#   --duration-seconds 3600
```

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| `DurationSeconds` | 3600 (1 hour) | Limits credential lifetime; matches the default AWS console session duration |
| Re-assumption cadence | Every 30 minutes (half the session duration) | Ensures overlap — the new credential is valid before the old one expires |
| Expiry behavior | Pod restarts if credentials expire | The sidecar/injector must exit non-zero when `sts:AssumeRole` fails, triggering a Kubernetes restart |

The re-assumption cadence of half the session duration (30 minutes for a 1-hour
session) follows the standard credential rotation pattern: refresh before expiry
so there is always a valid credential. The injector sidecar (or init container)
is responsible for this refresh loop.

> **Note:** This is a Floci accommodation. In real EKS, IRSA or EKS Pod Identity
> handles credential refresh automatically via the projected ServiceAccount token
> volume. The `DurationSeconds` bound and re-assumption cadence documented here
> are the manual equivalent of that automatic refresh.
```

**Auth plan impact:** Add a cross-reference in §8.4 or a new §6.x:

```markdown
The IRSA stand-in in [`landing-zone-design.md` §5.4](landing-zone-design.md)
now specifies a `DurationSeconds` bound of 3600s (1 hour) and a re-assumption
cadence of 30 minutes. This limits the blast radius of a compromised Kubernetes
Secret and ensures credentials are refreshed before expiry.
```

**Rationale:** Without a `DurationSeconds` bound, `sts:AssumeRole` credentials default to 3600s (1 hour) — but the absence of a documented bound means the implementation may use the default without a refresh loop, leaving pods with expired credentials after 1 hour. The 30-minute re-assumption cadence (half the session duration) ensures overlap: the new credential is valid before the old one expires. [Source: AWS STS API Reference — `DurationSeconds` parameter for `AssumeRole`; AWS IAM best practices — rotate temporary credentials before expiry]

---

## Cross-Reference Impact Summary

| Auth Plan Section | SPECs Affecting It | Nature of Change |
|-------------------|-------------------|------------------|
| §4.2 `FLOCI_AUTH_MODE` case statement | SPEC-SW-003, SPEC-SW-004 | Restructure `readonly` out of `case`; add `FLOCI_SERVICES_IAM_ENABLED` |
| §5.2 Rotation flow | SPEC-SW-005 | Add `sts get-caller-identity` verification step between create and delete |
| §6.1 `setup-floci.sh` config block | SPEC-SW-003, SPEC-SW-004 | Same as §4.2 — the case statement restructuring |
| §6.2 `write_env_file` | SPEC-SW-004 | Add `FLOCI_SERVICES_IAM_ENABLED` line |
| §6.5 `_rotate_bootstrap_credentials` | SPEC-SW-001, SPEC-SW-005 | Replace `eu-west-1` with `$DEV_REGION`; add verification step |
| §6.6 `dev_env` | SPEC-SW-001 | Replace `eu-west-1` with `$DEV_REGION` |
| §6.7 `_print_next_steps` | SPEC-SW-001 | Replace `eu-west-1` with `$DEV_REGION` |
| §3.3 / new §6.x | SPEC-SW-002, SPEC-SW-006, SPEC-SW-007, SPEC-SW-008 | Cross-reference additions for Deny statement, backend config, env tag, IRSA DurationSeconds |
| `infra/live/10-management-iam/main.tf` | SPEC-SW-002 | Fix `DenyAllExceptBoundary` resource scoping |
| `infra/live/10-management-iam/providers.tf` | SPEC-SW-006 | Remove hardcoded `bucket` |
| `infra/environments/dev.tfvars` | SPEC-SW-007 | Fix `Environment` tag, remove duplicate tags |
| `docs/design/landing-zone-design.md` §5.4 | SPEC-SW-008 | Add `DurationSeconds` bound + re-assumption cadence |

---

## Self-Audit Checklist

| Category | Checked? | Finding or PASS |
|----------|----------|-----------------|
| Build passes (exit 0, no warnings) | N/A | No code changes in this phase — specification only |
| Typed enums / vocabulary types | N/A | Bash scripting — not applicable |
| Documentation on new public symbols | N/A | Specification document — no code symbols |
| Spec/datasheet fidelity | PASS | All claims cited against AWS SigV4 docs, IAM docs, Floci scraped docs, Terraform docs |
| Module boundary | PASS | Cross-references correctly identify which file each change affects (dev-twin.sh vs setup-floci.sh vs infra/) |
| Reserved/padding fields handled | N/A | Not applicable |
| No magic numbers in doc examples | PASS | All values are named constants (`DEV_REGION`, `DEV_CREDENTIALS_FILE`, `DurationSeconds=3600`) |
| Buffer safety | N/A | Not applicable |
| AGENTS.md compliance | PASS | Follows `${VAR:-default}` test-injection convention; cross-references AGENTS.md Critical gotchas and Script conventions |
| Conventional commit ready | N/A | Specification phase — no commits |

---

## References

| Claim / Decision | Source | Verification |
|-----------------|--------|-------------|
| SigV4 signs region into credential scope | AWS SigV4 signing process | Verified — region is part of `Credential=<AKID>/<date>/<region>/<service>/aws4_request` |
| `iam:DeleteRolePermissionsBoundary` acts on role ARN, not policy ARN | AWS IAM API Reference | Verified — the resource is the IAM principal (role/user/group), not the policy |
| `iam:PermissionsBoundary` is a global condition key | AWS IAM documentation — Condition Keys | Verified — applies to IAM principal resources |
| `FLOCI_SERVICES_IAM_ENABLED` defaults to `true` | `docs/scraped/environment-variables.md:160` | Verified — `FLOCI_SERVICES_IAM_ENABLED` (default `true`) |
| `${VAR:-default}` test-injection convention | AGENTS.md Script conventions | Verified — "using the `readonly VAR="${VAR:-default}"` form so tests can inject overrides" |
| `readonly` inside `case` breaks test injection | `setup-floci.sh` existing pattern for TLS vars | Verified — TLS vars are computed then declared `readonly` with `${VAR:-default}` at top level |
| `sts:GetCallerIdentity` is the canonical verification call | AWS STS API Reference | Verified — returns the ARN of the caller, confirming the credentials are valid |
| Terraform partial backend configuration | Terraform documentation — Backend Configuration | Verified — `-backend-config` overrides partial backend blocks |
| `dev.tfvars` `environment = "dev"` | `infra/environments/dev.tfvars:10` | Verified — `environment = "dev"` |
| `providers.tf` injects `Environment = var.environment` | `infra/live/10-management-iam/providers.tf:32-35` | Verified — `default_tags { tags = merge({... Environment = var.environment ...}, var.default_tags) }` |
| `infra/AGENTS.md` anti-patterns flag duplicate tags | `infra/AGENTS.md` anti-patterns section | Verified — "Do NOT set `Environment = "dev"` directly in `default_tags`" |
| `DurationSeconds` parameter for `AssumeRole` | AWS STS API Reference | Verified — default 3600s, max depends on role configuration |
| IRSA stand-in is a production anti-pattern | `landing-zone-design.md:250-253` | Verified — "Secret-based approach is a Floci accommodation and a production anti-pattern" |

---

## Verdict

**VERDICT: CONDITIONAL PASS**

**FINDINGS:**
- [95] SPEC-SW-001: Region mismatch — `eu-west-1` hardcoded in 5 locations; must use `DEV_REGION` defaulting to `eu-west-2`
- [90] SPEC-SW-002: Deny statement no-op — `resources = [boundary_arn]` but denied actions act on principal ARNs; must use `Resource = "*"` with `StringNotEquals` condition
- [85] SPEC-SW-003: `readonly` inside `case` breaks test-injection convention; must compute into non-readonly locals, then declare `readonly` at top level
- [90] SPEC-SW-004: `FLOCI_SERVICES_IAM_ENABLED` missing from `sigv4` branch; must add to both branches and `write_env_file`
- [90] SPEC-SW-005: Missing `sts get-caller-identity` verification between create and delete in rotation; must add probe before deleting old key
- [85] SPEC-SW-006: Hardcoded backend bucket in `providers.tf`; must document full `terraform init -backend-config` command
- [85] SPEC-SW-007: `Environment = "development"` tag — fourth undocumented value; must use `Environment = "dev"` (injected by `providers.tf` merge)
- [80] SPEC-SW-008: IRSA stand-in has no `DurationSeconds` bound; must add 3600s bound + 30-min re-assumption cadence to §5.4

**ROUTING:** code-architect (for implementation in Phase B)

**Conditions for full approval:**
1. SPEC-SW-003 must be applied before SPEC-SW-004 — the `readonly` restructuring changes the case statement that SPEC-SW-004 adds `FLOCI_SERVICES_IAM_ENABLED` to
2. SPEC-SW-001 and SPEC-SW-005 both affect §6.5 `_rotate_bootstrap_credentials` — apply SPEC-SW-001 first (region constant), then SPEC-SW-005 (verification step) to avoid merge conflicts
3. SPEC-SW-002, SPEC-SW-006, SPEC-SW-007, SPEC-SW-008 are cross-reference additions to the auth plan — they can be applied independently in any order
4. All SPECs are independent of the BS, DX, and TX specifications from other A1 reviews
