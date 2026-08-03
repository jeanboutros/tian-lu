# Advisory: No test for CH-AUTH-001 probe outcome

| Field | Value |
|-------|-------|
| ID | psc-adv-0029-no-test-for-ch-auth-001-probe-outcome |
| Type | advisory |
| Status | accepted |
| Confidence | 90 |
| Priority | critical |
| Source ticket | psc-0003 |
| Source agent | TX-challenger |
| Source file | [docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md](docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md) |
| Created | 2026-07-30 |
| Finding ID | M-12 |

## Description
CH-AUTH-001 is the highest-priority finding. The advisory specifies a three-outcome probe that must be run regardless of the chosen option. The primary's dependency table lists CH-AUTH-002 as priority 1; CH-AUTH-001 is absent entirely. No test spec exists for recording the probe outcome as a gap-register entry.

## Recommended Action
Record the CH-AUTH-001 probe outcome as a test-plan dependency — at minimum a gap-register-assertion test.

## User Decision
accepted

## Decision Rationale
User accepted this advisory finding. Implement as recommended.

## Implementation Ticket
<filled if accepted or implemented — reference to the implementation ticket>
