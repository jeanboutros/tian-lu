# Findings — Authentication Plan and Landing-Zone Implementation Review

| Field | Value |
|-------|-------|
| Document | `docs/design/authentication-plan-findings.md` |
| Reviews | [`authentication-plan.md`](authentication-plan.md), [`landing-zone-design.md`](landing-zone-design.md), and the code implementing both |
| Created | 2026-07-30 |
| Branch | `feature/create-base-infra` |
| Findings | 15 open (25 retired as resolved — see §1.1) |
| Predecessor | [`psc-adv-0017-challenge-review.md`](../project-management/advisories/psc-adv-0017-challenge-review.md) |
| Status | The account-root auth redesign resolved 25 findings; 15 remain open (§5). |

## 1. Purpose

This document records a validation pass over the authentication plan, the landing-zone design, and
the code that implements them. It answers three questions:

1. Does the implementation match the plan?
2. Is the plan hardened enough to be implemented as written?
3. Does either drift from established best practice?

Each finding states what was observed, what it means for the system, and the proposed change.

## 1.1 Retired findings

The following were resolved by the account-root authentication redesign (environment = account by
12-digit AKID, deployment as account root, a per-env generated secret, `floci-deployer` seeded but
unused, and the signature-validation bug documented as an upstream issue). The design now lives in the
design docs; the code and tests were updated to match. Git history preserves the retired findings'
full text.

| Retired | Resolution |
| --- | --- |
| F-01 | Signatures not verified — documented as an upstream bug ([`docs/issues/`](../issues/floci-signature-validation-ignored.md), GAP-017); IAM reclassified "target state" in the design docs. |
| F-02, F-03 | Environment = account by 12-digit AKID; deployment runs as account root; `access_key = var.account_id`. `authentication-plan.md` §3. |
| F-04, F-27, F-29, F-30, F-39, F-40 | Rotation machinery retired; the dev twin uses a per-env generated secret + a project-local AWS profile (Option C). |
| F-15 | Backend-secret leak removed; the per-env account secret is sourced from the environment. `landing-zone-design.md` §10.1. |
| F-18, F-38 | `backend-<env>.hcl` naming aligned across docs; stray files removed. |
| F-19 | `data.aws_caller_identity` postcondition added to the provider; the "never hardcoded" claim corrected. |
| F-20–F-26 | Wrapper rewritten as `infra/stage.sh` (4 envs, env-derived var-file/backend, stage discovery, re-runnable init, plan/destroy). Covered by `tests/stage_wrapper.bats`. |
| F-28 | `print_summary` branches on the auth mode. |
| F-32 | Region unified to `eu-west-2`. |
| F-35, F-36, F-37 | Auth-plan corrections folded into the rewritten `authentication-plan.md`. |

## 2. Scope — artifacts reviewed (open findings)

| Artifact | Findings |
|----------|----------|
| `docs/design/landing-zone-design.md` | F-06, F-07, F-12, F-13 |
| `scripts/preflight-floci.sh` | F-05 |
| `infra/live/10-management-iam/main.tf` | F-06, F-07, F-08, F-09, F-10, F-11, F-12 |
| `infra/live/10-management-iam/providers.tf`, `versions.tf` | F-13, F-17 |
| `infra/live/00-backend-bootstrap/main.tf` | F-13, F-16 |
| `infra/_common/providers.tf`, `versions.tf` | F-13, F-14 |
| `infra/environments/dev.tfvars` | F-17 |
| `mock-server/run-test.sh`, `mock-server/in-vm/run-in-vm.sh` | F-31 |
| `tests/*.bats`, `mock-server/tests/*.bats` | F-33, F-34 |

Retired findings and where their design now lives are in §1.1.

## 3. Method and evidence classes

Every finding carries one of three evidence classes. Nothing is recorded on inspection alone unless
it is a plain textual contradiction between two files.

