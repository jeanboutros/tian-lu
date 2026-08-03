# Advisory: CI/CD and Operational Gaps

| Field | Value |
|-------|-------|
| ID | psc-adv-0005-ci-cd-gaps |
| Type | advisory |
| Status | awaiting user decision |
| Confidence | 88 |
| Priority | critical |
| Source ticket | psc-adv-0001 |
| Source agent | DXS, SX |
| Source file | [A2-dual-model-challenge.md](docs/project-management/logs/tickets/psc-adv-0001/A2-dual-model-challenge.md) |
| Created | 2026-07-30 |

## Description
Critical CI/CD supply-chain and operational gaps. The highest-severity finding in the entire repository is in this group.

**Consolidated findings:**

1. **M-DXS-001 (conf 92) — CRITICAL: `anomalyco/opencode/github@latest` unpinned in `opencode.yml`**: Unpinned mutable branch reference in a workflow with `id-token: write` AND `secrets.OLLAMA_API_KEY` access. A compromised action gets OIDC token + API key. **Highest-severity finding in the repository.** Primary only reviewed `test.yml` and missed `opencode.yml` entirely.

2. **M-SX-002 (conf 80) / M-SX-007 (conf 75) — `actions/checkout@v7` and `anomalyco/opencode/github@latest` unpinned**: Supply-chain substitution risk. `@latest` is the most dangerous form (auto-updates on every run).

3. **F-DXS-001 (conf 90) — `test.yml` missing `permissions:` block**: `GITHUB_TOKEN` defaults to read/write for all scopes. Challenger (M-SX-001, conf 85) confirmed this over-privileged token.

4. **M-DXS-002 (conf 75) — `opencode.yml` triggers on `issue_comment` with untrusted input**: Any user (including drive-by commenters on public repo) can trigger a workflow that runs an unpinned action with `id-token: write`.

5. **M-DXS-003 (conf 80) — No `timeout-minutes` on any CI job**: Default is 360 minutes (6 hours). A hung step burns 6 hours of runner time. For `opencode.yml` (with secret access), a hung run also prolongs credential-exposure window.

6. **F-DXS-002 (conf 85) — No Dependabot config for GitHub Actions**: No automated dependency updates for actions.

7. **M-DXS-005 (conf 68) — Dev env profile collision**: Already noted in landing-zone advisory but cross-cutting: `dev_env` profile name `[floci-dev]` collides with real AWS profiles.

8. **M-DXS-006 (conf 65) — `FIREWALL_SCOPE` catch-all silently falls through**: `configure_firewall` `case` uses `*)` catch-all for unknown values — typos silently fall through to `auto` instead of failing with clear error.

9. **F-DXS-004 (conf 85) — `wait_driver` false positive on empty PID**: Success path has false-positive when `DRIVER_SHELL_PID` is unset.

10. **F-DXS-006 (conf 80) — UFW stale rules on scope change**: `configure_firewall` does not clean up old rules when `FIREWALL_SCOPE` changes.

11. **F-DXS-012 (conf 80) — Dev-twin `ExecCondition` drift**: Dev twin's Quadlet `ExecCondition` diverges from production; drift documented but not version-controlled.

12. **F-SX-005 (conf 75) — No secret scanning in CI**: No secret scanning step in any workflow.

13. **D-DXS-001 (conf 92) — Primary's `actions/checkout` pin recommendation was stale v4.2.2**: Primary recommended `actions/checkout@11bd719... # v4.2.2` — a **downgrade of three major versions** from current v7. v7.0.0 introduced critical security fix blocking fork-PR checkouts for `pull_request_target`. Applying primary's recommendation as written would introduce a security regression. Correct pin: `actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1`.

14. **D-DXS-002 (conf 60) — F-DXS-007 rollback recommendation misapplies skill**: Primary recommended `--rollback` flag per reliability-scalability skill §7. Challenger correctly notes: the skill addresses continuous deployment of running services, not one-shot idempotent installers. The installer's idempotency IS the rollback strategy. Reframe as diagnostics improvement (transaction log / phase tracking).

15. **D-DXS-003 (conf 85) — F-DXS-011 formatting error**: Finding header reads `Confidence = 65` instead of `| Confidence | 65 |` — mechanical table structure defect.

## Recommended Action
1. **CRITICAL**: Pin `anomalyco/opencode/github` to full commit SHA in `opencode.yml`.
2. **CRITICAL**: Pin `actions/checkout` to `v7.0.1` SHA `3d3c42e5aac5ba805825da76410c181273ba90b1` in ALL workflows.
3. Add `permissions: contents: read` to `test.yml`; add `concurrency` group.
4. Add `timeout-minutes: 15` to test jobs, `30` to opencode job.
5. Add `.github/dependabot.yml` for GitHub Actions.
6. Add `github.event.comment.author_association` check to `opencode.yml` trigger (restrict to `MEMBER`/`OWNER`/`COLLABORATOR`).
7. Fix `FIREWALL_SCOPE` case: replace `*)` with explicit error for unknown values.
8. Add guard in `wait_driver` for empty `DRIVER_SHELL_PID`.
9. Add UFW rule cleanup on scope change in `configure_firewall`.
10. Version-control dev-twin `ExecCondition` override or document as intentional drift.
11. Add secret scanning step to CI (e.g., `trufflehog` or GitHub secret scanning).
12. Fix F-DXS-011 table formatting.
13. Reframe F-DXS-007 as diagnostics improvement (transaction log), not rollback gap.

## User Decision
all ok

## Decision Rationale

## Implementation Ticket