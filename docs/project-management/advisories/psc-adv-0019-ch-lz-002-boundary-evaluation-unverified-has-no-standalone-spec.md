# Advisory: CH-LZ-002 (boundary evaluation unverified) has no standalone SPEC

| Field | Value |
|-------|-------|
| ID | psc-adv-0019-ch-lz-002-boundary-evaluation-unverified-has-no-standalone-spec |
| Type | advisory |
| Status | accepted |
| Confidence | 90 |
| Priority | critical |
| Source ticket | psc-0003 |
| Source agent | SW-challenger |
| Source file | [docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md](docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md) |
| Created | 2026-07-30 |
| Finding ID | M-2 |

## Description
The advisory has CH-LZ-002 as a standalone high-severity finding. The SW analysis has no SPEC-SW for it — referenced only as acceptance criterion #6 in SPEC-SW-006. CH-LZ-002's architectural implication: Floci may not implement permissions-boundary evaluation at all, making the entire delegated-administration ceiling modeled, not enforced.

## Recommended Action
Create SPEC-SW-015 for CH-LZ-002 with G6 negative test as primary gate, dependency on the probe, §1.1 qualification requirement, and SX/TX/DO dependencies.

## User Decision
accepted

## Decision Rationale
User accepted this advisory finding. Implement as recommended.

## Implementation Ticket
<filled if accepted or implemented — reference to the implementation ticket>
