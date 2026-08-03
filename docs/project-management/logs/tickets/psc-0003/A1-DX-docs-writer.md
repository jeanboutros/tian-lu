# A1-DX: Docs Writer Requirements — psc-0003

| Field | Value |
|-------|-------|
| Agent | docs-writer |
| Timestamp | 2026-07-30T00:00:00Z |
| Step | A1-DX |
| Phase | A |
| Ticket | psc-0003 |
| Source | psc-adv-0017-challenge-review |
| Verdict | APPROVED |

## Self-Audit Checklist

| Category | Checked? | Finding or PASS |
|----------|----------|-----------------|
| Build passes (exit 0, no warnings) | N/A | No code changes in this step — documentation requirements analysis only |
| Typed enums / vocabulary types (no raw integers in API) | N/A | No API surface changes in scope |
| Documentation on new public symbols | N/A | No new public symbols — this is a documentation requirements analysis |
| Spec/datasheet fidelity (fields match spec) | N/A | No hardware specs in scope |
| Module boundary (no platform headers in shared modules) | N/A | No code modules in scope |
| Reserved/padding fields handled | N/A | No serialisation in scope |
| No magic numbers in doc examples | N/A | No code examples in this analysis |
| Buffer safety (bounded copies) | N/A | No buffer operations in scope |
| AGENTS.md compliance | yes | PASS — all findings reference specific file:line locations; cross-document consistency impacts are traced; acceptance criteria are binary and verifiable |
| Conventional commit ready | N/A | No commits from this step |

## Documentation Requirements Analysis

### Scope

This analysis covers **13 DX-relevant findings** from the challenge advisory `psc-adv-0017-challenge-review`, spanning 6 target documents. Each finding is mapped to a SPEC-DX requirement with affected documents, required changes, cross-document consistency impact, and acceptance criteria.

---

### SPEC-DX-001 — CH-AUTH-001: Update landing-zone §4.1/§4.2; record gap for "three accounts on one instance" trade-off

**Finding source:** CH-AUTH-001 (blocker, confidence 90). The 12-digit-AKID account selection and SigV4 validation are mutually exclusive — a 12-digit AKID with a wrong secret cannot be verified under `sigv4`. The fix moves the account axis from the AKID to `FLOCI_DEFAULT_ACCOUNT_ID` (one Floci instance per environment).

**Documents affected:**
1. `docs/design/landing-zone-design.md` — §4.1 (Environment = account = AKID), §4.2 (Promotion model)
2. `docs/design/gaps-register.md` — new gap entry

**Required changes:**

1. **landing-zone-design.md §4.1** — Update the "Environment = account = AKID" section:
   - Add a statement that under `sigv4` mode, the environment is selected by the instance's `FLOCI_DEFAULT_ACCOUNT_ID`, not by the client's AKID.
   - Add a note that promotion therefore requires one Floci instance per environment.
   - Update the environment table to reference `FLOCI_DEFAULT_ACCOUNT_ID` as the selection mechanism.
   - The existing AKID values (`111111111111`, `222222222222`, `333333333333`) remain as the account identifiers — they are now set via `FLOCI_DEFAULT_ACCOUNT_ID` rather than derived from the client's AKID.

2. **landing-zone-design.md §4.2** — Update the promotion model:
   - The "same stage code applies unchanged" claim must be qualified: promotion requires a separate Floci instance with the target environment's `FLOCI_DEFAULT_ACCOUNT_ID`.
   - The `data.aws_caller_identity.current.account_id` pattern remains correct — it now returns the `FLOCI_DEFAULT_ACCOUNT_ID` value.
   - Add a note that the "three accounts on one instance" demonstration (using different 12-digit AKIDs from the same client) is not available with auth on.

3. **gaps-register.md** — Add a new gap entry:
   - **GAP-016** — "Three accounts on one instance" trade-off. Under `sigv4` mode, the 12-digit-AKID account selection mechanism is incompatible with signature validation because Floci cannot verify a signature against a key it never minted. The environment-as-account contract is preserved by using one Floci instance per environment with `FLOCI_DEFAULT_ACCOUNT_ID` set to the target account. The "three accounts on one instance" demonstration (different 12-digit AKIDs from the same client) is only available in `off` mode. Status: OPEN. Action: document this limitation in the landing-zone design and verify the three-outcome probe result.

