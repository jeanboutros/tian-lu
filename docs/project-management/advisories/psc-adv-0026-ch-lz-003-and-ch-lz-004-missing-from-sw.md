# Advisory: CH-LZ-003 and CH-LZ-004 missing from SW

| Field | Value |
|-------|-------|
| ID | psc-adv-0026-ch-lz-003-and-ch-lz-004-missing-from-sw |
| Type | advisory |
| Status | backlog |
| Confidence | 85 |
| Priority | high |
| Source ticket | psc-0003 |
| Source agent | SW-challenger |
| Source file | [docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md](docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md) |
| Created | 2026-07-30 |
| Finding ID | M-9 |

## Description
CH-LZ-003 (G1 mislabelled; design never names enforcement variables) and CH-LZ-004 (G1 degrades to SKIP where design promises hard stop) are preflight-gate findings in the SW/DO domain. The SW analysis touches preflight in SPEC-SW-001 but does not address CH-LZ-003 or CH-LZ-004. CH-LZ-004 interacts with SPEC-SW-001 and SPEC-SW-003 — the three must be implemented together.

## Recommended Action
Create SPECs for CH-LZ-003 and CH-LZ-004. G1 must fail (not skip) when probe cannot be established.

## User Decision
backlog

## Decision Rationale
User backlogged this advisory finding. Deferred to future work.

## Implementation Ticket
<filled if accepted or implemented — reference to the implementation ticket>
