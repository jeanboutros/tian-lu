# Advisory: DX CH-LZ-006 doc correction relegated to parenthetical

| Field | Value |
|-------|-------|
| ID | psc-adv-0032-dx-ch-lz-006-doc-correction-relegated-to-parenthetical |
| Type | advisory |
| Status | backlog |
| Confidence | 88 |
| Priority | high |
| Source ticket | psc-0003 |
| Source agent | DX-challenger |
| Source file | [docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md](docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md) |
| Created | 2026-07-30 |
| Finding ID | M-15 |

## Description
CH-LZ-006 is a substantive doc defect: §6.10b prescribes deprecated `force_path_style`/`endpoint` backend args. The primary only mentions CH-LZ-006 once, parenthetically in SPEC-DX-002, and creates no acceptance criterion for actually correcting the §6.10b backend-init recipe.

## Recommended Action
Add explicit acceptance criterion: "§6.10b's `terraform init` recipe uses `-backend-config=../../_common/backend.hcl` + per-stage `key=` override only; deprecated args removed."

## User Decision
backlog

## Decision Rationale
User backlogged this advisory finding (part of remaining 64 findings). Deferred to future work.

## Implementation Ticket
<filled if accepted or implemented — reference to the implementation ticket>