**Cross-document consistency impact:**
- `authentication-plan.md` §6.10b (Terraform backend config) — the `access_key=111111111111` must change to the deployer's real AKID. This is a code change (not DX scope), but the DX must verify the docs are consistent after implementation.
- `solution-design.md` §8.3 (Multi-account isolation) — currently states "Multi-account isolation is automatic via 12-digit numeric access key IDs." Must be qualified: under `sigv4`, account selection is via `FLOCI_DEFAULT_ACCOUNT_ID`, not the client's AKID.
- `scripts/preflight-floci.sh` — G1's `DEV_AKID` usage must change. DX must verify the preflight docs are consistent.

**Acceptance criteria:**
- [ ] landing-zone-design.md §4.1 states that under `sigv4`, environment is selected by `FLOCI_DEFAULT_ACCOUNT_ID`
- [ ] landing-zone-design.md §4.1 notes that promotion requires one Floci instance per environment
- [ ] landing-zone-design.md §4.2 qualifies the "same code applies unchanged" claim
- [ ] gaps-register.md has GAP-016 entry documenting the trade-off
- [ ] Cross-reference: `solution-design.md` §8.3 is consistent with the new account selection model

---

### SPEC-DX-002 — CH-AUTH-012: Split §6.10a-d into changelog/appendix

**Finding source:** CH-AUTH-012 (low, confidence 100). §6.10a documents an already-landed change as pending work. A section headed "Explicit code changes" that mixes pending specifications with landed history is not safely executable.

**Documents affected:**
1. `docs/design/authentication-plan.md` — §6.10a through §6.10d

**Required changes:**

1. **authentication-plan.md** — Restructure §6.10a–d:
   - Move already-landed changes (§6.10a IAM permissions boundary, §6.10c Environment tag consistency, §6.10d IRSA stand-in) to a new appendix or changelog section.
   - Keep only pending specifications in §6.
   - The appendix should clearly label each entry as "Already applied" with the commit or PR reference.
   - §6.10b (Terraform backend configuration) is partially landed — the `_common/backend.hcl.example` exists but the init command in the plan is wrong (CH-LZ-006). This should remain in §6 as a pending spec.

**Cross-document consistency impact:**
- `landing-zone-design.md` §5.1 references the permissions boundary enforcement — must remain consistent with whatever form §6.10a takes after restructuring.
- `infra/live/10-management-iam/main.tf` — the actual code. The appendix entry must accurately describe what is in the tree.

**Acceptance criteria:**
- [ ] authentication-plan.md §6 no longer contains already-landed changes mixed with pending specs
- [ ] Already-landed changes are in a clearly labelled appendix or changelog section
- [ ] Each appendix entry states "Already applied" with a reference to the current code
- [ ] §6.10b remains in §6 as a pending specification (it needs correction per CH-LZ-006)

---

### SPEC-DX-003 — CH-AUTH-014: Add presign-secret threat model, rotation path, reuse-if-exists note to solution-design.md

**Finding source:** CH-AUTH-014 (low-medium, confidence 80). `FLOCI_AUTH_PRESIGN_SECRET` mints presigned S3 URLs that bypass the IAM layer. The Terraform state bucket is S3 — a presign capability over the state bucket is equivalent to administrative access to the estate.

**Documents affected:**
1. `docs/design/solution-design.md` — §8.2 (Presign secret)
2. `docs/design/authentication-plan.md` — cross-reference

**Required changes:**

1. **solution-design.md §8.2** — Expand the presign secret section:
   - **Threat model:** A presigned S3 URL bypasses IAM entirely — anyone holding a valid presigned URL can read/write the object regardless of their IAM credentials. Since the Terraform state bucket is S3 (landing-zone §9), a presign capability over the state bucket is equivalent to administrative access to the entire estate.
   - **Rotation path:** Document how to rotate the presign secret: generate a new value, update `floci.env`, restart Floci. Note that existing presigned URLs become invalid after rotation.
   - **Reuse-if-exists behaviour:** `generate_presign_secret` (`setup-floci.sh:793-801`) checks for an existing secret and reuses it. This means the secret survives every re-install until explicitly rotated. Document this as a deliberate design choice (preserves existing presigned URLs) with the security implication (a compromised secret persists across reinstalls).
   - Cross-link to `authentication-plan.md` for the broader IAM security model.

2. **authentication-plan.md** — Add a cross-reference in §8 (Security considerations) or §10 (Out of scope) noting that presigned URLs bypass IAM and referencing `solution-design.md` §8.2 for the threat model.

**Cross-document consistency impact:**
- `landing-zone-design.md` §9 (State management) — the S3 backend uses the same Floci instance. The presign threat model applies directly to the state bucket. Add a cross-reference.
- `landing-zone-design.md` §12 (Security model summary) — currently lists IAM as the primary boundary without noting the presign bypass. Add a note.

