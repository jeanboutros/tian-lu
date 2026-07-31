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
# (_common/providers.tf, 00-backend-bootstrap/main.tf), so Terraform would otherwise stop
# on an interactive prompt. Fail with the fix instead.
creds-guard:
	@[[ -n "$${TF_VAR_secret_key:-}" ]] || { \
	  printf 'error: TF_VAR_secret_key is not set.\n' >&2; \
	  printf '  Every stage declares var.secret_key (sensitive, no default).\n\n' >&2; \
	  printf '  source ~/.cache/tianlu-twin/dev-credentials.env\n' >&2; \
	  printf '  export TF_VAR_secret_key="$$DEV_BOOTSTRAP_SECRET"\n\n' >&2; \
	  printf '  If the dev twin has never run: export TF_VAR_secret_key=floci\n' >&2; \
	  exit 1; }

# infra/AGENTS.md: never apply without G1/G2/G3. G1 (authorization actually enforced) is a
# hard stop -- without it every IAM lesson in this estate is a false demo.
# The endpoint/region/AKID are passed explicitly: preflight-floci.sh defaults to the DEV
# account, so an un-parameterised run would gate a uat/prod apply against dev.
preflight:
	@if [[ '$(SKIP_PREFLIGHT)' == '1' ]]; then \
	  printf 'preflight SKIPPED (SKIP_PREFLIGHT=1) -- G1/G2/G3 unverified.\n' >&2; \
	else \
	  curl -fsS -m 5 -o /dev/null '$(ENDPOINT)' 2>/dev/null || { \
	    printf 'error: Floci is not answering at %s -- start it (make dev-up) or pass SKIP_PREFLIGHT=1.\n' '$(ENDPOINT)' >&2; \
	    exit 1; }; \
	  DEV_AKID='$(AKID)' AWS_ENDPOINT_URL='$(ENDPOINT)' AWS_DEFAULT_REGION='$(REGION)' $(PREFLIGHT); \
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
verify-backend:
	@printf 'account %s at %s (%s)\n\n' '$(AKID)' '$(ENDPOINT)' '$(REGION)'
	@AWS_ACCESS_KEY_ID='$(AKID)' AWS_SECRET_ACCESS_KEY="$${TF_VAR_secret_key:-test}" \
	  aws --endpoint-url '$(ENDPOINT)' --region '$(REGION)' \
	  s3api list-buckets --query 'Buckets[].Name' --output table
	@AWS_ACCESS_KEY_ID='$(AKID)' AWS_SECRET_ACCESS_KEY="$${TF_VAR_secret_key:-test}" \
	  aws --endpoint-url '$(ENDPOINT)' --region '$(REGION)' \
	  dynamodb list-tables --output table

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
