# Advisory: TX dropped 33 of 49 accepted findings (FLAG-1)

| Field | Value |
|-------|-------|
| ID | psc-adv-0018-tx-dropped-33-of-49-accepted-findings-flag-1 |
| Type | advisory |
| Status | accepted |
| Confidence | 100 |
| Priority | critical |
| Source ticket | psc-0003 |
| Source agent | TX-challenger |
| Source file | [docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md](docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md) |
| Created | 2026-07-30 |
| Finding ID | M-1 |

## Description
The primary covered 16 findings and declared "16/16 TX-relevant findings" and "GAPS: None." That claim is false. 33 findings — including high-severity items (CH-AUTH-003, CH-AUTH-005, CH-INST-001, CH-DEV-002/003/004/005, CH-LZ-008) — have no test specification. CH-AUTH-003 requires modifying an existing test spec (SPEC-TX-006 case 3) and the primary does not even mention it.

## Recommended Action
Re-scope to all 49 accepted findings. Produce test specs (or explicit "documentation-only / not testable" dispositions with reasoning) for every omitted finding.

## User Decision
accepted

## Decision Rationale
User accepted this advisory finding. Implement as recommended.

## Implementation Ticket
<filled if accepted or implemented — reference to the implementation ticket>
