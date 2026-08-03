# Advisory: TX SPEC-TX-101-7 weak structural integrity guard

| Field | Value |
|-------|-------|
| ID | psc-adv-0045-tx-spec-tx-101-7-weak-structural-integrity-guard |
| Type | advisory |
| Status | accepted |
| Confidence | 80 |
| Priority | high |
| Source ticket | psc-0003 |
| Source agent | TX-challenger |
| Source file | [docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md](docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md) |
| Created | 2026-07-30 |
| Finding ID | M-28 |

## Description
SPEC-TX-101-7 asserts "the first non-blank line is a section header." This guards against orphaned keys only for the first line. The `sed` bug can orphan keys at any boundary.

## Recommended Action
Strengthen to check no key line precedes the first section header at any position, not just line 1.

## User Decision
accepted

## Decision Rationale
User accepted this advisory finding. Implement as recommended.

## Implementation Ticket
<filled if accepted or implemented — reference to the implementation ticket>
