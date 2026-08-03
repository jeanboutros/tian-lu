# Advisory: DO dropped CH-TWIN-002, CH-TWIN-004, CH-TWIN-007, CH-DEV-001–004, CH-DEV-006

| Field | Value |
|-------|-------|
| ID | psc-adv-0041-do-dropped-ch-twin-002-ch-twin-004-ch-twin-007-ch-dev-001–004-ch-dev-006 |
| Type | advisory |
| Status | backlog |
| Confidence | 80 |
| Priority | high |
| Source ticket | psc-0003 |
| Source agent | DO-challenger |
| Source file | [docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md](docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md) |
| Created | 2026-07-30 |
| Finding ID | M-24 |

## Description
The primary's scope table lists only CH-DEV-005 for `dev-twin.sh` and CH-TWIN-001/003/005/006 for the test harness. Nine advisory findings (CH-TWIN-002/004/007, CH-DEV-001/002/003/004/006) were silently dropped with no deferral rationale. CH-DEV-003 (disk-exists conflates absent with query-failed) is a data-safety issue.

## Recommended Action
Add SPEC-DO entries for dropped findings or explicitly document deferral. At minimum, surface CH-DEV-003 (data safety) and CH-DEV-004 (silent breakage on documented override).

## User Decision
backlog

## Decision Rationale
User backlogged this advisory finding (part of remaining 64 findings). Deferred to future work.

## Implementation Ticket
<filled if accepted or implemented — reference to the implementation ticket>
