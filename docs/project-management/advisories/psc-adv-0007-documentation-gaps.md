# Advisory: Documentation Gaps

| Field | Value |
|-------|-------|
| ID | psc-adv-0007-documentation-gaps |
| Type | advisory |
| Status | awaiting user decision |
| Confidence | 90 |
| Priority | high |
| Source ticket | psc-adv-0001 |
| Source agent | DX |
| Source file | [A2-dual-model-challenge.md](docs/project-management/logs/tickets/psc-adv-0001/A2-dual-model-challenge.md) |
| Created | 2026-07-30 |

## Description
Documentation defects that misrepresent implementation status, create false premises, and omit critical lifecycle information.

**Consolidated findings:**

1. **F-DX-001 (conf 90) — Auth plan reads as implemented**: The authentication plan is written in present tense as if all features are already implemented. The code has NOT been updated. **Status banner needed: "Status: Design proposal — NOT YET IMPLEMENTED."**

2. **F-DX-002 (conf 85) / M-DX-002 (conf 88) — Platform-admin forward-looking claims read as facts**: Auth plan §3.1 Lifecycle column and §3.3 lifecycle diagram assert `platform-admin` IS created by `10-management-iam` as present-tense fact. Same defect as F-DX-001 — forward-looking claims reading as current-state facts.

3. **F-DX-003 (conf 90) — Missing gap entry GAP-015**: Floci's lack of root user concept (unlike AWS) is not documented in `gaps-register.md`.

4. **F-DX-004 (conf 90) — Missing IAM identity lifecycle note**: `solution-design.md` §10 should document IAM identity lifecycle considerations.

5. **M-DX-001 (conf 95) — ADR location confusion**: ADRs **do exist** in `docs/learning/decisions/` (0001–0005) covering exactly the landing-zone decisions. The primary only checked `docs/adr/` (which doesn't exist) and missed the entire ADR registry. The recommendation to create ADRs in `docs/adr/` contradicts `docs/learning/AGENTS.md` isolation rules. PM decision needed on correct location for auth-plan-specific ADRs.

6. **M-DX-005 (conf 90) — Cross-document report DC-1/DC-3 inherit false premise**: Cross-document report DC-1 ("ADRs found: 0") and DC-3 ("No ADRs to trace") are both false — they inherit the M-DX-001 false premise. DC-1 should read "ADRs found: 5 (docs/learning/decisions/0001–0005)."

7. **F-DX-014 (conf 80) — `dev_env` idempotency bug**: `dev_env` append pattern uses grep guard that silently skips if profile exists, leaving stale credentials. Should use `sed -i.bak` replace-then-write pattern.

8. **M-DX-004 (conf 70) — Auth plan resume-path undocumented**: Auth plan §4.3 states dev twin default is `sigv4`, but `make dev-up` on existing VM does NOT re-invoke installer (per AGENTS.md gotcha). The resume path is not documented.

## Recommended Action
1. Add status banner to auth plan: "Status: Design proposal — NOT YET IMPLEMENTED."
2. Add caveat to auth plan §3.1/§3.3 and landing-zone design §5.1: "`platform-admin` policy only — pending Phase 1 implementation."
3. Create gap entry GAP-015 in `gaps-register.md` for Floci's lack of root user concept.
4. Add IAM identity lifecycle note to `solution-design.md` §10.
5. PM decision: Determine correct ADR location for auth-plan-specific ADRs (per M-DX-001, `docs/learning/decisions/` is the established location per `docs/learning/AGENTS.md` isolation rules).
6. Correct cross-document report DC-1/DC-3 to reflect 5 existing ADRs.
7. Fix `dev_env` idempotency: use `sed -i.bak` replace-then-write for credential updates.
8. Document auth plan resume-path behavior: `make dev-up` on existing VM does not re-invoke installer; `FLOCI_AUTH_MODE` changes require `dev-recreate`.

## User Decision
1. ignore
2. ignore
3. ok
4. ok
5. adrs live in docs/adr/ and adrs are not recorded at the moment.
6. ignore
7. ok
8. ok

## Decision Rationale

## Implementation Ticket