# A1-DO: DevOps Specialist Requirements — psc-0003

## Self-Audit Checklist

| Category | Checked? | Finding or PASS |
|----------|----------|-----------------|
| Build passes (exit 0, no warnings) | N/A | No application code in scope — CI/CD design review only |
| Typed enums / vocabulary types | N/A | Not applicable to CI/CD pipeline design |
| Documentation on new public symbols | N/A | Not applicable to CI/CD pipeline design |
| Spec/datasheet fidelity | N/A | Not applicable to CI/CD pipeline design |
| Module boundary | N/A | Not applicable to CI/CD pipeline design |
| Reserved/padding fields handled | N/A | Not applicable to CI/CD pipeline design |
| No magic numbers in doc examples | N/A | Not applicable to CI/CD pipeline design |
| Buffer safety | N/A | Not applicable to CI/CD pipeline design |
| AGENTS.md compliance | yes | PASS — all findings cross-referenced against AGENTS.md conventions; no CI/CD-specific violations detected |
| Conventional commit ready | N/A | Phase A — no commits yet |
| Authoritative references cited | yes | PASS — GitHub Actions docs, Terraform backend source, OpenSSF Scorecard, OWASP referenced per finding |
| All findings have confidence scores | yes | PASS — every SPEC-DO-NNN carries a confidence score per review-confidence skill |
| No assumptions without evidence | yes | PASS — all claims verified against source files or cited to authoritative references |

---

## DevOps/CI-CD Requirements Analysis

### Scope Summary

This analysis covers 17 findings from the challenge advisory `psc-adv-0017-challenge-review` that fall within the DevOps Specialist's domain: CI/CD pipeline design, test harness orchestration, preflight gate automation, Terraform backend wiring, infrastructure-as-code conventions, and pipeline security. The findings span five subsystems:

| Subsystem | Files | Findings |
|-----------|-------|----------|
| Installer (`setup-floci.sh`) | 1 file | CH-INST-001, 002, 003, 004 |
| Dev twin (`dev-twin.sh`) | 1 file | CH-DEV-005 |
| Test harness (`run-test.sh`) | 1 file | CH-TWIN-001, 003, 005, 006 |
| Preflight gates (`preflight-floci.sh`) | 1 file | CH-LZ-004 |
| Terraform infra (`_common/`, `live/`) | 5 files | CH-LZ-005, 006, 007, 008, 009, 010, 011 |

---

### SPEC-DO-001: CH-INST-001 — Retry 5xx in verify_health; report last code in timeout message

- **Finding ID:** CH-INST-001
- **System(s) affected:** `setup-floci.sh` — `verify_health` function (lines 916–926)
- **Required change:**
  1. Extend the `case` statement in `verify_health` to retry on `5xx` responses (currently only `000` is retried; all other codes fall to `*)` and `exit 1`).
  2. Capture the last observed HTTP code and include it in the timeout message at line 927 (currently reports only the try count).
- **CI/CD impact:**
  - **Direct:** The installer is the primary artifact validated by CI (`make lint`, `make test`, `make twin-test`). A transient 503 during JVM warmup (documented in `digital-twin-findings.md §9` as a 2–3 minute AppArmor start race) currently causes a hard failure. This change makes the installer more resilient to transient conditions, reducing CI flakiness in the Lima twin test.
  - **Twin test:** `make twin-test` exercises `verify_health` through the full installer lifecycle. The change must not break the existing health-check contract (200 = pass, timeout = fail).
  - **Unit tests:** `tests/` bats stubs must be updated if the retry logic changes the number of expected `curl` invocations.
- **Acceptance criteria:**
  1. `verify_health` retries on HTTP `5xx` responses (500–599) with the same backoff as `000`.
  2. `verify_health` fails fast on `4xx` responses (genuine misconfiguration).
  3. The timeout message includes the last observed HTTP code: `"Floci did not return HTTP 200 within ${max_tries} tries (last code: ${last_code})"`.
  4. `make lint` passes (shellcheck).
  5. `make test` passes (bats unit tests).
  6. `make twin-test` passes (Lima digital twin integration test).
- **Confidence:** 88 (High) — static analysis confirms the defect; the fix is well-scoped.

---

### SPEC-DO-002: CH-INST-002 — Per-binary AppArmor sentinel; extend twin hash set

