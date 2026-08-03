# Decision: DO Dependabot recommendation incomplete

| Field | Value |
|-------|-------|
| ID | psc-dec-0021-do-dependabot-recommendation-incomplete |
| Type | decision |
| Status | resolved: challenger |
| Confidence | 85 |
| Priority | high |
| Source ticket | psc-0003 |
| Source agent | DO vs DO-challenger |
| Source file | [docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md](docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md) |
| Created | 2026-07-30 |
| Finding ID | D-21 |

## Description
Recommends only `package-ecosystem: "github-actions"` for Dependabot. The real supply-chain surface is container images (`docker.io/floci/floci:1.5.33-compat`) and Lima templates. Dependabot's `docker` ecosystem would track the Floci image tag. The `github-actions` ecosystem will not pin `@latest` to a SHA — that is a manual fix.

## Recommended Action
Add `docker` ecosystem to Dependabot for Floci image tag drift. Explicitly state that pinning `@latest` is a manual, one-time fix.

## User Decision
resolved: challenger

## Decision Rationale
User ruled: Challenger position accepted. The challenger finding is correct and the primary finding must be revised.

## Implementation Ticket
<filled if accepted or implemented — reference to the implementation ticket>
