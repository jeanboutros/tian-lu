# Clarification: DX CH-INST-004 doc-consistency impact dropped

| Field | Value |
|-------|-------|
| ID | psc-clar-0001-dx-ch-inst-004-doc-consistency-impact-dropped |
| Type | clarification |
| Status | backlog |
| Confidence | 75 |
| Priority | medium |
| Source ticket | psc-0003 |
| Source agent | DX-challenger |
| Source file | [docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md](docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md) |
| Created | 2026-07-30 |
| Finding ID | M-31 |

## Description
CH-INST-004 (no preflight for `curl`/`openssl`) is framed as code-only. But `solution-design.md §12` and `docs/testing-guide.md` describe installer dependencies. If `openssl`/`curl` become Phase-1 assertions, those docs should be consistent.

## Recommended Action
Add note that `solution-design.md §12` and prerequisites list in `docs/testing-guide.md` must reflect the `openssl`/`curl` Phase-1 assertions.

## User Decision
backlog

## Decision Rationale
User backlogged this one-sided finding (part of remaining 64 findings). Deferred to future work.

## Implementation Ticket
<filled if accepted or implemented — reference to the implementation ticket>
