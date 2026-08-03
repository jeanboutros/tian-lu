# A2: Dual-Model Challenge Synthesis — psc-0003

| Field | Value |
|-------|-------|
| Phase | A2 — Dual-Model Challenge |
| Ticket | psc-0003 |
| Source | psc-adv-0017-challenge-review |
| Primaries | A1-SW, A1-TX, A1-DX, A1-SX, A1-BS, A1-DO |
| Challengers | A2-challenger-SW, A2-challenger-TX, A2-challenger-DX, A2-challenger-SX, A2-challenger-BS, A2-challenger-DO |
| Date | 2026-07-30 |

## Summary

| Specialist | Primary Verdict | Challenger Verdict | Disagreements | One-Sided | Recommendations |
|------------|----------------|-------------------|---------------|-----------|-----------------|
| SW | CONDITIONAL PASS | CONDITIONAL PASS | 4 | 6 | 8 |
| TX | APPROVED | CONDITIONAL PASS | 5 | 7 | 11 |
| DX | APPROVED | CONDITIONAL PASS | 3 | 6 | 8 |
| SX | CONDITIONAL PASS | CONDITIONAL PASS | 4 | 6 | 7 |
| BS | CONDITIONAL PASS | CONDITIONAL PASS | 3 | 10 | 8 |
| DO | CONDITIONAL PASS | CONDITIONAL PASS | 4 | 10 | 11 |

**Key cross-cutting themes:**
- **The three-outcome probe (CH-AUTH-001) is a keystone gate** — SW, SX, TX, and DX challengers all independently identified that it must be a Phase B entry gate, not a deferrable acceptance criterion. Its outcome gates the entire remediation plan.
- **Scope omissions are systemic** — TX dropped 33/49 findings, DX dropped CH-AUTH-013, SX dropped 6 LZ/INST findings, DO dropped 9 TWIN/DEV findings. The primaries implicitly narrowed scope to their comfort domains.
- **The `opencode.yml` pipeline-security gap** (DO D-1/O-2) is the highest-severity finding in the repo's CI/CD surface and was missed by all primaries.

---

## 1. Disagreements

### D-1 — SPEC-SW-010 directly contradicts user decision on upper bound

| Field | Value |
|-------|-------|
| Finding ID | D-1 |
| Specialist pair | SW vs SW-challenger |
| Confidence | 95 (Critical — blocks) |
| Primary position | SPEC-SW-010 proposes `>= 6.56.0, < 7.0.0` with upper bound; acceptance criterion: "All stages use `aws >= 6.56.0, < 7.0.0`" |
| Challenger position | A0-task-definition.md:44 records user decision as "CH-LZ-009: >= 6.56.0 with NO upper bound." The SW either did not consult A0 or followed the advisory over the user decision. |
| Recommendation | Revise SPEC-SW-010 to `>= 6.56.0` with no upper bound, matching A0:44. Record supply-chain risk as a gaps-register advisory, not an acceptance criterion. |

### D-2 — SPEC-SW-001 under-weights three-outcome probe as Phase B gate

| Field | Value |
|-------|-------|
| Finding ID | D-2 |
| Specialist pair | SW vs SW-challenger |
| Confidence | 85 (High — should fix) |
| Primary position | Probe listed as acceptance criterion #6 among six items — a deferrable documentation step. |
| Challenger position | The probe is a keystone verification whose outcome determines whether multiple SPECs are meaningful. Outcome (b) means the estate's headline security claim is false. It must be a blocking prerequisite for Phase B. |
| Recommendation | Promote the three-outcome probe to a Phase B entry gate. No implementation SPEC proceeds until the probe result is known. Route to DO/BS for execution and SX for interpretation. |

### D-3 — SPEC-SW-006 conflates CH-LZ-001 (policy fix) with CH-LZ-002 (boundary evaluation unverified)

| Field | Value |
|-------|-------|
| Finding ID | D-3 |
| Specialist pair | SW vs SW-challenger |
| Confidence | 85 (High — should fix) |
| Primary position | CH-LZ-002 bundled as acceptance criterion #6 in SPEC-SW-006 ("G6 negative test added per CH-LZ-002"). |
| Challenger position | CH-LZ-002 is a standalone high-severity finding with distinct architectural implication: Floci may not evaluate boundaries at all. Bundling it treats it as a test-addition task rather than a finding that may invalidate the delegated-administration architecture. |
| Recommendation | Create SPEC-SW-015 for CH-LZ-002 with G6 as primary gate, dependency on the probe, §1.1 qualification requirement, and SX/TX/DO dependencies. |

### D-4 — SPEC-SW-004 confidence 100 conflates "definitely real" with "must fix/blocking"

| Field | Value |
|-------|-------|
| Finding ID | D-4 |
| Specialist pair | SW vs SW-challenger |
| Confidence | 80 (High — should fix) |
| Primary position | SPEC-SW-004 (CH-AUTH-012, split §6.10a–d) rated confidence 100. |
| Challenger position | Confidence 100 implies blocking, but the SW's verdict states "Blocking findings: None." A documentation structure issue is definitely real but not Critical/blocking. Either adjust to 90 or note the process-finding exception. |
| Recommendation | Adjust SPEC-SW-004 confidence to 90, or explicitly note that process findings can be confidence 100 without blocking the pipeline. |

### D-5 — TX Self-Audit Checklist partially evasive

| Field | Value |
|-------|-------|
| Finding ID | D-5 |
| Specialist pair | TX vs TX-challenger |
| Confidence | 90 (Critical) |
| Primary position | Self-audit marks 7/11 rows "N/A — Phase A" and several "yes" without evidence. |
| Challenger position | The self-audit certifies fidelity while dropping 33/49 findings. "Spec/datasheet fidelity: yes" is asserted but cross-referencing is selective. A self-audit that certifies fidelity while omitting 33 findings is not a passing self-audit. |
| Recommendation | Re-run the self-audit honestly — mark fidelity "partial" until all 49 findings are scoped. |

### D-6 — TX test-count arithmetic internally inconsistent

| Field | Value |
|-------|-------|
| Finding ID | D-6 |
| Specialist pair | TX vs TX-challenger |
| Confidence | 100 (Critical) |
| Primary position | Overview states "28 new + 3 modified across 7 test files"; Test File Summary table totals "26 new + 3 modified." |
| Challenger position | 26 is the reconciled number; "28" in the overview is wrong and never corrected. A requirements doc whose headline count doesn't match its own table misleads Phase B implementers. |
| Recommendation | Fix the test-count arithmetic. Use 26 (reconciled) or re-count after re-scoping to all 49 findings. |

### D-7 — TX SPEC-TX-103-3 claims "real kill" but kill is bash builtin

| Field | Value |
|-------|-------|
| Finding ID | D-7 |
| Specialist pair | TX vs TX-challenger |
| Confidence | 95 (Critical) |
| Primary position | Implementation detail says test "uses real `sleep` and `kill` commands." |
| Challenger position | On macOS, `kill` is a bash shell builtin, not `/bin/kill`. Auth plan §6.11 mandates a `kill` symlink to `_stub` with `STUB_RC_KILL`. The primary and auth plan disagree on whether `kill` is stubbed. |
| Recommendation | Resolve the `kill` stub contradiction between A1-TX ("real kill") and auth plan §6.11 (`kill` symlink with `STUB_RC_KILL`). Pick one and document it. |

### D-8 — TX SPEC-TX-112 stub claim "aws stub (existing)" is false

| Field | Value |
|-------|-------|
| Finding ID | D-8 |
| Specialist pair | TX vs TX-challenger |
| Confidence | 98 (Critical) |
| Primary position | Repeatedly asserts an `aws` stub already exists in `tests/stubs/bin/` as "a symlink to `_stub`." |
| Challenger position | Verified: `tests/stubs/bin/` has 19 entries — there is no `aws` symlink. SPEC-TX-112, 113, and 114 all depend on an `aws` stub that does not exist and must be created from scratch with per-subcommand control. |
| Recommendation | Create the `aws` stub before any preflight test is written. Specify it as a dedicated subcommand-aware stub (like `tests/stubs/bin/podman`), not a one-line symlink. |

### D-9 — TX SPEC-TX-105 stub claim incomplete

| Field | Value |
|-------|-------|
| Finding ID | D-9 |
| Specialist pair | TX vs TX-challenger |
| Confidence | 95 (Critical) |
| Primary position | Lists `uname` stub as "new symlink to `_stub` in `mock-server/tests/stubs/bin/`" but doesn't state the symlink target. |
| Challenger position | The Stub Requirements Summary table does not state that `_stub` lives at `mock-server/tests/stubs/_stub` and the symlink target is `../_stub`. An implementer following the table literally would create a dangling symlink. |
| Recommendation | Document the full symlink path: `mock-server/tests/stubs/bin/uname -> ../_stub`. |

### D-10 — DX SPEC-DX-007 cites wrong AGENTS.md line numbers

| Field | Value |
|-------|-------|
| Finding ID | D-10 |
| Specialist pair | DX vs DX-challenger |
| Confidence | 95 (Critical) |
| Primary position | Title is "Refresh AGENTS.md:57 and :64"; acceptance criteria assert `AGENTS.md:57` and `AGENTS.md:64`. |
| Challenger position | Verified: actual gotcha text lives at AGENTS.md:60 (enable-linger line) and AGENTS.md:67 (TLS line). The primary propagated the advisory's imprecise line references without re-verifying against the current file. |
| Recommendation | Change title and acceptance criteria to "AGENTS.md:60 and :67" or reference the gotcha by leading text (robust to reflow). |

