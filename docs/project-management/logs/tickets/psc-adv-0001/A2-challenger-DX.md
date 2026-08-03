# A2-Challenger-DX: Dual-Model Challenge — psc-adv-0001

| Field | Value |
|-------|-------|
| Model | glm-5.2 |
| Phase | A2 |
| Primary Output | DX review of 5 artifacts (auth plan, landing-zone design, setup-floci.sh, dev-twin.sh, run-test.sh). 14 findings (F-DX-001..014), 3 positive (F-DX-011..013), cross-document report, CONDITIONAL PASS. |
| Ticket | psc-adv-0001 |
| Challenger | Docs Writer Challenger (glm-5.2) |

---

## Verification Approach

The primary's claims were independently verified against the actual codebase:
- `rg` for `FLOCI_AUTH_MODE`, `FLOCI_AUTH_VALIDATE_SIGNATURES`, `FLOCI_SERVICES_IAM_*`, `DEV_CREDENTIALS_FILE`, `_rotate_bootstrap`, `DEV_AUTH_MODE`, `FLOCI_BOOTSTRAP_*`, `platform-admin`, `floci-deployer`, `auth-mode`, `AUTH_MODE`.
- Direct reads of `setup-floci.sh:810-845` (`write_env_file`), `setup-floci.sh:946` (`print_summary`), `dev-twin.sh:757-777` (`dev_env`), `scripts/preflight-floci.sh:35` (`aws_admin`), `run-test.sh:65-106` (`parse_args`).
- Inventory of `docs/adr/`, `docs/learning/decisions/`, `docs/project-management/decisions/`, and `counters.json`.
- Reads of `docs/learning/AGENTS.md` (isolation rules), `landing-zone-design.md` §5.1/§13/§15, `infra/AGENTS.md` (platform-admin stub status), `infra/live/10-management-iam/main.tf`.

---

## Agreements

The following primary findings are **confirmed correct** by independent codebase verification:

- **F-DX-001 (conf 90) — Auth plan reads as implemented.** Verified: `FLOCI_AUTH_MODE` does not appear anywhere in `setup-floci.sh`, `dev-twin.sh`, `run-test.sh`, or `preflight-floci.sh`. The auth plan §4.2/§6 use present-tense ("The installer accepts a single `FLOCI_AUTH_MODE` env var") while §6 uses imperative ("Add the `FLOCI_AUTH_MODE` case statement"). The status-banner recommendation is sound. AGREE.
- **F-DX-002 (conf 85) — `platform-admin` described as concrete identity but Terraform creates only the policy.** Verified: `infra/live/10-management-iam/main.tf:94` creates only `aws_iam_policy.platform_admin`; no `aws_iam_user`, `aws_iam_group`, or `aws_iam_role` resource exists. `infra/AGENTS.md:47` states "no users/roles/groups ... Stub until Phase 1." Yet auth plan §3.1 lists "platform-admin IAM user/group/role | Created by Terraform stage `10-management-iam`" and landing-zone §5.1 says "an assumable administrative identity (group + user + role)." AGREE — this is a genuine cross-document inconsistency.
- **F-DX-003 (conf 90) — Promised gap entry in `gaps-register.md` does not exist.** Verified: `gaps-register.md` contains only GAP-009 (closed), GAP-013b (open), GAP-014 (partially closed). No entry for "Floci has no root user concept" despite auth plan §3.2 and §6.12 promising it. AGREE.
- **F-DX-004 (conf 90) — Promised lifecycle note in `solution-design.md`/`REVIEW.md` does not exist.** Verified: `rg "floci-deployer|platform-admin"` across both files returns zero matches. AGREE.
- **F-DX-005 (conf 95) — `dev_env` writes hardcoded `test/test`.** Verified: `dev-twin.sh:769` writes `aws_access_key_id = test\naws_secret_access_key = test`. No `DEV_CREDENTIALS_FILE` or `_rotate_bootstrap` exists anywhere. AGREE.
- **F-DX-006 (conf 90) — `print_summary` unconditionally prints UNAUTHENTICATED.** Verified: `setup-floci.sh:946` prints the risk line unconditionally; no `FLOCI_AUTH_MODE` conditional. AGREE.
- **F-DX-007 (conf 90) — `write_env_file` omits auth vars.** Verified: `setup-floci.sh:823-841` writes 15 vars ending at `FLOCI_DOCKER_LOG_MAX_FILE`; none of `FLOCI_AUTH_VALIDATE_SIGNATURES`, `FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED`, `FLOCI_SERVICES_IAM_SEED_DEPLOYER_PRINCIPAL` appear. AGREE.
- **F-DX-008 (conf 85) — `run-test.sh` has no `--auth-mode` flag.** Verified: `parse_args` (lines 65-106) handles `--fresh`, `--keep`, `--destroy`, `--no-sidecar`, `--reboot-test`, `--evidence-dir`; no `--auth-mode`. AGREE.
- **F-DX-011 (conf 95) — Code comment quality is strong.** Verified via spot-checks of function headers. AGREE (positive finding).
- **F-DX-012 (conf 90) — Reference quality is strong.** Verified: auth plan §1 cites Floci scraped docs + AWS IAM User Guide; landing-zone §15 has 20+ authoritative links. AGREE (positive finding).
- **F-DX-013 (conf 95) — AGENTS.md conventions followed.** Verified: all three scripts have `set -euo pipefail`, `readonly` config, guarded `main`, pydoc headers. AGREE (positive finding).
- **F-DX-014 (conf 80) — `dev_env` idempotency bug.** Verified: `dev-twin.sh:768` guard `if ! grep -q '\[floci-dev\]'` only writes when block absent; never updates stale creds. AGREE.