**Acceptance criteria:**
- [ ] solution-design.md §8.2 includes a threat model for presigned URLs
- [ ] solution-design.md §8.2 documents the rotation path
- [ ] solution-design.md §8.2 documents the reuse-if-exists behaviour and its security implication
- [ ] authentication-plan.md cross-references the presign threat model
- [ ] landing-zone-design.md §9 and §12 cross-reference the presign threat model

---

### SPEC-DX-004 — CH-AUTH-015: Mark §9.3 items as specified-not-verified

**Finding source:** CH-AUTH-015 (low, confidence 95). §9.3 states the partial-failure handling is "Fixed in §6.5" and the next-steps warning is "Fixed in §6.7". Per CH-AUTH-005 and CH-AUTH-006, neither is operative. A challenger-findings section that overstates closure suppresses the next review.

**Documents affected:**
1. `docs/design/authentication-plan.md` — §9.3

**Required changes:**

1. **authentication-plan.md §9.3** — Replace "Fixed" claims with "Specified — not yet verified":
   - Item "Partial-failure (delete fails) leaves well-known key active" — change "Fixed in §6.5 (checks `delete_rc`, emits WARNING)" to "Specified in §6.5 — not yet verified. The `delete_rc=$?` assignment is unreachable under `set -e` (CH-AUTH-005)."
   - Item "`_print_next_steps` must warn on sigv4 + failed rotation" — change "Fixed in §6.7 (gates on `DEV_AUTH_MODE=sigv4` with a fallback sub-branch)" to "Specified in §6.7 — not yet verified. The `DEV_AUTH_MODE` variable is never assigned (CH-AUTH-006)."
   - Add a general note: "Items marked 'specified-not-verified' have been designed but not yet tested. They will be re-evaluated after implementation."

**Cross-document consistency impact:**
- None — this is a status-label correction within a single document.

**Acceptance criteria:**
- [ ] authentication-plan.md §9.3 no longer claims items are "Fixed" when they are not operative
- [ ] Items are marked "Specified — not yet verified" with a reference to the relevant CH finding
- [ ] A general note explains the "specified-not-verified" status

---

### SPEC-DX-005 — CH-AUTH-016: Replace "Crypto theater" wording

**Finding source:** CH-AUTH-016 (trivial, confidence 100). §4.1:125 and §8.3:924 use "Crypto theater" — editorialising that should be replaced with the factual description.

**Documents affected:**
1. `docs/design/authentication-plan.md` — §4.1, §8.3
2. `docs/design/solution-design.md` — §8 (if the phrase appears there)

**Required changes:**

1. **authentication-plan.md §4.1:125** — Replace "**Crypto theater** — looks secure, authorizes everyone" with "**Authenticates callers and then ignores their policies** — looks secure, authorizes everyone"
2. **authentication-plan.md §8.3:924** — Replace "crypto theater" with "authenticates callers and then ignores their policies"
3. **solution-design.md §8** — Check for the phrase. The current text at line 137 says "crypto theater — looks secure, authorizes everyone". Replace with the same factual description.

**Cross-document consistency impact:**
- The phrase must be replaced consistently across all documents. Grep for "crypto theater" across the entire `docs/` tree.

**Acceptance criteria:**
- [ ] No occurrence of "Crypto theater" or "crypto theater" remains in any documentation file
- [ ] All replacements use the factual description: "Authenticates callers and then ignores their policies"

---

### SPEC-DX-006 — CH-INST-003: Document or drop the four extra firewall ranges

**Finding source:** CH-INST-003 (low, confidence 90). UFW opens `6500:6599`, `9400:9499`, `2200:2299`, and `9169`; the container publishes none of them. The `5100-5199` exclusion has a gotcha entry explaining that sidecars bind host-side directly; the other four ranges have no rationale anywhere.

**Documents affected:**
1. `docs/design/solution-design.md` — §10 (Port mapping)
2. `AGENTS.md` — Critical gotchas (add entry, or reference solution-design.md)

**Required changes:**

1. **solution-design.md §10.2** — Add documentation for the four extra firewall ranges:
   - `6500-6599` — EKS k3s API server. Bound directly on the host by the k3s sidecar container. Opened in UFW so `kubectl` and other clients can reach the k3s API.
   - `9400-9499` — OpenSearch data plane. Bound directly on the host by the OpenSearch sidecar container.
   - `2200-2299` — EC2 SSH. Bound directly on the host by EC2 mock containers.
   - `9169` — EC2 IMDS. Bound directly on the host by EC2 mock containers.
   - Add a note that these ports are NOT in the container's `-p` flags (they are direct-bind ports, same as the ECR registry 5100-5199 range).
   - If any of these ranges are NOT needed (e.g., EC2 mock containers are not used), document that the UFW rules should be removed or made conditional.