### D-11 — DX SPEC-DX-005 omits psc-0002 precedent that preserved "crypto theater"

| Field | Value |
|-------|-------|
| Finding ID | D-11 |
| Specialist pair | DX vs DX-challenger |
| Confidence | 80 (High) |
| Primary position | Mandates replacing "Crypto theater" everywhere. |
| Challenger position | psc-0002 C1 dual-model challenge explicitly ruled this usage a PASS — distinguishing it from a rejected "security theater" pejorative. The primary proposes a directly contradictory change without acknowledging or overturning that prior verdict. |
| Recommendation | SPEC-DX-005 must reference the psc-0002 C1 verdict it is superseding, state why CH-AUTH-016 overrides it, and scope the grep to exclude `docs/project-management/logs/` historical artifacts. |

### D-12 — DX SPEC-DX-006 presents inferred firewall-range rationale as fact

| Field | Value |
|-------|-------|
| Finding ID | D-12 |
| Specialist pair | DX vs DX-challenger |
| Confidence | 85 (High) |
| Primary position | Assigns service names to four undocumented ranges: 6500-6599 = "EKS k3s API server", 9400-9499 = "OpenSearch data plane", 2200-2299 = "EC2 SSH", 9169 = "EC2 IMDS." |
| Challenger position | Only k3s API (6500-6599) is corroborated (GAP-013b). The other three are plausible inferences but unverified. Presenting inferences as established rationale violates the authoritative-reference skill. The primary also silently dropped the advisory's removal alternative. |
| Recommendation | Label 9400-9499, 2200-2299, 9169 as INFERRED pending verification, OR adopt the advisory's removal alternative: if a range's consumer cannot be confirmed, remove the UFW rule. |

### D-13 — SX SPEC-SX-001 severity should be 10, not 9

| Field | Value |
|-------|-------|
| Finding ID | D-13 |
| Specialist pair | SX vs SX-challenger |
| Confidence | 93 (Critical) |
| Primary position | Severity 9 — one blocker among many. |
| Challenger position | Severity 10 (Critical) — it is the foundational defect that makes every other IAM-related finding conditional. If outcome (b) holds, the estate's headline security claim is false. Severity 9 implies "fix alongside others"; severity 10 implies "resolve this first, then reassess the rest." |
| Recommendation | Raise SPEC-SX-001 to severity 10. Make the three-outcome probe a prerequisite gate (G0) that must run before any other remediation is built. |

### D-14 — SX SPEC-SX-007 under-weighted at severity 8 / confidence 80

| Field | Value |
|-------|-------|
| Finding ID | D-14 |
| Specialist pair | SX vs SX-challenger |
| Confidence | 88 (High) |
| Primary position | Severity 8, Confidence 80. Maps to OWASP A01 + A04. |
| Challenger position | Confidence 80 is too low for a CITED finding. Severity 8 under-weights the blast radius (administrative access to entire estate via state bucket). Missing rotation path is an OWASP A07:2021 finding, not just a documentation gap. |
| Recommendation | Raise to severity 9, confidence 88. Add OWASP A07:2021 mapping for the missing credential rotation path. |

### D-15 — SX SPEC-SX-006 misses a shell-injection finding

| Field | Value |
|-------|-------|
| Finding ID | D-15 |
| Specialist pair | SX vs SX-challenger |
| Confidence | 92 (Critical) |
| Primary position | Notes `source` executes the credential file but treats it as secondary — a one-liner inside SPEC-SX-006. |
| Challenger position | This is a distinct OWASP A03:2021 (Injection) vulnerability. The credential file is the output of an emulator whose security is what the estate is trying to prove. Treating emulator output as trusted input to `source` is an injection surface. |
| Recommendation | Elevate to its own SPEC-SX-013 with OWASP A03:2021 mapping. The `while IFS='=' read -r k v` parse fix removes both the injection risk and SC1090 suppressions. |

### D-16 — SX SPEC-SX-009 threat model incomplete

| Field | Value |
|-------|-------|
| Finding ID | D-16 |
| Specialist pair | SX vs SX-challenger |
| Confidence | 82 (High) |
| Primary position | Confidence 85, INFERRED. G6 test covers "boundary ignored" case. |
| Challenger position | Confidence 85 is slightly too high for a finding based on absence of evidence. The threat model does not consider the inverse: if Floci evaluates boundaries incorrectly (additive instead of intersectional), a role could exceed its intended ceiling. A second G6 test is needed. |
| Recommendation | Adjust confidence to 82. Add a second G6 test: boundary allows `s3:*`, identity denies `s3:ListAllMyBuckets`, assert denied — covering the intersectional failure mode. |

### D-17 — BS SPEC-BS-005 `printf '%q'` version claim is FALSE

| Field | Value |
|-------|-------|
| Finding ID | D-17 |
| Specialist pair | BS vs BS-challenger |
| Confidence | 95 (Critical) |
| Primary position | References table claims "`printf '%q'` format specifier introduced in bash 4.0." |
| Challenger position | Verified: `printf '%q'` works on bash 3.2.57 (`/bin/bash -c 'printf "%q\n" "hello world"'` → `hello\ world`). The `%q` format specifier predates bash 4.0. This factual error undermines the SPEC-BS-005 recommendation rationale. |
| Recommendation | Correct the References table. Reframe SPEC-BS-005: the guard is needed for empty-array `set -u` safety on 3.2, not for `printf '%q'`. |

### D-18 — BS bash-4+ precondition recommendation should be reconsidered

| Field | Value |
|-------|-------|
| Finding ID | D-18 |
| Specialist pair | BS vs BS-challenger |
| Confidence | 80 (High) |
| Primary position | Recommends adding `(( BASH_VERSINFO[0] >= 4 ))` precondition to `run-test.sh`. |
| Challenger position | The existing codebase deliberately supports bash 3.2 on the host side (parallel arrays at run-test.sh:455-456, `${arr[@]+…}` guards). Adding a bash-4+ precondition would contradict that deliberate design choice. |
| Recommendation | Do not add a bash-4+ gate without explicitly deciding to drop existing 3.2 compatibility. Keep the guard; `printf '%q'` is 3.2-safe. |

### D-19 — BS SPEC-BS-005 bundles `[*]`→`[@]` fix without calling it out

| Field | Value |
|-------|-------|
| Finding ID | D-19 |
| Specialist pair | BS vs BS-challenger |
| Confidence | 90 (Critical) |
| Primary position | Code sketch changes `${driver_args[*]+"${driver_args[*]}"}` to `${driver_args[@]+"${driver_args[@]}"}` but only justifies the guard retention. |
| Challenger position | The `[*]`→`[@]` change is an independent correctness fix: under `IFS=$'\n\t'`, `[*]` joins elements with newline producing a single field on re-split for multi-element arrays. Both fixes are required but only one is documented. |
| Recommendation | Split SPEC-BS-005 into two findings: (a) guard retention for `set -u` empty-array safety, (b) `[*]`→`[@]` for multi-element array correctness under `IFS=$'\n\t'`. |

### D-20 — DO under-weights opencode.yml as CI/CD attack surface

| Field | Value |
|-------|-------|
| Finding ID | D-20 |
| Specialist pair | DO vs DO-challenger |
| Confidence | 90 (Critical) |
| Primary position | opencode.yml treated as out of scope; no SPEC-DO finding covers it. |
| Challenger position | opencode.yml triggers on `issue_comment` (untrusted input from forks), requests `id-token: write`, runs `anomalyco/opencode/github@latest` (floating tag, not SHA-pinned) with `OLLAMA_API_KEY` injected. This is a textbook OWASP CI/CD Top-10 vector. Severity 8 — higher than the primary's top severity of 7. |
| Recommendation | Add SPEC-DO-018: pin `anomalyco/opencode/github@latest` to full SHA, add `environment:` with required reviewers, reduce `permissions` to minimum. |

### D-21 — DO Dependabot recommendation incomplete

| Field | Value |
|-------|-------|
| Finding ID | D-21 |
| Specialist pair | DO vs DO-challenger |
| Confidence | 85 (High) |
| Primary position | Recommends only `package-ecosystem: "github-actions"` for Dependabot. |
| Challenger position | The real supply-chain surface is container images (`docker.io/floci/floci:1.5.33-compat`) and Lima templates. Dependabot's `docker` ecosystem would track the Floci image tag. The `github-actions` ecosystem will not pin `@latest` to a SHA — that is a manual fix. |
| Recommendation | Add `docker` ecosystem to Dependabot for Floci image tag drift. Explicitly state that pinning `@latest` is a manual, one-time fix. |

### D-22 — DO SPEC-DO-009 `--fresh`/`--keep` over-specified and self-contradictory