---

## Disagreements

### D-DX-001: F-DX-009 contains a factual error — `preflight-floci.sh` does NOT reference `FLOCI_BOOTSTRAP_AKID`

| Field | Value |
|-------|-------|
| Primary Finding | F-DX-009 |
| Confidence | 92 |
| Primary Position | The primary claims `aws_admin` "partially implements" the auth plan §6.9 because `FLOCI_BOOTSTRAP_AKID` is referenced but `FLOCI_BOOTSTRAP_SECRET` is not; the primary quotes code with `AWS_ACCESS_KEY_ID="${FLOCI_BOOTSTRAP_AKID:-$DEV_AKID}"`. |
| Challenger Position | This is factually wrong. The actual `scripts/preflight-floci.sh:35` reads: `aws_admin() { AWS_ACCESS_KEY_ID="$DEV_AKID" AWS_SECRET_ACCESS_KEY=test aws --endpoint-url "$ENDPOINT" --region "$REGION" "$@"; }`. There is **no** `FLOCI_BOOTSTRAP_AKID` reference and **no** `${...:-$DEV_AKID}` fallback — it uses a bare `$DEV_AKID`. A global `rg "FLOCI_BOOTSTRAP"` across the entire repo returns zero matches; neither `FLOCI_BOOTSTRAP_AKID` nor `FLOCI_BOOTSTRAP_SECRET` exists in any file. The primary appears to have copied the *proposed* code from auth plan §6.9 and presented it as the *current* code, then invented a "partially implemented" narrative around it. The actual situation is simpler and the finding's framing is misleading: the preflight script hardcodes both AKID source (`$DEV_AKID`) and secret (`test`); NOTHING from the auth plan §6.9 is implemented. |
| Recommendation | Rewrite F-DX-009 to reflect the actual code: `aws_admin` uses `$DEV_AKID` (hardcoded AKID source) and literal `test` (hardcoded secret); neither `FLOCI_BOOTSTRAP_AKID` nor `FLOCI_BOOTSTRAP_SECRET` is referenced anywhere. The recommendation (add `FLOCI_BOOTSTRAP_*` env-var support) stays the same, but the "partially implements" framing must be removed — it is fully unimplemented. Severity is correct (MODERATE). |

---

## One-Sided Findings (Primary Missed)

### M-DX-001: F-DX-010 is built on a false premise — ADRs DO exist, and the recommended `docs/adr/` location contradicts project structure

