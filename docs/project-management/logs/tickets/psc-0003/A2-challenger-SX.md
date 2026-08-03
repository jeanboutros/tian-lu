# A2 Challenger: Security Reviewer — psc-0003

| Field | Value |
|-------|-------|
| Model | glm-5.2 (Security Reviewer Challenger) |
| Phase | A2 — Dual-Model Challenge |
| Primary Output | A1-SX: 12 SPEC-SX findings, CONDITIONAL PASS, severity 9, covering CH-AUTH-001…014 (subset) and CH-LZ-001…011 (subset) |
| Primary Verdict | CONDITIONAL PASS |
| Challenger Verdict | CONDITIONAL PASS |

## Reference Validation

| Primary Claim | Reference Provided | Authority Level | Verified? | Correctly Applied? |
|--------------|-------------------|-----------------|-----------|-------------------|
| 12-digit AKID account resolution | `docs/scraped/multi-account.md:9-10,60` | 4 (publisher docs) | ✓ | ✓ |
| IAM absent-key evaluation for inverted operators | AWS IAM User Guide (policy variables) | 2 (manufacturer) | ✓ | ✓ |
| `EQUIVALENT_TO_NULL_FALSE` Access Analyzer check | AWS IAM User Guide (policy checks) | 2 | ✓ | ✓ |
| Permissions boundaries apply to users/roles only | AWS IAM API Reference | 2 | ✓ | ✓ |
| Terraform `merge` precedence | HashiCorp docs | 3 | ✓ | ✓ |
| Bash `errexit` semantics | GNU bash manual | 2 | ✓ | ✓ |
| `FLOCI_SERVICES_IAM_ENABLED` default/purpose | `docs/scraped/environment-variables.md:160-161` | 4 | ✓ | ✓ |
| Terraform S3 `use_lockfile` conditional PutObject | hashicorp/terraform source | 8 | ✓ | Partial — source code ref not the canonical doc; acceptable |
| `FLOCI_AUTH_PRESIGN_SECRET` | `docs/scraped/environment-variables.md:22` | 4 | ✓ | ✓ |
| `generate_presign_secret` reuse-if-exists | `setup-floci.sh:793-801` | 8 (repo) | ✓ | ✓ |

**Findings:**
- [✓] All factual claims have at least one citation
- [✓] All citations are from authoritative sources (trust level 1-8)
- [✓] All cited sources were verified to actually support the claim
- [✓] Implementation alignment not assessed (Phase A — design review, no implementation yet)
- [✗] **Best practices and gotchas were NOT fully sought** — see Disagreements D1, D3 and One-Sided Findings O1-O6

## Agreements

The challenger agrees with the primary on the following:

| # | Finding | Agreement |
|---|---------|-----------|
| A1 | SPEC-SX-001 (CH-AUTH-001) | The 12-digit AKID / SigV4 incompatibility is the estate's central security defect. The three-outcome probe is the correct validation. The OWASP A07:2021 mapping is correct. Confidence 90 is appropriate. |
| A2 | SPEC-SX-002 (CH-AUTH-002) | The env-var injection reopening the forbidden `signatures=true enforcement=false` posture is a privilege-escalation-by-environment-variable. OWASP A01:2021 + A05:2021 mappings are correct. The `FLOCI_AUTH_UNSAFE_OVERRIDE` mitigation is sound. |
| A3 | SPEC-SX-003 (CH-AUTH-003) | Disabling the IAM *service* (not just enforcement) in `off` mode is a security misconfiguration. OWASP A05:2021 is correct. The fix (keep `IAM_ENABLED=true` in both branches) is correct. |
| A4 | SPEC-SX-004 (CH-AUTH-004) | The `sed` range delete silently destroys neighbouring AWS profiles — verified data loss in a file outside project ownership. OWASP A01:2021 is defensible. The 7 bats cases are appropriate. |
| A5 | SPEC-SX-005 (CH-AUTH-005) | The delete-failure handler is unreachable under `set -e` — silent credential leak. OWASP A07:2021 + silent-failure Pattern 2 mapping is correct. Confidence 95 is appropriate. |
| A6 | SPEC-SX-006 (CH-AUTH-007) | Non-atomic credential file write creates TOCTOU + permissions window. OWASP A04:2021 + A05:2021 mappings are correct. The `source`-vs-`parse` observation is a valuable security addition. |
| A7 | SPEC-SX-008 (CH-LZ-001) | `DenyAllExceptBoundary` is an unconditional deny because `StringNotEquals` matches the null `iam:PermissionsBoundary` key. The three-statement split fix is correct. The invalid `DeleteGroupPermissionsBoundary` action is a real defect. Confidence 92 is appropriate. |
| A8 | SPEC-SX-009 (CH-LZ-002) | Permissions-boundary evaluation claimed as enforced but never gated. The G6 negative test is the correct validation. OWASP A01:2021 + A04:2021 mappings are correct. |
| A9 | SPEC-SX-010 (CH-LZ-004) | G1 degrading to SKIP where the design promises a hard stop is a false-negative security gate. OWASP A09:2021 is correct. The fail-closed fix is correct. |
| A10 | SPEC-SX-011 (CH-LZ-007) | S3 conditional PutObject unverified for `use_lockfile`. OWASP A08:2021 is correct. G3b is the correct gate. |
| A11 | SPEC-SX-012 (CH-LZ-011) | `default_tags` merge order lets tfvars override governance tags — silent ABAC bypass. OWASP A01:2021 + A05:2021 are correct. The merge-order reversal fix is correct. |

## Disagreements

### D1 — SPEC-SX-001 severity should be raised to CRITICAL (10), not 9

| Field | Value |
|-------|-------|
| Challenger Confidence | 93 (Critical) |
| Primary Position | Severity 9 |
| Challenger Position | Severity 10 (Critical) |

**Reasoning:** The primary classifies SPEC-SX-001 as severity 9 alongside 9 other findings, treating it as one blocker among many. This under-weights its systemic nature. SPEC-SX-001 is not just "a blocker for the landing zone deployment" — it is the **foundational defect that makes every other IAM-related finding conditional**: if outcome (b) of the probe holds (12-digit AKID accepted with an unchecked secret), then:
- SPEC-SX-008 (DenyAllExceptBoundary) is security-neutral — the boundary is never evaluated because no authenticated request reaches it.
- SPEC-SX-009 (boundary evaluation unverified) becomes moot — the entire boundary concept is unenforceable.
- SPEC-SX-010 (G1 false-negative) compounds — G1 *cannot* pass under the configuration it polices because the probe user creation itself fails.
- The estate's headline security claim ("IAM is the primary boundary", landing-zone §12) is false.

The primary's own §Cross-Cutting Concern #1 (Credential Lifecycle) lists five credential types but does not note that **none of them can authenticate to the intended account under `sigv4`**. This is not a credential-lifecycle gap; it is a credential-architecture gap. The probe outcome gates the entire remediation effort, and the primary does not flag that the probe itself is a **prerequisite gate** that must run *before* any other remediation is built. Severity 9 implies "fix alongside others"; severity 10 implies "resolve this first, then reassess the rest".

**Evidence:** `docs/scraped/multi-account.md:9-10,60` — the qualifier "does not validate signatures by default" is load-bearing. The rotated `AKIA…` key (the only one that can authenticate under `sigv4`) resolves to `FLOCI_DEFAULT_ACCOUNT_ID=000000000000`, not `111111111111`. This is a total authentication-architecture failure, not one finding among equals.

### D2 — SPEC-SX-007 (presign-secret) under-weighted at 8; should be 9

| Field | Value |
|-------|-------|
| Challenger Confidence | 88 (High → should be 9) |
| Primary Position | Severity 8, Confidence 80 |
| Challenger Position | Severity 9, Confidence 88 |