| Field | Value |
|-------|-------|
| Finding ID | D-22 |
| Specialist pair | DO vs DO-challenger |
| Confidence | 80 (High) |
| Primary position | Acceptance criterion 3: "`--fresh` and `--keep` are mutually exclusive; the last one wins." |
| Challenger position | Mutual exclusivity and "last one wins" are contradictory. "Last wins" perpetuates the order-dependence bug being fixed. Also: making `--keep` the default conflicts with `Makefile:30` default `TWIN_FLAGS ?= --fresh --reboot-test`. |
| Recommendation | Pick one model: either reject the combination (`die "mutually exclusive"`) or make `--fresh` imply `--destroy`. Reconcile with `Makefile:30`. |

### D-23 — DO SPEC-DO-014 lint check should be terraform validate, not shell diff

| Field | Value |
|-------|-------|
| Finding ID | D-23 |
| Specialist pair | DO vs DO-challenger |
| Confidence | 75 (Advisory) |
| Primary position | Recommends "a lint check (shell script or Makefile target) that verifies every `infra/live/*/providers.tf` matches `_common/providers.tf` in its structural elements." |
| Challenger position | A shell-based structural diff of HCL is brittle (whitespace, block ordering, comments). The authoritative check is `terraform fmt -check` + `terraform validate` + optionally `checkov`. CI does not currently install Terraform. |
| Recommendation | Specify `terraform fmt -check` + `terraform validate` as the lint mechanism. Acknowledge the new CI capability required (Terraform install in `test.yml`). |

---

## 2. One-Sided Findings

### Priority Band: Critical (confidence ≥90)

#### M-1 — TX dropped 33 of 49 accepted findings (FLAG-1)

| Field | Value |
|-------|-------|
| Finding ID | M-1 |
| Source challenger | TX-challenger |
| Confidence | 100 |
| Description | The primary covered 16 findings and declared "16/16 TX-relevant findings" and "GAPS: None." That claim is false. 33 findings — including high-severity items (CH-AUTH-003, CH-AUTH-005, CH-INST-001, CH-DEV-002/003/004/005, CH-LZ-008) — have no test specification. CH-AUTH-003 requires modifying an existing test spec (SPEC-TX-006 case 3) and the primary does not even mention it. |
| Recommended action | Re-scope to all 49 accepted findings. Produce test specs (or explicit "documentation-only / not testable" dispositions with reasoning) for every omitted finding. |

#### M-2 — CH-LZ-002 (boundary evaluation unverified) has no standalone SPEC

| Field | Value |
|-------|-------|
| Finding ID | M-2 |
| Source challenger | SW-challenger |
| Confidence | 90 |
| Description | The advisory has CH-LZ-002 as a standalone high-severity finding. The SW analysis has no SPEC-SW for it — referenced only as acceptance criterion #6 in SPEC-SW-006. CH-LZ-002's architectural implication: Floci may not implement permissions-boundary evaluation at all, making the entire delegated-administration ceiling modeled, not enforced. |
| Recommended action | Create SPEC-SW-015 for CH-LZ-002 with G6 negative test as primary gate, dependency on the probe, §1.1 qualification requirement, and SX/TX/DO dependencies. |

#### M-3 — CH-AUTH-013 entirely absent from DX analysis

| Field | Value |
|-------|-------|
| Finding ID | M-3 |
| Source challenger | DX-challenger |
| Confidence | 95 |
| Description | CH-AUTH-013 ("`FLOCI_AUTH_MODE` is never recorded on the host") is a documentation-relevant finding the primary dropped entirely. `write_env_file` emits derived variables but not `FLOCI_AUTH_MODE` itself. §4.4's claim is false. `dev_status` and `preflight-floci.sh` need the mode as input. The primary's "13 findings analysed / 13 SPEC-DX" is a coverage overcount. |
| Recommended action | Add SPEC-DX-014 (CH-AUTH-013): update §6.2 to emit `FLOCI_AUTH_MODE`; correct §4.4's retention claim; specify `dev_status` surfaces the mode. |

#### M-4 — SX missed CH-LZ-008 (stage 10 governance tags deleted)

| Field | Value |
|-------|-------|
| Finding ID | M-4 |
| Source challenger | SX-challenger |
| Confidence | 95 |
| Description | The `Project`/`Environment`/`ManagedBy` trio was deleted from `infra/live/10-management-iam/providers.tf`. The stage's `default_tags` block reads `merge({}, var.default_tags)` — empty governance map. No `Environment` tag exists, so landing-zone §5.3's ABAC model has nothing to match on. Silent broken access control. |
| Recommended action | Include CH-LZ-008 in SX findings. Restore governance tags in stage 10 provider. Add lint check that every `infra/live/*/providers.tf` matches `_common/providers.tf`. |

#### M-5 — SX missed CH-LZ-005 (five region literals across stack)

| Field | Value |
|-------|-------|
| Finding ID | M-5 |
| Source challenger | SX-challenger |
| Confidence | 90 |
| Description | Five distinct region values live across the stack: `backend.hcl.example:12` (us-east-1), `dev.tfvars:13` (eu-west-2), `setup-floci.sh:54` (eu-west-1), `preflight-floci.sh:25` (us-east-1), `dev-twin.sh:766` (eu-west-1). Backend-region/provider-region mismatch means state orphaning → potential infrastructure destruction. |
| Recommended action | Include CH-LZ-005 in SX findings. Unify all five region literals to a single source of truth per environment. |

#### M-6 — DO missed test.yml lacks permissions: block

| Field | Value |
|-------|-------|
| Finding ID | M-6 |
| Source challenger | DO-challenger |
| Confidence | 92 |
| Description | `.github/workflows/test.yml` has no top-level or job-level `permissions:` key. GITHUB_TOKEN defaults to broad read/write. For a lint+unit job that only needs to read code, the token should be `permissions: { contents: read }` at minimum. |
| Recommended action | Add `permissions: { contents: read }` to `test.yml` (SPEC-DO-019). |

#### M-7 — DO missed make lint doesn't cover preflight-floci.sh or infra/ Terraform

| Field | Value |
|-------|-------|
| Finding ID | M-7 |
| Source challenger | DO-challenger |
| Confidence | 90 |
| Description | `Makefile:39` lints specific files — none is `scripts/preflight-floci.sh` or any `.tf`/`.hcl` file. SPEC-DO-010 acceptance criterion 5 requires "shellcheck on `preflight-floci.sh`" but `make lint` does not run it. The primary's own acceptance criteria reference a lint target that does not exist for the file being fixed. |
| Recommended action | Add `scripts/preflight-floci.sh` to `make lint` scope. Add a `make lint-infra` target for Terraform files. |

### Priority Band: High (confidence 80–89)

#### M-8 — CH-LZ-007 (use_lockfile S3-native locking unverified) missing from SW

| Field | Value |
|-------|-------|
| Finding ID | M-8 |
| Source challenger | SW-challenger |
| Confidence | 85 |
| Description | The advisory has CH-LZ-007: S3-native locking (`use_lockfile = true`) is offered as alternative to DynamoDB locking, but no gate verifies Floci's S3 honours `IfNoneMatch: "*"`. The SW analysis covers 9 of 13 LZ findings but omits CH-LZ-007. |
| Recommended action | Create SPEC for CH-LZ-007. Add G3b gate or mark `use_lockfile` unverified in §9 and `backend.hcl.example`. |

#### M-9 — CH-LZ-003 and CH-LZ-004 missing from SW

| Field | Value |
|-------|-------|
| Finding ID | M-9 |
| Source challenger | SW-challenger |
| Confidence | 85 |
| Description | CH-LZ-003 (G1 mislabelled; design never names enforcement variables) and CH-LZ-004 (G1 degrades to SKIP where design promises hard stop) are preflight-gate findings in the SW/DO domain. The SW analysis touches preflight in SPEC-SW-001 but does not address CH-LZ-003 or CH-LZ-004. CH-LZ-004 interacts with SPEC-SW-001 and SPEC-SW-003 — the three must be implemented together. |
| Recommended action | Create SPECs for CH-LZ-003 and CH-LZ-004. G1 must fail (not skip) when probe cannot be established. |

#### M-10 — SPEC-SW-001 doesn't flag §4.2 promotion model collapse

| Field | Value |
|-------|-------|
| Finding ID | M-10 |
| Source challenger | SW-challenger |
| Confidence | 88 |
| Description | SPEC-SW-001's fix moves the account axis from AKID to `FLOCI_DEFAULT_ACCOUNT_ID` (per-instance). Landing-zone §4.2's promotion model ("copy tfvars, change AKID, same code applies") is now false — promotion requires a new Floci instance. The SW lists this as a DX dependency without flagging the architectural implication. |
| Recommended action | Flag the §4.2 promotion model alteration as architectural. Route to SW/DO for review before DX writes it up. |

#### M-11 — CH-AUTH-014 under-weighted in SPEC-SW-014

| Field | Value |
|-------|-------|
| Finding ID | M-11 |
| Source challenger | SW-challenger |
| Confidence | 82 |
| Description | SPEC-SW-014 bundles four items into one finding. CH-AUTH-014 (presign secret IAM bypass) is architecturally distinct — it bypasses the IAM layer entirely, and the Terraform state bucket is S3. The SW bundles this into a "multiple documentation and hygiene gaps" finding. |
| Recommended action | Split CH-AUTH-014 into its own SPEC with SX dependency for the threat model, separate from documentation hygiene items. |

#### M-12 — No test for CH-AUTH-001 probe outcome

