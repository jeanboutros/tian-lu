#!/usr/bin/env bats
#
# Integration tests for infra/stage.sh — the Terraform stage wrapper.
# Runs the real script against a fixture infra tree (INFRA_ROOT override) with a
# logging `terraform` stub on PATH, so no real Terraform runs and the repo tree
# is untouched.

setup() {
  STAGE_SH="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." && pwd)/infra/stage.sh"
  export STAGE_SH
  TEST_TMP="$(mktemp -d)"
  export TEST_TMP
  FIX="${TEST_TMP}/infra"
  export FIX
  export TF_LOG="${TEST_TMP}/tf.log"

  # Fixture infra tree
  mkdir -p "${FIX}/live/00-backend-bootstrap" \
           "${FIX}/live/10-management-iam" \
           "${FIX}/_common" \
           "${FIX}/environments"
  printf '# providers\n' > "${FIX}/_common/providers.tf"
  printf '# versions\n' > "${FIX}/_common/versions.tf"
  printf 'bucket = "tf-state-dev"\n'  > "${FIX}/_common/backend-dev.hcl"
  printf 'bucket = "tf-state-test"\n' > "${FIX}/_common/backend-test.hcl"
  # account_id must be present: stage.sh derives the backend's AWS_ACCESS_KEY_ID from it
  # (a 12-digit AKID is the Floci account selector). Distinct per env so tests can prove
  # the right one is picked up. The trailing comment mirrors the real tfvars.
  printf 'environment = "dev"\naccount_id  = "111111111111" # dev AKID\n'  > "${FIX}/environments/dev.tfvars"
  printf 'environment = "test"\naccount_id  = "222222222222" # test AKID\n' > "${FIX}/environments/test.tfvars"

  # Keep the shared provider cache inside the temp dir: the script defaults it to
  # ~/.terraform.d/plugin-cache, which tests must not create or write to.
  export TF_PLUGIN_CACHE_DIR="${TEST_TMP}/plugin-cache"

  # Logging terraform stub. DATA_DIR is recorded so tests can prove `validate` runs in
  # its own data dir rather than the .terraform/ that a real `init` populates.
  mkdir -p "${TEST_TMP}/bin"
  cat > "${TEST_TMP}/bin/terraform" <<'STUB'
#!/usr/bin/env bash
{ printf 'SUBCMD=%s\n' "$1"; shift; for a in "$@"; do printf 'ARG=%s\n' "$a"; done; \
  printf 'DATA_DIR=%s\n' "${TF_DATA_DIR:-}"; \
  printf 'AKID=%s\n' "${AWS_ACCESS_KEY_ID:-}"; \
  printf 'SECRET=%s\n' "${AWS_SECRET_ACCESS_KEY:-}"; \
  printf 'TFVAR=%s\n' "${TF_VAR_secret_key:-}"; \
  printf 'PROFILE=%s\n' "${AWS_PROFILE:-}"; } >> "$TF_LOG"
exit 0
STUB
  chmod +x "${TEST_TMP}/bin/terraform"
  export PATH="${TEST_TMP}/bin:${PATH}"
}

teardown() {
  [[ -n "${TEST_TMP:-}" && -d "${TEST_TMP:-}" ]] && rm -rf "${TEST_TMP}"
}

# Hermetic: the developer's real AWS_* / TF_VAR_secret_key must not leak in, or the
# credential-derivation tests would pass or fail depending on the ambient shell.
#
# TWIN_SECRET_FILE is pointed at a path that does not exist, for the same reason: it defaults
# to the dev twin's real ~/.cache/tianlu-floci/dev/account.secret, which IS present on a
# machine that has run `make dev-up`. Without this override, "no secret available" would pass
# on CI and silently stop testing anything on a developer box.
run_stage() {
  run env -u AWS_ACCESS_KEY_ID -u AWS_SECRET_ACCESS_KEY -u AWS_PROFILE \
    INFRA_ROOT="$FIX" TF_LOG="$TF_LOG" TF_VAR_secret_key=test-secret \
    TWIN_SECRET_FILE="${TEST_TMP}/absent-twin-secret" \
    bash "$STAGE_SH" "$@"
}

