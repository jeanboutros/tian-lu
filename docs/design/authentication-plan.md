# Authentication Plan — Floci Signature Validation, IAM Enforcement, and Credential Rotation

> **Status:** Specification — not yet implemented. This document describes the complete design for
> Floci authentication (SigV4, IAM enforcement, credential rotation). The code changes in §6 are
> implementation specifications for Phase B. See psc-0002 for the implementation ticket.

## 1. Overview

This document describes the design for enabling AWS Signature V4 verification and IAM policy
enforcement in the Floci deployment, bootstrapping a proper IAM user hierarchy, and eliminating
all hardcoded credential secrets from the codebase.

The plan was validated by two adversarial challengers (Floci-bootstrap focus + AWS IAM
best-practices focus) and incorporates their findings. Key references:

- Floci env vars: [`docs/scraped/environment-variables.md`](../scraped/environment-variables.md)
- Floci multi-account + signature validation: [`docs/scraped/multi-account.md`](../scraped/multi-account.md)
- Floci compat image baked-in creds: [`docs/scraped/docker-images.md`](../scraped/docker-images.md)
- Landing-zone IAM model: [`landing-zone-design.md`](landing-zone-design.md) §5
- AWS root-user best practices: [AWS IAM User Guide](https://docs.aws.amazon.com/IAM/latest/UserGuide/root-user-best-practices.html)

## 2. Problem statement

### 2.1 Current state

The installer (`setup-floci.sh`) does not write `FLOCI_AUTH_VALIDATE_SIGNATURES` to the env file,
so Floci falls back to its image default of `false`. In this mode:

- The secret access key can be any non-empty string — no SigV4 verification.
- IAM policies are not enforced — any signed request succeeds regardless of the principal's policies.
- The summary prints "RISK: Floci is UNAUTHENTICATED by default."

The `infra/` Terraform project requires signature validation (G1 hard stop in
`scripts/preflight-floci.sh`), but the installer has no way to enable it.

### 2.2 Hardcoded credentials

The literal string `test` appears as a secret in multiple scripts:

| File | Line | Current value | Context |
|------|------|---------------|---------|
| `mock-server/dev-twin.sh` | 769 | `aws_secret_access_key = test` | `dev_env()` writes to host `~/.aws/credentials` |
| `scripts/preflight-floci.sh` | 35 | `AWS_SECRET_ACCESS_KEY=test` | `aws_admin()` helper |
| `docs/scraped/docker-images.md` | 78-79 | `AWS_ACCESS_KEY_ID=test` / `AWS_SECRET_ACCESS_KEY=test` | Compat image baked-in env vars (upstream — cannot change) |

The scraped docs (`docker-compose.md`, `tls.md`, `multi-account.md`, `initialization-hooks.md`)
also reference `test` — these document the Floci image's defaults and cannot be changed.

### 2.3 The `floci`/`floci` bootstrap credential

Floci's `FLOCI_SERVICES_IAM_SEED_DEPLOYER_PRINCIPAL=true` env var creates a local `floci-deployer`
IAM user with `AdministratorAccess` and **static `floci`/`floci` credentials** — both the access key
ID and the secret access key are the literal string `floci`
([`docs/scraped/environment-variables.md:162`](../scraped/environment-variables.md)).

This is Floci's equivalent of the "initial admin user" you create when you first log into a real
AWS account: a known bootstrap credential so you can authenticate before you've had a chance to
create your own IAM users. The credentials are hardcoded in the Floci image; we cannot change what
it seeds.

## 3. IAM hierarchy

### 3.1 The three layers

| Layer | Identity | Credentials | Purpose | Lifecycle |
|-------|----------|-------------|---------|-----------|
| **Root-equivalent** | `FLOCI_DEFAULT_ACCOUNT_ID` (default `000000000000`) | None — it is a namespace, not an authenticated principal | Account namespace for resources | Permanent |
| **Bootstrap admin** | `floci-deployer` IAM user | Initially `floci`/`floci` (seeded by Floci); rotated to a random secret immediately after first boot | Create the platform-admin, application roles, and permissions boundary via Terraform | Superseded after landing-zone stage 10 |
| **Platform admin** | `platform-admin` IAM user/group/role | Created by Terraform stage `10-management-iam` | Ongoing delegated administration — bounded by a permissions boundary | Permanent (after bootstrap) |

### 3.2 Floci's lack of a root user

In real AWS, the root user has email+password credentials and owns the account. Floci has no root
user concept — `FLOCI_DEFAULT_ACCOUNT_ID` is a fallback namespace identifier, not an authenticated
principal. Any request with a non-12-digit AKID resolves to this account, but there is no "root
login."

This is a Floci limitation, not a design choice. The `floci-deployer` serves as the de-facto
root-equivalent for bootstrap. This gap should be recorded in
[`gaps-register.md`](gaps-register.md).

### 3.3 Relationship to the landing-zone design

The landing-zone design ([`landing-zone-design.md` §5.1](landing-zone-design.md)) defines
`platform-admin` as a **bounded** delegated administrator whose `iam:CreateRole` and related actions
are conditioned on attaching a permissions boundary. This is distinct from `floci-deployer`, which
has unbounded `AdministratorAccess`.

The lifecycle is:

```
floci-deployer (bootstrap, floci/floci → rotated)
  │
  │  terraform apply (stage 10-management-iam)
  │  using floci-deployer credentials
  ▼
platform-admin (bounded by permissions boundary)
  │
  │  ongoing operations
  ▼
application roles (one per app, bounded by boundary + least-privilege policy)
```

`floci-deployer` is **bootstrap-only**. After the landing-zone Terraform creates `platform-admin`,
the deployer credentials should be rotated out and the platform-admin used for ongoing operations.

## 4. Design: single `FLOCI_AUTH_MODE` parameter

### 4.1 Why a single parameter

Floci exposes three separate auth-related env vars:

| Variable | Default | Effect |
|----------|---------|--------|
| `FLOCI_AUTH_VALIDATE_SIGNATURES` | `false` | Verifies AWS SigV4 on every request |
| `FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED` | `false` | Enforces IAM policies on API calls |
| `FLOCI_SERVICES_IAM_SEED_DEPLOYER_PRINCIPAL` | `false` | Creates `floci-deployer` user with `floci`/`floci` |

These are independent toggles, but not all combinations are meaningful:

| Signatures | Enforcement | Behaviour | Assessment |
|------------|-------------|-----------|------------|
| `false` | `false` | No sig check, no policy check — anyone can do anything | Current default; acceptable for trusted-LAN dev |
| `false` | `true` | No sig check → no authenticated principal → policy enforcement has no identity to evaluate | **Undefined / broken** |
| `true` | `false` | Sig check passes, but IAM policies are **ignored** — any correctly-signed request succeeds | **Crypto theater** — looks secure, authorizes everyone |
| `true` | `true` | Sig check + policy evaluation | **The only meaningful secure configuration** |

The `true`/`false` combination (signatures on, enforcement off) is worse than leaving both off
because it creates a false sense of security. The installer must prevent this.

### 4.2 The `FLOCI_AUTH_MODE` parameter

The installer accepts a single `FLOCI_AUTH_MODE` env var with two valid values:

```bash
readonly FLOCI_AUTH_MODE="${FLOCI_AUTH_MODE:-sigv4}"

# Compute auth sub-variables based on FLOCI_AUTH_MODE.
# Use non-readonly locals inside the case so tests can inject overrides
# via the ${VAR:-default} convention before the readonly declarations below.
_auth_validate_signatures=""
_auth_iam_enforcement=""
_auth_seed_deployer=""
_auth_iam_enabled=""
case "$FLOCI_AUTH_MODE" in
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
  *)
    printf 'ERROR: FLOCI_AUTH_MODE must be "off" or "sigv4" (got: %s)\n' "$FLOCI_AUTH_MODE" >&2
    exit 1
    ;;
esac

# Now freeze with test-injectable defaults.
# The ${VAR:-default} form lets tests override any individual auth var
# before sourcing the script, regardless of FLOCI_AUTH_MODE.
readonly FLOCI_AUTH_VALIDATE_SIGNATURES="${FLOCI_AUTH_VALIDATE_SIGNATURES:-$_auth_validate_signatures}"
readonly FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED="${FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED:-$_auth_iam_enforcement}"
readonly FLOCI_SERVICES_IAM_SEED_DEPLOYER_PRINCIPAL="${FLOCI_SERVICES_IAM_SEED_DEPLOYER_PRINCIPAL:-$_auth_seed_deployer}"
readonly FLOCI_SERVICES_IAM_ENABLED="${FLOCI_SERVICES_IAM_ENABLED:-$_auth_iam_enabled}"
```

This collapses the dangerous matrix into two coherent states. The dev twin and test twin can each
override `FLOCI_AUTH_MODE` independently.

### 4.3 Defaults

| Context | `FLOCI_AUTH_MODE` | Rationale |
|---------|-------------------|-----------|
| Production installer (`setup-floci.sh` direct) | `sigv4` | Secure by default — the project is not yet deployed, so there is no backward compatibility to preserve. Auth-off is an explicit opt-out for trusted-LAN convenience. |
| Dev twin (`make dev-up`) | `sigv4` | The dev twin is the natural place to prove IAM enforcement works |
| Test twin (`make twin-test`, default) | `off` | Tests installer mechanics, not auth semantics |
| Test twin (`make twin-test --auth-mode=sigv4`) | `sigv4` | Exercises the auth-on path (see §7) |

### 4.4 Changing `FLOCI_AUTH_MODE` on an existing VM

`make dev-up` does **not** re-invoke the installer on an existing VM — it only starts the VM and
verifies Floci health. The `FLOCI_AUTH_MODE` is written to the Floci env file during `_install_absent`
and is not re-evaluated on resume. To change `FLOCI_AUTH_MODE` on an existing dev twin:

1. Run `make dev-recreate` — this rebuilds the OS from the current checkout while retaining the
   `floci-dev-data` data disk, re-running the installer with the new `FLOCI_AUTH_MODE`.
2. Alternatively, run `make dev-reset` to wipe all state and start fresh.

Changing `FLOCI_AUTH_MODE` without `dev-recreate` has no effect — the env file retains the value from
the original install.

## 5. Design: credential rotation

### 5.1 Why rotation is needed

`FLOCI_SERVICES_IAM_SEED_DEPLOYER_PRINCIPAL=true` always creates `floci-deployer` with `floci`/`floci`.
These are well-known credentials documented in the Floci public docs — anyone who has read the docs
knows them. Using them long-term violates AWS best practice ("don't use the initial admin credential
for ongoing operations; rotate it immediately").

### 5.2 Rotation flow

The dev twin rotates the bootstrap credential immediately after Floci starts. The
`aws` CLI runs **inside the Floci container** via `podman exec` (the guest OS does
not have the AWS CLI — only the compat image does). The `-e` flags override the
container's baked-in `test/test` env vars.

```
1. Installer starts Floci with FLOCI_AUTH_MODE=sigv4
2. Floci creates floci-deployer with floci/floci (automatic)
3. _health_check passes (Floci is ready)
4. _rotate_bootstrap_credentials:
   a. Determine bootstrap creds:
      - Fresh install (no DEV_CREDENTIALS_FILE): use floci/floci
      - dev-recreate (DEV_CREDENTIALS_FILE exists): use the existing rotated creds
   b. podman exec -e AWS_ACCESS_KEY_ID=<bootstrap> -e AWS_SECRET_ACCESS_KEY=<bootstrap>
      tianlu-floci aws --endpoint-url http://localhost:4566 --region "$DEV_REGION"
      iam create-access-key --user-name floci-deployer
      → Floci returns a new AKID + a random secret
   c. VERIFY: podman exec -e AWS_ACCESS_KEY_ID=<new_akid> -e AWS_SECRET_ACCESS_KEY=<new_sk>
      tianlu-floci aws --endpoint-url http://localhost:4566 --region "$DEV_REGION"
      sts get-caller-identity
      → Must return the floci-deployer ARN. If it fails, abort rotation — do NOT delete the old key.
   d. Delete the old key (same podman exec pattern):
      aws iam delete-access-key --user-name floci-deployer --access-key-id <bootstrap>
      If delete fails, emit a WARNING (do NOT suppress — a stale key is a security risk)
   e. Persist the new AKID + secret to ~/.cache/tianlu-twin/dev-credentials.env (mode 0600)
5. dev_env writes the rotated creds to ~/.aws/credentials
6. _print_next_steps displays the credential location + rotation instructions
```

After rotation, the well-known `floci`/`floci` credential no longer works. Only the rotated random
secret can authenticate as `floci-deployer`.

The `dev-recreate` path (rebuild OS, retain data disk) re-runs `_install_absent`, which calls
`_rotate_bootstrap_credentials`. Since the data disk persists, Floci retains the rotated
`floci-deployer` key. The rotation function detects `DEV_CREDENTIALS_FILE` exists and uses the
**existing rotated creds** (not the deleted `floci`/`floci`) to create the next key — avoiding
the latent bug where `floci`/`floci` would fail after the first rotation.

### 5.3 Credential persistence

Rotated credentials are persisted to `~/.cache/tianlu-twin/dev-credentials.env` (mode 0600) so they
survive `dev-down`/`dev-up` cycles. The file is under `~/.cache` (git-ignored by convention).

```
DEV_BOOTSTRAP_AKID=AKIA...
DEV_BOOTSTRAP_SECRET=<64-hex random>
```

`dev-reset` deletes this file, so the next `dev-up` generates a fresh secret.

### 5.4 Fallback

If rotation fails (e.g. the `iam create-access-key` call errors), the dev twin falls back to
the best available credentials (`floci`/`floci` on fresh install, or the existing rotated creds
on `dev-recreate`) with a warning. This should not happen in practice, but the fallback ensures
the dev twin is not blocked by a rotation failure. The `_print_next_steps` security section
(§6.7) prints a prominent WARNING when sigv4 mode is active but rotation failed, so the user
knows the well-known public credential is in use.

## 6. Explicit code changes

### 6.1 `setup-floci.sh` — `FLOCI_AUTH_MODE` parameter

**Location**: config block, after `FLOCI_TLS_SELF_SIGNED` (line ~62).

Add the `FLOCI_AUTH_MODE` case statement (§4.2). No bootstrap credential constants
are needed in `setup-floci.sh` — Floci always seeds `floci`/`floci` (we cannot change
this), and the literal values appear only in `print_summary`'s message (§6.3) and
in `preflight-floci.sh`'s env-var defaults (§6.9).

```bash
readonly FLOCI_AUTH_MODE="${FLOCI_AUTH_MODE:-sigv4}"

# Compute auth sub-variables based on FLOCI_AUTH_MODE.
# Use non-readonly locals inside the case so tests can inject overrides
# via the ${VAR:-default} convention before the readonly declarations below.
_auth_validate_signatures=""
_auth_iam_enforcement=""
_auth_seed_deployer=""
_auth_iam_enabled=""
case "$FLOCI_AUTH_MODE" in
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
  *)
    printf 'ERROR: FLOCI_AUTH_MODE must be "off" or "sigv4" (got: %s)\n' "$FLOCI_AUTH_MODE" >&2
    exit 1
    ;;
esac

# Now freeze with test-injectable defaults.
readonly FLOCI_AUTH_VALIDATE_SIGNATURES="${FLOCI_AUTH_VALIDATE_SIGNATURES:-$_auth_validate_signatures}"
readonly FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED="${FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED:-$_auth_iam_enforcement}"
readonly FLOCI_SERVICES_IAM_SEED_DEPLOYER_PRINCIPAL="${FLOCI_SERVICES_IAM_SEED_DEPLOYER_PRINCIPAL:-$_auth_seed_deployer}"
readonly FLOCI_SERVICES_IAM_ENABLED="${FLOCI_SERVICES_IAM_ENABLED:-$_auth_iam_enabled}"
```

### 6.1a `dev-twin.sh` — `DEV_CREDENTIALS_FILE` constant

**Location**: constants block, after `DEV_POLL_INTERVAL` (line ~26).

The credential cache file must be declared as a readonly constant so all functions
in §6.5–§6.8 can reference it. Without this, `set -u` (line 2 of dev-twin.sh) aborts
on first use.

```bash
readonly DEV_CREDENTIALS_FILE="${DEV_CREDENTIALS_FILE:-${HOME}/.cache/tianlu-twin/dev-credentials.env}"
readonly DEV_REGION="${DEV_REGION:-eu-west-2}"
```

### 6.2 `setup-floci.sh` — write auth vars to env file

**Location**: `write_env_file`, after the `FLOCI_AUTH_PRESIGN_SECRET` line (~line 835).

```bash
FLOCI_SERVICES_IAM_ENABLED=${FLOCI_SERVICES_IAM_ENABLED}
FLOCI_AUTH_VALIDATE_SIGNATURES=${FLOCI_AUTH_VALIDATE_SIGNATURES}
FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED=${FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED}
FLOCI_SERVICES_IAM_SEED_DEPLOYER_PRINCIPAL=${FLOCI_SERVICES_IAM_SEED_DEPLOYER_PRINCIPAL}
```

> **Note:** SPEC-TX-006 test case 3 must be reversed — it previously asserted that
> `FLOCI_SERVICES_IAM_ENABLED` is NOT present in the env file. After SPEC-SW-004,
> it should now assert that `FLOCI_SERVICES_IAM_ENABLED=true` IS present in sigv4
> mode and `FLOCI_SERVICES_IAM_ENABLED=false` IS present in off mode.

### 6.3 `setup-floci.sh` — `print_summary` conditional

**Location**: `print_summary`, line ~946.

```bash
if [[ "$FLOCI_AUTH_VALIDATE_SIGNATURES" == "true" ]]; then
  echo "Auth: IAM signature validation + policy enforcement are ON (sigv4 mode)."
  echo "      Bootstrap admin: floci-deployer (well-known public credential)."
  echo "      The credential is documented in the Floci public docs — rotate it"
  echo "      immediately. See dev-twin _print_next_steps for rotation instructions."
  echo "      Create a bounded platform-admin via landing-zone stage 10 for"
  echo "      ongoing operations; rotate the deployer credentials after."
else
  echo "RISK: Floci is UNAUTHENTICATED (auth_mode=off)."
  echo "Any host within the trusted subnet(s) above has full control of all Floci"
  echo "resources. Self-signed TLS provides encryption only, NOT authentication."
  echo "Only run this on a fully trusted network (see docs/design/solution-design.md §10.4)."
fi
```

### 6.4 `dev-twin.sh` — pass `FLOCI_AUTH_MODE=sigv4` at install

**Location**: `_install_absent`, line 484.

```bash
limactl shell "$DEV_TWIN_NAME" -- sudo bash -c \
  "cd / && FLOCI_HOST_PERSISTENT_PATH=$DEV_GUEST_DATA_ROOT \
   FLOCI_TLS_ENABLED=false FLOCI_TLS_SELF_SIGNED=false \
   FLOCI_AUTH_MODE=sigv4 \
   bash /opt/tianlu/setup-floci.sh" 2>/dev/null
```

### 6.5 `dev-twin.sh` — credential rotation helper

**Location**: new function, after `_resume_health_check`.

The rotation runs `aws` **inside the Floci container** via `podman exec` (the guest
OS does not have the AWS CLI installed — only the compat image does). The `-e` flags
override the container's baked-in `test/test` env vars. The endpoint is
`http://localhost:4566` (TLS is off in the dev twin).

The function handles three scenarios:
1. **Fresh install** — `DEV_CREDENTIALS_FILE` doesn't exist → use `floci`/`floci` to
   create a new key, delete the original, persist the new creds.
2. **`dev-recreate`** (data disk persists, OS rebuilt) — `DEV_CREDENTIALS_FILE` exists
   with rotated creds → use those creds instead of `floci`/`floci` (which was deleted
   on the first rotation). Create a new key, delete the old rotated key, persist.
3. **Rotation failure** — `create-access-key` fails → fall back to the best available
   creds (`floci`/`floci` on fresh install, or the existing rotated creds on recreate)
   with a warning.

Partial-failure handling: if `create-access-key` succeeds but `delete-access-key`
fails, the well-known (or previous) credential remains active alongside the new one.
The function emits a WARNING and does NOT suppress the delete failure — the user is
told the old key is still live and must be deleted manually.

A second partial-failure scenario is added by the verification step: if
`create-access-key` succeeds but `sts get-caller-identity` fails, the old key is
preserved and a WARNING is emitted. The new (unverified) key is discarded — it will
be orphaned in Floci's IAM store but cannot be used (we don't know if it works).
A future rotation will create yet another key.

```bash
# _rotate_bootstrap_credentials
# Rotate the floci-deployer bootstrap credential immediately after Floci starts.
# Uses podman exec (the guest OS has no AWS CLI — only the compat container does).
# Handles fresh install (floci/floci → new key) and dev-recreate (existing rotated
# key → new key). Falls back with a warning if rotation fails.
_rotate_bootstrap_credentials() {
  local bootstrap_akid bootstrap_secret out new_akid new_sk delete_rc
  # Determine which credentials to use for the rotation API calls
  if [[ -f "$DEV_CREDENTIALS_FILE" ]]; then
    # dev-recreate: data disk persisted, use existing rotated creds
    # shellcheck disable=SC1090
    source "$DEV_CREDENTIALS_FILE"
    bootstrap_akid="${DEV_BOOTSTRAP_AKID:-floci}"
    bootstrap_secret="${DEV_BOOTSTRAP_SECRET:-floci}"
  else
    # Fresh install: use the well-known floci/floci bootstrap
    bootstrap_akid="floci"
    bootstrap_secret="floci"
  fi
  # Create a new access key using the current bootstrap creds (via podman exec)
  out="$(_run_as_floci_guest \
    "podman exec -e AWS_ACCESS_KEY_ID=${bootstrap_akid} -e AWS_SECRET_ACCESS_KEY=${bootstrap_secret} \
     tianlu-floci aws --endpoint-url http://localhost:4566 --region ${DEV_REGION} \
     iam create-access-key --user-name floci-deployer 2>/dev/null")" || true
  new_akid="$(printf '%s' "$out" | grep -o '"AccessKeyId": *"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')"
  new_sk="$(printf '%s' "$out" | grep -o '"SecretAccessKey": *"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')"
  if [[ -z "$new_akid" || -z "$new_sk" ]]; then
    printf 'WARNING: could not rotate bootstrap credentials — using %s/%s\n' \
      "$bootstrap_akid" "$bootstrap_secret" >&2
    DEV_BOOTSTRAP_AKID="$bootstrap_akid"
    DEV_BOOTSTRAP_SECRET="$bootstrap_secret"
    return 0
  fi
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
  # Delete the old access key (do NOT suppress failures — a stale key is a security risk)
  _run_as_floci_guest \
    "podman exec -e AWS_ACCESS_KEY_ID=${bootstrap_akid} -e AWS_SECRET_ACCESS_KEY=${bootstrap_secret} \
     tianlu-floci aws --endpoint-url http://localhost:4566 --region ${DEV_REGION} \
     iam delete-access-key --user-name floci-deployer --access-key-id ${bootstrap_akid} 2>/dev/null"
  delete_rc=$?
  if [[ $delete_rc -ne 0 ]]; then
    printf 'WARNING: could not delete old key %s — it is still active.\n' \
      "$bootstrap_akid" >&2
    printf '         Delete it manually: aws iam delete-access-key --user-name floci-deployer --access-key-id %s\n' \
      "$bootstrap_akid" >&2
  fi
  DEV_BOOTSTRAP_AKID="$new_akid"
  DEV_BOOTSTRAP_SECRET="$new_sk"
  mkdir -p "$(dirname "$DEV_CREDENTIALS_FILE")"
  printf 'DEV_BOOTSTRAP_AKID=%s\nDEV_BOOTSTRAP_SECRET=%s\n' \
    "$DEV_BOOTSTRAP_AKID" "$DEV_BOOTSTRAP_SECRET" > "$DEV_CREDENTIALS_FILE"
  chmod 0600 "$DEV_CREDENTIALS_FILE"
}
```

Call it in `_install_absent` after `_health_check`:

```bash
  _health_check
  _rotate_bootstrap_credentials
  dev_env
```

### 6.6 `dev-twin.sh` — `dev_env` uses rotated credentials

**Location**: `dev_env`, line ~757.

Replace the hardcoded `test/test` with credential loading:

```bash
dev_env() {
  assert_identity
  local export_only=false aws_dir config_file creds_file ak sk
  [[ "${1:-}" == "--export" ]] && export_only=true
  aws_dir="${HOME}/.aws"
  config_file="${aws_dir}/config"
  creds_file="${aws_dir}/credentials"
  mkdir -p "$aws_dir"
  if ! grep -q '\[profile tianlu-floci-dev\]' "$config_file" 2>/dev/null; then
    printf '\n[profile tianlu-floci-dev]\nregion = %s\noutput = json\nca_bundle =\n' "$DEV_REGION" >> "$config_file"
  fi
  # Load rotated credentials if available, else fall back to test/test (auth off)
  if [[ -f "$DEV_CREDENTIALS_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$DEV_CREDENTIALS_FILE"
    ak="${DEV_BOOTSTRAP_AKID:-test}"
    sk="${DEV_BOOTSTRAP_SECRET:-test}"
  else
    ak="test"
    sk="test"
  fi
  # Replace existing [tianlu-floci-dev] block (avoids stale creds from a previous mode).
  # Use sed -i.bak (portable across BSD and GNU sed) — BSD sed requires an
  # extension arg for -i; GNU sed accepts -i.bak and creates a backup we remove.
  sed -i.bak '/^\[tianlu-floci-dev\]/,/^\[/d' "$creds_file" && rm -f "${creds_file}.bak"
  printf '\n[tianlu-floci-dev]\naws_access_key_id = %s\naws_secret_access_key = %s\n' "$ak" "$sk" >> "$creds_file"
  chmod 0600 "$creds_file"
  if "$export_only"; then
    printf 'export AWS_PROFILE=tianlu-floci-dev\nexport AWS_ENDPOINT_URL=http://tianlu-floci:4566\nexport AWS_DEFAULT_REGION=%s\n' "$DEV_REGION"
  else
    printf '\n# AWS CLI configured for tianlu-floci-dev twin:\n# Profile "tianlu-floci-dev" added to ~/.aws/config and ~/.aws/credentials\n#\n# To connect in this shell:\nexport AWS_PROFILE=tianlu-floci-dev\nexport AWS_ENDPOINT_URL=http://tianlu-floci:4566\nexport AWS_DEFAULT_REGION=%s\n#\n# Or: eval "$(make dev-env -- --export)"\n' "$DEV_REGION"
  fi
}
```

### 6.7 `dev-twin.sh` — `_print_next_steps` security section

**Location**: `_print_next_steps`, after the lifecycle commands section.

The security section is gated on `FLOCI_AUTH_MODE=sigv4` (not on `DEV_CREDENTIALS_FILE`
existence), so the user always gets an auth status message when sigv4 is active.
If rotation succeeded (`DEV_CREDENTIALS_FILE` exists), the section shows the
credential location and rotation instructions using the **current** rotated creds
(not the deleted `floci`/`floci`). If rotation failed (fallback path), the section
warns that the well-known public credential is in use.

```bash
  if [[ "${DEV_AUTH_MODE:-off}" == "sigv4" ]]; then
    printf '7. Security — bootstrap credential rotation:\n'
    printf '\n'
    if [[ -f "$DEV_CREDENTIALS_FILE" ]]; then
      printf '   The dev twin generated a random secret for the floci-deployer\n'
      printf '   IAM user and deleted the original floci/floci key. The new\n'
      printf '   credentials are in ~/.aws/credentials and cached at:\n'
      printf '\n'
      printf '      %s\n' "$DEV_CREDENTIALS_FILE"
      printf '\n'
      printf '   To rotate again (e.g. if the secret is compromised):\n'
      printf '\n'
      printf '      # Use the CURRENT rotated creds (not floci/floci — that key was deleted)\n'
      printf '      AWS_PROFILE=tianlu-floci-dev aws --endpoint-url http://localhost:4566 --region %s \\\n' "$DEV_REGION"
      printf '        iam create-access-key --user-name floci-deployer\n'
      printf '      # ... then delete the old key and update ~/.aws/credentials\n'
      printf '\n'
      printf '   WARNING: do not commit ~/.aws/credentials or the cache file.\n'
      printf '   Both are mode 0600. The cache file is under ~/.cache (git-ignored).\n'
    else
      printf '   WARNING: rotation failed — the well-known public bootstrap\n'
      printf '   credential is in use with full AdministratorAccess. Rotate\n'
      printf '   manually as soon as possible. The credential values are\n'
      printf '   documented in the Floci public docs (floci-deployer user).\n'
      printf '   See docs/design/authentication-plan.md §5.2 for rotation steps.\n'
    fi
  fi
```

`DEV_AUTH_MODE` is set by `_install_absent` when it passes `FLOCI_AUTH_MODE=sigv4`
to the installer. It persists for the duration of the `dev_up` call so
`_print_next_steps` can check it.

### 6.8 `dev-twin.sh` — `dev_reset` deletes the credentials file

**Location**: `dev_reset`, after `managed_hosts_remove`.

```bash
  rm -f "$DEV_CREDENTIALS_FILE"
```

### 6.9 `preflight-floci.sh` — accept bootstrap creds via env vars

**Location**: `aws_admin`, line 35.

```bash
aws_admin() {
  AWS_ACCESS_KEY_ID="${FLOCI_BOOTSTRAP_AKID:-$DEV_AKID}" \
  AWS_SECRET_ACCESS_KEY="${FLOCI_BOOTSTRAP_SECRET:-test}" \
  aws --endpoint-url "$ENDPOINT" --region "$REGION" "$@"
}
```

When running against a `sigv4` Floci, set `FLOCI_BOOTSTRAP_AKID` and `FLOCI_BOOTSTRAP_SECRET` to the
rotated deployer credentials (or `floci`/`floci` if rotation was not performed).

### 6.10 Test twin — `run-test.sh` + `run-in-vm.sh` auth-mode support

**`run-test.sh`**: accept `--auth-mode=off|sigv4` flag (default `off`). Pass `AUTH_MODE` to the
guest driver.

**`run-in-vm.sh`**: when `AUTH_MODE=sigv4`:
- Pass `FLOCI_AUTH_MODE=sigv4` to the installer invocation
- Override the container's baked-in `test/test` on `podman exec aws` calls with explicit
  `-e AWS_ACCESS_KEY_ID=floci -e AWS_SECRET_ACCESS_KEY=floci` flags

Example for the s3-smoke test:

```bash
AWS_CREDS_ENV=""
if [[ "$AUTH_MODE" == "sigv4" ]]; then
  AWS_CREDS_ENV="-e AWS_ACCESS_KEY_ID=floci -e AWS_SECRET_ACCESS_KEY=floci"
fi
run_as_floci_guest podman exec $AWS_CREDS_ENV tianlu-floci aws \
  --endpoint-url https://localhost:4566 --no-verify-ssl s3 mb s3://twin
```

**`run-test.sh` `launch_driver`** — passes `--auth-mode` flag to the guest driver with safe
argument quoting:

```bash
launch_driver() {
  local -a driver_args=()

  if [[ "$NO_SIDECAR" == true ]]; then
    driver_args+=(--no-sidecar)
  fi
  if [[ -n "${AUTH_MODE:-}" ]]; then
    driver_args+=(--auth-mode="$AUTH_MODE")
  fi
  (
    local driver_args_quoted
    driver_args_quoted="$(printf '%q ' "${driver_args[@]}")"
    limactl shell "$TWIN_NAME" -- bash -c \
      "sudo systemd-run --quiet --wait --unit=tianlu-driver -- /opt/tianlu/mock-server/in-vm/run-in-vm.sh ${driver_args_quoted}" 2>/dev/null
  ) &
  DRIVER_SHELL_PID=$!
}
```

The `printf '%q ' "${driver_args[@]}"` pattern preserves argument boundaries by
shell-escaping each element individually. The original `${driver_args[*]}` expansion
joined array elements with the first character of `IFS` (space), losing argument
boundaries when any element contained whitespace. The `${arr[@]+...}` guard is no
longer needed because `printf '%q '` on an empty array produces an empty string
(not an unbound-variable error).

### 6.10a IAM permissions boundary enforcement

The `platform-admin` policy in [`infra/live/10-management-iam/main.tf`](../../infra/live/10-management-iam/main.tf)
uses a `DenyAllExceptBoundary` statement with `StringNotEquals` on `iam:PermissionsBoundary`
to prevent the platform-admin from deleting the permissions boundary or any policy
without the boundary condition. This is the enforcement mechanism for the escalation
ceiling described in [`landing-zone-design.md` §5.1](landing-zone-design.md).

The statement denies the following destructive IAM actions on **any** resource (`*`)
**unless** the request includes the `iam:PermissionsBoundary` condition key matching
the `general_app_boundary` ARN:

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

The original statement scoped `resources` to the boundary policy ARN, but the denied
actions (`iam:DeleteRolePermissionsBoundary`, etc.) act on IAM principal ARNs (roles,
users, groups), not on the policy ARN. The fix uses `Resource = "*"` with a
`StringNotEquals` condition — the standard AWS IAM pattern for "deny everything except
when the boundary matches."

### 6.10b Terraform backend configuration

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

### 6.10c Environment tag consistency

The `dev.tfvars` `default_tags` map must NOT include `Project`, `Environment`, or
`ManagedBy` — these are injected by `providers.tf`'s `default_tags` merge from
`var.environment`. Duplicating them causes `terraform plan` warnings and breaks
ABAC tag-match queries. The `Environment` tag value is `"dev"` (from
`var.environment = "dev"`), not `"development"`.

The `providers.tf` `default_tags` block injects the canonical trio:

```hcl
default_tags {
    tags = merge({
      Project     = "tianlu"
      Environment = var.environment
      ManagedBy   = "terraform"
    }, var.default_tags)
  }
```

The `var.environment` value is `"dev"` (from `dev.tfvars:10`), so the injected
`Environment` tag will be `"dev"` — matching the documented environment values
(`dev`, `uat`, `prod`). The `default_tags` map in `dev.tfvars` should contain only
additional tags (e.g., `Owner`), not the three that `providers.tf` already injects.

### 6.10d IRSA stand-in session duration

The IRSA stand-in in [`landing-zone-design.md` §5.4](landing-zone-design.md)
specifies a `DurationSeconds` bound of 3600s (1 hour) and a re-assumption
cadence of 30 minutes. This limits the blast radius of a compromised Kubernetes
Secret and ensures credentials are refreshed before expiry.

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

### 6.11 Tests

The auth-mode feature requires 40 test cases across 7 test files. The full test specifications are in
[`docs/project-management/logs/tickets/psc-0002/A1-TX-test-engineer.md`](../../project-management/logs/tickets/psc-0002/A1-TX-test-engineer.md).
This section summarizes the test structure and key patterns.

#### Test file summary

| Test File | New Tests | Modified Tests | Total Specs |
|-----------|-----------|----------------|-------------|
| `tests/phase5.bats` | 5 (SPEC-TX-005, SPEC-TX-006) | 0 | 5 |
| `tests/phase6_7.bats` | 3 (SPEC-TX-007) | 0 | 3 |
| `tests/preflight.bats` (NEW) | 4 (SPEC-TX-009) | 0 | 4 |
| `mock-server/tests/dev_twin.bats` | 12 (SPEC-TX-001, 002, 003, 008, 011) | 0 | 12 |
| `mock-server/tests/orchestrator_args.bats` | 5 (SPEC-TX-004:1-5) | 0 | 5 |
| `mock-server/tests/run_in_vm.bats` (NEW) | 9 (SPEC-TX-004:6-9, SPEC-TX-010) | 0 | 9 |
| `mock-server/tests/completion_protocol.bats` | 1 (SPEC-TX-013) | 1 (SPEC-TX-013 update) | 2 |
| **Total** | **39** | **1** | **40** |

#### Implementation order

1. **Phase 5 tests first** (SPEC-TX-005, SPEC-TX-006) — test the installer's config block and
   env-file writing, the foundation of the auth-mode feature.
2. **Phase 6/7 tests** (SPEC-TX-007) — test the summary output, which depends on the config block.
3. **Preflight tests** (SPEC-TX-009) — test the preflight script's credential handling.
4. **Dev-twin rotation tests** (SPEC-TX-001, 002, 003, 008, 011, 012) — test the rotation function
   and `dev_env` behavior.
5. **Orchestrator args tests** (SPEC-TX-004:1-5) — test the `--auth-mode` flag parsing.
6. **Run-in-vm tests** (SPEC-TX-004:6-9, SPEC-TX-010) — test the guest driver's auth-mode behavior.
7. **Completion protocol fix** (SPEC-TX-013) — fix and test the `wait_driver` hang.

#### Key test patterns

**Installer config block tests** (`tests/phase5.bats`):
- `FLOCI_AUTH_MODE` invalid value exits 1 with error message (SPEC-TX-005)
- `write_env_file` sigv4 mode emits all auth vars as `true` (SPEC-TX-006)
- `write_env_file` off mode emits all auth vars as `false` (SPEC-TX-006)
- `write_env_file` sigv4 mode emits `FLOCI_SERVICES_IAM_ENABLED=true` (SPEC-TX-006, updated per SPEC-SW-004)
- `write_env_file` auth vars absent when `FLOCI_AUTH_MODE` is unset (backward compat) (SPEC-TX-006)

**Summary output tests** (`tests/phase6_7.bats`):
- `print_summary` sigv4 mode prints IAM signature validation ON message (SPEC-TX-007)
- `print_summary` off mode prints UNAUTHENTICATED risk warning (SPEC-TX-007)
- `print_summary` sigv4 mode prints bootstrap admin credential note (SPEC-TX-007)

**Rotation tests** (`mock-server/tests/dev_twin.bats`):
- Fresh install uses `floci`/`floci`, creates new key, deletes old, persists (SPEC-TX-001)
- `dev-recreate` uses existing rotated creds from `DEV_CREDENTIALS_FILE` (SPEC-TX-001)
- Fallback when `create-access-key` fails — uses bootstrap creds with warning (SPEC-TX-001)
- Partial failure — create succeeds, delete fails, emits WARNING (SPEC-TX-001)
- File permissions — `DEV_CREDENTIALS_FILE` is mode 0600 (SPEC-TX-001)
- Rotation gated off in `auth_mode=off` (SPEC-TX-002)
- Stale `DEV_CREDENTIALS_FILE` not consumed in off mode (SPEC-TX-003)
- `dev_env` sed-replace and credential-rotation tests (SPEC-TX-008)
- `chmod` failure on `DEV_CREDENTIALS_FILE` is detected (SPEC-TX-011)
- Replace `grep`/`sed` JSON parsing with `jq` (SPEC-TX-012)

**Orchestrator flag parsing tests** (`mock-server/tests/orchestrator_args.bats`):
- `--auth-mode=off` sets `AUTH_MODE=off` (SPEC-TX-004)
- `--auth-mode=sigv4` sets `AUTH_MODE=sigv4` (SPEC-TX-004)
- `--auth-mode=invalid` reports a failure reason (SPEC-TX-004)
- `--auth-mode` with no value reports a failure reason (SPEC-TX-004)
- Default `AUTH_MODE` is `off` when `--auth-mode` is not passed (SPEC-TX-004)

**Guest driver tests** (`mock-server/tests/run_in_vm.bats`):
- `AUTH_MODE=off` does NOT pass `FLOCI_AUTH_MODE` to installer (SPEC-TX-004)
- `AUTH_MODE=sigv4` passes `FLOCI_AUTH_MODE=sigv4` to installer (SPEC-TX-004)
- `AUTH_MODE=sigv4` adds `-e` credential overrides to `podman exec aws` calls (SPEC-TX-004, SPEC-TX-010)
- `AUTH_MODE=off` does NOT add credential overrides to `podman exec aws` calls (SPEC-TX-004, SPEC-TX-010)

**Preflight tests** (`tests/preflight.bats`):
- `aws_admin` uses `DEV_AKID` and `test` secret by default (SPEC-TX-009)
- `aws_admin` uses `FLOCI_BOOTSTRAP_AKID` override when set (SPEC-TX-009)
- `aws_admin` uses `FLOCI_BOOTSTRAP_SECRET` override when set (SPEC-TX-009)
- `aws_admin` passes through additional aws arguments (SPEC-TX-009)

**Completion protocol fix** (`mock-server/tests/completion_protocol.bats`):
- `wait_driver` kills the transport before waiting (no hang) (SPEC-TX-013)

#### Stub requirements

New stubs needed in `mock-server/tests/stubs/bin/`:
- `jq` — symlink to `_stub` (for SPEC-TX-012 tests). Must support `STUB_OUT_JQ` for synthetic JSON
  parsing output.
- `kill` — symlink to `_stub` (for SPEC-TX-013 tests). Must support `STUB_RC_KILL` for exit code
  control.

New stubs needed in `tests/stubs/bin/`:
- `jq` — symlink to `_stub` (if preflight tests need it; currently they don't).

### 6.12 Documentation

- Add a gap finding in [`gaps-register.md`](gaps-register.md): Floci has no root user concept;
  `FLOCI_DEFAULT_ACCOUNT_ID` is a namespace, not an authenticated principal
- Add a lifecycle note in [`solution-design.md`](solution-design.md) or `REVIEW.md`:
  `floci-deployer` (bootstrap) → landing-zone stage 10 → `platform-admin` (ongoing)

## 7. Test-twin auth-on path

The user requirement: "dev-test should be able to run a test for both
`FLOCI_AUTH_VALIDATE_SIGNATURES=true` and `FLOCI_AUTH_VALIDATE_SIGNATURES=false`."

### 7.1 The `podman exec` credential problem

The compat image bakes `AWS_ACCESS_KEY_ID=test` / `AWS_SECRET_ACCESS_KEY=test` as container env vars
([`docs/scraped/docker-images.md:78-79`](../scraped/docker-images.md)). When you run
`podman exec tianlu-floci aws ...`, the command executes inside the container's namespace, where
the container's env vars take precedence over any host-side `~/.aws/credentials` file. The host's
creds file is NOT mounted into the container.

When auth is on, the baked-in `test/test` is not associated with any IAM user (the deployer is
`floci`/`floci`). Therefore, `podman exec aws` calls would fail with a signature validation error.

### 7.2 Solution

When `auth_mode=sigv4`, the test twin's `podman exec` calls must explicitly override the container's
baked-in env vars:

```bash
podman exec -e AWS_ACCESS_KEY_ID=floci -e AWS_SECRET_ACCESS_KEY=floci tianlu-floci aws ...
```

This is a per-call override — the container's env vars are not permanently changed.

### 7.3 Test matrix

| Test | `auth_mode=off` | `auth_mode=sigv4` |
|------|-----------------|-------------------|
| s3-smoke | `podman exec aws` (baked-in `test/test`) | `podman exec -e AWS_ACCESS_KEY_ID=floci -e AWS_SECRET_ACCESS_KEY=floci aws` |
| Lambda sidecar | same | same |
| G1 preflight | `aws_admin` with `test` secret | `aws_admin` with `floci` secret (or rotated) |
| Installer | `FLOCI_AUTH_MODE=off` | `FLOCI_AUTH_MODE=sigv4` |

## 8. Security considerations

### 8.1 The `floci`/`floci` credential is public knowledge

The `floci`/`floci` bootstrap credential is documented in the Floci public docs. Anyone who has
read the docs knows it. This is why rotation is mandatory in `sigv4` mode — after rotation, the
well-known credential no longer works.

### 8.2 Credential file permissions

- `~/.aws/credentials` — mode 0600 (set by `dev_env`)
- `~/.cache/tianlu-twin/dev-credentials.env` — mode 0600 (set by `_rotate_bootstrap_credentials`)
- Both files are under the user's home directory and are not committed to git

### 8.3 The `true`/`false` signature/enforcement split is prevented

The `FLOCI_AUTH_MODE` parameter prevents the dangerous `sig=on, enforcement=off` combination (crypto
theater). The installer only allows both-on or both-off.

### 8.4 The deployer is not the platform-admin

`floci-deployer` has unbounded `AdministratorAccess`. The landing-zone `platform-admin` is bounded
by a permissions boundary. The plan documents that the deployer is bootstrap-only and the
platform-admin supersedes it. Using the deployer for ongoing operations would violate the
landing-zone design's delegated-administration principle.

## 9. Challenger findings incorporated

### 9.1 Challenger 1 (Floci bootstrap) — key findings

- **`podman exec` uses container env vars, not host creds** — addressed in §7.2
- **Seed deployer only when auth is on** — addressed by `FLOCI_AUTH_MODE` (off mode seeds nothing)
- **`dev_env` must update existing entries, not just add if missing** — addressed in §6.6 (sed replace)
- **`floci-deployer` is bootstrap-only, not `platform-admin`** — addressed in §3.3
- **Idempotency of seeding is assumed, not documented** — noted; Floci's persistence layer handles
  "user already exists" on restart

### 9.2 Challenger 2 (AWS IAM alignment) — key findings

- **Collapse three toggles into one `FLOCI_AUTH_MODE`** — adopted (§4)
- **Don't seed deployer when auth is off** — adopted (off mode sets `SEED_DEPLOYER=false`)
- **Use different creds per auth mode** — adopted (`test/test` for off, rotated for sigv4)
- **Add test-twin auth-on path** — adopted (§7)
- **Document Floci's lack of a root user as a gap** — adopted (§3.2, §6.12)
- **`floci-deployer` is bootstrap-only, `platform-admin` supersedes** — adopted (§3.3)

### 9.3 Deep-agent validation — key findings

- **Rotation must use `podman exec`, not bare `aws` on the guest** — the guest OS has no
  AWS CLI (only the compat container does). Fixed in §6.5 (uses `_run_as_floci_guest` +
  `podman exec -e ...`).
- **Re-rotation instructions must use current rotated creds, not deleted `floci`/`floci`** —
  after rotation, `floci`/`floci` is deleted and cannot authenticate. Fixed in §6.7 (uses
  `AWS_PROFILE=tianlu-floci-dev`).
- **`DEV_CREDENTIALS_FILE` must be declared as a readonly constant** — without it, `set -u`
  aborts on first use. Fixed in §6.1a.
- **`sed -i` is not portable to macOS BSD sed** — BSD sed requires an extension arg for `-i`.
  Fixed in §6.6 (uses `sed -i.bak ... && rm`).
- **`FLOCI_BOOTSTRAP_*` constants in `setup-floci.sh` are dead code** — not consumed by any
  file. Removed from §6.1.
- **Partial-failure (delete fails) leaves well-known key active** — `|| true` silently hides
  it. Fixed in §6.5 (checks `delete_rc`, emits WARNING, does not suppress).
- **`_print_next_steps` must warn on sigv4 + failed rotation** — gating on `DEV_CREDENTIALS_FILE`
  existence misses the fallback path. Fixed in §6.7 (gates on `DEV_AUTH_MODE=sigv4` with a
  fallback sub-branch).
- **`dev-recreate` re-runs rotation with deleted `floci`/`floci`** — the data disk persists,
  so Floci retains the rotated key, but the rotation function would try `floci`/`floci` (deleted).
  Fixed in §6.5 (detects `DEV_CREDENTIALS_FILE` and uses existing rotated creds on recreate).
- **Production installer default should be `sigv4`, not `off`** — the project is not yet
  deployed, so there is no backward compatibility to preserve. Secure-by-default is the
  correct posture. Fixed in §4.2 (default changed from `off` to `sigv4`) and §4.3 (defaults
  table updated). Auth-off is now an explicit opt-out for trusted-LAN convenience.

## 10. Out of scope

- **MFA** — Floci does not support multi-factor authentication. Not applicable.
- **Temporary credentials (STS AssumeRole) for the bootstrap** — the bootstrap needs static creds to
  create the first IAM user. AssumeRole is used later by the landing-zone application roles.
- **Customizing the seeded deployer credentials** — `FLOCI_SERVICES_IAM_SEED_DEPLOYER_PRINCIPAL`
  always creates `floci`/`floci`. We cannot change this. Rotation after first boot is the workaround.
- **Root user credentials** — Floci has no root user concept (§3.2).