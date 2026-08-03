# Convenience targets for the staged Terraform estate. Run from infra/ (or use -C infra).
#
#   make help                     every target, with what it touches (infra/scripts/help.sh)
#   make init  STAGE=<stage>      sync _common templates + terraform init
#   make plan  STAGE=<stage>
#   make apply STAGE=<stage>      preflight-gated
#   make destroy STAGE=<stage> CONFIRM=destroy
#   make plan-all / apply-all     every stage, in topological order
#   make lint-infra               fmt -check + validate; needs no credentials
#   make verify-backend           list the state bucket + lock table
#
# Stage/env selection: ENV (default dev) and STAGE (default 10-management-iam), or the
# alias form `make plan-10-management-iam`. Extra stage.sh flags go in FLAGS,
# e.g. make init FLAGS=--force / make apply FLAGS=--auto-approve
#
# The init/plan/apply/destroy/fmt/validate lifecycle is delegated to ./stage.sh, which is
# covered by tests/stage_wrapper.bats. Terraform is invoked ONLY from there, so stage and
# environment resolution, template sync and backend wiring have exactly one implementation.
# This file adds what stage.sh has no notion of: the preflight gate, the *-all loops, the
# credential check, and the reporting helpers.
#
# Requires: terraform >= 1.15.8, aws CLI v2, a running Floci on :4566, and
#           TF_VAR_secret_key exported (see `make help`).
#
# NOTE: written for GNU Make 3.81 (the version macOS ships). No .ONESHELL, so multi-line
# recipes use explicit `\` continuations.

SHELL    := /bin/bash
STAGE_SH := ./stage.sh
PREFLIGHT := ../scripts/preflight-floci.sh

ENV   ?= dev
STAGE ?= 10-management-iam
FLAGS ?=