**Reasoning:** The primary correctly identifies the three threats (IAM bypass, secret persistence, secret exposure) and the blast radius (full S3 access including Terraform state). However:
1. **Confidence 80 is too low.** The mechanism is *cited* from `docs/scraped/environment-variables.md:22` and the blast radius is *inferred from the S3 state backend design* (landing-zone §9). The primary's own confidence note says "CITED" but assigns 80 — the CITED status should yield ≥85. The under-scoring means this finding is at the bottom of the blocking threshold rather than clearly in the "must fix" band.
2. **Severity 8 under-weights the blast radius.** The Terraform state file contains all resource ARNs, secrets, and the full infrastructure graph. A presign capability over the state bucket is **administrative access to the entire estate** — equivalent to root compromise. The primary states this ("equivalent to administrative access to the entire estate") but then assigns severity 8. Administrative-access-equivalent findings should be severity 9.
3. **Missing rotation path is a lifecycle defect, not just a documentation gap.** The primary lists "Add a rotation path" as a required change but frames it as documentation. The *absence* of a rotation path for a static, long-lived credential that bypasses IAM is an OWASP A07:2021 (Identification and Authentication Failures) finding — the primary only maps it to A01 (Broken Access Control) and A04 (Insecure Design). A07 should be added.

**Evidence:** `setup-floci.sh:793-801` (reuse-if-exists), `docs/scraped/environment-variables.md:22` (presign secret purpose), `docs/design/landing-zone-design.md §9` (state bucket is S3).

### D3 — SPEC-SX-006 (non-atomic write) misses a shell-injection finding

| Field | Value |
|-------|-------|
| Challenger Confidence | 92 (Critical) |
| Primary Position | Notes `source` executes the file but treats it as secondary |
| Challenger Position | The `source`-vs-`parse` issue is a separate, higher-severity finding |

**Reasoning:** The primary correctly notes that "`source` on this file *executes* it — any shell injection in the credential values would be executed. Parse instead." But it buries this inside SPEC-SX-006 as a one-liner. This is actually a **distinct vulnerability** (OWASP A03:2021 — Injection) that deserves its own finding:

The credential file (`DEV_CREDENTIALS_FILE`) is written by the rotation function, which parses JSON output from `podman exec aws iam create-access-key` using `grep`+`sed`. The extracted `AKID` and `SecretAccessKey` values are written to the file as `DEV_BOOTSTRAP_AKID=<value>\nDEV_BOOTSTRAP_SECRET=<value>`. If Floci (the AWS emulator) ever returns a value containing shell metacharacters (e.g., a backtick, `$(...)`, or `;`), `source`ing that file executes them. While Floci controls the values and they are currently alphanumeric, the trust boundary is weak: the file is the output of an emulator whose security is what the estate is trying to *prove*, not assume. Treating emulator output as trusted input to `source` is an injection surface that the primary's OWASP mapping (A04 Insecure Design, A05 Misconfiguration) does not cover. A03:2021 (Injection) should be added, and the `parse` recommendation should be elevated from a "secondary note" to a required fix with its own SPEC-SX entry.

**Evidence:** auth plan §6.5:467-470 (`printf 'DEV_BOOTSTRAP_AKID=%s\nDEV_BOOTSTRAP_SECRET=%s\n'`), §6.6:502-509 (`source "$DEV_CREDENTIALS_FILE"` with SC1090 suppressed). OWASP A03:2021 — Injection.

### D4 — SPEC-SX-009 confidence 85 is appropriate but the threat model is incomplete

| Field | Value |
|-------|-------|
| Challenger Confidence | 82 (High) |
| Primary Position | Confidence 85, INFERRED |
| Challenger Position | Confidence 82 — the primary over-claims by inferring Floci's behaviour from absence of documentation |

