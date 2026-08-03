# A2 Challenger: DevOps Specialist — psc-0003

| Field | Value |
|-------|-------|
| Model | glm-5.2 |
| Phase | A2 (Dual-Model Challenge) |
| Primary Output | A1-DO requirements analysis: 17 SPEC-DO findings (installer, dev twin, test harness, preflight, Terraform infra) + 5 cross-cutting CI/CD concerns + CONDITIONAL PASS verdict, severity 7, routed to code-architect |
| Source advisory | psc-adv-0017-challenge-review |
| Challenger read | A1-DO doc (487 lines), psc-adv-0017 (1471 lines), `.github/workflows/test.yml`, `.github/workflows/opencode.yml`, `Makefile`, `github-actions` skill, `ci-cd-pipeline` skill |

## Agreements

The primary DO analysis is, on the whole, technically accurate and well-scoped. I agree with the
following, and they do not need re-litigation here:

1. **SPEC-DO-010 (CH-LZ-004) is correctly identified as the highest-severity DevOps finding.**
   A gate that reports success on the configuration it exists to police is the textbook
   "unfalsifiable control" failure. The advisory's own lessons-learned row #9 names this class.
   Confidence 95 is well-justified; the fix (fail-not-skip, non-zero exit on automated-gate SKIP)
   is the right remedy. *(Confidence in agreement: 95)*

2. **SPEC-DO-006 (CH-TWIN-001) — machine-readable verdict contract breach.** The CI integration
   argument is correct: any wrapper grepping `TWIN:` sees nothing on precondition failure. The fix
   (route through `FAIL_REASON` + `print_verdict`) is the right shape. *(Confidence: 95)*

3. **SPEC-DO-014 (CH-LZ-008) — restore governance tags + add lint check.** The drift detection gap
   is real (no `make lint` target covers `infra/`), and the proposed lint check is the correct
   procedural safeguard. This is the one finding where the primary correctly identifies a *missing
   CI capability* rather than just a code defect. *(Confidence: 98)*

4. **SPEC-DO-015/016/017 (CH-LZ-009/010/011) — Terraform backend safety.** Unbounded provider
   constraint, missing env prefix in backend key, and merge-order hazard are all correctly
   characterised as silent-failure modes. The "omit `key` so it fails loudly" recommendation in
   SPEC-DO-016 is the right call (fail-loud > fail-silent). *(Confidence: 92–95)*

5. **SPEC-DO-001 (CH-INST-001) — retry 5xx, fail-fast on 4xx, report last code.** The retry policy
   is correctly bounded (5xx retried, 4xx fatal). The diagnostic improvement (last code in
   timeout message) is correct. *(Confidence: 88)*

6. **The verdict of CONDITIONAL PASS is defensible** — none of the 17 findings break the existing
   CI pipeline outright, and the routing to code-architect is correct since the fixes are
   implementation work, not CI workflow authoring. *(Confidence: 90)*

## Disagreements

### D-1: The primary under-weights `opencode.yml` as a CI/CD attack surface — it is NOT covered by any SPEC-DO finding, and the cross-cutting concerns miss it entirely

- **Confidence: 90**
- **Evidence:** `.github/workflows/opencode.yml` triggers on `issue_comment` and
  `pull_request_review_comment` — both are **untrusted-input events** from forks and arbitrary
  commenters. It requests `id-token: write` (OIDC token minting capability) and runs
  `anomalyco/opencode/github@latest` (a floating tag, not a SHA pin) with `OLLAMA_API_KEY`
  injected. The `github-actions` skill security checklist explicitly requires: (a) third-party
  actions pinned to full-length commit SHA, (b) `pull_request_target` avoided unless necessary
  and never checking out untrusted code, (c) untrusted input never interpolated into `run:` scripts.
  This workflow violates (a) and arguably (b)-equivalent (comment-triggered code execution).