2. **AGENTS.md** — Add a gotcha entry (or extend the existing 5100-5199 entry) explaining that these four ranges are direct-bind ports from sidecar containers, not proxy-in-Floci ports, and must not be added to the container's `-p` flags.

**Cross-document consistency impact:**
- `setup-floci.sh:76-92` — the actual UFW rules and publish ports. The documentation must match the code.
- `solution-design.md` §10.1 (Container `-p` flags) and §10.2 (Direct-bind ports) — the four ranges should appear in §10.2 alongside the existing ECR registry entry.

**Acceptance criteria:**
- [ ] solution-design.md §10.2 documents all four extra firewall ranges with their service names and rationale
- [ ] Each range is clearly identified as a direct-bind port (not a container `-p` flag)
- [ ] AGENTS.md has a gotcha entry (or extended existing entry) explaining the direct-bind nature of these ports
- [ ] If any range is not needed, the documentation states that the UFW rule should be removed

---

### SPEC-DX-007 — CH-INST-005: Refresh AGENTS.md:57 and :64

**Finding source:** CH-INST-005 (trivial, confidence 100). Two stale line references in AGENTS.md.

**Documents affected:**
1. `AGENTS.md` — lines 57 and 64

**Required changes:**

1. **AGENTS.md:57** — The current text prescribes `systemctl --user -M floci@.host is-active --quiet default.target`. The actual code in `setup-floci.sh:656-657` uses `run_as_floci systemctl --user is-active --quiet default.target` (because `run_as_floci` sets `XDG_RUNTIME_DIR` and `DBUS_SESSION_BUS_ADDRESS`). Update the gotcha to match the code:
   - Change: "Poll `systemctl is-active --quiet user@<UID>.service` then `systemctl --user -M floci@.host is-active --quiet default.target`."
   - To: "Poll `systemctl is-active --quiet user@<UID>.service` then `run_as_floci systemctl --user is-active --quiet default.target`."

2. **AGENTS.md:64** — The current text cites `dev-twin.sh line 322` for the TLS override. The TLS override now lives at `dev-twin.sh:484` (the `FLOCI_TLS_ENABLED=false` in the `limactl shell` invocation). Update the line reference:
   - Change: "The production installer keeps TLS on (`FLOCI_TLS_ENABLED=true`, self-signed cert), but the dev twin overrides it to `false` at invocation time (`dev-twin.sh` line 322)."
   - To: "The production installer keeps TLS on (`FLOCI_TLS_ENABLED=true`, self-signed cert), but the dev twin overrides it to `false` at invocation time (`dev-twin.sh` line 484)."

**Cross-document consistency impact:**
- `setup-floci.sh:656-657` — the actual `enable_lingering` implementation. The doc must match.
- `dev-twin.sh:484` — the actual TLS override location. The doc must match.

**Acceptance criteria:**
- [ ] AGENTS.md:57 references `run_as_floci systemctl --user` (not `-M floci@.host`)
- [ ] AGENTS.md:64 references `dev-twin.sh` line 484 (not 322)
- [ ] Both line references are verified against the current code

---

### SPEC-DX-008 — CH-LZ-002: Qualify §1.1 and §5.2/§12; record gap for boundary evaluation unverified

**Finding source:** CH-LZ-002 (high, confidence 85). Permissions-boundary evaluation is claimed as enforced but never gated. Floci's documentation promises only identity-policy enforcement — boundary evaluation is a distinct IAM feature. No gate in §10.1 tests it.

**Documents affected:**
1. `docs/design/landing-zone-design.md` — §1.1 (Platform fidelity table), §5.2 (Permissions boundary), §12 (Security model summary)
2. `docs/design/gaps-register.md` — new gap entry

**Required changes:**

1. **landing-zone-design.md §1.1** — Update the "API authorization" row:
   - Current: "**Enforced** (requires `FLOCI_AUTH_VALIDATE_SIGNATURES=true`)"
   - New: "**Enforced** (identity policies — requires `FLOCI_AUTH_VALIDATE_SIGNATURES=true` and `FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED=true`). Permissions-boundary evaluation is **unverified** — see GAP-017."
   - Add a footnote or parenthetical: "Floci documents enforcement of identity policies on API calls. Whether it also evaluates permissions boundaries (the effective-permission intersection of identity policy and boundary) has not been tested."

