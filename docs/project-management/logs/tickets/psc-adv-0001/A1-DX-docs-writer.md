# A1-DX: Docs Writer Review — psc-adv-0001

| Field | Value |
|-------|-------|
| Agent | docs-writer |
| Timestamp | 2026-07-29T00:00:00Z |
| Step | A1-DX |
| Phase | A |
| Ticket | psc-adv-0001 |
| Files reviewed | `docs/design/authentication-plan.md` (649L), `docs/design/landing-zone-design.md` (511L), `setup-floci.sh` (1020L), `mock-server/dev-twin.sh` (801L), `mock-server/run-test.sh` (563L) |

## Self-Audit Checklist

| Category | Checked? | Finding or PASS |
|----------|----------|-----------------|
| Build passes (exit 0, no warnings) | N/A | No build step for documentation review |
| Typed enums / vocabulary types | N/A | Not applicable to bash scripts or markdown docs |
| Documentation on new public symbols | yes | All bash functions in reviewed scripts have pydoc-style headers — PASS |
| Spec/datasheet fidelity | yes | Auth plan cites Floci scraped docs + AWS IAM User Guide; landing-zone §15 has extensive AWS references — PASS |
| Module boundary | N/A | Not applicable to bash scripts |
| Reserved/padding fields handled | N/A | Not applicable |
| No magic numbers in doc examples | yes | Auth plan uses named constants (`FLOCI_AUTH_MODE`, `DEV_CREDENTIALS_FILE`); landing-zone uses variables — PASS |
| Buffer safety | N/A | Not applicable |
| AGENTS.md compliance | yes | All scripts follow conventions: `set -euo pipefail`, `IFS=$'\n\t'`, `readonly` config, guarded `main`, sourceable — PASS |
| Conventional commit ready | N/A | Not committing in this step |

---

## Findings

### F-DX-001: Authentication plan is a forward-looking design, not a description of current state — reads as if implemented

| Field | Value |
|-------|-------|
| Confidence | 90 |
| Severity | HIGH |
| File | `docs/design/authentication-plan.md` |
| Category | documentation-quality |

**Description:** The authentication plan describes extensive code changes across four files (§6.1–§6.11) using present-tense language and concrete line numbers (e.g., "Location: config block, after `FLOCI_TLS_SELF_SIGNED` (line ~62)"). However, **none of these changes exist in the current codebase**:

- `setup-floci.sh`: No `FLOCI_AUTH_MODE` case statement, no auth vars in `write_env_file`, no conditional `print_summary` (line 946 still prints the hardcoded "UNAUTHENTICATED" message unconditionally).
- `dev-twin.sh`: No `_rotate_bootstrap_credentials` function, no `DEV_CREDENTIALS_FILE` constant, no `DEV_AUTH_MODE` variable, no `FLOCI_AUTH_MODE=sigv4` in `_install_absent` (line 484), `dev_env` (line 769) still writes hardcoded `test/test`.
- `run-test.sh`: No `--auth-mode` flag, no `AUTH_MODE` variable.
- `preflight-floci.sh`: No `FLOCI_BOOTSTRAP_AKID`/`FLOCI_BOOTSTRAP_SECRET` support.

The document's §6 ("Explicit code changes") uses imperative language ("Add the `FLOCI_AUTH_MODE` case statement") in some places but present-tense descriptions ("The installer accepts a single `FLOCI_AUTH_MODE` env var") in others. A reader skimming §4 or §6 could reasonably conclude these features exist. The document needs a prominent banner at the top stating its status as a design proposal, not implemented code.

**Recommendation:** Add a status banner at the top of `authentication-plan.md`:
```markdown
> **Status: Design proposal — NOT YET IMPLEMENTED.** The code changes described in §6
> do not exist in the current codebase. See the implementation ticket for current status.
```
Alternatively, move the document to a `docs/design/proposals/` directory to make its status explicit by location.

---

