# Advisory: SX missed CH-AUTH-006 + CH-AUTH-013 (security-gate variables never assigned)

| Field | Value |
|-------|-------|
| ID | psc-adv-0036-sx-missed-ch-auth-006--ch-auth-013-security-gate-variables-never-assigned |
| Type | advisory |
| Status | accepted |
| Confidence | 88 |
| Priority | high |
| Source ticket | psc-0003 |
| Source agent | SX-challenger |
| Source file | [docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md](docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md) |
| Created | 2026-07-30 |
| Finding ID | M-19 |

## Description
CH-AUTH-006: `DEV_AUTH_MODE` is never assigned host-side; the entire security section is dead code. CH-AUTH-013: `FLOCI_AUTH_MODE` never recorded on host. Together, the security posture of a running Floci instance is unverifiable from the host.

## Recommended Action
Include CH-AUTH-006 and CH-AUTH-013 in SX findings. Add a cross-cutting concern: Post-Install Security Observability — every security-relevant configuration must be queryable after install.

## User Decision
accepted

## Decision Rationale
User accepted this advisory finding. Implement as recommended.

## Implementation Ticket
<filled if accepted or implemented — reference to the implementation ticket>
