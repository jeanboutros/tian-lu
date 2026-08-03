# Advisory: DX lessons-learned entries capture only 3 of 10 advisory rows

| Field | Value |
|-------|-------|
| ID | psc-adv-0033-dx-lessons-learned-entries-capture-only-3-of-10-advisory-rows |
| Type | advisory |
| Status | backlog |
| Confidence | 85 |
| Priority | high |
| Source ticket | psc-0003 |
| Source agent | DX-challenger |
| Source file | [docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md](docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md) |
| Created | 2026-07-30 |
| Finding ID | M-16 |

## Description
The advisory's "Lessons-learned inputs" table has 10 rows. SPEC-DX-013 captures only rows 2, 3, 4 (CH-META-001/002/003). It omits 7 rows including: "re-read source line for qualifiers," "verify post-fix state, not just the diff," "distinguish specified from verified," "behavioural claims about the shell must be executed on the target interpreter," "every 'Enforced' row needs a named gate," and "if a convention says 'keep these identical,' add a check."

## Recommended Action
SPEC-DX-013 must specify all 10 lessons (or explicitly justify exclusions row-by-row). Name the specific skill each standing rule targets.

## User Decision
backlog

## Decision Rationale
User backlogged this advisory finding (part of remaining 64 findings). Deferred to future work.

## Implementation Ticket
<filled if accepted or implemented — reference to the implementation ticket>
