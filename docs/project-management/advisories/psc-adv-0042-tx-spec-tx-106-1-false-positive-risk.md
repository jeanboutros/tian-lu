# Advisory: TX SPEC-TX-106-1 false-positive risk

| Field | Value |
|-------|-------|
| ID | psc-adv-0042-tx-spec-tx-106-1-false-positive-risk |
| Type | advisory |
| Status | accepted |
| Confidence | 85 |
| Priority | high |
| Source ticket | psc-0003 |
| Source agent | TX-challenger |
| Source file | [docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md](docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md) |
| Created | 2026-07-30 |
| Finding ID | M-25 |

## Description
SPEC-TX-106-1 asserts `validate_summary` passes when `sidecar-delta=PASS` and `NO_SIDECAR=false`. The FAIL-rejection case is described in prose but not as a discrete test case. An implementation that adds `sidecar-delta` to `mandatory` but breaks the FAIL-rejection path could pass 106-1/106-2.

## Recommended Action
Add a discrete FAIL-rejection test case for `sidecar-delta` — separate from 106-1/106-2.

## User Decision
accepted

## Decision Rationale
User accepted this advisory finding. Implement as recommended.

## Implementation Ticket
<filled if accepted or implemented — reference to the implementation ticket>