| Field | Value |
|-------|-------|
| Confidence | 95 |
| Description | F-DX-010 claims "No ADRs exist for significant design decisions — `docs/adr/` directory is empty" and recommends creating ADRs in `docs/adr/` using `node docs/project-management/next-id.mjs adr`. Both the premise and the recommendation are wrong. First, the `docs/adr/` directory **does not exist at all** (the primary called it "empty" — it is absent, not empty). Second, and more importantly, **ADRs already exist** in this repository: `docs/learning/decisions/` contains 5 accepted ADRs (0001–0005) covering exactly the landing-zone decisions the primary listed as missing candidates: application IAM role + boundary (0001), hub-and-spoke intent + IAM/NetworkPolicy enforcement (0002), centralized EKS placement (0003), environment=account layered stacks (0004), spoke-to-spoke IAM-gated (0005). The primary's own F-DX-010 enumerates four ADR candidates ("one IAM role per application with permissions boundary"; "environment = account (AKID) with layered Terraform stacks") that are **already documented** in ADRs 0001 and 0004. Third, the recommendation to create ADRs in `docs/adr/` contradicts the established project layout: `docs/learning/AGENTS.md` designates `docs/learning/decisions/` as the ADR home and explicitly forbids manual edits or off-tree writes to that directory (ANTI-PATTERNS: "Manual edits to anything in `docs/learning/`" and "Cross-contamination"). The `next-id.mjs adr` counter in `counters.json` is `lastAdr: 0` — that counter tracks a *different* (unused) ADR stream, not the `docs/learning/decisions/` sequence. The primary did not search beyond `docs/adr/` and therefore missed an entire ADR registry. |
| Recommended Action | (1) Correct F-DX-010: restate it as "ADR coverage exists for landing-zone decisions (docs/learning/decisions/0001–0005) but NOT for the authentication plan's decisions." (2) Narrow the recommendation to the auth-plan-specific decisions only (`FLOCI_AUTH_MODE` collapse; `floci-deployer` bootstrap-only with rotation; `true`/`false` crypto-theater prevention). (3) Determine the correct ADR location for auth-plan decisions — since `docs/learning/` is `/learn`-command-only and isolated, auth-plan ADRs likely belong in a new `docs/adr/` directory (created, not assumed) OR in `docs/project-management/decisions/` (which exists but is currently empty and uses the `next-id.mjs adr` counter). This is a routing decision for the PM, not a blanket "create ADRs in docs/adr/" instruction. (4) Cross-reference the existing landing-zone ADRs from the auth plan rather than duplicating them. |

### M-DX-002: F-DX-002 understates the inconsistency — auth plan §3.1 actively asserts `platform-admin` IS created, not merely "described as concrete"

| Field | Value |
|-------|-------|
| Confidence | 88 |
| Description | F-DX-002 frames the issue as both docs "describing `platform-admin` as a concrete, assumable identity." But the auth plan goes further: §3.1's table row for Platform admin states under the Lifecycle column "Created by Terraform stage `10-management-iam`" as a present-tense assertion of fact, and §3.3 states "After the landing-zone Terraform creates `platform-admin`, the deployer credentials should be rotated out." These are not descriptions of design intent — they are assertions that the creation has occurred or will occur via that stage. Since `infra/AGENTS.md:47` explicitly says `10-management-iam` is a "Stub until Phase 1" with "no users/roles/groups," the auth plan is making a forward-looking claim that reads as a current-state fact — the same defect as F-DX-001, but specific to the `platform-admin` identity. F-DX-002's recommendation (add "policy only — pending Phase 1" caveat) is correct but does not call out that the auth plan's lifecycle diagram (§3.3) depicts a `floci-deployer → platform-admin → app roles` flow as if it is operational today. |
| Recommended Action | Strengthen F-DX-002: flag that the auth plan §3.1 Lifecycle column and §3.3 lifecycle diagram assert `platform-admin` creation as fact (present tense), compounding the F-DX-001 "reads as implemented" problem specifically for the IAM identity. The caveat should be added to §3.1's table cell AND the §3.3 diagram annotation, not just prose. |

### M-DX-003: Auth plan §2.2 hardcoded-credentials table omits `setup-floci.sh` `print_summary` exposure of `floci`/`floci`

| Field | Value |
|-------|-------|
| Confidence | 75 |
| Description | The auth plan §2.2 ("Hardcoded credentials") lists three locations where literal `test` appears as a secret: `dev-twin.sh:769`, `preflight-floci.sh:35`, and scraped docs (upstream). It does not list `setup-floci.sh:946` (`print_summary`), which — per the auth plan's own §6.3 proposed code — would print `AKID=floci, secret=floci` in the sigv4 branch. The proposed `print_summary` text literally echoes the bootstrap credential pair to stdout: `echo "      Bootstrap admin: floci-deployer (AKID=floci, secret=floci)."`. Echoing a live secret to stdout (which may be captured in logs, terminal scrollback, or CI output) is a credential-exposure vector the auth plan neither acknowledges in §2.2 nor mitigates in §6.3. The §8.1 "credential is public knowledge" justification applies to the *bootstrap* phase but does not address that the installer summary broadcasts it. This is a design-gap the primary review (F-DX-006) flagged as "stale after implementation" but did not flag as a credential-exposure concern in the proposed code itself. |
| Recommended Action | Add a finding: the auth plan §6.3 proposed `print_summary` echoes `floci`/`floci` to stdout. Recommend the summary print the AKID but redact/mask the secret (e.g., `secret=****`), or print only the credential *location* (cache file path) rather than the literal values. The §2.2 hardcoded-credentials table should also be updated to include this stdout exposure once §6.3 is implemented. |

### M-DX-004: No finding on the auth plan's own internal inconsistency between §4.3 defaults and §6.4 dev-twin invocation

