# Ticket: psc-adv-0001

| Field | Value |
|-------|-------|
| Status | open |
| Type | advisory |
| Priority | high |
| Created | 2026-07-29 |
| Domain signals | [bash-scripting] [security] [infrastructure] [documentation] |
| Specialist roster | SW, TX, DX, SX, BS, DXS |
| Passport | docs/project-management/passports/psc-adv-0001-passport.md |
| Log dir | docs/project-management/logs/tickets/psc-adv-0001/ |
| Assigned to | code-architect |
| PM decision | (pending C4 review) |
| New tickets spawned | [] |
| Linked | ADRs: [], Conversations: [], Mistakes: [] |

## Acceptance Criteria
1. Advisory report generated for each of the 5 target files/documents
2. Each advisory report documents feasibility gaps, missing details, best practice gaps, or issues found
3. All findings avoid "theater" language and AI-generated filler language
5. Advisory reports created in docs/project-management/advisories/psc-adv-0001-*.md
6. Synthesis artifacts created per pipeline-passport A2/A2b phase

## Description
The user requests a comprehensive advisory review of 5 artifacts:

1. **docs/design/authentication-plan.md** — Validate feasibility of authentication plan, check for missing details/gaps in auth strategy, IAM delegation, credential rotation, secrets management
2. **setup-floci.sh** — Bash script (996 lines) for deploying Floci (AWS emulator) on Ubuntu Server with rootless Podman. Analyze for bash best practices, security hardening, idempotency, edge cases
3. **mock-server/dev-twin.sh** — Dev twin lifecycle script (dev-up, dev-down, dev-recreate, etc.) for persistent Lima dev VM. Analyze for dev workflow correctness, idempotency, dev UX
4. **mock-server/run-test.sh** — Lima digital-twin test harness orchestrator. Analyze for CI readiness, idempotency, evidence collection, twin lifecycle correctness
5. **docs/design/landing-zone-design.md** — AWS landing zone design (IAM delegation, hub-and-spoke, EKS/k3s, RDS, environment=account, infra/ layout). Review for gaps, best practices, IAM delegation model correctness

All findings must avoid "theater" language and AI-generated filler. Focus on concrete gaps, feasibility issues, missing details, security gaps, and best practice violations.

## Files
- docs/design/authentication-plan.md
- setup-floci.sh
- mock-server/dev-twin.sh
- mock-server/run-test.sh
- docs/design/landing-zone-design.md

## Dependencies
- None (advisory is independent)