# Stages in apply order. The NN- prefix makes a lexicographic sort a topological one, so
# stages 20-60 are picked up with no edit here. Keyed off main.tf rather than `live/*` so
# an empty scaffold directory can never be fed to apply-all.
STAGES ?= $(sort $(notdir $(patsubst %/main.tf,%,$(wildcard live/*/main.tf))))

# Where `make dev-up` caches the account-root secret. stage.sh reads the same file as the
# last link of its secret chain; this is here so the guard below agrees with it, and so the
# preflight gate authenticates with the real credential rather than the literal "test".
TWIN_SECRET_FILE ?= $(HOME)/.cache/tianlu-floci/dev/account.secret

# Derived from the environment's tfvars so they cannot drift from the Terraform config.
# Recursive (=) not simple (:=), so an ENV override on the command line is picked up.
AKID     = $(shell awk -F'"' '/^[[:space:]]*account_id[[:space:]]*=/     {print $$2}' environments/$(ENV).tfvars 2>/dev/null)
REGION   = $(shell awk -F'"' '/^[[:space:]]*region[[:space:]]*=/         {print $$2}' environments/$(ENV).tfvars 2>/dev/null)
ENDPOINT = $(shell awk -F'"' '/^[[:space:]]*floci_endpoint[[:space:]]*=/ {print $$2}' environments/$(ENV).tfvars 2>/dev/null)

# Prerequisites must run in the order written (creds-guard and preflight before terraform),
# and the *-all loops must not interleave stages.
.NOTPARALLEL:

.PHONY: help init plan apply destroy fmt fmt-check validate \
        creds-guard preflight clean verify-backend \
        init-all plan-all apply-all validate-all lint-infra

help:
	@./scripts/help.sh

# --- lifecycle (delegated to stage.sh) --------------------------------------------------

init:
	$(STAGE_SH) init $(ENV) $(STAGE) $(FLAGS)

plan: creds-guard
	$(STAGE_SH) plan $(ENV) $(STAGE) $(FLAGS)

apply: creds-guard preflight
	$(STAGE_SH) apply $(ENV) $(STAGE) $(FLAGS)

destroy: creds-guard preflight
	@[[ '$(CONFIRM)' == 'destroy' ]] || { \
	  printf 'refusing to destroy %s/%s without CONFIRM=destroy\n' '$(ENV)' '$(STAGE)' >&2; \
	  exit 1; }
	$(STAGE_SH) destroy $(ENV) $(STAGE) $(FLAGS)

fmt:
	$(STAGE_SH) fmt

fmt-check:
	$(STAGE_SH) fmt --check

validate:
	$(STAGE_SH) validate $(ENV) $(STAGE)

# --- guards -----------------------------------------------------------------------------

# Every stage declares `variable "secret_key"` as sensitive with no default
# (_common/providers.tf, 00-backend-bootstrap/main.tf), so Terraform would otherwise stop on
# an interactive prompt. stage.sh enforces this too, but checking here fails before the slow,
# account-mutating preflight gate runs.
#
# The three accepted sources must match stage.sh's chain exactly -- a guard that is stricter
# than the thing it guards refuses work that would have succeeded.
# The AKID needs no check: stage.sh derives it from environments/$(ENV).tfvars.
creds-guard:
	@[[ -n "$${AWS_SECRET_ACCESS_KEY:-}" || -n "$${TF_VAR_secret_key:-}" \
	   || -s '$(TWIN_SECRET_FILE)' ]] || { \
	  printf 'error: no account secret available. Tried, in order:\n' >&2; \
	  printf '         AWS_SECRET_ACCESS_KEY, TF_VAR_secret_key, %s\n\n' '$(TWIN_SECRET_FILE)' >&2; \
	  printf '  Normally you export nothing: `make dev-up` (from the repo root) writes that\n' >&2; \
	  printf '  file, and stage.sh reads it. If the twin is running but the file is missing,\n' >&2; \
	  printf '  `make dev-env` regenerates it.\n\n' >&2; \
	  printf '  To override: export TF_VAR_secret_key=<secret>\n\n' >&2; \
	  printf '  Every stage declares var.secret_key (sensitive, no default), and the S3\n' >&2; \
	  printf '  backend needs a credential of its own.\n' >&2; \
	  exit 1; }

# infra/AGENTS.md: never apply without G1/G2/G3. G1 (authorization actually enforced) is a
# hard stop -- without it every IAM lesson in this estate is a false demo.
#
# The endpoint/region/AKID are passed explicitly: preflight-floci.sh defaults to the DEV
# account, so an un-parameterised run would gate a uat/prod apply against dev.
#
# The ambient AWS_* variables are cleared rather than inherited. A leftover AWS_PROFILE is
# the specific failure this estate has already hit twice: a profile can carry an empty
# `ca_bundle =`, which AWS CLI v2 rejects client-side ("Invalid CA bundle ... empty or
# whitespace-only string") before any request is sent -- and because preflight-floci.sh hides
# stderr, that surfaces as the misleading "could not create access key (is IAM up?)".
# Identity here comes from the tfvars and the twin's secret, never from an ambient profile.
#
# The secret is resolved in the recipe rather than in a make variable so the value never
# enters make's variable space or `make -n` output. Same chain as stage.sh; "test" is the
# last-resort default preflight-floci.sh itself uses.
preflight:
	@if [[ '$(SKIP_PREFLIGHT)' == '1' ]]; then \
	  printf 'preflight SKIPPED (SKIP_PREFLIGHT=1) -- G1/G2/G3 unverified.\n' >&2; \
	else \
	  curl -fsS -m 5 -o /dev/null '$(ENDPOINT)' 2>/dev/null || { \
	    printf 'error: Floci is not answering at %s -- start it (make dev-up) or pass SKIP_PREFLIGHT=1.\n' '$(ENDPOINT)' >&2; \
	    exit 1; }; \
	  secret="$${AWS_SECRET_ACCESS_KEY:-$${TF_VAR_secret_key:-}}"; \
	  if [[ -z "$$secret" && -s '$(TWIN_SECRET_FILE)' ]]; then \
	    secret="$$(tr -d '\r\n' < '$(TWIN_SECRET_FILE)')"; \
	  fi; \
	  env -u AWS_PROFILE -u AWS_DEFAULT_PROFILE -u AWS_ACCESS_KEY_ID -u AWS_SECRET_ACCESS_KEY \
	      -u AWS_SESSION_TOKEN -u AWS_CA_BUNDLE -u AWS_REGION \
	    DEV_AKID='$(AKID)' FLOCI_ACCOUNT_SECRET="$${secret:-test}" \
	    AWS_ENDPOINT_URL='$(ENDPOINT)' AWS_DEFAULT_REGION='$(REGION)' $(PREFLIGHT); \
	fi

# --- whole-estate loops -----------------------------------------------------------------
# Written out explicitly rather than via the pattern rules below: GNU Make prefers an
# explicit target over a pattern rule, which is what stops `plan-all` being interpreted as
# `plan-%` with STAGE=all. Do not "simplify" these away.

init-all:
	@for s in $(STAGES); do \
	  printf '\n=== init %s / %s ===\n' '$(ENV)' "$$s"; \
	  $(MAKE) --no-print-directory init ENV=$(ENV) STAGE="$$s" FLAGS='$(FLAGS)' || exit 1; \
	done

plan-all:
	@for s in $(STAGES); do \
	  printf '\n=== plan %s / %s ===\n' '$(ENV)' "$$s"; \
	  $(MAKE) --no-print-directory plan ENV=$(ENV) STAGE="$$s" FLAGS='$(FLAGS)' || exit 1; \
	done

# preflight runs once here, then is suppressed per-stage: it creates and deletes a probe
# IAM user and DynamoDB table each time, which is wasteful to repeat per stage.
apply-all: preflight
	@for s in $(STAGES); do \
	  printf '\n=== apply %s / %s ===\n' '$(ENV)' "$$s"; \
	  $(MAKE) --no-print-directory apply ENV=$(ENV) STAGE="$$s" FLAGS='$(FLAGS)' SKIP_PREFLIGHT=1 || exit 1; \
	done

validate-all:
	@for s in $(STAGES); do \
	  printf '\n=== validate %s ===\n' "$$s"; \
	  $(MAKE) --no-print-directory validate ENV=$(ENV) STAGE="$$s" || exit 1; \
	done

# Safe to run with Floci down and without credentials -- suitable for a pre-commit hook.
lint-infra: fmt-check validate-all

# --- housekeeping -----------------------------------------------------------------------

# Drops the generated template copies and the validate data dir. Leaves .terraform/ and
# state untouched; the next `make init` restores the templates via stage.sh sync_templates.
clean:
	@rm -f  live/*/providers.tf live/*/versions.tf
	@rm -rf live/*/.terraform-validate
	@printf 'removed generated providers.tf/versions.tf and validate data dirs.\n'
	@printf 'restore with: make init STAGE=<stage>\n'

# The remote-state bucket and lock table that 00-backend-bootstrap creates.
# Same secret chain and same profile-clearing as `preflight`, for the same reasons: this is
# the command you reach for when `init` reports NoSuchBucket, so it must not be able to
# authenticate as a different account than the stage did and confirm the wrong answer.
verify-backend:
	@printf 'account %s at %s (%s)\n\n' '$(AKID)' '$(ENDPOINT)' '$(REGION)'
	@secret="$${AWS_SECRET_ACCESS_KEY:-$${TF_VAR_secret_key:-}}"; \
	if [[ -z "$$secret" && -s '$(TWIN_SECRET_FILE)' ]]; then \
	  secret="$$(tr -d '\r\n' < '$(TWIN_SECRET_FILE)')"; \
	fi; \
	run() { env -u AWS_PROFILE -u AWS_DEFAULT_PROFILE -u AWS_SESSION_TOKEN -u AWS_CA_BUNDLE \
	  AWS_ACCESS_KEY_ID='$(AKID)' AWS_SECRET_ACCESS_KEY="$${secret:-test}" \
	  aws --endpoint-url '$(ENDPOINT)' --region '$(REGION)' "$$@"; }; \
	run s3api list-buckets --query 'Buckets[].Name' --output table; \
	run dynamodb list-tables --output table

# --- per-stage aliases ------------------------------------------------------------------
# `make plan-10-management-iam` as a shorthand for `make plan STAGE=10-management-iam`.
# An ENV= given on the command line propagates to the sub-make automatically.

init-%:
	@$(MAKE) --no-print-directory init STAGE=$* FLAGS='$(FLAGS)'

plan-%:
	@$(MAKE) --no-print-directory plan STAGE=$* FLAGS='$(FLAGS)'

apply-%:
	@$(MAKE) --no-print-directory apply STAGE=$* FLAGS='$(FLAGS)'

destroy-%:
	@$(MAKE) --no-print-directory destroy STAGE=$* FLAGS='$(FLAGS)' CONFIRM='$(CONFIRM)'

validate-%:
	@$(MAKE) --no-print-directory validate STAGE=$*
