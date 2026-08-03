# Advisory: SX missed CH-LZ-009 + CH-LZ-010 (provider version divergence + backend key prefix)

| Field | Value |
|-------|-------|
| ID | psc-adv-0034-sx-missed-ch-lz-009--ch-lz-010-provider-version-divergence--backend-key-prefix |
| Type | advisory |
| Status | backlog |
| Confidence | 88 |
| Priority | high |
| Source ticket | psc-0003 |
| Source agent | SX-challenger |
| Source file | [docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md](docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md) |
| Created | 2026-07-30 |
| Finding ID | M-17 |

## Description
CH-LZ-009: stage-10 has `>= 6.56.0` with no upper bound vs `_common` `>= 5.95.0, < 7.0.0`. CH-LZ-010: stage-10 backend key is `10-management-iam/terraform.tfstate` with no `<env>/` prefix. Cross-environment state collision → `terraform apply` in uat could destroy dev resources.

## Recommended Action
Include CH-LZ-009 and CH-LZ-010 in SX findings. State-file collision and provider-version drift have security blast radius.

## User Decision
backlog

## Decision Rationale
User backlogged this advisory finding. Deferred to future work.

## Implementation Ticket
<filled if accepted or implemented — reference to the implementation ticket>
