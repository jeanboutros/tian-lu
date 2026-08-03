#!/usr/bin/env bash
# infra/stage.sh — drive one Terraform stage (init/plan/apply/destroy) for one environment.
#
# Environments (= Floci accounts, §4.1): dev | test | uat | prod.
# Stages are discovered from infra/live/<stage>/ so the script never drifts from the tree.
# Paths resolve from the script's own location, so it runs from any working directory
# (clone, rename, or git worktree).
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
# INFRA_ROOT is overridable so tests can point the script at a fixture tree.
readonly INFRA_ROOT="${INFRA_ROOT:-$SCRIPT_DIR}"
readonly LIVE_DIR="${INFRA_ROOT}/live"
readonly COMMON_DIR="${INFRA_ROOT}/_common"
readonly ENV_DIR="${INFRA_ROOT}/environments"
readonly BOOTSTRAP_STAGE="00-backend-bootstrap"

readonly ENVIRONMENTS=(dev test uat prod)

# Data dir for `validate`: kept separate from .terraform/ so a credential-free validate
# can never disturb a working `init` (which records the S3 backend in .terraform/).
readonly VALIDATE_DATA_DIR=".terraform-validate"

# The dev twin generates the account-root secret (openssl rand -hex 32) and caches it here
# (mock-server/dev-twin.sh:_ensure_account_secret). Read the real one rather than asking the
# operator to invent a matching value: Floci ignores the secret today
# (docs/issues/floci-signature-validation-ignored.md), so a wrong one is invisible -- but the
# moment FLOCI_AUTH_VALIDATE_SIGNATURES=true is set, an invented secret fails every call with
# an error that names neither the cause nor this file.
# Overridable so tests can point at a fixture.
readonly TWIN_SECRET_FILE="${TWIN_SECRET_FILE:-${HOME}/.cache/tianlu-floci/dev/account.secret}"

STAGE_NAME="${STAGE_NAME:-10-management-iam}"
ENVIRONMENT="dev"
VERBOSE=false
FORCE=false
DEBUG=false
AUTO_APPROVE=false
CHECK=false
SUBCOMMAND=""
TF_ARGS=()

