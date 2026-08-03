# A2 Challenger: Software Engineer — psc-0003

| Field | Value |
|-------|-------|
| Agent | software-engineer-challenger (glm-5.2) |
| Phase | A2 — Dual-Model Challenge |
| Primary Output | A1-SW: 14 SPEC findings covering CH-AUTH-001/002/003/012/013, CH-LZ-001/005/006/008/009/010/011/012/013; architectural assessment; SOLID/module-boundary analysis; specialist dependency table |
| Date | 2026-07-30 |
| Verdict | CONDITIONAL PASS |

## Self-Audit Checklist

| Category | Checked? | Finding or PASS |
|----------|----------|-----------------|
| Build passes (exit 0, no warnings) | N/A — Phase A2, no code | N/A |
| Typed enums / vocabulary types | N/A — bash/Terraform | N/A |
| Documentation on new public symbols | N/A | N/A |
| Spec/datasheet fidelity | yes | Cross-referenced all 14 SW SPECs against advisory findings 001–016, LZ-001–013, and A0 user decisions; verified scope boundary against A0 specialist roster |
| Module boundary | yes | Checked SW scope (auth plan §4–§7, setup-floci.sh, infra/ Terraform, IAM policies) against advisory LZ findings for missed items |
| Reserved/padding fields | N/A | N/A |
| No magic numbers in doc examples | N/A | N/A |
| Buffer safety | N/A | N/A |
| AGENTS.md compliance | yes | PASS — challenge and critique only; no design work produced; all findings carry confidence scores |
| Conventional commit ready | N/A — Phase A2 | N/A |

## Reference Validation

| Primary Claim | Reference Provided | Authority Level | Verified? | Correctly Applied? |
|--------------|-------------------|-----------------|-----------|-------------------|
| SW covered 14 findings in scope | A1-SW §Requirements Analysis | — | ✓ | Partial — 4 LZ findings in SW domain are missing (see One-Sided F1–F3) |
| SPEC-SW-010 proposes `< 7.0.0` upper bound | A1-SW:337-338 | 3 (project files) | ✓ | ✗ — contradicts A0 user decision "NO upper bound" (A0:44) |
| SPEC-SW-006 bundles G6 test from CH-LZ-002 | A1-SW:228 | 2 (advisory) | ✓ | Partial — CH-LZ-002 is a standalone high-severity finding, not a sub-item |
| SPEC-SW-001 probe is an acceptance criterion | A1-SW:87 | 2 (advisory) | ✓ | ✗ — probe outcome gates the entire security model; should be a Phase B prerequisite, not a deferrable criterion |

### Findings

- [✓] All factual claims in the primary have at least one citation
- [✓] All citations are from authoritative sources (trust level 1-3)
- [✓] All cited sources were verified to actually support the claim
- [✗] Implementation follows what the reference recommends — SPEC-SW-010 contradicts the user decision recorded in A0
- [✓] Best practices, gotchas, and production-grade guidance were sought

---

## Agreements

### A1 — FLOCI_AUTH_MODE as the correct architectural abstraction
The SW correctly identifies `FLOCI_AUTH_MODE` as the right single-enum abstraction that collapses the dangerous 2×2 auth matrix. The SOLID assessment (Single Responsibility on the parameter, Interface Segregation on the escape hatch) is sound. **Confidence: 95.**

### A2 — SPEC-SW-002 (CH-AUTH-002) fix pattern is correct
The `FLOCI_AUTH_UNSAFE_OVERRIDE=1` escape hatch with unconditional derivation from the mode is the correct pattern. It closes the `${VAR:-default}` hole while preserving test injectability. The `unset _auth_on` cleanup aligns with AGENTS.md's readonly-configuration-block convention. **Confidence: 95.**

### A3 — SPEC-SW-006 (CH-LZ-001) three-statement split is architecturally sound
Splitting `DenyAllExceptBoundary` by whether `iam:PermissionsBoundary` is present in the request context is the correct fix. The three statements (DenyPrincipalCreationWithoutBoundary, DenyBoundaryPolicyMutation, DenyBoundaryDetach) correctly scope the inverted condition operator to actions where the key exists, and use resource-scoped denies where it doesn't. The removal of `iam:DeleteGroupPermissionsBoundary` (not a real API action) is correct. **Confidence: 92.**

