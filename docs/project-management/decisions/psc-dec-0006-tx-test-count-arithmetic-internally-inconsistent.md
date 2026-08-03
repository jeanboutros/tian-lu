# Decision: TX test-count arithmetic internally inconsistent

| Field | Value |
|-------|-------|
| ID | psc-dec-0006-tx-test-count-arithmetic-internally-inconsistent |
| Type | decision |
| Status | resolved: challenger |
| Confidence | 100 |
| Priority | critical |
| Source ticket | psc-0003 |
| Source agent | TX vs TX-challenger |
| Source file | [docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md](docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md) |
| Created | 2026-07-30 |
| Finding ID | D-6 |

## Description
Overview states "28 new + 3 modified across 7 test files"; Test File Summary table totals "26 new + 3 modified." 26 is the reconciled number; "28" in the overview is wrong and never corrected. A requirements doc whose headline count doesn't match its own table misleads Phase B implementers.

## Recommended Action
Fix the test-count arithmetic. Use 26 (reconciled) or re-count after re-scoping to all 49 findings.

## User Decision
resolved: challenger

## Decision Rationale
User ruled: Challenger position accepted. The challenger finding is correct and the primary finding must be revised.

## Implementation Ticket
<filled if accepted or implemented — reference to the implementation ticket>
