# B2-1: APPLY Unit 1 — psc-0002

| Field | Value |
|-------|-------|
| Agent | code-architect |
| Timestamp | 2026-07-30T15:00:00Z |
| Step | B2-1 |
| Unit | 1 — Structural + DX updates |
| Build result | PASS — markdown syntax valid, all cross-references resolve |

## Changes

### 1. Status banner (DX structural)
Added after title line (line 3-5):
```markdown
> **Status:** Specification — not yet implemented. This document describes the complete design for
> Floci authentication (SigV4, IAM enforcement, credential rotation). The code changes in §6 are
> implementation specifications for Phase B. See psc-0002 for the implementation ticket.
```

### 2. §4.4 Resume-path behavior (SPEC-DX-004)
Added new §4.4 "Changing `FLOCI_AUTH_MODE` on an existing VM" after the defaults table in §4.3 (line 167). Documents that `make dev-up` does not re-invoke the installer, and that `make dev-recreate` or `make dev-reset` is required to change `FLOCI_AUTH_MODE`.

### 3. §6.3 print_summary masked output (SPEC-DX-005)
Updated the sigv4-mode summary message (line 285) from:
```
"Bootstrap admin: floci-deployer (AKID=floci, secret=floci)."
```
to:
```
"Bootstrap admin: floci-deployer (well-known public credential)."
"The credential is documented in the Floci public docs — rotate it"
"immediately. See dev-twin _print_next_steps for rotation instructions."
```

### 4. §6.11 Tests section (all TX specs)
Replaced the 12-line test summary with a comprehensive test specification section incorporating all 13 TX specs:
- Test file summary table (7 files, 40 test cases)
- Implementation order (7 phases)
- Key test patterns (organized by test file)
- Stub requirements

## Acceptance criteria

- [x] Status banner present at top of document
- [x] §4.4 documents `make dev-recreate` requirement for mode changes
- [x] §6.3 no longer echoes `AKID=floci, secret=floci` literally
- [x] §6.11 contains test file summary, implementation order, and stub requirements
- [x] All cross-references in new content resolve to existing files/sections
