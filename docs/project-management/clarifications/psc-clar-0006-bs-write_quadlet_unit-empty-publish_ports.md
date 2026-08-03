# Clarification: BS write_quadlet_unit empty publish_ports

| Field | Value |
|-------|-------|
| ID | psc-clar-0006-bs-write_quadlet_unit-empty-publish_ports |
| Type | clarification |
| Status | backlog |
| Confidence | 72 |
| Priority | medium |
| Source ticket | psc-0003 |
| Source agent | BS-challenger |
| Source file | [docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md](docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md) |
| Created | 2026-07-30 |
| Finding ID | M-39 |

## Description
`publish_ports` is built by string concatenation; an empty value produces a blank line in the Quadlet file. ShellCheck SC2086 would flag the unquoted expansion.

## Recommended Action
Guard the `${publish_ports}` line: only emit it if non-empty, or build via array join.

## User Decision
backlog

## Decision Rationale
User backlogged this one-sided finding. Deferred to future work.

## Implementation Ticket
<filled if accepted or implemented — reference to the implementation ticket>
