# Decision: DO under-weights opencode.yml as CI/CD attack surface

| Field | Value |
|-------|-------|
| ID | psc-dec-0020-do-under-weights-opencodeyml-as-ci-cd-attack-surface |
| Type | decision |
| Status | resolved: primary |
| Confidence | 90 |
| Priority | critical |
| Source ticket | psc-0003 |
| Source agent | DO vs DO-challenger |
| Source file | [docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md](docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md) |
| Created | 2026-07-30 |
| Finding ID | D-20 |

## Description
opencode.yml treated as out of scope; no SPEC-DO finding covers it. opencode.yml triggers on `issue_comment` (untrusted input from forks), requests `id-token: write`, runs `anomalyco/opencode/github@latest` (floating tag, not SHA-pinned) with `OLLAMA_API_KEY` injected. This is a textbook OWASP CI/CD Top-10 vector. Severity 8 — higher than the primary's top severity of 7.

## Recommended Action
Add SPEC-DO-018: pin `anomalyco/opencode/github@latest` to full SHA, add `environment:` with required reviewers, reduce `permissions` to minimum.

## User Decision
resolved: primary

## Decision Rationale
User ruled: Primary position accepted. The primary finding stands; challenger position rejected.

## Implementation Ticket
<filled if accepted or implemented — reference to the implementation ticket>
