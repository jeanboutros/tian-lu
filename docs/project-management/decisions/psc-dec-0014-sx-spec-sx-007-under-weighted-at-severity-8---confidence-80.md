# Decision: SX SPEC-SX-007 under-weighted at severity 8 / confidence 80

| Field | Value |
|-------|-------|
| ID | psc-dec-0014-sx-spec-sx-007-under-weighted-at-severity-8---confidence-80 |
| Type | decision |
| Status | resolved: primary |
| Confidence | 88 |
| Priority | high |
| Source ticket | psc-0003 |
| Source agent | SX vs SX-challenger |
| Source file | [docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md](docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md) |
| Created | 2026-07-30 |
| Finding ID | D-14 |

## Description
Severity 8, Confidence 80. Maps to OWASP A01 + A04. Confidence 80 is too low for a CITED finding. Severity 8 under-weights the blast radius (administrative access to entire estate via state bucket). Missing rotation path is an OWASP A07:2021 finding, not just a documentation gap.

## Recommended Action
Raise to severity 9, confidence 88. Add OWASP A07:2021 mapping for the missing credential rotation path.

## User Decision
resolved: primary

## Decision Rationale
User ruled: Primary position accepted. The primary finding stands; challenger position rejected.

## Implementation Ticket
<filled if accepted or implemented — reference to the implementation ticket>
