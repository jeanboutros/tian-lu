# Advisory: TX implementation-order dependency cycle under-analysed

| Field | Value |
|-------|-------|
| ID | psc-adv-0030-tx-implementation-order-dependency-cycle-under-analysed |
| Type | advisory |
| Status | accepted |
| Confidence | 82 |
| Priority | high |
| Source ticket | psc-0003 |
| Source agent | TX-challenger |
| Source file | [docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md](docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md) |
| Created | 2026-07-30 |
| Finding ID | M-13 |

## Description
The dependency table lists CH-AUTH-006 "Blocks CH-AUTH-011" and CH-AUTH-011 "Depends on CH-AUTH-006" — a mutual dependency. In reality, 011 (introduce `DEV_AUTH_MODE`) must precede 006 (`_print_next_steps` uses `DEV_AUTH_MODE`). The "Blocks" column for 006 is wrong — 006 does not block 011; 011 blocks 006.

## Recommended Action
Correct the CH-AUTH-006 ↔ CH-AUTH-011 dependency direction. 011 introduces `DEV_AUTH_MODE`; 006 consumes it. 011 blocks 006, not vice versa.

## User Decision
accepted

## Decision Rationale
User accepted this advisory finding. Implement as recommended.

## Implementation Ticket
<filled if accepted or implemented — reference to the implementation ticket>
