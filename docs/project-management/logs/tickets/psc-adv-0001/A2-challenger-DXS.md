# A2-Challenger-DXS: Dual-Model Challenge — psc-adv-0001

**Agent:** devops-specialist-challenger (glm-5.2)
**Timestamp:** 2026-07-29T22:30:00Z
**Phase:** A2
**Ticket:** psc-adv-0001
**Primary review challenged:** `docs/project-management/logs/tickets/psc-adv-0001/A1-DXS-devops-specialist.md`
**Artifacts cross-checked:** `.github/workflows/test.yml`, `.github/workflows/opencode.yml`, `Makefile`, `setup-floci.sh`, `mock-server/run-test.sh`, `mock-server/dev-twin.sh`, `docs/design/landing-zone-design.md`

---

## Reference Validation

| Primary Claim | Reference Provided | Authority Level | Verified? | Correctly Applied? |
|--------------|-------------------|-----------------|-----------|-------------------|
| GitHub Actions workflow syntax | docs.github.com/en/actions/using-workflows/workflow-syntax | 3 (Publisher official docs) | ✓ | ✓ |
| GitHub Actions security hardening guide | docs.github.com/en/actions/security-guides/security-hardening-for-github-actions | 3 (Publisher official docs) | ✓ | ✓ |
| Quadlet `.container` unit format | docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html | 2 (Manufacturer docs) | ✓ (not independently re-verified) | N/A — not challenged |
| systemd service hardening directives | freedesktop.org/systemd.man/latest/systemd.exec.html | 2 (Official docs) | ✓ (not independently re-verified) | N/A — not challenged |
| Terraform S3 backend + DynamoDB locking | developer.hashicorp.com/terraform/language/settings/backends/s3 | 2 (Publisher official docs) | ✓ | ✓ |
| ci-cd-pipeline skill §Pipeline Design Principles | project skill | N/A (internal) | ✓ | ✓ |
| reliability-scalability skill §7 | project skill | N/A (internal) | ✓ | Partial — see D-DXS-003 |
| observability skill §6 | project skill | N/A (internal) | ✓ | ✓ |
| `actions/checkout` SHA pinning recommendation | NONE — no citation for the specific SHA `11bd71901bbe5b1630ceea73d27597364c9af683` | N/A | ✗ — Missing reference | ✗ — SHA is stale/incorrect (see D-DXS-001) |

### Reference Validation Findings

