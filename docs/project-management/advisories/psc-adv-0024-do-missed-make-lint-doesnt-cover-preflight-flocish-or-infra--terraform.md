# Advisory: DO missed make lint doesn't cover preflight-floci.sh or infra/ Terraform

| Field | Value |
|-------|-------|
| ID | psc-adv-0024-do-missed-make-lint-doesnt-cover-preflight-flocish-or-infra--terraform |
| Type | advisory |
| Status | accepted |
| Confidence | 90 |
| Priority | critical |
| Source ticket | psc-0003 |
| Source agent | DO-challenger |
| Source file | [docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md](docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md) |
| Created | 2026-07-30 |
| Finding ID | M-7 |

## Description
`Makefile:39` lints specific files — none is `scripts/preflight-floci.sh` or any `.tf`/`.hcl` file. SPEC-DO-010 acceptance criterion 5 requires "shellcheck on `preflight-floci.sh`" but `make lint` does not run it. The primary's own acceptance criteria reference a lint target that does not exist for the file being fixed.

## Recommended Action
Add `scripts/preflight-floci.sh` to `make lint` scope. Add a `make lint-infra` target for Terraform files.

## User Decision
accepted

## Decision Rationale
User accepted this advisory finding. Implement as recommended.

## Implementation Ticket
<filled if accepted or implemented — reference to the implementation ticket>
