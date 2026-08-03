# Advisory: SPEC-SW-001 doesn't flag §4.2 promotion model collapse

| Field | Value |
|-------|-------|
| ID | psc-adv-0027-spec-sw-001-doesnt-flag-§42-promotion-model-collapse |
| Type | advisory |
| Status | accepted |
| Confidence | 88 |
| Priority | high |
| Source ticket | psc-0003 |
| Source agent | SW-challenger |
| Source file | [docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md](docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md) |
| Created | 2026-07-30 |
| Finding ID | M-10 |

## Description
SPEC-SW-001's fix moves the account axis from AKID to `FLOCI_DEFAULT_ACCOUNT_ID` (per-instance). Landing-zone §4.2's promotion model ("copy tfvars, change AKID, same code applies") is now false — promotion requires a new Floci instance. The SW lists this as a DX dependency without flagging the architectural implication.

## Recommended Action
Flag the §4.2 promotion model alteration as architectural. Route to SW/DO for review before DX writes it up.

## User Decision
accepted

## Decision Rationale
User accepted this advisory finding. Implement as recommended.

## Implementation Ticket
<filled if accepted or implemented — reference to the implementation ticket>