| Field | Value |
|-------|-------|
| Finding ID | M-12 |
| Source challenger | TX-challenger |
| Confidence | 90 |
| Description | CH-AUTH-001 is the highest-priority finding. The advisory specifies a three-outcome probe that must be run regardless of the chosen option. The primary's dependency table lists CH-AUTH-002 as priority 1; CH-AUTH-001 is absent entirely. No test spec exists for recording the probe outcome as a gap-register entry. |
| Recommended action | Record the CH-AUTH-001 probe outcome as a test-plan dependency — at minimum a gap-register-assertion test. |

#### M-13 — TX implementation-order dependency cycle under-analysed

| Field | Value |
|-------|-------|
| Finding ID | M-13 |
| Source challenger | TX-challenger |
| Confidence | 82 |
| Description | The dependency table lists CH-AUTH-006 "Blocks CH-AUTH-011" and CH-AUTH-011 "Depends on CH-AUTH-006" — a mutual dependency. In reality, 011 (introduce `DEV_AUTH_MODE`) must precede 006 (`_print_next_steps` uses `DEV_AUTH_MODE`). The "Blocks" column for 006 is wrong — 006 does not block 011; 011 blocks 006. |
| Recommended action | Correct the CH-AUTH-006 ↔ CH-AUTH-011 dependency direction. 011 introduces `DEV_AUTH_MODE`; 006 consumes it. 011 blocks 006, not vice versa. |

#### M-14 — DX CH-LZ-012 wrong-mechanism comment not corrected

| Field | Value |
|-------|-------|
| Finding ID | M-14 |
| Source challenger | DX-challenger |
| Confidence | 92 |
| Description | CH-LZ-012 explicitly states: correct both the `dev.tfvars` comment and auth plan §6.10c to state the real mechanism (merge precedence, silent override, no diagnostic). The primary's SPEC-DX-002 mentions §6.10c only as "already-landed, move to appendix" and never corrects the wrong-mechanism sentence inside it. Moving a wrong claim to an appendix preserves the error. |
| Recommended action | Add requirement to correct the mechanism wording in both `dev.tfvars:27-28` and `authentication-plan.md §6.10c` to "merge precedence silently overrides; no diagnostic." |

#### M-15 — DX CH-LZ-006 doc correction relegated to parenthetical

| Field | Value |
|-------|-------|
| Finding ID | M-15 |
| Source challenger | DX-challenger |
| Confidence | 88 |
| Description | CH-LZ-006 is a substantive doc defect: §6.10b prescribes deprecated `force_path_style`/`endpoint` backend args. The primary only mentions CH-LZ-006 once, parenthetically in SPEC-DX-002, and creates no acceptance criterion for actually correcting the §6.10b backend-init recipe. |
| Recommended action | Add explicit acceptance criterion: "§6.10b's `terraform init` recipe uses `-backend-config=../../_common/backend.hcl` + per-stage `key=` override only; deprecated args removed." |

#### M-16 — DX lessons-learned entries capture only 3 of 10 advisory rows

| Field | Value |
|-------|-------|
| Finding ID | M-16 |
| Source challenger | DX-challenger |
| Confidence | 85 |
| Description | The advisory's "Lessons-learned inputs" table has 10 rows. SPEC-DX-013 captures only rows 2, 3, 4 (CH-META-001/002/003). It omits 7 rows including: "re-read source line for qualifiers," "verify post-fix state, not just the diff," "distinguish specified from verified," "behavioural claims about the shell must be executed on the target interpreter," "every 'Enforced' row needs a named gate," and "if a convention says 'keep these identical,' add a check." |
| Recommended action | SPEC-DX-013 must specify all 10 lessons (or explicitly justify exclusions row-by-row). Name the specific skill each standing rule targets. |

#### M-17 — SX missed CH-LZ-009 + CH-LZ-010 (provider version divergence + backend key prefix)

| Field | Value |
|-------|-------|
| Finding ID | M-17 |
| Source challenger | SX-challenger |
| Confidence | 88 |
| Description | CH-LZ-009: stage-10 has `>= 6.56.0` with no upper bound vs `_common` `>= 5.95.0, < 7.0.0`. CH-LZ-010: stage-10 backend key is `10-management-iam/terraform.tfstate` with no `<env>/` prefix. Cross-environment state collision → `terraform apply` in uat could destroy dev resources. |
| Recommended action | Include CH-LZ-009 and CH-LZ-010 in SX findings. State-file collision and provider-version drift have security blast radius. |

#### M-18 — SX missed CH-INST-003 (four undocumented open firewall ports)

| Field | Value |
|-------|-------|
| Finding ID | M-18 |
| Source challenger | SX-challenger |
| Confidence | 85 |
| Description | `setup-floci.sh` opens UFW ports 6500:6599, 9400:9499, 2200:2299, and 9169, but the container publishes none of them. Open ports with no documented consumer are attack-surface expansion. |
| Recommended action | Include CH-INST-003 in SX findings. Audit the installer's attack surface (open ports) as part of the security review scope. |

#### M-19 — SX missed CH-AUTH-006 + CH-AUTH-013 (security-gate variables never assigned)

| Field | Value |
|-------|-------|
| Finding ID | M-19 |
| Source challenger | SX-challenger |
| Confidence | 88 |
| Description | CH-AUTH-006: `DEV_AUTH_MODE` is never assigned host-side; the entire security section is dead code. CH-AUTH-013: `FLOCI_AUTH_MODE` never recorded on host. Together, the security posture of a running Floci instance is unverifiable from the host. |
| Recommended action | Include CH-AUTH-006 and CH-AUTH-013 in SX findings. Add a cross-cutting concern: Post-Install Security Observability — every security-relevant configuration must be queryable after install. |

#### M-20 — BS configure_subuid_subgid numeric validation gap

| Field | Value |
|-------|-------|
| Finding ID | M-20 |
| Source challenger | BS-challenger |
| Confidence | 82 |
| Description | The overlap-detection loop uses `[[ "$candidate" -lt "$range_end" ]]` with arithmetic comparison on variables from `/etc/subuid` that may contain non-numeric values. If the file contains a malformed line, the `-lt` comparison produces "integer expression expected" which under `set -e` would abort. |
| Recommended action | Add a numeric-validation guard (`[[ "$range_start" =~ ^[0-9]+$ ]]`) before the `-lt`/`-gt` comparison in the overlap loop. |

#### M-21 — DO missed opencode.yml id-token: write + comment trigger + @latest action

| Field | Value |
|-------|-------|
| Finding ID | M-21 |
| Source challenger | DO-challenger |
| Confidence | 88 |
| Description | opencode.yml triggers on `issue_comment` (untrusted input), requests `id-token: write`, runs `anomalyco/opencode/github@latest` (floating tag) with `OLLAMA_API_KEY` injected. Even with `persist-credentials: false`, the OIDC token is available to the `@latest` action's code. |
| Recommended action | Pin action to full SHA. Add `environment:` with required reviewers. Reduce `permissions` to minimum. |

#### M-22 — DO missed no concurrency on opencode.yml

| Field | Value |
|-------|-------|
| Finding ID | M-22 |
| Source challenger | DO-challenger |
| Confidence | 85 |
| Description | opencode.yml has no `concurrency:` group. Two reviewers posting `/oc` on the same PR spawn two parallel jobs, both with `id-token: write`, both calling the LLM API. |
| Recommended action | Add `concurrency:` to opencode.yml grouped by PR/comment thread, `cancel-in-progress: true`. |

#### M-23 — DO missed no CI job validates HCL syntax

| Field | Value |
|-------|-------|
| Finding ID | M-23 |
| Source challenger | DO-challenger |
| Confidence | 82 |
| Description | CI (`test.yml`) installs only `shellcheck` and `bats`. No `terraform fmt -check`, no `terraform validate`. SPEC-DO-014–017 all prescribe changes to `.tf`/`.hcl` files and list `terraform validate` as acceptance criteria, but neither capability exists in CI. |
| Recommended action | Add a `terraform-validate` job to `test.yml` that installs Terraform, runs `terraform fmt -check -recursive` and `terraform -chdir=infra/live/<stage> validate` for each stage. |

#### M-24 — DO dropped CH-TWIN-002, CH-TWIN-004, CH-TWIN-007, CH-DEV-001–004, CH-DEV-006

| Field | Value |
|-------|-------|
| Finding ID | M-24 |
| Source challenger | DO-challenger |
| Confidence | 80 |
| Description | The primary's scope table lists only CH-DEV-005 for `dev-twin.sh` and CH-TWIN-001/003/005/006 for the test harness. Nine advisory findings (CH-TWIN-002/004/007, CH-DEV-001/002/003/004/006) were silently dropped with no deferral rationale. CH-DEV-003 (disk-exists conflates absent with query-failed) is a data-safety issue. |
| Recommended action | Add SPEC-DO entries for dropped findings or explicitly document deferral. At minimum, surface CH-DEV-003 (data safety) and CH-DEV-004 (silent breakage on documented override). |

### Priority Band: Moderate (confidence 70–79)

#### M-25 — TX SPEC-TX-106-1 false-positive risk