### F-DX-002: `platform-admin` described as a concrete identity in both design docs but Terraform only creates the policy — cross-document inconsistency

| Field | Value |
|-------|-------|
| Confidence | 85 |
| Severity | HIGH |
| File | `docs/design/authentication-plan.md` §3.1, §3.3; `docs/design/landing-zone-design.md` §5.1 |
| Category | cross-doc-consistency |

**Description:** Both design documents describe `platform-admin` as a concrete, assumable identity:

- **Auth plan §3.1:** "Platform admin | `platform-admin` IAM user/group/role | Created by Terraform stage `10-management-iam`"
- **Auth plan §3.3:** "After the landing-zone Terraform creates `platform-admin`, the deployer credentials should be rotated out and the platform-admin used for ongoing operations."
- **Landing-zone design §5.1:** "`platform-admin` is an assumable administrative identity (group + user + role) responsible for managing IAM users, roles, and policies."

However, the SW Engineer's review (F-SW-008) confirmed that the `10-management-iam` Terraform stage creates only `aws_iam_policy.platform_admin` — the policy document — but **no IAM user, group, or role** to hold it. The `infra/AGENTS.md` acknowledges this: "no users/roles/groups" and "Stub until Phase 1."

The auth plan's lifecycle diagram (§3.3) shows `floci-deployer → platform-admin → app roles` as if `platform-admin` is a concrete principal that supersedes the deployer. Without the IAM user/role resources, `platform-admin` is a policy without a principal — there is nothing to assume.

**Recommendation:** Both documents should explicitly note that `platform-admin` is currently a policy-only stub. The auth plan §3.3 lifecycle diagram should add a note: "(policy only — IAM user/role pending Phase 1 implementation)." The landing-zone design §5.1 should add a similar caveat. This is a Phase 1 implementation task, not a design flaw, but the gap between documentation and code must be closed.

---

### F-DX-003: Auth plan §6.12 promises a gap finding in `gaps-register.md` that does not exist

| Field | Value |
|-------|-------|
| Confidence | 90 |
| Severity | MODERATE |
| File | `docs/design/authentication-plan.md` §6.12, line 532-533 |
| Category | missing-docs |

**Description:** The auth plan §6.12 ("Documentation") states:
> - Add a gap finding in `gaps-register.md`: Floci has no root user concept; `FLOCI_DEFAULT_ACCOUNT_ID` is a namespace, not an authenticated principal

This gap does not exist in `docs/design/gaps-register.md`. The file contains GAP-009 (closed), GAP-013b (open), and GAP-014 (partially closed). There is no entry for Floci's lack of a root user. The auth plan §3.2 describes this as a Floci limitation and §9.2 lists it as an adopted challenger finding, but the promised gap entry was never created.

**Recommendation:** Create the gap entry in `gaps-register.md` with the next sequential ID (GAP-015). The entry should document: Floci has no root user concept; `FLOCI_DEFAULT_ACCOUNT_ID` is a namespace identifier, not an authenticated principal; the `floci-deployer` serves as the de-facto root-equivalent for bootstrap; this is a Floci limitation, not a design choice.

---

### F-DX-004: Auth plan §6.12 promises a lifecycle note in `solution-design.md` or `REVIEW.md` that does not exist

| Field | Value |
|-------|-------|
| Confidence | 90 |
| Severity | MODERATE |
| File | `docs/design/authentication-plan.md` §6.12, line 534-535 |
| Category | missing-docs |

**Description:** The auth plan §6.12 states:
> - Add a lifecycle note in `solution-design.md` or `REVIEW.md`: `floci-deployer` (bootstrap) → landing-zone stage 10 → `platform-admin` (ongoing)

Neither `docs/design/solution-design.md` nor `REVIEW.md` contains this lifecycle note. A grep for `floci-deployer.*bootstrap.*platform-admin` across both files returns zero matches. The `solution-design.md` mentions `FLOCI_DEFAULT_ACCOUNT_ID` and `FLOCI_AUTH_VALIDATE_SIGNATURES` but does not describe the IAM identity lifecycle. `REVIEW.md` does not mention `floci-deployer` or `platform-admin` at all.