- **Finding ID:** CH-INST-002
- **System(s) affected:** `setup-floci.sh` — `assert_userns_allowed` function (lines 451–500); `mock-server/in-vm/run-in-vm.sh` — idempotency hash set (lines 300–303)
- **Required change:**
  1. Replace the single `grep -q 'podman-userns' "$APPARMOR_PROFILES_FILE"` sentinel with per-binary checks: for each chain binary that needs a userns block (`podman`, `crun`, `newuidmap`, `newgidmap`), check whether that binary's profile is already loaded.
  2. Extend the twin's idempotency hash set in `run-in-vm.sh` to include the AppArmor profile files so the regression (profile rewritten on every converged run) is guarded.
- **CI/CD impact:**
  - **Twin test:** The idempotency hash set change directly affects `make twin-test` — the `idempotency-hashes` criterion must now include the AppArmor profile checksums. Without this, the twin cannot detect the non-idempotent profile rewrite.
  - **Unit tests:** `tests/` bats stubs for `apparmor_parser` and `aa-status` may need updating if the sentinel logic changes the call pattern.
  - **Production path:** On Ubuntu 26.04 (the declared target), the `apparmor-profiles` package ships a podman profile, so the current sentinel never matches and the profile is rewritten on every run. This is outcome-idempotent but not action-idempotent, contradicting the docstring and `AGENTS.md:49`.
- **Acceptance criteria:**
  1. Per-binary sentinel: each binary's profile is checked independently (e.g., `aa-status --json | grep -q '"podman-userns"'`).
  2. The twin's hash set includes the AppArmor profile files.
  3. `make lint` passes.
  4. `make test` passes.
  5. `make twin-test` passes with the extended hash set.
- **Confidence:** 85 (High) — mechanism is well-understood; the fix requires careful implementation of the per-binary check.

---

### SPEC-DO-003: CH-INST-003 — Document or drop the four extra firewall ranges

- **Finding ID:** CH-INST-003
- **System(s) affected:** `setup-floci.sh` — UFW rules (lines 83–92) and container publish flags (lines 76–80)
- **Required change:**
  1. Either add inline comments explaining why UFW opens ports `6500:6599`, `9400:9499`, `2200:2299`, and `9169` when the container publishes none of them, OR remove the UFW rules.
  2. The `5100-5199` exclusion already has a gotcha entry in `AGENTS.md:45` explaining that sidecars bind host-side directly. The other four ranges need the same treatment.
- **CI/CD impact:**
  - **Security posture:** Open ports with no documented consumer are a finding every future security review will re-raise. This is a pipeline security concern — the CI pipeline should not deploy an installer that opens undocumented ports.
  - **Twin test:** If ports are removed, the twin's UFW verification may need updating.
  - **No functional change to CI** — this is a documentation/clarity fix.
- **Acceptance criteria:**
  1. Each of the four extra firewall ranges has an inline comment explaining its purpose, OR the ranges are removed from the UFW rules.
  2. If removed, the twin's UFW verification is updated accordingly.
  3. `make lint` passes.
  4. `make test` passes.
- **Confidence:** 90 (Critical) — static analysis confirms the asymmetry; the fix is straightforward.

---

### SPEC-DO-004: CH-INST-004 — Assert curl and openssl in Phase 1

- **Finding ID:** CH-INST-004
- **System(s) affected:** `setup-floci.sh` — Phase 1 preflight (lines 630–636) and Phase 3 apt-get install
- **Required change:**
  1. Add `curl` and `openssl` to Phase 1's command assertions (currently only `podman` and `uidmap` are checked/installed).
  2. Alternatively, add them to the `apt-get install` list in Phase 3.
- **CI/CD impact:**
  - **Direct:** On a minimal Ubuntu image (the target environment), the installer currently fails in Phase 6 (`verify_health` needs `curl`, `generate_presign_secret` needs `openssl`) after all mutating work is done. This is a reliability issue — the failure should occur early (Phase 1) rather than late (Phase 6).
  - **Twin test:** The Lima twin uses a full Ubuntu image that includes these tools, so the twin does not currently catch this. A minimal-image CI variant would.
  - **CI pipeline:** The current CI (`make lint`, `make test`) does not exercise the runtime path. This is a gap that the twin test partially covers, but a minimal-image test would be ideal.
- **Acceptance criteria:**
  1. `curl` and `openssl` are asserted in Phase 1 (or installed in Phase 3).
  2. The installer fails early with a clear message if either is missing.
  3. `make lint` passes.
  4. `make test` passes.
- **Confidence:** 90 (Critical) — static analysis confirms the missing preflight; the fix is trivial.

---

### SPEC-DO-005: CH-DEV-005 — Unify health budget (fresh install gets same 300s as resume)

