# Decision: DX SPEC-DX-007 cites wrong AGENTS.md line numbers

| Field | Value |
|-------|-------|
| ID | psc-dec-0010-dx-spec-dx-007-cites-wrong-agentsmd-line-numbers |
| Type | decision |
| Status | resolved: challenger |
| Confidence | 95 |
| Priority | critical |
| Source ticket | psc-0003 |
| Source agent | DX vs DX-challenger |
| Source file | [docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md](docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md) |
| Created | 2026-07-30 |
| Finding ID | D-10 |

## Description
Title is "Refresh AGENTS.md:57 and :64"; acceptance criteria assert `AGENTS.md:57` and `AGENTS.md:64`. Verified: actual gotcha text lives at AGENTS.md:60 (enable-linger line) and AGENTS.md:67 (TLS line). The primary propagated the advisory's imprecise line references without re-verifying against the current file.

## Recommended Action
Change title and acceptance criteria to "AGENTS.md:60 and :67" or reference the gotcha by leading text (robust to reflow).

## User Decision
resolved: challenger

## Decision Rationale
User ruled: Challenger position accepted. The challenger finding is correct and the primary finding must be revised.

## Implementation Ticket
<filled if accepted or implemented — reference to the implementation ticket>
