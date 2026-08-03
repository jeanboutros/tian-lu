# Decision: DO SPEC-DO-014 lint check should be terraform validate, not shell diff

| Field | Value |
|-------|-------|
| ID | psc-dec-0023-do-spec-do-014-lint-check-should-be-terraform-validate-not-shell-diff |
| Type | decision |
| Status | backlog |
| Confidence | 75 |
| Priority | medium |
| Source ticket | psc-0003 |
| Source agent | DO vs DO-challenger |
| Source file | [docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md](docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md) |
| Created | 2026-07-30 |
| Finding ID | D-23 |

## Description
Recommends "a lint check (shell script or Makefile target) that verifies every `infra/live/*/providers.tf` matches `_common/providers.tf` in its structural elements." A shell-based structural diff of HCL is brittle (whitespace, block ordering, comments). The authoritative check is `terraform fmt -check` + `terraform validate` + optionally `checkov`. CI does not currently install Terraform.

## Recommended Action
Specify `terraform fmt -check` + `terraform validate` as the lint mechanism. Acknowledge the new CI capability required (Terraform install in `test.yml`).

## User Decision
backlog

## Decision Rationale
User ruled: Backlogged (confidence 75 below fast-track threshold of 80). Deferred to future work.

## Implementation Ticket
<filled if accepted or implemented — reference to the implementation ticket>
