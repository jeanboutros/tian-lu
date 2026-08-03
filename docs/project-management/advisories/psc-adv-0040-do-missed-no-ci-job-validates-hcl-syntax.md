# Advisory: DO missed no CI job validates HCL syntax

| Field | Value |
|-------|-------|
| ID | psc-adv-0040-do-missed-no-ci-job-validates-hcl-syntax |
| Type | advisory |
| Status | backlog |
| Confidence | 82 |
| Priority | high |
| Source ticket | psc-0003 |
| Source agent | DO-challenger |
| Source file | [docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md](docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md) |
| Created | 2026-07-30 |
| Finding ID | M-23 |

## Description
CI (`test.yml`) installs only `shellcheck` and `bats`. No `terraform fmt -check`, no `terraform validate`. SPEC-DO-014–017 all prescribe changes to `.tf`/`.hcl` files and list `terraform validate` as acceptance criteria, but neither capability exists in CI.

## Recommended Action
Add a `terraform-validate` job to `test.yml` that installs Terraform, runs `terraform fmt -check -recursive` and `terraform -chdir=infra/live/<stage> validate` for each stage.

## User Decision
backlog

## Decision Rationale
User backlogged this advisory finding (part of remaining 64 findings). Deferred to future work.

## Implementation Ticket
<filled if accepted or implemented — reference to the implementation ticket>
