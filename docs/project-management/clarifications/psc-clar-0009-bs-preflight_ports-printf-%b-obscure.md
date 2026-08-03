# Clarification: BS preflight_ports printf '%b' obscure

| Field | Value |
|-------|-------|
| ID | psc-clar-0009-bs-preflight_ports-printf-%b-obscure |
| Type | clarification |
| Status | backlog |
| Confidence | 65 |
| Priority | low |
| Source ticket | psc-0003 |
| Source agent | BS-challenger |
| Source file | [docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md](docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md) |
| Created | 2026-07-30 |
| Finding ID | M-42 |

## Description
`conflicts="${conflicts}${port}\n"` builds a string with literal `\n` then uses `printf '%b'` to interpret it. Works but is obscure.

## Recommended Action
Consider array-based accumulation for clarity; no functional change needed.

## User Decision
backlog

## Decision Rationale
User backlogged this one-sided finding (part of remaining 64 findings). Deferred to future work.

## Implementation Ticket
<filled if accepted or implemented — reference to the implementation ticket>
