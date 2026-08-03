# A2-Challenger-SX: Dual-Model Challenge — psc-adv-0001

| Field | Value |
|-------|-------|
| Model | glm-5.2 |
| Phase | A2 — Dual-Model Challenge |
| Primary Output | Security Reviewer A1 review of 4 artifacts (auth-plan, setup-floci.sh, dev-twin.sh, landing-zone-design.md). Verdict CONDITIONAL PASS, 11 findings (F-SX-001..011), severity 9, blocking flag raised for authentication-plan code implementation. |
| Date | 2026-07-29 |

## Reference Validation

| Primary Claim | Reference Provided | Verified? | Correctly Applied? | Challenger Note |
|---------------|---------------------|-----------|--------------------|-----------------|
| All Floci env vars | `docs/scraped/environment-variables.md` (TL2) | ✓ | ✓ | Agreed — scraped docs are authoritative for Floci |
| OWASP Top 10:2021 | owasp.org (TL1) | ✓ | ✓ | Agreed |
| AWS Well-Architected SEC02/SEC03/SEC04 | AWS WA Framework (TL2) | ✓ | ✓ | Agreed |
| systemd 259 / AppArmor gotchas | AGENTS.md (TL3) | ✓ | ✓ | Agreed — verified against lines 41-49 of AGENTS.md |
| gitleaks | gitleaks GitHub repo | ✓ | Partially | gitleaks is authoritative for *itself*, but the OWASP A07:2021 mapping is loose; gitleaks is a tool, not the standard. Minor — does not change finding outcome. |

The primary's reference-validation table is largely sound. One weak spot: F-SX-005 cites gitleaks under OWASP A07:2021 — gitleaks is the *mitigation tool*, not the authority for the requirement. The requirement authority is OWASP A07 / NIST SP 800-53 IA-5. This does not change the conclusion, only the citation's precision.

## Agreements

I agree with the following findings, with the caveats noted where applicable:

- **F-SX-001 (test/test in dev_env, conf 95)** — AGREE. Verified at `mock-server/dev-twin.sh:768-769`: `printf '\n[floci-dev]\naws_access_key_id = test\naws_secret_access_key = test\n'`. The auth-plan §6.6 (`authentication-plan.md:384-418`) clearly specifies the rotated-credentials load path, and `_rotate_bootstrap_credentials`, `DEV_CREDENTIALS_FILE`, and `DEV_AUTH_MODE` are indeed absent from the current `dev-twin.sh` (grep for `DEV_CREDENTIALS_FILE` returns only the auth plan, not dev-twin.sh). The implementation gap is real.
- **F-SX-002 (test in preflight aws_admin, conf 90)** — AGREE. Verified at `scripts/preflight-floci.sh:35`: `aws_admin() { AWS_ACCESS_KEY_ID="$DEV_AKID" AWS_SECRET_ACCESS_KEY=test aws ...`. Note: the primary *understates* — the AKID used is `DEV_AKID` (`111111111111` default), not `test`. Under `FLOCI_AUTH_MODE=sigv4`, the deployer credential is `floci`/`floci`, so both the AKID *and* the secret are wrong, not just the secret. The primary's recommendation matches auth-plan §6.9.
- **F-SX-003 (FLOCI_AUTH_MODE not implemented, conf 95)** — AGREE, and this is the highest-priority finding. Verified: no `FLOCI_AUTH_MODE` in `setup-floci.sh` config block (lines 36-180); `write_env_file` (815-842) writes no `FLOCI_AUTH_VALIDATE_SIGNATURES` / `FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED` / `FLOCI_SERVICES_IAM_SEED_DEPLOYER_PRINCIPAL`. The crypto-theater `true`/`false` split is a genuine OWASP A04:2021 (Insecure Design) risk. The primary correctly identifies this as the single most important control.
- **F-SX-004 (no chmod 0600 on ~/.aws/credentials, conf 85)** — AGREE on the gap, DISAGREE on confidence (see D-SX-004). The current code (`dev-twin.sh:768-769`) does write the file without `chmod`. However, AWS CLI *will* refuse a credentials file with group/other read, so the practical exposure is a noisy failure, not a silent leak.
- **F-SX-005 (no secret scanning in CI, conf 80)** — AGREE. Verified `.github/workflows/test.yml` has only `make lint` + `make test`, no gitleaks/truffleHog step. No `permissions:` block either (see M-SX-001 below for the related issue).
- **F-SX-006 (IRSA stand-in long-lived Secret, conf 85)** — AGREE on the substance. Verified `landing-zone-design.md:246-253`: the design admits it is a "production anti-pattern" with "long-lived credential sprawl" but specifies no rotation cadence, no `immutable: true`, no RBAC restriction, and no audit logging. This is a genuine OWASP A01:2021 (Broken Access Control) gap.
- **F-SX-007 (path traversal in FLOCI_HOST_PERSISTENT_PATH, conf 75)** — AGREE it is worth hardening, DISAGREE on severity (see D-SX-007).
- **F-SX-008 (print_summary unconditional UNAUTHENTICATED, conf 90)** — AGREE. Verified `setup-floci.sh:946-949` prints the risk message unconditionally. The auth-plan §6.3 conditional (`authentication-plan.md:265-277`) is the correct fix.
- **F-SX-009 (env file no integrity check, conf 70)** — AGREE as advisory. The primary correctly self-rates this LOW and acknowledges the 0600/0700 model is adequate for the threat model. This is appropriately tiered.
- **F-SX-010 (TLS off in dev twin, conf 80)** — AGREE. Verified `dev-twin.sh:484` passes `FLOCI_TLS_ENABLED=false FLOCI_TLS_SELF_SIGNED=false`. AGENTS.md documents this as intentional (dev-twin section). Loopback-only per `floci-dev.yaml`. The finding is correctly advisory.
- **F-SX-011 (no rotation in test twin, conf 75)** — AGREE. The auth-plan §7.3 (`authentication-plan.md:566-571`) test matrix shows the sigv4 column should be exercisable, and `run-in-vm.sh:194` uses bare `podman exec ... aws` with no `-e AWS_ACCESS_KEY_ID=floci` override. The primary correctly scopes this as LOW (test twin tests mechanics, not lifecycle).

## Disagreements

### D-SX-004: F-SX-004 confidence overstated — AWS CLI enforces 0600 at read time

| Field | Value |
|-------|-------|
| Primary Finding | F-SX-004 |
| Confidence | 78 (primary: 85) |
| Primary Position | MODERATE severity; "the principle of least privilege dictates that the script should set the correct permissions proactively rather than relying on the CLI to reject misconfigured files." |
| Challenger Position | The practical impact is lower than MODERATE. The AWS CLI hard-aborts with `FileNotFoundError` (sic) / a permissions error when `~/.aws/credentials` is mode >0600 — this is a documented, enforced behaviour, not a "reliance" on a soft check. The real residual risk is only the window *between write and first CLI use*, during which a local process on the same uid could read the file. Since the file is created with the user's default umask (typically 022 → 0644), that window is real but bounded. MODERATE overstates a finding with no network exposure and a self-correcting failure mode. I do NOT disagree the fix is needed — only the tier. Recommend LOW-MODERATE (confidence 78). |
| Recommendation | Keep the fix (`chmod 0600 "$creds_file"` per auth-plan §6.6 line 411), but retier to LOW-MODERATE. The auth-plan already specifies the fix; this is a faithful implementation note, not a new risk class. |
| Reference | [AWS CLI shared config docs — "credentials file … must have permissions of 0600"; OWASP A05:2021 — the misconfiguration is self-detected by the consumer, lowering exploitability (CWE-732 with a compensating control).] |

### D-SX-007: F-SX-007 severity is overstated for a root-only input path