**Recommendation:** Add the lifecycle note to `solution-design.md` in the security section (§10.4 or a new §10.5). The note should describe the three-layer IAM hierarchy (root-equivalent namespace → bootstrap deployer → platform-admin) and the promotion path. This is important context for anyone reading the solution design who encounters the auth plan's IAM concepts.

---

### F-DX-005: `dev-twin.sh` `dev_env` function writes hardcoded `test/test` credentials — auth plan §6.6 replacement not implemented

| Field | Value |
|-------|-------|
| Confidence | 95 |
| Severity | HIGH |
| File | `mock-server/dev-twin.sh`, line 769 |
| Category | code-comments |

**Description:** The `dev_env` function at line 768-769 writes hardcoded credentials unconditionally:
```bash
if ! grep -q '\[floci-dev\]' "$creds_file" 2>/dev/null; then
    printf '\n[floci-dev]\naws_access_key_id = test\naws_secret_access_key = test\n' >> "$creds_file"
fi
```

The authentication plan §6.6 specifies that `dev_env` should load rotated credentials from `DEV_CREDENTIALS_FILE` when available, falling back to `test/test` only when no rotated credentials exist. The current code has no `DEV_CREDENTIALS_FILE` constant, no `_rotate_bootstrap_credentials` function, and no credential loading logic. This is the same finding as F-SX-001 from the Security Reviewer, confirmed independently.

The function also has an idempotency bug: it only writes credentials if the `[floci-dev]` block doesn't exist, but never updates stale credentials. The auth plan §6.6 fixes this with a `sed -i.bak` replace-then-write pattern.

**Recommendation:** Implement the auth plan §6.6 changes: add `DEV_CREDENTIALS_FILE` constant (§6.1a), implement `_rotate_bootstrap_credentials` (§6.5), update `dev_env` to load rotated credentials with `test/test` fallback, and use the sed replace pattern to handle credential updates. This is a security-sensitive function — hardcoded credentials in a dev tool are a moderate risk, but the auth plan's rotation design eliminates them.

---

### F-DX-006: `setup-floci.sh` `print_summary` unconditionally prints "UNAUTHENTICATED" — auth plan §6.3 conditional not implemented

| Field | Value |
|-------|-------|
| Confidence | 90 |
| Severity | MODERATE |
| File | `setup-floci.sh`, line 946 |
| Category | code-comments |

**Description:** The `print_summary` function at line 946 prints:
```bash
echo "RISK: Floci is UNAUTHENTICATED by default (FLOCI_AUTH_VALIDATE_SIGNATURES=false)."
```
This message is unconditional — it prints even if `FLOCI_AUTH_VALIDATE_SIGNATURES=true`. The auth plan §6.3 specifies a conditional: when `FLOCI_AUTH_VALIDATE_SIGNATURES=true`, print a different message confirming IAM enforcement is on with bootstrap admin instructions. When `false`, print the current risk warning.

Since `FLOCI_AUTH_MODE` is not yet implemented (F-DX-001), this message is currently always correct. But once the auth mode parameter is added, the summary will be misleading in `sigv4` mode. The auth plan explicitly addresses this, so it's a known gap — but worth flagging because the current script's summary message will be stale after implementation.

**Recommendation:** Implement the conditional `print_summary` from auth plan §6.3 as part of the `FLOCI_AUTH_MODE` implementation. The sigv4 branch should print the auth-ON message with bootstrap admin info and rotation instructions.

---

### F-DX-007: `setup-floci.sh` `write_env_file` does not write auth-related env vars — auth plan §6.2 not implemented

| Field | Value |
|-------|-------|
| Confidence | 90 |
| Severity | MODERATE |
| File | `setup-floci.sh`, lines 815-842 |
| Category | code-comments |

