# Advisory: SX missed CH-LZ-008 (stage 10 governance tags deleted)

| Field | Value |
|-------|-------|
| ID | psc-adv-0021-sx-missed-ch-lz-008-stage-10-governance-tags-deleted |
| Type | advisory |
| Status | accepted |
| Confidence | 95 |
| Priority | critical |
| Source ticket | psc-0003 |
| Source agent | SX-challenger |
| Source file | [docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md](docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md) |
| Created | 2026-07-30 |
| Finding ID | M-4 |

## Description
The `Project`/`Environment`/`ManagedBy` trio was deleted from `infra/live/10-management-iam/providers.tf`. The stage's `default_tags` block reads `merge({}, var.default_tags)` — empty governance map. No `Environment` tag exists, so landing-zone §5.3's ABAC model has nothing to match on. Silent broken access control.

## Recommended Action
Include CH-LZ-008 in SX findings. Restore governance tags in stage 10 provider. Add lint check that every `infra/live/*/providers.tf` matches `_common/providers.tf`.

## User Decision
accepted

## Decision Rationale
User accepted this advisory finding. Implement as recommended.

## Implementation Ticket
<filled if accepted or implemented — reference to the implementation ticket>
