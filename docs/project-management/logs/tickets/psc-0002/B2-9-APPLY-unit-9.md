# B2-9: APPLY Unit 9 — psc-0002

| Field | Value |
|-------|-------|
| Agent | code-architect |
| Timestamp | 2026-07-30T15:40:00Z |
| Step | B2-9 |
| Unit | 9 — External doc changes |
| Build result | PASS — markdown link check across all modified docs; cross-document references consistent |

## Changes

### 1. `docs/design/gaps-register.md` — GAP-015 (SPEC-DX-001)
Added GAP-015 after GAP-014, before "How to add a new gap":
- Title: "Floci has no root user concept [OPEN]"
- Impact: `floci-deployer` is de-facto root-equivalent; no recovery from lost credential; no Organizations/SCPs
- Mitigation: rotate immediately, use `platform-admin` for ongoing operations
- Reference: `authentication-plan.md` §3.2, `landing-zone-design.md` §5.1

### 2. `docs/design/solution-design.md` — §8 replacement (SPEC-DX-002)
Replaced the 5-line §8 with expanded §8–§8.3:
- **§8:** Mode table (`sigv4`/`off`), cross-reference to auth plan §4
- **§8.1:** IAM identity lifecycle — three-layer hierarchy table, ASCII lifecycle diagram, `floci-deployer` bootstrap-only note
- **§8.2:** Presign secret — `openssl rand -hex 32`, idempotent
- **§8.3:** Multi-account isolation — automatic via 12-digit AKIDs

### 3. `docs/design/landing-zone-design.md` — §5.4 DurationSeconds (SPEC-SW-008)
Added after the existing IRSA stand-in note:
- `DurationSeconds` bound of 3600s (1 hour)
- Re-assumption cadence of 30 minutes (half the session duration)
- Expiry behavior: pod restarts if credentials expire
- Table with parameter, value, and rationale
- Note that this is a Floci accommodation

### 4. `AGENTS.md` — three additions
- **Key files:** Added `authentication-plan.md` entry after `landing-zone-design.md` (DX structural)
- **Critical gotcha:** `FLOCI_AUTH_MODE` cannot change without `make dev-recreate` (SPEC-DX-004)
- **Critical gotcha:** Dev twin `ExecCondition` Quadlet override does not exist in production (SPEC-DX-007)

## Acceptance criteria

- [x] GAP-015 present in gaps-register.md with Impact, Mitigation, and Reference fields
- [x] solution-design.md §8 includes mode table, IAM identity lifecycle diagram, presign secret, multi-account isolation
- [x] landing-zone-design.md §5.4 includes `DurationSeconds=3600`, 30-min re-assumption cadence, expiry behavior
- [x] AGENTS.md has both new Critical gotchas (resume-path + ExecCondition)
- [x] AGENTS.md Key files lists `authentication-plan.md`
- [x] All cross-document references are consistent (no contradictions)
