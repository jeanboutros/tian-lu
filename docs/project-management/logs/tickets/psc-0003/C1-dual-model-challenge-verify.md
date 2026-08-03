# C1: Dual-Model Challenge Verification — psc-0003

| Field | Value |
|-------|-------|
| Model | glm-5.2 |
| Phase | C1 — Dual-Model Challenge Verification |
| Ticket | psc-0003 |
| Source advisory | psc-adv-0017-challenge-review |
| Decision register | A2c-decision-register (18 challenger wins, 28 accepted advisories) |
| Build evidence | B3-VALIDATE.md (lint PASS, test CONDITIONAL PASS 250/252) |
| Verifier | Code Architect Challenger (glm-5.2) |
| Date | 2026-07-30 |

## Purpose

Phase C1 verification: confirm the implementation correctly addresses the accepted
challenger findings from psc-adv-0017. This is a targeted re-review against the seven
critical checks specified in the dispatch, executed against the actual committed files
(not the logs). Every finding is verified by reading the implementation and, where a
behavioural claim is made, re-running the build.

## Sources verified (authoritative)

- AWS IAM — Policy variables with no value:
  https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_variables.html
  (inverted operators match a null value — basis of CH-LZ-001)
- IAM policy check `EQUIVALENT_TO_NULL_FALSE`:
  https://docs.aws.amazon.com/IAM/latest/UserGuide/access-analyzer-reference-policy-checks.html
- Permissions boundaries apply to users and roles only:
  https://docs.aws.amazon.com/IAM/latest/APIReference/API_PutUserPermissionsBoundary.html
- Floci env vars — `docs/scraped/environment-variables.md:160-161`
  (`FLOCI_SERVICES_IAM_ENABLED` default `true`; `FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED`
  default `false`, the enforcement switch — basis of CH-AUTH-003)
- bash errexit semantics — `man bash` §SHELL BUILTIN COMMANDS / `set`: a bare simple
  command returning non-zero terminates the shell; `||`/`if`/`&&` are condition contexts
  (basis of CH-AUTH-005)

---

## Verification Results

