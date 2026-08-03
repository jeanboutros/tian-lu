# Clarification: BS here-string bashism not noted in portability

| Field | Value |
|-------|-------|
| ID | psc-clar-0005-bs-here-string-bashism-not-noted-in-portability |
| Type | clarification |
| Status | accepted |
| Confidence | 85 |
| Priority | medium |
| Source ticket | psc-0003 |
| Source agent | BS-challenger |
| Source file | [docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md](docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md) |
| Created | 2026-07-30 |
| Finding ID | M-38 |

## Description
`IFS='.' read -r octet1 octet2 octet3 _ <<< "$SERVER_IP"` uses a here-string (`<<<`), a bashism. The primary's blanket "None" portability assessments would be more accurate as "N/A — bash-only feature, consistent with shebang."

## Recommended Action
Refine portability assessment language to acknowledge bash-only constructs. No code change needed.

## User Decision
accepted

## Decision Rationale
User accepted this one-sided finding. Implement as recommended.

## Implementation Ticket
<filled if accepted or implemented — reference to the implementation ticket>
