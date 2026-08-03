# Advisory: SX missed CH-INST-004 (no preflight for curl/openssl)

| Field | Value |
|-------|-------|
| ID | psc-adv-0048-sx-missed-ch-inst-004-no-preflight-for-curl-openssl |
| Type | advisory |
| Status | backlog |
| Confidence | 80 |
| Priority | high |
| Source ticket | psc-0003 |
| Source agent | SX-challenger |
| Source file | [docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md](docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md) |
| Created | 2026-07-30 |
| Finding ID | M-32 |

## Description
`generate_presign_secret` needs `openssl` (Phase 5) and `verify_health` needs `curl` (Phase 6). Neither is asserted in Phase 1. A failure after mutating work is a partial-install state — fail-open configuration where security-relevant steps fail while setup steps succeed.

## Recommended Action
Include CH-INST-004 in SX findings. Trace the dependency chain from `openssl` availability to presign-secret integrity.

## User Decision
backlog

## Decision Rationale
User backlogged this advisory finding (part of remaining 64 findings). Deferred to future work.

## Implementation Ticket
<filled if accepted or implemented — reference to the implementation ticket>
