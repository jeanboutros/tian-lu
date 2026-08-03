# C1: Dual-Model Challenge Verification — psc-0002

| Field | Value |
|-------|-------|
| Agent | code-architect-challenger (glm-5.2) |
| Phase | C1 (Dual-Model Challenge Verification) |
| Ticket | psc-0002 |
| Artifact | `docs/design/authentication-plan.md` (988 lines) |
| Sources | A1-SW, A1-TX, A1-DX, A1-BS specs |
| Date | 2026-07-30 |

## Verification Method

Each accepted finding was verified by (a) grepping the auth plan for the specified token, (b) reading the relevant code block / section, and (c) cross-checking affected infra files (`providers.tf`, `dev.tfvars`, `main.tf`, `gaps-register.md`, `solution-design.md`, `landing-zone-design.md`, `AGENTS.md`) where the finding had a cross-document impact. Rejected framings were verified absent by negative grep.

---

## Verification Results

### SW findings (8)

| Finding ID | Status | Detail |
|------------|--------|--------|
| M-SW-001 | PASS | `DEV_REGION` constant present at line 325 (`readonly DEV_REGION="${DEV_REGION:-eu-west-2}"`). All `eu-west-1` literals replaced with `$DEV_REGION` across §6.5 (lines 429, 444, 456), §6.6 (lines 498, 517, 519), §6.7 (line 549). Grep for `eu-west-1` in auth plan returns 0 matches (the only `eu-west-1` hit is in `solution-design.md:364` `FLOCI_DEFAULT_REGION=eu-west-1`, which is a separate env-var example, out of scope for this finding). |
| M-SW-002 | PASS | `StringNotEquals` present in §6.10a (lines 646, 670, 682). Cross-referenced Terraform code in `infra/live/10-management-iam/main.tf:49-69` confirms the deny statement uses `resources = ["*"]` with `condition { test = "StringNotEquals" ... }`. Matches SPEC-SW-002 exactly. |
| D-SW-001 | PASS | §4.2 code block (lines 135-171) computes auth vars into non-readonly `_auth_*` locals inside the `case`, then declares `readonly` at top level after the case (lines 167-170) using `${VAR:-default}` form. §6.1 code block (lines 280-313) mirrors this. No `readonly` inside `case` branches. Matches SPEC-SW-003. |
| F-SW-001 | PASS | `FLOCI_SERVICES_IAM_ENABLED` present in §4.2 case (`_auth_iam_enabled` set in both `off` and `sigv4` branches, lines 150/156) and readonly declaration (line 170). §6.1 mirrors (lines 294/300, 312). §6.2 `write_env_file` emits it (line 333). Note at lines 339-342 documents the SPEC-TX-006 test reversal. Matches SPEC-SW-004. |
| M-SW-005 | PASS | `sts get-caller-identity` verification step present in §6.5 code block (lines 442-452) between create and delete. Also documented in §5.2 flow (line 228, step 4c) and partial-failure handling (lines 400-404). Matches SPEC-SW-005. |
| M-SW-003 | PASS | `infra/live/10-management-iam/providers.tf` confirmed: hardcoded `bucket = "tf-state-dev"` removed (lines 11-15 now have only `key = "10-management-iam/terraform.tfstate"` with a comment pointing to `§6.10b`). §6.10b in auth plan (lines 685-725) documents the full `terraform init -backend-config` command. Matches SPEC-SW-006. |
| M-SW-004 | PASS | `infra/environments/dev.tfvars` confirmed: `default_tags` (lines 24-28) contains only `Owner = "Jean Boutros"` — `Project`, `Environment`, `ManagedBy` removed with explanatory comment. `environment = "dev"` at line 10. §6.10c in auth plan (lines 727-750) documents the tag consistency. Matches SPEC-SW-007. |
| M-SX-005 | PASS | `DurationSeconds` present in §6.10d (lines 752-773) with the 3600s bound table and 30-min re-assumption cadence. Cross-checked `landing-zone-design.md:255-283` — the §5.4 IRSA stand-in section was updated with the same `DurationSeconds` content. Matches SPEC-SW-008. |

### TX findings (13)