### A4 — SPEC-SW-012 (CH-LZ-011) merge-order reversal is the right fix
Reversing `default_tags` merge order so `var.default_tags` is first (governance trio wins) is the correct fix. Adding `environment` validation restricting to `dev`/`uat`/`prod` closes the hazard for future tfvars files. The comment explaining why is good practice. **Confidence: 95.**

### A5 — Module boundary assessment is accurate
The SW's module boundary table correctly identifies the four drifted/inconsistent boundaries (`_common/providers.tf` ↔ stage, auth plan ↔ setup-floci.sh, landing-zone ↔ infra/, backend.hcl ↔ dev.tfvars). The architectural assessment of the `_common/` template pattern (open for extension, not closed for modification — CH-LZ-008 lint check closes it) is correct. **Confidence: 90.**

### A6 — Reference validation is thorough
The SW's reference validation table cites 18 claims with authority levels 1-3, all verified. The bash-execution-verified claims (CH-AUTH-002, 004, 005, 008, 009) are the strongest evidence in the analysis. **Confidence: 90.**

---

## Disagreements

### D1 — SPEC-SW-010 directly contradicts the user decision on the upper bound

**Confidence: 95 (Critical — blocks)**

The SW's SPEC-SW-010 proposes `>= 6.56.0, < 7.0.0` (with upper bound) and lists as acceptance criterion #1: "All stages use `aws >= 6.56.0, < 7.0.0`" (A1-SW:344). However, `A0-task-definition.md:44` records the user decision as:

> CH-LZ-009: >= 6.56.0 with NO upper bound

The advisory (CH-LZ-009, psc-adv-0017:1128) recommended `< 7.0.0`, but the user explicitly overruled the upper bound in the A0 task definition. The SW analysis either did not consult A0, or chose to follow the advisory recommendation over the user decision. Either way, the acceptance criterion is wrong: Phase B implementers following SPEC-SW-010 would add `< 7.0.0`, directly violating the user's recorded decision.

The SW's verdict rationale (A1-SW:503) states CH-LZ-009 is "not yet decided by the user — discovered after the review session." But A0 (the task definition prepared after the advisory) records the decision as "NO upper bound." The SW is working from stale information.

**Evidence:**
- A0-task-definition.md:44 — `CH-LZ-009: >= 6.56.0 with NO upper bound`
- A1-SW:337-338 — `Add an upper bound: < 7.0.0`
- A1-SW:344 — `All stages use aws >= 6.56.0, < 7.0.0`

**Suggested fix:** SPEC-SW-010 must be revised to `>= 6.56.0` with no upper bound, matching A0. The acceptance criteria must state "All stages use `aws >= 6.56.0` (no upper bound, per user decision A0:44)." The rationale about supply-chain risk from an unbounded constraint should be recorded as an advisory note in the gaps register, not as an acceptance criterion.

### D2 — SPEC-SW-001 under-weights the three-outcome probe as a Phase B gate

**Confidence: 85 (High — should fix)**

The SW lists "Three-outcome probe executed and result recorded in gaps register" as acceptance criterion #6 (A1-SW:87), treating it as one item among six. The advisory (CH-AUTH-001, psc-adv-0017:139-155) states the probe has three possible outcomes, and outcome (b) — a 12-digit AKID accepted with an unchecked secret — "would mean the estate's headline security claim is unenforced" and "auth plan §8.3 and landing-zone §1.1 would both be false and must be rewritten."

The probe is not a documentation step; it is a **keystone verification** whose outcome determines whether multiple SPECs are even meaningful:
- If outcome (b): SPEC-SW-001's account model is security-neutral, SPEC-SW-006's boundary fix is modeled not enforced, and landing-zone §1.1's "API authorization: Enforced" row is false.
- If outcome (c): silent account relocation — `data.aws_caller_identity` returns `000000000000`, invalidating SPEC-SW-001's precondition.

The SW should have flagged the probe as a **blocking prerequisite for Phase B**, not a deferrable acceptance criterion. Without the probe result, the SW cannot know whether the architectural fixes it specifies are real or cosmetic.

