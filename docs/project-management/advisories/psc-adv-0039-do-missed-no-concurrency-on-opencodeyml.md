# Advisory: DO missed no concurrency on opencode.yml

| Field | Value |
|-------|-------|
| ID | psc-adv-0039-do-missed-no-concurrency-on-opencodeyml |
| Type | advisory |
| Status | accepted |
| Confidence | 85 |
| Priority | high |
| Source ticket | psc-0003 |
| Source agent | DO-challenger |
| Source file | [docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md](docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md) |
| Created | 2026-07-30 |
| Finding ID | M-22 |

## Description
opencode.yml has no `concurrency:` group. Two reviewers posting `/oc` on the same PR spawn two parallel jobs, both with `id-token: write`, both calling the LLM API.

## Recommended Action
Add `concurrency:` to opencode.yml grouped by PR/comment thread, `cancel-in-progress: true`.

## User Decision
accepted

## Decision Rationale
User accepted this advisory finding. Implement as recommended.

## Implementation Ticket
<filled if accepted or implemented — reference to the implementation ticket>