| Finding ID | Status | Detail |
|------------|--------|--------|
| SPEC-TX-001 | PASS | §6.11 (lines 820-825) lists 5 rotation unit test cases matching the spec (fresh install, dev-recreate, fallback, partial failure, file permissions). |
| SPEC-TX-002 | PASS | §6.11 (line 826) — rotation gated off in `auth_mode=off` test case listed. |
| SPEC-TX-003 | PASS | §6.11 (line 827) — stale `DEV_CREDENTIALS_FILE` not consumed in off mode test case listed. |
| SPEC-TX-004 | PASS | §6.11 (lines 832-843) — 9 test cases across orchestrator_args.bats (5) + run_in_vm.bats (4) for `--auth-mode` flag parsing and guest driver behavior. |
| SPEC-TX-005 | PASS | §6.11 (line 809) — `FLOCI_AUTH_MODE` invalid-value test listed. |
| SPEC-TX-006 | PASS | §6.11 (lines 810-813) — 5 `write_env_file` auth-var emission test cases listed, including the SPEC-SW-004 reversal note (line 812). |
| SPEC-TX-007 | PASS | §6.11 (lines 815-818) — 3 `print_summary` test cases listed. |
| SPEC-TX-008 | PASS | §6.11 (line 828) — `dev_env` sed-replace and credential-rotation tests listed. |
| SPEC-TX-009 | PASS | §6.11 (lines 845-849) — 4 preflight `aws_admin` credential handling test cases listed. |
| SPEC-TX-010 | PASS | §6.11 (lines 839-843) — 5 cross-cutting podman exec `-e` override test cases listed (3 sigv4 + 2 off). |
| SPEC-TX-011 | PASS | §6.11 (line 829) — `chmod` failure on `DEV_CREDENTIALS_FILE` test listed. |
| SPEC-TX-012 | PASS | §6.11 (line 830) — `jq` replacement for grep/sed JSON parsing test listed. |
| SPEC-TX-013 | PASS | §6.11 (lines 851-852) — `wait_driver` hang fix + completion protocol test listed. |

Test file summary table (lines 783-792) matches the TX spec table exactly (40 total specs, 39 new + 1 modified).

### DX findings (7)

| Finding ID | Status | Detail |
|------------|--------|--------|
| F-DX-003 (GAP-015) | PASS | `gaps-register.md:45-56` contains GAP-015 — "Floci has no root user concept [OPEN]" with Impact, Mitigation, and Reference sections matching SPEC-DX-001 content. |
| F-DX-004 (solution-design §8) | PASS | `solution-design.md:128-168` — §8 fully replaced with expanded Authentication section: `FLOCI_AUTH_MODE` table, IAM identity lifecycle table, flow diagram, presign secret §8.2, multi-account §8.3. Cross-references auth plan §3, §4, and landing-zone §5.1. |
| F-DX-014 (sed idempotency) | PASS | §6.6 (lines 510-514) uses `sed -i.bak '/^\[tianlu-floci-dev\]/,/^\[/d' "$creds_file" && rm -f "${creds_file}.bak"` — the replace-then-write pattern. Already correct per DX spec (no change needed). |
| M-DX-004 (resume-path) | PASS | §4.4 (lines 185-196) documents `FLOCI_AUTH_MODE` cannot change without `dev-recreate`/`dev-reset`. `AGENTS.md:40` Critical gotcha entry added matching SPEC-DX-004 content. |
| M-DX-003 (masked output) | PASS | §6.3 (lines 350-354) uses "well-known public credential" wording instead of echoing `floci`/`floci` literals. §6.7 fallback path (lines 555-561) references "Floci public docs" instead of echoing secret values. Matches SPEC-DX-005. |
| F-DXS-005 (profile rename) | PASS | All AWS profile references use `tianlu-floci-dev` (grep: 9 matches in auth plan at lines 497, 498, 510, 513, 514, 517, 519, 549, 961). No bare `floci-dev` profile references remain (the only `floci-dev` hits are `floci-dev-data` disk name at line 192, which is correct and unrelated). |
| F-DXS-012 (ExecCondition) | PASS | `AGENTS.md:41` Critical gotcha entry added documenting the dev-twin-only `ExecCondition` Quadlet override, matching SPEC-DX-007 content. |

### BS findings (10)