**Description:** The `write_env_file` function writes 15 env vars to `floci.env` but does not include the three auth-related variables specified in the auth plan §6.2:
```bash
FLOCI_AUTH_VALIDATE_SIGNATURES=${FLOCI_AUTH_VALIDATE_SIGNATURES}
FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED=${FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED}
FLOCI_SERVICES_IAM_SEED_DEPLOYER_PRINCIPAL=${FLOCI_SERVICES_IAM_SEED_DEPLOYER_PRINCIPAL}
```

Without these vars in the env file, Floci uses its image defaults (all `false`), which means signature validation and IAM enforcement are off regardless of any `FLOCI_AUTH_MODE` setting. The auth plan's `FLOCI_AUTH_MODE` case statement sets these variables, but they must also be written to the env file for Floci to read them at startup.

**Recommendation:** Add the three auth vars to `write_env_file` as part of the `FLOCI_AUTH_MODE` implementation. The vars should be written after the `FLOCI_AUTH_PRESIGN_SECRET` line, as specified in the auth plan §6.2.

---

### F-DX-008: `run-test.sh` has no `--auth-mode` flag — auth plan §6.10 not implemented

| Field | Value |
|-------|-------|
| Confidence | 85 |
| Severity | MODERATE |
| File | `mock-server/run-test.sh` |
| Category | code-comments |

**Description:** The auth plan §6.10 specifies that `run-test.sh` should accept a `--auth-mode=off|sigv4` flag (default `off`) and pass `AUTH_MODE` to the guest driver. The current `run-test.sh` has no such flag. A grep for `auth-mode`, `AUTH_MODE`, or `sigv4` returns zero matches. The `parse_args` function (lines 65-106) handles `--fresh`, `--keep`, `--destroy`, `--no-sidecar`, `--reboot-test`, and `--evidence-dir` but not `--auth-mode`.

The test twin currently always runs with `auth_mode=off` (the installer default). The auth plan §7.3 defines a test matrix showing different behavior for `auth_mode=off` vs `auth_mode=sigv4` (different `podman exec` credential overrides, different installer invocations). Without the `--auth-mode` flag, the sigv4 test path cannot be exercised.

**Recommendation:** Add `--auth-mode=off|sigv4` flag to `run-test.sh` `parse_args`, pass `AUTH_MODE` to the guest driver via `launch_driver`, and implement the per-call `podman exec` credential overrides in `run-in-vm.sh` as specified in auth plan §6.10 and §7.2.

---

### F-DX-009: `preflight-floci.sh` `aws_admin` hardcodes `test` secret — auth plan §6.9 bootstrap credential support not implemented

| Field | Value |
|-------|-------|
| Confidence | 85 |
| Severity | MODERATE |
| File | `scripts/preflight-floci.sh`, line 35 |
| Category | code-comments |

**Description:** The `aws_admin` helper at line 35 hardcodes `AWS_SECRET_ACCESS_KEY=test`:
```bash
aws_admin() {
  AWS_ACCESS_KEY_ID="${FLOCI_BOOTSTRAP_AKID:-$DEV_AKID}" \
  AWS_SECRET_ACCESS_KEY="${FLOCI_BOOTSTRAP_SECRET:-test}" \
  aws --endpoint-url "$ENDPOINT" --region "$REGION" "$@"
}
```

The auth plan §6.9 specifies that this should accept bootstrap credentials via `FLOCI_BOOTSTRAP_AKID` and `FLOCI_BOOTSTRAP_SECRET` env vars. The current code partially implements this — `FLOCI_BOOTSTRAP_AKID` is referenced but `FLOCI_BOOTSTRAP_SECRET` is not. A grep for `FLOCI_BOOTSTRAP_SECRET` in `preflight-floci.sh` returns zero matches. The `test` fallback is hardcoded.

When running against a `sigv4` Floci, the `test/test` credential is not associated with any IAM user (the deployer is `floci`/`floci`), so the preflight gates would fail with a signature validation error. The preflight script cannot currently operate against a sigv4-enabled Floci.

