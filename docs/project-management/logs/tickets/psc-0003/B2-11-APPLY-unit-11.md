# B2-11: APPLY Unit 11 — Documentation Updates

| Field | Value |
|-------|-------|
| Agent | code-architect |
| Timestamp | 2026-07-30T23:00:00Z |
| Step | B2-11 |
| Ticket | psc-0003 |
| Unit | 11 — Documentation Updates |

## Files Changed

| File | Lines Added | Lines Removed | Net |
|------|-------------|---------------|-----|
| `docs/design/authentication-plan.md` | +140 | -135 | +5 |
| `docs/design/solution-design.md` | +48 | -2 | +46 |
| `docs/design/landing-zone-design.md` | +24 | -3 | +21 |
| `docs/design/gaps-register.md` | +82 | -0 | +82 |
| **Total** | **+294** | **-140** | **+154** |

## Acceptance Criteria Satisfied

### CH-AUTH-012: Split §6.10a-d into changelog/appendix
- **Status:** DONE
- **What changed:** Removed §6.10a (IAM permissions boundary enforcement), §6.10b (Terraform backend configuration), §6.10c (Environment tag consistency), and §6.10d (IRSA stand-in session duration) from §6. Replaced with a brief note pointing to the new appendix. Added "Appendix A: Already Applied Changes" at the end of the file containing all four sections as A.1–A.4.
- **Rationale:** These sections describe already-landed changes, not pending specifications. Moving them to an appendix keeps §6 focused on pending implementation work.

### CH-AUTH-014: Add presign-secret threat model
- **Status:** DONE
- **What changed:** Expanded `solution-design.md` §8.2 from a single paragraph to three subsections:
  - **§8.2.1 Threat model** — Documents that `FLOCI_AUTH_PRESIGN_SECRET` mints presigned S3 URLs that bypass the IAM layer entirely. A presign capability over the Terraform state bucket is equivalent to administrative access (read/write/delete `terraform.tfstate`). The presign secret is a single key for all S3 buckets.
  - **§8.2.2 Rotation path** — Documents the rotation procedure and warns that rotating invalidates all existing presigned URLs.
  - **§8.2.3 Reuse-if-exists behavior** — Documents the idempotent behavior: the secret is preserved on `dev-recreate` (retains data disk), regenerated on `dev-reset` (wipes all state), and preserved on installer re-run.
- **Cross-reference:** `landing-zone-design.md` §12 now cross-links to this threat model.

### CH-AUTH-015: Mark §9.3 items as specified-not-verified
- **Status:** DONE
- **What changed:** Two items in §9.3 (Deep-agent validation — key findings) changed from "Fixed in §6.x" to "Specified in §6.x — not yet verified by test":
  - Partial-failure (delete fails) leaves well-known key active (CH-AUTH-005)
  - `_print_next_steps` must warn on sigv4 + failed rotation (CH-AUTH-006)
- **Rationale:** These items lack test coverage. The specification exists in the code but has not been verified by a passing test.

### CH-AUTH-016: Replace "Crypto theater" wording
- **Status:** DONE
- **What changed:** Replaced "Crypto theater" with "Authenticates callers and then ignores their policies" in three locations:
  - `authentication-plan.md` §4.1 table (Assessment column for `true`/`false` row)
  - `authentication-plan.md` §8.3 (parenthetical in the first sentence)
  - `solution-design.md` §8 (parenthetical in the `FLOCI_AUTH_MODE` description)
- **Verification:** `grep -r "[Cc]rypto theater" docs/design/` returns zero matches.
- **Note:** Historical artifacts in `docs/project-management/logs/` were NOT changed per the instruction.

