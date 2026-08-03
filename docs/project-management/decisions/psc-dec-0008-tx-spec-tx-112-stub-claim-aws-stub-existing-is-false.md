# Decision: TX SPEC-TX-112 stub claim 'aws stub (existing)' is false

| Field | Value |
|-------|-------|
| ID | psc-dec-0008-tx-spec-tx-112-stub-claim-aws-stub-existing-is-false |
| Type | decision |
| Status | resolved: challenger |
| Confidence | 98 |
| Priority | critical |
| Source ticket | psc-0003 |
| Source agent | TX vs TX-challenger |
| Source file | [docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md](docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md) |
| Created | 2026-07-30 |
| Finding ID | D-8 |

## Description
Repeatedly asserts an `aws` stub already exists in `tests/stubs/bin/` as "a symlink to `_stub`." Verified: `tests/stubs/bin/` has 19 entries — there is no `aws` symlink. SPEC-TX-112, 113, and 114 all depend on an `aws` stub that does not exist and must be created from scratch with per-subcommand control.

## Recommended Action
Create the `aws` stub before any preflight test is written. Specify it as a dedicated subcommand-aware stub (like `tests/stubs/bin/podman`), not a one-line symlink.

## User Decision
resolved: challenger

## Decision Rationale
User ruled: Challenger position accepted. The challenger finding is correct and the primary finding must be revised.

## Implementation Ticket
<filled if accepted or implemented — reference to the implementation ticket>
