# Advisory: BS configure_subuid_subgid numeric validation gap

| Field | Value |
|-------|-------|
| ID | psc-adv-0037-bs-configure_subuid_subgid-numeric-validation-gap |
| Type | advisory |
| Status | backlog |
| Confidence | 82 |
| Priority | high |
| Source ticket | psc-0003 |
| Source agent | BS-challenger |
| Source file | [docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md](docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md) |
| Created | 2026-07-30 |
| Finding ID | M-20 |

## Description
The overlap-detection loop uses `[[ "$candidate" -lt "$range_end" ]]` with arithmetic comparison on variables from `/etc/subuid` that may contain non-numeric values. If the file contains a malformed line, the `-lt` comparison produces "integer expression expected" which under `set -e` would abort.

## Recommended Action
Add a numeric-validation guard (`[[ "$range_start" =~ ^[0-9]+$ ]]`) before the `-lt`/`-gt` comparison in the overlap loop.

## User Decision
backlog

## Decision Rationale
User backlogged this advisory finding (part of remaining 64 findings). Deferred to future work.

## Implementation Ticket
<filled if accepted or implemented — reference to the implementation ticket>
