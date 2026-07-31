#!/usr/bin/env bash
set -euo pipefail

cat <<'EOF'

Tianlu infra — staged Terraform landing zone on Floci

SELECTING WHAT TO ACT ON:
  ENV=<env>        dev | test | uat | prod          (default: dev)
  STAGE=<stage>    a directory under infra/live/    (default: 10-management-iam)
  FLAGS=<flags>    passed through to stage.sh: --force, --auto-approve, -v, --debug

    make plan STAGE=00-backend-bootstrap
    make apply ENV=dev STAGE=10-management-iam
    make plan-10-management-iam            # alias form of the same thing

LIFECYCLE (delegated to ./stage.sh, which is what actually calls terraform):
  init             Sync providers.tf/versions.tf from _common/, then terraform init.
                     For 00-backend-bootstrap: plain init (local state, no backend flags).
                     Every other stage: -backend-config=_common/backend-$ENV.hcl plus
                     key=$ENV/$STAGE/terraform.tfstate.
                     Affects: live/$STAGE/{providers.tf,versions.tf,.terraform/}.
                     Override: make init FLAGS=--force  (overwrite a drifted copy)
                     When to use: first run of a stage, or after editing _common/.
  plan             terraform plan with -var-file=environments/$ENV.tfvars.
                     Requires: TF_VAR_secret_key.
  apply            terraform apply. Runs the preflight gate first.
                     Affects: real resources in the Floci account for $ENV.
                     Requires: TF_VAR_secret_key, Floci up, G1/G3 passing.
                     Override: make apply FLAGS=--auto-approve
                               make apply SKIP_PREFLIGHT=1   (skips the G1/G3 gate)
  destroy          terraform destroy. Refuses unless CONFIRM=destroy is given.
                     Affects: DELETES the stage's resources. Not reversible.
                     When to use: tearing a stage down to rebuild it.

WHOLE ESTATE (stages run in NN- order, which is topological order):
  init-all         init every stage under live/.
  plan-all         plan every stage. Downstream stages read upstream outputs via remote
                     state, so an upstream change must be re-planned downstream.
  apply-all        apply every stage in order. Runs preflight once, not per stage.
                     Affects: the whole estate for $ENV.
  validate-all     validate every stage.

CHECKS (no credentials, no backend, safe with Floci down):
  fmt              terraform fmt across the whole infra/ tree (not just one stage).
                     Affects: rewrites unformatted .tf/.tfvars files in place.
  fmt-check        Report unformatted files instead of rewriting. Non-zero exit if any.
  validate         Validate one stage. Uses -backend=false and a separate
                     .terraform-validate/ data dir, so it cannot disturb a real init.
  lint-infra       fmt-check + validate-all. Suitable for a pre-commit hook or CI.
                     When to use: before committing any .tf change.

REPORTING & HOUSEKEEPING:
  verify-backend   List the S3 buckets and DynamoDB tables in the $ENV account — the
                     tf-state-$ENV bucket and tf-locks-$ENV table that
                     00-backend-bootstrap creates.
                     When to use: confirm bootstrap worked before initialising any
                     S3-backed stage.
  clean            Delete the generated live/*/{providers.tf,versions.tf} and every
                     .terraform-validate/. Leaves .terraform/ and state alone.
                     When to use: prove the templates regenerate, or clear drifted copies.

GENERATED FILES:
  live/<stage>/providers.tf and versions.tf are COPIES of infra/_common/, made by
  `make init`, and are git-ignored. infra/_common/ is the single source of truth —
  edit there and re-run `make init`. A copy that has drifted is left alone with a
  warning; `make init FLAGS=--force` overwrites it. 00-backend-bootstrap is exempt:
  it declares its own provider inline because it creates the backend the others use.

CREDENTIALS:
  Every stage declares var.secret_key (sensitive, no default), so export it first:

    source ~/.cache/tianlu-twin/dev-credentials.env
    export TF_VAR_secret_key="$DEV_BOOTSTRAP_SECRET"

  If the dev twin has never run, the bootstrap credential is: TF_VAR_secret_key=floci

PREREQUISITES:
  terraform >= 1.15.8, aws CLI v2, and a Floci instance on the endpoint named in
  environments/$ENV.tfvars (default http://localhost:4566 — see `make dev-up` in the
  repo root Makefile).

EOF