### CH-LZ-003: Relabel G1; add enforcement variables to §1.1 and §10.1
- **Status:** DONE
- **What changed in `landing-zone-design.md`:**
  - **§1.1** (API authorization row): Changed from `FLOCI_AUTH_VALIDATE_SIGNATURES=true` to `FLOCI_AUTH_VALIDATE_SIGNATURES=true AND FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED=true`
  - **§10.1** (G1 gate): Changed from "Signature authorization is ON" to "Signature authorization AND IAM enforcement are ON" with both variable names
  - **§10.1** (Prerequisites): Added a new bullet documenting that both enforcement variables are required, with a cross-reference to `authentication-plan.md` §4.1 explaining why signatures alone without enforcement is insufficient

### CH-LZ-013: Qualify §3 scaffolding; add TF_VAR_secret_key story; cross-link presign
- **Status:** DONE
- **What changed in `landing-zone-design.md`:**
  - **§3** (after directory tree): Added an "Implementation status" note documenting that only stages 00 and 10 are implemented; stages 20–60 are planned but not yet written. The present-tense descriptions in §3–§8 describe the intended design, not the current implementation state.
  - **§10.1** (Prerequisites): Added `TF_VAR_secret_key` documentation showing how to source the rotated deployer credential from `~/.cache/tianlu-twin/dev-credentials.env` and export it as `TF_VAR_secret_key`. Includes fallback to `floci`/`floci` if the dev twin hasn't been started.
  - **§12** (Security model summary): Added a presign secret risk bullet cross-linking to `solution-design.md` §8.2.1 for the full threat model, rotation path, and reuse-if-exists behavior.

### CH-LZ-013: Remove root install.sh
- **Status:** DONE (no-op)
- **What changed:** The file `install.sh` does not exist in the repository root — it was already removed. Verified with `ls -la install.sh` (exit 1, "No such file or directory").
- **Verification:** `grep -r "install\.sh" --include="*.md" --include="Makefile" --include="*.sh" . | grep -v ".git" | grep -v "node_modules"` returns only references in `docs/project-management/logs/` (historical artifacts) — no code, Makefile, or design doc references the file.

### CH-META-001/002/003: Record lessons-learned
- **Status:** DONE
- **What changed:** Added a "Lessons Learned" section to `docs/design/gaps-register.md` with three entries:
  - **LL-001** (CH-META-001): Verify causal mechanisms against primary sources before recording blockers. The region mismatch finding had the right action but the wrong mechanism — the real consequence is resource/ARN divergence, not signature validation failure.
  - **LL-002** (CH-META-002): IAM Condition absent-key evaluation is a recurring trap; never apply "A or B" alternatives as "A and B". The `StringNotEquals` on `iam:PermissionsBoundary` matches null when the key is absent, turning a guardrail into a blanket deny.
  - **LL-003** (CH-META-003): Verify environment variable purpose against the authoritative source before propagating a finding. `FLOCI_SERVICES_IAM_ENABLED` is the IAM service on/off switch, not the enforcement toggle — the conflation cascaded into the mode matrix, env-file spec, and test cases.
- Each entry includes: source reference, what happened, why it matters, and a standing rule.

## Build Verification

```bash
# Verify no broken references to install.sh
grep -r "install\.sh" --include="*.md" --include="Makefile" --include="*.sh" . | grep -v ".git" | grep -v "node_modules"
```
**Result:** Only references in `docs/project-management/logs/` (historical artifacts). No code, Makefile, or design doc references. PASS.

```bash
# Verify no remaining "crypto theater" in design docs
grep -r "[Cc]rypto theater" docs/design/
```
**Result:** Zero matches. PASS.

```bash
# Verify install.sh does not exist
ls -la install.sh
```
**Result:** "No such file or directory" (exit 1). PASS.

## Notes

- The `AGENTS.md` file was listed as a target but required no changes — the `install.sh` removal was already complete, and no other AGENTS.md updates were needed for this unit.
- All changes are documentation-only; no code was modified.
- The `authentication-plan.md` appendix preserves all original content from §6.10a–d verbatim, only relabeled as A.1–A.4.