**Recommendation:** Implement the auth plan §6.9 changes: add `FLOCI_BOOTSTRAP_SECRET` env var support to `aws_admin`, with `test` as the fallback. Document in `preflight-floci.sh` comments that when running against sigv4 Floci, set both `FLOCI_BOOTSTRAP_AKID` and `FLOCI_BOOTSTRAP_SECRET` to the deployer credentials.

---

### F-DX-010: No ADRs exist for significant design decisions — `docs/adr/` directory is empty

| Field | Value |
|-------|-------|
| Confidence | 80 |
| Severity | MODERATE |
| File | `docs/adr/` (empty directory) |
| Category | missing-docs |

**Description:** The `docs/adr/` directory contains no ADR files. Both the authentication plan and the landing-zone design contain significant architectural decisions that warrant ADRs per the `documentation-standards` skill:

- **Auth plan decisions:** Collapsing three independent auth toggles into a single `FLOCI_AUTH_MODE` parameter; using `floci-deployer` as bootstrap-only with rotation; the `platform-admin` delegated administration model; the `true`/`false` crypto-theater prevention.
- **Landing-zone decisions:** One IAM role per application; modeling hub-and-spoke (incl. TGW) as intent with IAM + NetworkPolicy enforcement; centralized EKS with namespaces for multi-tenancy; environment = account (AKID) with layered stacks.

The `documentation-standards` skill requires: "Per significant decision — An ADR." The `pipeline` skill's A2a step requires: "Every resolved design decision from A2 MUST have an ADR file." The landing-zone design §13 lists 5 key design decisions in a table — these are prime candidates for ADRs.

**Recommendation:** Create ADRs for the key decisions in both documents. At minimum:
- ADR for `FLOCI_AUTH_MODE` parameter design (collapsing three toggles)
- ADR for `floci-deployer` as bootstrap-only with credential rotation
- ADR for one IAM role per application with permissions boundary
- ADR for environment = account (AKID) with layered Terraform stacks

Use `node docs/project-management/next-id.mjs adr` for sequence numbers. Each ADR should follow the template in `documentation-standards` §2.5.

---

### F-DX-011: Code comment quality is strong across all three scripts — no missing function documentation

| Field | Value |
|-------|-------|
| Confidence | 95 |
| Severity | N/A (positive finding) |
| File | `setup-floci.sh`, `mock-server/dev-twin.sh`, `mock-server/run-test.sh` |
| Category | code-comments |

**Description:** All three scripts demonstrate excellent function documentation:

- **`setup-floci.sh`:** Every function has a pydoc-style header describing purpose, idempotency guarantees, parameters, and design rationale. The `write_quadlet_unit` function (lines 224-317) has a 30-line header explaining the atomic write pattern, Quadlet specifiers, and the rationale for each `[Service]` hardening directive excluded. The `assert_userns_allowed` function (lines 420-506) documents the conflicting-attachment avoidance for Ubuntu 26.04 system profiles. The `run_as_floci` helper (lines 198-222) explains why `--` is omitted (GNU coreutils 9.4 `env` behavior).

- **`dev-twin.sh`:** Functions are well-documented with purpose, parameters, and edge cases. `_resume_health_check` (lines 491-521) explains the AppArmor boot-race and the reset+restart fallback. `_ensure_service` (lines 394-414) documents the state-aware idempotency logic. `managed_hosts_add` (lines 167-237) documents the confirmation flow and test override mechanism.

- **`run-test.sh`:** Functions have clear one-line descriptions. `wait_for_reboot_health` (lines 301-343) documents the AppArmor boot-timing quirk and the fallback path. `validate_summary` (lines 425-499) documents the criterion status matrix and bash 3.2 compatibility.

The scripts follow the AGENTS.md convention of pydoc-style function documentation. Complex sections (AppArmor userns handling, Quadlet hardening, credential rotation) are explained with inline comments citing the specific mechanism and rationale. No undocumented public functions were found.