- **Finding ID:** CH-DEV-005
- **System(s) affected:** `mock-server/dev-twin.sh` — `_health_check` (lines 304–315) and `_resume_health_check` (lines 503–521); budgets at lines 21–22 and 43–44
- **Required change:**
  1. Give the fresh-install path the same health budget as the resume path (300s via `DEV_RESUME_HEALTH_TRIES=150 × DEV_RESUME_HEALTH_SLEEP=2`).
  2. Give the fresh-install path the same `_reset_floci_service` fallback that the resume path has.
  3. Use `_resume_health_check` for both paths (it is already the more correct implementation), keeping distinct error strings.
- **CI/CD impact:**
  - **Dev twin reliability:** The AppArmor race is documented at 2–3 minutes and applies to first boot as much as to resume. A fresh `dev-up` on a cold QEMU arm64 boot can time out where a resume would recover. This change makes the dev twin more reliable in CI-like environments.
  - **No CI workflow change** — the dev twin is a local tool, not part of the CI pipeline.
- **Acceptance criteria:**
  1. Fresh install uses the same health budget as resume (300s).
  2. Fresh install uses the same `_reset_floci_service` fallback.
  3. `make lint` passes (shellcheck on `dev-twin.sh`).
- **Confidence:** 88 (High) — mechanism is well-understood; the fix is a unification of two already-correct implementations.

---

### SPEC-DO-006: CH-TWIN-001 — Verdict on precondition failure (machine-readable contract)

- **Finding ID:** CH-TWIN-001
- **System(s) affected:** `mock-server/run-test.sh` — `assert_preconditions` (lines 49–61), `main` (lines 526–559), `print_verdict` (lines 514–522)
- **Required change:**
  1. Route precondition failures through `FAIL_REASON` + `print_verdict` so that CI wrappers grepping for `TWIN:` always see a machine-readable verdict.
  2. Move the `assert_preconditions` call inside the guarded block in `main`, or have it set `FAIL_REASON` and return non-zero instead of calling `die` (which exits directly).
- **CI/CD impact:**
  - **Critical for CI integration:** Any CI wrapper that greps for `TWIN: PASS` or `TWIN: FAIL` currently sees nothing when preconditions fail (missing `limactl`, non-arm64 host, macOS < 13). The exit code is non-zero, but the machine-readable contract is broken.
  - **The `print_verdict` function (lines 514–522) is the contract.** It must be called on every failure path.
- **Acceptance criteria:**
  1. Precondition failures produce a `TWIN: FAIL: <reason>` message on stderr.
  2. `assert_preconditions` sets `FAIL_REASON` and returns non-zero instead of calling `die`.
  3. `main` calls `print_verdict` on the precondition failure path.
  4. `make lint` passes (shellcheck on `run-test.sh`).
- **Confidence:** 95 (Critical) — static analysis confirms the contract breach; the fix is well-scoped.

---

### SPEC-DO-007: CH-TWIN-003 — Replace or drop journal ordering check

- **Finding ID:** CH-TWIN-003
- **System(s) affected:** `mock-server/run-test.sh` — `run_reboot_test` (lines 394–402)
- **Required change:**
  1. Either replace the journal line-number comparison with activation-record matching (`Started`/`Listening` with timestamps), OR drop the journal comparison entirely and rely on the property assertions (`After=`/`Requires=`) plus `service_active` (lines 376–391), which are the real evidence.
  2. The current check compares the first `grep -n` line number of `podman.socket` against the first for `floci.service` in a single-boot journal. Journal line order is not activation order, and any earlier *mention* of the socket satisfies it regardless of actual start sequence.
- **CI/CD impact:**
  - **Twin test reliability:** The current check can produce false FAIL on log-format variance and false PASS without proving ordering. This affects the `--reboot-test` flag of `make twin-test`.
  - **Recommendation:** Drop the journal comparison. The property assertions at lines 376–391 (`After=podman.socket`, `Requires=podman.socket`, `is-active`) are the real evidence of correct Quadlet ordering. The journal comparison adds noise without signal.
- **Acceptance criteria:**
  1. The journal line-number comparison is either replaced with timestamp-based activation-record matching, or removed entirely.
  2. If removed, the `reboot-ordering` criterion in `validate_summary` is updated to rely solely on the property assertions.
  3. `make lint` passes.
  4. `make twin-test -- --reboot-test` passes.
- **Confidence:** 85 (High) — mechanism is well-understood; the fix is a simplification.

---

### SPEC-DO-008: CH-TWIN-005 — Document evidence-dir split

