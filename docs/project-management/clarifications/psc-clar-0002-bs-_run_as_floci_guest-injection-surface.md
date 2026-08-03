# Clarification: BS _run_as_floci_guest injection surface

| Field | Value |
|-------|-------|
| ID | psc-clar-0002-bs-_run_as_floci_guest-injection-surface |
| Type | clarification |
| Status | backlog |
| Confidence | 78 |
| Priority | medium |
| Source ticket | psc-0003 |
| Source agent | BS-challenger |
| Source file | [docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md](docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md) |
| Created | 2026-07-30 |
| Finding ID | M-35 |

## Description
`_run_as_floci_guest` passes `"$*"` (all args joined) into a single `bash -c` string. Arguments with spaces or special chars would be re-interpreted by the inner shell. Current call sites pass static strings, but the pattern is a latent command-injection trap.

## Recommended Action
Document that callers must not pass untrusted data. Ideally, refactor to use positional parameters: `bash -c '...' "$@"`.

## User Decision
backlog

## Decision Rationale
User backlogged this one-sided finding (part of remaining 64 findings). Deferred to future work.

## Implementation Ticket
<filled if accepted or implemented — reference to the implementation ticket>