# Same, but the caller supplies the environment (for the credential-chain tests).
# The defaults come first so a caller-supplied assignment overrides them (env applies
# name=value operands left to right).
run_stage_env() {
  local -a envs=()
  while [[ "$1" == *=* || "$1" == -u ]]; do
    if [[ "$1" == -u ]]; then envs+=(-u "$2"); shift 2; else envs+=("$1"); shift; fi
  done
  run env -u AWS_ACCESS_KEY_ID -u AWS_SECRET_ACCESS_KEY -u AWS_PROFILE -u TF_VAR_secret_key \
    INFRA_ROOT="$FIX" TF_LOG="$TF_LOG" TWIN_SECRET_FILE="${TEST_TMP}/absent-twin-secret" \
    "${envs[@]}" bash "$STAGE_SH" "$@"
}

@test "help lists the four environments" {
  run_stage help
  [ "$status" -eq 0 ]
  [[ "$output" == *"dev test uat prod"* ]]
}

@test "init: default stage uses backend-dev.hcl and the dev/<stage> state key (F-21)" {
  run_stage init
  [ "$status" -eq 0 ]
  grep -qF 'ARG=-backend-config=' "$TF_LOG"
  grep -qF 'backend-dev.hcl' "$TF_LOG"
  grep -qF 'ARG=-backend-config=key=dev/10-management-iam/terraform.tfstate' "$TF_LOG"
}

@test "init: environment selects the matching backend + state key prefix (F-20/F-21)" {
  run_stage init test 10-management-iam
  [ "$status" -eq 0 ]
  grep -qF 'backend-test.hcl' "$TF_LOG"
  grep -qF 'ARG=-backend-config=key=test/10-management-iam/terraform.tfstate' "$TF_LOG"
}

@test "apply: uses the env var-file and NO backend-config flags (F-25)" {
  run_stage apply test
  [ "$status" -eq 0 ]
  grep -qF 'SUBCMD=apply' "$TF_LOG"
  grep -qF "ARG=-var-file=${FIX}/environments/test.tfvars" "$TF_LOG"
  ! grep -qF 'ARG=-backend-config=' "$TF_LOG"
}

@test "apply --auto-approve passes -auto-approve" {
  run_stage apply test --auto-approve
  [ "$status" -eq 0 ]
  grep -qF 'ARG=-auto-approve' "$TF_LOG"
}

@test "plan and destroy are implemented (not stubbed out)" {
  run_stage plan test
  [ "$status" -eq 0 ]
  grep -qF 'SUBCMD=plan' "$TF_LOG"
  : > "$TF_LOG"
  run_stage destroy test --auto-approve
  [ "$status" -eq 0 ]
  grep -qF 'SUBCMD=destroy' "$TF_LOG"
}

@test "bootstrap stage inits with plain 'terraform init' (no backend flags)" {
  run_stage init dev 00-backend-bootstrap
  [ "$status" -eq 0 ]
  grep -qF 'SUBCMD=init' "$TF_LOG"
  ! grep -qF 'ARG=-backend-config=' "$TF_LOG"
}

@test "missing tfvars for an environment fails early with a specific message (F-20)" {
  run_stage init uat
  [ "$status" -ne 0 ]
  [[ "$output" == *"no tfvars for environment 'uat'"* ]]
}

@test "unknown positional argument is rejected (F-22)" {
  run_stage init 20-does-not-exist
  [ "$status" -ne 0 ]
  [[ "$output" == *"unrecognized argument"* ]]
}

@test "unknown subcommand is rejected" {
  run_stage frobnicate
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown subcommand"* ]]
}