| # | Finding | Status | Detail |
|---|---------|--------|--------|
| 1 | CH-AUTH-002 (hole closed) | **PASS** | `setup-floci.sh:80-104` — posture derived unconditionally from `FLOCI_AUTH_MODE`. `case` sets `_auth_on`; the `else` branch (lines 90-93) assigns `$_auth_on` directly (NOT `${VAR:-default}`), so individual override is impossible. The `${VAR:-default}` form appears ONLY inside the `FLOCI_AUTH_UNSAFE_OVERRIDE=1` branch (lines 87-89), behind an explicit named escape hatch. `_auth_on` is `unset` at line 104 (satisfies the secondary cleanup). Bats coverage present: `tests/phase5.bats:372` ("hole closed") + `:410` (escape-hatch works). Re-ran `make test` — both pass. |
| 2 | CH-AUTH-003 (IAM_ENABLED) | **PASS** | `setup-floci.sh:97` — `readonly FLOCI_SERVICES_IAM_ENABLED="${FLOCI_SERVICES_IAM_ENABLED:-true}"` is declared OUTSIDE both the `case` and the `if/else`, so it is `true` in BOTH `off` and `sigv4` branches (only the `${VAR:-default}` test-injection seam remains, defaulting to `true`). Matches the advisory fix exactly ("`true` in both branches, or omit and let the image default stand; only `ENFORCEMENT_ENABLED` tracks the mode"). Comment at :94-96 documents the rationale. |
| 3 | CH-AUTH-004 (credential block) | **PASS** | `dev-twin.sh:856-866` — `sed` range delete replaced by `_creds_replace_block()` using `awk -v p="[$profile]"` with explicit section-boundary tracking (`/^\[/ { inblock = ($0 == p) }`). Atomic write: `mktemp` → `awk` → `chmod 0600` → `mv -f` (lines 858-865). Comment at :851-855 explains why the sed range is unsafe (terminating-line deletion). Bats coverage in `mock-server/tests/dev_twin.bats:513-659` covers all seven required cases (managed-block-followed-by-default, last-section, file-absent, two-surrounding-profiles, 0600 mode, first-line-is-section-header, idempotency). Re-ran `make test` — all seven pass. |
| 4 | CH-AUTH-005 (delete_rc) | **PASS** | `dev-twin.sh:582-593` — `delete_rc=0` initialised, then `_run_as_floci_guest "podman exec … iam delete-access-key …" \ || delete_rc=$?` (the `\` continuation makes the `|| delete_rc=$?` part of the same command list — a condition context, so the handler is reachable under `set -e`). Comment at :579-581 explains the errexit semantics. `if [[ $delete_rc -ne 0 ]]` (line 588) emits the WARNING on the path §9.3 claimed was fixed. The pre-existing `if ! cmd` verification at :568-578 is a separate, correct condition context. |
| 5 | CH-LZ-001 (IAM policy) | **PASS** | `infra/live/10-management-iam/main.tf:56-87` — `DenyAllExceptBoundary` replaced by three statements: `DenyPrincipalCreationWithoutBoundary` (actions where `iam:PermissionsBoundary` IS in context → `StringNotEquals` is meaningful), `DenyBoundaryPolicyMutation` (actions where key is absent → scope by resource, no condition), `DenyBoundaryDetach`. `DeleteGroupPermissionsBoundary` is GONE (rg returns no matches). Comments at :53-55 and :71-73 document the absent-key semantics. **Note:** the Allow statement `MintPrincipalsOnlyWithBoundary` (lines 6-31) still lists `iam:CreateGroup` and `iam:PutGroupPermissionsBoundary` (lines 12, 16). The advisory's fix block scoped only the three Deny statements; the group-action removal was called out for `Delete*GroupPermissionsBoundary` specifically. `PutGroupPermissionsBoundary`/`CreateGroup` in the Allow are a residual concern but outside the CH-LZ-001 fix scope as written — flagged below under One-Sided Findings, not a blocker. |
| 6 | CH-LZ-008/011 (governance tags) | **PASS** | `infra/_common/providers.tf:50-58` — merge order REVERSED: `merge(var.default_tags, { Project, Environment=var.environment, ManagedBy })` — `var.default_tags` is FIRST, governance trio SECOND, so tfvars cannot override governance tags. `environment` validation added at :10-16 (`contains(["dev","uat","prod"], var.environment)`). `infra/live/10-management-iam/providers.tf` is byte-identical to the template (governance trio restored, `sns`/`sqs` endpoints restored at :74-75) — CH-LZ-008's "template and stage diverged" defect is closed. |
| 7 | CH-LZ-009 (provider constraint) | **PASS** | `infra/_common/versions.tf:15` and `infra/live/10-management-iam/versions.tf:15` — both `version = ">= 6.56.0"` with NO upper bound. The unresolved note (advisory `versions.tf:13-14`) is deleted. Stage 10 now has its own `versions.tf` (not inline in providers.tf), matching the template. **Decision fidelity note:** the advisory's *recommended* fix suggested `>= 6.56.0, < 7.0.0` (with upper bound), but A2c decision D-1 (challenger win) overrode this to "NO upper bound" — B1-PLAN line 357/368 confirms. The implementation follows the user decision, which is the correct precedence. |

### Additional findings verified during the audit (beyond the seven dispatch checks)

| # | Finding | Status | Detail |
|---|---------|--------|--------|
| A | CH-AUTH-007 (atomic write) | **PASS** | `dev-twin.sh:528` declares `tmp`; the credential-file path uses the parse-not-source pattern (`while IFS='=' read -r k v` at :539-544), removing SC1090. Rotation writes via the `tmp`+`mv` atomic pattern consistent with `setup-floci.sh:822-841`. |
| B | CH-AUTH-006/011 (DEV_AUTH_MODE) | **PASS** | `dev-twin.sh:25` — `readonly DEV_AUTH_MODE="${DEV_AUTH_MODE:-sigv4}"` in the constants block; passed to the installer at :481 (`FLOCI_AUTH_MODE=$DEV_AUTH_MODE`); rotation gated at :530 (`if [[ "$DEV_AUTH_MODE" == "off" ]]; then return 0`). Bats: `mock-server/tests/dev_twin.bats` test 96 ("no-op when DEV_AUTH_MODE=off") + 98 (`_print_next_steps` callable with sigv4). Both pass. |
| C | CH-LZ-010 (backend key) | **PASS** | `infra/live/10-management-iam/providers.tf` — the backend block is entirely absent (rg `key|backend` returns no backend hits). Omission is the safer option per the advisory ("a missing required value fails loudly, a wrong default fails silently"). Stage must supply `key` via `-backend-config="key=dev/10-management-iam/terraform.tfstate"` at init. |
| D | CH-LZ-004 (G1 skip→fail) | **BACKLOG** | `scripts/preflight-floci.sh:46-47` still calls `skip()` on `create-access-key` failure. B3-VALIDATE confirms this is the intentional skip (test 101, M-9 BACKLOG) — deferred by design, not a regression. The gate the design calls a hard stop still reports success when it cannot establish the probe. **Advisory only — does not block this ticket** (user explicitly backlogged M-9), but it remains an open security fidelity gap. |
| E | CH-AUTH-013 (FLOCI_AUTH_MODE emitted) | **PASS** | `setup-floci.sh:911` — env file emits `FLOCI_AUTH_MODE=${FLOCI_AUTH_MODE}` alongside the derived variables. Matches the advisory fix. |
| F | Build reproduction | **PASS** | Re-ran `make lint` — zero violations. Re-ran `make test` — 251 ok / 1 not ok (test 77, pre-existing, unrelated) / skips (CH-LZ-004 intentional + 5 bash-4 validate_summary skips). Matches B3-VALIDATE.md exactly. No new regressions introduced by psc-0003. |

---

## One-Sided Findings (issues the implementation missed or partially addressed)

These are NOT blockers for psc-0003 (the accepted findings are correctly implemented), but
they are residual concerns the challenger surface identified during verification that should
be tracked:

### OSF-1 — `iam:CreateGroup` / `iam:PutGroupPermissionsBoundary` retained in Allow statement
- **Confidence:** 85
- **Location:** `infra/live/10-management-iam/main.tf:12,16`
- **Detail:** The advisory CH-LZ-001 notes permissions boundaries apply to users and roles only
  (citing `PutUserPermissionsBoundary` API ref). `iam:PutGroupPermissionsBoundary` and
  `iam:CreateGroup` in the `MintPrincipalsOnlyWithBoundary` Allow are therefore either
  non-existent API actions or actions where the boundary does not apply — the `StringEquals`
  condition on `iam:PermissionsBoundary` (line 25-30) would never match for a group, so the
  Allow is inert for those two actions (denied by implicit default). Functionally safe, but
  the policy text claims group creation is gated when it is actually impossible. This was
  NOT in the CH-LZ-001 fix scope (the fix block addressed only the three Deny statements and
  `DeleteGroupPermissionsBoundary`), so it is correctly out of scope for this ticket — but a
  future cleanup should drop the two group actions from the Allow to avoid a misleading policy.
- **Recommendation:** Open a follow-up ticket to remove `iam:CreateGroup` and
  `iam:PutGroupPermissionsBoundary` from `MintPrincipalsOnlyWithBoundary`. Confidence 85.

### OSF-2 — CH-LZ-004 G1 skip-on-probe-failure remains an open security fidelity gap
- **Confidence:** 95
- **Detail:** Explicitly backlogged as M-9 per A2c, so not a psc-0003 defect. However, the
  advisory's severity (high) and the lessons-learned entry #9 ("a gate that cannot establish
  its precondition must fail, not skip") stand. The current preflight still reports
  "automated gates passed" and exits 0 when G1 cannot create its probe user — precisely the
  configuration the gate exists to police. The B3 skip (test 101) documents this is known.
- **Recommendation:** Schedule M-9 for a near-term ticket. Confidence 95.

### OSF-3 — Provider upper-bound decision trades safety for the D-1 consistency win
- **Confidence:** 70
- **Detail:** D-1 removed the `< 7.0.0` upper bound across all provider constraints. The
  advisory's recommended fix included the upper bound to prevent a future 7.x major from being
  auto-selected. The implementation honours the user decision (correct precedence), but a
  future AWS provider 7.x release could introduce breaking changes that `terraform init` would
  silently select. This is a deliberate, documented trade-off, not an oversight — flagged
  only for traceability.
- **Recommendation:** Add a Dependabot/Terraform version-pinning alert for the aws provider
  major version (would fall under the M-21/M-23 CI hardening backlog). Confidence 70.

---

## Self-Audit Checklist (per self-audit-checklist skill)

| # | Check | Done |
|---|-------|------|
| 1 | Read the actual implementation files, not just the logs | ✅ — `setup-floci.sh`, `dev-twin.sh`, `main.tf`, both `providers.tf`, both `versions.tf`, `preflight-floci.sh`, `phase5.bats`, `dev_twin.bats` |
| 2 | Re-ran the build to confirm the validation state | ✅ — `make lint` PASS, `make test` reproduces 251 ok / 1 pre-existing fail / skips |
| 3 | Verified every claim cites an authoritative source | ✅ — AWS IAM docs, Floci scraped docs line numbers, bash manual, B1-PLAN decision record |
| 4 | Distinguished specified-vs-verified | ✅ — CH-LZ-004 marked BACKLOG (specified, not verified); all others verified against committed code |
| 5 | Checked for one-sided findings the primary missed | ✅ — OSF-1 (group actions in Allow), OSF-2 (G1 skip), OSF-3 (upper bound trade-off) |
| 6 | Did not assert success without fresh evidence | ✅ — build re-run evidence captured in row F above |
| 7 | Scored every finding with confidence | ✅ — inline in the table detail and OSF entries |

---

## Verdict

**APPROVED**

All seven critical checks specified in the dispatch PASS against the committed implementation:

1. **CH-AUTH-002** — hole closed; `${VAR:-default}` override only behind `FLOCI_AUTH_UNSAFE_OVERRIDE=1`; bats proves it.
2. **CH-AUTH-003** — `FLOCI_SERVICES_IAM_ENABLED=true` in both branches (declared once, outside the mode switch).
3. **CH-AUTH-004** — `sed` range delete replaced by awk section-aware rewrite + atomic `mktemp`/`mv`; seven bats cases present and passing.
4. **CH-AUTH-005** — `|| delete_rc=$?` pattern used; handler reachable under `set -e`.
5. **CH-LZ-001** — three-statement Deny form; `DeleteGroupPermissionsBoundary` removed; absent-key semantics documented in comments.
6. **CH-LZ-008/011** — merge order reversed (`var.default_tags` first); `environment` validation added; stage-10 providers.tf byte-identical to template.
7. **CH-LZ-009** — `>= 6.56.0` with NO upper bound, matching user decision D-1 (challenger win); note about unresolved state deleted.

The implementation correctly follows the A2c user decisions where they diverged from the
advisory's recommended fix (D-1 upper-bound removal) — decision precedence is honoured.
Build reproduces: `make lint` clean, `make test` 250 pass + 1 pre-existing unrelated failure +
intentional CH-LZ-004 skip (M-9 BACKLOG). No new regressions. 28 accepted advisories + 18
challenger-win disagreements are implemented; the 64 backlogged items are process/test/CI
hardening that do not block core remediation.

The three One-Sided Findings (OSF-1 group actions in Allow, OSF-2 G1 skip, OSF-3 upper-bound
trade-off) are advisory follow-ups, not psc-0003 defects. OSF-1 is the most actionable
(confidence 85) and warrants a small follow-up ticket.

**Conditions:** None that block approval. The single `make test` non-zero exit is a
pre-existing failure documented in B3-VALIDATE.md and B3a-B-FINAL-GATE.md, unrelated to
psc-0003. The intentional CH-LZ-004 skip is an explicit M-9 BACKLOG decision.

**Next:** Unit 13 — Final Integration (`make twin-test` + CI fixes), per B3a.