---

### F-DX-012: Reference quality is strong in both design documents — authoritative sources cited

| Field | Value |
|-------|-------|
| Confidence | 90 |
| Severity | N/A (positive finding) |
| File | `docs/design/authentication-plan.md`, `docs/design/landing-zone-design.md` |
| Category | references |

**Description:** Both design documents cite authoritative sources:

- **Auth plan §1:** Lists 5 references including Floci scraped docs (environment-variables.md, multi-account.md, docker-images.md), the landing-zone design, and the AWS IAM User Guide root-user best practices. Each reference is a relative link to a file in the repo or an official AWS documentation URL.

- **Landing-zone design §15:** Contains an extensive references section organized by domain (IAM & identity, Accounts & landing zones, Networking, EKS, Data, Kubernetes, Terraform, Floci) with 20+ links to official AWS documentation, Kubernetes docs, Terraform registry, and Floci docs. Every link is to an authoritative source (docs.aws.amazon.com, kubernetes.io, developer.hashicorp.com, floci.io).

- **Auth plan §9:** Documents challenger findings with specific section references showing where each finding was addressed.

- **Landing-zone design §1.1:** Includes a fidelity table distinguishing enforced vs. modeled controls with explicit consequences for the design — this is a model of honest documentation.

No unverified or non-authoritative references were found. All URLs are to official documentation or project-internal files.

---

### F-DX-013: AGENTS.md script conventions are consistently followed across all three scripts

| Field | Value |
|-------|-------|
| Confidence | 95 |
| Severity | N/A (positive finding) |
| File | `setup-floci.sh`, `mock-server/dev-twin.sh`, `mock-server/run-test.sh` |
| Category | code-comments |

**Description:** All three scripts follow the AGENTS.md script conventions:

| Convention | `setup-floci.sh` | `dev-twin.sh` | `run-test.sh` |
|------------|------------------|---------------|---------------|
| `set -euo pipefail` + `IFS=$'\n\t'` | Line 25-26 | Line 2-3 | Line 4-5 |
| `readonly` config with `${VAR:-default}` | Lines 37-180 | Lines 6-44 | Lines 7-24 |
| Guarded `main` (sourceable) | Lines 1017-1020 | Lines 799-801 | Lines 561-563 |
| Pydoc-style function docs | Every function | Every function | Every function |
| Phase-based structure | 7 phases (lines 186-192) | State-machine dispatch | Lifecycle pipeline |
| Idempotency (check before create) | All functions | All functions | `ensure_twin`, `make_evidence_dir` |
| Privilege model (root for setup, drop for user ops) | `run_as_floci` helper | `_run_as_floci_guest` helper | `run_as_floci_guest` via assert.sh |

The `dev-twin.sh` and `run-test.sh` additionally follow the `mock-server/AGENTS.md` conventions: 9p evidence staging, guest driver as transient systemd unit, manifest-validated evidence, and separate twin instances with zero shared state.

---

### F-DX-014: `dev-twin.sh` `dev_env` idempotency bug — only writes credentials if `[floci-dev]` block is absent, never updates stale creds

| Field | Value |
|-------|-------|
| Confidence | 80 |
| Severity | MODERATE |
| File | `mock-server/dev-twin.sh`, lines 768-770 |
| Category | code-comments |

**Description:** The `dev_env` function at lines 768-770 uses a guard clause that only writes credentials when the `[floci-dev]` block doesn't exist:
```bash
if ! grep -q '\[floci-dev\]' "$creds_file" 2>/dev/null; then
    printf '\n[floci-dev]\naws_access_key_id = test\naws_secret_access_key = test\n' >> "$creds_file"
fi
```

This means if the user switches from `auth_mode=off` to `auth_mode=sigv4` (or vice versa), the credentials file retains the old values. The `[floci-dev]` block already exists, so the guard clause skips the write. The user would have stale `test/test` credentials when sigv4 is active, or stale rotated credentials when switching back to off mode.