| Class | Meaning |
|-------|---------|
| **Verified** | Reproduced by running a command. The command and its output were captured. |
| **Cited** | Settled against a primary source (AWS documentation, HashiCorp documentation, Floci's own scraped docs) with the relevant sentence quoted. |
| **Observed** | A textual contradiction between two artifacts in this repository, established by reading both. |

Findings were validated independently: the IAM-semantics group, the Terraform-backend group, the
bash-defect group, and the wrapper-script group were each validated by a separate agent working from
a written claim list, instructed to test or cite rather than reason. The Terraform-stage group was
validated directly. Where a validator contradicted the original claim, the finding below records the
corrected version — three claims were narrowed or corrected this way (F-25, F-26, F-32).

Finding IDs are stable and match the review they were first reported in. They are arranged by
subject rather than by number, so document order is not numeric order: **F-39** sits with the other
`dev-twin.sh` defects in Group E, and **F-40** with the other plan corrections in Group F. Use the
scope table above, or the remediation order in §6, to navigate.

Claims that were investigated and **not** recorded as findings, so they are not re-litigated:
`_creds_replace_block` (`dev-twin.sh:865-876`) is correct and covered by seven passing tests;
`dev_recreate` does call `_print_next_steps`; the installer's `FLOCI_SERVICES_IAM_ENABLED` default of
`true` matches `docs/scraped/environment-variables.md:160`; `sed -i.bak` on a missing file exits 1 on
macOS but is `set -e`-exempt in an `&&` list, so `dev_env`'s use of it is safe as written; and
passing `-var-file` to `terraform init` is accepted silently rather than being an error.

## 4. Live-platform probe

Five findings depend on one experiment, recorded here once. The running `floci-dev` Lima instance
has this configuration in `/home/floci/.config/floci/floci.env`:

```ini
FLOCI_AUTH_MODE=sigv4
FLOCI_AUTH_VALIDATE_SIGNATURES=true
FLOCI_SERVICES_IAM_ENABLED=true
FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED=true
FLOCI_SERVICES_IAM_SEED_DEPLOYER_PRINCIPAL=true
FLOCI_DEFAULT_REGION=eu-west-2
FLOCI_DEFAULT_ACCOUNT_ID=000000000000
```

That is the exact posture the plan calls the "only meaningful secure configuration"
([§4.1](authentication-plan.md)). Against it, read-only:

| Credential | Call | Result |
|------------|------|--------|
| `111111111111` / `definitely-not-the-right-secret` | `sts get-caller-identity` | `arn:aws:iam::111111111111:root` |
| `111111111111` / `x` | `sts get-caller-identity` | `arn:aws:iam::111111111111:root` |
| `floci` / `floci` | `sts get-caller-identity` | `arn:aws:iam::000000000000:user/floci-deployer` |
| `floci` / `wrong-secret-here` | `sts get-caller-identity` | `arn:aws:iam::000000000000:user/floci-deployer` |
| `floci` / `nope` | `iam list-users` | succeeds — returns `floci-deployer` |
| `floci` / `nope` | `iam get-user --user-name floci-deployer` | succeeds |
| `AKIANOTAREALKEY` / `junk` | `sts get-caller-identity` | `arn:aws:iam::000000000000:root` |
| `111111111111` / `any` | `iam list-users` | `{"Users": []}` |
| `floci` / `floci` | `iam list-users` | returns `floci-deployer` |

Three facts follow, and they are the substance of F-01 through F-03:

1. A wrong secret authenticates successfully — on STS **and** on IAM service calls — with
   `FLOCI_AUTH_VALIDATE_SIGNATURES=true`.
2. `floci-deployer` exists in account `000000000000`, not in `111111111111`. Account
   `111111111111` contains no IAM users at all.
3. A 12-digit Access Key ID authenticates as that account's **root** principal.

Account *isolation* is genuine — the two AKIDs see disjoint user lists. It is signature
*verification* and principal *identity* that do not behave as the design assumes.

## 5. Findings

Severity scale: **Blocking** — the described control does not exist, or the stage cannot run.
**High** — silent incorrect behaviour, or a documented instruction that fails. **Medium** — drift
that will produce a wrong result under a foreseeable change. **Low** — hygiene and consistency.

---

### Group A — The auth model's premise does not hold on the platform

#### F-05 · Pre-flight G1 cannot detect F-01 to F-03, and names the wrong variable

**Severity** High · **Location** `scripts/preflight-floci.sh:35`, `:42-59`;
`docs/design/landing-zone-design.md:437` · **Evidence** Verified (§4 probe) + Observed

**What it means.** Three separate problems in the one gate the design calls a hard stop.

1. **It tests the wrong variable to its own message.** The gate asserts that a no-policy user is
   denied a privileged call — that is `FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED`. Its failure text says
   "Set `FLOCI_AUTH_VALIDATE_SIGNATURES=true`". An operator following that instruction would not make
   the gate pass. `landing-zone-design.md:437` describes the gate as covering both flags; the code
   covers one.
2. **Its probe changes accounts mid-gate.** `aws_admin` uses AKID `111111111111`, so the throwaway
   user is created in account `111111111111`. The minted access key is a non-12-digit AKID, so when
   the gate then uses it, the call resolves to `FLOCI_DEFAULT_ACCOUNT_ID` — account `000000000000`.
   The deny-or-allow observed is therefore not evidence about policy enforcement.
3. **It cannot see the root bypass.** Nothing in the gate exercises the credential Terraform actually
   uses, so the gate can pass while every apply runs as account root (F-03).

**Proposed change.**

- Correct the failure message to name `FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED`, and rename the gate
  from "signature validation" to "IAM authorization enforcement" so the label matches the assertion.
- Add **G0** (per F-01): a known AKID with a deliberately wrong secret must be rejected. This is the
  gate that would have caught F-01 on day one.
- Add **G0b**: assert that the credential the Terraform provider will use is not the account root
  principal — `sts get-caller-identity` with `access_key = account_id` must not return an ARN ending
  in `:root`.
- Make the account resolution explicit in G1: after minting the probe key, call
  `sts get-caller-identity` with it and assert the returned `Account` equals the account the user was
  created in. If it does not, the gate must report that it cannot measure enforcement rather than
  reporting a pass or a fail.
- Replace the `grep`/`sed` JSON extraction at `:49-50` with `jq`, matching `dev-twin.sh`, and apply
  F-27's `// empty` guard.

#### F-06 · Stage `10-management-iam` cannot plan or apply

**Severity** Blocking · **Location** `infra/live/10-management-iam/main.tf:28`, `:67`, `:79` ·
**Evidence** Verified — `terraform validate` fails with three errors

```
Error: Reference to undeclared resource
  on main.tf line 28, in data "aws_iam_policy_document" "platform_admin":
  28:         aws_iam_policy.general_app_boundary.arn,
A managed resource "aws_iam_policy" "general_app_boundary" has not been declared in the root module.
```

**What it means.** `aws_iam_policy.general_app_boundary` is referenced three times. The stage declares
`data "aws_iam_policy_document" "general_app_boundary"` (the *document*) and
`resource "aws_iam_policy" "platform_admin"` (a different *policy*), but never the boundary policy
resource. The permissions boundary is the object `landing-zone-design.md` §5.2 makes the maximum-permissions
ceiling for every application role; it does not exist. `landing-zone-design.md:129-133` reports this
stage as implemented.

**Proposed change.** Declare the missing resource and consume the existing document:

```hcl
resource "aws_iam_policy" "general_app_boundary" {
  name        = "general_app_boundary"
  path        = "/"
  description = "Maximum permissions any application role may hold (landing-zone-design.md §5.2)."
  policy      = data.aws_iam_policy_document.general_app_boundary.json
}
```

Fix F-11 in the same change, or the policy will be rejected at apply. Then add
`terraform validate` for every stage under `infra/live/` to `make lint` — a three-reference undeclared
resource surviving into a stage described as implemented means nothing validates this tree in CI.

#### F-07 · No IAM principal is declared anywhere in `infra/`

**Severity** Blocking · **Location** `infra/live/10-management-iam/main.tf`;
`docs/design/landing-zone-design.md:214-222` (§5.1) · **Evidence** Verified — no `aws_iam_user`,
`aws_iam_role`, `aws_iam_group`, or `permissions_boundary` argument in any `.tf` file

**What it means.** §5.1 describes `platform-admin` as "an assumable administrative identity (group +
user + role)". The stage creates one `aws_iam_policy` and nothing to attach it to. There is no
principal, so nothing is bounded, nothing assumes anything, and the escalation ceiling has no
subject. Consequently F-08's escalation is unmitigated: a permissions boundary on `platform-admin`
would be the mitigation, and none is attached because there is nothing to attach it to.