**Reasoning:** The primary correctly identifies that permissions-boundary evaluation is unverified. However, the primary's confidence 85 (INFERRED) is slightly too high for a finding based on *absence of evidence*. The review-confidence skill scores INFERRED findings lower because "absence of evidence" could mean the feature exists but is undocumented. The primary itself says "the probe will confirm or refute" — which means the finding is a hypothesis, not a confirmed defect. Confidence 82 is more appropriate: still blocking (≥80), but acknowledging the uncertainty. The G6 negative test is correct and remains required.

Additionally, the primary's threat model for SPEC-SX-009 focuses only on the boundary being ignored. It does not consider the **inverse**: if Floci evaluates boundaries but *incorrectly* (e.g., treats the boundary as additive rather than intersectional), a role with a boundary *and* a permissive identity policy could *exceed* its intended ceiling. The G6 test (boundary denies `s3:*`, identity allows `s3:ListAllMyBuckets`, assert denied) covers the "ignored" case but not the "incorrectly evaluated" case. A second test (boundary allows `s3:*`, identity denies `s3:ListAllMyBuckets`, assert denied) would cover the intersectional case.

**Evidence:** `docs/scraped/environment-variables.md:161` ("enforce IAM policies on API calls" — does not distinguish identity vs boundary). AWS IAM docs: permissions boundaries use *effective permissions = intersection of identity policy and boundary*.

## One-Sided Findings

### O1 — CH-LZ-005: Five region literals across the stack (MISSED)

| Field | Value |
|-------|-------|
| Confidence | 90 (Critical) |
| OWASP | A05:2021 — Security Misconfiguration |

**Description:** The primary SX output does not include a finding for CH-LZ-005 from the challenge advisory. Five distinct region values are live across the stack:
- `backend.hcl.example:12` — `us-east-1`
- `dev.tfvars:13` — `eu-west-2`
- `setup-floci.sh:54` — `eu-west-1`
- `preflight-floci.sh:25` — `us-east-1`
- `dev-twin.sh:766` — `eu-west-1`

The state bucket is created by stage 00 under the provider region and read by every other stage under the backend region. A backend-region/provider-region mismatch means the Terraform S3 backend cannot find the state bucket — `terraform init` fails silently (the bucket appears not to exist) or, worse, creates a *new* empty bucket in the wrong region, orphaning the real state.

