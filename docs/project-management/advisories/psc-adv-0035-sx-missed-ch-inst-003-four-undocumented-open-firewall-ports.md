# Advisory: SX missed CH-INST-003 (four undocumented open firewall ports)

| Field | Value |
|-------|-------|
| ID | psc-adv-0035-sx-missed-ch-inst-003-four-undocumented-open-firewall-ports |
| Type | advisory |
| Status | accepted |
| Confidence | 85 |
| Priority | high |
| Source ticket | psc-0003 |
| Source agent | SX-challenger |
| Source file | [docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md](docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md) |
| Created | 2026-07-30 |
| Finding ID | M-18 |

## Description
`setup-floci.sh` opens UFW ports 6500:6599, 9400:9499, 2200:2299, and 9169, but the container publishes none of them. Open ports with no documented consumer are attack-surface expansion.

## Recommended Action
Include CH-INST-003 in SX findings. Audit the installer's attack surface (open ports) as part of the security review scope.

## User Decision
accepted

## Decision Rationale
User accepted this advisory finding. Implement as recommended.

## Implementation Ticket
<filled if accepted or implemented — reference to the implementation ticket>