2. **landing-zone-design.md §5.2** — Qualify the permissions boundary section:
   - Add a note at the top: "**Verification status:** The permissions-boundary evaluation described below is specified in Terraform but has not been verified against Floci's IAM implementation. Until gate G6 passes, the boundary is modeled, not confirmed as enforced."
   - The existing description of the boundary mechanism remains — it is correct as a specification.

3. **landing-zone-design.md §12** — Qualify the security model summary:
   - Current: "Primary boundary: IAM. One bounded role per application; delegated administration cannot escalate past the permissions boundary."
   - New: "Primary boundary: IAM. One bounded role per application; delegated administration cannot escalate past the permissions boundary (specified; boundary evaluation unverified — see GAP-017)."

4. **gaps-register.md** — Add a new gap entry:
   - **GAP-017** — Permissions-boundary evaluation unverified. Floci documents enforcement of identity policies on API calls (`FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED`). Whether it also evaluates permissions boundaries (the effective-permission intersection of identity policy and boundary) has not been tested. If Floci evaluates identity policies but ignores boundaries, the escalation ceiling described in landing-zone §5.1–§5.2 is modeled, not enforced. Status: OPEN. Action: add gate G6 — mint a role with a boundary denying `s3:*`, attach an identity policy allowing `s3:ListAllMyBuckets`, assume it, and require the call to be denied. Until G6 passes, §1.1's API authorization row must read "Enforced (identity policies); boundary evaluation unverified."

**Cross-document consistency impact:**
- `authentication-plan.md` §8.4 — references the permissions boundary as a security control. Should cross-reference the verification gap.
- `scripts/preflight-floci.sh` — G6 must be added (code change, not DX scope). DX must verify the preflight docs are consistent.

**Acceptance criteria:**
- [ ] landing-zone-design.md §1.1 API authorization row is qualified with "boundary evaluation unverified"
- [ ] landing-zone-design.md §1.1 names both enforcement variables (`FLOCI_AUTH_VALIDATE_SIGNATURES` and `FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED`)
- [ ] landing-zone-design.md §5.2 has a verification-status note at the top
- [ ] landing-zone-design.md §12 qualifies the permissions-boundary claim
- [ ] gaps-register.md has GAP-017 entry
- [ ] authentication-plan.md §8.4 cross-references the gap

---

### SPEC-DX-009 — CH-LZ-003: Relabel G1; add enforcement variables to §1.1 and §10.1

**Finding source:** CH-LZ-003 (medium, confidence 95). G1 is mislabelled — it tests enforcement (`FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED`), not signature validation (`FLOCI_AUTH_VALIDATE_SIGNATURES`). Neither enforcement variable appears anywhere in the landing-zone design.

**Documents affected:**
1. `docs/design/landing-zone-design.md` — §1.1 (Platform fidelity table), §10.1 (Prerequisites and pre-flight)

**Required changes:**

1. **landing-zone-design.md §1.1** — Update the "API authorization" row (combined with SPEC-DX-008):
   - Name both variables: `FLOCI_AUTH_VALIDATE_SIGNATURES=true` AND `FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED=true`
   - See SPEC-DX-008 for the full updated row text.

2. **landing-zone-design.md §10.1** — Update the G1 gate description:
   - Current label: "Signature authorization is ON (`FLOCI_AUTH_VALIDATE_SIGNATURES=true`) — a no-policy user is denied a privileged call."
   - New label: "IAM signature validation AND policy enforcement are ON (`FLOCI_AUTH_VALIDATE_SIGNATURES=true` AND `FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED=true`) — a no-policy user is denied a privileged call."
   - Add a note: "G1 tests enforcement (the no-policy user is denied), which requires both variables. Signature validation alone (`FLOCI_AUTH_VALIDATE_SIGNATURES=true` with enforcement off) would pass the signature check but allow the call — G1 would fail. Both must be `true` for the security model to hold."

**Cross-document consistency impact:**
- `scripts/preflight-floci.sh` — G1 implementation. The doc must match the code's actual test.
- `authentication-plan.md` §4.1 — the mode matrix. The doc must be consistent about which variable does what.

**Acceptance criteria:**
- [ ] landing-zone-design.md §10.1 G1 label names both `FLOCI_AUTH_VALIDATE_SIGNATURES` and `FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED`
- [ ] landing-zone-design.md §10.1 G1 description explains why both are needed
- [ ] landing-zone-design.md §1.1 names both variables (combined with SPEC-DX-008)

---

### SPEC-DX-010 — CH-LZ-005: Unify five region literals across docs

**Finding source:** CH-LZ-005 (medium, confidence 92). Five distinct region values are live across the stack: `us-east-1` (backend.hcl.example), `eu-west-2` (dev.tfvars, auth plan §6.10b), `eu-west-1` (setup-floci.sh, dev-twin.sh), `us-east-1` (preflight-floci.sh).

