# A0: Task Definition — psc-adv-0001

| Field | Value |
|-------|-------|
| Ticket | psc-adv-0001 |
| Type | advisory |
| Created | 2026-07-29 |
| Log dir | docs/project-management/logs/tickets/psc-adv-0001/ |

## Task Scope

Comprehensive advisory review of 5 artifacts:

1. **docs/design/authentication-plan.md** — Validate feasibility of Floci auth plan (SigV4, IAM enforcement, credential rotation, FLOCI_AUTH_MODE parameter). Check for missing details, gaps, security issues.
2. **setup-floci.sh** (1020 lines) — Bash installer for Floci on Ubuntu with rootless Podman. Review for bash best practices, security hardening, idempotency, edge cases, error handling.
3. **mock-server/dev-twin.sh** (801 lines) — Dev twin lifecycle script for persistent Lima dev VM. Review for correctness, idempotency, dev UX, error handling.
4. **mock-server/run-test.sh** (563 lines) — Lima digital-twin test harness orchestrator. Review for CI readiness, evidence collection, twin lifecycle correctness.
5. **docs/design/landing-zone-design.md** (511 lines) — AWS landing zone design (IAM delegation, hub-and-spoke, EKS/k3s, RDS, environment=account). Review for gaps, best practices, IAM model correctness.

## Domain Classification

| Domain Signal | Detected | Rationale |
|---------------|----------|-----------|
| bash-scripting | Yes | All 3 scripts are bash |
| security | Yes | Auth plan, IAM, credential rotation, secrets |
| infrastructure | Yes | Floci, Podman, systemd, Lima, Terraform |
| documentation | Yes | Design doc reviews |

## Specialist Roster

**Roster: SW, TX, DX, SX, BS, DXS**
**Total: 6 specialists**

| Specialist | Role | Focus |
|------------|------|-------|
| SW (Software Engineer) | Default | Architecture, API design, component boundaries |
| TX (Test Engineer) | Default | Test strategy, edge case coverage, CI readiness |
| DX (Docs Writer) | Default | Documentation quality, cross-document consistency |
| SX (Security Reviewer) | Conditional (security) | Auth plan, IAM, credential rotation, secrets |
| BS (Bash Specialist) | Conditional (bash-scripting) | Bash best practices, portability, security hardening |
| DXS (DevOps Specialist) | Conditional (infrastructure) | CI/CD patterns, deployment, infrastructure |

## Constraints

- Avoid "theater" language and AI-generated filler
- Focus on concrete gaps, feasibility issues, missing details
- High engineering standards: documentation, code comments, docstrings
- All findings must cite authoritative references where applicable

## Pipeline Path

Advisory ticket: Phase A only (A0 → A1 → A2 → A2b → A2c → A2a → A3 → A-GATE → C4 → COMMIT)
