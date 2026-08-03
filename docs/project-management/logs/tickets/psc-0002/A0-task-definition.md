# A0: Task Definition — psc-0002

| Field | Value |
|-------|-------|
| Ticket | psc-0002 |
| Type | feature |
| Created | 2026-07-30 |
| Log dir | docs/project-management/logs/tickets/psc-0002/ |

## Task Scope

Enrich `docs/design/authentication-plan.md` with all accepted findings from advisory review psc-adv-0001. Transform the auth plan from a design proposal into a complete implementation specification.

## Accepted Findings to Incorporate (49 total)

### From psc-adv-0001-auth-plan-gaps.md (9)
- M-SW-001: Region mismatch — use eu-west-2, make DEV_REGION constant
- M-SW-002: Deny statement no-op — correct resource scoping
- D-SW-001: readonly inside case — compute values into non-readonly locals
- M-SX-003: Non-atomic credential write — .tmp + chmod 0600 + mv -f
- M-SW-005: Missing verification step — sts get-caller-identity between create and delete
- F-SW-001: FLOCI_SERVICES_IAM_ENABLED missing from sigv4 branch
- M-SX-006: FLOCI_AUTH_PRESIGN_SECRET scope gap — add threat model + rotation
- M-DX-003: Secret in stdout — masked output, show file location
- M-DX-004: Resume-path gap — document expected behavior

### From psc-adv-0002-landing-zone-defects.md (6)
- M-SW-003: Hardcoded backend bucket — document full terraform apply command
- M-SW-004: Environment = "development" tag fix
- M-SX-005: STS DurationSeconds bound + re-assumption cadence
- F-DXS-005: Namespace dev-env AWS profile, document
- F-DX-003: Gap entry GAP-015 (Floci no root user)
- F-DX-004: IAM identity lifecycle note in solution-design.md

### From psc-adv-0004-bash-defects.md (11, auto-approved)
- F-BS-001: $* arg boundary loss in _run_as_floci_guest
- M-BS-001: set -o errtrace in all scripts
- M-BS-003: Split local x="$(cmd)" assignments
- F-BS-002, F-BS-003: Trap cleanup for temp files
- M-BS-002: Signal trap + orphan cleanup in run-test.sh
- F-BS-005: Document sort -V GNU dependency
- F-BS-007: Fix driver_args[*] expansion
- F-BS-008: ERR trap / stack backtrace
- F-BS-009: Fix function documentation mismatch
- F-BS-011: Fix error suppression in _install_exec_condition

### From psc-adv-0005-ci-cd-gaps.md (15)
- M-DXS-001: Pin opencode action to commit SHA
- M-SX-002: Pin actions/checkout to v7.0.1 SHA
- M-SX-007: Restrict opencode workflow triggers
- F-DXS-001: Permissions block + concurrency in test.yml
- F-DXS-002: Dependabot config
- M-DXS-003: timeout-minutes on CI jobs
- M-DXS-002: author_association check
- F-DXS-004: Fix wait_driver false positive
- F-DXS-006: UFW rule cleanup on scope change
- F-DXS-012: Document dev-twin ExecCondition override
- F-SX-005: Secret scanning in CI
- M-DXS-005: Namespace dev-env profile
- M-DXS-006: Validate FIREWALL_SCOPE explicitly
- D-DXS-001: Correct action-pinning SHA
- D-DXS-002, D-DXS-003: Reframe rollback + fix formatting

### From psc-adv-0006-test-coverage-gaps.md (12)
- F-TX-001: Rotation unit tests (5 cases)
- M-TX-001, M-TX-002: Mode-gating tests
- F-TX-002: run-in-vm.sh auth-mode tests
- F-TX-011/012/013: FLOCI_AUTH_MODE tests
- F-TX-014: dev_env tests
- F-TX-015: preflight-floci.sh tests
- M-TX-006: Cross-cutting podman exec override tests
- M-TX-004: chmod failure test
- F-TX-004: Replace grep/sed JSON parsing with jq
- M-TX-003: Fix wait_driver success-path hang

### From psc-adv-0007-documentation-gaps.md (4)
- F-DX-003: Gap entry GAP-015
- F-DX-004: IAM identity lifecycle note
- F-DX-014: dev_env idempotency fix (sed replace-then-write)
- M-DX-004: Document resume-path behavior

## Rejected Findings (NOT incorporated)
- Advisory 3 entirely (auth implementation gaps — plan is a plan)
- M-DX-002, M-DX-001, M-DX-005, F-DX-001, F-DX-002: Various doc/ADR findings

## Domain Classification

| Domain Signal | Detected |
|---------------|----------|
| bash-scripting | Yes |
| security | Yes |
| infrastructure | Yes |
| documentation | Yes |

## Specialist Roster

**Roster: SW, TX, DX, BS** (SX skipped — advisory review completed)
**Total: 4 specialists**

## Pipeline Path

Feature ticket: Full pipeline A→B→C→C4→CR→COMMIT
Phase A streamlined: A1-SX, A2, A2b, A2c, A2a skipped (advisory review equivalent)
