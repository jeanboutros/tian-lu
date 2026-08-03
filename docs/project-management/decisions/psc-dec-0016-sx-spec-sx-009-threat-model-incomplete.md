# Decision: SX SPEC-SX-009 threat model incomplete

| Field | Value |
|-------|-------|
| ID | psc-dec-0016-sx-spec-sx-009-threat-model-incomplete |
| Type | decision |
| Status | resolved: challenger |
| Confidence | 82 |
| Priority | high |
| Source ticket | psc-0003 |
| Source agent | SX vs SX-challenger |
| Source file | [docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md](docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md) |
| Created | 2026-07-30 |
| Finding ID | D-16 |

## Description
Confidence 85, INFERRED. G6 test covers "boundary ignored" case. Confidence 85 is slightly too high for a finding based on absence of evidence. The threat model does not consider the inverse: if Floci evaluates boundaries incorrectly (additive instead of intersectional), a role could exceed its intended ceiling. A second G6 test is needed.

## Recommended Action
Adjust confidence to 82. Add a second G6 test: boundary allows `s3:*`, identity denies `s3:ListAllMyBuckets`, assert denied — covering the intersectional failure mode.

## User Decision
resolved: challenger

## Decision Rationale
User ruled: Challenger position accepted. The challenger finding is correct and the primary finding must be revised.

## Implementation Ticket
<filled if accepted or implemented — reference to the implementation ticket>
