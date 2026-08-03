# B1: PLAN — psc-0002

| Field | Value |
|-------|-------|
| Agent | code-architect |
| Timestamp | 2026-07-30T14:00:00Z |
| Step | B1 |
| Phase | B |
| Ticket | psc-0002 |
| Primary target | `docs/design/authentication-plan.md` (653 lines → enriched specification) |

## Files to Modify

| File | Changes | Specs Covered |
|------|---------|---------------|
| `docs/design/authentication-plan.md` | **Primary target** — all code blocks, structural additions, cross-references, test section | SW-001–008, DX-003–006, BS-007, all TX specs |
| `infra/live/10-management-iam/main.tf` | Fix `DenyAllExceptBoundary` resource scoping (line 49–63) | SW-002 |
| `infra/live/10-management-iam/providers.tf` | Remove hardcoded `bucket` from backend block (line 12) | SW-006 |
| `infra/environments/dev.tfvars` | Fix `Environment` tag, remove duplicate tags (lines 24–29) | SW-007 |
| `docs/design/gaps-register.md` | Add GAP-015 — Floci's lack of root user concept | DX-001 |
| `docs/design/solution-design.md` | Replace §8 (Authentication) with expanded cross-reference section | DX-002 |
| `docs/design/landing-zone-design.md` | Add `DurationSeconds` bound + re-assumption cadence to §5.4 | SW-008 |
| `AGENTS.md` | Add resume-path gotcha, ExecCondition gotcha, Key files listing | DX-004, DX-007, DX structural |

## Files NOT Modified (no auth plan impact)

