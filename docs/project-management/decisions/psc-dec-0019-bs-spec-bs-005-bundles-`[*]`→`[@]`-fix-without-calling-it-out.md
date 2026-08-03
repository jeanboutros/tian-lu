# Decision: BS SPEC-BS-005 bundles `[*]`→`[@]` fix without calling it out

| Field | Value |
|-------|-------|
| ID | psc-dec-0019-bs-spec-bs-005-bundles-`[*]`→`[@]`-fix-without-calling-it-out |
| Type | decision |
| Status | resolved: challenger |
| Confidence | 90 |
| Priority | critical |
| Source ticket | psc-0003 |
| Source agent | BS vs BS-challenger |
| Source file | [docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md](docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md) |
| Created | 2026-07-30 |
| Finding ID | D-19 |

## Description
Code sketch changes `${driver_args[*]+"${driver_args[*]}"}` to `${driver_args[@]+"${driver_args[@]}"}` but only justifies the guard retention. The `[*]`→`[@]` change is an independent correctness fix: under `IFS=$'\n\t'`, `[*]` joins elements with newline producing a single field on re-split for multi-element arrays. Both fixes are required but only one is documented.

## Recommended Action
Split SPEC-BS-005 into two findings: (a) guard retention for `set -u` empty-array safety, (b) `[*]`→`[@]` for multi-element array correctness under `IFS=$'\n\t'`.

## User Decision
resolved: challenger

## Decision Rationale
User ruled: Challenger position accepted. The challenger finding is correct and the primary finding must be revised.

## Implementation Ticket
<filled if accepted or implemented — reference to the implementation ticket>