- **Why the primary missed it:** The primary's scope summary lists "17 findings … within the
  DevOps Specialist's domain" and treats `opencode.yml` as out of scope. But the challenge advisory
  is the *source* — it does not enumerate `opencode.yml` either. The DevOps Specialist's domain
  explicitly includes "pipeline security" (per the role definition and the `github-actions` skill).
  A comment-triggered workflow with `id-token: write` and a floating third-party action tag is a
  pipeline-security finding of the highest order, and the primary should have surfaced it as a
  one-sided finding even if the advisory did not.
- **Specific scenario:** A malicious commenter posts `/oc` on any PR. The workflow mints an OIDC
  token (`id-token: write`) and hands `OLLAMA_API_KEY` to a `@latest`-pinned action. If
  `anomalyco/opencode` is ever compromised or its `latest` tag is moved to a malicious ref, the
  attacker exfiltrates `OLLAMA_API_KEY` and obtains an OIDC token minted with the repo's identity.
  Depending on the cloud roles that trust that OIDC provider, this is lateral-movement-to-cloud.
- **Severity I would assign: 8** (higher than the primary's top severity of 7).

### D-2: The Dependabot recommendation (cross-cutting #1) is incomplete — it omits the ecosystems that actually matter for this repo

- **Confidence: 85**
- **Evidence:** The primary recommends only `package-ecosystem: "github-actions"`. But this repo
  has no `package.json`/`go.mod`/`requirements.txt` application dependencies — its real supply-chain
  surface is **container images** (`docker.io/floci/floci:1.5.33-compat`, pinned per AGENTS.md) and
  **Lima templates** (`floci-twin.yaml`, `floci-dev.yaml` reference image tags). Dependabot's
  `docker` ecosystem would track the Floci image tag. The primary also does not mention that the
  `github-actions` ecosystem is the *least* urgent here because `test.yml` uses only
  `actions/checkout@v7` (a first-party action with a moving major tag, which the primary correctly
  assesses as acceptable in cross-cutting #4). The real gap is the unpinned `@latest` in
  `opencode.yml`, which Dependabot's `github-actions` ecosystem **will not downgrade to a SHA** —
  Dependabot opens PRs that *bump* floating tags, it does not *pin* them. So the recommendation
  addresses the wrong threat.
- **Corrected recommendation:** (1) Pin `anomalyco/opencode/github@latest` to a full SHA in
  `opencode.yml` (manual, not Dependabot). (2) Add `docker` ecosystem to Dependabot for the Floci
  image tag drift. (3) Then add `github-actions` ecosystem for the already-pinned actions.

### D-3: SPEC-DO-009 (`--fresh`/`--keep`) recommendation is over-specified and self-contradictory

- **Confidence: 80**
- **Evidence:** Acceptance criterion 3 states "`--fresh` and `--keep` are mutually exclusive; the
  last one wins." Mutual exclusivity and "last one wins" are contradictory — mutually exclusive
  flags reject combination; "last wins" accepts it with order dependence (the exact bug being
  fixed). The advisory's own finding (CH-TWIN-006) describes the order-dependence as the defect.
  The primary should pick one model: either reject the combination (`if [[ $FRESH && $KEEP ]]; die
  "mutually exclusive"`) or make `--fresh` imply `--destroy` and make `--keep` a no-op when
  `--fresh` is set (clear precedence, no order dependence). "Last wins" perpetuates the order bug.
- **Additionally:** Acceptance criterion 2 ("`--keep` is the default") conflicts with the existing
  `Makefile:30` default `TWIN_FLAGS ?= --fresh --reboot-test`. Making `--keep` the default would
  change the `make twin-test` contract documented in AGENTS.md. The primary does not flag this
  downstream impact.

### D-4: SPEC-DO-014's lint check is specified as a structural diff but the right tool is `terraform validate` + `tfscan`/`checkov`, not a shell diff

- **Confidence: 75**
- **Evidence:** The primary recommends "a lint check (shell script or Makefile target) that
  verifies every `infra/live/*/providers.tf` matches `_common/providers.tf` in its structural
  elements (provider block, endpoints, default_tags merge)." A shell-based structural diff of HCL
  is brittle (whitespace, block ordering, comments). The authoritative check is `terraform
  validate` (catches schema errors) plus a policy tool (`checkov` or `tfsec`) with a rule for
  required `default_tags`. The CI does not currently install Terraform at all (verified: `test.yml`
  installs only `shellcheck` and `bats`), so even `terraform validate` would require a new CI
  capability. The primary frames this as "add to `make lint`" but `make lint` is shellcheck+bash-n
  only — it has no HCL parser. This is a hidden CI capability gap the primary glosses over.
- **Recommendation:** Add a `make lint-infra` target running `terraform fmt -check` + `terraform
  validate` (requires Terraform in CI) and optionally `checkov -d infra/`. Wire it into
  `scripts/pre-commit` and `.github/workflows/test.yml` as a separate job. The primary's "or a new
  `make lint-infra` target" parenthetical acknowledges this but buries it.

## One-Sided Findings

### O-1: `test.yml` lacks `permissions:` block — GITHUB_TOKEN defaults to read/write

- **Confidence: 92**
- **Evidence:** `.github/workflows/test.yml` has no top-level or job-level `permissions:` key
  (verified by grep — only `opencode.yml` sets permissions). Per the `github-actions` skill security
  checklist, the GITHUB_TOKEN defaults to broad read/write. For a lint+unit job that only needs to
  read code and run tests, the token should be `permissions: { contents: read }` at minimum. The
  primary's cross-cutting #4 ("Action Pinning — PASS") reviews `test.yml` and says nothing about
  permissions. This is a standard hardening gap the DevOps Specialist domain covers.
- **Specific scenario:** A compromised `shellcheck` or `bats` step (e.g., via a supply-chain
  compromise of the `apt-get install` packages, or a `run:` script injection from a future
  untrusted input added to the workflow) would have a write-capable GITHUB_TOKEN and could push to
  the repo or modify PRs. Least-privilege would contain the blast radius to `contents: read`.
- **Severity: 5** (advisory but should be fixed in this ticket since the primary is already
  reviewing `test.yml`).

### O-2: `opencode.yml` uses `actions/checkout@v7` with `persist-credentials: false` — good — but `id-token: write` + comment trigger + `@latest` action is an unmitigated injection vector

- **Confidence: 88**
- **Evidence:** This overlaps D-1 but is a distinct, specific gap: the comment body is the trigger
  (`contains(github.event.comment.body, ' /oc')`), and the action runs on that event with
  `id-token: write`. Even with `persist-credentials: false` on checkout, the OIDC token is
  available to the `@latest` action's code. The `github-actions` skill states `pull_request_target`
  should be avoided and `workflow_run` used for privilege separation; the comment-trigger pattern is
  the same risk class — untrusted event → elevated-token job. There is no environment protection,
  no required-reviewer gate, and the action is not pinned to a SHA.
- **Severity: 8.**

### O-3: No `concurrency:` on `opencode.yml` — concurrent `/oc` comments spawn parallel agent runs

- **Confidence: 85**
- **Evidence:** `opencode.yml` has no `concurrency:` group. Two reviewers posting `/oc` on the same
  PR spawn two parallel `ubuntu-latest` jobs, both with `id-token: write`, both calling the LLM
  API with the same `OLLAMA_API_KEY`. The primary's cross-cutting #5 notes the missing concurrency
  on `test.yml` (Low severity) but does not extend the analysis to `opencode.yml`, which is the
  more expensive and more dangerous workflow to run concurrently (LLM API cost + token minting).
- **Severity: 4** (cost + parallel OIDC minting).

### O-4: `make lint` does not cover `scripts/preflight-floci.sh` or any `infra/` Terraform

- **Confidence: 90**
- **Evidence:** `Makefile:39` lints `$(SCRIPT) $(STUB) $(MOCK_SHELLS) $(MOCK_STUB) $(MOCK_SUDO)
  $(HOOK) $(HELP_SCRIPT)` — none of which is `scripts/preflight-floci.sh` or any `.tf`/`.hcl` file.
  SPEC-DO-010 (CH-LZ-004 fix) requires "shellcheck on `preflight-floci.sh`" as acceptance criterion
  5, but `make lint` does not run it. So the primary's own acceptance criteria reference a lint
  target that does not exist for the file being fixed. This is an internal inconsistency: the
  primary prescribes `make lint` passes for `preflight-floci.sh` without noting that `preflight-floci.sh`
  is not in the lint scope today. The implementer will either skip the check (defeating the
  criterion) or expand `make lint` (an undocumented scope change).
- **Recommendation:** Add `scripts/preflight-floci.sh` to the `MOCK_SHELLS` or a new lint variable,
  and call this out in the SPEC-DO-010 acceptance criteria. *(Severity: 5)*

### O-5: No CI job validates that `infra/_common/backend.hcl.example` and `infra/live/*/providers.tf` are syntactically valid HCL

- **Confidence: 82**
- **Evidence:** The CI (`test.yml`) installs only `shellcheck` and `bats`. There is no `terraform`
  install step, no `terraform fmt -check`, no `terraform validate`. SPEC-DO-014, 015, 016, 017 all
  prescribe changes to `.tf`/`.hcl` files and list `terraform validate` or `make lint` as
  acceptance criteria, but neither capability exists in CI. The primary notes this for SPEC-DO-014
  ("The CI workflow should run this check") but does not recognise it as a *systematic* gap
  affecting four of its own findings. Without a Terraform validation step in CI, the merge of
  SPEC-DO-014–017 fixes cannot be gated — the acceptance criteria are unenforceable in the current
  pipeline.
- **Recommendation:** Add a `terraform-validate` job to `test.yml` that installs Terraform, runs
  `terraform fmt -check -recursive` and `terraform -chdir=infra/live/<stage> validate` for each
  stage. *(Severity: 6)*

### O-6: CH-TWIN-002 (sidecar-delta not in mandatory array) is dropped from the DevOps scope with no rationale

- **Confidence: 80**
- **Evidence:** The advisory lists CH-TWIN-002 ("Host never validates the sidecar result; the
  special case is unreachable") under subsystem D. The primary's scope summary table lists only
  "CH-TWIN-001, 003, 005, 006" for the test harness — CH-TWIN-002 is silently omitted. There is no
  "Disagreements" or "Out of scope" section explaining why. CH-TWIN-002 is a test-harness
  reliability gap (a special case that can never fire, leaving a latent false-pass path) squarely
  in the DevOps domain. Even if the primary judged it lower priority, omitting it without comment
  means the code-architect will not receive a SPEC for it.
- **Recommendation:** Either add a SPEC-DO for CH-TWIN-002 (add `sidecar-delta` to `mandatory` or
  delete the dead special case) or explicitly document it as deferred. *(Severity: 4)*

### O-7: CH-TWIN-004 and CH-TWIN-007 are also dropped without rationale

- **Confidence: 78**
- **Evidence:** Same pattern as O-6. CH-TWIN-004 (stale-sentinel cleanup targets wrong directory)
  and CH-TWIN-007 (two robustness gaps: `wait` on empty PID yields 127, `HOST_HOME` falls back to
  a username) are in the advisory under subsystem D but absent from the primary's scope. CH-TWIN-007
  item 2 (`HOST_HOME` falls back to `id -un`, a username, where a path is required) is a real
  silent-failure path: every derived evidence path becomes relative and lands in the CWD. The
  primary's own SPEC-DO-006 (verdict contract) depends on `print_verdict` writing to an evidence
  dir — if `HOST_HOME` is wrong, the evidence bundle is mislocated. These are small but they are
  DevOps-domain findings the primary silently dropped.
- **Recommendation:** Add SPEC-DO entries or document deferral. *(Severity: 3)*

### O-8: CH-DEV-001 through CH-DEV-004 and CH-DEV-006 are dropped — only CH-DEV-005 is kept

- **Confidence: 80**
- **Evidence:** The primary's scope table lists only "CH-DEV-005" for `dev-twin.sh`. The advisory
  contains six CH-DEV findings. CH-DEV-003 (`dev_disk_exists` conflates "absent" with "query
  failed") is a medium-severity finding where a transient `limactl` failure silently skips a
  confirmed disk delete — a data-safety issue. CH-DEV-004 (configurable `DEV_DISK_NAME` but
  hardcoded mount path) silently breaks `verify_disk_mount`, the mode-1777 assertion, and the
  systemd `ExecCondition`. These are reliability gaps in a tool the primary itself acknowledges is
  part of the CI-adjacent testing harness (`make dev-*`). The primary gives no rationale for the
  5-of-6 cut.
- **Recommendation:** At minimum, surface CH-DEV-003 (data safety) and CH-DEV-004 (silent breakage
  on a documented override). *(Severity: 5 for CH-DEV-003, 4 for CH-DEV-004)*

### O-9: No assessment of deployment safety / rollback for the Terraform stages

- **Confidence: 75**
- **Evidence:** The DevOps Specialist domain per the role definition includes "deployment
  strategies" and "deployment rollback gaps." The `infra/` project has stages 00→10→20→30→40 with
  `terraform apply` per stage and no documented rollback or `terraform destroy` ordering. The
  advisory's CH-LZ-001 notes `terraform destroy` on stage 10 *fails* due to the
  `DenyAllExceptBoundary` defect. The primary covers CH-LZ-001's fix (governance tags, provider
  drift) but does not assess the *deployment-safety* implication: there is no `terraform plan`
  review gate, no `apply` confirmation, no state-import/rollback runbook for the landing zone. The
  `reliability-scalability` skill (deployment safety: expand-migrate-contract, canary, reversible
  deploys) is in the role's skill load list but is not applied. This is a deployment-safety
  consideration not identified.
- **Severity: 5** (advisory; the landing zone is educational, but the DevOps Specialist should at
  minimum flag that no reversible-deploy strategy exists for `infra/`).

### O-10: Self-audit checklist is largely "N/A" — the DevOps role can do better

- **Confidence: 70**
- **Evidence:** The primary's self-audit checklist marks 10 of 15 rows "N/A" with "Not applicable
  to CI/CD pipeline design." Several are applicable: "No magic numbers in doc examples" applies to
  the Terraform examples in SPEC-DO-012/017; "Buffer safety" applies to shell array handling in
  the test-harness findings (CH-AUTH-008/009, which the advisory explicitly ties to `IFS`
  splitting); "Reserved/padding fields handled" is N/A but "Module boundary" is not — the
  `infra/live/*` vs `_common/` boundary is exactly a module-boundary question (CH-LZ-008/009).
  The self-audit is perfunctory. The `self-audit-checklist` skill requires the checklist be
  completed explicitly; "N/A" with no reasoning is not the same as "checked and not applicable."
- **Severity: 3** (process; does not block the ticket but undermines the audit trail).

## Recommendations

1. **Add SPEC-DO-018 (new):** Pin `anomalyco/opencode/github@latest` in `opencode.yml` to a full
   SHA, add an `environment:` with required reviewers (or restrict the `if:` to
   `github.event.issue.pull_request.user.login == github.repository_owner`), and reduce
   `permissions` to the minimum the opencode action actually needs. This is the highest-severity
   pipeline-security gap in the repo and the primary did not surface it. *(Confidence: 90)*

2. **Add SPEC-DO-019 (new):** Add `permissions: { contents: read }` to `test.yml` (top-level or
   job-level). One-line hardening; the primary reviewed `test.yml` and missed it. *(Confidence: 92)*

3. **Add SPEC-DO-020 (new):** Add `concurrency:` to `opencode.yml` grouped by PR/comment thread,
   `cancel-in-progress: true`. Prevents parallel LLM spend and parallel OIDC minting. *(Confidence:
   85)*

4. **Revise cross-cutting #1 (Dependabot):** Add the `docker` ecosystem (for the Floci image tag)
   and explicitly state that Dependabot will *not* pin `@latest` — that is a manual, one-time fix.
   *(Confidence: 85)*

5. **Revise SPEC-DO-009:** Pick one model (mutual exclusion *or* `--fresh` implies `--destroy`),
   not "last one wins." Reconcile with `Makefile:30` default `TWIN_FLAGS`. *(Confidence: 80)*

6. **Revise SPEC-DO-014:** Specify `terraform fmt -check` + `terraform validate` (or `checkov`)
   as the lint mechanism, not a shell structural diff. Acknowledge the new CI capability required
   (Terraform install in `test.yml`). *(Confidence: 75)*

7. **Add SPEC-DO-021 (new):** Add a `terraform-validate` job to `.github/workflows/test.yml`
   covering `infra/`. Without this, the acceptance criteria of SPEC-DO-014/015/016/017 are
   unenforceable in CI. *(Confidence: 82)*

8. **Add `scripts/preflight-floci.sh` to `make lint` scope** and correct SPEC-DO-010 acceptance
   criterion 5, which references a lint pass on a file not in the lint set. *(Confidence: 90)*

9. **Add SPEC-DO entries for the dropped findings:** CH-TWIN-002, CH-TWIN-004, CH-TWIN-007,
   CH-DEV-003, CH-DEV-004, CH-DEV-006. If any are deferred, state it explicitly rather than
   silently omitting. *(Confidence: 78–80)*

10. **Assess deployment-safety / reversibility for `infra/`** (rollback ordering, `plan` review
    gate, state-import runbook). At minimum flag it as an open item in the gaps register.
    *(Confidence: 75)*

11. **Re-do the self-audit checklist** with per-row reasoning rather than blanket "N/A." Apply
    "module boundary" to `infra/live/*` vs `_common/`, and "no magic numbers" to the Terraform
    examples. *(Confidence: 70)*

## Verdict

**CONDITIONAL PASS**

The primary's 17 SPEC-DO findings are technically sound and their fixes are correctly specified.
The CONDITIONAL PASS verdict and severity-7 top line are defensible. However, the analysis has
three systemic gaps that must be addressed before the ticket is routed:

1. **The `opencode.yml` pipeline-security gap (D-1/O-2) is the highest-severity finding in the
   repo's CI/CD surface and was entirely missed.** A comment-triggered workflow with `id-token:
   write` and a floating `@latest` action is a textbook OWASP CI/CD Top-10 vector, and the
   `github-actions` skill explicitly requires SHA pinning and privilege separation for this
   pattern. This alone would not justify REJECTED (the advisory did not enumerate it either, so
   the primary was not given it on a plate — but the DevOps Specialist domain includes proactive
   pipeline-security review, and the file is in `.github/workflows/`).

2. **Five acceptance criteria reference lint/validate capabilities that do not exist in CI.**
   `make lint` does not cover `preflight-floci.sh` or any Terraform; `test.yml` installs no
   Terraform. The primary prescribes `make lint passes` and `terraform validate passes` as gates
   without noting they are unenforceable in the current pipeline. The code-architect will either
   silently skip them or expand CI scope without specification.

3. **Nine advisory findings (CH-TWIN-002/004/007, CH-DEV-001/002/003/004/006, and the deployment-
   safety gap) were silently dropped** with no deferral rationale. The scope table presents a
   subset as if it were the full set.

These are correctable in a revision pass. I do not recommend REJECTED — the core analysis is good
and the disagreements are additive (more findings, sharper CI capability assessment) rather than
corrective of wrong conclusions. The routing to code-architect remains correct, but two of the new
SPECs (O-1/O-2) are CI-workflow changes that the code-architect should *not* own alone — they need
DevOps Specialist review after implementation. The primary's "ROUTING: code-architect (all
findings require implementation … no CI workflow changes are required)" line is incorrect once O-1
and O-2 are added; CI workflow changes *are* required and should be routed back to the DevOps
Specialist for the workflow edits.