| Field | Value |
|-------|-------|
| Primary Finding | F-SX-007 |
| Confidence | 60 (primary: 75) |
| Primary Position | MODERATE; cites `..` traversal and symlink following in `FLOCI_HOST_PERSISTENT_PATH` (set via env var before sourcing). |
| Challenger Position | The threat model is mis-specified. `FLOCI_HOST_PERSISTENT_PATH` is set by the **operator running the installer as root** (per AGENTS.md privilege model: "root/sudo for setup steps"). It is not sourced from untrusted input — it is a deployment parameter the operator chose. A "vulnerability" that requires the operator to attack their own install is not a vulnerability; it is a footgun. The symlink-following concern (`mkdir -p` follows symlinks) is real only if an attacker already has write access to the parent directory *before* root runs the installer — which is a pre-compromise assumption, not a finding about the script. The primary's `realpath` suggestion is a reasonable hardening, but tiering it MODERATE alongside the IRSA stand-in (which has real cross-pod exposure) inflates it. |
| Recommendation | Retier to LOW (confidence 60-65). Keep the `realpath` canonicalization as defense-in-depth, but do not block A-GATE on it. The script already validates newlines/colons/whitespace/quotes/backslashes/`%` (lines 115-116) — that is more validation than most installers perform on a root-supplied path. |
| Reference | [CWE-22 — the "restricted directory" requires the attacker control the path component; here the operator controls the entire path; OWASP A01:2021 — broken access control requires an untrusted principal, which is absent.] |

### D-SX-009: F-SX-009 is correctly advisory but the recommendation is unimplementable as written

| Field | Value |
|-------|-------|
| Primary Finding | F-SX-009 |
| Confidence | 55 (primary: 70) |
| Primary Position | LOW; recommends "Consider adding a `ProtectSystem=strict` equivalent (not possible under rootless systemd per AGENTS.md gotchas) or documenting FIM via `aide`/`auditd`." |
| Challenger Position | The primary correctly notes `ProtectSystem=strict` is excluded by AGENTS.md (lines 41-49 — it triggers implicit userns → AppArmor denies). But then it offers `aide`/`auditd` as the alternative — **`auditd` is a system service that the unprivileged `floci` user cannot install or configure**, and `aide` requires a root-owned baseline DB the floci user cannot write. The recommendation is, by the primary's own context, unimplementable in the rootless model. This is a finding whose fix contradicts the threat model it was filed under. The env file is already 0600 floci:floci inside a 0700 home — that *is* the integrity control for this privilege tier. |
| Recommendation | Drop the `aide`/`auditd` recommendation. The adequate mitigation for an unprivileged-user-owned file is file ownership + mode, which is already in place. If a detection layer is genuinely wanted, it belongs at the *host* level (system-wide FIM), not in the rootless container unit. Reclassify as informational (confidence ≤55), not a LOW finding requiring action. |
| Reference | [OWASP A05:2021 — compensating control (0600+0700) present; systemd 259 rootless limitations documented in AGENTS.md §"Critical gotchas".] |

## One-Sided Findings (Primary Missed)

### M-SX-001: CI workflow `test.yml` has no `permissions:` block — default token over-privileged

