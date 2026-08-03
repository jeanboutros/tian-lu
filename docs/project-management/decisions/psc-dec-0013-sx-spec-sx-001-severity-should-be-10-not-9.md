# Decision: SX SPEC-SX-001 severity should be 10, not 9

| Field | Value |
|-------|-------|
| ID | psc-dec-0013-sx-spec-sx-001-severity-should-be-10-not-9 |
| Type | decision |
| Status | resolved: challenger |
| Confidence | 93 |
| Priority | critical |
| Source ticket | psc-0003 |
| Source agent | SX vs SX-challenger |
| Source file | [docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md](docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md) |
| Created | 2026-07-30 |
| Finding ID | D-13 |

## Description
Severity 9 — one blocker among many. Severity 10 (Critical) — it is the foundational defect that makes every other IAM-related finding conditional. If outcome (b) holds, the estate's headline security claim is false. Severity 9 implies "fix alongside others"; severity 10 implies "resolve this first, then reassess the rest."

## Recommended Action
Raise SPEC-SX-001 to severity 10. Make the three-outcome probe a prerequisite gate (G0) that must run before any other remediation is built.

## User Decision
resolved: challenger

## Decision Rationale
User ruled: Challenger position accepted. The challenger finding is correct and the primary finding must be revised.

## Implementation Ticket
<filled if accepted or implemented — reference to the implementation ticket>
