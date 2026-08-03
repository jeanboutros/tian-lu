# Decision: SPEC-SW-010 directly contradicts user decision on upper bound

| Field | Value |
|-------|-------|
| ID | psc-dec-0001-spec-sw-010-directly-contradicts-user-decision-on-upper-bound |
| Type | decision |
| Status | resolved: challenger |
| Confidence | 95 |
| Priority | critical |
| Source ticket | psc-0003 |
| Source agent | SW vs SW-challenger |
| Source file | [docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md](docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md) |
| Created | 2026-07-30 |
| Finding ID | D-1 |

## Description
SPEC-SW-010 proposes `>= 6.56.0, < 7.0.0` with upper bound; acceptance criterion: "All stages use `aws >= 6.56.0, < 7.0.0`". A0-task-definition.md:44 records user decision as "CH-LZ-009: >= 6.56.0 with NO upper bound." The SW either did not consult A0 or followed the advisory over the user decision.

## Recommended Action
Revise SPEC-SW-010 to `>= 6.56.0` with no upper bound, matching A0:44. Record supply-chain risk as a gaps-register advisory, not an acceptance criterion.

## User Decision
resolved: challenger

## Decision Rationale
User ruled: Challenger position accepted. The challenger finding is correct and the primary finding must be revised.

## Implementation Ticket
<filled if accepted or implemented — reference to the implementation ticket>