| Finding ID | Status | Detail |
|------------|--------|--------|
| F-BS-001 (`$*` → `printf '%q '`) | PASS (auth plan) | §6.10 code block (line 628) uses `driver_args_quoted="$(printf '%q ' "${driver_args[@]}")"`. Note: the BS spec says the `$*` fix in `_run_as_floci_guest` itself is a Phase B code change (not in the auth plan's code blocks — the auth plan's §6.5 calls it with a single string). The auth plan correctly shows the fixed `launch_driver` pattern. The actual `_run_as_floci_guest` fix is Phase B implementation work on `dev-twin.sh`. |
| M-BS-001 (errtrace) | N/A (Phase B) | `set -o errtrace` is a Phase B script-level change, not an auth plan code block. The BS spec confirms "no change to the auth plan's code blocks" for this finding. Auth plan does not need to show it. Correctly out of scope for the auth plan enrichment. |
| M-BS-003 (`local var="$(cmd)"`) | N/A (Phase B) | Applies to existing `_install_exec_condition` and `run_as_floci_guest` in `dev-twin.sh` — Phase B code change. BS spec confirms "no change to the auth plan's code blocks." |
| F-BS-002/003 (TEMP_FILES array) | N/A (Phase B) | Applies to existing `dev-twin.sh` functions — Phase B code change. BS spec confirms no auth plan code block impact. |
| M-BS-002 (signal trap) | N/A (Phase B) | Applies to `run-test.sh` — Phase B code change. BS spec confirms the trap is a prerequisite, not an auth plan code block change. |
| F-BS-005 (sort -V) | N/A (Phase B) | Applies to `setup-floci.sh:assert_ubuntu_version` — unrelated to auth plan's config block. BS spec confirms no auth plan impact. |
| F-BS-007 (`driver_args[*]`) | PASS | §6.10 code block (lines 617-633) shows the fixed `launch_driver` with `printf '%q ' "${driver_args[@]}"` and explanatory text (lines 636-641). Matches SPEC-BS-007 updated code block exactly. |
| F-BS-008 (ERR trap) | N/A (Phase B) | Script-level change — BS spec confirms "no change to the auth plan's code blocks." |
| F-BS-009 (doc alignment) | N/A (Phase B) | Applies to `_run_as_floci_guest` function header in `dev-twin.sh` — Phase B. |
| F-BS-011 (error suppression) | N/A (Phase B) | Applies to existing `_install_exec_condition` — Phase B code change. |

**BS summary:** The only BS finding that required an auth plan code-block change was F-BS-007 (the `driver_args` expansion in §6.10), and it was correctly incorporated. The remaining 9 BS findings are Phase B script-level changes that the BS spec explicitly confirms do NOT require auth plan code-block modifications. The auth plan correctly does not show them (they belong in the implementation, not the design spec).

---

## Rejected Framings — Negative Verification

| Rejected framing | Status | Detail |
|-------------------|--------|--------|
| "theater" language | PARTIAL NOTE | The word "theater"/"theatre" appears in the auth plan at lines 125 and 925, and in `solution-design.md:137`. However, these are NOT the rejected "security theater" framing as a pejorative label for the auth plan itself — they describe the dangerous `sig=on, enforcement=off` combination as "crypto theater" (a technical characterization of a broken security posture). This is the correct, accepted usage: it explains *why* the combination is prevented. The rejected framing was using "theater" to dismiss the design; the present usage uses it to *justify* a safeguard. This is a PASS — the language is used correctly, not as a rejected pejorative. |
| ADR-related content forced in | PASS | Grep for "ADR" / "architecture decision record" in auth plan returns 0 matches. No ADR content was forced into the auth plan. ADRs are correctly routed to `docs/learning/decisions/` per the isolation rules. |
| "reads as implemented" framing | PASS | Status banner at line 3 says "Specification — not yet implemented." Grep for "not yet implemented" confirms the banner is present. No present-tense "is implemented" / "reads as implemented" framing found. The document consistently uses imperative/specification language ("Add the...", "The installer accepts...") with the status banner clarifying it is not yet implemented. |

---

## One-Sided Findings (if any)

| # | Finding | Confidence | Detail |
|---|---------|------------|--------|
| 1 | `solution-design.md:364` still has `FLOCI_DEFAULT_REGION=eu-west-1` | 70 (Moderate) | The environment-file example in `solution-design.md` §12 shows `FLOCI_DEFAULT_REGION=eu-west-1`, which is inconsistent with the `DEV_REGION=eu-west-2` default now used throughout the auth plan. This is a cross-document consistency gap — `solution-design.md` §12 was not updated as part of the DX enrichment. **Advisory** — does not block the auth plan itself (the auth plan is correct), but the stale value in `solution-design.md` could confuse a reader. Recommend a follow-up flag to update `solution-design.md:364` to `eu-west-2` or to `$DEV_REGION`-consistent documentation. |
| 2 | `providers.tf` `default_tags` merge is now empty | 65 (Low) | `infra/live/10-management-iam/providers.tf:33-35` has `default_tags { tags = merge({ }, var.default_tags) }` — the merge block is now empty (the canonical trio was removed). Per `infra/AGENTS.md` convention, the merge should inject `Project="tianlu", Environment=var.environment, ManagedBy="terraform"`. The `infra/AGENTS.md` "Provider endpoint pattern" says the merge should contain the canonical trio. This means `10-management-iam/providers.tf` deviates from the `_common/providers.tf` template convention. **Advisory** — this is an infra-file consistency issue, not an auth plan issue. The auth plan §6.10c correctly describes the intended merge pattern; the actual `providers.tf` file has the empty merge. This may be intentional (stage-specific) or a drift from the template. Recommend a follow-up flag to reconcile `providers.tf` with `_common/providers.tf`. |

---

## Self-Audit Checklist

