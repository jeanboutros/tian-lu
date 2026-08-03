# A0: Task Definition — psc-0003

## Task Identity
- **Ticket:** psc-0003
- **Title:** Challenge Review Remediation — 49 accepted findings from psc-adv-0017
- **Priority:** critical
- **Source:** External challenge advisory psc-adv-0017 (1,471 lines, 50+ findings)

## Domain Classification
- **bash-scripting:** setup-floci.sh, dev-twin.sh, run-test.sh, run-in-vm.sh, preflight-floci.sh
- **security:** SigV4 enforcement, IAM delegation, permissions boundaries, credential rotation, presign secrets
- **infrastructure:** Terraform landing zone stages, providers, backends, governance tags
- **documentation:** authentication-plan.md, landing-zone-design.md, solution-design.md, gaps-register.md, AGENTS.md
- **CI/CD:** preflight gates, twin test harness, health checks, AppArmor profiles

## Specialist Roster
| Role | Agent | Scope |
|------|-------|-------|
| SW | software-engineer | Auth plan §4-§7 code blocks, setup-floci.sh, infra/ Terraform, IAM policies |
| TX | test-engineer | bats tests (phase5, dev_twin, preflight), SPEC-TX updates, twin validation |
| DX | docs-writer | Auth plan, landing-zone design, solution-design, gaps-register, AGENTS.md, cross-document consistency |
| SX | security-reviewer | SigV4 enforcement, IAM delegation, permissions boundaries, credential handling, presign secrets |
| BS | bash-specialist | All shell scripts: setup-floci.sh, dev-twin.sh, run-test.sh, run-in-vm.sh, preflight-floci.sh |
| DO | devops-specialist | CI/CD, preflight gates, twin test harness, health check budgets, AppArmor profiles |

**Total:** 6 specialists
**Domain signals detected:** [bash-scripting] [security] [infrastructure] [documentation] [CI/CD]

## Finding Categories
| Category | Count | Files Affected |
|----------|-------|---------------|
| CH-AUTH (auth plan) | 16 | authentication-plan.md, dev-twin.sh, run-in-vm.sh, run-test.sh |
| CH-INST (installer) | 5 | setup-floci.sh, AGENTS.md |
| CH-DEV (dev twin) | 6 | dev-twin.sh |
| CH-TWIN (test harness) | 7 | run-test.sh |
| CH-LZ (landing zone) | 13 | landing-zone-design.md, infra/, preflight-floci.sh, dev.tfvars |
| CH-META (meta-corrections) | 3 | Prior advisory corrections + lessons learned |
| **Total** | **50** | **19 files** |

## Key User Decisions
- CH-AUTH-001: Option 1 — per-environment FLOCI_DEFAULT_ACCOUNT_ID
- CH-AUTH-004: bats coverage required (7 test cases)
- CH-LZ-008: Restore governance tags in _common/providers.tf; Owner is general tag
- CH-LZ-009: >= 6.56.0 with NO upper bound
- CH-LZ-010: Omit key from providers.tf
- All other findings: ACCEPTED as specified

## Files to Change (19)
1. docs/design/authentication-plan.md
2. setup-floci.sh
3. mock-server/dev-twin.sh
4. mock-server/run-test.sh
5. mock-server/in-vm/run-in-vm.sh
6. docs/design/landing-zone-design.md
7. scripts/preflight-floci.sh
8. infra/live/10-management-iam/main.tf
9. infra/live/10-management-iam/providers.tf
10. infra/_common/providers.tf
11. infra/_common/versions.tf
12. infra/_common/backend.hcl.example
13. infra/environments/dev.tfvars
14. AGENTS.md
15. docs/design/gaps-register.md
16. docs/design/solution-design.md
17. mock-server/tests/dev_twin.bats
18. tests/phase5.bats
19. install.sh (root) — REMOVE