- **Finding ID:** CH-TWIN-005
- **System(s) affected:** `mock-server/run-test.sh` — `usage` (lines 36–38), `make_evidence_dir` (lines 110–117); `docs/design/digital-twin-testing-design.md`
- **Required change:**
  1. Document in `usage` and in `docs/design/digital-twin-testing-design.md` that `--evidence-dir` only relocates the final copy, not the 9p staging area.
  2. `HOST_EVIDENCE_MOUNT` and `STAGING` are hardcoded to `${HOST_HOME}/.cache/tianlu-twin/evidence` because that path is the 9p mount declared in the Lima template. The `--evidence-dir` flag only changes where the final sealed copy lands.
- **CI/CD impact:**
  - **Documentation only** — no functional change. CI wrappers that use `--evidence-dir` need to understand that the 9p staging path is fixed.
- **Acceptance criteria:**
  1. `usage` output explains the split: staging is fixed at `~/.cache/tianlu-twin/evidence`; `--evidence-dir` relocates the final copy.
  2. `docs/design/digital-twin-testing-design.md` documents the split.
  3. `make lint` passes.
- **Confidence:** 95 (Critical) — static analysis confirms the documentation gap.

---

### SPEC-DO-009: CH-TWIN-006 — Resolve --fresh/--keep semantics

- **Finding ID:** CH-TWIN-006
- **System(s) affected:** `mock-server/run-test.sh` — argument parsing (lines 70–78), `teardown` (lines 503–510), `usage` (line 37)
- **Required change:**
  1. Decide the intent: either `--fresh` implies teardown (destroy after run), or stop clearing `KEEP` when `--fresh` is set.
  2. Make `usage` match the actual behaviour.
  3. Fix the order-dependence: `--keep` after `--fresh` is currently ignored (lines 75–77) but `--fresh` after `--keep` wins.
- **CI/CD impact:**
  - **CI integration:** CI wrappers that use `--fresh` expecting the VM to be destroyed after the run will be surprised when it is left running. Conversely, CI wrappers that use `--keep` after `--fresh` expecting to preserve the VM will be surprised when it is destroyed.
  - **Recommendation:** `--fresh` should imply `--destroy` (create fresh, destroy after). `--keep` should be the default for local development. This matches the principle of least surprise for CI: a CI run should clean up after itself.
- **Acceptance criteria:**
  1. `--fresh` implies `--destroy` (VM is deleted after the run).
  2. `--keep` is the default (VM is preserved for local development).
  3. `--fresh` and `--keep` are mutually exclusive; the last one wins.
  4. `usage` output accurately describes the behaviour.
  5. `make lint` passes.
- **Confidence:** 95 (Critical) — static analysis confirms the semantic confusion.

---

### SPEC-DO-010: CH-LZ-004 — G1 must fail (not skip) when probe cannot be established; main exit non-zero on any SKIP among automated gates

- **Finding ID:** CH-LZ-004
- **System(s) affected:** `scripts/preflight-floci.sh` — `gate_g1_signatures` (lines 42–59), `skip` function (line 31), `main` (lines 119–128)
- **Required change:**
  1. G1 must call `fail` (not `skip`) when it cannot establish the probe (i.e., when `create-access-key` fails). An unestablished gate is not a passed gate.
  2. Distinguish "IAM unreachable" from "IAM reachable and permissive" in the failure message.
  3. `main` must exit non-zero on any SKIP among the automated gates (G1, G3), while leaving the manual-notes gates (G2, G4, G5) as SKIP.
- **CI/CD impact:**
  - **Critical for CI gating:** The preflight script is the gate that must pass before any `terraform apply`. If G1 silently SKIPs on the configuration it exists to police, the CI pipeline cannot enforce the "hard stop" that landing-zone §10.1 promises.
  - **CI integration pattern:** `scripts/preflight-floci.sh` should be run as a CI step before any Terraform stage. A non-zero exit must block the pipeline.
  - **Current CI gap:** `.github/workflows/test.yml` does not run `preflight-floci.sh`. This is a separate gap — the preflight requires a running Floci instance, which the current CI does not provide. The twin test (`make twin-test`) exercises the installer but does not currently run the preflight gates.
- **Acceptance criteria:**
  1. G1 calls `fail` (not `skip`) when `create-access-key` fails.
  2. The failure message distinguishes "IAM unreachable" from "IAM reachable and permissive".
  3. `main` exits non-zero when any automated gate (G1, G3) SKIPs.
  4. Manual-notes gates (G2, G4, G5) may still SKIP without affecting the exit code.
  5. `make lint` passes (shellcheck on `preflight-floci.sh`).
- **Confidence:** 95 (Critical) — static analysis confirms the gate bypass; the fix is well-scoped.

---

### SPEC-DO-011: CH-LZ-005 — Align backend region with tfvars region