@test "init is re-runnable: an already-synced provider file is left in place without --force (F-23)" {
  # First init syncs providers.tf into the stage dir
  run_stage init test 10-management-iam
  [ "$status" -eq 0 ]
  # Diverge the stage-local providers.tf
  printf '# local edit\n' >> "${FIX}/live/10-management-iam/providers.tf"
  : > "$TF_LOG"
  run_stage init test 10-management-iam
  [ "$status" -eq 0 ]
  # Without --force the local edit survives, and init still ran
  grep -qF '# local edit' "${FIX}/live/10-management-iam/providers.tf"
  grep -qF 'SUBCMD=init' "$TF_LOG"
}

@test "fmt formats the whole infra tree, not a single stage" {
  run_stage fmt
  [ "$status" -eq 0 ]
  grep -qF 'SUBCMD=fmt' "$TF_LOG"
  grep -qF 'ARG=-recursive' "$TF_LOG"
  grep -qF "ARG=${FIX}" "$TF_LOG"
}

@test "fmt rewrites by default; --check only reports (so lint cannot mutate the tree)" {
  run_stage fmt
  [ "$status" -eq 0 ]
  ! grep -qF 'ARG=-check' "$TF_LOG"
  : > "$TF_LOG"
  run_stage fmt --check
  [ "$status" -eq 0 ]
  grep -qF 'ARG=-check' "$TF_LOG"
}

@test "validate needs no backend: passes -backend=false and no -backend-config" {
  run_stage validate test 10-management-iam
  [ "$status" -eq 0 ]
  grep -qF 'SUBCMD=validate' "$TF_LOG"
  grep -qF 'ARG=-backend=false' "$TF_LOG"
  ! grep -qF 'ARG=-backend-config=' "$TF_LOG"
}

@test "validate runs in its own data dir so it cannot disturb a real init" {
  run_stage validate test 10-management-iam
  [ "$status" -eq 0 ]
  grep -qF 'DATA_DIR=.terraform-validate' "$TF_LOG"
  # Nothing in this run may fall back to the default (empty TF_DATA_DIR) data dir.
  ! grep -qxF 'DATA_DIR=' "$TF_LOG"
}

@test "validate syncs templates for a normal stage but not for bootstrap" {
  run_stage validate test 10-management-iam
  [ "$status" -eq 0 ]
  [ -f "${FIX}/live/10-management-iam/providers.tf" ]
  [ -f "${FIX}/live/10-management-iam/versions.tf" ]
  run_stage validate test 00-backend-bootstrap
  [ "$status" -eq 0 ]
  [ ! -e "${FIX}/live/00-backend-bootstrap/providers.tf" ]
  [ ! -e "${FIX}/live/00-backend-bootstrap/versions.tf" ]
}

@test "fmt and validate are accepted subcommands" {
  run_stage help
  [ "$status" -eq 0 ]
  [[ "$output" == *"fmt"* ]]
  [[ "$output" == *"validate"* ]]
}

@test "a shared provider plugin cache is created and exported" {
  run_stage validate test 10-management-iam
  [ "$status" -eq 0 ]
  [ -d "$TF_PLUGIN_CACHE_DIR" ]
}

# --- backend credentials -----------------------------------------------------------------
# The S3 backend does not read var.account_id/var.secret_key, so stage.sh must put the
# environment's AKID into AWS_ACCESS_KEY_ID itself. Getting this wrong points a stage at
# another account's state, which surfaces only as NoSuchBucket "tf-state-<env>".

@test "init derives the backend AKID from the environment's tfvars" {
  run_stage init dev 10-management-iam
  [ "$status" -eq 0 ]
  grep -qxF 'AKID=111111111111' "$TF_LOG"
}

@test "a different environment selects that environment's AKID" {
  run_stage init test 10-management-iam
  [ "$status" -eq 0 ]
  grep -qxF 'AKID=222222222222' "$TF_LOG"
  ! grep -qxF 'AKID=111111111111' "$TF_LOG"
}