| Field | Value |
|-------|-------|
| Finding ID | M-25 |
| Source challenger | TX-challenger |
| Confidence | 85 |
| Description | SPEC-TX-106-1 asserts `validate_summary` passes when `sidecar-delta=PASS` and `NO_SIDECAR=false`. The FAIL-rejection case is described in prose but not as a discrete test case. An implementation that adds `sidecar-delta` to `mandatory` but breaks the FAIL-rejection path could pass 106-1/106-2. |
| Recommended action | Add a discrete FAIL-rejection test case for `sidecar-delta` — separate from 106-1/106-2. |

#### M-26 — TX SPEC-TX-107 marks MODIFY but describes no-op

| Field | Value |
|-------|-------|
| Finding ID | M-26 |
| Source challenger | TX-challenger |
| Confidence | 88 |
| Description | SPEC-TX-107-1 is labelled MODIFY, but the implementation detail says "The existing test … continues to work unchanged" and "no new test is needed." This is a non-modification presented as a modification, inflating the modified-test count. |
| Recommended action | Either state what assertion changes, or mark as "0 modified" not "1 modified." |

#### M-27 — TX no test for CH-TWIN-006 order-dependence direction

| Field | Value |
|-------|-------|
| Finding ID | M-27 |
| Source challenger | TX-challenger |
| Confidence | 85 |
| Description | SPEC-TX-110-3 tests `--fresh --keep` but defers the semantic decision. No RED test captures the current broken order-dependence (`--keep` after `--fresh` silently ignored, `--fresh` after `--keep` wins). |
| Recommended action | Add a RED test for the current `--fresh`/`--keep` order-dependence before the semantic decision. |

#### M-28 — TX SPEC-TX-101-7 weak structural integrity guard

| Field | Value |
|-------|-------|
| Finding ID | M-28 |
| Source challenger | TX-challenger |
| Confidence | 80 |
| Description | SPEC-TX-101-7 asserts "the first non-blank line is a section header." This guards against orphaned keys only for the first line. The `sed` bug can orphan keys at any boundary. |
| Recommended action | Strengthen to check no key line precedes the first section header at any position, not just line 1. |

#### M-29 — TX no coverage for bash-3.2 guard on actual test host

| Field | Value |
|-------|-------|
| Finding ID | M-29 |
| Source challenger | TX-challenger |
| Confidence | 88 |
| Description | CH-AUTH-009 is about `/bin/bash` 3.2 on macOS. A test that runs under Homebrew bash 5 would pass trivially and prove nothing. The test plan must specify `/bin/bash -c` explicitly. |
| Recommended action | Specify `/bin/bash` (3.2) as the interpreter for the CH-AUTH-009 test. |

#### M-30 — DX GAP-016 doesn't branch on probe result

| Field | Value |
|-------|-------|
| Finding ID | M-30 |
| Source challenger | DX-challenger |
| Confidence | 82 |
| Description | GAP-016's action says "verify the three-outcome probe result" but doesn't specify that the gap entry must record which outcome was observed and trigger a rewrite of auth-plan §8.3 + landing-zone §1.1 if outcome (b) holds. |
| Recommended action | GAP-016's action must state: "Run the probe; record the observed outcome (a/b/c); if outcome (b), auth-plan §8.3 and landing-zone §1.1 'Enforced' rows must be rewritten." |

#### M-31 — DX CH-INST-004 doc-consistency impact dropped

| Field | Value |
|-------|-------|
| Finding ID | M-31 |
| Source challenger | DX-challenger |
| Confidence | 75 |
| Description | CH-INST-004 (no preflight for `curl`/`openssl`) is framed as code-only. But `solution-design.md §12` and `docs/testing-guide.md` describe installer dependencies. If `openssl`/`curl` become Phase-1 assertions, those docs should be consistent. |
| Recommended action | Add note that `solution-design.md §12` and prerequisites list in `docs/testing-guide.md` must reflect the `openssl`/`curl` Phase-1 assertions. |

#### M-32 — SX missed CH-INST-004 (no preflight for curl/openssl)

| Field | Value |
|-------|-------|
| Finding ID | M-32 |
| Source challenger | SX-challenger |
| Confidence | 80 |
| Description | `generate_presign_secret` needs `openssl` (Phase 5) and `verify_health` needs `curl` (Phase 6). Neither is asserted in Phase 1. A failure after mutating work is a partial-install state — fail-open configuration where security-relevant steps fail while setup steps succeed. |
| Recommended action | Include CH-INST-004 in SX findings. Trace the dependency chain from `openssl` availability to presign-secret integrity. |

#### M-33 — BS FLOCI_HOST_PERSISTENT_PATH validation ordering

| Field | Value |
|-------|-------|
| Finding ID | M-33 |
| Source challenger | BS-challenger |
| Confidence | 88 |
| Description | `FLOCI_HOST_PERSISTENT_PATH` is used to derive `FLOCI_DATA_DIR` before validation. If validation fails, `exit 1` fires but `FLOCI_DATA_DIR` was already set from an invalid path. The character-class validation uses a long chain of `[[ ]]` glob negations which is hard to audit. |
| Recommended action | Reorder: validate before deriving `FLOCI_DATA_DIR`. Consider a positive-character-class allowlist instead of negation chain. |

#### M-34 — BS detect_hostname_and_ip || true masks failures

| Field | Value |
|-------|-------|
| Finding ID | M-34 |
| Source challenger | BS-challenger |
| Confidence | 80 |
| Description | `SERVER_IP="$(ip route get 1.1.1.1 2>/dev/null | awk '{...}' || true)"` — the `|| true` suppresses ALL failures including `awk` parse failures, leaving `SERVER_IP` empty silently. The subsequent `[[ -z ]]` check catches this, but the `|| true` masks the distinction between "ip route failed" and "awk produced no output." |
| Recommended action | Replace `|| true` with a more targeted error path, or add a diagnostic when `ip route` succeeds but `awk` yields empty. |

#### M-35 — BS _run_as_floci_guest injection surface

| Field | Value |
|-------|-------|
| Finding ID | M-35 |
| Source challenger | BS-challenger |
| Confidence | 78 |
| Description | `_run_as_floci_guest` passes `"$*"` (all args joined) into a single `bash -c` string. Arguments with spaces or special chars would be re-interpreted by the inner shell. Current call sites pass static strings, but the pattern is a latent command-injection trap. |
| Recommended action | Document that callers must not pass untrusted data. Ideally, refactor to use positional parameters: `bash -c '...' "$@"`. |

#### M-36 — BS generate_presign_secret no error check

| Field | Value |
|-------|-------|
| Finding ID | M-36 |
| Source challenger | BS-challenger |
| Confidence | 75 |
| Description | `PRESIGN_SECRET="$(openssl rand -hex 32)"` — no error check on `openssl` failure. If `openssl` is absent or fails, `PRESIGN_SECRET` is empty and `write_env_file` writes `FLOCI_AUTH_PRESIGN_SECRET=` (empty) to the env file. An empty presign secret means all presigned URLs are accepted with no signature verification. |
| Recommended action | Add `[[ -n "$PRESIGN_SECRET" ]] || { printf 'ERROR: failed to generate presign secret\n' >&2; exit 1; }` after the `openssl rand` call. |

#### M-37 — DO no assessment of deployment safety/rollback for infra/

| Field | Value |
|-------|-------|
| Finding ID | M-37 |
| Source challenger | DO-challenger |
| Confidence | 75 |
| Description | The `infra/` project has stages 00→10→20→30→40 with `terraform apply` per stage and no documented rollback or `terraform destroy` ordering. No `terraform plan` review gate, no `apply` confirmation, no state-import/rollback runbook. |
| Recommended action | Assess deployment-safety/reversibility for `infra/`. At minimum flag as an open item in the gaps register. |

### Priority Band: Low (confidence <70)

#### M-38 — BS here-string bashism not noted in portability

| Field | Value |
|-------|-------|
| Finding ID | M-38 |
| Source challenger | BS-challenger |
| Confidence | 85 |
| Description | `IFS='.' read -r octet1 octet2 octet3 _ <<< "$SERVER_IP"` uses a here-string (`<<<`), a bashism. The primary's blanket "None" portability assessments would be more accurate as "N/A — bash-only feature, consistent with shebang." |
| Recommended action | Refine portability assessment language to acknowledge bash-only constructs. No code change needed. |

#### M-39 — BS write_quadlet_unit empty publish_ports

| Field | Value |
|-------|-------|
| Finding ID | M-39 |
| Source challenger | BS-challenger |
| Confidence | 72 |
| Description | `publish_ports` is built by string concatenation; an empty value produces a blank line in the Quadlet file. ShellCheck SC2086 would flag the unquoted expansion. |
| Recommended action | Guard the `${publish_ports}` line: only emit it if non-empty, or build via array join. |

#### M-40 — BS wait_driver signal-kill misattribution

| Field | Value |
|-------|-------|
| Finding ID | M-40 |
| Source challenger | BS-challenger |
| Confidence | 70 |
| Description | `2>/dev/null` suppresses legitimate wait errors. A killed-by-signal driver (status 143) would be misattributed as a failure — the CH-AUTH-010 concern the primary notes but does not fix in SPEC-BS-019. |
| Recommended action | After fixing the empty-PID guard, also distinguish signal-kill (128+N) from genuine non-zero exit, per CH-AUTH-010. |

#### M-41 — BS enable_lingering C-style for loop bashism

