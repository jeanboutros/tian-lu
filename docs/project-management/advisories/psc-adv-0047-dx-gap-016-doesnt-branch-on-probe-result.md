# Advisory: DX GAP-016 doesn't branch on probe result

| Field | Value |
|-------|-------|
| ID | psc-adv-0047-dx-gap-016-doesnt-branch-on-probe-result |
| Type | advisory |
| Status | accepted |
| Confidence | 82 |
| Priority | high |
| Source ticket | psc-0003 |
| Source agent | DX-challenger |
| Source file | [docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md](docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md) |
| Created | 2026-07-30 |
| Finding ID | M-30 |

## Description
GAP-016's action says "verify the three-outcome probe result" but doesn't specify that the gap entry must record which outcome was observed and trigger a rewrite of auth-plan §8.3 + landing-zone §1.1 if outcome (b) holds.

## Recommended Action
GAP-016's action must state: "Run the probe; record the observed outcome (a/b/c); if outcome (b), auth-plan §8.3 and landing-zone §1.1 'Enforced' rows must be rewritten."

## User Decision
accepted

## Decision Rationale
User accepted this advisory finding. Implement as recommended.

## Implementation Ticket
<filled if accepted or implemented — reference to the implementation ticket>