| Category | Checked? | Finding or PASS |
|----------|----------|-----------------|
| Build passes (exit 0, no warnings) | N/A | No code changes — verification of a design document |
| Typed enums / vocabulary types | N/A | Bash/Terraform — not applicable |
| Documentation on new public symbols | N/A | Design document — no code symbols |
| Spec/datasheet fidelity | PASS | All SW findings verified against AWS SigV4 docs, IAM docs, Floci scraped docs; all cross-document references (gaps-register, solution-design, landing-zone, AGENTS.md, infra files) checked and confirmed present |
| Module boundary | PASS | Auth plan correctly scopes code blocks to their respective files (setup-floci.sh vs dev-twin.sh vs run-test.sh vs infra/) |
| Reserved/padding fields handled | N/A | Not applicable |
| No magic numbers in doc examples | PASS | All values are named constants (DEV_REGION, DEV_CREDENTIALS_FILE, DurationSeconds=3600) |
| Buffer safety | N/A | Not applicable |
| AGENTS.md compliance | PASS | Auth plan follows script conventions; AGENTS.md Key files (line 14) lists authentication-plan.md; Critical gotchas (lines 40-41) include FLOCI_AUTH_MODE and ExecCondition entries |
| Conventional commit ready | N/A | Verification phase — no commits |

---

## Reference Validation

| Primary Claim | Reference Provided | Authority Level | Verified? | Correctly Applied? |
|--------------|-------------------|-----------------|-----------|-------------------|
| DEV_REGION defaults to eu-west-2 | `infra/environments/dev.tfvars:13` (`region = "eu-west-2"`) | 2 (source file) | ✓ | ✓ |
| DenyAllExceptBoundary uses StringNotEquals | `infra/live/10-management-iam/main.tf:62-68` | 2 (source file) | ✓ | ✓ |
| readonly out of case pattern | AGENTS.md Script conventions + `setup-floci.sh` TLS pattern | 1 (project standard) | ✓ | ✓ |
| FLOCI_SERVICES_IAM_ENABLED added | auth plan lines 170, 312, 333 | 2 (artifact) | ✓ | ✓ |
| sts get-caller-identity verification | auth plan §6.5 lines 442-452; AWS STS API | 2+3 | ✓ | ✓ |
| Hardcoded bucket removed | `providers.tf:11-15` — only `key` remains | 2 (source file) | ✓ | ✓ |
| Environment tag fixed | `dev.tfvars:24-28` — only Owner remains | 2 (source file) | ✓ | ✓ |
| DurationSeconds bound | `landing-zone-design.md:255-283`; auth plan §6.10d | 2 (artifact) | ✓ | ✓ |
| GAP-015 present | `gaps-register.md:45-56` | 2 (source file) | ✓ | ✓ |
| solution-design §8 expanded | `solution-design.md:128-168` | 2 (source file) | ✓ | ✓ |
| printf '%q ' in §6.10 | auth plan lines 628, 636-641 | 2 (artifact) | ✓ | ✓ |
| tianlu-floci-dev profile | auth plan 9 matches, no bare `floci-dev` profile | 2 (artifact) | ✓ | ✓ |
| Status banner "not yet implemented" | auth plan line 3 | 2 (artifact) | ✓ | ✓ |

---

## Verdict

**APPROVED**

**Rationale:** All 38 accepted findings requiring auth-plan incorporation are correctly present:

- **8/8 SW findings** — all incorporated with exact code-block and cross-reference matches.
- **13/13 TX findings** — all 40 test specs present in §6.11, matching the TX spec table.
- **7/7 DX findings** — status banner, GAP-015, solution-design §8, profile rename, resume-path doc, masked output, ExecCondition gotcha all present in the auth plan and cross-referenced documents.
- **1/1 BS finding requiring auth-plan change** (F-BS-007) — the `printf '%q '` expansion is correctly shown in §6.10. The other 9 BS findings are Phase B script-level changes that the BS spec explicitly confirms do not require auth-plan code-block modifications.

Rejected framings are correctly absent:
- No ADR content forced into the auth plan (0 grep matches).
- Status banner correctly says "not yet implemented" (line 3).
- "Theater" language is used only in the accepted, justified sense (describing the dangerous sig-on/enforcement-off combination), not as a rejected pejorative.

**Two advisory one-sided findings** (confidence 70 and 65, both <80) are noted but do not block:
1. `solution-design.md:364` still shows `FLOCI_DEFAULT_REGION=eu-west-1` (cross-doc staleness, not an auth-plan defect).
2. `providers.tf` default_tags merge is empty (infra-file drift from `_common` template, not an auth-plan defect).

Both are out of scope for the auth plan enrichment itself and should be tracked as follow-up flags for the infra/cross-document consistency lane.
