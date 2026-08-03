# Clarification: BS enable_lingering C-style for loop bashism

| Field | Value |
|-------|-------|
| ID | psc-clar-0008-bs-enable_lingering-c-style-for-loop-bashism |
| Type | clarification |
| Status | accepted |
| Confidence | 68 |
| Priority | low |
| Source ticket | psc-0003 |
| Source agent | BS-challenger |
| Source file | [docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md](docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md) |
| Created | 2026-07-30 |
| Finding ID | M-41 |

## Description
`for (( i=1; i<=USER_MANAGER_POLL_TRIES; i++ ))` — C-style for loop is a bashism. `(( i++ ))` under `errexit` returns exit status 1 when `i` is 0. Safe by luck of starting at 1.

## Recommended Action
Either start at 1 (current, safe) and document why, or use `(( i++ )) || true` defensively.

## User Decision
accepted

## Decision Rationale
User accepted this one-sided finding. Implement as recommended.

## Implementation Ticket
<filled if accepted or implemented — reference to the implementation ticket>
