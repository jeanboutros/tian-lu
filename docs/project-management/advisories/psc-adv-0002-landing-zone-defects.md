# Advisory: Landing Zone Design Defects

| Field | Value |
|-------|-------|
| ID | psc-adv-0002-landing-zone-defects |
| Type | advisory |
| Status | awaiting user decision |
| Confidence | 85 |
| Priority | critical |
| Source ticket | psc-adv-0001 |
| Source agent | SW, SX, DXS |
| Source file | [A2-dual-model-challenge.md](docs/project-management/logs/tickets/psc-adv-0001/A2-dual-model-challenge.md) |
| Created | 2026-07-30 |

## Description
The landing zone design (`landing-zone-design.md`) and associated Terraform stage code contain architectural defects that violate the landing zone's own conventions and break environment promotion.

**Consolidated findings:**

1. **M-SW-003 (conf 85) — Hardcoded backend bucket breaks promotion pattern**: `10-management-iam/providers.tf:12` hardcodes `bucket = "tf-state-dev"`, breaking the `_common/backend.hcl` environment-promotion pattern. Promoting to `uat`/`prod` requires editing stage code — violating the "stage code unchanged" rule.

2. **M-SW-004 (conf 80) — Undocumented `Environment = "development"`**: `dev.tfvars:27` sets `Environment = "development"` — a fourth, undocumented environment label distinct from `dev`/`uat`/`prod`. Even if deduplication worked, ABAC tag-match queries would fail because principals are tagged `Environment=dev` while resources get `development`.

3. **M-DX-002 (conf 88) — Auth plan reads as current-state fact**: Auth plan §3.1's Lifecycle column asserts `platform-admin` IS created by `10-management-iam` as a present-tense fact, and §3.3's lifecycle diagram depicts `floci-deployer → platform-admin → app roles` as operational. These are forward-looking claims reading as current-state facts — the same defect as F-DX-001.

4. **M-SX-005 (conf 82) — IRSA stand-in missing session duration**: Landing-zone design §5.4 IRSA stand-in never specifies `DurationSeconds` for the `sts:AssumeRole` call. Without an explicit bound, the session duration defaults to 1h but can be up to 12h — the exposure window is unspecified.

5. **F-DXS-005 (conf 75) — Dev env profile collision**: `dev_env` profile name `[floci-dev]` can collide with a user's pre-existing real AWS profile of the same name. The grep guard skips the append, silently leaving real credentials in place.

6. **M-DX-001 (conf 95) — ADRs exist but primary missed them**: ADRs **do exist** in `docs/learning/decisions/` (0001–0005) covering exactly the landing-zone decisions the primary listed as missing. The primary only checked `docs/adr/` (which doesn't exist) and missed the entire ADR registry. The recommendation to create ADRs in `docs/adr/` contradicts `docs/learning/AGENTS.md` isolation rules.

7. **M-DX-005 (conf 90) — Cross-document report DC-1/DC-3 inherit false premise**: Cross-document report DC-1 ("ADRs found: 0") and DC-3 ("No ADRs to trace") are both false — they inherit the M-DX-001 false premise. DC-1 should read "ADRs found: 5 (docs/learning/decisions/0001–0005)."

8. **F-DX-003 (conf 90) — Missing gap for Floci's lack of root user**: Floci has no root user concept (unlike AWS). Gap entry GAP-015 should be created in `gaps-register.md` for this gap.

9. **F-DX-004 (conf 90) — Missing IAM identity lifecycle note**: `solution-design.md` §10 should document IAM identity lifecycle considerations.

## Recommended Action
1. Remove hardcoded `bucket = "tf-state-dev"` from `10-management-iam/providers.tf`; use `-backend-config` pattern.
2. Remove `Environment = "development"` from `dev.tfvars`; add validation that `Environment ∈ {dev,uat,prod}`.
3. Add caveat to auth plan §3.1/§3.3 and landing-zone design §5.1: "`platform-admin` policy only — pending Phase 1 implementation."
4. Add `DurationSeconds` bound + re-assumption cadence to landing-zone design §5.4.
5. Namespace dev-env AWS profile to `tianlu-floci-dev` instead of `floci-dev` to avoid collisions with real AWS profiles.
3. Create gap entry GAP-015 in `gaps-register.md` for Floci's lack of root user concept.
4. Add IAM identity lifecycle note to `solution-design.md` §10.
5. Correct cross-document report DC-1/DC-3 to reflect 5 existing ADRs in `docs/learning/decisions/`.
6. Determine correct ADR location for auth-plan-specific ADRs (PM decision needed — per M-DX-001).

## User Decision
1. ok abd ensure the main.tf describes the full command to run the terraform apply with the backend config and the tfvars file.
2. ok
3. they are parallel tasks. ignore this finding
4. ok
5. ok. it should also be documented
6. ignore ADRs at this stage. the project is still early stage trial and error.
7. ignore
8. ok
9. ok

## Decision Rationale

## Implementation Ticket