**Evidence:**
- psc-adv-0017:139-155 — probe specification with three outcomes
- psc-adv-0017:154 — "outcome (b) is the one to look for: it would mean the estate's headline security claim is unenforced"
- A1-SW:87 — probe listed as criterion #6, not as a gate

### D3 — SPEC-SW-006 conflates CH-LZ-001 (policy fix) with CH-LZ-002 (boundary evaluation unverified)

**Confidence: 85 (High — should fix)**

SPEC-SW-006 (A1-SW:228) includes "G6 negative test added (per CH-LZ-002)" as acceptance criterion #6, bundling CH-LZ-002 into CH-LZ-001's fix. But CH-LZ-002 is a standalone high-severity finding (advisory:85, "high · Confidence 85") with a distinct architectural implication: Floci may not evaluate permissions boundaries *at all*, making §5.1/§5.2/§12's security model "modeled, not enforced."

The advisory states (psc-adv-0017:941): "If Floci evaluates identity policies but ignores boundaries, §5.1–§5.2 are *modeled*, not enforced — and that is the single most important security claim in the design."

By bundling G6 into SPEC-SW-006, the SW treats CH-LZ-002 as a test-addition task rather than a finding that may invalidate the entire delegated-administration architecture. The three-statement policy fix (SPEC-SW-006) is only meaningful if Floci evaluates boundaries — if it doesn't, the fix is cosmetic and the escalation ceiling doesn't exist in either direction (the advisory notes: "creation without a boundary is *not* denied, because no statement covers `iam:CreateRole` at all").

**Suggested fix:** CH-LZ-002 should have its own SPEC (SPEC-SW-015) with:
- The G6 negative test as the primary acceptance criterion
- A dependency on the three-outcome probe (D2) — if Floci doesn't enforce signatures, boundary evaluation is moot
- A qualification requirement: until G6 passes, landing-zone §1.1's row must read "Enforced (identity policies); boundary evaluation unverified"
- SX dependency to validate whether Floci's IAM implements boundary evaluation

### D4 — SPEC-SW-004 confidence 100 conflates "definitely real" with "must fix/blocking"

**Confidence: 80 (High — should fix)**

SPEC-SW-004 (CH-AUTH-012, split §6.10a–d into changelog/appendix) is rated confidence 100 (A1-SW:182). Per the review-confidence skill, 90-100 is "Critical — definitely real, must fix / blocks." A documentation structure issue (mixing pending and landed changes in a "Explicit code changes" section) is definitely real, but it is not "Critical" in the blocking sense — it does not break security, data, or operations. The advisory itself rates it "Severity low (process) · Confidence 100" (psc-adv-0017:500), but the confidence scale's action column says 90-100 "Blocks — equivalent to REJECTED."

The SW's own verdict (A1-SW:505) states "Blocking findings (confidence ≥80): None" — which contradicts SPEC-SW-004's confidence 100. If confidence 100 is assigned, it must block; if it doesn't block, the confidence is inflated. The SW should either:
- Adjust to 90 (still "Critical" tier, but the scale allows 90-100), or
- Note that this is a process finding where "definitely real" does not imply "blocks the pipeline"

This is a scoring precision issue, not a content error — the finding itself is correct.

---

## One-Sided Findings

### F1 — CH-LZ-002 (boundary evaluation unverified) has no standalone SPEC

**Confidence: 90 (Critical — blocks)**

The advisory has CH-LZ-002 as a standalone high-severity finding (psc-adv-0017:929-948). The SW analysis has no SPEC-SW for it. It is referenced only as acceptance criterion #6 in SPEC-SW-006 ("G6 negative test added per CH-LZ-002"). This is the most significant omission in the SW analysis.

CH-LZ-002's architectural implication: Floci may not implement permissions-boundary evaluation at all. The scraped docs promise only "enforce IAM policies on API calls" — identity-policy evaluation, not boundary evaluation. If Floci ignores boundaries, the entire delegated-administration ceiling (§5.1, §5.2, §12) is modeled, not enforced — the "false demo" class that §10.1's gates exist to prevent.

