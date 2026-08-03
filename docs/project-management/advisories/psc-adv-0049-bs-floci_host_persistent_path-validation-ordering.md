# Advisory: BS FLOCI_HOST_PERSISTENT_PATH validation ordering

| Field | Value |
|-------|-------|
| ID | psc-adv-0049-bs-floci_host_persistent_path-validation-ordering |
| Type | advisory |
| Status | accepted |
| Confidence | 88 |
| Priority | high |
| Source ticket | psc-0003 |
| Source agent | BS-challenger |
| Source file | [docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md](docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md) |
| Created | 2026-07-30 |
| Finding ID | M-33 |

## Description
`FLOCI_HOST_PERSISTENT_PATH` is used to derive `FLOCI_DATA_DIR` before validation. If validation fails, `exit 1` fires but `FLOCI_DATA_DIR` was already set from an invalid path. The character-class validation uses a long chain of `[[ ]]` glob negations which is hard to audit.

## Recommended Action
Reorder: validate before deriving `FLOCI_DATA_DIR`. Consider a positive-character-class allowlist instead of negation chain.

## User Decision
accepted

## Decision Rationale
User accepted this advisory finding. Implement as recommended.

## Implementation Ticket
<filled if accepted or implemented — reference to the implementation ticket>
