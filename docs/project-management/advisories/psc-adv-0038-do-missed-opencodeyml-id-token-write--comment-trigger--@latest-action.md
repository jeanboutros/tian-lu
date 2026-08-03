# Advisory: DO missed opencode.yml id-token: write + comment trigger + @latest action

| Field | Value |
|-------|-------|
| ID | psc-adv-0038-do-missed-opencodeyml-id-token-write--comment-trigger--@latest-action |
| Type | advisory |
| Status | accepted |
| Confidence | 88 |
| Priority | high |
| Source ticket | psc-0003 |
| Source agent | DO-challenger |
| Source file | [docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md](docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md) |
| Created | 2026-07-30 |
| Finding ID | M-21 |

## Description
opencode.yml triggers on `issue_comment` (untrusted input), requests `id-token: write`, runs `anomalyco/opencode/github@latest` (floating tag) with `OLLAMA_API_KEY` injected. Even with `persist-credentials: false`, the OIDC token is available to the `@latest` action's code.

## Recommended Action
Pin action to full SHA. Add `environment:` with required reviewers. Reduce `permissions` to minimum.

## User Decision
accepted

## Decision Rationale
User accepted this advisory finding. Implement as recommended.

## Implementation Ticket
<filled if accepted or implemented — reference to the implementation ticket>