- [✓] All factual claims have at least one citation — **EXCEPTION:** F-DXS-001 recommends pinning `actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683` with no citation for that SHA, and the SHA is stale (it corresponds to v4.2.2, not the v7 the workflow uses). This is an uncited, incorrect factual claim.
- [✓] All citations are from authoritative sources (trust level 1-7)
- [✗] All cited sources were verified to actually support the claim — the checkout SHA recommendation in F-DXS-001 was NOT verified against the actions/checkout releases page. [Source: https://github.com/actions/checkout/releases, accessed 2026-07-29] shows v7.0.1 is latest (20 Jul 2026); the cited SHA is from v4.2.2 (2024), a downgrade.
- [✓] Implementation follows what the reference recommends — for cited references, yes
- [✓] Best practices, gotchas, and production-grade guidance were sought — generally yes, with the checkout-version gap being the exception

---

## Agreements

Findings where the primary's position is correct and I concur after independent verification:

| ID | Finding | Agreement | Notes |
|----|---------|-----------|-------|
| F-DXS-001 (partial) | CI workflow lacks `permissions` block | AGREE | Verified: `.github/workflows/test.yml` has no `permissions` key. `opencode.yml` does set permissions but `test.yml` does not. GITHUB_TOKEN defaults to read/write. Correct per [Source: https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions, accessed 2026-07-29]. |
| F-DXS-001 (partial) | No concurrency control | AGREE | Verified: no `concurrency:` key in `test.yml`. Multiple pushes to the same branch waste runner minutes. Correct. |
| F-DXS-001 (partial) | No CODEOWNERS / no Dependabot | AGREE | Verified: `glob .github/{dependabot.yml,CODEOWNERS,dependabot.yaml}` returns no files. Correct. |
| F-DXS-002 | No Dependabot for GitHub Actions | AGREE | Verified: same as above. Recommendation is correct and matches the github-actions skill §Dependabot for Actions. Note: F-DXS-002 overlaps with F-DXS-001 point 4 — minor redundancy in the primary. |
| F-DXS-003 | Twin test cannot run in CI (Lima/QEMU/arm64) | AGREE | Verified: `run-test.sh:55` asserts `[[ "$(uname -m)" == 'arm64' ]]`. GitHub `ubuntu-latest` is x86_64. The AGENTS.md explicitly states "CI covers lint+unit only." The limitation is real and documented. The recommendation to consider `macos-15` arm64 runners is reasonable. |
| F-DXS-004 | `wait_driver` silent false-positive when PID empty | AGREE | Verified: `run-test.sh:229` — `wait "${DRIVER_SHELL_PID:-}" 2>/dev/null || status=$?`. If `DRIVER_SHELL_PID` is empty, `wait ""` returns 0. The guard recommendation is sound. Confidence 85 is appropriate. |
| F-DXS-005 | `dev_env` writes to real `~/.aws/credentials` | AGREE | Verified: `dev-twin.sh:768-769` appends `[floci-dev]` profile with `aws_access_key_id = test` to `${HOME}/.aws/credentials`. The `ca_bundle =` empty setting (`dev-twin.sh:766`) disables TLS verification. The risk is real — an accidental `AWS_PROFILE=floci-dev aws s3 ls` against real AWS would disable cert validation. Confidence 75 is appropriate (advisory — test creds, not real). |
| F-DXS-006 | UFW rules never cleaned up on scope change | AGREE | Verified: `setup-floci.sh:865-901`. The idempotency check at line 895 only checks if the *current* subnet's rule exists — it never enumerates and removes stale rules from a previous scope. If run with `--firewall-scope=auto` then `--firewall-scope=rfc1918`, old LAN /24 rules persist. The AGENTS.md note at lines 97-99 hints at this ("rules become stale") but the script has no cleanup. Confidence 80 is appropriate. |
| F-DXS-008 | Pinned image never refreshed | AGREE | Verified: `setup-floci.sh:711-716` — `podman image inspect` skips pull if image exists. This is a deliberate design choice for reproducibility. Confidence 75 (advisory) is appropriate. The `--refresh-image` flag suggestion is reasonable. |
| F-DXS-009 | No CI/CD pipeline for Terraform | AGREE | Verified: `landing-zone-design.md:400-418` describes manual `terraform apply` commands. No pipeline. For an educational project this is acceptable, and the recommendation to document a target-state pipeline is sound. |
| F-DXS-010 | Bootstrap state has no backup strategy | AGREE | Verified: `landing-zone-design.md:371-373` — bootstrap uses local state, no backup mentioned. The orphaned-resource risk on state loss is real. Confidence 75 is appropriate. |
| F-DXS-011 | `terraform_remote_state` coupling | AGREE | Verified: `landing-zone-design.md:99-101` references `terraform_remote_state`. The coupling trade-off is valid. Confidence 65 (low/advisory) is appropriate for an educational project. |
| F-DXS-012 | Dev-twin-only Quadlet override not documented | AGREE | Verified: `dev-twin.sh:442-451` — `_install_exec_condition` writes `ExecCondition` checking `/mnt/lima-floci-dev-data`, which only exists in the dev twin. `setup-floci.sh` does NOT create this override. Copying the dev Quadlet to production would break service start. Confidence 80 is appropriate — this is a real configuration-drift documentation gap. |
| F-DXS-013 | `_resume_health_check` resets in loop | AGREE | Verified: `dev-twin.sh:503-521` — the loop at line 505 runs up to `DEV_RESUME_HEALTH_TRIES` iterations, and lines 513-516 reset+restart the service on every `failed` state detection. The docstring (line 500) says "reset it once" but the code resets on every iteration. The primary correctly notes the docstring/code mismatch. Confidence 70 is appropriate (advisory — the service is eventually reported as failed after the budget). |
| F-DXS-014 | Port range 5100-5199 asymmetry | AGREE | Verified: `setup-floci.sh:76-92`. `FLOCI_PORTS_CONTAINER` (lines 76-80) excludes 5100-5199; `FLOCI_PORTS_FIREWALL` (lines 83-92) includes it. AGENTS.md documents the constraint. The maintenance-hazard observation is valid. Confidence 60 (low) is appropriate. |
| F-DXS-015 | No structured logging | AGREE | Verified across all three scripts — they use `printf`/`echo` with no structured format. For the current single-server scope this is acceptable. Confidence 65 (advisory) is appropriate. |
| F-DXS-016 | No overall timeout on twin run | AGREE | Verified: `run-test.sh:526-559` — `main` chains phases with individual budgets but no overall `timeout` wrapper. A hung QEMU/9p mount would block indefinitely for local runs. Confidence 75 is appropriate. |

---

## Disagreements

### D-DXS-001: F-DXS-001 action-pinning recommendation cites a stale v4.x SHA — would downgrade from v7 to v4 and lose a critical security fix

| Field | Value |
|-------|-------|
| Primary Finding | F-DXS-001 |
| Confidence | 92 |
| Primary Position | "Pin `actions/checkout` to a full commit SHA: `actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2` (or the latest v4.x SHA)" |
| Challenger Position | The recommendation is factually incorrect and would introduce a security regression. The workflow already uses `actions/checkout@v7` (verified: `test.yml:13`, `opencode.yml:24`; git log shows commit `60594cd ci: bump actions/checkout to v7`). Per [Source: https://github.com/actions/checkout/releases, accessed 2026-07-29], the latest release is **v7.0.1** (20 Jul 2026), and **v7.0.0** (18 Jun 2026) introduced a **critical security change**: it blocks checking out fork PRs for `pull_request_target` and `workflow_run` triggers (PR #2454). The SHA the primary cites (`11bd71901bbe5b1630ceea73d27597364c9af683`) corresponds to v4.2.2 from 2024 — a **downgrade of three major versions** that would lose the v7 fork-PR-checkout safety fix. Furthermore, the primary did not cite any source for this specific SHA, violating the authoritative-reference protocol (Rule 1 — Verify Before Acting). The correct recommendation is to pin to the **v7.0.1 commit SHA**: `actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1` [Source: https://github.com/actions/checkout/releases/tag/v7.0.1, accessed 2026-07-29]. |
| Recommendation | Pin `actions/checkout` to the v7.0.1 SHA `3d3c42e5aac5ba805825da76410c181273ba90b1` (NOT the v4.2.2 SHA). The primary's `# v4.2.2` comment was hallucinated from stale training data and never verified against the releases page. This is a blocking correction — applying the primary's recommendation as written would downgrade the action and remove the fork-PR-checkout protection. |

---

### D-DXS-002: F-DXS-007 rollback recommendation overstates the reliability-scalability skill's applicability to an idempotent installer

| Field | Value |
|-------|-------|
| Primary Finding | F-DXS-007 |
| Confidence | 60 |
| Primary Position | "Per the reliability-scalability skill [§7], every deploy should be reversible within 5 minutes... a failed installation should leave the system in a known state." Recommends a `--rollback` flag, transaction log, and manual rollback documentation. |
| Challenger Position | The primary misapplies the deployment-reversibility principle. The reliability-scalability skill §7 addresses **continuous deployment of running services** (canary, blue-green, expand-migrate-contract) where traffic must be shifted back from a failed new version to the previous known-good version. `setup-floci.sh` is a **one-shot idempotent installer**, not a rolling deployment. Its idempotency IS the rollback strategy: re-running the script converges to the desired state regardless of where it failed. A `.bak`-based `--rollback` flag adds complexity for marginal value — the operator's recovery path is "fix the issue and re-run the installer," which is simpler and already supported. The transaction-log suggestion has some merit (better failure diagnostics), but framing it as a "reversible deploy" requirement mischaracterises the tool. Confidence lowered from 70 to 60 (advisory, not blocking). |
| Recommendation | Reframe F-DXS-007 as a **diagnostics improvement** (transaction log / phase tracking for better error messages) rather than a **rollback/reversibility** gap. The installer's idempotency already satisfies the spirit of the reliability principle for a setup tool. A `--rollback` flag is premature complexity for an educational single-server project. |

---

### D-DXS-003: F-DXS-011 confidence score has a formatting error — `Confidence = 65` instead of `| Confidence | 65 |`

| Field | Value |
|-------|-------|
| Primary Finding | F-DXS-011 |
| Confidence | 85 |
| Primary Position | The finding header reads `Confidence = 65` instead of the markdown-table format `| Confidence | 65 |` used by all other findings. |
| Challenger Position | This is a mechanical formatting defect that breaks the table structure and could cause automated parsers to miss the confidence value. While minor, it indicates a copy-paste or template drift error that should be caught by a self-audit. The finding's content (terraform_remote_state coupling) is otherwise valid and I agree with the substance. |
| Recommendation | Fix the table row to `| Confidence | 65 |` to match the other findings. |

---

## One-Sided Findings (Primary Missed)

### M-DXS-001: `.github/workflows/opencode.yml` uses `anomalyco/opencode/github@latest` — unpinned mutable action reference in a workflow with `id-token: write` and secret access

| Field | Value |
|-------|-------|
| Confidence | 92 |
| Description | The primary reviewed only `.github/workflows/test.yml` (listed in F-DXS-001 as "`.github/workflows/test.yml:1-21`") and missed `.github/workflows/opencode.yml` entirely. The opencode workflow (verified: `.github/workflows/opencode.yml:29`) uses `anomalyco/opencode/github@latest` — a **mutable branch reference** that floats to whatever the latest commit on `main` is. This is explicitly forbidden by the GitHub Actions security hardening guide [Source: https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions#using-third-party-actions] and the github-actions skill ("Do NOT use `@main`, `@master`, or branch references — these are mutable and can introduce breaking changes without warning"). Critically, this workflow requests `permissions: id-token: write` (line 18) and accesses `secrets.OLLAMA_API_KEY` (line 31). If the `anomalyco/opencode/github` repository is compromised or a malicious commit is pushed to `main`, the attacker gets an OIDC token and the secret — a **supply-chain compromise with credential exfiltration**. This is strictly worse than the `actions/checkout@v7` floating tag the primary flagged in F-DXS-001, because `@latest` is a branch ref (fully mutable, no version pinning at all) while `@v7` is a major-version tag (semver-bounded, only receives patch/minor updates within v7). |
| Recommended Action | Pin `anomalyco/opencode/github` to a full commit SHA immediately. This is a **blocking** finding (confidence ≥80) — the combination of `@latest` + `id-token: write` + secret access is a critical supply-chain risk. If a SHA is not available, pin to a specific version tag (e.g. `@v1.2.3`) as an interim measure and open a task to obtain the SHA. This should have been the highest-severity finding in the primary review. |

---

### M-DXS-002: `.github/workflows/opencode.yml` trigger condition can be spoofed via comment body — script-injection-adjacent pattern with untrusted input

| Field | Value |
|-------|-------|
| Confidence | 75 |
| Description | The opencode workflow (verified: `opencode.yml:11-15`) triggers on `issue_comment` and `pull_request_review_comment` events, with an `if:` condition that checks `github.event.comment.body` for `/oc` or `/opencode` prefixes. Per the GitHub Actions security hardening guide [Source: https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions#understanding-the-risk-of-script-injections], comment bodies are **untrusted input**. While the `if:` expression itself is not directly injectable (GitHub evaluates `if:` in a sandboxed context, not a shell), the pattern of matching prefixes in untrusted input means any user (including drive-by commenters on a public repo) can trigger the workflow. Combined with M-DXS-001's `@latest` action reference and `id-token: write`, a malicious commenter could trigger a workflow that runs an untrusted action version with OIDC token access. The primary did not review this workflow at all. |
| Recommended Action | 1. Restrict who can trigger the workflow — use `github.event.comment.author_association` to check for `OWNER`, `MEMBER`, or `COLLABORATOR` only. 2. Pin the action (see M-DXS-001). 3. Consider whether `id-token: write` is actually needed for the opencode action — if it only needs the API key, drop `id-token` to reduce blast radius. |

---

### M-DXS-003: No `timeout-minutes` on any CI job — a hung step consumes runner minutes indefinitely until the GitHub default (6h/360min) kicks in

| Field | Value |
|-------|-------|
| Confidence | 80 |
| Description | Neither `test.yml` nor `opencode.yml` sets `timeout-minutes` on their jobs (verified: `test.yml:9-21` has no `timeout-minutes`; `opencode.yml:10-33` has none). Per [Source: https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#jobsjob_idtimeout-minutes, accessed 2026-07-29], the default is **360 minutes (6 hours)**. A hung `apt-get install`, a stuck `make test`, or a wedged opencode invocation would burn 6 hours of runner time before GitHub kills it. For the `test.yml` job this is a waste-of-resources issue; for `opencode.yml` (which has secret access and OIDC) a hung run also prolongs the window during which credentials are available in the runner environment. The primary's F-DXS-016 correctly identifies the missing overall timeout on the local twin runner (`run-test.sh`), but missed the same class of issue in the CI workflows themselves. |
| Recommended Action | Add `timeout-minutes: 15` to `test.yml` lint-and-unit job (lint+unit should finish in <5 min; 15 is generous). Add `timeout-minutes: 30` to `opencode.yml` opencode job. This is a low-cost, high-value hardening that the primary should have caught. |

---

### M-DXS-004: CI workflow installs `shellcheck` and `bats` via `apt-get` on every run — no dependency caching, slow feedback

| Field | Value |
|-------|-------|
| Confidence | 70 |
| Description | `test.yml:14-17` runs `sudo apt-get update && sudo apt-get install -y shellcheck bats` on every workflow run (verified). There is no caching of the apt packages or the installed tools. On `ubuntu-latest` this adds ~10-20 seconds of cold-install time per run. While the ci-cd-pipeline skill §Caching Strategy recommends caching dependencies keyed on lockfile hashes, apt packages are harder to cache than language dependencies. However, the primary's review did not mention this at all — for a CI-readiness review, the feedback-loop latency is a relevant observation. A simpler mitigation: use a pre-built Docker image with shellcheck+bats baked in, or use the `lyokha/action-shellcheck` / `bats-core/bats-action` marketplace actions which handle installation and caching. Alternatively, `actions/cache` on `/var/cache/apt/archives` keyed on the apt package list. |
| Recommended Action | Advisory — consider caching apt archives or switching to a pre-baked runner image / marketplace action to reduce CI feedback latency. Not blocking. |

---

### M-DXS-005: `dev_env` in `dev-twin.sh` does not check if the `~/.aws/credentials` file already contains a conflicting `[floci-dev]` section with different values — silent overwrite on profile-name collision

| Field | Value |
|-------|-------|
| Confidence | 70 |
| Description | The primary's F-DXS-005 correctly identifies that `dev_env` writes to the real `~/.aws/credentials` file, but misses a subtler bug: `dev-twin.sh:768` checks `grep -q '\[floci-dev\]' "$creds_file"` and only appends if the profile name is absent. But if a user has a pre-existing `[floci-dev]` profile with **real** AWS credentials (e.g., they named a real profile `floci-dev` for an unrelated project), the grep finds the name and **skips the append** — silently leaving the real credentials in place. The user then runs `AWS_PROFILE=floci-dev` expecting Floci test creds, but hits real AWS with `ca_bundle=` (TLS verification disabled) from the config profile (`dev-twin.sh:765`). The reverse is also possible: if the user later adds a real `[floci-dev]` profile, the dev-env check skips (profile exists), and the user's real creds are used where test creds were expected. The profile-name collision is unhandled. |
| Recommended Action | Use a unique, namespaced profile name unlikely to collide (e.g., `tianlu-floci-dev`) OR verify the existing profile's credentials match `test`/`test` before reusing it, OR use a separate credentials file entirely (the primary's recommendation in F-DXS-005 point 1). Advisory — confidence 70. |

---

### M-DXS-006: `setup-floci.sh` `configure_firewall` does not validate that `FIREWALL_SCOPE` is a known value — typos silently fall through to the `auto` branch

| Field | Value |
|-------|-------|
| Confidence | 65 |
| Description | `setup-floci.sh:866-877` uses a `case "$FIREWALL_SCOPE"` with only two branches: `rfc1918)` and `*)`. The `*` catch-all treats ANY unknown value (including typos like `--firewall-scope=rf1918-typo` or `--firewall-scope=` with an empty value) as `auto`, which then requires `SERVER_LAN_SUBNET`. If `SERVER_LAN_SUBNET` happens to be set (from a previous `detect_hostname_and_ip` run), the typo silently opens ports to the detected /24 instead of the intended RFC1918 ranges. The primary's F-DXS-006 covers the stale-rule cleanup issue but not this input-validation gap. |
| Recommended Action | Add explicit validation: `case` should have a `*) FAIL "unknown --firewall-scope value: $FIREWALL_SCOPE; use 'auto' or 'rfc1918'"` branch instead of silently defaulting to `auto`. Advisory — confidence 65. |

---

## Recommendations

### High-priority (blocking — must address before gate passes)

1. **Fix the `actions/checkout` pinning recommendation (D-DXS-001).** The primary's SHA is stale (v4.2.2). Pin to `actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1`. Applying the primary's recommendation as written would downgrade the action three major versions and remove the v7 fork-PR-checkout security fix. [Source: https://github.com/actions/checkout/releases/tag/v7.0.1, accessed 2026-07-29]

2. **Pin `anomalyco/opencode/github` in `opencode.yml` (M-DXS-001).** `@latest` + `id-token: write` + `secrets.OLLAMA_API_KEY` access is a critical supply-chain risk. This is a more severe finding than anything in the primary review and was entirely missed. The primary should have reviewed ALL workflow files in `.github/workflows/`, not just `test.yml`.

3. **Add `timeout-minutes` to all CI jobs (M-DXS-003).** 15 min for test, 30 min for opencode. Low-cost, prevents 6-hour runner burns on hung steps.

### Medium-priority (should address)

4. **Restrict opencode workflow triggers to trusted users (M-DXS-002).** Add `github.event.comment.author_association == 'OWNER' || == 'MEMBER' || == 'COLLABORATOR'` to the `if:` condition.

5. **Fix F-DXS-011 table formatting (D-DXS-003).** Mechanical defect in the primary's output.

6. **Reframe F-DXS-007 as diagnostics, not rollback (D-DXS-002).** The idempotency IS the recovery mechanism for an installer.

### Low-priority (advisory)

7. Consider apt caching in CI (M-DXS-004).
8. Namespace the dev-env AWS profile to avoid collisions (M-DXS-005).
9. Validate `FIREWALL_SCOPE` explicitly instead of catch-all (M-DXS-006).

---

## Self-Audit Checklist

| Category | Checked? | Finding or PASS |
|----------|----------|-----------------|
| All primary claims cross-checked against source files | PASS | Read `test.yml`, `opencode.yml`, `Makefile`, `setup-floci.sh`, `run-test.sh`, `dev-twin.sh`, `landing-zone-design.md` |
| Reference validation performed | PASS — with finding | D-DXS-001: primary's checkout SHA is uncited and incorrect; verified against releases page |
| Confidence scores assigned to all findings | PASS | D-DXS-001 (92), D-DXS-002 (60), D-DXS-003 (85), M-DXS-001 (92), M-DXS-002 (75), M-DXS-003 (80), M-DXS-004 (70), M-DXS-005 (70), M-DXS-006 (65) |
| One-sided findings identified | PASS | 6 missed findings (M-DXS-001 through M-DXS-006), including 2 blocking (≥80) |
| Agreement/disagreement rationale provided | PASS | Every agreement and disagreement has evidence (file:line citations) |
| Authoritative sources cited for new claims | PASS | GitHub Actions docs, actions/checkout releases page, security hardening guide |
| No code written (challenge only) | PASS | This is a critique document only — no code changes proposed in the file |

---

## Verdict

**VERDICT: CONDITIONAL PASS — with corrections required**

The primary review is thorough and largely accurate (16 findings, 13 of which I fully agree with after independent verification). However, it contains **one factual error that would cause a security regression if applied as written** (D-DXS-001: stale checkout SHA) and **missed the most severe supply-chain finding in the repository** (M-DXS-001: `@latest` action with `id-token: write`). The primary also only reviewed `test.yml` and missed `opencode.yml` entirely — a scope gap for a CI-readiness review.

**Blocking corrections to the primary review:**
- D-DXS-001 (92): Fix the checkout SHA recommendation — pin to v7.0.1, not v4.2.2
- M-DXS-001 (92): Add the `opencode.yml` `@latest` finding to the primary — this is the highest-severity finding in the repo
- M-DXS-003 (80): Add `timeout-minutes` to all CI jobs

After these corrections, the primary review's blocking-finding list should be:
1. **M-DXS-001 (92)** — `@latest` action + `id-token: write` + secret access (NEW, highest severity)
2. **D-DXS-001 (92)** — corrected checkout pinning (fix primary's stale SHA)
3. F-DXS-001 (90) — `test.yml` lacks `permissions` + concurrency (unchanged, minus the SHA error)
4. F-DXS-004 (85) — `wait_driver` false-positive (unchanged)
5. F-DXS-002 (85) — no Dependabot (unchanged)
6. M-DXS-003 (80) — no `timeout-minutes` (NEW)
7. F-DXS-003 (80) — twin cannot run in CI (unchanged)
8. F-DXS-006 (80) — UFW stale rules (unchanged)
9. F-DXS-009 (80) — no Terraform CI/CD (unchanged)
10. F-DXS-012 (80) — dev-twin Quadlet override drift (unchanged)

**ROUTING:** code-architect (D-DXS-001 correction, M-DXS-001 action pinning, M-DXS-002 trigger restriction, M-DXS-003 timeout-minutes, F-DXS-001 permissions/concurrency), bash-specialist (F-DXS-004, F-DXS-006, M-DXS-006), docs-writer (F-DXS-009, F-DXS-012, D-DXS-003 formatting fix)
