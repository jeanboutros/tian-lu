# Advisory: CH-AUTH-014 under-weighted in SPEC-SW-014

| Field | Value |
|-------|-------|
| ID | psc-adv-0028-ch-auth-014-under-weighted-in-spec-sw-014 |
| Type | advisory |
| Status | accepted |
| Confidence | 82 |
| Priority | high |
| Source ticket | psc-0003 |
| Source agent | SW-challenger |
| Source file | [docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md](docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md) |
| Created | 2026-07-30 |
| Finding ID | M-11 |

## Description
SPEC-SW-014 bundles four items into one finding. CH-AUTH-014 (presign secret IAM bypass) is architecturally distinct — it bypasses the IAM layer entirely, and the Terraform state bucket is S3. The SW bundles this into a "multiple documentation and hygiene gaps" finding.

## Recommended Action
Split CH-AUTH-014 into its own SPEC with SX dependency for the threat model, separate from documentation hygiene items.

## User Decision
accepted

## Decision Rationale
User accepted this advisory finding. Implement as recommended.

## Implementation Ticket
<filled if accepted or implemented — reference to the implementation ticket>
