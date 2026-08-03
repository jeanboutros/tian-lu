# Decision: DO SPEC-DO-009 `--fresh`/`--keep` over-specified and self-contradictory

| Field | Value |
|-------|-------|
| ID | psc-dec-0022-do-spec-do-009-`--fresh`-`--keep`-over-specified-and-self-contradictory |
| Type | decision |
| Status | resolved: challenger |
| Confidence | 80 |
| Priority | high |
| Source ticket | psc-0003 |
| Source agent | DO vs DO-challenger |
| Source file | [docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md](docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md) |
| Created | 2026-07-30 |
| Finding ID | D-22 |

## Description
Acceptance criterion 3: "`--fresh` and `--keep` are mutually exclusive; the last one wins." Mutual exclusivity and "last one wins" are contradictory. "Last wins" perpetuates the order-dependence bug being fixed. Also: making `--keep` the default conflicts with `Makefile:30` default `TWIN_FLAGS ?= --fresh --reboot-test`.

## Recommended Action
Pick one model: either reject the combination (`die "mutually exclusive"`) or make `--fresh` imply `--destroy`. Reconcile with `Makefile:30`.

## User Decision
resolved: challenger

## Decision Rationale
User ruled: Challenger position accepted. The challenger finding is correct and the primary finding must be revised.

## Implementation Ticket
<filled if accepted or implemented — reference to the implementation ticket>