The auth plan §6.6 fixes this with a `sed -i.bak` pattern that deletes the existing `[floci-dev]` block and writes a fresh one:
```bash
sed -i.bak '/^\[floci-dev\]/,/^\[/d' "$creds_file" && rm -f "${creds_file}.bak"
printf '\n[floci-dev]\naws_access_key_id = %s\naws_secret_access_key = %s\n' "$ak" "$sk" >> "$creds_file"
```

**Recommendation:** Implement the auth plan §6.6 `dev_env` changes, which include the sed replace pattern. This is a prerequisite for the credential rotation feature — without it, rotated credentials are never written to `~/.aws/credentials` after the first `dev_up`.

---

## Cross-Document Consistency Report

### DC-1 — ADR Cross-Reference
- **ADRs found:** 0
- **Referenced:** N/A
- **Orphaned:** N/A
- **Finding:** No ADRs exist. The `docs/adr/` directory is empty. Both design documents contain significant architectural decisions that should have ADRs (see F-DX-010).

### DC-2 — Schema Consistency
- **Contradictions found:** 1
- **Finding:** Both `authentication-plan.md` §3.1/§3.3 and `landing-zone-design.md` §5.1 describe `platform-admin` as a concrete IAM identity (user/group/role). The Terraform code in `10-management-iam` creates only the policy, not the principal. This is a documentation-vs-code contradiction (see F-DX-002).

### DC-3 — Decision-to-Document Trace
- **ADRs checked:** 0
- **Traced:** N/A
- **Untraced:** N/A
- **Finding:** No ADRs to trace. The landing-zone design §13 lists 5 key design decisions in a table — these are documented in the design doc but have no corresponding ADR files.

### DC-4 — SQL-vs-Decision Validation
- **SQL files found:** 0 (no `.sql` files in the repo)
- **Mismatches:** 0
- **Finding:** Not applicable — no SQL schemas are claimed in the reviewed documents.

### Cross-Document Consistency Verdict
**ISSUES FOUND** — One contradiction between design documents and Terraform code (F-DX-002), and missing ADRs for documented design decisions (F-DX-010).

---

## Verdict

**CONDITIONAL PASS**

**Rationale:** The documentation quality is strong overall — both design documents are well-structured, well-referenced, and follow documentation standards. Code comments across all three scripts are excellent, with every function documented and complex sections explained. AGENTS.md conventions are consistently followed.

However, there are blocking issues that must be addressed before this review can pass:

1. **F-DX-001 (confidence 90):** The authentication plan reads as if describing implemented features, but none of the code changes exist. A status banner is needed.
2. **F-DX-002 (confidence 85):** Both design docs describe `platform-admin` as a concrete identity, but Terraform only creates the policy. This cross-document inconsistency must be resolved.
3. **F-DX-005 (confidence 95):** `dev-twin.sh` `dev_env` writes hardcoded `test/test` credentials — the auth plan's rotation design is not implemented.

**Blocking findings (confidence ≥80):** F-DX-001, F-DX-002, F-DX-003, F-DX-004, F-DX-005, F-DX-006, F-DX-007, F-DX-008, F-DX-009, F-DX-010, F-DX-014

**Advisory findings (confidence <80):** None

**Routing:** The auth plan is a design document — the Docs Writer cannot implement code changes. Route to:
- **Code Architect** for `setup-floci.sh`, `dev-twin.sh`, `run-test.sh`, `preflight-floci.sh` code changes (F-DX-005, F-DX-006, F-DX-007, F-DX-008, F-DX-009, F-DX-014)
- **Docs Writer** (self) for documentation fixes: status banner on auth plan (F-DX-001), `platform-admin` caveat in both design docs (F-DX-002), gap entry in `gaps-register.md` (F-DX-003), lifecycle note in `solution-design.md` (F-DX-004), ADR creation (F-DX-010)