@test "the secret reaches the backend from TF_VAR_secret_key" {
  run_stage init dev 10-management-iam
  [ "$status" -eq 0 ]
  grep -qxF 'SECRET=test-secret' "$TF_LOG"
}

@test "plan/apply/destroy also get the derived credentials" {
  for sub in plan apply destroy; do
    : > "$TF_LOG"
    run_stage "$sub" dev 10-management-iam --auto-approve
    [ "$status" -eq 0 ]
    grep -qxF 'AKID=111111111111' "$TF_LOG"
  done
}

@test "an AWS_ACCESS_KEY_ID for a different account is refused, not silently used" {
  run_stage_env AWS_ACCESS_KEY_ID=999999999999 TF_VAR_secret_key=test-secret \
    init dev 10-management-iam
  [ "$status" -ne 0 ]
  [[ "$output" == *"999999999999"* ]]
  [[ "$output" == *"111111111111"* ]]
  [[ "$output" == *"another account"* ]]
  # Terraform must never have been reached.
  [ ! -s "$TF_LOG" ]
}

@test "a matching AWS_ACCESS_KEY_ID is accepted" {
  run_stage_env AWS_ACCESS_KEY_ID=111111111111 TF_VAR_secret_key=test-secret \
    init dev 10-management-iam
  [ "$status" -eq 0 ]
  grep -qxF 'AKID=111111111111' "$TF_LOG"
}

@test "no secret anywhere fails with an actionable message before terraform runs" {
  run_stage_env init dev 10-management-iam
  [ "$status" -ne 0 ]
  [[ "$output" == *"TF_VAR_secret_key"* ]]
  [ ! -s "$TF_LOG" ]
}

@test "AWS_SECRET_ACCESS_KEY is honoured when TF_VAR_secret_key is absent" {
  run_stage_env AWS_SECRET_ACCESS_KEY=from-aws-var init dev 10-management-iam
  [ "$status" -eq 0 ]
  grep -qxF 'SECRET=from-aws-var' "$TF_LOG"
}

@test "fmt and validate need no credentials at all" {
  run_stage_env fmt --check
  [ "$status" -eq 0 ]
  : > "$TF_LOG"
  run_stage_env validate dev 10-management-iam
  [ "$status" -eq 0 ]
  grep -qF 'SUBCMD=validate' "$TF_LOG"
}

@test "tfvars without an account_id fails with a specific message" {
  printf 'environment = "dev"\n' > "${FIX}/environments/dev.tfvars"
  run_stage init dev 10-management-iam
  [ "$status" -ne 0 ]
  [[ "$output" == *"account_id"* ]]
}

# ---------------------------------------------------------------------------
# Secret resolution chain
#
# The dev twin generates the account-root secret and caches it in a file; stage.sh reads
# that file so `make apply` works straight after `make dev-up` with nothing exported. Floci
# ignores the secret today, which is exactly why these need pinning: a wrong value is
# invisible until FLOCI_AUTH_VALIDATE_SIGNATURES=true is set, and then everything breaks at
# once with an error that names none of this.
# ---------------------------------------------------------------------------

@test "the twin's cached secret is used when nothing is exported" {
  printf 'twin-secret-from-file\n' > "${TEST_TMP}/twin.secret"
  run_stage_env TWIN_SECRET_FILE="${TEST_TMP}/twin.secret" init dev 10-management-iam
  [ "$status" -eq 0 ]
  grep -qxF 'SECRET=twin-secret-from-file' "$TF_LOG"
}

@test "a trailing newline in the twin secret file is stripped" {
  # A stray \r\n inside a signing key is not a syntax error, it is a signature mismatch.
  printf 'twin-secret\r\n' > "${TEST_TMP}/twin.secret"
  run_stage_env TWIN_SECRET_FILE="${TEST_TMP}/twin.secret" init dev 10-management-iam
  [ "$status" -eq 0 ]
  grep -qxF 'SECRET=twin-secret' "$TF_LOG"
}

