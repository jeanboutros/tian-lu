# Advisory: CH-AUTH-013 entirely absent from DX analysis

| Field | Value |
|-------|-------|
| ID | psc-adv-0020-ch-auth-013-entirely-absent-from-dx-analysis |
| Type | advisory |
| Status | accepted |
| Confidence | 95 |
| Priority | critical |
| Source ticket | psc-0003 |
| Source agent | DX-challenger |
| Source file | [docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md](docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md) |
| Created | 2026-07-30 |
| Finding ID | M-3 |

## Description
CH-AUTH-013 ("`FLOCI_AUTH_MODE` is never recorded on the host") is a documentation-relevant finding the primary dropped entirely. `write_env_file` emits derived variables but not `FLOCI_AUTH_MODE` itself. §4.4's claim is false. `dev_status` and `preflight-floci.sh` need the mode as input. The primary's "13 findings analysed / 13 SPEC-DX" is a coverage overcount.

## Recommended Action
Add SPEC-DX-014 (CH-AUTH-013): update §6.2 to emit `FLOCI_AUTH_MODE`; correct §4.4's retention claim; specify `dev_status` surfaces the mode.

## User Decision
accepted

## Decision Rationale
User accepted this advisory finding. Implement as recommended.

## Implementation Ticket
<filled if accepted or implemented — reference to the implementation ticket>
