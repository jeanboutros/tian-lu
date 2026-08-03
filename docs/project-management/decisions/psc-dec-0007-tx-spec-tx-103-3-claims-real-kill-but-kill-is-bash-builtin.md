# Decision: TX SPEC-TX-103-3 claims 'real kill' but kill is bash builtin

| Field | Value |
|-------|-------|
| ID | psc-dec-0007-tx-spec-tx-103-3-claims-real-kill-but-kill-is-bash-builtin |
| Type | decision |
| Status | resolved: challenger |
| Confidence | 95 |
| Priority | critical |
| Source ticket | psc-0003 |
| Source agent | TX vs TX-challenger |
| Source file | [docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md](docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md) |
| Created | 2026-07-30 |
| Finding ID | D-7 |

## Description
Implementation detail says test "uses real `sleep` and `kill` commands." On macOS, `kill` is a bash shell builtin, not `/bin/kill`. Auth plan §6.11 mandates a `kill` symlink to `_stub` with `STUB_RC_KILL`. The primary and auth plan disagree on whether `kill` is stubbed.

## Recommended Action
Resolve the `kill` stub contradiction between A1-TX ("real kill") and auth plan §6.11 (`kill` symlink with `STUB_RC_KILL`). Pick one and document it.

## User Decision
resolved: challenger

## Decision Rationale
User ruled: Challenger position accepted. The challenger finding is correct and the primary finding must be revised.

## Implementation Ticket
<filled if accepted or implemented — reference to the implementation ticket>
