# Advisory: TX SPEC-TX-107 marks MODIFY but describes no-op

| Field | Value |
|-------|-------|
| ID | psc-adv-0043-tx-spec-tx-107-marks-modify-but-describes-no-op |
| Type | advisory |
| Status | accepted |
| Confidence | 88 |
| Priority | high |
| Source ticket | psc-0003 |
| Source agent | TX-challenger |
| Source file | [docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md](docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md) |
| Created | 2026-07-30 |
| Finding ID | M-26 |

## Description
SPEC-TX-107-1 is labelled MODIFY, but the implementation detail says "The existing test … continues to work unchanged" and "no new test is needed." This is a non-modification presented as a modification, inflating the modified-test count.

## Recommended Action
Either state what assertion changes, or mark as "0 modified" not "1 modified."

## User Decision
accepted

## Decision Rationale
User accepted this advisory finding. Implement as recommended.

## Implementation Ticket
<filled if accepted or implemented — reference to the implementation ticket>