- **Finding ID:** CH-LZ-005
- **System(s) affected:** `infra/_common/backend.hcl.example` (line 12), `infra/environments/dev.tfvars` (line 13), `setup-floci.sh` (line 54), `scripts/preflight-floci.sh` (line 25), `dev-twin.sh` (line 766)
- **Required change:**
  1. `backend.hcl.example` region must equal the tfvars region for the target environment.
  2. Unify the five region literals across the codebase to a single source of truth per environment.
  3. Per CH-META-001, this is a resource-visibility and ARN-correctness issue, not a signing issue.
- **CI/CD impact:**
  - **Terraform init:** The state bucket is created by stage 00 under the provider region and read by every other stage under the backend region. A mismatch means the backend points at a different region than the provider, which can cause silent state corruption or "bucket not found" errors.
  - **CI integration:** A CI pipeline that runs `terraform init` with `-backend-config=../../_common/backend.hcl` must have the backend region match the environment's provider region. This should be enforced by a lint check or a pre-init validation step.
- **Acceptance criteria:**
  1. `backend.hcl.example` region matches `dev.tfvars` region (both `eu-west-2` or a single canonical value).
  2. `setup-floci.sh` `FLOCI_DEFAULT_REGION` matches the target environment.
  3. `preflight-floci.sh` `REGION` matches the target environment.
  4. `dev-twin.sh` `dev_env` region matches the target environment.
  5. A single source of truth per environment is documented in landing-zone §4.1.
- **Confidence:** 92 (Critical) — static analysis confirms five divergent region literals.

---

### SPEC-DO-012: CH-LZ-006 — Reduce §6.10b to -backend-config=../../_common/backend.hcl + per-stage key

- **Finding ID:** CH-LZ-006
- **System(s) affected:** `docs/design/authentication-plan.md` §6.10b (lines 697–709); `infra/_common/backend.hcl.example`
- **Required change:**
  1. Reduce the §6.10b `terraform init` command to the two per-stage overrides:
     ```bash
     terraform init \
       -backend-config=../../_common/backend.hcl \
       -backend-config="key=dev/10-management-iam/terraform.tfstate"
     ```
  2. Remove the deprecated `force_path_style` and `endpoint` CLI arguments (superseded by `use_path_style` and `endpoints` map in the `.hcl` file).
  3. `backend.hcl.example` already uses the modern form — this change aligns the documentation with the existing template.
- **CI/CD impact:**
  - **Terraform init reliability:** The current §6.10b prescribes `-backend-config="endpoint=…"` which is superseded and `-backend-config="force_path_style=true"` which is deprecated and mutually exclusive with `use_path_style`. A CI pipeline following §6.10b would fail on modern Terraform versions.
  - **The `.hcl` file is the correct approach** because `endpoints` is a map, which `-backend-config="key=value"` cannot express.
- **Acceptance criteria:**
  1. §6.10b prescribes `-backend-config=../../_common/backend.hcl` + per-stage `key`.
  2. No deprecated `force_path_style` or `endpoint` CLI arguments remain in §6.10b.
  3. The `backend.hcl.example` template is the single source of truth for backend configuration.
- **Confidence:** 95 (Critical) — cited to Terraform S3 backend source code confirming deprecation.

---

### SPEC-DO-013: CH-LZ-007 — Add G3b for S3 conditional PutObject

- **Finding ID:** CH-LZ-007
- **System(s) affected:** `scripts/preflight-floci.sh` — gate set; `infra/_common/backend.hcl.example` (line 19); `docs/design/landing-zone-design.md` §9 (lines 375–376)
- **Required change:**
  1. Add gate G3b to `preflight-floci.sh`: `aws s3api put-object --if-none-match '*'` twice; the second must fail with `PreconditionFailed`.
  2. OR mark `use_lockfile` as unverified in §9 and `backend.hcl.example` and state that it must not be used until verified.
- **CI/CD impact:**
  - **State locking integrity:** S3-native locking (`use_lockfile = true`) uses `IfNoneMatch: "*"` on `PutObject`. If Floci's S3 does not honour this header, two concurrent `terraform apply` operations both acquire the lock and corrupt state. G3 currently verifies DynamoDB conditional writes only.
  - **CI gating:** G3b should be part of the preflight gate suite run before any Terraform stage. If it fails, the CI pipeline must block.
- **Acceptance criteria:**
  1. G3b is added to `preflight-floci.sh` as an automated gate, OR `use_lockfile` is explicitly marked unverified in §9 and `backend.hcl.example`.
  2. If added as a gate, G3b must fail (not skip) when the probe cannot be established (per CH-LZ-004).
  3. `make lint` passes.
- **Confidence:** 90 (Critical) — cited to Terraform S3 backend source code confirming the `IfNoneMatch` mechanism.