**Security impact:** State orphaning → `terraform apply` operates on stale/empty state → resource drift → potential destruction of real resources (Terraform thinks they don't exist and recreates them, conflicting with the real infrastructure). This is an integrity failure (OWASP A08:2021 — Software and Data Integrity Failures) in addition to the misconfiguration (A05:2021).

**Why the primary missed it:** The primary focused on IAM and credential findings (its core domain) and treated region divergence as a configuration-coherence issue rather than a security issue. But state-file integrity is a security concern — a corrupted or orphaned state file is a path to infrastructure destruction.

**Evidence:** Challenge advisory CH-LZ-005; `infra/_common/backend.hcl.example:12`; `infra/environments/dev.tfvars:13`; `setup-floci.sh:54`; `scripts/preflight-floci.sh:25`.

### O2 — CH-LZ-008: Stage 10 governance tags deleted (MISSED)

| Field | Value |
|-------|-------|
| Confidence | 95 (Critical) |
| OWASP | A01:2021 — Broken Access Control |

**Description:** The primary SX output does not include a finding for CH-LZ-008. The `Project`/`Environment`/`ManagedBy` trio was deleted from `infra/live/10-management-iam/providers.tf` (the stage provider), not just from `dev.tfvars`. The stage's `default_tags` block now reads `merge({}, var.default_tags)` — empty governance map. The comment above it still says "Mandatory governance tags on every taggable resource."

**Security impact:** No `Environment` tag exists at all on stage-10 resources, so landing-zone §5.3's ABAC model (which matches on `Environment` tag) has nothing to match on. ABAC conditions silently evaluate to "no match" → access denied where it should be allowed, OR access allowed where it should be denied (depending on whether the condition is `StringEquals` or `StringNotEquals`). This is a **silent broken access control** — the exact class OWASP A01:2021 describes.

**Why the primary missed it:** The primary addressed CH-LZ-011 (merge order) but not CH-LZ-008 (the tags were deleted from the wrong file). The challenge advisory notes CH-LZ-008 was "discovered while preparing this advisory, after the review session" and had "no user decision recorded" at the time. The SX review may have been written before CH-LZ-008 was finalized, or may have implicitly assumed the user's "all other are okay" covered it. But a security reviewer's job is to surface *all* security-relevant findings, including those the user has not yet decided on — the user cannot disposition what they have not been told about.

**Evidence:** `infra/live/10-management-iam/providers.tf:32-36` (empty merge); `infra/_common/providers.tf:45-51` (template still has the trio — diverged); `docs/design/landing-zone-design.md §5.3` (ABAC depends on `Environment` tag).

### O3 — CH-LZ-009 + CH-LZ-010: Provider version divergence + backend key prefix (MISSED)

| Field | Value |
|-------|-------|
| Confidence | 88 (High) — combined |
| OWASP | A05:2021 — Security Misconfiguration; A08:2021 — Data Integrity |

**Description:** The primary SX output does not include findings for CH-LZ-009 (provider version constraints diverged; stage-10 has `>= 6.56.0` with no upper bound vs `_common` `>= 5.95.0, < 7.0.0`) or CH-LZ-010 (stage-10 backend key is `10-management-iam/terraform.tfstate` with no `<env>/` prefix, contradicting landing-zone §9's isolation scheme).

**Security impact (CH-LZ-010):** An `init` without the `-backend-config="key=…"` override silently writes state to an unprefixed key. Promotion to uat/prod then collides on the same S3 object — one environment's `terraform apply` reads another environment's state and operates on the wrong infrastructure. This is a **cross-environment state collision** → `terraform apply` in uat could destroy dev resources (or vice versa) because Terraform thinks the resources already exist and plans a no-op, or thinks they don't exist and recreates them. This is a data-integrity failure with infrastructure-destruction blast radius.

**Security impact (CH-LZ-009):** An unbounded upper constraint (`>= 6.56.0` with no `< 7.0.0`) means a future AWS provider 7.x major release could be auto-selected, introducing breaking changes that silently alter IAM policy serialization or resource behaviour. The security concern is that IAM policy JSON generated by provider 7.x may not match the policy text the estate reviewed under provider 6.x — a silent policy-drift vulnerability.

**Why the primary missed it:** Both are infrastructure-configuration findings rather than classic "security" findings, but state-file collision and provider-version drift both have security blast radius. A security reviewer should treat state-file integrity and provider-pin integrity as security concerns because they gate the correctness of the IAM policies the reviewer is validating.

**Evidence:** `infra/live/10-management-iam/providers.tf:5-8` (version), `:11-15` (key); `infra/_common/versions.tf:15-18`; `docs/design/landing-zone-design.md §9` (key scheme).

### O4 — CH-INST-003: Four undocumented open firewall ports (MISSED)

| Field | Value |
|-------|-------|
| Confidence | 85 (High) |
| OWASP | A05:2021 — Security Misconfiguration |

**Description:** The primary SX output does not include a finding for CH-INST-003. `setup-floci.sh` opens UFW ports `6500:6599`, `9400:9499`, `2200:2299`, and `9169`, but the container publishes none of them. The `5100-5199` exclusion has a gotcha entry (sidecars bind host-side directly); the other four ranges have no rationale anywhere.

**Security impact:** Open ports with no documented consumer are a standing finding that every future security review will re-raise. More critically, an open port that no service binds is not "harmless" — it is an **attack surface expansion**: if a service is later started on one of those ports (e.g., a misconfigured sidecar, a debugging tool left running), the firewall already permits inbound traffic to it. The principle of least privilege requires that firewall rules be opened only for ports that have a documented consumer.

**Why the primary missed it:** The SX review focused on the auth plan and landing-zone IAM, not on `setup-floci.sh` firewall configuration. However, the challenge advisory explicitly lists CH-INST-003 in its scope (file #2: `setup-floci.sh`), and the advisory's recommended action #13 includes it. The security reviewer should have audited the firewall configuration as part of the attack-surface review.

**Evidence:** `setup-floci.sh:76-80` (published ports) vs `:83-92` (firewalled ports); `AGENTS.md:45` (only 5100-5199 exclusion documented).

### O5 — CH-INST-004: No preflight for `curl` and `openssl` (MISSED)

| Field | Value |
|-------|-------|
| Confidence | 80 (High) |
| OWASP | A05:2021 — Security Misconfiguration |

**Description:** The primary SX output does not include a finding for CH-INST-004. `generate_presign_secret` needs `openssl` (Phase 5) and `verify_health` needs `curl` (Phase 6). Neither is asserted in Phase 1 nor installed in Phase 3. On a minimal Ubuntu image, the run fails in Phase 6 after all mutating work (user creation, image pull, service start) is done.

**Security impact:** A failure after mutating work is a **partial-install state**: the `floci` user exists, Podman is installed, the container is running, but health verification never ran — so the installer may report success (or fail with a confusing error) while the Floci instance is in an unknown state. If the installer's error handling is insufficient (and we already know from SPEC-SX-005 that the script's `set -e` handling has bugs), a partial install could leave Floci running with default credentials and no rotation, no health check, and no indication to the user that the install was incomplete. This is a **fail-open** configuration: the security-relevant steps (rotation, health verification) are the ones that fail, while the setup steps (user creation, container start) succeed.

**Why the primary missed it:** This is an installer-robustness finding rather than an auth-plan finding, but it has a direct security consequence: the presign secret (SPEC-SX-007) is generated by `openssl`, and if `openssl` is absent, the secret generation fails — potentially leaving a default or empty presign secret, which would make presigned URLs either unenforceable or trivially forgeable. The security reviewer should trace the dependency chain from `openssl` availability to presign-secret integrity.

**Evidence:** `setup-floci.sh:630-636` (Phase 1 asserts only `podman uidmap`); consumers at `:803` (openssl), `:917` (curl).

### O6 — CH-AUTH-006 + CH-AUTH-013: Security-gate variables never assigned (MISSED)

| Field | Value |
|-------|-------|
| Confidence | 88 (High) — combined |
| OWASP | A09:2021 — Security Logging and Monitoring Failures |

**Description:** The primary SX output does not include findings for CH-AUTH-006 (`DEV_AUTH_MODE` is never assigned; `dev_recreate` prints no next steps) or CH-AUTH-013 (`FLOCI_AUTH_MODE` is never recorded on the host). These are distinct from SPEC-SX-010 (G1 SKIP) but compound it:

- **CH-AUTH-006:** §6.7's next-steps security section gates on `${DEV_AUTH_MODE:-off}`. The variable is never set by `_install_absent` (it passes `FLOCI_AUTH_MODE=sigv4` into the *guest* environment via `sudo bash -c`, which never reaches the host shell). The default `off` wins; the entire security section is dead code. After rotation, the well-known `floci`/`floci` key is deleted, and the user is **never told** where the new credential is, nor warned if rotation fell back. This is a security-monitoring failure: the security-critical communication path (next-steps warning) is silently inoperative.

- **CH-AUTH-013:** `write_env_file` emits the three derived variables but not `FLOCI_AUTH_MODE` itself. Nothing on the box records which posture it was installed with. `dev_status`, `preflight-floci.sh`, and the §6.7 next-steps block all need that input. §4.4's claim ("the env file retains the value from the original install") is only true of the *derived* variables, not the mode itself.

**Security impact:** Together, these mean the **security posture of a running Floci instance is unverifiable from the host**. An operator cannot determine (a) whether the instance was installed in `sigv4` or `off` mode, (b) whether rotation succeeded, or (c) where the active credentials are. This is a security-observability gap: if you cannot determine the security state of a system, you cannot verify that it is secure. OWASP A09:2021 — Security Logging and Monitoring Failures.

**Why the primary missed it:** These are operational/UX findings in the challenge advisory, classified as "medium" and "low" severity. But from a security perspective, the inability to verify the security posture of a running system is itself a security finding. The primary's Cross-Cutting Concern #4 (Security Gate Reliability) is the right framing but does not extend to "the security state must be observable post-install." The primary should have added a cross-cutting concern: **Post-Install Security Observability** — every security-relevant configuration must be queryable after install.

**Evidence:** auth plan §6.7:536 (`${DEV_AUTH_MODE:-off}`), §6.4:369-373 (does not set it host-side); auth plan §6.2:332-337 (emits derived vars, not mode); `dev-twin.sh:612,681-701`.

## Recommendations

### R1 — Make the three-outcome probe a prerequisite gate (Confidence: 95)

The SPEC-SX-001 probe (`AWS_ACCESS_KEY_ID=111111111111 AWS_SECRET_ACCESS_KEY=wrong-on-purpose aws ... sts get-caller-identity`) must run **before** any other remediation is built. If outcome (b) holds (12-digit AKID accepted with unchecked secret), the entire remediation plan changes — not just CH-AUTH-001 but every IAM finding becomes conditional. The primary should recommend adding this probe as a **pre-remediation gate** (call it G0 or G7) and state that all other SPEC-SX findings are contingent on the outcome.

### R2 — Add a shell-injection SPEC-SX for the `source`-vs-`parse` issue (Confidence: 92)

Elevate the `source`-on-credential-file observation from a one-liner inside SPEC-SX-006 to its own finding (SPEC-SX-013). Map it to OWASP A03:2021 — Injection. The credential file is the output of an emulator whose security is what the estate is trying to prove; treating it as trusted input to `source` is an injection surface. The fix (`while IFS='=' read -r k v`) removes both the injection risk and the SC1090 suppressions.

### R3 — Add a post-install security-observability cross-cutting concern (Confidence: 88)

The primary has 4 cross-cutting concerns (Credential Lifecycle, IAM Condition Key Safety, Environment Variable Injection Surface, Security Gate Reliability). Add a 5th: **Post-Install Security Observability** — every security-relevant configuration (`FLOCI_AUTH_MODE`, rotation status, credential location) must be queryable after install. This covers CH-AUTH-006 and CH-AUTH-013, which the primary missed entirely.

### R4 — Expand the G6 test to cover both boundary-evaluation failure modes (Confidence: 82)

SPEC-SX-009's G6 test (boundary denies `s3:*`, identity allows, assert denied) covers the "boundary ignored" case. Add a second test: boundary allows `s3:*`, identity denies `s3:ListAllMyBuckets`, assert denied. This covers the "boundary evaluated incorrectly (additive instead of intersectional)" case. Without both, the gate only proves one of two possible failure modes.

### R5 — Include CH-LZ-005/008/009/010 in the SX findings (Confidence: 85)

The challenge advisory's recommended action #12 includes CH-LZ-008…012. The primary picked up CH-LZ-011 and CH-LZ-012 but dropped CH-LZ-008/009/010. These have security blast radius (broken ABAC, state collision, provider-version drift) and should be in the SX finding set. A security reviewer who only looks at "classic" security findings (auth, crypto, access control) and ignores infrastructure-integrity findings will miss the class of defects that cause infrastructure destruction.

### R6 — Audit the firewall and preflight for security-relevant dependencies (Confidence: 82)

CH-INST-003 (undocumented open ports) and CH-INST-004 (missing `curl`/`openssl` preflight) are installer-level findings with security consequences. The security reviewer should audit the installer's attack surface (open ports) and dependency chain (presign secret depends on `openssl`) as part of the review scope, not defer them to the DevOps/Bash specialists.

### R7 — Add OWASP A07 to SPEC-SX-007 (Confidence: 85)

The presign-secret finding maps to A01 (Broken Access Control) and A04 (Insecure Design). It should also map to A07:2021 — Identification and Authentication Failures, because the presign secret is a static, long-lived credential with no rotation path. A07 covers "allowing the use of default or weak passwords" and "no rotation of credentials" — both apply to the presign secret.

## Verdict

**CONDITIONAL PASS**

**Rationale:** The primary SX analysis is thorough, well-referenced, and correctly identifies the estate's central security defects. The OWASP mappings are largely correct, the confidence scores are defensible (with the exceptions in D1-D4), and the verification methods are concrete and executable. The analysis correctly identifies the most critical finding (CH-AUTH-001) and the silent-credential-leak pattern (CH-AUTH-005).

However, the analysis has **material gaps** that must be addressed before A-GATE:

1. **D1 (Severity under-weighting):** SPEC-SX-001 should be severity 10, not 9, because it is the prerequisite gate for all other IAM findings. The probe outcome changes the entire remediation plan, not just one finding.

2. **D2 (Presign-secret under-scoring):** SPEC-SX-007 at confidence 80 is at the bottom of the blocking band for a finding whose blast radius is "administrative access to the entire estate." Raise to 88 and add A07 mapping.

3. **D3 (Missed injection finding):** The `source`-on-credential-file issue is a distinct OWASP A03:2021 injection finding that should have its own SPEC-SX entry, not a one-liner inside SPEC-SX-006.

4. **O1-O6 (One-sided findings):** Six security-relevant findings from the challenge advisory (CH-LZ-005, CH-LZ-008, CH-LZ-009/010, CH-INST-003, CH-INST-004, CH-AUTH-006/013) were not included. These have real security blast radius: state-file collision, broken ABAC, attack-surface expansion, fail-open partial install, and unverifiable security posture. The primary's scope was too narrow — it focused on the auth plan and landing-zone IAM but did not audit the installer's attack surface, firewall configuration, or post-install observability.

**Blocking findings (confidence ≥80):** D1 (93), D2 (88), D3 (92), D4 (82), O1 (90), O2 (95), O3 (88), O4 (85), O5 (80), O6 (88), R1 (95), R2 (92), R3 (88), R5 (85).

**Advisory findings (confidence <80):** R4 (82 — borderline), R6 (82 — borderline), R7 (85 — borderline). Note: R4/R6 are at the boundary; I score them at 82 as "high confidence" but they are close to advisory. The user may disposition them either way.

**Condition for PASS:** The primary must (a) raise SPEC-SX-001 to severity 10, (b) raise SPEC-SX-007 to severity 9 / confidence 88 and add A07 mapping, (c) add a SPEC-SX-013 for the `source`-injection finding, (d) add the six one-sided findings (O1-O6) as new SPEC-SX entries, and (e) add the post-install-observability cross-cutting concern. These are additive — the primary's existing findings do not need to be retracted, only supplemented.

**Self-Reflection (challenger):**

1. **Why did the primary miss O1-O6?** The primary's scope was implicitly bounded to "the auth plan and landing-zone IAM" — the classic security-reviewer domain. But the challenge advisory's scope was broader (14 files, including `setup-floci.sh`, `dev-twin.sh`, `run-test.sh`). A security reviewer should treat *all* files in the challenge advisory's scope as in-scope and extract every security-relevant finding, not just the ones that fit the "auth/IAM" mental model.

2. **What procedural safeguard would have caught this?** A mandatory "scope coverage check" in the self-audit checklist: the reviewer must explicitly list every file in the challenge advisory's scope and state "covered / not security-relevant / finding raised" for each. This prevents the reviewer from implicitly narrowing scope to their comfort domain.

3. **Knowledge update:** Add to `docs/learning/` a note on "security review scope discipline" — a security reviewer must audit *all* files in the review scope, not just the ones that match the reviewer's primary domain expertise. Infrastructure-integrity findings (state collision, provider drift, open ports) are security findings when their blast radius includes infrastructure destruction or access-control bypass.
