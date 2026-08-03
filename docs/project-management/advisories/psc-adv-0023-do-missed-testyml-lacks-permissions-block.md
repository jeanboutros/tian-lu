# Advisory: DO missed test.yml lacks permissions: block

| Field | Value |
|-------|-------|
| ID | psc-adv-0023-do-missed-testyml-lacks-permissions-block |
| Type | advisory |
| Status | accepted |
| Confidence | 92 |
| Priority | critical |
| Source ticket | psc-0003 |
| Source agent | DO-challenger |
| Source file | [docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md](docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md) |
| Created | 2026-07-30 |
| Finding ID | M-6 |

## Description
`.github/workflows/test.yml` has no top-level or job-level `permissions:` key. GITHUB_TOKEN defaults to broad read/write. For a lint+unit job that only needs to read code, the token should be `permissions: { contents: read }` at minimum.

## Recommended Action
Add `permissions: { contents: read }` to `test.yml` (SPEC-DO-019).

## User Decision
accepted

## Decision Rationale
User accepted this advisory finding. Implement as recommended.

## Implementation Ticket
<filled if accepted or implemented — reference to the implementation ticket>