---

### SPEC-DO-014: CH-LZ-008 — Add lint check that every infra/live/*/providers.tf matches _common/providers.tf

- **Finding ID:** CH-LZ-008
- **System(s) affected:** `infra/live/10-management-iam/providers.tf` (lines 32–36, 39–51); `infra/_common/providers.tf` (lines 45–51); CI lint infrastructure
- **Required change:**
  1. Restore the governance tag trio (`Project`, `Environment`, `ManagedBy`) in stage 10's provider (currently empty `merge({}, var.default_tags)`).
  2. Restore `sns` and `sqs` in stage 10's `endpoints` block (currently dropped relative to the template).
  3. Add a lint check (shell script or Makefile target) that verifies every `infra/live/*/providers.tf` matches `_common/providers.tf` in its structural elements (provider block, endpoints, default_tags merge).
- **CI/CD impact:**
  - **New CI check:** A lint check must be added to `make lint` (or a new `make lint-infra` target) that diffs each stage's `providers.tf` against the template. This prevents the drift that caused this finding.
  - **CI workflow:** `.github/workflows/test.yml` should run this check.
  - **Pre-commit hook:** `scripts/pre-commit` should run this check.
- **Acceptance criteria:**
  1. Stage 10's `providers.tf` governance tags match the template (trio present in `merge`).
  2. Stage 10's `providers.tf` endpoints match the template (includes `sns` and `sqs`).
  3. A lint check exists that verifies all `infra/live/*/providers.tf` match `_common/providers.tf`.
  4. The lint check is integrated into `make lint` (or a new `make lint-infra` target).
  5. `make lint` passes.
- **Confidence:** 98 (Critical) — static analysis confirms the drift; the fix includes a procedural safeguard.

---

### SPEC-DO-015: CH-LZ-009 — Unify provider constraints across all stages

- **Finding ID:** CH-LZ-009
- **System(s) affected:** `infra/_common/versions.tf` (lines 15–18); `infra/live/10-management-iam/providers.tf` (lines 5–8); `infra/live/00-backend-bootstrap/main.tf` (lines 16–19)
- **Required change:**
  1. Decide the floor once: `>= 6.56.0, < 7.0.0` (if EKS v21 requires it).
  2. Apply it in `_common/versions.tf`.
  3. Propagate to all stages.
  4. Delete the unresolved note at `versions.tf:13-14`.
  5. Record the decision in landing-zone §7.
- **CI/CD impact:**
  - **Terraform init reliability:** Three different constraints for one provider across three root modules, and the stage-10 one has no upper bound — a future 7.x major would be selected automatically, contradicting the "keep pins identical across stages" convention.
  - **CI integration:** A CI pipeline that runs `terraform init` across stages would encounter constraint conflicts or silently select different provider versions.
- **Acceptance criteria:**
  1. `_common/versions.tf` has a single canonical constraint (e.g., `>= 6.56.0, < 7.0.0`).
  2. All stage root modules use the same constraint.
  3. The unresolved note at `versions.tf:13-14` is removed.
  4. The decision is recorded in landing-zone §7.
- **Confidence:** 95 (Critical) — static analysis confirms three divergent constraints.

---

### SPEC-DO-016: CH-LZ-010 — Omit key from providers.tf

- **Finding ID:** CH-LZ-010
- **System(s) affected:** `infra/live/10-management-iam/providers.tf` (line 14)
- **Required change:**
  1. Either omit `key` entirely from the `backend "s3"` block (forcing the `-backend-config="key=…"` override), OR default it to `dev/10-management-iam/terraform.tfstate`.
  2. Omitting is safer: a missing required value fails loudly (`terraform init` errors), a wrong default fails silently (state collision on promotion).
- **CI/CD impact:**
  - **Terraform init safety:** An `init` without the `-backend-config="key=…"` override currently silently writes state to an unprefixed key. Promotion to uat/prod then collides on the same object — the failure the per-environment key scheme exists to prevent.
  - **CI integration:** A CI pipeline that runs `terraform init` must always pass the `-backend-config="key=…"` override. Omitting the default `key` from the provider block makes this mandatory rather than optional.
- **Acceptance criteria:**
  1. `key` is either omitted from the `backend "s3"` block, or defaulted to `dev/10-management-iam/terraform.tfstate`.
  2. If omitted, `terraform init` without `-backend-config="key=…"` fails with a clear error.
  3. The `backend.hcl.example` template documents the required override.
- **Confidence:** 95 (Critical) — static analysis confirms the missing environment prefix.

---

### SPEC-DO-017: CH-LZ-011 — Add environment validation variable

