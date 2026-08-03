# Advisory: SX missed CH-LZ-005 (five region literals across stack)

| Field | Value |
|-------|-------|
| ID | psc-adv-0022-sx-missed-ch-lz-005-five-region-literals-across-stack |
| Type | advisory |
| Status | accepted |
| Confidence | 90 |
| Priority | critical |
| Source ticket | psc-0003 |
| Source agent | SX-challenger |
| Source file | [docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md](docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md) |
| Created | 2026-07-30 |
| Finding ID | M-5 |

## Description
Five distinct region values live across the stack: `backend.hcl.example:12` (us-east-1), `dev.tfvars:13` (eu-west-2), `setup-floci.sh:54` (eu-west-1), `preflight-floci.sh:25` (us-east-1), `dev-twin.sh:766` (eu-west-1). Backend-region/provider-region mismatch means state orphaning → potential infrastructure destruction.

## Recommended Action
Include CH-LZ-005 in SX findings. Unify all five region literals to a single source of truth per environment.

## User Decision
accepted

## Decision Rationale
User accepted this advisory finding. Implement as recommended.

## Implementation Ticket
<filled if accepted or implemented — reference to the implementation ticket>
