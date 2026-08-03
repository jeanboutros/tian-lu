# Decision: BS SPEC-BS-005 `printf '%q'` version claim is FALSE

| Field | Value |
|-------|-------|
| ID | psc-dec-0017-bs-spec-bs-005-`printf-%q`-version-claim-is-false |
| Type | decision |
| Status | resolved: challenger |
| Confidence | 95 |
| Priority | critical |
| Source ticket | psc-0003 |
| Source agent | BS vs BS-challenger |
| Source file | [docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md](docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md) |
| Created | 2026-07-30 |
| Finding ID | D-17 |

## Description
References table claims "`printf '%q'` format specifier introduced in bash 4.0." Verified: `printf '%q'` works on bash 3.2.57 (`/bin/bash -c 'printf "%q\n" "hello world"'` → `hello\ world`). The `%q` format specifier predates bash 4.0. This factual error undermines the SPEC-BS-005 recommendation rationale.

## Recommended Action
Correct the References table. Reframe SPEC-BS-005: the guard is needed for empty-array `set -u` safety on 3.2, not for `printf '%q'`.

## User Decision
resolved: challenger

## Decision Rationale
User ruled: Challenger position accepted. The challenger finding is correct and the primary finding must be revised.

## Implementation Ticket
<filled if accepted or implemented — reference to the implementation ticket>