| Field | Value |
|-------|-------|
| Finding ID | M-41 |
| Source challenger | BS-challenger |
| Confidence | 68 |
| Description | `for (( i=1; i<=USER_MANAGER_POLL_TRIES; i++ ))` — C-style for loop is a bashism. `(( i++ ))` under `errexit` returns exit status 1 when `i` is 0. Safe by luck of starting at 1. |
| Recommended action | Either start at 1 (current, safe) and document why, or use `(( i++ )) || true` defensively. |

#### M-42 — BS preflight_ports printf '%b' obscure

| Field | Value |
|-------|-------|
| Finding ID | M-42 |
| Source challenger | BS-challenger |
| Confidence | 65 |
| Description | `conflicts="${conflicts}${port}\n"` builds a string with literal `\n` then uses `printf '%b'` to interpret it. Works but is obscure. |
| Recommended action | Consider array-based accumulation for clarity; no functional change needed. |

#### M-43 — DO self-audit checklist largely "N/A"

| Field | Value |
|-------|-------|
| Finding ID | M-43 |
| Source challenger | DO-challenger |
| Confidence | 70 |
| Description | Primary's self-audit marks 10/15 rows "N/A" with "Not applicable to CI/CD pipeline design." Several are applicable: "No magic numbers" applies to Terraform examples; "Module boundary" applies to `infra/live/*` vs `_common/`. |
| Recommended action | Re-do the self-audit checklist with per-row reasoning rather than blanket "N/A." |

---

## 3. Recommendations

### Priority Band: Critical (confidence ≥90)

| ID | Source | Confidence | Recommendation | Priority |
|----|--------|-----------|----------------|----------|
| R-1 | SW-challenger | 95 | Revise SPEC-SW-010 to `>= 6.56.0` with no upper bound, matching A0:44 user decision | Critical |
| R-2 | SW-challenger | 90 | Promote three-outcome probe (CH-AUTH-001) to Phase B entry gate — no implementation SPEC proceeds until probe result is known | Critical |
| R-3 | SW-challenger | 90 | Create SPEC-SW-015 for CH-LZ-002 (boundary evaluation unverified) with G6 as primary gate | Critical |
| R-4 | TX-challenger | 100 | Re-scope TX to all 49 accepted findings with explicit dispositions for every omitted finding | Critical |
| R-5 | TX-challenger | 98 | Create `aws` stub (subcommand-aware, like `tests/stubs/bin/podman`) before any preflight test is written | Critical |
| R-6 | TX-challenger | 100 | Fix test-count arithmetic — overview says 28, table says 26; use reconciled number | Critical |
| R-7 | TX-challenger | 90 | Resolve `kill` stub contradiction between A1-TX ("real kill") and auth plan §6.11 (`kill` symlink with `STUB_RC_KILL`) | Critical |
| R-8 | TX-challenger | 90 | Re-run TX self-audit honestly — mark fidelity "partial" until all 49 findings are scoped | Critical |
| R-9 | DX-challenger | 95 | Fix AGENTS.md line numbers in SPEC-DX-007 — actual lines are 60 and 67, not 57 and 64 | Critical |
| R-10 | DX-challenger | 95 | Add SPEC-DX-014 for CH-AUTH-013 (FLOCI_AUTH_MODE never recorded on host) | Critical |
| R-11 | SX-challenger | 95 | Make three-outcome probe a prerequisite gate (G0) — all other SPEC-SX findings are contingent on the outcome | Critical |
| R-12 | SX-challenger | 92 | Add SPEC-SX-013 for `source`-on-credential-file shell-injection (OWASP A03:2021) | Critical |
| R-13 | BS-challenger | 95 | Correct `printf '%q'` version claim in References table — it works on bash 3.2.57, not bash 4.0+ | Critical |
| R-14 | BS-challenger | 90 | Split SPEC-BS-005 into two findings: (a) guard retention, (b) `[*]`→`[@]` for multi-element array correctness | Critical |
| R-15 | DO-challenger | 92 | Add `permissions: { contents: read }` to `test.yml` (SPEC-DO-019) | Critical |
| R-16 | DO-challenger | 90 | Pin `anomalyco/opencode/github@latest` to full SHA in `opencode.yml`; add `environment:` with required reviewers (SPEC-DO-018) | Critical |
| R-17 | DO-challenger | 90 | Add `scripts/preflight-floci.sh` to `make lint` scope | Critical |

### Priority Band: High (confidence 80–89)

| ID | Source | Confidence | Recommendation | Priority |
|----|--------|-----------|----------------|----------|
| R-18 | SW-challenger | 85 | Create SPECs for CH-LZ-003, CH-LZ-004, and CH-LZ-007 (missing from SW analysis) | High |
| R-19 | SW-challenger | 88 | Flag landing-zone §4.2 promotion model alteration as architectural, not just documentation | High |
| R-20 | SW-challenger | 82 | Split CH-AUTH-014 (presign secret IAM bypass) into its own SPEC | High |
| R-21 | SW-challenger | 80 | Gate `data.aws_caller_identity` precondition on probe result | High |
| R-22 | SW-challenger | 80 | Adjust SPEC-SW-004 confidence to 90 or note process-finding exception | High |
| R-23 | TX-challenger | 85 | Add discrete FAIL-rejection test case for `sidecar-delta` | High |
| R-24 | TX-challenger | 82 | Correct CH-AUTH-006 ↔ CH-AUTH-011 dependency direction — 011 blocks 006, not vice versa | High |
| R-25 | TX-challenger | 88 | Specify `/bin/bash` (3.2) as interpreter for CH-AUTH-009 test | High |
| R-26 | TX-challenger | 85 | Add RED test for current `--fresh`/`--keep` order-dependence before semantic decision | High |
| R-27 | TX-challenger | 90 | Record CH-AUTH-001 probe outcome as test-plan dependency | High |
| R-28 | TX-challenger | 80 | Strengthen SPEC-TX-101-7 to check no key line precedes first section header at any position | High |
| R-29 | DX-challenger | 92 | Add CH-LZ-012 mechanism correction as acceptance criterion | High |
| R-30 | DX-challenger | 88 | Promote CH-LZ-006 from parenthetical to explicit acceptance criterion in SPEC-DX-002 | High |
| R-31 | DX-challenger | 85 | Expand SPEC-DX-013 to all 10 advisory lessons-learned rows; name target skill per standing rule | High |
| R-32 | DX-challenger | 82 | Branch GAP-016 on probe outcome — record which outcome (a/b/c) and trigger doc rewrites if outcome (b) | High |
| R-33 | DX-challenger | 85 | Label SPEC-DX-006 inferred ranges as INFERRED or adopt advisory's removal alternative | High |
| R-34 | DX-challenger | 80 | Reference and supersede psc-0002 C1 verdict in SPEC-DX-005; scope grep to exclude historical artifacts | High |
| R-35 | SX-challenger | 88 | Raise SPEC-SX-007 to severity 9 / confidence 88; add OWASP A07:2021 mapping | High |
| R-36 | SX-challenger | 88 | Add post-install security-observability cross-cutting concern (covers CH-AUTH-006 + CH-AUTH-013) | High |
| R-37 | SX-challenger | 85 | Include CH-LZ-005, CH-LZ-008, CH-LZ-009, CH-LZ-010 in SX findings | High |
| R-38 | SX-challenger | 82 | Expand G6 test to cover both boundary-evaluation failure modes (ignored + incorrectly evaluated) | High |
| R-39 | SX-challenger | 82 | Audit firewall and preflight for security-relevant dependencies (CH-INST-003, CH-INST-004) | High |
| R-40 | BS-challenger | 82 | Add numeric validation to `configure_subuid_subgid` overlap loop | High |
| R-41 | BS-challenger | 80 | Add post-generation assertion for `PRESIGN_SECRET` — empty secret is security bypass | High |
| R-42 | BS-challenger | 80 | Reconsider bash-4+ precondition — existing codebase deliberately supports bash 3.2 on host side | High |
| R-43 | DO-challenger | 85 | Add `docker` ecosystem to Dependabot for Floci image tag; note that pinning `@latest` is manual | High |
| R-44 | DO-challenger | 85 | Add `concurrency:` to `opencode.yml` (SPEC-DO-020) | High |
| R-45 | DO-challenger | 82 | Add `terraform-validate` job to `test.yml` (SPEC-DO-021) | High |
| R-46 | DO-challenger | 80 | Revise SPEC-DO-009 — pick one model (mutual exclusion or `--fresh` implies `--destroy`), not "last wins" | High |
| R-47 | DO-challenger | 80 | Add SPEC-DO entries for dropped findings (CH-TWIN-002/004/007, CH-DEV-003/004) or document deferral | High |

### Priority Band: Moderate (confidence 70–79)

| ID | Source | Confidence | Recommendation | Priority |
|----|--------|-----------|----------------|----------|
| R-48 | BS-challenger | 78 | Document `_run_as_floci_guest` injection surface; ideally refactor to use positional parameters | Moderate |
| R-49 | BS-challenger | 72 | Refine portability assessments — replace blanket "None" with "N/A — bash-only construct, consistent with shebang" | Moderate |
| R-50 | BS-challenger | 70 | Address `wait_driver` signal-kill misattribution jointly with CH-AUTH-010 | Moderate |
| R-51 | DO-challenger | 75 | Revise SPEC-DO-014 — specify `terraform fmt -check` + `terraform validate`, not shell structural diff | Moderate |
| R-52 | DO-challenger | 75 | Assess deployment-safety/reversibility for `infra/`; flag as open item in gaps register | Moderate |
| R-53 | DO-challenger | 70 | Re-do self-audit checklist with per-row reasoning rather than blanket "N/A" | Moderate |

