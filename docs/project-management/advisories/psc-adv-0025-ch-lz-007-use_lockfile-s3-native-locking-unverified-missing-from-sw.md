# Advisory: CH-LZ-007 (use_lockfile S3-native locking unverified) missing from SW

| Field | Value |
|-------|-------|
| ID | psc-adv-0025-ch-lz-007-use_lockfile-s3-native-locking-unverified-missing-from-sw |
| Type | advisory |
| Status | accepted |
| Confidence | 85 |
| Priority | high |
| Source ticket | psc-0003 |
| Source agent | SW-challenger |
| Source file | [docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md](docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md) |
| Created | 2026-07-30 |
| Finding ID | M-8 |

## Description
The advisory has CH-LZ-007: S3-native locking (`use_lockfile = true`) is offered as alternative to DynamoDB locking, but no gate verifies Floci's S3 honours `IfNoneMatch: "*"`. The SW analysis covers 9 of 13 LZ findings but omits CH-LZ-007.

## Recommended Action
Create SPEC for CH-LZ-007. Add G3b gate or mark `use_lockfile` unverified in §9 and `backend.hcl.example`.

## User Decision
accepted

## Decision Rationale
User accepted this advisory finding. Implement as recommended.

## Implementation Ticket
<filled if accepted or implemented — reference to the implementation ticket>
