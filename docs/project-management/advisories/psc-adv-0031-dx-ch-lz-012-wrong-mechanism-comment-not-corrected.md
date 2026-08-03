# Advisory: DX CH-LZ-012 wrong-mechanism comment not corrected

| Field | Value |
|-------|-------|
| ID | psc-adv-0031-dx-ch-lz-012-wrong-mechanism-comment-not-corrected |
| Type | advisory |
| Status | accepted |
| Confidence | 92 |
| Priority | critical |
| Source ticket | psc-0003 |
| Source agent | DX-challenger |
| Source file | [docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md](docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md) |
| Created | 2026-07-30 |
| Finding ID | M-14 |

## Description
CH-LZ-012 explicitly states: correct both the `dev.tfvars` comment and auth plan §6.10c to state the real mechanism (merge precedence, silent override, no diagnostic). The primary's SPEC-DX-002 mentions §6.10c only as "already-landed, move to appendix" and never corrects the wrong-mechanism sentence inside it. Moving a wrong claim to an appendix preserves the error.

## Recommended Action
Add requirement to correct the mechanism wording in both `dev.tfvars:27-28` and `authentication-plan.md §6.10c` to "merge precedence silently overrides; no diagnostic."

## User Decision
accepted

## Decision Rationale
User accepted this advisory finding. Implement as recommended.

## Implementation Ticket
<filled if accepted or implemented — reference to the implementation ticket>