- **Finding ID:** CH-LZ-011
- **System(s) affected:** `infra/_common/providers.tf` — `default_tags` merge (lines 46–50), `variable "environment"` (line 10)
- **Required change:**
  1. Reverse the `merge` order so governance tags cannot be overridden: `merge(var.default_tags, {Project = "tianlu", Environment = var.environment, ManagedBy = "terraform"})`.
  2. Add a `validation` block to `variable "environment"` constraining values to `["dev", "uat", "prod"]`.
- **CI/CD impact:**
  - **Terraform plan safety:** The current merge order (`merge({governance}, var.default_tags)`) lets a tfvars file silently override `Environment`. This is how the original `Environment = "development"` override occurred — silently, with no plan warning.
  - **CI integration:** The validation block makes invalid environment values fail at `terraform plan` time rather than silently producing wrong tags.
- **Acceptance criteria:**
  1. `merge` order is reversed: `var.default_tags` first, governance tags second.
  2. `variable "environment"` has a `validation` block constraining to `["dev", "uat", "prod"]`.
  3. `terraform validate` passes for all stages.
- **Confidence:** 95 (Critical) — static analysis confirms the merge-order hazard.

---

## Cross-Cutting CI/CD Concerns

### 1. Dependabot Configuration (Missing)

**Finding:** No `.github/dependabot.yml` exists. The `github-actions` skill requires Dependabot configured for action version updates.

**Recommendation:** Add `.github/dependabot.yml`:
```yaml
version: 2
updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
    groups:
      actions:
        patterns:
          - "*"
```

**CI/CD impact:** Without Dependabot, GitHub Actions workflow dependencies (`actions/checkout@v7`, etc.) are not automatically updated. This is a supply-chain security gap.

**Severity:** Medium (advisory, not blocking for psc-0003).

### 2. CODEOWNERS Coverage (Missing)

**Finding:** No `CODEOWNERS` file exists. The `github-actions` skill requires workflow files covered by CODEOWNERS for change review.

**Recommendation:** Add a `CODEOWNERS` file covering `.github/workflows/` and `infra/` directories.

**CI/CD impact:** Without CODEOWNERS, workflow changes can be merged without review from the DevOps/infra team.

**Severity:** Low (advisory, not blocking for psc-0003).

### 3. Preflight Gates in CI (Gap)

**Finding:** `.github/workflows/test.yml` runs `make lint` and `make test` only. It does not run `scripts/preflight-floci.sh` because the preflight requires a running Floci instance.

**Recommendation:** The preflight gates are exercised by `make twin-test` (which runs the full installer lifecycle in a Lima VM). The twin test is a local pre-push gate, not a CI gate. This is documented in `AGENTS.md` and `docs/testing-guide.md`. No change required for psc-0003, but note that CH-LZ-004's fix (G1 must fail, not skip) makes the preflight script safe to run in any context — it will fail loudly rather than silently skipping.

**Severity:** Informational.

### 4. Action Pinning (Current State)

**Finding:** `.github/workflows/test.yml` uses `actions/checkout@v7` — pinned to a major version tag. Per the `github-actions` skill, this is acceptable: major version tags float to the latest minor/patch within the major version, providing automatic security and bug fixes without breaking changes.

**Assessment:** PASS — no change required.

### 5. Workflow Concurrency (Missing)

**Finding:** `.github/workflows/test.yml` has no `concurrency` group. Multiple pushes to the same branch/PR could run concurrent workflows.

**Recommendation:** Add concurrency control:
```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```

**CI/CD impact:** Without concurrency control, multiple rapid pushes can queue redundant workflow runs, wasting runner minutes.

**Severity:** Low (advisory, not blocking for psc-0003).

---

## Verdict

**VERDICT: CONDITIONAL PASS**

**SEVERITY: 7** (CH-LZ-004 — G1 silent-SKIP on the configuration it exists to police; this is the highest-severity finding in the DevOps scope because it directly undermines the CI gating contract)