The following BS specs fix actual script files but do **not** require auth plan code block changes. They are out of scope for this ticket (the auth plan's code blocks are already correct for these):

| BS Spec | Affected File | Why No Auth Plan Change |
|---------|---------------|------------------------|
| BS-001 | `dev-twin.sh:_run_as_floci_guest` | Auth plan calls `_run_as_floci_guest` with single string — `$*` bug not triggered |
| BS-002 | All 6 scripts (`set -o errtrace`) | Added to script preamble, not to auth plan code blocks |
| BS-003 | `dev-twin.sh`, `assert.sh` (`local var="$(cmd)"`) | Auth plan's `_rotate_bootstrap_credentials` uses separate declaration + assignment |
| BS-004 | `dev-twin.sh`, `run-test.sh` (`TEMP_FILES=()`) | Auth plan's code blocks don't create temp files |
| BS-005 | `run-test.sh` (signal trap) | Prerequisite for auth-mode test runs; no code block change |
| BS-006 | `setup-floci.sh` (`sort -V` doc) | `assert_ubuntu_version` not touched by auth plan |
| BS-008 | All 6 scripts (ERR trap) | Added to script, not to auth plan code blocks |
| BS-009 | `dev-twin.sh` (doc update) | Auth plan doesn't show `_run_as_floci_guest` function body |
| BS-010 | `dev-twin.sh` (`_install_exec_condition`) | Auth plan doesn't show this function body |

## Implementation Units

### Unit 1: Auth plan — structural and DX updates (non-code-block changes)

**Specs covered:** DX-004 (§4.4), DX-005 (§6.3), all TX specs (§6.11), DX structural (status banner)

**Changes:**
1. Add status banner after title line: `> **Status:** Specification — not yet implemented.`
2. Add new §4.4 "Changing `FLOCI_AUTH_MODE` on an existing VM" — documents that `make dev-up` does not re-invoke the installer (SPEC-DX-004)
3. Update §6.3 `print_summary` — mask the `floci`/`floci` literal, show file location instead (SPEC-DX-005)
4. Replace §6.11 "Tests" with comprehensive test specification section incorporating all 13 TX specs:
   - Test file summary table (7 files, 40 test cases)
   - Implementation order (7 phases)
   - Stub requirements
   - Key test patterns

**Acceptance criteria:**
- [ ] Status banner present at top of document
- [ ] §4.4 documents `make dev-recreate` requirement for mode changes
- [ ] §6.3 no longer echoes `AKID=floci, secret=floci` literally
- [ ] §6.11 contains test file summary, implementation order, and stub requirements
- [ ] All cross-references in new content resolve to existing files/sections

**Build validation:** `bash -n` on extracted code blocks; markdown link check

---

### Unit 2: Auth plan — §4.2 `FLOCI_AUTH_MODE` case statement restructuring

**Specs covered:** SW-003 (readonly out of case), SW-004 (add `FLOCI_SERVICES_IAM_ENABLED`)

**Dependency:** SW-003 must be applied before SW-004 (SW-004 adds vars to the restructured case)

**Changes:**
1. Replace the current `readonly`-inside-`case` pattern with non-readonly `_auth_*` locals computed inside the `case`, then `readonly` declarations with `${VAR:-default}` at the top level after the `case` block
2. Add `_auth_iam_enabled` to both branches (`off` → `false`, `sigv4` → `true`)
3. Add corresponding `readonly FLOCI_SERVICES_IAM_ENABLED="${FLOCI_SERVICES_IAM_ENABLED:-$_auth_iam_enabled}"` after the case block
4. Add explanatory comment about test-injection convention

**Acceptance criteria:**
- [ ] No `readonly` declarations inside `case` branches
- [ ] All four auth vars (`FLOCI_AUTH_VALIDATE_SIGNATURES`, `FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED`, `FLOCI_SERVICES_IAM_SEED_DEPLOYER_PRINCIPAL`, `FLOCI_SERVICES_IAM_ENABLED`) declared `readonly` with `${VAR:-default}` at top level
- [ ] `off` branch sets all four to `false`
- [ ] `sigv4` branch sets all four to `true`
- [ ] Comment explains the `${VAR:-default}` test-injection convention
- [ ] `_` prefix on internal locals (convention: not part of public API)

**Build validation:** `bash -n` on extracted case statement block

---

### Unit 3: Auth plan — §6.1, §6.2 code block updates

**Specs covered:** SW-003 (restructured case in §6.1), SW-004 (`FLOCI_SERVICES_IAM_ENABLED` in §6.1 and §6.2)

**Dependency:** Unit 2 must be complete (the §6.1 code block mirrors §4.2)

**Changes:**
1. Update §6.1 code block to match the restructured case statement from Unit 2
2. Update §6.2 `write_env_file` code block to include `FLOCI_SERVICES_IAM_ENABLED=${FLOCI_SERVICES_IAM_ENABLED}` line (before the existing three auth vars)
3. Add note that SPEC-TX-006 test case 3 must be reversed (now asserts `FLOCI_SERVICES_IAM_ENABLED` IS present)

**Acceptance criteria:**
- [ ] §6.1 code block matches §4.2 restructured case statement exactly
- [ ] §6.2 code block includes all four auth vars in order: `FLOCI_SERVICES_IAM_ENABLED`, `FLOCI_AUTH_VALIDATE_SIGNATURES`, `FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED`, `FLOCI_SERVICES_IAM_SEED_DEPLOYER_PRINCIPAL`
- [ ] Note about SPEC-TX-006 test case 3 reversal present

**Build validation:** `bash -n` on extracted code blocks; diff §4.2 vs §6.1 case statements for consistency

---

### Unit 4: Auth plan — §5.2, §6.1a, §6.5 rotation updates

**Specs covered:** SW-001 (DEV_REGION constant), SW-005 (sts get-caller-identity verification)

**Dependency:** SW-001 must be applied before SW-005 (region constant used in verification call)

**Changes:**
1. Add `DEV_REGION` constant to §6.1a constants block:
   ```bash
   readonly DEV_REGION="${DEV_REGION:-eu-west-2}"
   ```
2. Replace all `eu-west-1` literals in §6.5 with `$DEV_REGION` (2 occurrences: create-access-key and delete-access-key calls)
3. Insert `sts get-caller-identity` verification step between create and delete in §6.5:
   - Probe with new credentials before deleting old key
   - On failure: emit WARNING, preserve old key, abort rotation (return 0 with fallback)
   - On success: proceed to delete old key
4. Update §5.2 rotation flow diagram to include step 4c (verification), renumber 4d→4e

**Acceptance criteria:**
- [ ] `DEV_REGION` constant declared in §6.1a with `${DEV_REGION:-eu-west-2}` default
- [ ] No `eu-west-1` literals remain in §6.5
- [ ] Verification step uses `sts get-caller-identity` with new credentials
- [ ] Verification failure preserves old key and emits WARNING (does not delete)
- [ ] Verification success proceeds to delete old key
- [ ] §5.2 flow diagram shows verification step (4c)
- [ ] Partial-failure handling note updated to include verification-failure scenario

**Build validation:** `bash -n` on extracted `_rotate_bootstrap_credentials` function

---

### Unit 5: Auth plan — §6.6, §6.7 region + profile + masked output

**Specs covered:** SW-001 (DEV_REGION in §6.6, §6.7), DX-005 (masked output in §6.7), DX-006 (namespace profile to `tianlu-floci-dev`)

**Changes:**
1. §6.6 `dev_env`:
   - Replace `eu-west-1` with `$DEV_REGION` in config profile printf and export lines (2 occurrences)
   - Replace all `floci-dev` profile references with `tianlu-floci-dev` (5 occurrences: grep, printf config, sed, printf creds, export)
2. §6.7 `_print_next_steps`:
   - Replace `eu-west-1` with `$DEV_REGION` in manual rotation command
   - Replace `AWS_PROFILE=floci-dev` with `AWS_PROFILE=tianlu-floci-dev`
   - Replace fallback path: mask `floci`/`floci` literal, reference docs instead (SPEC-DX-005)

**Acceptance criteria:**
- [ ] No `eu-west-1` literals remain in §6.6 or §6.7
- [ ] No `floci-dev` profile references remain (all use `tianlu-floci-dev`)
- [ ] §6.7 fallback path does not echo `floci`/`floci` literally
- [ ] §6.7 fallback path references `docs/design/authentication-plan.md §5.2` for rotation steps

**Build validation:** `bash -n` on extracted `dev_env` and `_print_next_steps` functions; grep for `eu-west-1` and `floci-dev` in auth plan (should return zero matches in code blocks)

---

### Unit 6: Auth plan — cross-reference additions

**Specs covered:** SW-002 (Deny statement), SW-006 (backend config), SW-007 (env tag), SW-008 (IRSA DurationSeconds)

**Changes:**
Add new subsections after §6.10 (or integrate into existing sections):

1. **§6.x.1 — IAM permissions boundary enforcement** (SW-002):
   - Cross-reference to `infra/live/10-management-iam/main.tf` `DenyAllExceptBoundary` statement
   - Explain the `StringNotEquals` on `iam:PermissionsBoundary` condition
   - Link to `landing-zone-design.md` §5.1

2. **§6.x.2 — Terraform backend configuration** (SW-006):
   - Full `terraform init -backend-config` command for stage `10-management-iam`
   - Pre-rotation and post-rotation variants
   - Note that `bucket` is NOT hardcoded in `providers.tf`

3. **§6.x.3 — Environment tag consistency** (SW-007):
   - Cross-reference to `infra/environments/dev.tfvars`
   - Explain that `Project`, `Environment`, `ManagedBy` are injected by `providers.tf` merge
   - `Environment` tag value is `"dev"` (from `var.environment`), not `"development"`

4. **§6.x.4 — IRSA stand-in session duration** (SW-008):
   - Cross-reference to `landing-zone-design.md` §5.4
   - `DurationSeconds` bound of 3600s, re-assumption cadence of 30 minutes

**Acceptance criteria:**
- [ ] Four new subsections present with correct cross-references
- [ ] All referenced file paths resolve to existing files
- [ ] Backend config subsection includes full `terraform init` command with all 9 `-backend-config` flags
- [ ] Each subsection has a clear rationale explaining why the cross-reference exists

**Build validation:** Markdown link check (verify all `[text](path)` references resolve)

---

### Unit 7: Auth plan — §6.10 code block update (BS-007)

**Specs covered:** BS-007 (fix `driver_args[*]` expansion)

**Changes:**
Replace the current `launch_driver` code block in §6.10 with the fixed version using `printf '%q ' "${driver_args[@]}"`:
```bash
launch_driver() {
  local -a driver_args=()
  if [[ "$NO_SIDECAR" == true ]]; then
    driver_args+=(--no-sidecar)
  fi
  if [[ -n "${AUTH_MODE:-}" ]]; then
    driver_args+=(--auth-mode="$AUTH_MODE")
  fi
  (
    local driver_args_quoted
    driver_args_quoted="$(printf '%q ' "${driver_args[@]}")"
    limactl shell "$TWIN_NAME" -- bash -c \
      "sudo systemd-run --quiet --wait --unit=tianlu-driver -- /opt/tianlu/mock-server/in-vm/run-in-vm.sh ${driver_args_quoted}" 2>/dev/null
  ) &
  DRIVER_SHELL_PID=$!
}
```

**Acceptance criteria:**
- [ ] No `${driver_args[*]}` expansion in code block
- [ ] Uses `printf '%q ' "${driver_args[@]}"` for safe argument quoting
- [ ] `${arr[@]+...}` guard removed (not needed with `printf '%q '` on empty array)
- [ ] `DRIVER_SHELL_PID=$!` present after background subshell

**Build validation:** `bash -n` on extracted `launch_driver` function

---

### Unit 8: infra/ code changes

**Specs covered:** SW-002 (main.tf), SW-006 (providers.tf), SW-007 (dev.tfvars)

**Changes:**
1. **`infra/live/10-management-iam/main.tf:49-63`** — Replace `DenyAllExceptBoundary` statement:
   - Change `resources = [aws_iam_policy.general_app_boundary.arn]` to `resources = ["*"]`
   - Add `condition` block with `StringNotEquals` on `iam:PermissionsBoundary`
2. **`infra/live/10-management-iam/providers.tf:12`** — Remove hardcoded `bucket = "tf-state-dev"`:
   - Replace with comment: `# bucket and region are passed via -backend-config at init time.`
3. **`infra/environments/dev.tfvars:24-29`** — Fix `default_tags`:
   - Remove `Project`, `Environment`, `ManagedBy` from the map (keep only `Owner`)
   - Add comment explaining these are injected by `providers.tf` merge

**Acceptance criteria:**
- [ ] `main.tf` `DenyAllExceptBoundary` uses `resources = ["*"]` with `StringNotEquals` condition
- [ ] `providers.tf` backend block has no hardcoded `bucket` value
- [ ] `dev.tfvars` `default_tags` contains only `Owner` (not `Project`, `Environment`, `ManagedBy`)
- [ ] `dev.tfvars` has comment explaining the `providers.tf` merge injection

**Build validation:** `terraform fmt -check` on all three files; `terraform validate` in `infra/live/10-management-iam/`

---

### Unit 9: External documentation changes

**Specs covered:** DX-001 (GAP-015), DX-002 (solution-design.md §8), DX-004 (AGENTS.md resume-path), DX-007 (AGENTS.md ExecCondition), SW-008 (landing-zone-design.md §5.4), DX structural (AGENTS.md Key files)

**Changes:**
1. **`docs/design/gaps-register.md`** — Add GAP-015 after GAP-014 (SPEC-DX-001)
2. **`docs/design/solution-design.md`** — Replace §8 (5 lines) with expanded §8–§8.3 (SPEC-DX-002)
3. **`docs/design/landing-zone-design.md`** — Add `DurationSeconds` bound + re-assumption cadence to §5.4 (SPEC-SW-008)
4. **`AGENTS.md`** — Three additions:
   - Critical gotcha: `FLOCI_AUTH_MODE` cannot change without `make dev-recreate` (SPEC-DX-004)
   - Critical gotcha: Dev twin `ExecCondition` Quadlet override does not exist in production (SPEC-DX-007)
   - Key files: Add `authentication-plan.md` entry after `landing-zone-design.md` (DX structural)

**Acceptance criteria:**
- [ ] GAP-015 present in gaps-register.md with Impact, Mitigation, and Reference fields
- [ ] solution-design.md §8 includes mode table, IAM identity lifecycle diagram, presign secret, multi-account isolation
- [ ] landing-zone-design.md §5.4 includes `DurationSeconds=3600`, 30-min re-assumption cadence, expiry behavior
- [ ] AGENTS.md has both new Critical gotchas (resume-path + ExecCondition)
- [ ] AGENTS.md Key files lists `authentication-plan.md`
- [ ] All cross-document references are consistent (no contradictions)

**Build validation:** Markdown link check across all modified docs; grep for consistency of IAM identity names across files

---

## Build Validation

Since the primary artifact is a Markdown specification document (not executable code), build validation consists of:

### Per-unit validation
1. **`bash -n`** on every code block extracted from the auth plan — verifies syntax of all bash code blocks
2. **Markdown link check** — verify all `[text](path.md#section)` references resolve to existing files and anchor targets
3. **Cross-reference consistency** — grep for identity names (`floci-deployer`, `platform-admin`, `tianlu-floci-dev`) across all modified files to ensure no contradictions

### Final validation (B3)
1. **Full `bash -n` pass** — extract all code blocks from the enriched auth plan into a temp file, run `bash -n`
2. **`terraform fmt -check`** on modified infra files
3. **`terraform validate`** in `infra/live/10-management-iam/`
4. **Spec coverage audit** — verify all 38 specs (8 SW + 13 TX + 7 DX + 10 BS) are either:
   - Implemented in the auth plan (code block changes, structural additions)
   - Implemented in referenced files (infra/*.tf, docs/*.md, AGENTS.md)
   - Explicitly noted as "no auth plan change needed" (BS-001–006, BS-008–010)
5. **Grep for stale values** — confirm zero matches for `eu-west-1`, `floci-dev` (as profile name), `floci/floci` (as echoed literal) in auth plan code blocks

---

## Implementation Order Rationale

| Order | Unit | Rationale |
|-------|------|-----------|
| 1 | Structural + DX | Non-code-block changes first — status banner, §4.4, §6.3, §6.11. No dependencies on other units. |
| 2 | §4.2 restructuring | Foundation for all code blocks — the case statement is referenced by §6.1, §6.2, §6.3. SW-003 before SW-004 per specialist ordering constraint. |
| 3 | §6.1, §6.2 updates | Depends on Unit 2 (must mirror the restructured case). |
| 4 | §5.2, §6.5 rotation | SW-001 (DEV_REGION) before SW-005 (verification uses DEV_REGION). Independent of Units 2–3. |
| 5 | §6.6, §6.7 updates | Uses DEV_REGION from Unit 4. Profile namespace + masked output are independent of rotation logic. |
| 6 | Cross-reference additions | Independent of all other units — adds new subsections, doesn't modify existing code blocks. |
| 7 | §6.10 BS-007 | Independent — only affects the run-test.sh code block. |
| 8 | infra/ code changes | Independent of auth plan text — modifies actual .tf files. Can be done in parallel with Units 6–7. |
| 9 | External doc changes | Independent — modifies gaps-register.md, solution-design.md, AGENTS.md, landing-zone-design.md. Can be done in parallel with Units 6–8. |

Units 6–9 are independent of each other and can be parallelized if multiple agents are available. Units 1–5 must be sequential due to dependencies.

---

## Spec Coverage Matrix

| Spec | Unit | Status |
|------|------|--------|
| SW-001 (DEV_REGION) | 4, 5 | Code block changes in §6.1a, §6.5, §6.6, §6.7 |
| SW-002 (Deny statement) | 6, 8 | Cross-reference in auth plan + main.tf fix |
| SW-003 (readonly out of case) | 2, 3 | §4.2 + §6.1 restructuring |
| SW-004 (FLOCI_SERVICES_IAM_ENABLED) | 2, 3 | §4.2 + §6.1 + §6.2 |
| SW-005 (sts verification) | 4 | §5.2 + §6.5 |
| SW-006 (backend config) | 6, 8 | Cross-reference + providers.tf fix |
| SW-007 (env tag) | 6, 8 | Cross-reference + dev.tfvars fix |
| SW-008 (IRSA DurationSeconds) | 6, 9 | Cross-reference + landing-zone-design.md |
| TX-001–013 (all test specs) | 1 | §6.11 comprehensive test section |
| DX-001 (GAP-015) | 9 | gaps-register.md |
| DX-002 (solution-design §8) | 9 | solution-design.md |
| DX-003 (dev_env idempotency) | — | Already correct — no change needed |
| DX-004 (resume-path) | 1, 9 | §4.4 + AGENTS.md |
| DX-005 (masked output) | 1, 5 | §6.3 + §6.7 |
| DX-006 (namespace profile) | 5 | §6.6 + §6.7 |
| DX-007 (ExecCondition) | 9 | AGENTS.md |
| DX structural (banner, Key files) | 1, 9 | Auth plan + AGENTS.md |
| BS-001–006, BS-008–010 | — | No auth plan change needed (see table above) |
| BS-007 (driver_args) | 7 | §6.10 code block |

**Total: 38 specs, 28 implemented in this plan, 10 explicitly out of scope (no auth plan change needed)**

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Code block drift between §4.2 and §6.1 | Medium | High — inconsistent spec | Unit 3 explicitly diffs §4.2 vs §6.1 after Unit 2 |
| Markdown link rot after section renumbering | Low | Medium — broken nav | Final validation grep for all `](#` references |
| `terraform validate` fails after providers.tf change | Low | Medium — blocks infra | Run validate in Unit 8 before marking complete |
| TX test specs too verbose for §6.11 | Medium | Low — readability | Summarize at test-file level with key patterns; full details in A1-TX specialist doc |
| Cross-document inconsistency after parallel Units 6–9 | Low | Medium | Final validation cross-reference grep across all modified files |