---

## 4. Agreements — Proposed Consolidated Actions

The following actions are confirmed by both primary and challenger across all six specialist pairs. These represent the uncontested remediation work for psc-0003.

### Authentication Plan (CH-AUTH)

| ID | Finding | Agreed Action | Confirmed By |
|----|---------|---------------|-------------|
| A-1 | CH-AUTH-001 | Move account axis from AKID to `FLOCI_DEFAULT_ACCOUNT_ID` (per-instance). Change `_common/providers.tf` `access_key` to deployer's real AKID. Add `data.aws_caller_identity` precondition. Update landing-zone §4.1/§4.2. | SW, SX, DX |
| A-2 | CH-AUTH-002 | Rewrite §4.2 with `FLOCI_AUTH_UNSAFE_OVERRIDE=1` escape hatch. Derive posture unconditionally from `FLOCI_AUTH_MODE`. `unset _auth_on` after use. Add bats case proving hole closed. | SW, SX, BS, TX |
| A-3 | CH-AUTH-003 | `FLOCI_SERVICES_IAM_ENABLED=true` in both branches (or omit, defaulting to `true`). Only `FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED` tracks the mode. Correct §6.2 note and SPEC-TX-006 case-3. | SW, SX |
| A-4 | CH-AUTH-004 | Replace `sed` range delete with `awk` section-aware rewrite + atomic write (`.tmp` + `chmod 0600` + `mv -f`). Add 7 bats cases. | SX, TX, BS |
| A-5 | CH-AUTH-005 | `delete_rc=0; cmd || delete_rc=$?` — the `||` creates a condition context suppressing `errexit`. Audit §6.5 for same pattern. | SX, BS |
| A-6 | CH-AUTH-007 | Atomic `.tmp`+`chmod`+`mv` for credential file. Parse with `while IFS='=' read -r k v` instead of `source`. | SX, BS |
| A-7 | CH-AUTH-008 | Replace string `$AWS_CREDS_ENV` with array-based `-e` overrides. Use `${arr[@]+"${arr[@]}"}` guard. | BS |
| A-8 | CH-AUTH-009 | Retain `${arr[@]+…}` guard for bash 3.2 `set -u` safety. Adopt `printf '%q '` for shell-escaping (3.2-safe). | BS |
| A-9 | CH-AUTH-010 | Re-derive `wait_driver` hang. Distinguish exit codes: 0=success, 143=killed-after-timeout, other=driver failure. | TX |
| A-10 | CH-AUTH-011 | Add `readonly DEV_AUTH_MODE="${DEV_AUTH_MODE:-sigv4}"`. Gate `_rotate_bootstrap_credentials` on mode. Pass to installer. | BS |
| A-11 | CH-AUTH-012 | Split §6.10a–d into "Changes already applied" appendix and "Pending changes" section. | SW, DX |
| A-12 | CH-AUTH-014 | Add presign-secret threat model to `solution-design.md §8.2`. Document rotation path and reuse-if-exists behaviour. Cross-link from landing-zone §9/§12. | SX, DX |
| A-13 | CH-AUTH-015 | Mark §9.3 items as "Specified — not yet verified" instead of "Fixed." | DX |
| A-14 | CH-AUTH-016 | Replace "Crypto theater" with factual description. | DX |

### Installer (CH-INST)

| ID | Finding | Agreed Action | Confirmed By |
|----|---------|---------------|-------------|
| A-15 | CH-INST-001 | Retry 5xx in `verify_health`; fail fast on 4xx. Capture `last_code` for timeout message. | BS, DO |
| A-16 | CH-INST-002 | Per-binary AppArmor sentinel. Extend twin hash set to include AppArmor profiles. | BS, DO |
| A-17 | CH-INST-003 | Document or drop four extra firewall ranges (6500:6599, 9400:9499, 2200:2299, 9169). | DX, DO |
| A-18 | CH-INST-004 | Assert `curl` and `openssl` in Phase 1 preflight. | BS, DO |
| A-19 | CH-INST-005 | Refresh AGENTS.md:60 and :67 line references. | DX |

### Dev Twin (CH-DEV)

| ID | Finding | Agreed Action | Confirmed By |
|----|---------|---------------|-------------|
| A-20 | CH-DEV-001 | Call `_print_next_steps` from `dev_recreate`. | BS |
| A-21 | CH-DEV-002 | Call `dev_env` on Running/Stopped resume paths in `dev_up`. | BS |
| A-22 | CH-DEV-003 | Distinct return codes from `dev_disk_exists`: 0=present, 1=absent, 2=query-failed. Update all callers. | BS |
| A-23 | CH-DEV-004 | Derive `DEV_DISK_MOUNT` from `DEV_DISK_NAME`: `readonly DEV_DISK_MOUNT="${DEV_DISK_MOUNT:-/mnt/lima-${DEV_DISK_NAME}}"`. | BS |
| A-24 | CH-DEV-005 | Unify health budget — fresh install gets same 300s budget + `_reset_floci_service` fallback as resume. | BS, DO |
| A-25 | CH-DEV-006 | Drop redundant inner `main` guard so `main` is callable from bats. | BS |

### Test Harness (CH-TWIN)

| ID | Finding | Agreed Action | Confirmed By |
|----|---------|---------------|-------------|
| A-26 | CH-TWIN-001 | Route precondition failures through `FAIL_REASON` + `print_verdict`. Move `assert_preconditions` inside guarded block. | BS, DO, TX |
| A-27 | CH-TWIN-002 | Add `sidecar-delta` to `mandatory` array in `validate_summary`. | BS, TX |
| A-28 | CH-TWIN-003 | Drop journal line-number comparison. Rely on property assertions (`After=`/`Requires=`) + `service_active`. | DO, TX |
| A-29 | CH-TWIN-004 | Fix stale-sentinel cleanup path — target `$STAGING`, not `$HOST_EVIDENCE_MOUNT`. | BS, TX |
| A-30 | CH-TWIN-005 | Document evidence-dir split: `--evidence-dir` relocates final copy only; 9p staging is fixed. | DO, TX |
| A-31 | CH-TWIN-006 | Resolve `--fresh`/`--keep` semantics. | DO, TX |
| A-32 | CH-TWIN-007 | Guard `wait` with `[[ -n "${DRIVER_SHELL_PID:-}" ]]`. Fail on unset `HOME` instead of falling back to `$(id -un)`. | BS, TX |

### Landing Zone (CH-LZ)

| ID | Finding | Agreed Action | Confirmed By |
|----|---------|---------------|-------------|
| A-33 | CH-LZ-001 | Replace `DenyAllExceptBoundary` with three-statement form. Drop `iam:DeleteGroupPermissionsBoundary`. | SW, SX |
| A-34 | CH-LZ-002 | Add G6 negative test (boundary denies `s3:*`, identity allows, assert denied). Qualify §1.1/§5.2/§12 until G6 passes. | SX, DX |
| A-35 | CH-LZ-003 | Relabel G1 to name both `FLOCI_AUTH_VALIDATE_SIGNATURES` and `FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED`. | DX |
| A-36 | CH-LZ-004 | G1 must `fail` (not `skip`) when probe cannot be established. `main` exits non-zero on any SKIP among automated gates. | BS, DO, SX, TX |
| A-37 | CH-LZ-005 | Unify five region literals to single source of truth per environment. | SW, DO, DX |
| A-38 | CH-LZ-006 | Reduce §6.10b to `-backend-config=../../_common/backend.hcl` + per-stage `key`. Remove deprecated args. | SW, DO |
| A-39 | CH-LZ-007 | Add G3b for S3 conditional PutObject, or mark `use_lockfile` unverified in §9 and `backend.hcl.example`. | DO, SX |
| A-40 | CH-LZ-008 | Restore governance tag trio in stage 10 provider. Add lint check that every `infra/live/*/providers.tf` matches `_common/providers.tf`. | SW, DO |
| A-41 | CH-LZ-009 | Unify provider constraints across all stages. | SW, DO |
| A-42 | CH-LZ-010 | Omit `key` from `providers.tf` backend block (fail-loud on missing override). | SW, DO |
| A-43 | CH-LZ-011 | Reverse `default_tags` merge order (governance tags win). Add `environment` validation restricting to `dev`/`uat`/`prod`. | SW, SX, DO |
| A-44 | CH-LZ-012 | Correct mechanism in `dev.tfvars` comment and auth plan §6.10c — merge precedence, silent override, no diagnostic. | SW, DX |
| A-45 | CH-LZ-013 | Remove root `install.sh`. Add `TF_VAR_secret_key` sourcing story to §10.1. Qualify §3 unbuilt scaffolding. Cross-link presign secret to §12. | SW, DX |

### Meta / Lessons Learned (CH-META)