**FINDINGS:**
- [7] `scripts/preflight-floci.sh:46-48` — G1 calls `skip` when `create-access-key` fails; `skip` does not set `FAILED`; `main` exits 0. The gate the design calls a "hard stop" reports success on precisely the configuration it exists to police. (CH-LZ-004)
- [6] `mock-server/run-test.sh:539` — `assert_preconditions` calls `die` which exits directly without `print_verdict`. CI wrappers grepping for `TWIN:` see nothing on precondition failure. (CH-TWIN-001)
- [6] `infra/live/10-management-iam/providers.tf:32-36` — Governance tag trio deleted from stage provider; `endpoints` block drops `sns`/`sqs`. Template and stage have diverged with no detection mechanism. (CH-LZ-008)
- [6] `infra/_common/versions.tf:15-18` vs `infra/live/10-management-iam/providers.tf:5-8` — Three different provider constraints; stage-10 has no upper bound. (CH-LZ-009)
- [5] `infra/live/10-management-iam/providers.tf:14` — Backend `key` omits `<env>/` prefix; silent state collision on promotion. (CH-LZ-010)
- [5] `infra/_common/providers.tf:46-50` — `merge` order lets `var.default_tags` override governance tags; no `environment` validation. (CH-LZ-011)
- [5] `infra/_common/backend.hcl.example:12` vs `infra/environments/dev.tfvars:13` — Backend region (`us-east-1`) diverges from provider region (`eu-west-2`); four other region literals also diverge. (CH-LZ-005)
- [5] `docs/design/authentication-plan.md §6.10b:697-709` — Prescribes deprecated `force_path_style` and superseded `endpoint` CLI arguments. (CH-LZ-006)
- [5] `scripts/preflight-floci.sh` — No G3b gate for S3 conditional `PutObject`; `use_lockfile` alternative is unverified. (CH-LZ-007)
- [4] `setup-floci.sh:916-926` — `verify_health` retries only `000`; `5xx` during JVM warmup causes hard failure. (CH-INST-001)
- [4] `setup-floci.sh:451-500` — AppArmor sentinel never matches on Ubuntu 26.04; profile rewritten on every converged run. (CH-INST-002)
- [4] `mock-server/dev-twin.sh:304-315` — Fresh install has 120s health budget vs resume's 300s; no `_reset_floci_service` fallback. (CH-DEV-005)
- [4] `mock-server/run-test.sh:394-402` — Journal line-number comparison is not activation-order proof; can produce false PASS and false FAIL. (CH-TWIN-003)
- [3] `mock-server/run-test.sh:70-78` — `--fresh` and `--keep` are not opposites; order-dependent; `usage` is misleading. (CH-TWIN-006)
- [3] `mock-server/run-test.sh:36-38` — `--evidence-dir` only relocates final copy; 9p staging is fixed; not documented. (CH-TWIN-005)
- [3] `setup-floci.sh:83-92` — Four firewall ranges opened with no documented consumer. (CH-INST-003)
- [3] `setup-floci.sh:630-636` — `curl` and `openssl` not asserted in Phase 1; installer fails late on minimal images. (CH-INST-004)

**ROUTING:** code-architect (all findings require implementation in the target files; no CI workflow changes are required for psc-0003 beyond the lint check addition in SPEC-DO-014)

**RATIONALE:** All 17 findings in the DevOps scope are well-understood and have clear fixes. The CONDITIONAL PASS reflects that none of the findings are CI/CD-blocking in themselves (the CI pipeline is not broken), but several (CH-LZ-004, CH-TWIN-001, CH-LZ-008) represent significant reliability gaps that must be addressed before the pipeline can be trusted to gate production changes. The cross-cutting concerns (Dependabot, CODEOWNERS, concurrency) are advisory and do not block this ticket.

## References

| Claim / Decision | Source | Verification |
|-----------------|--------|-------------|
| GitHub Actions workflow syntax and security hardening | [Source: https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions, accessed 2026-07-30] | Official GitHub Actions documentation |
| Action pinning best practices (major version tags acceptable) | [Skill: github-actions, §Action Security] | Project skill file |
| Dependabot for GitHub Actions | [Source: https://docs.github.com/en/code-security/dependabot/dependabot-version-updates, accessed 2026-07-30] | Official GitHub documentation |
| Terraform S3 backend `force_path_style` deprecation | [Source: hashicorp/terraform `internal/backend/remote-state/s3/backend.go`, accessed 2026-07-30] | Cited in psc-adv-0017 §Verification |
| Terraform S3 backend `use_lockfile` conditional PutObject | [Source: hashicorp/terraform `internal/backend/remote-state/s3/client.go`, accessed 2026-07-30] | Cited in psc-adv-0017 §Verification |
| IAM absent-key evaluation (`StringNotEquals` matches null) | [Source: https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_variables.html, accessed 2026-07-30] | Official AWS IAM documentation |
| OpenSSF Scorecard for pipeline security assessment | [Source: https://github.com/ossf/scorecard, accessed 2026-07-30] | OpenSSF project |
| OWASP CI/CD Security Cheat Sheet | [Source: https://cheatsheetseries.owasp.org/cheatsheets/CI_CD_Security_Cheat_Sheet.html, accessed 2026-07-30] | OWASP Cheat Sheet Series |
