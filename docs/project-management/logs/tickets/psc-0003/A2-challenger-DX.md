# A2 Challenger: Docs Writer — psc-0003

| Field | Value |
|-------|-------|
| Agent | docs-writer-challenger (glm-5.2) |
| Phase | A2 — Dual-Model Challenge |
| Primary | A1-DX-docs-writer.md (13 SPEC-DX requirements) |
| Source | psc-adv-0017-challenge-review.md |
| Ticket | psc-0003 |
| Verdict | CONDITIONAL PASS |

## Agreements

The primary's overall structure is sound. The following are correct and well-scoped:

1. **SPEC-DX-001 (CH-AUTH-001)** — Correctly identifies the §4.1/§4.2 update, the `FLOCI_DEFAULT_ACCOUNT_ID` selection mechanism, the promotion-model qualification, and the gap-register entry. The cross-document list (authentication-plan §6.10b, solution-design §8.3, preflight-floci.sh) is accurate — I verified `solution-design.md:170` still asserts "Multi-account isolation is automatic via 12-digit numeric access key IDs", which directly contradicts the sigv4 model. Good catch.

2. **SPEC-DX-004 (CH-AUTH-015)** — Correct. I verified `authentication-plan.md:957-978` still claims "Fixed in §6.5"/"Fixed in §6.7" for items CH-AUTH-005/006 show are inoperative. The "specified-not-verified" relabelling is the right fix.

3. **SPEC-DX-008 (CH-LZ-002)** and **SPEC-DX-009 (CH-LZ-003)** — Correctly add GAP-017, qualify §1.1/§5.2/§12, name both enforcement variables, and relabel G1. The cross-reference to `authentication-plan.md §8.4` (which I verified references the permissions boundary as a control at line ~928) is appropriate.

4. **SPEC-DX-007 (CH-INST-005)** — The *substance* is correct. I verified `setup-floci.sh:656-657` uses `run_as_floci systemctl --user` and `dev-twin.sh:484` is the actual TLS override line. (See Disagreements for the line-number defect.)

5. **SPEC-DX-011 (CH-LZ-007)** — Correct. I verified `landing-zone-design.md` §9 and `backend.hcl.example:19` offer `use_lockfile` with only an "also verify with G3" comment and no actual gate. The conditional-PutObject mechanism description is accurate.

6. **SPEC-DX-010 (CH-LZ-005)** — Correct that five region sites exist and diverge. I verified: `setup-floci.sh:54` (eu-west-1), `preflight-floci.sh:25` (us-east-1), `dev-twin.sh:766` (eu-west-1), `backend.hcl.example:12` (us-east-1), `dev.tfvars:13` (eu-west-2). The CH-META-001 corrected-mechanism cross-reference is properly included.

## Disagreements

### D1 — SPEC-DX-007 cites wrong AGENTS.md line numbers (confidence 95)

