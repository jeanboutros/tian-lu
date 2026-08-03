# Advisory: TX no test for CH-TWIN-006 order-dependence direction

| Field | Value |
|-------|-------|
| ID | psc-adv-0044-tx-no-test-for-ch-twin-006-order-dependence-direction |
| Type | advisory |
| Status | accepted |
| Confidence | 85 |
| Priority | high |
| Source ticket | psc-0003 |
| Source agent | TX-challenger |
| Source file | [docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md](docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md) |
| Created | 2026-07-30 |
| Finding ID | M-27 |

## Description
SPEC-TX-110-3 tests `--fresh --keep` but defers the semantic decision. No RED test captures the current broken order-dependence (`--keep` after `--fresh` silently ignored, `--fresh` after `--keep` wins).

## Recommended Action
Add a RED test for the current `--fresh`/`--keep` order-dependence before the semantic decision.

## User Decision
accepted

## Decision Rationale
User accepted this advisory finding. Implement as recommended.

## Implementation Ticket
<filled if accepted or implemented — reference to the implementation ticket>
