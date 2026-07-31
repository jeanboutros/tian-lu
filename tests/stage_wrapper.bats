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
  printf 'environment = "dev"\n'  > "${FIX}/environments/dev.tfvars"
  printf 'environment = "test"\n' > "${FIX}/environments/test.tfvars"

  # Keep the shared provider cache inside the temp dir: the script defaults it to
  # ~/.terraform.d/plugin-cache, which tests must not create or write to.
  export TF_PLUGIN_CACHE_DIR="${TEST_TMP}/plugin-cache"

  # Logging terraform stub. DATA_DIR is recorded so tests can prove `validate` runs in
  # its own data dir rather than the .terraform/ that a real `init` populates.
  mkdir -p "${TEST_TMP}/bin"
  cat > "${TEST_TMP}/bin/terraform" <<'STUB'
#!/usr/bin/env bash
{ printf 'SUBCMD=%s\n' "$1"; shift; for a in "$@"; do printf 'ARG=%s\n' "$a"; done; \
  printf 'DATA_DIR=%s\n' "${TF_DATA_DIR:-}"; } >> "$TF_LOG"
exit 0
STUB
  chmod +x "${TEST_TMP}/bin/terraform"
  export PATH="${TEST_TMP}/bin:${PATH}"
}

teardown() {
  [[ -n "${TEST_TMP:-}" && -d "${TEST_TMP:-}" ]] && rm -rf "${TEST_TMP}"
}

run_stage() {
  run env INFRA_ROOT="$FIX" TF_LOG="$TF_LOG" bash "$STAGE_SH" "$@"
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