The primary's title is "Refresh AGENTS.md:57 and :64" and its acceptance criteria assert `AGENTS.md:57` and `AGENTS.md:64`. I verified the actual gotcha text lives at **AGENTS.md:60** (the `enable-linger` / `systemctl --user -M floci@.host` line) and **AGENTS.md:67** (the `dev-twin.sh line 322` TLS line). The primary propagated the advisory's own imprecise line references (`AGENTS.md:57`, `:64` from CH-INST-005's "Location" field) without re-verifying against the current file. A documentation-requirements analysis that cites wrong line numbers in its acceptance criteria is self-defeating — the implementer will edit the wrong lines or find nothing matching.

**Recommendation:** Change the title and acceptance criteria to "AGENTS.md:60 and :67" (or remove the hard line numbers and reference the gotcha by its leading text, which is robust to reflow). Confidence 95.

### D2 — SPEC-DX-005 omits the psc-0002 precedent that preserved "crypto theater" (confidence 80)

The primary mandates replacing "Crypto theater" everywhere. I verified the phrase appears at `authentication-plan.md:125`, `:924`-ish (§8.3 heading), and `solution-design.md:137`. However, the psc-0002 C1 dual-model challenge (`docs/project-management/logs/tickets/psc-0002/C1-dual-model-challenge-verify.md:88`) explicitly ruled this usage a **PASS** — distinguishing it from a rejected "security theater" pejorative and calling it "the correct, accepted usage… used to *justify* a safeguard." The primary proposes a directly contradictory change without acknowledging or overturning that prior verdict. Per the authoritative-reference and cross-document-consistency skills, a doc change that reverses a prior verification must cite and supersede it, not silently overwrite it.

**Recommendation:** SPEC-DX-005 must (a) reference the psc-0002 C1 verdict it is superseding, (b) state *why* the CH-AUTH-016 challenge overrides that verdict (CH-AUTH-016 is trivial/100-confidence editorialising per the advisory, but psc-0002 treated it as technical characterization — the rationale for the reversal must be explicit), and (c) grep `docs/project-management/logs/` not just `docs/` since the phrase also appears in A1/SX review logs that should NOT be rewritten (they are historical artifacts). Confidence 80.

### D3 — SPEC-DX-006 presents inferred firewall-range rationale as fact (confidence 85)

The primary assigns service names to the four undocumented ranges: `6500-6599` = "EKS k3s API server", `9400-9499` = "OpenSearch data plane", `2200-2299` = "EC2 SSH", `9169` = "EC2 IMDS". I verified only the k3s API (6500-6599) is corroborated — `gaps-register.md` GAP-013b confirms "k3s API (6500-6599)". The other three assignments appear nowhere in `docs/` or `docs/scraped/`; they are plausible inferences from Floci's service set but unverified. The advisory's own CH-INST-003 framing is "Either add the same explanation… **or remove the rules**" — it does not assert what the ranges are for. Presenting inferences as established rationale violates the authoritative-reference skill (every claim must cite a source) and risks documenting a guess that a future reviewer treats as ground truth.

**Recommendation:** SPEC-DX-006 must label `9400-9499`, `2200-2299`, `9169` as INFERRED pending verification, OR — better, matching the advisory's "or remove the rules" alternative — add an acceptance criterion: "If a range's consumer cannot be confirmed against `docs/scraped/`, the requirement is to remove the UFW rule from `setup-floci.sh:83-92`, not document an unverified rationale." The primary silently dropped the advisory's removal alternative. Confidence 85.

## One-Sided Findings

### O1 — CH-AUTH-013 is entirely absent (confidence 95) — **CRITICAL GAP**

CH-AUTH-013 ("`FLOCI_AUTH_MODE` is never recorded on the host") is a documentation-relevant finding the primary dropped entirely. I verified the finding: `authentication-plan.md` §6.2's `write_env_file` block (lines ~332-339) emits `FLOCI_SERVICES_IAM_ENABLED`, `FLOCI_AUTH_VALIDATE_SIGNATURES`, `FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED`, `FLOCI_SERVICES_IAM_SEED_DEPLOYER_PRINCIPAL` — but NOT `FLOCI_AUTH_MODE` itself. The advisory notes §4.4's claim ("the env file retains the value from the original install") is only true of the derived variables, and `dev_status` / `preflight-floci.sh` / §6.7 next-steps all need the mode as input. This requires doc changes in three places: (a) §6.2 env-file spec must add `FLOCI_AUTH_MODE`, (b) §4.4 must be corrected (its "retains the value" claim is false for the mode), (c) `dev_status` output spec must surface the mode. The primary's claim of "13 findings analysed / 13 SPEC-DX" is a coverage overcount — there are 14 DX-relevant findings. This is a genuine miss, not a scoping judgment call.

**Recommendation:** Add SPEC-DX-014 (CH-AUTH-013): update §6.2 to emit `FLOCI_AUTH_MODE`; correct §4.4's retention claim; specify `dev_status` surfaces the mode. Confidence 95 — flagging via flag-protocol as a blocker because the primary's coverage claim ("no findings are missing") is demonstrably false.

### O2 — CH-LZ-012 wrong-mechanism comment not corrected (confidence 92)

CH-LZ-012 explicitly states: "Correct **both** the comment and auth plan §6.10c to state the real mechanism: `merge` precedence, silent override, no diagnostic." I verified `infra/environments/dev.tfvars:27-28` says "causes terraform plan warnings (duplicate key)" and `authentication-plan.md:731` (§6.10c) says "Duplicating them causes `terraform plan` warnings and breaks ABAC tag-match queries." Both encode the wrong mechanism — `merge` silently lets the later map win (per CH-LZ-011), it does NOT produce warnings. The primary's SPEC-DX-002 mentions §6.10c only as "already-landed, move to appendix" and never corrects the wrong-mechanism sentence inside it. Moving a wrong claim to an appendix preserves the error. This is a doc defect the advisory named and the primary skipped.

**Recommendation:** Add a requirement (under SPEC-DX-002 or a new SPEC-DX) to correct the mechanism wording in both `dev.tfvars:27-28` and `authentication-plan.md §6.10c` to "merge precedence silently overrides; no diagnostic." Confidence 92.

### O3 — CH-LZ-006 doc correction relegated to a parenthetical (confidence 88)

CH-LZ-006 is a substantive doc defect: §6.10b prescribes deprecated `force_path_style`/`endpoint` backend args and bypasses the repo's own `backend.hcl.example` template (which already uses `use_path_style` + `endpoints = {…}`). The advisory's fix reduces §6.10b to `-backend-config=../../_common/backend.hcl` plus a per-stage `key`. The primary only mentions CH-LZ-006 once, parenthetically in SPEC-DX-002 ("the init command in the plan is wrong (CH-LZ-006)"), and creates no acceptance criterion for actually correcting the §6.10b backend-init recipe. Since §6.10b is a doc block (an executable recipe in the auth plan), correcting it IS DX scope, not just a code-reference note.

**Recommendation:** Add an explicit acceptance criterion to SPEC-DX-002 (or a new SPEC-DX): "§6.10b's `terraform init` recipe uses `-backend-config=../../_common/backend.hcl` + per-stage `key=` override only; deprecated `force_path_style`/`endpoint` args removed; recipe matches `backend.hcl.example`." Confidence 88.

### O4 — Lessons-learned entries capture only 3 of 10 advisory rows (confidence 85)

The advisory's "Lessons-learned inputs" table has **10 rows**. The primary's SPEC-DX-013 captures only rows 2, 3, 4 (CH-META-001/002/003). It omits:
- Row #1 (CH-AUTH-001 — "re-read source line for qualifiers ('by default', 'unless')")
- Row #6 (CH-LZ-008 — "Remediation applied to the wrong file; verify post-fix state, not just the diff") — note CH-LZ-008 is undecided but the *lesson* is advisory-level and decided
- Row #7 (CH-AUTH-002/005/009 — "Do not mark fixed without an executed check; distinguish specified from verified") — directly reinforced by SPEC-DX-004, yet not captured as a lesson
- Row #8 (CH-AUTH-009 — "Behavioural claims about the shell must be executed on the target interpreter")
- Row #9 (CH-LZ-002/004/007 — "Every 'Enforced' row needs a named gate; a gate that cannot establish its precondition must fail, not skip")
- Row #10 (CH-LZ-009/010 — "If a convention says 'keep these identical', add a check that fails when they are not")

These are doc-relevant standing rules the primary dropped. The primary's acceptance criterion "Three lessons-learned entries are specified" understates the advisory's own input list.

**Recommendation:** SPEC-DX-013 must specify all 10 lessons (or explicitly justify exclusions row-by-row). The "candidates for inclusion in relevant skills" criterion (currently vague) should name the specific skill each standing rule targets (e.g., row #8 → `bash-scripting`; row #9 → `security-principles`/`compliance-gate`; row #10 → `cross-document-consistency`). Confidence 85.

### O5 — GAP-016 doesn't branch on the three-outcome probe result (confidence 82)

CH-AUTH-001 mandates running a three-outcome probe (rejected / accepted-and-namespaced-to-111111111111 / accepted-and-mapped-to-DEFAULT_ACCOUNT_ID) and states: "Record the result as a gap-register entry either way" and outcome (b) "would mean the estate's headline security claim is unenforced… auth plan §8 and landing-zone §1.1 would both be false and must be rewritten." The primary's GAP-016 entry says only "verify the three-outcome probe result" — it doesn't specify that the gap entry must (a) record WHICH outcome was observed, and (b) trigger a rewrite of auth-plan §8.3 + landing-zone §1.1 if outcome (b) holds. A gap entry that says "verify the result" without conditioning downstream doc rewrites on the outcome is incomplete.

**Recommendation:** GAP-016's action must state: "Run the probe; record the observed outcome (a/b/c); if outcome (b), auth-plan §8.3 and landing-zone §1.1 'Enforced' rows must be rewritten to 'Unenforced — signatures unchecked for 12-digit AKIDs'." Confidence 82.

### O6 — CH-INST-004 doc-consistency impact dropped (confidence 75)

CH-INST-004 (no preflight for `curl`/`openssl`) is framed as code-only. But `solution-design.md §12` (Environment file) documents the installer's behaviour, and AGENTS.md's "Critical gotchas" + `docs/testing-guide.md` describe the installer's dependencies. If `openssl`/`curl` become Phase-1 assertions, the docs that enumerate installer prerequisites should be consistent. Minor, but the primary's pattern elsewhere (e.g., SPEC-DX-006 extending to AGENTS.md) is to trace doc consistency for code changes — here it didn't.

**Recommendation:** Add a note that `solution-design.md §12` and any prerequisites list in `docs/testing-guide.md` must reflect the `openssl`/`curl` Phase-1 assertions once CH-INST-004 is implemented. Confidence 75 (advisory).

## Recommendations

1. **Fix the AGENTS.md line numbers** in SPEC-DX-007 (D1) — this is a factual correctness defect in the acceptance criteria.
2. **Add SPEC-DX-014 for CH-AUTH-013** (O1) — the primary's coverage claim is false; this is a blocker.
3. **Add the CH-LZ-012 mechanism correction** (O2) as an acceptance criterion under SPEC-DX-002 or a new SPEC-DX.
4. **Promote CH-LZ-006 from parenthetical to acceptance criterion** (O3) — the §6.10b backend-init recipe correction is DX scope.
5. **Expand SPEC-DX-013 to all 10 advisory lessons-learned rows** (O4) and name the target skill per standing rule.
6. **Branch GAP-016 on probe outcome** (O5) — the downstream doc rewrites depend on which of (a/b/c) is observed.
7. **Label SPEC-DX-006 inferred ranges as INFERRED or adopt the advisory's removal alternative** (D3).
8. **Reference and supersede the psc-0002 C1 verdict in SPEC-DX-005** (D2), and scope the grep to exclude `docs/project-management/logs/` historical artifacts.

## Verdict

**CONDITIONAL PASS**

The primary is structurally competent and most SPEC-DX requirements are accurate and well-traced. However, it contains one demonstrable coverage defect (CH-AUTH-013 entirely missing — O1), one factual error in acceptance criteria (wrong AGENTS.md line numbers — D1), two dropped doc corrections the advisory explicitly named (CH-LZ-012 mechanism wording — O2; CH-LZ-006 recipe relegation — O3), an under-counted lessons-learned set (3 of 10 rows — O4), an inference presented as fact (D3), and a missing prior-verdict citation (D2). The conditional-pass gates are O1 (blocker — coverage claim is false) and D1 (blocker — acceptance criteria cite wrong lines). The remainder are strong recommendations that should be addressed before Phase B implementation to avoid propagulating the defects into the docs themselves.
