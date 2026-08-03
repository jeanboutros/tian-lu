# Decision: DX SPEC-DX-006 presents inferred firewall-range rationale as fact

| Field | Value |
|-------|-------|
| ID | psc-dec-0012-dx-spec-dx-006-presents-inferred-firewall-range-rationale-as-fact |
| Type | decision |
| Status | resolved: challenger |
| Confidence | 85 |
| Priority | high |
| Source ticket | psc-0003 |
| Source agent | DX vs DX-challenger |
| Source file | [docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md](docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md) |
| Created | 2026-07-30 |
| Finding ID | D-12 |

## Description
Assigns service names to four undocumented ranges: 6500-6599 = "EKS k3s API server", 9400-9499 = "OpenSearch data plane", 2200-2299 = "EC2 SSH", 9169 = "EC2 IMDS." Only k3s API (6500-6599) is corroborated (GAP-013b). The other three are plausible inferences but unverified. Presenting inferences as established rationale violates the authoritative-reference skill. The primary also silently dropped the advisory's removal alternative.

## Recommended Action
Label 9400-9499, 2200-2299, 9169 as INFERRED pending verification, OR adopt the advisory's removal alternative: if a range's consumer cannot be confirmed, remove the UFW rule.

## User Decision
resolved: challenger

## Decision Rationale
User ruled: Challenger position accepted. The challenger finding is correct and the primary finding must be revised.

## Implementation Ticket
<filled if accepted or implemented — reference to the implementation ticket>
