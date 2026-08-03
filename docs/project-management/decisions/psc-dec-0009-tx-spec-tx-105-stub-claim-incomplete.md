# Decision: TX SPEC-TX-105 stub claim incomplete

| Field | Value |
|-------|-------|
| ID | psc-dec-0009-tx-spec-tx-105-stub-claim-incomplete |
| Type | decision |
| Status | resolved: challenger |
| Confidence | 95 |
| Priority | critical |
| Source ticket | psc-0003 |
| Source agent | TX vs TX-challenger |
| Source file | [docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md](docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md) |
| Created | 2026-07-30 |
| Finding ID | D-9 |

## Description
Lists `uname` stub as "new symlink to `_stub` in `mock-server/tests/stubs/bin/`" but doesn't state the symlink target. The Stub Requirements Summary table does not state that `_stub` lives at `mock-server/tests/stubs/_stub` and the symlink target is `../_stub`. An implementer following the table literally would create a dangling symlink.

## Recommended Action
Document the full symlink path: `mock-server/tests/stubs/bin/uname -> ../_stub`.

## User Decision
resolved: challenger

## Decision Rationale
User ruled: Challenger position accepted. The challenger finding is correct and the primary finding must be revised.

## Implementation Ticket
<filled if accepted or implemented — reference to the implementation ticket>