discover_stages() {
  local d
  for d in "${LIVE_DIR}"/*/; do
    [[ -d "$d" ]] && basename "$d"
  done
}

usage() {
  local envs stages
  envs="$(IFS=' '; echo "${ENVIRONMENTS[*]}")"
  stages="$(discover_stages | paste -sd' ' -)"
  cat <<EOF
usage: $(basename "$0") <init|plan|apply|destroy|fmt|validate|help> [environment] [stage] [flags]

  environment    one of: ${envs} (default: dev)
  stage          one of the directories under infra/live/ (default: ${STAGE_NAME})
                 available: ${stages}

  fmt            format every .tf/.tfvars file under infra/ (tree-wide, not per-stage)
  validate       check one stage's config; needs no credentials and no backend

  -v, --verbose      enable command tracing (set -x)
  --force            overwrite an already-synced providers.tf/versions.tf during init
  --auto-approve     pass -auto-approve to apply/destroy
  --check            fmt only: report unformatted files instead of rewriting them
  --debug            print the resolved configuration before running
EOF
}

is_valid_env() {
  local e="$1" x
  for x in "${ENVIRONMENTS[@]}"; do [[ "$x" == "$e" ]] && return 0; done
  return 1
}

is_valid_stage() {
  local s="$1" x
  while IFS= read -r x; do [[ "$x" == "$s" ]] && return 0; done < <(discover_stages)
  return 1
}

check_terraform_installed() {
  command -v terraform >/dev/null 2>&1 || {
    echo "error: terraform is not installed" >&2
    exit 1
  }
}

# Provider binaries are big (the AWS provider alone is ~776MB) and Terraform keeps a
# private copy per stage per data dir. A shared cache means each version is downloaded
# and stored once for the whole estate, which also makes VALIDATE_DATA_DIR nearly free.
setup_plugin_cache() {
  export TF_PLUGIN_CACHE_DIR="${TF_PLUGIN_CACHE_DIR:-${HOME}/.terraform.d/plugin-cache}"
  mkdir -p "$TF_PLUGIN_CACHE_DIR"
}

# Fail early with a specific message when the environment's input files are absent,
# rather than letting Terraform report a confusing file-read error later.
assert_env_files() {
  [[ -f "${ENV_DIR}/${ENVIRONMENT}.tfvars" ]] || {
    echo "error: no tfvars for environment '${ENVIRONMENT}' (expected ${ENV_DIR}/${ENVIRONMENT}.tfvars)" >&2
    exit 1
  }
  if [[ "$STAGE_NAME" != "$BOOTSTRAP_STAGE" ]]; then
    [[ -f "${COMMON_DIR}/backend-${ENVIRONMENT}.hcl" ]] || {
      echo "error: no backend config for environment '${ENVIRONMENT}' (expected ${COMMON_DIR}/backend-${ENVIRONMENT}.hcl)" >&2
      exit 1
    }
  fi
}

cd_stage() {
  cd "${LIVE_DIR}/${STAGE_NAME}" 2>/dev/null || {
    echo "error: stage directory not found: ${LIVE_DIR}/${STAGE_NAME}" >&2
    exit 1
  }
}

# The S3 backend does NOT read var.account_id/var.secret_key -- those configure only the
# `provider "aws"` block. The backend resolves credentials through the standard AWS chain,
# so without help `init` authenticates as whatever happens to be in the environment. Since a
# 12-digit AKID *is* the Floci account selector, a missing or stale one silently points the
# stage at a different account's state (symptom: NoSuchBucket "tf-state-<env>").
#
# So: the AKID comes from the environment's tfvars, and the secret from the chain below
# (ending at the dev twin's own cached secret). Both are exported rather than written into
# backend-<env>.hcl -- that file is committed, and Terraform copies backend config verbatim
# into .terraform/ and plan files, which would persist the secret in cleartext.
export_account_credentials() {
  local akid
  akid="$(awk -F'"' '/^[[:space:]]*account_id[[:space:]]*=/ {print $2; exit}' \
    "${ENV_DIR}/${ENVIRONMENT}.tfvars")"
  [[ -n "$akid" ]] || {
    echo "error: could not read account_id from ${ENV_DIR}/${ENVIRONMENT}.tfvars" >&2
    exit 1
  }

  # An AKID already set for a different account is a footgun, not a convenience: it would
  # send this stage's state to another account. Refuse rather than silently disagree.
  if [[ -n "${AWS_ACCESS_KEY_ID:-}" && "${AWS_ACCESS_KEY_ID}" != "$akid" ]]; then
    printf 'error: AWS_ACCESS_KEY_ID=%s but %s.tfvars sets account_id=%s.\n' \
      "$AWS_ACCESS_KEY_ID" "$ENVIRONMENT" "$akid" >&2
    printf '       Unset AWS_ACCESS_KEY_ID (it is derived from the tfvars) or fix the mismatch;\n' >&2
    printf '       continuing would read and write another account'"'"'s Terraform state.\n' >&2
    exit 1
  fi

  # An ambient AWS_PROFILE must not survive. It is not just a second opinion on identity:
  # a profile also carries TRANSPORT config, and a `ca_bundle =` with an empty value makes
  # AWS CLI v2 and the Terraform AWS provider fail every call client-side ("Invalid CA
  # bundle ... empty or whitespace-only string") before a request is sent. An older version
  # of mock-server/dev-twin.sh left exactly such a profile in ~/.aws, and it cost two
  # debugging sessions -- once as NoSuchBucket "tf-state-dev" (wrong account), once as
  # preflight's "could not create access key (is IAM up?)". Identity here comes from the
  # tfvars and the resolved secret, nothing else.
  unset AWS_PROFILE AWS_DEFAULT_PROFILE AWS_SESSION_TOKEN

  export AWS_ACCESS_KEY_ID="$akid"

  # Resolve the secret once from an explicit precedence chain. The twin's cached secret is
  # the last resort rather than the first so an operator can always override it, but it is
  # what makes `make apply` work with nothing exported after `make dev-up`.
  local secret secret_src
  if [[ -n "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
    secret="$AWS_SECRET_ACCESS_KEY"
    secret_src="AWS_SECRET_ACCESS_KEY"
  elif [[ -n "${TF_VAR_secret_key:-}" ]]; then
    secret="$TF_VAR_secret_key"
    secret_src="TF_VAR_secret_key"
  elif [[ -s "$TWIN_SECRET_FILE" ]]; then
    # Strip the trailing newline: a stray \r\n inside a signing key is not a syntax error,
    # it is a signature mismatch -- silent today, and unattributable once signatures are on.
    secret="$(tr -d '\r\n' < "$TWIN_SECRET_FILE")"
    secret_src="$TWIN_SECRET_FILE"
  else
    echo "error: no account secret available. Tried, in order:" >&2
    echo "         AWS_SECRET_ACCESS_KEY, TF_VAR_secret_key, ${TWIN_SECRET_FILE}" >&2
    echo "       Normally you export nothing -- \`make dev-up\` writes the twin secret file." >&2
    echo "       Otherwise: export TF_VAR_secret_key=<secret>" >&2
    echo "       Every stage declares var.secret_key, and the S3 backend needs one too." >&2
    exit 1
  fi

  # Both, from one value: the S3 backend authenticates through the standard AWS chain, while
  # `provider "aws"` reads var.secret_key -- declared sensitive with no default in every
  # stage, so an unset TF_VAR_secret_key stops Terraform on an interactive prompt even when
  # the backend is perfectly happy. They must be the same account-root credential.
  export AWS_SECRET_ACCESS_KEY="$secret"
  export TF_VAR_secret_key="$secret"

  # The source, never the value. (`-v` also enables set -x, which traces the value anyway --
  # that is what a debug flag is for, but do not add a second leak on the default path.)
  [[ "$VERBOSE" == true ]] && printf 'secret source: %s\n' "$secret_src" >&2
  return 0
}

# Sync providers.tf/versions.tf from _common independently of --force: a missing file is
# always restored; a diverged file is overwritten only with --force, else left with a warning.
sync_templates() {
  [[ "$STAGE_NAME" == "$BOOTSTRAP_STAGE" ]] && return 0
  local f
  for f in providers.tf versions.tf; do
    if [[ ! -f "$f" ]]; then
      cp "${COMMON_DIR}/${f}" .
      printf 'synced %s from _common\n' "$f" >&2
    elif ! cmp -s "$f" "${COMMON_DIR}/${f}"; then
      if [[ "$FORCE" == true ]]; then
        cp "${COMMON_DIR}/${f}" .
        printf 'overwrote %s from _common (--force)\n' "$f" >&2
      else
        printf 'warning: %s differs from _common/%s; leaving it (use --force to overwrite)\n' "$f" "$f" >&2
      fi
    fi
  done
}

# -backend-config is init-only; plan/apply/destroy take -var-file only.
build_init_args() {
  TF_ARGS=()
  [[ "$STAGE_NAME" == "$BOOTSTRAP_STAGE" ]] && return 0
  TF_ARGS=(
    "-backend-config=${COMMON_DIR}/backend-${ENVIRONMENT}.hcl"
    "-backend-config=key=${ENVIRONMENT}/${STAGE_NAME}/terraform.tfstate"
  )
}

build_var_args() {
  TF_ARGS=("-var-file=${ENV_DIR}/${ENVIRONMENT}.tfvars")
  { [[ "$AUTO_APPROVE" == true ]] && [[ "$SUBCOMMAND" == "apply" || "$SUBCOMMAND" == "destroy" ]]; } \
    && TF_ARGS+=("-auto-approve")
  return 0
}

cmd_init() {
  cd_stage
  assert_env_files
  export_account_credentials
  sync_templates
  if [[ "$STAGE_NAME" == "$BOOTSTRAP_STAGE" ]]; then
    terraform init
  else
    build_init_args
    terraform init "${TF_ARGS[@]}"
  fi
  echo "Init complete for ${ENVIRONMENT}/${STAGE_NAME}."
}

cmd_plan() {
  cd_stage
  assert_env_files
  export_account_credentials
  build_var_args
  terraform plan "${TF_ARGS[@]}"
}

cmd_apply() {
  cd_stage
  assert_env_files
  export_account_credentials
  build_var_args
  terraform apply "${TF_ARGS[@]}"
}

cmd_destroy() {
  cd_stage
  assert_env_files
  export_account_credentials
  build_var_args
  terraform destroy "${TF_ARGS[@]}"
}

# fmt is deliberately tree-wide rather than per-stage: `make lint-infra` has to cover
# _common/ and environments/ as well as every root under live/.
cmd_fmt() {
  local args=(-recursive)
  [[ "$CHECK" == true ]] && args+=(-check -diff)
  terraform fmt "${args[@]}" "$INFRA_ROOT"
}

# validate needs neither credentials nor a backend, so it stays runnable with Floci down
# and in CI. -backend=false skips backend init; the separate data dir keeps the provider
# set for validation away from the one `init` populated for real runs.
cmd_validate() {
  cd_stage
  assert_env_files
  sync_templates
  TF_DATA_DIR="$VALIDATE_DATA_DIR" terraform init -backend=false -input=false >/dev/null
  TF_DATA_DIR="$VALIDATE_DATA_DIR" terraform validate
}

print_debug_info() {
  printf 'Resolved configuration:\n' >&2
  printf '  subcommand:  %s\n' "$SUBCOMMAND" >&2
  printf '  environment: %s\n' "$ENVIRONMENT" >&2
  printf '  stage:       %s\n' "$STAGE_NAME" >&2
  printf '  force:       %s\n' "$FORCE" >&2
  printf '  auto-approve:%s\n' "$AUTO_APPROVE" >&2
  printf '  infra root:  %s\n' "$INFRA_ROOT" >&2
}

parse_args() {
  [[ $# -eq 0 ]] && { usage >&2; exit 1; }
  SUBCOMMAND="$1"; shift
  case "$SUBCOMMAND" in
    init | plan | apply | destroy | fmt | validate | help) ;;
    *) echo "error: unknown subcommand '${SUBCOMMAND}'" >&2; usage >&2; exit 1 ;;
  esac

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -v | --verbose) VERBOSE=true ;;
      --force) FORCE=true ;;
      --auto-approve) AUTO_APPROVE=true ;;
      --check) CHECK=true ;;
      --debug) DEBUG=true ;;
      *)
        if is_valid_env "$1"; then
          ENVIRONMENT="$1"
        elif is_valid_stage "$1"; then
          STAGE_NAME="$1"
        else
          echo "error: unrecognized argument '$1' (not a known environment or stage)" >&2
          usage >&2
          exit 1
        fi
        ;;
    esac
    shift
  done
}

main() {
  parse_args "$@"
  [[ "$VERBOSE" == true ]] && set -x
  [[ "$DEBUG" == true ]] && print_debug_info
  [[ "$SUBCOMMAND" == "help" ]] && { usage; exit 0; }
  check_terraform_installed
  setup_plugin_cache
  case "$SUBCOMMAND" in
    init) cmd_init ;;
    plan) cmd_plan ;;
    apply) cmd_apply ;;
    destroy) cmd_destroy ;;
    fmt) cmd_fmt ;;
    validate) cmd_validate ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
