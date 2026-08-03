# Authentication — signature validation, IAM enforcement, and credentials

Authoritative reference for how the Floci deployment authenticates callers and how the estate's
credentials are managed. Host-platform details live in [`solution-design.md`](solution-design.md);
the IAM/estate model lives in [`landing-zone-design.md`](landing-zone-design.md).

## 1. Overview

The estate runs on Floci with AWS SigV4 verification and IAM policy enforcement **requested** (auth
mode `sigv4`) — the target security posture. Each environment is a Floci account selected by a
12-digit Access Key ID; Terraform and the host CLI authenticate as that account's root identity.

## 2. Known issue — signatures are not verified on this Floci build

> Floci `1.5.33-compat` does **not** verify SigV4 signatures even with
> `FLOCI_AUTH_VALIDATE_SIGNATURES=true`. A request signed with the wrong secret is accepted, and a
> 12-digit AKID authenticates as that account's `root`. Reproduced in
> [`docs/issues/floci-signature-validation-ignored.md`](../issues/floci-signature-validation-ignored.md)
> (to be filed upstream).

IAM is therefore **authored faithfully but not enforced at runtime yet**. Everything below is the
target state; when the upstream fix lands it becomes enforced with no code change. Until then the
trusted-network firewall scope is the real control (see [`solution-design.md`](solution-design.md) §10.4).

## 3. Identity model

### 3.1 Environment = account (12-digit AKID)

| Environment | Account (AKID) |
| --- | --- |
| dev | `111111111111` |
| test | `222222222222` |
| uat | `333333333333` |
| prod | `444444444444` |

One Floci instance serves all four accounts; the AKID on each request selects the namespace. Promotion
is "copy the tfvars, change the AKID" (see [`landing-zone-design.md`](landing-zone-design.md) §4.2).
An AKID is always a 12-digit number — never a literal string.

### 3.2 Root principal, not a root credential

Floci has no root *credential* (no email/password login), but it does present a root *principal*: a
12-digit AKID authenticates as `arn:aws:iam::<account>:root`. **Deployment runs as account root.** A
permissions boundary cannot constrain root, so the delegated-admin model (§3.4) is authored for
real-AWS fidelity but not exercised on Floci. This is an accepted Floci limitation.

### 3.3 The deployer is seeded but unused

`FLOCI_SERVICES_IAM_SEED_DEPLOYER_PRINCIPAL=true` seeds a `floci-deployer` IAM user (well-known
`floci`/`floci`). It is kept for the future: when Floci can authenticate a per-account IAM user,
deployment can switch to it. It is **not** used for deployment today because any IAM-user key
(`AKIA…`) resolves to the default account `000000000000`, not the environment's account.

### 3.4 platform-admin and the permissions boundary (authored, not exercised)

The landing zone authors `platform-admin` (a bounded delegated administrator) and a permissions
boundary in stage `10-management-iam`. On Floci these are modeled — like VPC / Transit Gateway —
because Terraform runs as account root, so the boundary is not the runtime control. See
[`landing-zone-design.md`](landing-zone-design.md) §5.

## 4. Auth modes

`setup-floci.sh` exposes a single `FLOCI_AUTH_MODE` with two coherent values:

| Mode | Signatures | IAM enforcement | Deployer seeded |
| --- | --- | --- | --- |
| `sigv4` (default) | `true` | `true` | `true` |
| `off` | `false` | `false` | `false` |

Only these two states are allowed. The dangerous "signatures on / enforcement off" combination
(authenticate callers, then ignore their policies) is unreachable unless a test explicitly sets
`FLOCI_AUTH_UNSAFE_OVERRIDE=1`. `print_summary` reports the posture and the §2 caveat.

## 5. Credentials

Every environment has a 12-digit account AKID and a **generated per-env secret**. Floci ignores the
secret today (§2), but we carry a real one so the setup is correct for a future signature-honoring
build.

### 5.1 Host CLI — project-local profile

`make dev-env` writes an AWS profile `ns-tianlu-floci-dev` into a project-local store
(`~/.cache/tianlu-floci/aws/{config,credentials}`, mode `0600`) via `aws configure`, pointing
`AWS_CONFIG_FILE` + `AWS_SHARED_CREDENTIALS_FILE` at that store so the host's real `~/.aws` is never
touched. `eval "$(make dev-env-export)"` exports those two variables plus `AWS_PROFILE`; the
endpoint is baked into the profile. `make dev-reset` removes the store and the cached secret.

### 5.2 Terraform

The provider uses `access_key = var.account_id` (the 12-digit AKID) and `secret_key` from
`TF_VAR_secret_key`. Source the environment's account secret before `terraform init` (see
[`landing-zone-design.md`](landing-zone-design.md) §10.1). A `data.aws_caller_identity` postcondition
fails the plan if the AKID does not resolve to the expected account.

## 6. Pre-flight

[`scripts/preflight-floci.sh`](../../scripts/preflight-floci.sh) gate **G1** checks IAM enforcement
before any `terraform apply`. On this build G1 reflects the §2 reality; treat it as a target-state gate
until the upstream fix lands.

## 7. Naming convention

Type-prefixed names make each object's role clear. Applied now: AWS CLI profiles →
`ns-tianlu-floci-<env>` (`ns` = account namespace). The container and `FLOCI_HOSTNAME` stay
`tianlu-floci` (Podman DNS depends on it). Other objects adopt the convention as they are created.

## 8. Out of scope

- **MFA** — not supported by Floci.
- **STS/temporary credentials for bootstrap** — account root is the bootstrap identity.
- **Customizing the seeded deployer credential** — fixed by the Floci image.