**Documents affected:**
1. `docs/design/landing-zone-design.md` — §6.2 (CIDR allocation), §10.2 (Apply order)
2. `docs/design/authentication-plan.md` — §6.10b (Terraform backend config)
3. `docs/design/solution-design.md` — §12 (Environment file)
4. `AGENTS.md` — any region references

**Required changes:**

1. **Identify the single source of truth per environment:**
   - Dev environment: `eu-west-2` (as declared in `dev.tfvars` and landing-zone §6.2)
   - The `FLOCI_DEFAULT_REGION` in `setup-floci.sh` and `solution-design.md` §12 must match the environment they target.
   - `preflight-floci.sh`'s `REGION` must match the environment it targets.
   - `backend.hcl.example`'s region must match the tfvars region.

2. **Document the region decision:**
   - Add a note in landing-zone-design.md §6.2 or a new §6.2a: "All region literals across the stack must match the environment's configured region. For dev, this is `eu-west-2`. The `FLOCI_DEFAULT_REGION` in the installer, the `REGION` in preflight-floci.sh, the backend region in `backend.hcl.example`, and the provider region in `dev.tfvars` must all agree. A mismatch causes resource/ARN divergence (resources created in one region are not visible to clients querying another)."

3. **Cross-reference CH-META-001:**
   - The original finding (psc-adv-0001 M-SW-001) claimed region mismatch breaks signature validation. The corrected mechanism (CH-META-001) is that it causes resource/ARN divergence. The documentation must reflect the corrected mechanism.

**Cross-document consistency impact:**
- `setup-floci.sh:54` — `FLOCI_DEFAULT_REGION=eu-west-1`. Must change to `eu-west-2` (or be parameterised).
- `scripts/preflight-floci.sh:25` — `REGION=us-east-1`. Must change to `eu-west-2` (or be parameterised).
- `dev-twin.sh:766` — `DEV_REGION=eu-west-1`. Must change to `eu-west-2`.
- `infra/_common/backend.hcl.example:12` — `region = "us-east-1"`. Must change to `eu-west-2`.
- `authentication-plan.md` §6.10b — `region=eu-west-2` (already correct, but must be verified against the unified value).

**Acceptance criteria:**
- [ ] landing-zone-design.md documents the single-source-of-truth region per environment
- [ ] landing-zone-design.md explains the consequence of region mismatch (resource/ARN divergence, not signing failure)
- [ ] All five region sites are identified and their required values documented
- [ ] The corrected mechanism from CH-META-001 is reflected (not the original "breaks signing" claim)

---

### SPEC-DX-011 — CH-LZ-007: Mark use_lockfile unverified in §9 and backend.hcl.example

**Finding source:** CH-LZ-007 (medium, confidence 90). `use_lockfile` (S3-native locking via `IfNoneMatch: *`) is offered as an alternative to DynamoDB locking, but no gate verifies that Floci's S3 honours the conditional `PutObject`. An ignored header means two concurrent applies both acquire the lock and corrupt state.

**Documents affected:**
1. `docs/design/landing-zone-design.md` — §9 (State management)
2. `infra/_common/backend.hcl.example` — line 19 (the `use_lockfile` comment)

**Required changes:**

1. **landing-zone-design.md §9** — Update the locking paragraph:
   - Current: "On Terraform ≥ 1.10, S3-native locking (`use_lockfile = true`) is an alternative."
   - New: "On Terraform ≥ 1.10, S3-native locking (`use_lockfile = true`) is an alternative, **but is unverified on Floci**. S3-native locking uses a conditional `PutObject` with `IfNoneMatch: *` — whether Floci's S3 honours this header has not been tested. Until gate G3b passes, use DynamoDB locking only."

2. **infra/_common/backend.hcl.example** — Update the `use_lockfile` comment:
   - Current: "# use_lockfile = true  # Terraform >= 1.10 S3-native locking (also verify with G3)"
   - New: "# use_lockfile = true  # Terraform >= 1.10 S3-native locking — UNVERIFIED on Floci. Requires G3b (S3 conditional PutObject). Do not enable until G3b passes."

**Cross-document consistency impact:**
- `scripts/preflight-floci.sh` — G3b must be added (code change, not DX scope). DX must verify the preflight docs are consistent.

