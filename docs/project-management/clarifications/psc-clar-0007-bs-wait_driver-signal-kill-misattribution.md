# Clarification: BS wait_driver signal-kill misattribution

| Field | Value |
|-------|-------|
| ID | psc-clar-0007-bs-wait_driver-signal-kill-misattribution |
| Type | clarification |
| Status | accepted |
| Confidence | 70 |
| Priority | medium |
| Source ticket | psc-0003 |
| Source agent | BS-challenger |
| Source file | [docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md](docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md) |
| Created | 2026-07-30 |
| Finding ID | M-40 |

## Description
`2>/dev/null` suppresses legitimate wait errors. A killed-by-signal driver (status 143) would be misattributed as a failure — the CH-AUTH-010 concern the primary notes but does not fix in SPEC-BS-019.

## Recommended Action
After fixing the empty-PID guard, also distinguish signal-kill (128+N) from genuine non-zero exit, per CH-AUTH-010.

## User Decision
accepted

## Decision Rationale
User accepted this one-sided finding. Implement as recommended.

## Implementation Ticket
<filled if accepted or implemented — reference to the implementation ticket>
