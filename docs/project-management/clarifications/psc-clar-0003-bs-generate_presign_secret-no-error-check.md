# Clarification: BS generate_presign_secret no error check

| Field | Value |
|-------|-------|
| ID | psc-clar-0003-bs-generate_presign_secret-no-error-check |
| Type | clarification |
| Status | backlog |
| Confidence | 75 |
| Priority | medium |
| Source ticket | psc-0003 |
| Source agent | BS-challenger |
| Source file | [docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md](docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md) |
| Created | 2026-07-30 |
| Finding ID | M-36 |

## Description
`PRESIGN_SECRET="$(openssl rand -hex 32)"` — no error check on `openssl` failure. If `openssl` is absent or fails, `PRESIGN_SECRET` is empty and `write_env_file` writes `FLOCI_AUTH_PRESIGN_SECRET=` (empty) to the env file. An empty presign secret means all presigned URLs are accepted with no signature verification.

## Recommended Action
Add `[[ -n "$PRESIGN_SECRET" ]] || { printf 'ERROR: failed to generate presign secret\n' >&2; exit 1; }` after the `openssl rand` call.

## User Decision
backlog

## Decision Rationale
User backlogged this one-sided finding (part of remaining 64 findings). Deferred to future work.

## Implementation Ticket
<filled if accepted or implemented — reference to the implementation ticket>
