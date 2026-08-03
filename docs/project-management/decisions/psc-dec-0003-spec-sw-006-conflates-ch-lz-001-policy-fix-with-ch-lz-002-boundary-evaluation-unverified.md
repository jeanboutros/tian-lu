# Decision: SPEC-SW-006 conflates CH-LZ-001 (policy fix) with CH-LZ-002 (boundary evaluation unverified)

| Field | Value |
|-------|-------|
| ID | psc-dec-0003-spec-sw-006-conflates-ch-lz-001-policy-fix-with-ch-lz-002-boundary-evaluation-unverified |
| Type | decision |
| Status | resolved: challenger |
| Confidence | 85 |
| Priority | high |
| Source ticket | psc-0003 |
| Source agent | SW vs SW-challenger |
| Source file | [docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md](docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md) |
| Created | 2026-07-30 |
| Finding ID | D-3 |

## Description
CH-LZ-002 bundled as acceptance criterion #6 in SPEC-SW-006 ("G6 negative test added per CH-LZ-002"). CH-LZ-002 is a standalone high-severity finding with distinct architectural implication: Floci may not evaluate boundaries at all. Bundling it treats it as a test-addition task rather than a finding that may invalidate the delegated-administration architecture.

## Recommended Action
Create SPEC-SW-015 for CH-LZ-002 with G6 as primary gate, dependency on the probe, §1.1 qualification requirement, and SX/TX/DO dependencies.

## User Decision
resolved: challenger

## Decision Rationale
User ruled: Challenger position accepted. The challenger finding is correct and the primary finding must be revised.

## Implementation Ticket
<filled if accepted or implemented — reference to the implementation ticket>