| ID | Finding | Agreed Action | Confirmed By |
|----|---------|---------------|-------------|
| A-46 | CH-META-001 | Record lesson: "Separate 'what is wrong' from 'why it is wrong' — the fix scope follows the mechanism." | DX |
| A-47 | CH-META-002 | Record lesson: "IAM Condition absent-key evaluation is a recurring trap." Standing rules: recommendations must be single-valued; any IAM Condition on a service-specific key must state which actions populate that key; any Deny intended as a ceiling needs a negative test before it counts as landed. | DX |
| A-48 | CH-META-003 | Record lesson: "A finding that adds an environment variable must quote the source line documenting its default and effect." | DX |

---

## Cross-Cutting Gate Conditions

The following conditions span multiple specialists and must be resolved before Phase B:

1. **Three-outcome probe (CH-AUTH-001) is a Phase B entry gate.** SW, SX, TX, and DX challengers independently identified this. The probe must run against a live `sigv4` Floci instance. Route execution to DO/BS, interpretation to SX. No implementation SPEC proceeds until the outcome (a/b/c) is known and recorded in the gaps register.

2. **Scope completion.** TX must re-scope to all 49 accepted findings (M-1). DX must add SPEC-DX-014 for CH-AUTH-013 (M-3). SX must add findings for CH-LZ-005/008/009/010 and CH-INST-003/004 (M-4, M-5, M-17, M-18, M-32). DO must add SPECs for dropped TWIN/DEV findings (M-24). SW must add SPECs for CH-LZ-002/003/004/007 (M-2, M-8, M-9).

3. **Stub infrastructure.** The `aws` stub does not exist (D-8). It must be created as a subcommand-aware stub before any preflight test (SPEC-TX-112/113/114) can be written.

4. **CI capability gaps.** `make lint` does not cover `preflight-floci.sh` or any Terraform (M-7). No `terraform validate` job exists in CI (M-23). `test.yml` lacks `permissions:` (M-6). `opencode.yml` has a floating `@latest` action with `id-token: write` (M-21). These must be addressed before SPEC-DO-010/014–017 acceptance criteria can be enforced.

5. **User decision conflicts.** SPEC-SW-010 proposes `< 7.0.0` upper bound but A0:44 records "NO upper bound" (D-1). SPEC-DX-005 proposes removing "Crypto theater" but psc-0002 C1 ruled it a PASS (D-11). These must be reconciled with the user before implementation.

---

## 6. User Decisions (A2c — Post-Synthesis Ruling)

Date of ruling: 2026-07-30
Ruling authority: Supreme Leader (user)
Source synthesis: A2-dual-model-challenge.md (this document)

### 6.1 Disagreements (D-1 through D-23)

| Finding ID | Specialist Pair | Confidence | Priority | User Decision |
|------------|----------------|------------|----------|---------------|
| D-1 | SW vs SW-challenger | 95 | Critical | **Resolved: Challenger** |
| D-2 | SW vs SW-challenger | 85 | High | **Resolved: Challenger** |
| D-3 | SW vs SW-challenger | 85 | High | **Resolved: Challenger** |
| D-4 | SW vs SW-challenger | 80 | High | **Resolved: Primary** |
| D-5 | TX vs TX-challenger | 90 | Critical | **Resolved: Challenger** |
| D-6 | TX vs TX-challenger | 100 | Critical | **Resolved: Challenger** |
| D-7 | TX vs TX-challenger | 95 | Critical | **Resolved: Challenger** |
| D-8 | TX vs TX-challenger | 98 | Critical | **Resolved: Challenger** |
| D-9 | TX vs TX-challenger | 95 | Critical | **Resolved: Challenger** |
| D-10 | DX vs DX-challenger | 95 | Critical | **Resolved: Challenger** |
| D-11 | DX vs DX-challenger | 80 | High | **Resolved: Primary** |
| D-12 | DX vs DX-challenger | 85 | High | **Resolved: Challenger** |
| D-13 | SX vs SX-challenger | 93 | Critical | **Resolved: Challenger** |
| D-14 | SX vs SX-challenger | 88 | High | **Resolved: Primary** |
| D-15 | SX vs SX-challenger | 92 | Critical | **Resolved: Challenger** |
| D-16 | SX vs SX-challenger | 82 | High | **Resolved: Challenger** |
| D-17 | BS vs BS-challenger | 95 | Critical | **Resolved: Challenger** |
| D-18 | BS vs BS-challenger | 80 | High | **Resolved: Challenger** |
| D-19 | BS vs BS-challenger | 90 | Critical | **Resolved: Challenger** |
| D-20 | DO vs DO-challenger | 90 | Critical | **Resolved: Primary** |
| D-21 | DO vs DO-challenger | 85 | High | **Resolved: Challenger** |
| D-22 | DO vs DO-challenger | 80 | High | **Resolved: Challenger** |
| D-23 | DO vs DO-challenger | 75 | Advisory | **Backlogged** |

**Summary:** Challenger wins: 18 | Primary wins: 4 | Backlogged: 1

### 6.2 One-Sided Findings (M-1 through M-43)

| Finding ID | Source Challenger | Confidence | Priority Band | User Decision |
|------------|-------------------|------------|---------------|---------------|
| M-1 | TX-challenger | 100 | Critical | **Accepted** |
| M-2 | SW-challenger | 90 | Critical | **Accepted** |
| M-3 | DX-challenger | 95 | Critical | **Accepted** |
| M-4 | SX-challenger | 95 | Critical | **Accepted** |
| M-5 | SX-challenger | 90 | Critical | **Accepted** |
| M-6 | DO-challenger | 92 | Critical | **Accepted** |
| M-7 | DO-challenger | 90 | Critical | **Accepted** |
| M-8 | SW-challenger | 85 | High | **Accepted** |
| M-9 | SW-challenger | 85 | High | **Backlog** |
| M-10 | SW-challenger | 88 | High | **Accepted** |
| M-11 | SW-challenger | 82 | High | **Accepted** |
| M-12 | TX-challenger | 90 | High | **Accepted** |
| M-13 | TX-challenger | 82 | High | **Accepted** |
| M-14 | DX-challenger | 92 | High | **Accepted** |
| M-15 | DX-challenger | 88 | High | **Accepted** |
| M-16 | DX-challenger | 85 | High | **Backlog** |
| M-17 | SX-challenger | 88 | High | **Backlog** |
| M-18 | SX-challenger | 85 | High | **Accepted** |
| M-19 | SX-challenger | 88 | High | **Accepted** |
| M-20 | BS-challenger | 82 | High | **Accepted** |
| M-21 | DO-challenger | 88 | High | **Accepted** |
| M-22 | DO-challenger | 85 | High | **Accepted** |
| M-23 | DO-challenger | 82 | High | **Accepted** |
| M-24 | DO-challenger | 80 | High | **Backlog** |
| M-25 | TX-challenger | 85 | Moderate | **Accepted** |
| M-26 | TX-challenger | 88 | Moderate | **Accepted** |
| M-27 | TX-challenger | 85 | Moderate | **Accepted** |
| M-28 | TX-challenger | 80 | Moderate | **Accepted** |
| M-29 | TX-challenger | 88 | Moderate | **Accepted** |
| M-30 | DX-challenger | 82 | Moderate | **Accepted** |
| M-31 | DX-challenger | 75 | Low | **Backlog** |
| M-32 | SX-challenger | 80 | Moderate | **Accepted** |
| M-33 | BS-challenger | 88 | Moderate | **Accepted** |
| M-34 | BS-challenger | 80 | Moderate | **Accepted** |
| M-35 | BS-challenger | 78 | Low | **Backlog** |
| M-36 | BS-challenger | 75 | Low | **Backlog** |
| M-37 | DO-challenger | 75 | Low | **Backlog** |
| M-38 | BS-challenger | 85 | Low | **Accepted** |
| M-39 | BS-challenger | 72 | Low | **Backlog** |
| M-40 | BS-challenger | 70 | Low | **Backlog** |
| M-41 | BS-challenger | 68 | Low | **Backlog** |
| M-42 | BS-challenger | 65 | Low | **Backlog** |
| M-43 | DO-challenger | 70 | Low | **Backlog** |

**Summary:** Accepted: 28 | Backlogged: 15 (3 from moderate/high bands, 12 from low band)

### 6.3 Recommendations (R-1 through R-53)

All 53 recommendations (R-1 through R-53) → **Backlog** (user ruled remaining 64 findings — 53 recommendations + 11 low-confidence one-sided — as BACKLOG)

---

## Decision Impact Summary

**Total artifacts created in A2b:** 120 (23 Decisions + 34 Advisories + 63 Clarifications)

**Final status after user ruling:**
- **Decisions:** 18 resolved: challenger, 4 resolved: primary, 1 backlog
- **Advisories:** 28 accepted, 6 backlog
- **Clarifications:** 10 backlog (low-confidence one-sided), 53 backlog (recommendations)

**Next phase:** All accepted findings (D-1/D-2/D-3/D-5/D-6/D-7/D-8/D-9/D-10/D-12/D-13/D-15/D-16/D-17/D-18/D-19/D-21/D-22 + M-1 through M-8, M-10, M-11, M-12, M-13, M-14, M-15, M-18, M-19, M-20, M-21, M-22, M-23, M-25, M-26, M-27, M-28, M-29, M-30, M-32, M-33, M-34, M-38) flow into Phase B implementation planning via implementation tickets.