| Field | Value |
|-------|-------|
| Confidence | 85 |
| Description | The primary reviewed `.github/workflows/test.yml` (F-SX-005) but only flagged the *absence of secret scanning*. It missed that `test.yml` declares **no `permissions:` block at all** (verified: the file has `on:`, `jobs:`, `runs-on:`, `steps:` but no `permissions:`). Per GitHub's [automatic token authentication defaults](https://docs.github.com/en/actions/security-for-github-actions/security-guides/automatic-token-authentication), a workflow without an explicit `permissions:` block inherits the repo/org default — which historically is `contents: write`, `pull-requests: write`, etc. (read-write). The `opencode.yml` workflow *correctly* sets `permissions: id-token: write, contents: read, pull-requests: read, issues: read`, which proves the project knows the pattern. `test.yml` is the more frequently-triggered workflow (every push/PR) and is the one missing it. This is an OWASP A05:2021 (Security Misconfiguration) / GitHub hardening baseline issue that a secret-scanner-only recommendation would not address. |
| Recommended Action | Add an explicit least-privilege `permissions:` block to `test.yml`: `permissions: { contents: read }` (lint+unit needs only to read the repo). Reference: [GitHub Actions security hardening — "set the minimum required permissions"](https://docs.github.com/en/actions/security-for-github-actions/security-guides/security-hardening-for-github-actions#using-third-party-actions). |
| Severity | MODERATE — CI is the supply-chain entry point; an over-privileged `GITHUB_TOKEN` in the lint job can be exfiltrated by a compromised dependency or a `pull_request_target` misconfiguration to push to the protected branch. |

### M-SX-002: `actions/checkout@v7` and `anomalyco/opencode/github@latest` are unpinned to a SHA — supply-chain substitution risk

| Field | Value |
|-------|-------|
| Confidence | 80 |
| Description | The primary's CI review (F-SX-005) focused on secret *scanning* but did not flag the supply-chain integrity of the actions themselves. Verified: `test.yml:13` uses `actions/checkout@v7` (floating major tag) and `opencode.yml:29` uses `anomalyco/opencode/github@latest` (floating `@latest`). A floating tag is mutable — a tag compromise or maintainer account compromise can swap the action content without a version bump. OWASP [SCVS v2 / A10:2021 — Software and Data Integrity Failures] and the GitHub [security-hardening guide](https://docs.github.com/en/actions/security-for-github-actions/security-guides/security-hardening-for-github-actions#using-third-party-actions) mandate pinning third-party actions to a commit SHA. `@latest` is the most dangerous form: it auto-updates on every run. |
| Recommended Action | Pin `actions/checkout` to a full 40-char commit SHA with a `# v7.x.y` comment for readability. Pin `anomalyco/opencode/github` to a SHA immediately (it's a third-party action running with `id-token: write` — the highest-privilege CI permission). Add a Dependabot config for actions to get PRs on new SHA-pinned versions. |
| Severity | HIGH for `opencode.yml` (it has `id-token: write` — a compromised action can mint OIDC tokens for any cloud the repo trusts); MODERATE for `test.yml` (read-only lint, but still a supply-chain vector). |

### M-SX-003: Auth plan rotation persists secret via `printf '%s\n%s\n'` to a plain file — no atomicity, no in-memory zeroization

| Field | Value |
|-------|-------|
| Confidence | 72 |
| Description | The primary reviewed the auth plan's *implementation gap* (F-SX-001) but did not critique the rotation design itself (`authentication-plan.md:321-367`). Two issues the primary missed: (1) `_rotate_bootstrap_credentials` writes the new AKID+secret with `printf ... > "$DEV_CREDENTIALS_FILE"` (`authentication-plan.md:364-365`) — a non-atomic write. A crash mid-write leaves a truncated or empty credentials file, and the next `dev_env` falls back to `test/test` (per §6.6) *silently*, defeating the rotation. The design says "mode 0600" but never specifies write-to-temp + atomic rename (which `write_env_file` and `write_quadlet_unit` in `setup-floci.sh` *do* use — this is an inconsistency). (2) The new secret is parsed out of `aws iam create-access-key` JSON via `grep | sed` (`authentication-plan.md:340-341`) and held in a plain shell variable (`$new_sk`) for the function's lifetime. There is no `unset` / zeroization. While bash variables are not reliably zeroable, the design should at least `unset DEV_BOOTSTRAP_SECRET` after `dev_env` consumes it, and the file write should be atomic to match the installer's own pattern. |
| Recommended Action | (1) Make the credential-file write atomic: write to `$DEV_CREDENTIALS_FILE.tmp`, `chmod 0600`, `mv -f` — mirroring `write_env_file` (`setup-floci.sh:840-841`). (2) Document that the shell variable cannot be reliably zeroized (a bash limitation) but `unset` the bootstrap vars at end of `_rotate_bootstrap_credentials` and `dev_env`. (3) Add a recovery path: if `DEV_CREDENTIALS_FILE` exists but is empty/truncated, treat it as rotation-failed (use `test -s`, not `-f`). |
| Severity | MODERATE — a truncated credentials file silently reverts to the well-known `test/test`, which is the exact risk the rotation was designed to eliminate. This is a self-defeating design flaw the primary did not surface. |
| Reference | [OWASP A07:2021 — silent fallback to a known-compromised credential; CWE-377 — Insecure Temporary File (the truncated-write is a durability bug); the installer's own `write_env_file`/`write_quadlet_unit` establish the project's atomic-write norm.] |

### M-SX-004: Auth plan `dev-recreate` rotation path trusts `DEV_CREDENTIALS_FILE` content without validating it still authenticates

| Field | Value |
|-------|-------|
| Confidence | 68 |
| Description | `authentication-plan.md:324-334` describes the `dev-recreate` path: if `DEV_CREDENTIALS_FILE` exists, `source` it and use `DEV_BOOTSTRAP_AKID`/`DEV_BOOTSTRAP_SECRET` to create the next key. The design assumes the persisted credential is still valid. But the data disk persists the *Floci IAM state*, and an operator could have manually deleted the key (via the UI or a prior rotation) between `dev-down` and `dev-recreate`. The plan has a "rotation failure" fallback (§5.4) but that fallback *also* uses the stale `bootstrap_secret` variable sourced from the (now-invalid) file — it never falls back to `floci`/`floci` on the recreate path because `floci`/`floci` was deleted in the *first* rotation. The result: `dev-recreate` after a manual key deletion silently fails both the rotation AND the fallback, leaving `dev_env` with no usable credential. The primary flagged the general rotation gap (F-SX-001) but did not trace this specific `dev-recreate` failure branch. |
| Recommended Action | In `_rotate_bootstrap_credentials`, after sourcing `DEV_CREDENTIALS_FILE`, do a cheap probe (`aws sts get-caller-identity` via `podman exec`) before trusting it. If the probe fails, surface a clear error: "persisted bootstrap credential is no longer valid — run `make dev-reset` then `make dev-recreate`." Do not silently fall back to a credential that was deliberately deleted. |
| Severity | LOW-MODERATE — requires an unusual operator sequence (manual key deletion + dev-recreate), but the silent failure mode is the concern. |
| Reference | [OWASP A09:2021 — Security Logging and Monitoring Failures (silent fallback); CWE-754 — Improper Check for Unusual or Exceptional Conditions.] |

### M-SX-005: Landing-zone design does not bound the IRSA stand-in credential's STS session duration

| Field | Value |
|-------|-------|
| Confidence | 82 |
| Description | The primary's F-SX-006 correctly flagged the missing rotation cadence, immutability, and RBAC for the IRSA stand-in Secret. However, it missed a more fundamental parameter: the `sts:AssumeRole` call (`landing-zone-design.md:247`) is "deploy-time" — the design never specifies `DurationSeconds`. STS AssumeRole defaults to **3600 seconds (1 hour)** but can be set up to 43200 seconds (12 hours) via a role policy, and many deployments set it to the maximum to avoid re-assumption. A 12-hour static credential mounted in a Secret is materially worse than a 1-hour one. The design says "long-lived credential sprawl" but never states *how* long. Without an explicit `DurationSeconds` bound (and a documented CronJob that re-assumes before expiry), the stand-in's exposure window is unspecified — an auditor cannot evaluate the risk. This compounds F-SX-006 rather than replacing it. |
| Recommended Action | In `landing-zone-design.md` §5.4, state the session duration explicitly (recommend ≤1 hour to mirror real IRSA's ~1h pod-token TTL), document the re-assumption mechanism (CronJob cadence = duration − 10% margin), and add a note that `MaxSessionDuration` on the application role must be set to the same bound to prevent a longer-duration assumption via direct API. |
| Severity | MODERATE — the design currently permits an unspecified (up to 12h) static credential to sit in a namespace Secret indefinitely, with no documented re-assumption. |
| Reference | [AWS STS AssumeRole — `DurationSeconds` default 3600, max 43200; OWASP A01:2021 — Broken Access Control (unbounded session); AWS Well-Architected SEC03 — "Rotate credentials regularly" applies to session credentials too.] |

### M-SX-006: `FLOCI_AUTH_PRESIGN_SECRET` has no documented threat model / no rotation path

| Field | Value |
|-------|-------|
| Confidence | 70 |
| Description | The primary reviewed the auth plan's rotation design (F-SX-001) but treated `FLOCI_AUTH_PRESIGN_SECRET` as out of scope. Verified in `setup-floci.sh:790-804` (`generate_presign_secret`): the secret is generated once via `openssl rand -hex 32` and reused-if-exists forever — there is **no rotation path** in the auth plan or the installer. The auth plan (`authentication-plan.md`) covers `floci-deployer` rotation extensively but never mentions `FLOCI_AUTH_PRESIGN_SECRET`. Per the Floci docs (`docs/scraped/environment-variables.md:22`), this secret "sign[s] and verif[ies] pre-signed URLs." A compromised `FLOCI_AUTH_PRESIGN_SECRET` allows forging pre-signed URLs (S3 object access, SQS/SNS endpoints) without `floci-deployer` credentials at all — it is an independent authentication secret that bypasses the IAM layer the entire auth plan is about. The primary's review scope included `setup-floci.sh`, where this secret lives, and the auth plan, where it is never discussed. |
| Recommended Action | Add a section to the auth plan covering `FLOCI_AUTH_PRESIGN_SECRET`: (1) its threat model (forge pre-signed URLs → read/write any S3 object), (2) a rotation procedure (regenerate, write to env file, restart `floci.service` — note this invalidates all existing pre-signed URLs), (3) a note that it is *not* covered by the `floci-deployer` rotation. Cross-link from F-SX-001. |
| Severity | MODERATE — the secret's compromise is a direct S3/queue access bypass, and it has zero documented lifecycle. |
| Reference | [Floci env vars doc (`docs/scraped/environment-variables.md:22`) — "Secret used to sign and verify pre-signed URLs"; OWASP A02:2021 — Cryptographic Failures (key without rotation); OWASP A07:2021 — Identification and Authentication Failures.] |

### M-SX-007: `opencode.yml` exposes `id-token: write` to a third-party action with no job-environment isolation

| Field | Value |
|-------|-------|
| Confidence | 75 |
| Description | The primary did not review `.github/workflows/opencode.yml` (it was outside the stated artifact list, but F-SX-005 reviewed *CI* generically and this *is* a CI workflow). Verified `opencode.yml:17-21`: the job grants `id-token: write` (OIDC minting) AND `contents: read` AND runs `anomalyco/opencode/github@latest` (unpinned — see M-SX-002). `id-token: write` is the most powerful GitHub Actions permission: it lets the job mint OIDC tokens asserting the repo's identity to any configured cloud provider. Combined with an unpinned `@latest` third-party action, a compromise of the `anomalyco/opencode` action (or its registry namespace) becomes a direct cloud-credential-issuance primitive. The `OLLAMA_API_KEY` secret is also exposed to this action (`opencode.yml:31`). This is a higher-severity CI finding than F-SX-005's "no secret scanning." |
| Recommended Action | (1) Pin `anomalyco/opencode/github` to a commit SHA (M-SX-002). (2) Restrict `id-token: write` to only the steps that need it using a per-step `permissions:` override, or split into two jobs (one with id-token, one without). (3) Document which cloud OIDC providers this repo trusts and audit that list. (4) Add a `timeout-minutes` to the job (currently unset → default 360 min, a hijacked job runs for 6h). |
| Severity | HIGH — `id-token: write` + unpinned third-party action + exposed secret is the canonical GitHub Actions takeover → cloud impersonation chain. |
| Reference | [GitHub Actions OIDC hardening — "the most dangerous permission"; OWASP A08:2021 — Software and Data Integrity Failures (untrusted action with privileged token); GitHub security-hardening guide — pin actions + scope OIDC.] |

## Recommendations

1. **Highest-priority additions to the primary's flag:** Promote M-SX-002 (action pinning, esp. `opencode.yml` `@latest` + `id-token: write`) and M-SX-007 (OIDC isolation) into the blocking flag set. F-SX-005 ("no secret scanning") is a smaller subset of the CI supply-chain issue; the unpinned-privileged-action problem is the more exploitable path and was entirely missed.

2. **Reconcile tiering:** Retier F-SX-004 → LOW-MODERATE, F-SX-007 → LOW, F-SX-009 → informational. These three over-tiers dilute the blocking set and will cause the implementer to spend effort on low-impact hardening while M-SX-001/002/007 (real CI supply-chain exposure) go unaddressed.

3. **Close the rotation-design gaps before implementation:** The primary's flag says "implement the auth plan's §6.1–§6.9." My M-SX-003 (non-atomic credential write) and M-SX-004 (dev-recreate trusts stale file) show the auth plan *itself* has design defects that implementing it verbatim would propagate. Recommend a design-revision pass on `authentication-plan.md` §6.5 before code implementation — otherwise the code will faithfully encode a rotation that can silently revert to `test/test` on a crash.

4. **Add `FLOCI_AUTH_PRESIGN_SECRET` to the auth plan's scope (M-SX-006).** The current plan is narrowly focused on `floci-deployer` and ignores an independent secret that bypasses the IAM layer. This is a one-sided threat-model gap in the design document the primary reviewed but did not extend to.

5. **STS session duration (M-SX-005):** A one-line addition to `landing-zone-design.md` §5.4 (`DurationSeconds` bound + re-assumption cadence) closes an unspecified-exposure-window finding. Low effort, real risk reduction.

6. **Self-audit note:** The primary's self-audit checklist marks "AGENTS.md compliance: PASS." This is accurate for the systemd/AppArmor gotchas but the self-audit did not cover CI-workflow hardening (permissions, action pinning, OIDC scoping) — which is where 4 of my 7 one-sided findings live. Recommend the Security Reviewer's checklist add a "CI/CD supply-chain" row.

7. **Routing:** The primary routed to `code-architect` for auth-plan implementation. I concur with that routing, but add `devops-specialist` for the CI hardening findings (M-SX-001/002/007) — those are workflow-file changes, not application code, and the code-architect's scope (per AGENTS.md) is application architecture.

---

## Synthesis

The primary review is **substantively correct on the application/IAM layer** — the `FLOCI_AUTH_MODE` gap (F-SX-003), the `test/test` credential exposure (F-SX-001/002), and the IRSA stand-in gaps (F-SX-006) are all real and well-referenced. The CONDITIONAL PASS verdict is defensible for those findings.

However, the primary review has **two blind spots that change the blocking set:**

- **CI/CD supply chain:** The primary's only CI finding (F-SX-005) is the *weakest* of the CI issues. The missing `permissions:` block (M-SX-001), the unpinned `@latest` action with `id-token: write` (M-SX-002/M-SX-007), and the OIDC-token-exposure chain are higher-severity and fully absent from the A1 review. A security review of an artifact set that includes `.github/workflows/test.yml` should have examined *all* workflows in that directory, not just the one named in the task scope — `opencode.yml` is a sibling workflow with a privileged token and a third-party action, and it was not read.

- **The auth plan as a design document:** The primary treated the auth plan as the *specification* against which the code is measured (correctly), but did not critique the specification itself. M-SX-003 (non-atomic rotation write) and M-SX-004 (stale-file trust on dev-recreate) are design defects in the auth plan that, if implemented verbatim, would introduce the silent-fallback-to-`test/test` path the entire rotation is meant to prevent. A Phase A security review should review the *design* for security, not just the code-vs-design delta.

**Net effect on the verdict:** I agree with CONDITIONAL PASS, but the *blocking* set should be expanded from {F-SX-001/002/003/004/005/006} to also include {M-SX-001, M-SX-002, M-SX-007} (the CI supply-chain blockers) and M-SX-003 (the auth-plan design defect). The implementation flag should require a design-revision pass on auth-plan §6.5 before code-architect implements it.