@test "TF_VAR_secret_key beats the twin secret file" {
  printf 'twin-secret\n' > "${TEST_TMP}/twin.secret"
  run_stage_env TWIN_SECRET_FILE="${TEST_TMP}/twin.secret" TF_VAR_secret_key=from-tfvar \
    init dev 10-management-iam
  [ "$status" -eq 0 ]
  grep -qxF 'SECRET=from-tfvar' "$TF_LOG"
}

@test "AWS_SECRET_ACCESS_KEY beats both TF_VAR_secret_key and the twin file" {
  printf 'twin-secret\n' > "${TEST_TMP}/twin.secret"
  run_stage_env TWIN_SECRET_FILE="${TEST_TMP}/twin.secret" TF_VAR_secret_key=from-tfvar \
    AWS_SECRET_ACCESS_KEY=from-aws-var init dev 10-management-iam
  [ "$status" -eq 0 ]
  grep -qxF 'SECRET=from-aws-var' "$TF_LOG"
}

@test "TF_VAR_secret_key is exported for Terraform even when the secret came from the file" {
  # var.secret_key is sensitive with no default in every stage, so without this export
  # Terraform stops on an interactive prompt while the S3 backend is perfectly happy.
  printf 'twin-secret\n' > "${TEST_TMP}/twin.secret"
  run_stage_env TWIN_SECRET_FILE="${TEST_TMP}/twin.secret" init dev 10-management-iam
  [ "$status" -eq 0 ]
  grep -qxF 'TFVAR=twin-secret' "$TF_LOG"
}

@test "the backend secret and var.secret_key are always the same value" {
  run_stage_env AWS_SECRET_ACCESS_KEY=one-credential init dev 10-management-iam
  [ "$status" -eq 0 ]
  grep -qxF 'SECRET=one-credential' "$TF_LOG"
  grep -qxF 'TFVAR=one-credential' "$TF_LOG"
}

@test "with no secret source at all the error names all three, including the twin path" {
  run_stage_env TWIN_SECRET_FILE="${TEST_TMP}/nope/account.secret" init dev 10-management-iam
  [ "$status" -ne 0 ]
  [[ "$output" == *"AWS_SECRET_ACCESS_KEY"* ]]
  [[ "$output" == *"TF_VAR_secret_key"* ]]
  [[ "$output" == *"${TEST_TMP}/nope/account.secret"* ]]
  [ ! -s "$TF_LOG" ]
}

@test "an empty twin secret file is not treated as a secret" {
  : > "${TEST_TMP}/twin.secret"
  run_stage_env TWIN_SECRET_FILE="${TEST_TMP}/twin.secret" init dev 10-management-iam
  [ "$status" -ne 0 ]
  [ ! -s "$TF_LOG" ]
}

@test "an ambient AWS_PROFILE is neutralised, not passed to terraform" {
  # A profile carrying an empty `ca_bundle =` makes AWS CLI v2 reject every call, and
  # Terraform's AWS provider resolves profiles through the same chain.
  printf 'twin-secret\n' > "${TEST_TMP}/twin.secret"
  run_stage_env TWIN_SECRET_FILE="${TEST_TMP}/twin.secret" AWS_PROFILE=floci-dev \
    init dev 10-management-iam
  [ "$status" -eq 0 ]
  grep -qxF 'PROFILE=' "$TF_LOG"
}

@test "verbose reports the secret source, never the secret" {
  printf 'twin-secret\n' > "${TEST_TMP}/twin.secret"
  run_stage_env TWIN_SECRET_FILE="${TEST_TMP}/twin.secret" TF_VAR_secret_key=from-tfvar \
    init dev 10-management-iam -v
  [ "$status" -eq 0 ]
  [[ "$output" == *"secret source: TF_VAR_secret_key"* ]]
}