**Proposed change.** Complete the stage: declare `aws_iam_user.platform_admin` (or a role, if the
assume-role flow is the intent), attach `aws_iam_policy.platform_admin`, and set
`permissions_boundary` on it — to a *second* boundary policy, per F-12, not to
`general_app_boundary`. Add an output for the principal ARN so downstream stages can reference it.
Until the principal exists, change `landing-zone-design.md:129-133` to describe stage 10 as partially
implemented and name what is missing; a reader currently cannot tell that the identity is absent.

---

### Group B — The delegated-administration policy

The policy document at `infra/live/10-management-iam/main.tf:5-88` is the enforcement mechanism for
§5.1's escalation ceiling. Five findings, all validated against AWS documentation.

#### F-08 · Unconditional `iam:Attach*` and `iam:PassRole` on `*` permit privilege escalation

**Severity** Blocking · **Location** `infra/live/10-management-iam/main.tf:34-47` ·
**Evidence** Cited — AWS IAM User Guide

**What it means.** The statement `AllowAllOtherNonMutatingActions` allows `iam:Get*`, `iam:List*`,
`iam:PassRole`, `iam:Tag*`, `iam:Attach*`, `iam:Detach*` on `Resource: "*"` with no condition.
`iam:Attach*` matches `AttachUserPolicy`, `AttachRolePolicy`, and `AttachGroupPolicy`, so the holder
can attach `AdministratorAccess` to itself or to any principal in one API call. The two Deny
statements do not stop it — they cover only boundary removal and mutation of the boundary policy. The
escalation ceiling §5.1 claims is therefore absent, and F-07 means no permissions boundary caps the
holder either.

AWS's own delegated-administration policy places this action *inside* the boundary-conditioned
statement:

> `"Sid": "CreateOrChangeOnlyWithBoundary", "Effect": "Allow", "Action": [ "iam:AttachUserPolicy", "iam:CreateUser", … ], "Condition": { "StringEquals": { "iam:PermissionsBoundary": "arn:aws:iam::123456789012:policy/XCompanyBoundaries" } }`
> — [Permissions boundaries for IAM entities](https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies_boundaries.html)

`iam:PassRole` on `*` is separately flagged by IAM Access Analyzer as a `SECURITY_WARNING`:

> "Pass role with star in resource: Using the `iam:PassRole` action with wildcards (\*) in the
> resource can be overly permissive… We recommend that you specify resource ARNs or add the
> `iam:PassedToService` condition key to your statement."
> — [Access Analyzer policy checks](https://docs.aws.amazon.com/IAM/latest/UserGuide/access-analyzer-reference-policy-checks.html)

The statement name is also false. `Attach*`, `Detach*`, and `Tag*` are all write operations, so the
highest-privilege statement in the file carries a read-only label — the kind of naming that survives
review because the name is read instead of the actions.

**Proposed change.** Split the statement by whether the action mutates permissions.

```hcl
statement {
  sid       = "AllowReadOnlyIAM"
  actions   = ["iam:Get*", "iam:List*"]
  resources = ["*"]
}

# Attaching and detaching policies changes effective permissions, so it is gated on the
# boundary exactly as principal creation is (AWS: CreateOrChangeOnlyWithBoundary).
statement {
  sid     = "AttachOnlyToBoundedPrincipals"
  actions = ["iam:AttachUserPolicy", "iam:AttachRolePolicy",
             "iam:DetachUserPolicy", "iam:DetachRolePolicy",
             "iam:PutUserPolicy", "iam:PutRolePolicy"]
  resources = ["*"]
  condition {
    test     = "StringEquals"
    variable = "iam:PermissionsBoundary"
    values   = [aws_iam_policy.general_app_boundary.arn]
  }
}

# Scope PassRole to the roles this estate mints, and pin the consuming service.
statement {
  sid       = "PassOnlyEstateRoles"
  actions   = ["iam:PassRole"]
  resources = ["arn:aws:iam::${var.account_id}:role/app-*"]
  condition {
    test     = "StringEquals"
    variable = "iam:PassedToService"
    values   = ["eks.amazonaws.com", "rds.amazonaws.com"]
  }
}

statement {
  sid       = "AllowTagging"
  actions   = ["iam:Tag*", "iam:Untag*"]
  resources = ["*"]
}
```

Note the `iam:PermissionsBoundary` condition on `Attach*`/`Put*Policy` is only meaningful because
those requests act on a principal that already has a boundary; verify against F-09's citation before
relying on it, and if the key proves absent for `Attach*`, scope by resource ARN prefix instead.

#### F-09 · Three Allow statements are unreachable

**Severity** High · **Location** `infra/live/10-management-iam/main.tf:6-31` ·
**Evidence** Cited — AWS IAM User Guide

**What it means.** `MintPrincipalsOnlyWithBoundary` gates `iam:CreateUser`, `iam:CreateRole`,
`iam:CreateGroup`, `iam:CreatePolicy`, `iam:CreatePolicyVersion`, and the three
`Put*PermissionsBoundary` actions on `StringEquals` against `iam:PermissionsBoundary`. That condition
key can only be populated by a request that carries a boundary ARN for a principal.
`CreateGroup` (parameters: `GroupName`, `Path`) and `CreatePolicy` (parameters: `Description`, `Path`,
`PolicyDocument`, `PolicyName`, `Tags`) have no such parameter, so the key is always absent for them.

> "When you use a variable with no value in the condition element of an IAM policy, IAM JSON policy
> elements: Condition operators like `StringEquals` or `StringLike` **do not match, and the policy
> statement does not take effect**."
> — [IAM policy elements: variables](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_variables.html)

`MintPrincipalsOnlyWithBoundary` is the only statement granting `iam:CreatePolicy`, so
`platform-admin` receives an implicit deny on it. The delegated administrator cannot create the
per-application least-privilege policies §5.3 requires — it cannot do its primary job. This surfaces
only at runtime as `not authorized to perform: iam:CreatePolicy`; `terraform apply` reports success.
`iam:CreatePolicyVersion` is doubly unusable: dead here, and explicitly denied on the boundary ARN by
`DenyBoundaryPolicyMutation` at `:74-80`.

AWS's reference policy puts these actions in a statement with no boundary condition, using
`NotResource` to protect the delegator instead.

**Proposed change.** Move `iam:CreateGroup`, `iam:CreatePolicy`, and `iam:CreatePolicyVersion` out of
the conditioned statement into an unconditioned Allow, keeping `DenyBoundaryPolicyMutation` as the
guard on the boundary policy itself:

```hcl
statement {
  sid     = "MintPrincipalsOnlyWithBoundary"
  actions = ["iam:CreateUser", "iam:CreateRole",
             "iam:PutUserPermissionsBoundary", "iam:PutRolePermissionsBoundary"]
  resources = ["*"]
  condition {
    test     = "StringEquals"
    variable = "iam:PermissionsBoundary"
    values   = [aws_iam_policy.general_app_boundary.arn]
  }
}

# iam:PermissionsBoundary is absent from these request contexts, so a positive operator would
# never match. The boundary policy itself is protected by DenyBoundaryPolicyMutation below.
statement {
  sid       = "ManagePoliciesAndGroups"
  actions   = ["iam:CreateGroup", "iam:CreatePolicy", "iam:CreatePolicyVersion",
               "iam:DeleteGroup", "iam:ListPolicyVersions"]
  resources = ["*"]
}
```

Add a comment naming the absent-key rule at every `iam:PermissionsBoundary` condition in the file.
This is the third time this rule has produced a finding in this repository (`gaps-register.md` LL-002
records the previous two); a comment at each site is cheaper than rediscovering it.

#### F-10 · `iam:PutGroupPermissionsBoundary` is not a real IAM action

**Severity** Medium · **Location** `infra/live/10-management-iam/main.tf:16`;
`docs/design/authentication-plan.md:886` · **Evidence** Cited — AWS IAM API Reference

**What it means.** Permissions boundaries apply to users and roles only:

> "AWS supports *permissions boundaries* for IAM **entities (users or roles)**."
> — [Permissions boundaries for IAM entities](https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies_boundaries.html)

The IAM API exposes exactly four boundary actions — `PutUserPermissionsBoundary`,
`PutRolePermissionsBoundary`, `DeleteUserPermissionsBoundary`, `DeleteRolePermissionsBoundary`. There
is no group variant, and `CreateGroup` has no `PermissionsBoundary` parameter. AWS accepts invalid
actions rather than rejecting the document:

> "Invalid actions do not affect the permissions granted by the policy."
> — [Access Analyzer policy checks](https://docs.aws.amazon.com/IAM/latest/UserGuide/access-analyzer-reference-policy-checks.html)

So `terraform apply` succeeds and the line grants nothing. Its cost is that it reads as coverage of
group boundaries — coverage that is architecturally impossible — which can lead a reviewer to believe
groups are bounded when no such control exists. The same non-action appears as
`iam:DeleteGroupPermissionsBoundary` in authentication-plan Appendix A.1.

**Proposed change.** Delete `iam:PutGroupPermissionsBoundary` from `main.tf:16` and
`iam:DeleteGroupPermissionsBoundary` from the plan's Appendix A.1 code block. If group-level bounding
is wanted, the only mechanism is to bound each user in the group individually — state that explicitly
in §5.1 rather than implying an API that does not exist. Add `aws accessanalyzer validate-policy` to
the pre-flight or to `make lint`; it would have caught this and F-08's `PassRole` warning
mechanically.

#### F-11 · The boundary policy document omits `Resource` and would be rejected

**Severity** Blocking · **Location** `infra/live/10-management-iam/main.tf:91-103` ·
**Evidence** Verified (rendered) + Cited

Rendering the document standalone produces:

```json
{ "Sid": "1", "Effect": "Allow",
  "Action": ["sts:AssumeRole","s3:*","rds-db:connect","logs:*","glue:*","dynamodb:*"] }
```

No `Resource` element. Terraform validates it — the data source only builds a string — but IAM does
not:

> "The `Resource` element in an IAM policy statement defines the object or objects that the statement
> applies to. **Statements must include either a `Resource` or a `NotResource` element.**"
> — [IAM JSON policy elements: Resource](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_elements_resource.html)

**What it means.** Once F-06 is fixed and the policy is actually created, `CreatePolicy` fails with
`MalformedPolicyDocument`. The failure is latent today only because the resource is never declared —
fixing F-06 alone converts a validate-time error into an apply-time error.

**Proposed change.** Add `resources = ["*"]` to the statement and replace the placeholder sids with
names that say what each statement does:

```hcl
statement {
  sid = "BoundaryCeilingAllow"
  actions = ["rds-db:connect", "s3:*", "dynamodb:*", "glue:*", "logs:*", "sts:AssumeRole"]
  # A permissions boundary is a ceiling, not a grant: "*" is correct here because the
  # effective permission is the intersection with the role's own identity policy (§5.2).
  resources = ["*"]
}

statement {
  sid       = "BoundaryDenyIdentityAndOrgMutation"
  effect    = "Deny"
  actions   = ["iam:*", "organizations:*"]
  resources = ["*"]
}
```

#### F-12 · One boundary policy is doing the work of two

**Severity** High · **Location** `infra/live/10-management-iam/main.tf:90-116`;
`docs/design/landing-zone-design.md:224-229` (§5.2) · **Evidence** Cited — AWS delegation tutorial

**What it means.** `general_app_boundary` denies `iam:*`. That is correct for an *application* role,
which should never touch IAM. But F-07's fix requires a boundary on `platform-admin` itself, and
`platform-admin`'s entire function is IAM administration — bounding it with a policy that denies
`iam:*` would leave it unable to do anything. So the single boundary cannot serve both purposes, and
the design names only one.

AWS's delegation tutorial uses two distinct policies: `DelegatedUserBoundary` bounds the delegated
administrator, and `XCompanyBoundaries` is the boundary that administrator must attach to the
principals it mints. The design has collapsed them.

**Proposed change.** Introduce a second policy, `platform_admin_boundary`, as the boundary attached
to `platform-admin`. It permits the IAM actions the delegated administrator legitimately needs and
denies the escalation paths — deleting boundaries, mutating the application boundary, and attaching
policies to itself outside the boundary condition. Keep `general_app_boundary` as the boundary
`platform-admin` must attach to every application role. Document both in §5.2 with a sentence on why
one policy cannot do both jobs; this is the kind of distinction that gets collapsed again on the next
edit unless the reason is written down.

---

### Group C — Terraform configuration and backend

#### F-13 · Five mutually inconsistent version constraints; the provider has no upper bound

**Severity** Medium · **Location** `infra/_common/versions.tf:10`, `:15`;
`infra/live/10-management-iam/versions.tf:10`, `:15`;
`infra/live/00-backend-bootstrap/main.tf:14`, `:19`;
`docs/design/landing-zone-design.md:141`; `infra/README.md:26`; `infra/AGENTS.md:7`, `:38` ·
**Evidence** Verified + Cited — HashiCorp provider requirements

| Location | Terraform | `hashicorp/aws` |
|---|---|---|
| `_common/versions.tf` | `>= 1.15.8` | `>= 6.56.0` (no ceiling) |
| `live/10-management-iam/versions.tf` | `>= 1.15.8` | `>= 6.56.0` (no ceiling) |
| `live/00-backend-bootstrap/main.tf` | `>= 1.9.0` | `>= 6.56.0` |
| `landing-zone-design.md:141` | `>= 1.9.0` | `>= 5.95, < 7.0` |
| `infra/README.md:26` | `>= 1.9` | — |
| `00-backend-bootstrap/.terraform.lock.hcl` (recorded) | — | `>= 5.95.0, < 7.0.0` |

**What it means.** The lock file still records `>= 5.95.0, < 7.0.0`, exactly the string in the design
document — the document was accurate against an earlier revision and the code moved without it.
`infra/AGENTS.md:38` even warns that the two constraints must be reconciled, which means the drift was
noticed and left in place.

The unbounded provider constraint is a documented best-practice violation for a root module:

> "A module intended to be used as the root of a configuration … should also specify the *maximum*
> provider version it is intended to work with, to avoid accidental upgrades to incompatible new
> versions."
> — [Provider requirements](https://developer.hashicorp.com/terraform/language/providers/requirements)

`_common/versions.tf` is copied *into* root modules (its own header says so) but uses the
reusable-module pattern. Verified: with no lock file and `>= 6.56.0`, `init` selected 6.57.1 — the
newest match. No `7.x` exists yet, so this is latent rather than active.

`required_version = ">= 1.15.8"` admits exactly one released Terraform — 1.15.8, the version
installed on this machine. Verified: `>= 1.15.9` fails with "Unsupported Terraform Core version";
`>= 1.9.0` succeeds. The floor pins the estate to whatever the author happened to have installed.

Separately, `infra/live/10-management-iam/.terraform.lock.hcl` is untracked, against HashiCorp's
guidance to commit it so dependency changes go through review.

**Proposed change.**

- Set one constraint in `_common/versions.tf` and copy it verbatim into every stage:
  `required_version = ">= 1.9.0"` (the floor the docs promise) and
  `version = ">= 6.56.0, < 7.0.0"` for the provider.
- Replace stage 00's inline `terraform` block with the same copied `versions.tf`, so there is one
  source of truth rather than an inline variant.
- Update `landing-zone-design.md:141`, `infra/README.md:26`, and `infra/AGENTS.md:7` to the chosen
  values, and delete the now-resolved reconciliation warning at `infra/AGENTS.md:38`.
- Commit `infra/live/10-management-iam/.terraform.lock.hcl`.
- Add `terraform init -backend=false && terraform validate` per stage to `make lint`, which would
  surface constraint conflicts and F-06 together.

#### F-14 · `dynamodb_table` is deprecated and warns on every `init`

**Severity** Medium · **Location** `infra/_common/backend-dev.hcl:24-27`;
`docs/design/landing-zone-design.md:403-412` (§9) · **Evidence** Verified + Cited

Reproduced on Terraform 1.15.8:

```
Warning: Deprecated Parameter
   6:     dynamodb_table              = "tf-locks-dev"
The parameter "dynamodb_table" is deprecated. Use parameter "use_lockfile" instead.
```

> "State locking is an opt-in feature of the S3 backend. Locking can be enabled via S3 or DynamoDB.
> However, **DynamoDB-based locking is deprecated** and will be removed in a future minor version."
> — [S3 backend](https://developer.hashicorp.com/terraform/language/backend/s3)

**What it means.** Every non-bootstrap stage warns today and will hard-fail on a future 1.x minor.
The comment at `backend-dev.hcl:25` calls `use_lockfile` an alternative "on Terraform >= 1.10"; it
became generally available in 1.11, which is also when `dynamodb_table` was deprecated — so the
comment understates how settled the replacement is. Both may be set simultaneously, deliberately, as
a migration path.

**Proposed change.** Add `use_lockfile = true` alongside `dynamodb_table` and verify S3-native
locking works on Floci — it requires conditional `PutObject` with `If-None-Match: "*"`, which needs a
new pre-flight gate (call it **G3b**, next to the existing DynamoDB gate G3). Once G3b passes, remove
`dynamodb_table` and the `aws_dynamodb_table.tf_locks` resource from stage 00. Until G3b passes, keep
both and change the comment to say that DynamoDB locking is deprecated and retained only until
S3-native locking is verified on this platform. Update landing-zone §9 to match — it currently
presents DynamoDB as the primary mechanism and `use_lockfile` as the alternative, which is now
backwards.

#### F-16 · Stage 00 keeps the unsafe tag-merge order and does not validate `environment`

**Severity** Medium · **Location** `infra/live/00-backend-bootstrap/main.tf:26-28`, `:80-87`, `:96-98` ·
**Evidence** Verified — `terraform console`

```
> merge({Environment="dev"},{Environment="development"})   →  { "Environment" = "development" }
> merge({Environment="development"},{Environment="dev"})    →  { "Environment" = "dev" }
```

**What it means.** Two inconsistencies in one file.

`_common/providers.tf:52-58` and `live/10-management-iam/providers.tf:52-58` use
`merge(var.default_tags, {governance})`, so the governance keys win and cannot be overridden from
tfvars — the fix applied after psc-adv-0002. Stage 00 still uses the reverse,
`merge({governance}, var.default_tags)`, so a `default_tags` entry named `Project`, `Environment`, or
`ManagedBy` in a tfvars file silently overrides governance with no diagnostic. The comment in
`dev.tfvars:26-29` warns readers about exactly this precedence; stage 00 is the one place still
exposed to it.

Stage 00 also declares `variable "environment"` with no `validation` block, while
`_common/providers.tf:10-16` constrains it to `dev`/`uat`/`prod`. Stage 00 derives the state bucket
name from it (`tf-state-${var.environment}` at `:97`) and the lock table likewise, so a typo creates
a divergent bucket that every later stage then fails to find.

**Proposed change.** Reverse the merge to `merge(var.default_tags, { Project, Environment, ManagedBy,
Stage })` and copy the `validation` block from `_common/providers.tf` into stage 00's `environment`
variable. Better: give stage 00 the same copied `providers.tf`/`versions.tf` treatment as every other
stage, with only the `Stage` tag and the local-state comment as stage-specific additions, so the
divergence cannot recur.

#### F-17 · Four undeclared-variable warnings on every stage-10 plan

**Severity** Low · **Location** `infra/environments/dev.tfvars:19-22`;
`infra/live/10-management-iam/` (no `variables.tf`) · **Evidence** Verified — reproduced as a warning,
not an error

```
Warning: Value for undeclared variable
The root module does not declare a variable named "undeclared_one" but a value was found in file …
```

**What it means.** `variables.tf` was deleted from stage 10 and its variables moved into
`providers.tf`. The shared `dev.tfvars` still sets `hub_vpc_cidr`, `cluster_vpc_cidr`,
`alpha_vpc_cidr`, and `beta_vpc_cidr`, which stage 10 does not declare, so every plan and apply emits
four warnings. Stage 00 declares them defensively at `:52-67` with `default = null` precisely to
avoid this; stage 10 does not. Not harmful, but four warnings on every run train the operator to
ignore warning output — which is where F-14's deprecation notice also lands.

**Proposed change.** Either declare the four CIDR variables in the shared `_common/providers.tf` with
`default = null` so every stage accepts the shared tfvars cleanly, or split `dev.tfvars` into a
common file and a network-only file that only the network stages consume. The first is less work and
matches what stage 00 already does; the second is cleaner if the variable set grows.

---

### Group E — Defects in the shipped scripts

#### F-31 · The test twin's `--auth-mode` never reaches the installer

**Severity** High · **Location** `mock-server/in-vm/run-in-vm.sh:20`, `:187`, `:270`, `:353-354`;
`docs/design/authentication-plan.md:592-611` (§6.10) · **Evidence** Verified inside the Lima guest

```
=== T5: run-in-vm.sh FORM (export then sudo bash script) ===
IN-SCRIPT FLOCI_AUTH_MODE=UNSET
=== T6: dev-twin.sh FORM (assignment inside bash -c) ===
IN-SCRIPT FLOCI_AUTH_MODE=sigv4
```

Guest is Ubuntu 26.04 with `sudo-rs`, `/etc/sudoers:9: Defaults env_reset`, and every `env_keep` line
commented out.

**What it means.** `run-in-vm.sh` invokes `sudo bash "$SETUP_SCRIPT"` with no `FLOCI_AUTH_MODE`, so
the installer uses its own default — now `sigv4`. The driver's `AUTH_MODE` defaults to `off` and is
used only to decide whether to add `-e` credential overrides to `podman exec`. So `--auth-mode=off`
produces Floci configured for `sigv4` while the harness talks to it with the container's baked-in
`test`/`test`, and `--auth-mode=sigv4` changes only the client credentials, never the server's
posture. The flag cannot do what §6.10 and §7.3's test matrix say it does, and the default path is
now internally inconsistent.

Exporting the variable would not fix it: with `env_reset` the child environment does not receive it
at all. The inline-assignment-inside-`bash -c` form that `dev-twin.sh:484` already uses is required.

> "By default, the `env_reset` flag is enabled. This causes commands to be executed with a new,
> minimal environment." — `sudoers(5)`

**Proposed change.** Pass the mode the way `dev-twin.sh` does, at both invocation sites:

```bash
  # FLOCI_AUTH_MODE must be assigned INSIDE the sudo'd shell: sudoers' env_reset
  # discards the caller's environment, so an exported variable never arrives.
  sudo bash -c "FLOCI_AUTH_MODE=${AUTH_MODE} bash '${SETUP_SCRIPT}'" 2>&1 \
    | tee "$EVIDENCE_STAGING/run1.log"
```

Add the `SPEC-TX-004` guest-driver cases from plan §6.11 asserting that `FLOCI_AUTH_MODE` appears in
the installer invocation for `sigv4` and not for `off`, and create the missing
`mock-server/tests/run_in_vm.bats` to hold them (F-34). Also add a criterion to `run-in-vm.sh`'s
`CRITERIA` map that reads `FLOCI_AUTH_MODE` back out of the guest's env file and compares it to
`AUTH_MODE` — the harness should verify the posture it requested rather than assume it.

#### F-33 · Two stale skip guards disable eight tests

**Severity** Medium · **Location** `mock-server/tests/completion_protocol.bats:98-99`, `:131-132`,
`:165-166`, `:198-199`, `:232-233`; `tests/preflight.bats:69` · **Evidence** Verified

```
$ /bin/bash -c 'source mock-server/run-test.sh; FINAL=…; NO_SIDECAR=false; REBOOT_TEST=false; validate_summary'
validate_summary exit=0 under bash 3.2
```

**What it means.** Five `completion_protocol.bats` tests skip behind `(( BASH_VERSINFO[0] < 4 ))`
with the reason "validate_summary requires Bash 4 or newer". `run-test.sh:468` and `:497` document
that the function was rewritten to be bash-3.2-compatible — "no `declare -A`", using arrays plus a
`seen_get()` helper — and running it under `/bin/bash` 3.2 confirms it works. The guard is stale, so
the bash-3.2 compatibility work has zero test coverage on macOS, the platform it exists for and the
platform `run-test.sh` runs on.

`tests/preflight.bats:69` skips with "G1 currently calls `skip()` on create-access-key failure —
needs implementation to call `fail()` instead". `scripts/preflight-floci.sh:47` already calls `fail`.
The remediation landed; the test guarding it was never enabled.

Both are the same failure: a skip added as a placeholder, and the placeholder outliving its reason.
A permanently skipped test is worse than a missing one, because the suite reports coverage that does
not exist.

**Proposed change.** Delete all five `BASH_VERSINFO` guards from `completion_protocol.bats` and run
the suite to confirm 124 passing. Rewrite `tests/preflight.bats:69` as a real assertion — with
`STUB_RC_AWS=1`, `gate_g1_signatures` must emit `FAIL`, not `SKIP`, and must set `FAILED=1`. Add a
convention to `tests/AGENTS.md`: a `skip` must name the condition that would make it run, and any
skip whose reason references pending implementation must be converted or deleted when that
implementation lands.

#### F-34 · Plan §6.11's test specification is 14 cases short

**Severity** Medium · **Location** `docs/design/authentication-plan.md:647-736` (§6.11) ·
**Evidence** Verified

| Required by §6.11 | State |
|---|---|
| `tests/phase5.bats` (5 specs) | present, 30 tests |
| `tests/phase6_7.bats` (3 specs) | present, 19 tests, **no auth-mode cases** |
| `tests/preflight.bats` (4 specs) | present, 9 tests |
| `mock-server/tests/dev_twin.bats` (12 specs) | present, 58 tests |
| `mock-server/tests/orchestrator_args.bats` (5 `--auth-mode` specs) | present, 11 tests, **no `--auth-mode` cases** |
| `mock-server/tests/run_in_vm.bats` (9 specs) | **missing entirely** |
| `mock-server/tests/completion_protocol.bats` (2 specs) | present, 12 tests |
| `mock-server/tests/stubs/bin/jq`, `kill` | **missing** |

**What it means.** The `--auth-mode` flag is implemented in `run-test.sh:107-112` and
`run-in-vm.sh:54-59` but is asserted nowhere, so F-31 — the flag having no effect on the installer —
had no test that could have caught it. The three `SPEC-TX-007` `print_summary` cases are likewise
absent, which is why F-28 persists.

**Proposed change.** Create `mock-server/tests/run_in_vm.bats` with the nine `SPEC-TX-004`/`SPEC-TX-010`
cases, add the five `--auth-mode` parsing cases to `orchestrator_args.bats`, and add the three
`SPEC-TX-007` cases to `phase6_7.bats` alongside the F-28 fix. The `jq` stub is not needed — the real
`jq` is a documented prerequisite and the rotation tests already pass with it — so update §6.11 to
drop that requirement rather than adding a stub nothing uses. Add the `kill` stub only with the
`SPEC-TX-013` case that needs it.

## 6. Remediation order

The open findings are not independent. This order avoids redoing work.

| Step | Findings | Why |
|------|----------|-----|
| 1 | F-06, F-11, F-07 | Make stage `10-management-iam` valid, then complete it. F-11 must land with F-06 or apply fails. |
| 2 | F-08, F-09, F-10, F-12 | The delegated-admin policy itself. Pointless before F-07 gives it a subject. |
| 3 | F-05 | Correct pre-flight G1's variable/message and its account-resolution confound. |
| 4 | F-13, F-14, F-16, F-17 | Terraform configuration coherence (version pins, lock migration, stage-00 tag-merge, undeclared vars). Independent of the rest. |
| 5 | F-31, F-33, F-34 | Test-harness gaps: the test-twin `--auth-mode` passing, stale skip guards, and missing auth-mode test cases. |

## 7. Residual open questions

Three things this pass did not settle.

1. **Which account a minted access key resolves to.** F-05 depends on it. Determining it requires
   creating an IAM user, which this pass did not do. The test: create a user in account
   `111111111111`, mint a key, call `sts get-caller-identity` with that key, and compare the returned
   `Account`. If it returns `000000000000`, pre-flight G1 has been measuring cross-account resolution
   rather than policy enforcement for its entire existence.
2. **Whether Floci evaluates permissions boundaries at all.** Assumed throughout landing-zone §5,
   never tested. Needs gate **G6**, which `main.tf:49-51` already carries a comment reserving. Until
   it exists, F-08's fix cannot be verified on this platform — only reviewed against AWS semantics.
3. **Whether Floci's S3 supports conditional `PutObject` with `If-None-Match`.** F-14's migration to
   `use_lockfile` depends on it. Needs gate **G3b** alongside the existing DynamoDB gate G3.

All three are gates, and all three are gates the design already anticipated. The pattern is worth
noting on its own: the pre-flight script exists precisely to stop unverified platform assumptions
from becoming load-bearing, and the signature-validation gap (GAP-017) is what happens when an
assumption gets into the design faster than a gate gets into the script.

## 8. References

**Primary sources cited in this document**

- IAM permissions boundaries — https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies_boundaries.html
- IAM policy elements: Resource — https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_elements_resource.html
- IAM policy variables (absent-key semantics) — https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_variables.html
- IAM Access Analyzer policy checks — https://docs.aws.amazon.com/IAM/latest/UserGuide/access-analyzer-reference-policy-checks.html
- Restricting `iam:PassRole` — https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_use_passrole.html
- IAM API operations — https://docs.aws.amazon.com/IAM/latest/APIReference/API_Operations.html
- Terraform provider requirements — https://developer.hashicorp.com/terraform/language/providers/requirements
- Terraform S3 backend — https://developer.hashicorp.com/terraform/language/backend/s3
- Terraform backend configuration and secrets — https://developer.hashicorp.com/terraform/language/backend
- Terraform dependency lock file — https://developer.hashicorp.com/terraform/language/files/dependency-lock
- `sudoers(5)` — `env_reset`

**Internal**

- [`authentication-plan.md`](authentication-plan.md) · [`landing-zone-design.md`](landing-zone-design.md) · [`solution-design.md`](solution-design.md) · [`gaps-register.md`](gaps-register.md)
- [`psc-adv-0017-challenge-review.md`](../project-management/advisories/psc-adv-0017-challenge-review.md) — the predecessor review; F-02 confirms its CH-AUTH-001
- `docs/scraped/multi-account.md:9-10`, `:35`, `:60`, `:153-162` · `docs/scraped/environment-variables.md:160-162` · `docs/scraped/docker-images.md:74-86`
