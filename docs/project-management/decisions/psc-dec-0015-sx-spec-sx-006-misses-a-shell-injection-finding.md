# Decision: SX SPEC-SX-006 misses a shell-injection finding

| Field | Value |
|-------|-------|
| ID | psc-dec-0015-sx-spec-sx-006-misses-a-shell-injection-finding |
| Type | decision |
| Status | resolved: challenger |
| Confidence | 92 |
| Priority | critical |
| Source ticket | psc-0003 |
| Source agent | SX vs SX-challenger |
| Source file | [docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md](docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md) |
| Created | 2026-07-30 |
| Finding ID | D-15 |

## Description
Notes `source` executes the credential file but treats it as secondary — a one-liner inside SPEC-SX-006. This is a distinct OWASP A03:2021 (Injection) vulnerability. The credential file is the output of an emulator whose security is what the estate is trying to prove. Treating emulator output as trusted input to `source` is an injection surface.

## Recommended Action
Elevate to its own SPEC-SX-013 with OWASP A03:2021 mapping. The `while IFS='=' read -r k v` parse fix removes both the injection risk and SC1090 suppressions.

## User Decision
resolved: challenger

## Decision Rationale
User ruled: Challenger position accepted. The challenger finding is correct and the primary finding must be revised.

## Implementation Ticket
<filled if accepted or implemented — reference to the implementation ticket>
