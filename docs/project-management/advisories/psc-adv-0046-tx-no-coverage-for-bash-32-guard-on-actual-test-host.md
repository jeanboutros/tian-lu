# Advisory: TX no coverage for bash-3.2 guard on actual test host

| Field | Value |
|-------|-------|
| ID | psc-adv-0046-tx-no-coverage-for-bash-32-guard-on-actual-test-host |
| Type | advisory |
| Status | accepted |
| Confidence | 88 |
| Priority | high |
| Source ticket | psc-0003 |
| Source agent | TX-challenger |
| Source file | [docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md](docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md) |
| Created | 2026-07-30 |
| Finding ID | M-29 |

## Description
CH-AUTH-009 is about `/bin/bash` 3.2 on macOS. A test that runs under Homebrew bash 5 would pass trivially and prove nothing. The test plan must specify `/bin/bash -c` explicitly.

## Recommended Action
Specify `/bin/bash` (3.2) as the interpreter for the CH-AUTH-009 test.

## User Decision
accepted

## Decision Rationale
User accepted this advisory finding. Implement as recommended.

## Implementation Ticket
<filled if accepted or implemented — reference to the implementation ticket>