**Acceptance criteria:**
- [ ] landing-zone-design.md §9 marks `use_lockfile` as unverified
- [ ] landing-zone-design.md §9 explains the mechanism (conditional PutObject with IfNoneMatch)
- [ ] landing-zone-design.md §9 states the consequence of an ignored header (concurrent apply, state corruption)
- [ ] backend.hcl.example comment is updated to mark `use_lockfile` as unverified

---

### SPEC-DX-012 — CH-LZ-013: Qualify §3 unbuilt scaffolding; cross-link presign secret to CH-AUTH-014; add TF_VAR_secret_key story to §10.1

**Finding source:** CH-LZ-013 (low, confidence 90). Three residual documentation gaps in the landing-zone design.

**Documents affected:**
1. `docs/design/landing-zone-design.md` — §3 (Terraform directory structure), §10.1 (Prerequisites and pre-flight), §12 (Security model summary)
2. Root `install.sh` — removal (not a doc change, but DX must verify it's gone)

**Required changes:**

1. **landing-zone-design.md §3** — Qualify unbuilt scaffolding:
   - Add a note at the top of §3 (or in the directory tree): "**Implementation status:** Only stages `00-backend-bootstrap` and `10-management-iam` are currently implemented. Stages 20–60 and `modules/workload-spoke/` are specified but not yet built. The directory structure and stage descriptions represent the full design intent."
   - This is the same class of fix as psc-adv-0002 M-DX-002 (which qualified the auth plan's unbuilt sections).

2. **landing-zone-design.md §10.1** — Add `TF_VAR_secret_key` story:
   - Add a prerequisite or note: "The `secret_key` variable (declared in `_common/providers.tf`) is required for Terraform to authenticate to Floci. It is not set in `dev.tfvars` and must be supplied via `TF_VAR_secret_key`. Source it from the rotated deployer credentials: `export TF_VAR_secret_key=$(grep DEV_BOOTSTRAP_SECRET ~/.cache/tianlu-twin/dev-credentials.env | cut -d= -f2)`. Without this, Terraform prompts interactively and non-TTY runs hang."
   - This is the seam where credential rotation lands — document the connection.

3. **landing-zone-design.md §12** — Cross-link presign secret:
   - Add a note: "**Presign bypass:** `FLOCI_AUTH_PRESIGN_SECRET` mints presigned S3 URLs that bypass IAM entirely. Since the Terraform state bucket is S3 (§9), a presign capability over the state bucket is equivalent to administrative access. See `solution-design.md` §8.2 for the threat model and rotation path."
   - Cross-link to CH-AUTH-014 / SPEC-DX-003.

4. **Root `install.sh`** — Verify removal. This is a code change (not DX scope), but DX must confirm the file is gone and no documentation references it.

**Cross-document consistency impact:**
- `solution-design.md` §8.2 — the presign threat model (SPEC-DX-003). The landing-zone cross-reference must be consistent.
- `authentication-plan.md` §5.3 — credential persistence. The `TF_VAR_secret_key` sourcing story must reference the same credential file.

**Acceptance criteria:**
- [ ] landing-zone-design.md §3 has an implementation-status note listing which stages are built vs. specified
- [ ] landing-zone-design.md §10.1 documents how to supply `TF_VAR_secret_key` from rotated credentials
- [ ] landing-zone-design.md §12 cross-references the presign-secret threat model
- [ ] Root `install.sh` is removed from the repository
- [ ] No documentation file references `install.sh`

---

### SPEC-DX-013 — CH-META-001/002/003: Record lessons-learned entries

**Finding source:** CH-META-001, CH-META-002, CH-META-003 (confidence 92 each). Three prior advisory findings had wrong mechanisms or unsafe recommendations. The lessons-learned inputs must be recorded.

**Documents affected:**
1. `docs/learning/` — lessons-learned entries (per the learning loop's isolation rules)
2. `docs/design/authentication-plan.md` — §9 (Challenger findings incorporated) — add cross-references to the lessons

**Required changes:**

1. **Create lessons-learned entries** in the learning docs directory. Per the learning loop isolation rules (`docs/learning/README.md`), these are written by the `/learn` command, not manually. The DX requirement is to **specify what must be recorded**, not to write the entries directly.

   The three lessons to record:

   **Lesson 1 (CH-META-001):** "Separate 'what is wrong' from 'why it is wrong' — the fix scope follows the mechanism."
   - A finding (psc-adv-0001 M-SW-001) claimed region mismatch breaks signature validation. The real consequence is resource/ARN divergence. The fix stopped at the auth plan's own literals, leaving five other region sites untouched, because the stated mechanism pointed at signing rather than at configuration coherence.
   - Standing rule: When a finding asserts a causal mechanism, verify it against the primary source before recording it as a blocker. The fix scope follows the mechanism — a wrong mechanism yields an incomplete fix.

   **Lesson 2 (CH-META-002):** "IAM Condition absent-key evaluation is a recurring trap."
   - A recommendation (psc-adv-0001 M-SW-002) offered "A or B" alternatives for an IAM policy condition. Both were applied, and the combination inverted the guardrail because `StringNotEquals` matches a null value when the condition key is absent from the request context.
   - Standing rules: (a) Recommendations must be single-valued, or state what happens if alternatives are combined. (b) Any IAM `Condition` on a service-specific key must state which actions populate that key. (c) Any Deny intended as a ceiling needs a negative test before it counts as landed.

   **Lesson 3 (CH-META-003):** "A finding that adds an environment variable must quote the source line documenting its default and effect."
   - A finding (psc-adv-0001 F-SW-001) conflated `FLOCI_SERVICES_IAM_ENABLED` (IAM service on/off) with `FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED` (policy enforcement). The remediation propagated the conflation into the mode matrix, a summary note, and a test specification.
   - Standing rule: A finding that adds a new environment variable to a configuration surface must quote the source line documenting that variable's default and effect.

2. **authentication-plan.md §9** — Add a cross-reference:
   - Add a subsection "§9.4 Lessons learned from prior findings" with brief summaries and links to the learning docs entries.

**Cross-document consistency impact:**
- The learning docs are isolated per `docs/learning/README.md`. The DX must not write into them directly — only specify the requirement.
- The standing rules should also be considered for inclusion in the relevant skills (e.g., `security-principles` for IAM condition rules, `bash-scripting` for env-var source-line quoting).

**Acceptance criteria:**
- [ ] Three lessons-learned entries are specified with their standing rules
- [ ] Each lesson references the originating finding (CH-META-001/002/003) and the prior advisory finding
- [ ] authentication-plan.md §9 cross-references the lessons
- [ ] The standing rules are candidates for inclusion in relevant skills

---

## Cross-Document Consistency Impact Summary

The following cross-document relationships must be verified after all changes are implemented:

| Relationship | Documents | Finding |
|-------------|-----------|---------|
| Account selection model | landing-zone-design.md §4.1/§4.2 ↔ solution-design.md §8.3 ↔ authentication-plan.md §6.10b | CH-AUTH-001 |
| Presign threat model | solution-design.md §8.2 ↔ landing-zone-design.md §9/§12 ↔ authentication-plan.md §8 | CH-AUTH-014, CH-LZ-013 |
| Permissions boundary verification | landing-zone-design.md §1.1/§5.2/§12 ↔ authentication-plan.md §8.4 ↔ gaps-register.md | CH-LZ-002 |
| Enforcement variable naming | landing-zone-design.md §1.1/§10.1 ↔ authentication-plan.md §4.1 ↔ preflight-floci.sh | CH-LZ-003 |
| Region literals | landing-zone-design.md §6.2 ↔ solution-design.md §12 ↔ authentication-plan.md §6.10b ↔ backend.hcl.example ↔ preflight-floci.sh | CH-LZ-005 |
| State locking verification | landing-zone-design.md §9 ↔ backend.hcl.example ↔ preflight-floci.sh | CH-LZ-007 |
| Credential sourcing | landing-zone-design.md §10.1 ↔ authentication-plan.md §5.3 ↔ dev-twin.sh | CH-LZ-013 |
| "Crypto theater" wording | authentication-plan.md §4.1/§8.3 ↔ solution-design.md §8 | CH-AUTH-016 |
| Firewall range documentation | solution-design.md §10.2 ↔ AGENTS.md ↔ setup-floci.sh | CH-INST-003 |
| AGENTS.md line references | AGENTS.md:57/64 ↔ setup-floci.sh:656-657 ↔ dev-twin.sh:484 | CH-INST-005 |

## Verdict

**VERDICT: APPROVED**

**Rationale:** All 13 DX-relevant findings from the challenge advisory have been analysed and mapped to 13 SPEC-DX requirements with concrete, verifiable acceptance criteria. Each requirement identifies the affected documents, the required changes, and the cross-document consistency impact. No findings are missing, no ambiguities remain, and all acceptance criteria are binary (pass/fail).

**Coverage:**
- 13 findings analysed
- 13 SPEC-DX requirements produced
- 6 target documents identified
- 10 cross-document consistency relationships traced
- 3 lessons-learned entries specified

**Routing:** This analysis proceeds to the Supreme Leader for A1 synthesis. Implementation of the documentation changes will be performed by the Docs Writer in Phase B (for doc-only changes) or by the Code Architect (for code changes that docs reference).