The SW gave this one line in another finding's acceptance criteria. It deserves its own SPEC with:
- Severity: high (the advisory rates it high)
- The G6 negative test as the primary gate
- A dependency on the three-outcome probe (if signatures aren't enforced, boundary evaluation is moot)
- A documentation requirement: §1.1 must read "Enforced (identity policies); boundary evaluation unverified" until G6 passes
- SX dependency to validate Floci's boundary-evaluation capability

**Evidence:** psc-adv-0017:929-948 (CH-LZ-002 full finding); A1-SW:228 (only mention, as a sub-criterion)

### F2 — CH-LZ-007 (use_lockfile S3-native locking unverified) is missing entirely

**Confidence: 85 (High — should fix)**

The advisory has CH-LZ-007 (psc-adv-0017:1051-1075): S3-native locking (`use_lockfile = true`) is offered as an alternative to DynamoDB locking, but no gate verifies that Floci's S3 honours `IfNoneMatch: "*"`. The advisory's recommended action #11 (psc-adv-0017:1329) calls for "Add G3b for S3 conditional PutObject, or mark use_lockfile unverified in §9 and backend.hcl.example."

This is a Terraform backend concern squarely in the SW/DO domain (the A0 roster assigns "infra/ Terraform" to SW and "preflight gates" to DO). The SW analysis covers 9 of 13 LZ findings but omits CH-LZ-007. `backend.hcl.example:19` offers the alternative with an "also verify" comment, but no gate exists — two concurrent applies could both acquire the lock and corrupt state.

**Evidence:** psc-adv-0017:1051-1075 (CH-LZ-007); A1-SW (no SPEC for CH-LZ-007)

### F3 — CH-LZ-003 and CH-LZ-004 (G1 mislabelling and SKIP-vs-fail) are missing

**Confidence: 85 (High — should fix)**

CH-LZ-003 (G1 mislabelled; design never names enforcement variables) and CH-LZ-004 (G1 degrades to SKIP where design promises hard stop) are preflight-gate findings. The A0 roster assigns `preflight-floci.sh` to both SW and DO. The SW analysis touches preflight in SPEC-SW-001 (credential changes for G1) but does not address CH-LZ-003 or CH-LZ-004.

CH-LZ-004 is particularly critical (psc-adv-0017:973-990): "If `create-access-key` fails, G1 calls `skip` and returns. `skip` does not set `FAILED`, so `main` reports 'automated gates passed' and exits 0." Under the default credentials (`$DEV_AKID` + `test`), the call always fails (per CH-AUTH-001), so "the gate the design calls a hard stop reports success on precisely the configuration it exists to police."

This interacts with SPEC-SW-001: the SW changes G1's credentials (from `DEV_AKID` to the deployer key), but if CH-LZ-004 is not fixed, G1 may still skip (not fail) on the new credential configuration if `create-access-key` fails for any reason. The SW's SPEC-SW-001 acceptance criterion #6 ("preflight-floci.sh G1 uses deployer credentials") is necessary but insufficient — G1 must also *fail* (not skip) when it cannot establish the probe.

**Evidence:** psc-adv-0017:952-990 (CH-LZ-003, CH-LZ-004); A1-SW (no SPEC for either)

### F4 — SPEC-SW-001 does not flag the landing-zone §4.2 promotion model collapse

**Confidence: 88 (High — should fix)**

SPEC-SW-001's fix moves the account axis from the AKID to `FLOCI_DEFAULT_ACCOUNT_ID` (per-instance configuration). The acceptance criteria include "Landing-zone §4.1/§4.2 updated with the new account-selection mechanism" (A1-SW:86). But the SW does not flag that §4.2's entire promotion model is now false.

Landing-zone §4.2 (landing-zone-design.md:189-201) states:
> "Promoting from dev to uat/prod requires no code changes: 1. Copy `environments/dev.tfvars` to `environments/uat.tfvars`. 2. Change `account_id` to the new AKID. 3. Change the backend state `key` prefix. The **same stage code applies unchanged**."

Under the new model (FLOCI_DEFAULT_ACCOUNT_ID per instance), promotion requires a **new Floci instance** with a different `FLOCI_DEFAULT_ACCOUNT_ID`, not just a new tfvars file. The "same stage code applies unchanged" claim is still true for the Terraform, but the "no code changes" promotion story is broken at the infrastructure layer — you need a new VM/container instance. The advisory notes this (psc-adv-0017:136: "promotion therefore requires one instance per environment") and says to "record the trade-off in the gaps register," but the SW lists it as a DX dependency without flagging the architectural implication: the environment-as-account promotion model, which is landing-zone §4's headline design decision, is fundamentally altered.

**Evidence:** landing-zone-design.md:189-201 (§4.2 promotion model); psc-adv-0017:136 (trade-off); A1-SW:86 (listed as DX dependency, not flagged as architectural impact)

### F5 — SPEC-SW-001's `data.aws_caller_identity` precondition depends on the unverified probe

**Confidence: 80 (High — should fix)**

SPEC-SW-001 (A1-SW:77) proposes adding a `data.aws_caller_identity` + `precondition` that fails the plan when the resolved account id does not equal `var.account_id`. Under the fix, `access_key` is the deployer's rotated AKID (non-12-digit), which resolves to `FLOCI_DEFAULT_ACCOUNT_ID`.

The precondition's correctness depends on what `sts:GetCallerIdentity` returns for a non-12-digit AKID under `sigv4`. The three-outcome probe (CH-AUTH-001) is designed to verify exactly this. If the probe has not been run, the SW cannot know whether:
- `GetCallerIdentity` returns `FLOCI_DEFAULT_ACCOUNT_ID` (precondition works), or
- `GetCallerIdentity` returns something else (precondition fails on every plan), or
- `GetCallerIdentity` is not enforced at all (precondition is meaningless)

The SW adds the precondition as an unconditional fix without gating it on the probe outcome. If the probe returns outcome (b) or (c), the precondition may fail on every `terraform plan` — breaking all stages, not just stage 10.

**Suggested fix:** The precondition should be added *after* the probe confirms outcome (a) or (c-with-correct-account). Until then, the SW should specify a `null_resource` check or a documented manual verification step.

### F6 — CH-AUTH-014 (presign secret IAM bypass) is under-weighted in SPEC-SW-014

**Confidence: 82 (High — should fix)**

SPEC-SW-014 (A1-SW:437-461) bundles four items into one finding with confidence 90. Item 4 is: "Cross-link presign secret to CH-AUTH-014 in §12." But CH-AUTH-014 (psc-adv-0017:523-535) is architecturally distinct from the other three items (install.sh removal, TF_VAR_secret_key story, §3 scaffolding qualification).

`FLOCI_AUTH_PRESIGN_SECRET` mints presigned S3 URLs that **bypass the IAM layer entirely** — the entire authentication plan is about IAM enforcement, and this secret circumvents it. The Terraform state bucket is S3 (landing-zone §9), so a presign capability over the state bucket is equivalent to administrative access to the estate. The advisory notes: "a presign capability over the state bucket is equivalent to administrative access to the estate" (psc-adv-0017:531-532).

The SW bundles this into a "multiple documentation and hygiene gaps" finding (A1-SW:461). The presign-secret bypass deserves its own SPEC because:
- It's a direct bypass of the security model the entire plan builds
- It needs a threat model, a rotation path, and a note on `generate_presign_secret`'s reuse-if-exists behaviour
- The advisory rates it "low-medium · Confidence 80" but the *impact* (admin access via state bucket) is high
- It's the only finding that bypasses IAM from a different vector (presign URLs), not a configuration error

**Suggested fix:** Split CH-AUTH-014 into its own SPEC (SPEC-SW-015 or SPEC-SW-016) with SX dependency for the threat model, separate from the documentation hygiene items.

---

## Cross-Cutting Concerns

### C1 — The three-outcome probe (CH-AUTH-001) is a keystone gate for multiple SPECs

The probe outcome affects at least three SPECs:
- **SPEC-SW-001** (account model): outcome (c) means silent account relocation; the `data.aws_caller_identity` precondition (F5) may fail
- **SPEC-SW-006** (boundary fix): if signatures aren't enforced (outcome b), boundary evaluation is moot
- **Landing-zone §1.1/§5.1/§12**: outcome (b) means "API authorization: Enforced" is false

The SW treats the probe as one acceptance criterion. It should be a **Phase B entry gate**: no implementation SPEC proceeds until the probe result is known and recorded. This is the single most important cross-cutting concern the SW missed.

### C2 — CH-LZ-002 (boundary evaluation) gates SPEC-SW-006 (policy fix)

The three-statement IAM fix (SPEC-SW-006) is only meaningful if Floci evaluates permissions boundaries. If Floci doesn't (CH-LZ-002), the fix is cosmetic — the escalation ceiling doesn't exist in either direction. The SW bundles G6 into SPEC-SW-006 but doesn't state the dependency: the three-statement form is an architecture change that's only falsifiable if G6 can run, and G6 may not be possible on Floci at all. This is a prerequisite chain: probe (C1) → boundary evaluation (CH-LZ-002) → policy fix (SPEC-SW-006).

### C3 — CH-LZ-004 (G1 SKIP-vs-fail) interacts with SPEC-SW-001 and SPEC-SW-003

SPEC-SW-001 changes G1's credentials; SPEC-SW-003 fixes `IAM_ENABLED`. But CH-LZ-004 says G1 silently skips when it can't establish the probe. If SPEC-SW-001 and SPEC-SW-003 are implemented without CH-LZ-004, G1 may still skip (not fail) on the new credential configuration, reporting "gates passed" when it didn't actually test. The SW doesn't identify this interaction — the three findings must be implemented together, not independently.

### C4 — The landing-zone §4.2 promotion model is altered by SPEC-SW-001, not just documented

SPEC-SW-001's fix changes the environment-selection mechanism from AKID-derived to instance-configured. This doesn't just require a documentation update (as the SW's DX dependency suggests) — it alters a headline design decision (§4: "Environment = account = AKID"). The §4.2 promotion model ("copy tfvars, change AKID, same code applies") is now incomplete: promotion requires a new Floci instance. This is an architectural change to the landing-zone design, not a documentation task.

---

## Undocumented Specialist Dependencies

### U1 — CH-LZ-002 needs SX and TX but is not routed

CH-LZ-002 (boundary evaluation unverified) is not in the SW's dependency table (A1-SW:513-519). It needs:
- **SX (Security Reviewer):** Validate whether Floci's IAM implements permissions-boundary evaluation (distinct from identity-policy evaluation)
- **TX (Test Engineer):** Implement G6 negative test
- **DO (DevOps Specialist):** Run G6 against a live sigv4 Floci

The SW only routes CH-LZ-001 to SX ("Validate the three-statement form correctly enforces the escalation ceiling; design G6 negative test"). CH-LZ-002 is a separate finding that needs its own SX validation.

### U2 — CH-LZ-007 needs DO but is not routed

CH-LZ-007 (use_lockfile gate) needs DO to implement G3b (S3 conditional PutObject test) or to mark the alternative as unverified. It's not in the SW's analysis at all (F2).

### U3 — The three-outcome probe needs a runtime specialist

The probe (CH-AUTH-001 verification) must run against a live sigv4 Floci instance. The SW lists it as an acceptance criterion but doesn't route it to any specialist. It needs:
- **DO or BS:** Execute the probe on the dev twin (the only sigv4 Floci instance available)
- **SX:** Interpret the outcome (does it mean the security model is false, or just that account selection works differently?)

### U4 — SPEC-SW-001's landing-zone §4.1/§4.2 update needs architectural review, not just documentation

The SW routes "Update landing-zone §4.1/§4.2" to DX (Docs Writer). But the promotion model change (C4) is an architectural alteration to a headline design decision, not a documentation edit. It needs SW or DO review to confirm the new promotion story is coherent before DX writes it up.

---

## Recommendations

### R1 — Revise SPEC-SW-010 to match the user decision (no upper bound) — Confidence 95
SPEC-SW-010 must be revised to `>= 6.56.0` with no upper bound, per A0:44. Record the supply-chain risk as a gaps-register advisory, not an acceptance criterion. This is a blocking fix — Phase B must not implement `< 7.0.0`.

### R2 — Promote the three-outcome probe to a Phase B entry gate — Confidence 90
The probe (CH-AUTH-001 verification) should be a blocking prerequisite for Phase B, not a deferrable acceptance criterion. No implementation SPEC proceeds until the probe result is known. Route to DO/BS for execution and SX for interpretation.

### R3 — Create SPEC-SW-015 for CH-LZ-002 (boundary evaluation unverified) — Confidence 90
CH-LZ-002 deserves its own SPEC with the G6 negative test as the primary gate, a dependency on the probe, a §1.1 qualification requirement, and SX/TX/DO dependencies. Do not bundle it into SPEC-SW-006.

### R4 — Create SPECs for CH-LZ-003, CH-LZ-004, and CH-LZ-007 — Confidence 85
These three findings are in the SW/DO domain and are missing from the analysis. CH-LZ-004 (G1 SKIP-vs-fail) is particularly critical because it interacts with SPEC-SW-001 and SPEC-SW-003 (C3).

### R5 — Split CH-AUTH-014 (presign secret) into its own SPEC — Confidence 82
The presign-secret IAM bypass is architecturally distinct from the documentation hygiene items in SPEC-SW-014. It needs its own SPEC with SX dependency for the threat model.

### R6 — Flag the landing-zone §4.2 promotion model alteration as architectural — Confidence 88
SPEC-SW-001's fix alters the §4.2 promotion model (environment-as-account → environment-as-instance). This is an architectural change, not a documentation task. Route to SW/DO for review before DX writes it up.

### R7 — Gate the `data.aws_caller_identity` precondition on the probe result — Confidence 80
SPEC-SW-001's precondition should be added after the probe confirms the account-resolution behaviour. Until then, specify a manual verification step or a `null_resource` check.

### R8 — Adjust SPEC-SW-004 confidence to 90 or note the process-finding exception — Confidence 80
Confidence 100 implies blocking, but the SW's verdict states no blocking findings. Either adjust to 90 or explicitly note that process findings can be confidence 100 without blocking the pipeline.

---

## Verdict

**CONDITIONAL PASS**

**Rationale:** The SW analysis is thorough, well-referenced, and architecturally sound on the 14 findings it covers. The SOLID and module-boundary assessments are accurate. However, four issues prevent an APPROVED:

1. **D1 (confidence 95):** SPEC-SW-010 directly contradicts the user decision recorded in A0. This is a blocking error — Phase B must not implement `< 7.0.0` when the user said "NO upper bound."
2. **F1 (confidence 90):** CH-LZ-002 (boundary evaluation unverified) — the most important security claim in the design — has no standalone SPEC. It's bundled as a sub-criterion in SPEC-SW-006.
3. **F2/F3 (confidence 85):** CH-LZ-007, CH-LZ-003, and CH-LZ-004 are missing from the analysis entirely. CH-LZ-004 interacts with SPEC-SW-001 and SPEC-SW-003 (C3).
4. **D2 (confidence 85):** The three-outcome probe is treated as a deferrable acceptance criterion when it is a keystone gate for multiple SPECs (C1).

**Blocking findings (confidence ≥80):** D1 (95), F1 (90), D2 (85), D3 (85), F2 (85), F3 (85), F4 (88), F5 (80), F6 (82), R3 (90), R4 (85).

**Advisory findings (confidence <80):** D4 (80 — scoring precision), R8 (80 — scoring precision).

**Conditions for APPROVED:**
1. Revise SPEC-SW-010 to match A0 (no upper bound) — D1
2. Create SPEC-SW-015 for CH-LZ-002 — F1/R3
3. Create SPECs for CH-LZ-003, CH-LZ-004, CH-LZ-007 — F2/F3/R4
4. Promote the three-outcome probe to a Phase B entry gate — D2/R2
5. Split CH-AUTH-014 into its own SPEC — F6/R5
6. Flag the §4.2 promotion model alteration as architectural — F4/R6
7. Gate the `data.aws_caller_identity` precondition on the probe result — F5/R7

**Routing:** Output to supreme-leader for A-GATE synthesis. The blocking findings (D1, F1, D2, F2/F3) must be resolved before Phase B can begin.