| Field | Value |
|-------|-------|
| Confidence | 70 |
| Description | Auth plan §4.3 ("Defaults") states the dev twin default for `FLOCI_AUTH_MODE` is `sigv4` ("The dev twin is the natural place to prove IAM enforcement works"). §6.4 then shows the `_install_absent` invocation hardcoding `FLOCI_AUTH_MODE=sigv4`. However, `setup-floci.sh`'s own default (per §4.2's `readonly FLOCI_AUTH_MODE="${FLOCI_AUTH_MODE:-off}"`) is `off`. The dev twin relies on the env-var override at invocation, which is fine — but the auth plan does not document what happens if a user runs `make dev-up` on a VM where `_install_absent` is NOT called (i.e., an already-running VM via `make dev-up` on existing instance). The AGENTS.md critical gotcha states "`make dev-up` does NOT rerun the installer on an existing VM." So on a resume, `FLOCI_AUTH_MODE` is never set and the existing Floci keeps whatever auth mode it was installed with. The auth plan §6.4 only covers the install path; the resume path (`_resume_health_check`) is not addressed. This is an edge case the primary did not surface. |
| Recommended Action | Add an advisory finding: the auth plan should document the resume-path behavior — `make dev-up` on an existing VM does not re-invoke the installer, so `FLOCI_AUTH_MODE` cannot be changed without `dev-recreate`. Note this in §4.3 or §6.4. (Advisory; confidence below 80.) |

### M-DX-005: Cross-document report DC-1/DC-3 inherit the F-DX-010 error and should be corrected

| Field | Value |
|-------|-------|
| Confidence | 90 |
| Description | The Cross-Document Consistency Report's DC-1 ("ADRs found: 0") and DC-3 ("No ADRs to trace") are both false — they inherit the F-DX-010 false premise. DC-1 should read "ADRs found: 5 (docs/learning/decisions/0001–0005)" and DC-3 should trace the landing-zone §13 decisions to those ADRs. As written, the report understates existing ADR coverage and overstates the gap. The DC-2 contradiction finding (platform-admin) is correct. |
| Recommended Action | Correct DC-1 and DC-3 to reflect the 5 existing ADRs in `docs/learning/decisions/`. Update the "Cross-Document Consistency Verdict" to note that landing-zone decisions ARE traced to ADRs, and the untraced gap is auth-plan-specific only. |

---

## Recommendations

1. **Fix F-DX-009 (D-DX-001) before this review is used downstream.** It contains a verifiable factual error (quotes code that does not exist in the repo). Any consuming agent (Code Architect, synthesizer) relying on F-DX-009 will proceed from a false premise. Confidence 92 — this should block the finding's acceptance as-written.

2. **Rewrite F-DX-010 per M-DX-001.** The finding as written would cause a Docs Writer to create duplicate ADRs for decisions already recorded in `docs/learning/decisions/0001` and `0004`, and to write into a `docs/adr/` path that contradicts the `docs/learning/` isolation rules. The ADR-coverage gap is real but narrower than stated: it covers auth-plan decisions only, not landing-zone decisions.

3. **Escalate M-DX-003 (secret in stdout) to the Security Reviewer (SX) for cross-validation.** The auth plan §6.3 proposed code prints `secret=floci` to stdout. Whether this is acceptable (given §8.1 "public knowledge" justification) or a credential-exposure gap is a security judgment, not a docs judgment. Flag to SX via flag-protocol.

4. **The CONDITIONAL PASS verdict is broadly supportable** but its blocking-findings list includes F-DX-003, F-DX-004, F-DX-008, F-DX-009, F-DX-010, F-DX-014 — several of which are documentation/implementation gaps the Docs Writer cannot fix (they route to Code Architect or PM). The verdict's "Routing" section correctly assigns these, but the blocking list conflates "must fix before Docs review passes" with "must fix before the code is correct." Recommend splitting the blocking list into (a) docs-blocking (F-DX-001, F-DX-002, F-DX-003, F-DX-004 — Docs Writer can fix) and (b) code-blocking (F-DX-005..009, F-DX-014 — routes to Code Architect). F-DX-010 is routing-dependent (PM decision on ADR location).

5. **Self-audit checklist note:** The primary's self-audit marked "Documentation on new public symbols" as PASS and "AGENTS.md compliance" as PASS. Both are accurate for the *scripts*. However, the self-audit does not include a row for "ADR coverage verified against actual ADR directory" — had such a row existed, F-DX-010's false premise would have been caught at self-audit time. Recommend the Docs Writer add an ADR-inventory check to the self-audit when ADR findings are in scope.
