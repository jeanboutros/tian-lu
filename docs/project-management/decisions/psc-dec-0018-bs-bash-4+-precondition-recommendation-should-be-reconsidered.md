# Decision: BS bash-4+ precondition recommendation should be reconsidered

| Field | Value |
|-------|-------|
| ID | psc-dec-0018-bs-bash-4+-precondition-recommendation-should-be-reconsidered |
| Type | decision |
| Status | resolved: challenger |
| Confidence | 80 |
| Priority | high |
| Source ticket | psc-0003 |
| Source agent | BS vs BS-challenger |
| Source file | [docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md](docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md) |
| Created | 2026-07-30 |
| Finding ID | D-18 |

## Description
Recommends adding `(( BASH_VERSINFO[0] >= 4 ))` precondition to `run-test.sh`. The existing codebase deliberately supports bash 3.2 on the host side (parallel arrays at run-test.sh:455-456, `${arr[@]+…}` guards). Adding a bash-4+ precondition would contradict that deliberate design choice.

## Recommended Action
Do not add a bash-4+ gate without explicitly deciding to drop existing 3.2 compatibility. Keep the guard; `printf '%q'` is 3.2-safe.

## User Decision
resolved: challenger

## Decision Rationale
User ruled: Challenger position accepted. The challenger finding is correct and the primary finding must be revised.

## Implementation Ticket
<filled if accepted or implemented — reference to the implementation ticket>
