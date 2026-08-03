# Advisory: Challenge Review — Auth Plan, Installer/Twin Scripts, Landing Zone

| Field | Value |
|-------|-------|
| ID | psc-adv-0017-challenge-review |
| Type | advisory (challenge) |
| Status | user decisions recorded; 3 findings awaiting decision |
| Confidence | 92 (per-finding confidence stated inline) |
| Priority | critical |
| Source ticket | psc-adv-0001 |
| Source agent | interactive challenge review (Claude Code, Opus 5) |
| Source file | this advisory is self-contained; verification commands in §Verification |
| Created | 2026-07-30 |
| Challenges | psc-adv-0001, psc-adv-0002, psc-adv-0003 (see §Prior advisories challenged) |

## Purpose

This is a **challenge advisory**. It re-reviews the artifacts covered by `psc-adv-0001` *after*
the psc-adv-0001…0007 remediation round, and reports:

1. Defects introduced or left unresolved **by** that round.
2. Defects in the target artifacts that the round did not reach.
3. Three prior findings whose stated **mechanism or recommendation was wrong**, where the
   remediation was applied faithfully and made the code worse. These are the primary
   lessons-learned inputs.

Every behavioural claim in this document was executed and confirmed, or is cited to a
primary source (AWS IAM documentation, Terraform S3 backend source, `docs/scraped/`).
Claims resting on inference are labelled **INFERRED** and carry a verification step.

## Scope — files and documents challenged

| # | Artifact | What is challenged | Findings |
|---|----------|--------------------|----------|
| 1 | `docs/design/authentication-plan.md` | Feasibility of §4–§7 as specified; correctness of the §6 code blocks; §6.10a–d Terraform additions; §9.3's claim that prior findings are fixed | CH-AUTH-001 … 016 |
| 2 | `setup-floci.sh` | `verify_health` failure policy, `assert_userns_allowed` idempotency on the target OS, firewall/publish asymmetry, missing command preflight | CH-INST-001 … 005 |
| 3 | `mock-server/dev-twin.sh` | Next-steps reachability, resume-path credential sync, `dev_disk_exists` error conflation, hardcoded mount path, fresh-install health budget | CH-DEV-001 … 006 |
| 4 | `mock-server/run-test.sh` | Verdict contract on precondition failure, dead sidecar validation, Quadlet ordering proof strength, evidence-dir semantics, `--fresh`/`--keep` | CH-TWIN-001 … 007 |
| 5 | `mock-server/in-vm/run-in-vm.sh` | Word-splitting under `IFS=$'\n\t'` for the auth-mode credential overrides specified in auth plan §6.10 | CH-AUTH-008 |
| 6 | `docs/design/landing-zone-design.md` | §1.1 enforcement claims, §4.1 account model vs §10.1 G1, §9 locking alternative, §10.1 gate labelling | CH-LZ-001 … 007 |
| 7 | `scripts/preflight-floci.sh` | G1 label vs implementation; G1 silent-SKIP on the configuration it exists to police | CH-LZ-003, CH-LZ-004 |
| 8 | `infra/live/10-management-iam/main.tf` | `DenyAllExceptBoundary` statement semantics (landed via psc-adv-0001 rec. 2) | CH-LZ-001 |
| 9 | `infra/live/10-management-iam/providers.tf` | Governance tag map gutted; provider constraint drift; backend key missing env prefix | CH-LZ-008, CH-LZ-009, CH-LZ-010 |
| 10 | `infra/_common/providers.tf` | `default_tags` merge order allows a tfvars file to override governance tags | CH-LZ-011 |
| 11 | `infra/_common/backend.hcl.example` | Backend region diverges from `dev.tfvars` provider region | CH-LZ-005 |
| 12 | `infra/environments/dev.tfvars` | Comment encodes the wrong mechanism from psc-adv-0002 rec. 2 | CH-LZ-012 |
| 13 | `AGENTS.md` | Stale `enable_lingering` prescription | CH-INST-005 |
| 14 | repo root | `install.sh` — unrelated third-party installer, untracked | CH-LZ-013 |

## Finding ID scheme

Prior advisories use `F-/M-/D-` + agent code. To avoid collision this advisory uses
`CH-<DOMAIN>-NNN` (CH = challenge). Domains: `AUTH` (auth plan), `INST` (`setup-floci.sh`),
`DEV` (`dev-twin.sh`), `TWIN` (test harness), `LZ` (landing zone + `infra/`),
`META` (corrections to prior advisories).

Each finding carries: **Severity**, **Confidence**, **Status** (VERIFIED / CITED / INFERRED),
**Location**, **Mechanism**, **Impact**, **Fix**.

## Prior advisories challenged

| Prior finding | Prior claim | This advisory | Outcome |
|---|---|---|---|
| psc-adv-0001 **M-SW-001** | "AWS SigV4 signs the region into the signature — this mismatch breaks the entire rotation flow" | CH-META-001 | **Mechanism wrong.** Region lives in the request's credential scope and the server derives it from the `Authorization` header; two clients signing different regions each verify. The real damage is resource/ARN visibility. Action (adopt `DEV_REGION`) was right; rationale must be corrected, and three region literals the fix did not reach remain (CH-LZ-005). |
| psc-adv-0001 **M-SW-002** | "Rewrite `DenyAllExceptBoundary` resources to `["*"]` **or** use `StringNotEquals` condition on `iam:PermissionsBoundary`" | CH-META-002 / CH-LZ-001 | **Recommendation unsafe.** Both were applied. `iam:PermissionsBoundary` is absent from the request context for the denied actions, and AWS documents that inverted operators **match** a null value — so the Deny now fires unconditionally on `Resource = "*"`. The guardrail became a blanket deny that breaks `terraform destroy`. |
| psc-adv-0001 **F-SW-001** | "`FLOCI_SERVICES_IAM_ENABLED` … is required for Floci to enforce IAM signatures" | CH-META-003 / CH-AUTH-003 | **Premise wrong.** `docs/scraped/environment-variables.md:160` documents it as the IAM *service* on/off switch, default `true`. Enforcement is `FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED:161`. The remediation sets it `false` in `off` mode, which disables IAM entirely and breaks preflight G1 and stage 10. |
| psc-adv-0001 **D-SW-001** | "Move `readonly` out of `case` to preserve `${VAR:-default}` test-injection" | CH-AUTH-002 | Applied correctly, but the resulting pattern reopens the `signatures=on, enforcement=off` state that auth plan §4.1 exists to forbid and §8.3 claims is impossible. |
| psc-adv-0001 **M-SX-003** | "Make credential-file write atomic" — user decision: *fix it* | CH-AUTH-007 | **Not applied.** Auth plan §6.5 still writes with `printf … >` then `chmod`. |
| psc-adv-0001 **M-SW-005** | "Add verification step between create and delete" — user decision: *fix it* | — | Applied correctly (§5.2c, §6.5). No challenge. |
| psc-adv-0001 **M-DX-003** | "Remove `secret=floci` from `print_summary`" — user decision: *fix it, masked* | — | Applied (§6.3 now says "well-known public credential"). No challenge. |
| psc-adv-0001 **M-DX-004** | "Document resume-path behaviour" — user decision: *document it* | CH-AUTH-006 | Documented (§4.4), but the §6.7 gate variable it depends on is never assigned, and `dev_recreate` — the procedure §4.4 prescribes — prints nothing. |
| psc-adv-0002 **M-SW-004** | "Remove `Environment = "development"` from `dev.tfvars`" | CH-LZ-008, CH-LZ-011, CH-LZ-012 | **Applied in the wrong file.** The governance trio was removed from `dev.tfvars` *and* deleted from `10-management-iam/providers.tf`'s `default_tags`, leaving that stage with no `Project`/`Environment`/`ManagedBy` at all. The merge-order hazard and the missing `environment` validation remain. |
| psc-adv-0002 **M-SW-003** | "Remove hardcoded `bucket` from `10-management-iam/providers.tf`" | CH-LZ-010 | Bucket removed, but the `key` left in place hardcodes `10-management-iam/terraform.tfstate` with **no `<env>/` prefix**, contradicting landing-zone §9's isolation scheme. |
| psc-adv-0002 **M-SX-005** | "Add `DurationSeconds` bound to IRSA stand-in" | — | Applied (§6.10d). No challenge. |
| psc-adv-0002 **F-DXS-005** | "Namespace dev-env profile to `tianlu-floci-dev`" | CH-AUTH-004 | Applied, but the block-replacement mechanism chosen to implement it destroys the *following* profile in `~/.aws/credentials`. |
| psc-adv-0003 (all) | "Code not implemented" — user decision: *only resurface gaps that affect implementation of the plan* | — | Honoured. This advisory reports no "not yet implemented" findings. Every CH-AUTH finding is a defect that would break the implementation if built as specified. |

---

## Findings

### A. Authentication plan (`docs/design/authentication-plan.md`)

---

#### CH-AUTH-001 — 12-digit-AKID account selection and SigV4 validation are mutually exclusive

- **Severity** blocker · **Confidence** 90 · **Status** CITED + INFERRED (probe specified below)
- **Location** auth plan §6.10b:694-721; `infra/_common/providers.tf:34-35`;
  `scripts/preflight-floci.sh:27,35`; `setup-floci.sh:55`; `infra/environments/dev.tfvars:11`
- **Sources** `docs/scraped/multi-account.md:9-10`, `:35`, `:60`, `:153`;
  `docs/scraped/environment-variables.md:10`

**Mechanism.** Floci resolves the account from the Access Key ID — *"If the AKID is exactly 12
digits, it is used as the account ID. Any other key format falls back to
`FLOCI_DEFAULT_ACCOUNT_ID`"* (`multi-account.md:9-10`). The same document, line 60:
*"The secret access key can be any non-empty string — Floci **does not validate signatures by
default**."* That qualifier is load-bearing: with `FLOCI_AUTH_VALIDATE_SIGNATURES=true`, Floci
must resolve a *secret* for the presented AKID in order to verify the signature.

Every credential pair the plan and the estate prescribe fails that resolution:

| Location | AKID | Secret | Verifiable under `sigv4`? |
|---|---|---|---|
| auth plan §6.10b:703-704 | `111111111111` | `floci` | **No** — `111111111111` was never minted by Floci IAM; there is no secret bound to it. The two halves belong to different credentials. |
| `_common/providers.tf:34-35` | `var.account_id` = `111111111111` | `var.secret_key` | **No** — same, for every stage. |
| `preflight-floci.sh:35` | `$DEV_AKID` = `111111111111` | `test` | **No** |
| auth plan §6.5 rotated key | `AKIA…` | matching random | **Yes** — but non-12-digit, so account = `FLOCI_DEFAULT_ACCOUNT_ID` = `000000000000` (`setup-floci.sh:55`) |

**Impact.** The only credential that can authenticate under `sigv4` resolves to account
`000000000000`, while `dev.tfvars:11` and landing-zone §4.1 declare dev to be `111111111111`.
Either the estate silently relocates to `000000000000` — and
`data.aws_caller_identity.current.account_id` returns `000000000000`, invalidating landing-zone
§4.2's claim that ARNs are "correct in any account" — or the requests are rejected outright and
no stage applies. There is no escape via `iam create-access-key`: the AKID is server-generated,
so a key whose ID is literally `111111111111` cannot be minted.

This is the plan's central unexamined assumption. It is not recorded in psc-adv-0001…0007.

**Fix (user-selected: option 1).** Move the account axis from the AKID to installer
configuration — one Floci instance per environment:

1. Add `FLOCI_DEFAULT_ACCOUNT_ID` to the dev-twin installer invocation (auth plan §6.4) so the
   dev instance's default account is the dev account id (`111111111111`), and document the
   per-environment value in landing-zone §4.1.
2. Change `_common/providers.tf` so `access_key` is the **deployer's real AKID** (rotated,
   sourced from `DEV_CREDENTIALS_FILE`) rather than `var.account_id`. Keep `var.account_id` as
   the *assertion* target — add a `data.aws_caller_identity` + `precondition` (or a `null_resource`
   check) that fails the plan when the resolved account id does not equal `var.account_id`.
   That preserves the environment-as-account contract while making it verifiable rather than
   implied.
3. Update `preflight-floci.sh:27,35` accordingly: the AKID must be the deployer key, not
   `DEV_AKID`; `DEV_AKID` becomes the *expected account id* the gates assert against.
4. Update landing-zone §4.1/§4.2 to state that under `sigv4` the environment is selected by
   the instance's `FLOCI_DEFAULT_ACCOUNT_ID`, not by the client's AKID, and that promotion
   therefore requires one instance per environment. Record the trade-off in the gaps register:
   the "three accounts on one instance" demonstration is not available with auth on.

**Verification (run regardless of the chosen option — it validates the fix, and the outcome
changes how much of §8 survives).** Against a `sigv4` Floci, establish which of three
behaviours holds for a 12-digit AKID with a wrong secret:

```sh
# a) rejected  → option 1 is mandatory, as designed
# b) accepted and namespaced to 111111111111
#    → sigv4 mode is security-NEUTRAL for any client using a 12-digit AKID,
#      because the secret is unchecked. Auth plan §8.3 and landing-zone §1.1
#      would both be false and must be rewritten.
# c) accepted and mapped to FLOCI_DEFAULT_ACCOUNT_ID → silent account relocation
AWS_ACCESS_KEY_ID=111111111111 AWS_SECRET_ACCESS_KEY=wrong-on-purpose \
  aws --endpoint-url http://localhost:4566 --region eu-west-2 sts get-caller-identity
```

Outcome (b) is the one to look for: it would mean the estate's headline security claim is
unenforced. Record the result as a gap-register entry either way.

---

#### CH-AUTH-002 — §4.2's test-injection pattern reopens the state §4.1 forbids

- **Severity** high · **Confidence** 95 · **Status** VERIFIED
- **Location** auth plan §4.2:136-171 and §6.1:280-313; claim contradicted at §4.1:121-129
  and §8.3:922-925
- **Challenges** psc-adv-0001 D-SW-001 remediation

**Mechanism.** The remediation correctly moved `readonly` out of the `case`, but the
`${VAR:-default}` form it adopted lets an exported sub-variable override the mode independently.

**Evidence.**

```
$ FLOCI_AUTH_MODE=off FLOCI_AUTH_VALIDATE_SIGNATURES=true bash -c '<§4.2 block>'
signatures=true enforcement=false
```

**Impact.** That is exactly the row auth plan §4.1:125 marks *"worse than leaving both off"* —
callers are authenticated and their policies are then ignored. §8.3's assertion, *"The installer
only allows both-on or both-off,"* is false as specified. The environment reaching the installer
is not fully controlled: `dev-twin.sh:484` and the guest driver both inject `FLOCI_*` variables
through `sudo bash -c`, so an inherited or mistyped export lands in the env file.

**Fix.** Derive the posture unconditionally from the mode; expose one explicit, named escape
hatch for tests. This satisfies both requirements without a hole:

```bash
# Auth posture is derived from FLOCI_AUTH_MODE and is NOT individually overridable:
# (signatures=on, enforcement=off) authenticates callers and then ignores their
# policies, which is strictly worse than leaving both off (§4.1). Tests that need an
# incoherent combination set FLOCI_AUTH_UNSAFE_OVERRIDE=1 and own the consequences.
readonly FLOCI_AUTH_MODE="${FLOCI_AUTH_MODE:-sigv4}"
case "$FLOCI_AUTH_MODE" in
  off)   _auth_on="false" ;;
  sigv4) _auth_on="true"  ;;
  *) printf 'ERROR: FLOCI_AUTH_MODE must be "off" or "sigv4" (got: %s)\n' "$FLOCI_AUTH_MODE" >&2
     exit 1 ;;
esac
if [[ "${FLOCI_AUTH_UNSAFE_OVERRIDE:-0}" == "1" ]]; then
  readonly FLOCI_AUTH_VALIDATE_SIGNATURES="${FLOCI_AUTH_VALIDATE_SIGNATURES:-$_auth_on}"
  readonly FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED="${FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED:-$_auth_on}"
else
  readonly FLOCI_AUTH_VALIDATE_SIGNATURES="$_auth_on"
  readonly FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED="$_auth_on"
fi
unset _auth_on
```

Tests then drive both postures via `FLOCI_AUTH_MODE`, which is the behaviour they should be
asserting. Add a bats case proving the hole is closed: `FLOCI_AUTH_MODE=off` +
`FLOCI_AUTH_VALIDATE_SIGNATURES=true` must yield `false` in the env file.

Secondary: `_auth_*` helpers are left set in the shell after §4.2 runs and are not `readonly`,
against the `AGENTS.md` "all parameters readonly in a single configuration block" convention.
`unset` them.

---

#### CH-AUTH-003 — `FLOCI_SERVICES_IAM_ENABLED=false` in `off` mode disables the IAM service

- **Severity** high · **Confidence** 92 · **Status** CITED
- **Location** auth plan §4.2:150, §6.1:294, §6.2:333
- **Source** `docs/scraped/environment-variables.md:160-161`
- **Challenges** psc-adv-0001 F-SW-001 premise

**Mechanism.** `FLOCI_SERVICES_IAM_ENABLED` (default **`true`**) is the IAM *service* on/off
switch. Enforcement is a separate variable, `FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED`
(default `false`). F-SW-001's premise — that `IAM_ENABLED` is "required for Floci to enforce IAM
signatures" — conflates the two.

**Impact.** Setting `IAM_ENABLED=false` in `off` mode turns IAM off outright:

- `preflight-floci.sh:45-48` cannot create its G1 probe user → G1 SKIPs (compounding CH-LZ-004).
- `infra/live/10-management-iam` cannot apply at all.
- Any stage referencing a role ARN fails.

`off` is the test-twin default (auth plan §4.3:182), so this would break the twin's IAM surface
in its default configuration.

**Fix.** `FLOCI_SERVICES_IAM_ENABLED=true` in both branches, or omit it entirely and let the
image default stand. Only `ENFORCEMENT_ENABLED` tracks the mode. Correct §6.2's note and the
SPEC-TX-006 case-3 direction accordingly — the assertion should be `=true` in *both* modes, not
mode-dependent.

---

#### CH-AUTH-004 — §6.6's `sed` range delete destroys the user's other AWS profiles

- **Severity** high (data loss on a file the twin does not own) · **Confidence** 98 · **Status** VERIFIED
- **Location** auth plan §6.6:513
- **Related** psc-adv-0002 F-DXS-005 (profile rename) — reduces collision odds, does not address this

**Mechanism.** `sed '/^\[tianlu-floci-dev\]/,/^\[/d'` deletes the range **inclusive of its
terminating line**. The terminating line is the *next* profile's header. That header is removed
while its key lines survive.

**Evidence.**

```
before:  [tianlu-floci-dev]        after:  aws_access_key_id = REAL_PROD_KEY
         aws_access_key_id = old           aws_secret_access_key = REAL_PROD_SECRET
         aws_secret_access_key = old
                                   (then §6.6 appends [tianlu-floci-dev] at EOF)
         [default]
         aws_access_key_id = REAL_PROD_KEY
         aws_secret_access_key = REAL_PROD_SECRET
```

**Impact.** The user's real `[default]` credentials are destroyed, and `~/.aws/credentials` is
left malformed — it opens with section-less key lines, which the AWS CLI rejects. After the
append, those orphaned keys sit above `[tianlu-floci-dev]`, so they are silently absorbed by
whatever section precedes them. §6.6 then `chmod 0600`s the wreckage.

**Fix.** Replace the range delete with a section-aware rewrite, and mirror
`setup-floci.sh:822-841`'s atomic pattern:

```bash
# Replace the managed [tianlu-floci-dev] block without touching neighbouring profiles.
# A sed range (/^\[x\]/,/^\[/d) also deletes its TERMINATING line — the next profile's
# header — orphaning that profile's keys. awk tracks section boundaries explicitly:
# drop lines only while inside our own section.
_creds_replace_block() {
  local file="$1" profile="$2" tmp
  tmp="$(mktemp "${file}.XXXXXX")"
  awk -v p="[$profile]" '
    /^\[/ { inblock = ($0 == p) }   # any header ends the previous section
    !inblock { print }
  ' "$file" 2>/dev/null > "$tmp" || true
  chmod 0600 "$tmp"
  mv -f "$tmp" "$file"
}
```

**User decision requires bats coverage.** Add to `mock-server/tests/dev_twin.bats`:

1. `[tianlu-floci-dev]` followed by `[default]` → `[default]` header **and** both of its keys
   survive verbatim; the managed block is replaced not duplicated.
2. `[tianlu-floci-dev]` as the last section → replaced cleanly, no residue.
3. `[tianlu-floci-dev]` absent → block appended, all pre-existing profiles byte-identical.
4. Two pre-existing unrelated profiles surrounding the managed block → both intact.
5. File absent → created with mode 0600, single block, `dev_env` exits 0.
6. Idempotency: two consecutive `dev_env` runs produce byte-identical output (no accumulating
   blank lines, no duplicate blocks).
7. Resulting file mode is 0600 and the first non-blank line is a section header (guards the
   orphaned-keys failure mode directly).

Note: `sed -i.bak` on a missing file is tolerable on this path — BSD sed warns and exits 0, and
`dev-twin.sh` is macOS-only via `assert_preconditions:419-421`. It exits 2 under GNU sed, so the
idiom must not be reused guest-side.

---

#### CH-AUTH-005 — §6.5's delete-failure handler is unreachable under `set -e`

- **Severity** high · **Confidence** 95 · **Status** VERIFIED (bash semantics)
- **Location** auth plan §6.5:454-464; `dev-twin.sh:2` (`set -euo pipefail`)
- **Challenges** psc-adv-0001 §9.3 claim: *"Fixed in §6.5 (checks `delete_rc`, emits WARNING)"*

**Mechanism.**

```bash
_run_as_floci_guest "podman exec … iam delete-access-key …"   # bare simple command
delete_rc=$?
```

Under `errexit`, a bare simple command returning non-zero terminates the shell. `delete_rc=$?` is
unreachable on precisely the path it exists to handle. `if`/`&&`/`||`/`!` are condition contexts;
a standalone call is not.

**Impact.** `dev-up` aborts mid-install when the old key cannot be deleted, and the WARNING that
§9.3 lists as the remediation for *"partial-failure leaves well-known key active"* never prints.
The stated fix is inoperative.

**Fix.**

```bash
delete_rc=0
_run_as_floci_guest "podman exec … iam delete-access-key …" || delete_rc=$?
```

The new `sts get-caller-identity` verification at §6.5:442-452 is correct — `if ! cmd` is a
condition context. Audit the rest of §6.5 for the same pattern before implementation.

---

#### CH-AUTH-006 — §6.7's gate variable is never assigned; `dev_recreate` prints nothing

- **Severity** medium · **Confidence** 95 · **Status** VERIFIED (static)
- **Location** auth plan §6.7:536 (`${DEV_AUTH_MODE:-off}`), §6.7:565-567 (claim), §6.4:369-373
  (does not set it); `dev-twin.sh:612`, `dev-twin.sh:681-701`
- **Related** psc-adv-0001 M-DX-004 (documented at §4.4, but the procedure it prescribes is silent)

**Mechanism.** Two independent breaks in the same user-facing path.

1. §6.7 gates on `${DEV_AUTH_MODE:-off}`. The trailing note claims it *"is set by
   `_install_absent`"*. §6.4's code block does not set it — it passes `FLOCI_AUTH_MODE=sigv4`
   into the **guest** environment via `sudo bash -c`, which never reaches the host shell. The
   default wins; section 7 is dead code.
2. `_print_next_steps` is reachable only from `dev_up` (`dev-twin.sh:594,608,612`).
   `dev_recreate:700` calls `_install_absent SKIP_PREFLIGHT` and returns without printing.

**Impact.** §4.4:191-192 names `make dev-recreate` as *the* way to change auth mode. A user
follows it, rotation runs, the well-known key is deleted — and they are never told where the new
credential is, nor warned if rotation fell back. Both branches of §6.7 are unreachable in the
one workflow that needs them.

**Fix.** Set `DEV_AUTH_MODE` host-side next to the install invocation (and derive the guest value
from it, per CH-AUTH-011); call `_print_next_steps` at the end of `dev_recreate`. Add a bats case
asserting the sigv4 security section appears for both `dev_up`-fresh and `dev_recreate`.

---

#### CH-AUTH-007 — §6.5 still writes the credential file non-atomically

- **Severity** medium · **Confidence** 90 · **Status** VERIFIED (static)
- **Location** auth plan §6.5:467-470
- **Challenges** psc-adv-0001 M-SX-003 — user decision was *fix it*; not applied

**Mechanism.** `printf … > "$DEV_CREDENTIALS_FILE"` then `chmod 0600`. Two windows: a crash
mid-write leaves a truncated file, and the file exists at umask permissions until the `chmod`.

**Impact.** The truncated case fails quietly in the worst direction. §6.6:501-509 sources the
file and `${DEV_BOOTSTRAP_AKID:-test}` falls back to `test/test` — so the user gets signature
failures against a `sigv4` Floci with no indication that their credential cache is corrupt.
`setup-floci.sh:822-841` already demonstrates the correct pattern in this codebase.

**Fix.** Write `.tmp`, `chmod 0600` the tmp, `mv -f`. Additionally: `source` on this file
*executes* it — parse instead (`while IFS='=' read -r k v`), which also removes the SC1090
suppressions at §6.5:417 and §6.6:502.

---

#### CH-AUTH-008 — §6.10's `$AWS_CREDS_ENV` collapses to a single argument

- **Severity** medium (breaks both modes, not just sigv4) · **Confidence** 98 · **Status** VERIFIED
- **Location** auth plan §6.10:604-611; `mock-server/in-vm/run-in-vm.sh:5` (`IFS=$'\n\t'`);
  call sites `run-in-vm.sh:194-196`, `:225-230`; helper `mock-server/in-vm/lib/assert.sh:233-244`
- **Distinct from** psc-adv-0004 F-BS-001 (which concerns `"$*"` inside `_run_as_floci_guest`)

**Mechanism.** Unquoted expansion splits on `IFS` only, and `IFS=$'\n\t'` contains no space.

**Evidence.**

```
$ /bin/bash -c 'IFS=$'"'"'\n\t'"'"'; V="-e A=1 -e B=2"; set -- $V; echo $#'
1
```

**Impact.** `podman` receives one malformed argument. The s3-smoke and Lambda steps fail in
`sigv4` mode, and the pattern is a latent trap for anyone copying it.

**Fix.**

```bash
# IFS is $'\n\t' here, so an unquoted string of flags does NOT word-split on spaces —
# it arrives as a single argument. Build the overrides as an array.
aws_creds_env=()
if [[ "$AUTH_MODE" == "sigv4" ]]; then
  aws_creds_env=(-e AWS_ACCESS_KEY_ID=floci -e AWS_SECRET_ACCESS_KEY=floci)
fi
run_as_floci_guest podman exec ${aws_creds_env[@]+"${aws_creds_env[@]}"} tianlu-floci aws …
```

The `${arr[@]+…}` guard is required — see CH-AUTH-009. Note the Lambda step
(`run-in-vm.sh:220-238`) passes a heredoc-style `bash -c` script, so the `-e` flags must be
inserted before `bash`, not inside the script.

---

#### CH-AUTH-009 — §6.10 removes an array guard that is still required

- **Severity** medium · **Confidence** 98 · **Status** VERIFIED
- **Location** auth plan §6.10:628 and its rationale at §6.10:636-641; `run-test.sh:4` (`set -u`),
  `run-test.sh:194` (existing guard)

**Mechanism.** §6.10 asserts: *"The `${arr[@]+...}` guard is no longer needed because
`printf '%q '` on an empty array produces an empty string (not an unbound-variable error)."*

**Evidence — the assertion is false on bash 3.2, which is `/bin/bash` on macOS:**

```
$ /bin/bash --version | head -1
GNU bash, version 3.2.57(1)-release (arm64-apple-darwin25)
$ /bin/bash -c 'set -u; a=(); printf "%q " "${a[@]}"'
/bin/bash: a[@]: unbound variable
```

(`${#a[@]}` is safe in 3.2; `${a[@]}` and `${a[*]}` are not. The distinction is why
`run-test.sh:429-438`'s `seen_get` is correct as written and needs no change.)

**Impact.** `run-test.sh` runs host-side with `#!/usr/bin/env bash`, so the interpreter is
PATH-dependent — Homebrew bash 5 is fine, `/bin/bash` is not. A default-flag run (`NO_SIDECAR`
false, `AUTH_MODE` unset) yields an empty array and aborts before the driver launches. The
existing guard at line 194 exists for exactly this reason.

**Fix.** Keep the guard: `printf '%q ' ${driver_args[@]+"${driver_args[@]}"}`. Moving from
`${driver_args[*]}` to `printf '%q '` is otherwise a genuine improvement and resolves
psc-adv-0004 F-BS-007. Consider `#!/usr/bin/env bash` + an explicit
`(( BASH_VERSINFO[0] >= 4 ))` precondition if 3.2 support is not wanted — but decide it
deliberately rather than by accident.

---

#### CH-AUTH-010 — §6.11's SPEC-TX-013 would fail every run

- **Severity** medium · **Confidence** 85 · **Status** VERIFIED (static)
- **Location** auth plan §6.11:852; `run-test.sh:228-235`

**Mechanism.** The spec reads *"`wait_driver` kills the transport before waiting (no hang)."*
`wait_driver` treats any non-zero status as fatal:
`FAIL_REASON="driver exited nonzero (${status}) despite DONE"`. Killing the transport yields 143.

**Impact.** Every successful run would report `TWIN: FAIL`.

**Fix.** Re-derive the hang before specifying the remedy — `systemd-run --wait` should return
once the driver writes `DONE` and exits (`run-in-vm.sh:352`), so a hang implies the driver did
not exit, which is itself the finding. If a bounded wait is wanted, distinguish the outcomes:
success, driver-failed (non-zero, no kill), and killed-after-timeout — and treat the third as a
distinct, named verdict rather than folding it into "driver exited nonzero".

---

#### CH-AUTH-011 — §6.5 has no auth-mode gate, contradicting SPEC-TX-002/003

- **Severity** low-medium · **Confidence** 90 · **Status** VERIFIED (static)
- **Location** auth plan §6.5:412-471 (ungated), §6.11:826-827 (SPEC-TX-002, SPEC-TX-003),
  §6.4:372 (hardcoded), §4.3:181 (implies configurable)

**Mechanism.** `_rotate_bootstrap_credentials` has no mode check, and §6.4 hardcodes
`FLOCI_AUTH_MODE=sigv4` in the dev-twin invocation. So the dev twin has no `off` mode at all —
yet §4.3's table presents dev-twin mode as a choice, and SPEC-TX-002/003 specify off-mode
behaviour that is unreachable.

**Fix.** `readonly DEV_AUTH_MODE="${DEV_AUTH_MODE:-sigv4}"` in the constants block (alongside
§6.1a); pass `FLOCI_AUTH_MODE="$DEV_AUTH_MODE"` in §6.4; early-return from rotation when the
mode is `off`. This also supplies the variable CH-AUTH-006 needs.

---

#### CH-AUTH-012 — §6.10a documents an already-landed change as pending work

- **Severity** low (process) · **Confidence** 100 · **Status** VERIFIED
- **Location** auth plan §6.10a:643-683; already present at `infra/live/10-management-iam/main.tf:49-69`

The change is in the tree. A section headed "Explicit code changes" that mixes pending
specifications with landed history is not safely executable — an implementer cannot tell which
blocks to apply. Compounded by the fact that this particular landed change is defective
(CH-LZ-001). Split §6.10a–d into a changelog or an "already applied" appendix.

---

#### CH-AUTH-013 — `FLOCI_AUTH_MODE` is never recorded on the host

- **Severity** low · **Confidence** 95 · **Status** VERIFIED (static)
- **Location** auth plan §6.2:332-337

`write_env_file` emits the three derived variables but not `FLOCI_AUTH_MODE` itself, so nothing
on the box records which posture it was installed with. `dev_status`, `preflight-floci.sh`, and
the §6.7 next-steps block all need that input, and §4.4's "the env file retains the value from
the original install" is only true of the derived variables. Emit `FLOCI_AUTH_MODE` as a
comment or a variable and have `dev_status` surface it.

---

#### CH-AUTH-014 — `FLOCI_AUTH_PRESIGN_SECRET` remains unaddressed

- **Severity** low-medium · **Confidence** 80 · **Status** CITED
- **Location** `setup-floci.sh:790-804`, `:835`; `docs/scraped/environment-variables.md:22`
- **Challenges** psc-adv-0001 M-SX-006 — user decision was *fix it*; not applied

Presigned URLs are verified against this secret and bypass the IAM layer the entire plan is
about. It matters more here than in a generic deployment because the Terraform state bucket is
S3 (landing-zone §9) — a presign capability over the state bucket is equivalent to
administrative access to the estate. The plan needs a threat model, a rotation path, and a note
that `generate_presign_secret`'s reuse-if-exists behaviour (`setup-floci.sh:793-801`) means the
secret survives every re-install until explicitly rotated.

---

#### CH-AUTH-015 — §9.3's fix list is now partly inaccurate

- **Severity** low (process) · **Confidence** 95 · **Status** VERIFIED
- **Location** auth plan §9.3:968-972

§9.3 states the partial-failure handling is *"Fixed in §6.5"* and the next-steps warning is
*"Fixed in §6.7"*. Per CH-AUTH-005 and CH-AUTH-006 neither is operative. A challenger-findings
section that overstates closure suppresses the next review. Mark items as
*specified-not-verified* until a test covers them.

---

#### CH-AUTH-016 — §4.1 wording

- **Severity** trivial · **Confidence** 100

§4.1:125 and §8.3:924 use "Crypto theater". "Authenticates callers and then ignores their
policies" states the same fact without editorialising, and matches the psc-adv-0001 acceptance
criterion prohibiting that register.

---

### B. `setup-floci.sh`

---

#### CH-INST-001 — `verify_health` aborts the install on any transient non-200

- **Severity** medium-high · **Confidence** 88 · **Status** VERIFIED (static)
- **Location** `setup-floci.sh:916-926`, `*)` branch at `:924`

**Mechanism.** The `case` retries only `000` (connection refused/timeout). Every other code
falls to `*)` and `exit 1`.

**Impact.** A JVM emulator returning `503` while warming up, or `404` before the health route is
registered, kills a run that would have succeeded seconds later — after the user has been
created, the image pulled, and the service started. `digital-twin-findings.md §9` documents a
2–3 minute AppArmor start race on this exact path, making a transient non-200 likely rather than
theoretical.

**Fix.** Retry `000` and `5xx`; fail fast only on `4xx` (a genuine wrong-endpoint or
wrong-scheme signal). Include the last observed code in the timeout message — currently
`:927` reports only the try count, which discards the one datum needed to diagnose it.

---

#### CH-INST-002 — `assert_userns_allowed` rewrites the profile and reloads AppArmor on every run, on the production OS

- **Severity** medium · **Confidence** 85 · **Status** INFERRED (static; confirm on 26.04)
- **Location** `setup-floci.sh:451-460` (sentinel), `:492-500` (block emission); docstring `:420-427`;
  `AGENTS.md:49` (*"Idempotent: no-op when a permitting profile is already loaded"*)

**Mechanism.** The idempotency sentinel is
`grep -q 'podman-userns' "$APPARMOR_PROFILES_FILE"`. On Ubuntu 26.04 the `apparmor-profiles`
package ships a podman profile, so `_system_profile_grants_userns "$PODMAN_BIN"` succeeds at
`:492` and the `podman-userns` block is **never written**. The sentinel therefore can never
match, `need_install` stays `true`, and every run rewrites `/etc/apparmor.d/podman-userns` and
runs `apparmor_parser -r`.

**Impact.** Outcome-idempotent, not action-idempotent — contradicting the docstring and
`AGENTS.md:49`. It reloads a security profile on every converged run, and the twin cannot catch
it: `run-in-vm.sh`'s `idempotency-hashes` criterion hashes the env file and Quadlet unit
(`:300-303`), not the AppArmor profile. 26.04 is the declared production target
(`AGENTS.md:89`), so this is the default path.

**Fix.** Make the sentinel per-binary: for each chain binary that needs a block, check whether
*that block's* profile name (`podman-userns`, `podman-userns-crun`, `newuidmap-userns`,
`newgidmap-userns`) is loaded. Extend the twin's hash set to include the AppArmor profile so the
regression is guarded.

---

#### CH-INST-003 — Firewall/publish asymmetry is undocumented

- **Severity** low · **Confidence** 90 · **Status** VERIFIED
- **Location** `setup-floci.sh:76-80` (published) vs `:83-92` (firewalled)

UFW opens `6500:6599`, `9400:9499`, `2200:2299`, and `9169`; the container publishes none of
them. The `5100-5199` exclusion has a gotcha entry (`AGENTS.md:45`) explaining that sidecars
bind host-side directly; the other four ranges have no rationale anywhere. Either add the same
explanation as an inline comment or remove the rules — an open port with no documented consumer
is a finding every future security review will re-raise.

---

#### CH-INST-004 — No preflight for `curl` and `openssl`

- **Severity** low · **Confidence** 90 · **Status** VERIFIED
- **Location** `setup-floci.sh:630-636` (installs `podman uidmap` only); consumers `:803`, `:917`

`generate_presign_secret` needs `openssl` (Phase 5) and `verify_health` needs `curl` (Phase 6).
Neither is asserted in Phase 1 nor installed in Phase 3. On a minimal Ubuntu image the run fails
in Phase 6 after all mutating work is done. Add both to Phase 1's assertions or to the
`apt-get install` list.

---

#### CH-INST-005 — `AGENTS.md:57` is stale

- **Severity** trivial · **Confidence** 100 · **Status** VERIFIED
- **Location** `AGENTS.md:57` vs `setup-floci.sh:656-657`

`AGENTS.md` prescribes `systemctl --user -M floci@.host is-active --quiet default.target`;
`enable_lingering` uses `run_as_floci systemctl --user is-active --quiet default.target`. The
code is correct (`run_as_floci` sets `XDG_RUNTIME_DIR` and `DBUS_SESSION_BUS_ADDRESS`); the doc
should match it. Same class as `AGENTS.md:64`, which cites `dev-twin.sh line 322` for the TLS
override that now lives at `dev-twin.sh:484`.

---

### C. `mock-server/dev-twin.sh`

---

#### CH-DEV-001 — `dev_recreate` prints no next steps

- **Severity** medium · **Confidence** 95 · **Status** VERIFIED
- **Location** `dev-twin.sh:681-701`; cf. `dev_up:594,608,612`

Standalone defect, independent of the auth plan; becomes user-visible harm once rotation exists
(CH-AUTH-006). `make dev-recreate` completes with no output about endpoints, profile, or hosts
entry.

**Fix.** Call `_print_next_steps` at the end of `dev_recreate`.

---

#### CH-DEV-002 — Resume paths never refresh the AWS profile

- **Severity** medium · **Confidence** 90 · **Status** VERIFIED
- **Location** `dev-twin.sh:488` (only call site of `dev_env`); `dev_up:589-609`

`dev_env` runs only from `_install_absent`. After `dev-down`/`dev-up`, `~/.aws/credentials` is
whatever it was. Harmless today; once the credential cache exists, cache and profile can diverge
with no reconciliation, and the failure presents as an opaque signature error.

**Fix.** Call `dev_env` on the `Running` and `Stopped` branches — it is idempotent by design
(and must remain so; see CH-AUTH-004 test 6).

---

#### CH-DEV-003 — `dev_disk_exists` conflates "absent" with "query failed"

- **Severity** medium · **Confidence** 92 · **Status** VERIFIED
- **Location** `dev-twin.sh:112-120`; callers `:465-474`, `:690-698`, `:726-752`

**Mechanism.** The function returns `1` when `limactl disk list` fails (`:103`, after printing an
error) *and* when `grep` finds no match (`:119`). All three callers branch on `rc -eq 1` as
though it meant "absent" — the `if [[ $rc -eq 1 ]] … else return 1` structure implies `rc>1`
signals a query error, but nothing ever returns `>1`.

**Impact.** A transient `limactl` failure takes the "create the disk" path in `_install_absent`,
and in `dev_reset` it takes the "no disk to delete" path — silently skipping the delete the user
just confirmed.

**Fix.** Return `2` on query failure; branch on all three states explicitly. Same conflation
exists in `dev_disk_state_safe:122-133`, which maps a query failure to the string `unavailable` —
that one is correct and can serve as the model.

---

#### CH-DEV-004 — `DEV_DISK_NAME` is configurable but the mount path is hardcoded

- **Severity** medium · **Confidence** 95 · **Status** VERIFIED
- **Location** `dev-twin.sh:7` (`DEV_DISK_NAME` overridable) vs literal `/mnt/lima-floci-dev-data`
  at `:137`, `:446`, `:478`, `:479`

Overriding `DEV_DISK_NAME` — which line 7's `${VAR:-default}` form explicitly invites — breaks
`verify_disk_mount`, the mode-1777 assertion, and the systemd `ExecCondition` silently. Lima
derives the mount from the disk name, so the two cannot be independent.

**Fix.** `readonly DEV_DISK_MOUNT="${DEV_DISK_MOUNT:-/mnt/lima-${DEV_DISK_NAME}}"` and use it at
all four sites. Note `:446` embeds the path inside a nested-quoted `printf` for the drop-in file;
that one needs care.

---

#### CH-DEV-005 — Fresh install has a shorter health budget than resume, and no failed-unit fallback

- **Severity** medium · **Confidence** 88 · **Status** VERIFIED
- **Location** `_health_check:304-315` (60 × 2s = 120s, no reset) vs
  `_resume_health_check:503-521` (150 × 2s = 300s + `failed`-state reset);
  budgets at `:21-22`, `:43-44`

The AppArmor race is documented at 2–3 minutes (`digital-twin-findings.md §9`, quoted in
`dev-twin.sh:37-40`) and applies to first boot as much as to resume. A fresh `dev-up` on a cold
QEMU arm64 boot can therefore time out where a resume would recover. `run-test.sh` gives both
paths 300s (`REBOOT_HEALTH_BUDGET`, `:24`).

**Fix.** Give the fresh path the same budget and the same `_reset_floci_service` fallback —
`_resume_health_check` is already the more correct implementation; use it for both and keep the
distinct error strings.

---

#### CH-DEV-006 — Redundant inner guard makes `main` untestable

- **Severity** trivial · **Confidence** 100 · **Status** VERIFIED
- **Location** `dev-twin.sh:780` duplicating `:799`

The `if [[ "${BASH_SOURCE[0]}" == "${0}" ]]` inside `main` duplicates the bottom guard and makes
`main` uncallable from bats, so argument dispatch cannot be tested. Drop the inner one.

---

### D. `mock-server/run-test.sh`

---

#### CH-TWIN-001 — Precondition failures skip the machine-readable verdict

- **Severity** medium · **Confidence** 95 · **Status** VERIFIED
- **Location** `run-test.sh:539` (called outside the guarded block), `:42-45` (`die` → `exit 1`),
  `:49-61`; contract stated at `:525`

`assert_preconditions` exits directly on a missing `limactl`, non-arm64 host, or macOS < 13.
`main`'s docstring promises *"a verdict after every failure"*, and `print_verdict` (`:514-522`) is
the machine-readable contract — any CI wrapper grepping for `TWIN:` sees nothing.

**Fix.** Route preconditions through `FAIL_REASON` + `print_verdict`, or move the call inside the
guarded block.

---

#### CH-TWIN-002 — Host never validates the sidecar result; the special case is unreachable

- **Severity** medium · **Confidence** 92 · **Status** VERIFIED
- **Location** `run-test.sh:451-452` (`mandatory` array), `:475-477` (special case inside
  `for c in "${mandatory[@]}"`); guest side `run-in-vm.sh:28`, `:210`, `:248`

`sidecar-delta` is not in `mandatory`, so the
`if [[ "$c" == "sidecar-delta" && "$NO_SIDECAR" == true ]]` branch can never be reached. The
guest driver does fail the run via the `FAILED` sentinel (`run-in-vm.sh:241,245`), so this is not
an open hole today — but the host-side code reads as coverage that does not exist, and the guest
initialises `CRITERIA[sidecar-delta]=FAIL` (`:28`), so any future path that publishes `DONE`
without setting it would pass unnoticed.

**Fix.** Add `sidecar-delta` to `mandatory` — the special case then becomes live and correct — or
delete the special case.

---

#### CH-TWIN-003 — The Quadlet ordering proof is weaker than claimed

- **Severity** medium · **Confidence** 85 · **Status** VERIFIED
- **Location** `run-test.sh:394-402`; the sound assertions are at `:376-391`

**Mechanism.** The check compares the first `grep -n` line number of `podman.socket` against the
first for `floci.service` in a single-boot journal. Journal line order is not activation order,
and any earlier *mention* of the socket satisfies it regardless of actual start sequence.

**Impact.** `run_reboot_test` can downgrade `ordering_result` to `FAIL` (`:401`) on log-format
variance, and conversely passes without proving ordering. The `After=`/`Requires=` property
checks at `:376-391` are the real evidence.

**Fix.** Either match activation records (`Started`/`Listening`) with timestamps, or drop the
journal comparison and rely on the property assertions plus `service_active`.

---

#### CH-TWIN-004 — Stale-sentinel cleanup targets the wrong directory

- **Severity** low · **Confidence** 100 · **Status** VERIFIED
- **Location** `run-test.sh:181` vs `poll_sentinel:210,214`

`rm -f "${HOST_EVIDENCE_MOUNT}/DONE" "${HOST_EVIDENCE_MOUNT}/FAILED"` — the sentinels live in
`$STAGING`. Harmless because `rm -rf "$STAGING"` (`:180`) does the real work, but it reads as a
guard that is not one, and would mask a real bug if line 180 were ever removed.

---

#### CH-TWIN-005 — `--evidence-dir` only relocates the final copy

- **Severity** low-medium (documentation) · **Confidence** 95 · **Status** VERIFIED
- **Location** `run-test.sh:88-94`, `:112`, `:174-175`, `usage:36-38`

`HOST_EVIDENCE_MOUNT` and `STAGING` are hardcoded to `${HOST_HOME}/.cache/tianlu-twin/evidence`
because that path is the 9p mount declared in the Lima template — correct, but `usage` implies
the flag moves the evidence directory. `EVIDENCE_DIR_ROOT` (`:13`) has the same limitation.
Document the split in `usage` and in `docs/design/digital-twin-testing-design.md`.

---

#### CH-TWIN-006 — `--fresh` and `--keep` are not opposites

- **Severity** low · **Confidence** 95 · **Status** VERIFIED
- **Location** `run-test.sh:70-78` (`--fresh` sets `KEEP=false`), `teardown:503-510`, `usage:37`

With `--fresh` and no `--destroy`, `teardown` falls through both branches and does nothing — the
VM is left running exactly as with `--keep`. `usage` presents them as alternatives
(`[--fresh|--keep]`). Also order-dependent: `--keep` after `--fresh` is ignored (`:75-77`) but
`--fresh` after `--keep` wins.

**Fix.** Decide the intent — either `--fresh` implies teardown, or stop clearing `KEEP` — and
make `usage` match.

---

#### CH-TWIN-007 — Two minor robustness gaps

- **Severity** low · **Confidence** 90 · **Status** VERIFIED
- `run-test.sh:229` — `wait "${DRIVER_SHELL_PID:-}"` with an empty PID yields 127, producing
  `driver exited nonzero (127) despite DONE`, which misattributes the failure.
- `run-test.sh:11` — `HOST_HOME="${HOME:-$(id -un)}"` falls back to a *username* where a path is
  required; every derived path would be relative and land in the CWD. Fail instead.

---

### E. Landing zone (`docs/design/landing-zone-design.md`, `infra/`, `scripts/preflight-floci.sh`)

---

#### CH-LZ-001 — `DenyAllExceptBoundary` is an unconditional deny

- **Severity** high · **Confidence** 92 · **Status** CITED (AWS documentation)
- **Location** `infra/live/10-management-iam/main.tf:49-69`; specified at auth plan §6.10a:655-683;
  claimed at landing-zone §5.1:208-217, §12:443-444
- **Challenges** psc-adv-0001 M-SW-002 recommendation (CH-META-002)

**Mechanism.** AWS IAM,
[Policy variables with no value](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_variables.html):

> When you use a variable with no value in the condition element of an IAM policy, condition
> operators like `StringEquals` or `StringLike` do not match… **Inverted condition operators like
> `StringNotEquals` or `StringNotLike` do match against a null value**, as the value of the
> condition key they are testing against is not equal to or like the effectively null value.

`iam:PermissionsBoundary` is present in the request context only for operations that *attach* a
boundary — `CreateRole`, `CreateUser`, `PutRolePermissionsBoundary`,
`PutUserPermissionsBoundary`. It is absent for `iam:DeletePolicy`, `iam:DeletePolicyVersion`, and
every `Delete*PermissionsBoundary`. The key is therefore null, `StringNotEquals` matches, and with
`resources = ["*"]` the Deny fires on **every** one of those calls.

**Impact.** `platform-admin` can never delete any policy or policy version, anywhere.
`terraform destroy` on stage 10 fails. `terraform apply` fails once a customer-managed policy
reaches the five-version limit and needs `DeletePolicyVersion`. The condition is inert — the
statement is equivalent to having no condition at all. IAM Access Analyzer flags this class as
`EQUIVALENT_TO_NULL_FALSE`
([policy check reference](https://docs.aws.amazon.com/IAM/latest/UserGuide/access-analyzer-reference-policy-checks.html)).
The delegated-administration ceiling that landing-zone §5.1 and §12 describe does not exist in
either direction: creation without a boundary is *not* denied, because no statement covers
`iam:CreateRole` at all.

Note also `iam:DeleteGroupPermissionsBoundary` (`main.tf:55`) is not an IAM API action —
permissions boundaries apply to users and roles only
([API reference](https://docs.aws.amazon.com/IAM/latest/APIReference/API_PutUserPermissionsBoundary.html)).

**Fix.** Split by whether the condition key exists in the request context:

```hcl
# Boundary-attachment ceiling. iam:PermissionsBoundary IS present in the request context
# for these actions, so StringNotEquals is meaningful: platform-admin may mint principals
# only when the designated boundary is attached.
statement {
  sid    = "DenyPrincipalCreationWithoutBoundary"
  effect = "Deny"
  actions = [
    "iam:CreateRole", "iam:CreateUser",
    "iam:PutRolePermissionsBoundary", "iam:PutUserPermissionsBoundary",
  ]
  resources = ["*"]
  condition {
    test     = "StringNotEquals"
    variable = "iam:PermissionsBoundary"
    values   = [aws_iam_policy.general_app_boundary.arn]
  }
}

# Boundary-removal ceiling. iam:PermissionsBoundary is NOT in the request context for
# these actions — an inverted operator matches the null value and would deny them
# unconditionally. Scope by resource, with no condition.
statement {
  sid       = "DenyBoundaryPolicyMutation"
  effect    = "Deny"
  actions   = ["iam:DeletePolicy", "iam:DeletePolicyVersion",
               "iam:CreatePolicyVersion", "iam:SetDefaultPolicyVersion"]
  resources = [aws_iam_policy.general_app_boundary.arn]
}

statement {
  sid       = "DenyBoundaryDetach"
  effect    = "Deny"
  actions   = ["iam:DeleteRolePermissionsBoundary", "iam:DeleteUserPermissionsBoundary"]
  resources = ["*"]
}
```

Add a negative test to the G-series (see CH-LZ-002) rather than trusting the policy text.

---

#### CH-LZ-002 — Permissions-boundary *evaluation* is claimed as enforced but never gated

- **Severity** high · **Confidence** 85 · **Status** INFERRED (absence of evidence; probe specified)
- **Location** landing-zone §1.1:30, §5.2:218-224, §12:443-444, §10.1:388-398;
  `docs/scraped/environment-variables.md:161`

**Mechanism.** §1.1 lists API authorization as **Enforced**, and §5.2/§12 build the escalation
ceiling on the boundary being the effective-permission intersection. The scraped documentation
promises only *"enforce IAM policies on API calls"* (`:161`). Permissions-boundary evaluation is
a distinct IAM feature from identity-policy evaluation; nothing in `docs/scraped/` states that
Floci implements it, and no gate in §10.1 tests it.

**Impact.** If Floci evaluates identity policies but ignores boundaries, §5.1–§5.2 are *modeled*,
not enforced — and that is the single most important security claim in the design. The
consequence is exactly the "false demo" class §10.1 exists to prevent.

**Fix.** Add gate G6: mint a role with a boundary denying `s3:*`, attach an identity policy
allowing `s3:ListAllMyBuckets`, assume it, and require the call to be **denied**. Until G6
passes, §1.1's row must read "Enforced (identity policies); boundary evaluation unverified", and
§5.2/§12 must be qualified. Record as a gap-register entry.

---

#### CH-LZ-003 — G1 is mislabelled; the design never names the enforcement variables

- **Severity** medium · **Confidence** 95 · **Status** VERIFIED
- **Location** landing-zone §10.1:390 (label), §1.1:30; implementation
  `scripts/preflight-floci.sh:42-59`

**Mechanism.** §10.1 states G1 asserts *"Signature authorization is ON
(`FLOCI_AUTH_VALIDATE_SIGNATURES=true`)"*. What `gate_g1_signatures` tests is that a no-policy
user is **denied** a privileged call — which is `FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED`. With
signatures on and enforcement off, the correctly-signed call succeeds and G1 fails. The test is
the right test; the label names the wrong variable.

Neither `FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED` nor `FLOCI_SERVICES_IAM_SEED_DEPLOYER_PRINCIPAL`
appears anywhere in `landing-zone-design.md`, so the document describes an enforced IAM model
without naming the switch that enforces it.

**Fix.** Relabel G1 to reference both variables; add them to §1.1's row and to §10.1's
prerequisites.

---

#### CH-LZ-004 — G1 degrades to SKIP where the design promises a hard stop

- **Severity** high · **Confidence** 95 · **Status** VERIFIED
- **Location** `scripts/preflight-floci.sh:46-48`, `:31` (`skip` does not set `FAILED`), `:127`;
  landing-zone §10.1:398 (*"this is a hard stop"*)

**Mechanism.** If `create-access-key` fails, G1 calls `skip` and returns. `skip` does not set
`FAILED`, so `main` reports *"automated gates passed"* and exits 0.

**Impact.** Under `sigv4` with the default credentials (`$DEV_AKID` + `test`, `:35`) the call
always fails — see CH-AUTH-001 — so the gate the design calls a hard stop reports success on
precisely the configuration it exists to police. Compounded by CH-AUTH-003: with
`IAM_ENABLED=false` in `off` mode, it also always skips.

**Fix.** G1 must `fail` when it cannot establish the probe: an unestablished gate is not a passed
gate. Distinguish "IAM unreachable" from "IAM reachable and permissive" in the message, and make
`main` exit non-zero on any SKIP among the automated gates (G1, G3) while leaving the
manual-notes gates (G2, G4, G5) as SKIP.

---

#### CH-LZ-005 — Backend region diverges from provider region; three region literals remain

- **Severity** medium · **Confidence** 92 · **Status** VERIFIED
- **Location** `infra/_common/backend.hcl.example:12` (`us-east-1`) vs
  `infra/environments/dev.tfvars:13` (`eu-west-2`); also `setup-floci.sh:54` (`eu-west-1`),
  `scripts/preflight-floci.sh:25` (`us-east-1`), `dev-twin.sh:766` (`eu-west-1`)
- **Related** psc-adv-0001 M-SW-001 — the `DEV_REGION` fix did not reach these five sites

The state bucket is created by stage 00 under the provider region and read by every other stage
under the backend region. Four distinct region values are live across the stack; auth plan
§6.10b introduces a fifth surface at `eu-west-2`.

**Fix.** Single source of truth per environment. `backend.hcl` region must equal the tfvars
region; `setup-floci.sh`'s `FLOCI_DEFAULT_REGION` and `preflight-floci.sh`'s `REGION` must match
the environment they target. See CH-META-001 for the corrected rationale — this is a
resource-visibility and ARN-correctness issue, not a signing issue.

---

#### CH-LZ-006 — §6.10b regresses to deprecated backend arguments and bypasses the repo's own template

- **Severity** medium · **Confidence** 95 · **Status** CITED (Terraform source)
- **Location** auth plan §6.10b:697-709; correct form already at
  `infra/_common/backend.hcl.example:31-36`; documented at landing-zone §10.2:414-418

**Mechanism.** §6.10b prescribes `-backend-config="endpoint=…"` and
`-backend-config="force_path_style=true"`. Both are superseded. From the Terraform S3 backend
implementation (`internal/backend/remote-state/s3/backend.go`):

```go
validateAttributesConflict(
	cty.GetAttrPath("force_path_style"),
	cty.GetAttrPath("use_path_style"),
)(obj, cty.Path{}, &diags)
…
diags = diags.Append(deprecatedAttrDiag(attrPath, cty.GetAttrPath("use_path_style")))
```

`force_path_style` is deprecated in favour of `use_path_style`, and the two are mutually
exclusive; `endpoint` is superseded by `endpoints.s3`. `backend.hcl.example` **already uses the
modern form** — `use_path_style` plus `endpoints = { s3 = …, dynamodb = … }`.

**Impact.** Beyond the regression, §6.10b cannot work as an all-CLI recipe: `endpoints` is a map,
which `-backend-config="key=value"` cannot express — which is why the repo keeps a `.hcl` file,
and what landing-zone §10.2 already documents.

**Fix.** Reduce §6.10b to the two per-stage overrides and parameterise the rest inside
`backend.hcl`:

```bash
terraform init \
  -backend-config=../../_common/backend.hcl \
  -backend-config="key=dev/10-management-iam/terraform.tfstate"
```

---

#### CH-LZ-007 — `use_lockfile` is offered as an alternative with no gate

- **Severity** medium · **Confidence** 90 · **Status** CITED (Terraform source)
- **Location** landing-zone §9:375-376; `infra/_common/backend.hcl.example:19`;
  gate set `scripts/preflight-floci.sh:65-81` (G3 tests DynamoDB only)

**Mechanism.** S3-native locking uses a conditional `PutObject`
(`internal/backend/remote-state/s3/client.go`):

```go
input := &s3.PutObjectInput{
	Bucket:      aws.String(c.bucketName),
	Key:         aws.String(c.lockFilePath),
	IfNoneMatch: aws.String("*"),
}
```

`IfNoneMatch: "*"` is a distinct capability from the DynamoDB conditional write G3 verifies.
Nothing establishes that Floci's S3 honours it, and an ignored header means two concurrent
applies both acquire the lock and corrupt state. `backend.hcl.example:19` offers the same
alternative with an "also verify" comment, but no gate exists.

**Fix.** Add G3b — `aws s3api put-object --if-none-match '*'` twice; the second must fail — or
state in §9 that the alternative is unverified and must not be used.

---

#### CH-LZ-008 — Stage 10's governance tag map is empty; the trio was deleted from the wrong file

- **Severity** high · **Confidence** 98 · **Status** VERIFIED · **NEW — no user decision recorded**
- **Location** `infra/live/10-management-iam/providers.tf:32-36`; template
  `infra/_common/providers.tf:45-51`; claimed at auth plan §6.10c:735-745; required by
  landing-zone §3.1:136-141, §5.3:232-234
- **Challenges** psc-adv-0002 M-SW-004 remediation

**Mechanism.** The stage's provider block now reads:

```hcl
  # Mandatory governance tags on every taggable resource.
  default_tags {
    tags = merge({
    }, var.default_tags)
  }
```

The `Project` / `Environment` / `ManagedBy` trio was removed from the **stage's provider**, not
only from `dev.tfvars`. The comment above it still claims the tags are mandatory. The template
(`_common/providers.tf:46-50`) still carries the trio, so template and stage have diverged —
which is the exact failure mode landing-zone §3.1 exists to prevent.

**Impact.** Stage 10 tags every resource with `Owner` only. No `Environment` tag exists at all,
so landing-zone §5.3's ABAC model has nothing to match on, and §3.1's "mandatory `default_tags`"
is false for the only stage that currently applies. Silent — no plan warning, no error.

Secondary drift in the same file: the `endpoints` block (`:39-51`) drops `sns` and `sqs` relative
to the template.

**Fix.** Restore the trio in the stage provider (or, better, make the stage a symlink to
`_common/providers.tf` as §3.1 permits), keep `dev.tfvars` carrying only `Owner`, and add a lint
check that every `infra/live/*/providers.tf` matches the template.

---

#### CH-LZ-009 — Provider version constraints have diverged; one is unbounded

- **Severity** medium · **Confidence** 95 · **Status** VERIFIED · **NEW — no user decision recorded**
- **Location** `infra/live/10-management-iam/providers.tf:5-8` (`>= 6.56.0`, no upper bound) vs
  `infra/_common/versions.tf:15-18` (`>= 5.95.0, < 7.0.0`) vs
  `infra/live/00-backend-bootstrap/main.tf:16-19` (`>= 5.95.0, < 7.0.0`);
  unresolved note at `versions.tf:13-14`; landing-zone §7:321-323

Three different constraints for one provider across three root modules, and the stage-10 one has
no upper bound — a future 7.x major would be selected automatically, contradicting §3.1's
"keep pins identical across stages". The `versions.tf:13-14` note ("v21 may require the AWS
provider >= 6.0. If `terraform init` reports a constraint conflict, tighten this") was evidently
resolved in the stage but never propagated back to the template.

**Fix.** Decide the floor once (`>= 6.56.0, < 7.0.0` if EKS v21 requires it), apply it in
`_common/versions.tf`, propagate to all stages, delete the note, and record the decision in
landing-zone §7.

---

#### CH-LZ-010 — Stage 10's backend key omits the environment prefix

- **Severity** medium · **Confidence** 95 · **Status** VERIFIED · **NEW — no user decision recorded**
- **Location** `infra/live/10-management-iam/providers.tf:11-15`; scheme at landing-zone §9:369-370
- **Challenges** psc-adv-0002 M-SW-003 remediation (bucket removed, key not addressed)

**Mechanism.** The in-file default is `key = "10-management-iam/terraform.tfstate"` — no `<env>/`
prefix. Landing-zone §9 specifies `<env>/<stage>/terraform.tfstate`.

**Impact.** An `init` without the `-backend-config="key=…"` override silently writes state to an
unprefixed key. Promotion to uat/prod then collides on the same object — the failure the
per-environment key scheme exists to prevent, and it presents as one environment's apply
destroying another's resources.

**Fix.** Either omit `key` entirely (forcing the override, consistent with how `bucket` and
`region` are handled) or default it to `dev/10-management-iam/terraform.tfstate`. Omitting is
safer: a missing required value fails loudly, a wrong default fails silently.

---

#### CH-LZ-011 — `default_tags` merge order lets a tfvars file override governance tags

- **Severity** medium · **Confidence** 95 · **Status** VERIFIED
- **Location** `infra/_common/providers.tf:46-50`
- **Challenges** psc-adv-0002 M-SW-004 mechanism

`merge({Project, Environment = var.environment, ManagedBy}, var.default_tags)` puts
`var.default_tags` **second**, so it wins. That is how `Environment = "development"` overrode
`var.environment = "dev"` in the first place — silently, with no plan warning. Removing the
duplicates from `dev.tfvars` fixes today's symptom but leaves the hazard armed.

**Fix.** Reverse the order so governance tags cannot be overridden, and constrain the
environment value:

```hcl
# var.default_tags FIRST so the governance trio always wins — a tfvars file must not be
# able to retag Environment and silently break the ABAC conditions in §5.3.
default_tags {
  tags = merge(var.default_tags, {
    Project     = "tianlu"
    Environment = var.environment
    ManagedBy   = "terraform"
  })
}

variable "environment" {
  type = string
  validation {
    condition     = contains(["dev", "uat", "prod"], var.environment)
    error_message = "environment must be one of dev, uat, prod (see landing-zone-design.md §4.1)."
  }
}
```

---

#### CH-LZ-012 — `dev.tfvars` comment encodes the wrong mechanism

- **Severity** low · **Confidence** 95 · **Status** VERIFIED
- **Location** `infra/environments/dev.tfvars:26-29`; same error at auth plan §6.10c:731

The comment states duplication *"causes terraform plan warnings (duplicate key)"*. It does not —
`merge` silently lets the later map win (CH-LZ-011). The wrong mechanism is now committed as a
code comment, where it will teach the next maintainer that the failure is loud when it is silent.

**Fix.** Correct both the comment and auth plan §6.10c to state the real mechanism: `merge`
precedence, silent override, no diagnostic.

---

#### CH-LZ-013 — Three residual documentation gaps

- **Severity** low · **Confidence** 90 · **Status** VERIFIED

1. **`secret_key` is required but no documented command supplies it.**
   `infra/_common/providers.tf:12-15` declares it `sensitive`, no default. `dev.tfvars` does not
   set it and landing-zone §10.2:405-418's commands do not pass it, so Terraform prompts
   interactively and any non-TTY run hangs. This is also the seam where rotation lands, so it
   needs an explicit story: `TF_VAR_secret_key` sourced from `DEV_CREDENTIALS_FILE`, documented
   in §10.1 next to the preflight step.
2. **Present-tense scaffolding.** §3:104-127 lists `modules/workload-spoke/` and stages 20–60;
   only `00` and `10` exist. Same class as psc-adv-0002 M-DX-002, applied to the landing-zone
   document rather than the auth plan.
3. **Presign secret as an IAM bypass.** §12:441-451 lists IAM as the primary boundary without
   noting that `FLOCI_AUTH_PRESIGN_SECRET` mints presigned S3 URLs that skip it — material
   because the Terraform state bucket is S3 (§9). Cross-link to CH-AUTH-014.

Plus, outside the reviewed set: **`install.sh` in the repo root** is an "OpenAgents Control
Installer" for opencode — 52 KB, untracked, unrelated to this project, sitting beside
`setup-floci.sh`. Remove it or move it out of the tree.

---

### F. Corrections to prior advisories — lessons-learned inputs

---

#### CH-META-001 — psc-adv-0001 M-SW-001 states the wrong mechanism for the region mismatch

- **Confidence** 92 · **Status** CITED

**The claim.** *"AWS SigV4 signs the region into the signature — this mismatch breaks the entire
rotation flow in sigv4 mode. Runtime-correctness blocker."*

**Why it is wrong.** The region is part of the request's own credential scope
(`Credential=AKID/date/region/service/aws4_request`) and the server derives it from the
`Authorization` header — `docs/scraped/environment-variables.md` describes
`FLOCI_DEFAULT_REGION` as the region *"used when not derivable from the `Authorization` header"*,
and `multi-account.md:173` repeats it. Two clients signing for different regions each verify
correctly and independently. A client/config region mismatch does not break signature validation.

**What the real consequence is.** Resource and ARN divergence: resources created against
`eu-west-1` are not returned to a client querying `eu-west-2`, and ARNs embed the wrong region.
Still worth fixing; `DEV_REGION` is the right instrument.

**Lesson.** The action was correct and the severity roughly right, but the causal claim was not
checked against the primary source before being recorded as a blocker. A finding whose mechanism
is wrong cannot be verified by a test derived from it — and the fix stopped at the auth plan's
own literals, leaving five other region sites untouched (CH-LZ-005) precisely because the stated
mechanism pointed at signing rather than at configuration coherence.

---

#### CH-META-002 — psc-adv-0001 M-SW-002's recommendation was unsafe, and applying it made the guardrail worse

- **Confidence** 92 · **Status** CITED

**The recommendation.** *"Rewrite `DenyAllExceptBoundary` statement resources to `["*"]` **or**
use `StringNotEquals` condition on `iam:PermissionsBoundary`."*

**What happened.** Both were applied. AWS documents that inverted condition operators **match** a
null value, and `iam:PermissionsBoundary` is absent from the request context for every action in
the statement — so the Deny now fires unconditionally on all resources (CH-LZ-001). The original
resource-scoped form was closer to correct: it had the same null-key match but was confined to
the boundary policy, which is the intended protection.

**Lesson.** Three compounding factors: (a) the recommendation offered two alternatives joined by
"or" without stating that combining them changes the semantics; (b) neither alternative was
checked against IAM's absent-key evaluation rules, which are the crux; (c) no test accompanied
the fix, and on Floci a permissions-boundary test may not even be possible (CH-LZ-002) — so the
change was unfalsifiable by construction. IAM condition logic on actions that may not carry the
key is a recurring trap; AWS ships a policy check for it
(`EQUIVALENT_TO_NULL_FALSE`). Candidate standing rule: any IAM `Condition` on a
service-specific key must state which actions populate that key, and any Deny intended as a
ceiling needs a negative test before it counts as landed.

---

#### CH-META-003 — psc-adv-0001 F-SW-001's premise misread the variable's purpose

- **Confidence** 92 · **Status** CITED

**The claim.** *"`FLOCI_SERVICES_IAM_ENABLED` … is required for Floci to enforce IAM signatures."*

**Why it is wrong.** `docs/scraped/environment-variables.md:160` documents it as the IAM service
on/off switch, default `true`. Enforcement is `FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED`
(`:161`), which the plan already set. Adding `IAM_ENABLED` to the mode switch — and setting it
`false` in `off` mode — disables IAM entirely (CH-AUTH-003).

**Lesson.** Two adjacent variables in the same doc section were conflated, and the remediation
propagated the conflation into the mode matrix, a summary note (§6.2:339-342), and a test
specification (SPEC-TX-006 case 3) before anyone re-read line 160. Candidate standing rule: a
finding that adds a new environment variable to a configuration surface must quote the source
line documenting that variable's default and effect.

---

## Recommended Action

Ordered by dependency. Items 1–2 gate everything else.

1. **CH-AUTH-001** — implement the user-selected option 1: per-environment
   `FLOCI_DEFAULT_ACCOUNT_ID`; `access_key` becomes the rotated deployer AKID; add a
   caller-identity precondition asserting `var.account_id`; update landing-zone §4.1/§4.2 and the
   gaps register. Run the three-outcome probe in CH-AUTH-001 first — outcome (b) would require
   rewriting auth plan §8 and landing-zone §1.1.
2. **CH-LZ-001** — replace `DenyAllExceptBoundary` with the three-statement form; drop the
   non-existent group action; add **CH-LZ-002**'s G6 negative test so the ceiling is falsifiable.
3. **CH-AUTH-002, CH-AUTH-003** — rewrite §4.2/§6.1: derive posture from the mode with one named
   escape hatch; pin `FLOCI_SERVICES_IAM_ENABLED=true` in both branches; correct §6.2's note and
   the SPEC-TX-006 case-3 direction.
4. **CH-AUTH-004** — replace the `sed` range delete with the awk section-aware rewrite plus
   atomic write; add the seven bats cases listed under the finding.
5. **CH-AUTH-005, CH-AUTH-007** — `|| delete_rc=$?` for the delete; atomic `.tmp`+`chmod`+`mv`
   for the credential file; parse instead of `source`.
6. **CH-AUTH-006, CH-AUTH-011** — introduce `DEV_AUTH_MODE` in the constants block, pass it to
   the installer, gate rotation on it, and call `_print_next_steps` from `dev_recreate`.
7. **CH-AUTH-008, CH-AUTH-009** — array-based `-e` overrides in the guest driver; retain the
   `${arr[@]+…}` guard in `launch_driver`; decide the bash-3.2 support question explicitly.
8. **CH-AUTH-010** — re-derive the `wait_driver` hang before specifying SPEC-TX-013; if a bounded
   wait is adopted, add a distinct killed-after-timeout verdict.
9. **CH-LZ-004, CH-LZ-003** — G1 must fail rather than skip when it cannot establish the probe;
   relabel G1 to name both enforcement variables; add them to §1.1 and §10.1.
10. **CH-LZ-006, CH-LZ-005** — reduce §6.10b to `-backend-config=../../_common/backend.hcl` plus
    the per-stage `key`; align backend region with tfvars region; unify the five region literals.
11. **CH-LZ-007** — add G3b for S3 conditional `PutObject`, or mark `use_lockfile` unverified in
    §9 and `backend.hcl.example`.
12. **CH-LZ-008, CH-LZ-009, CH-LZ-010, CH-LZ-011, CH-LZ-012** — restore stage-10 governance tags
    (or symlink the template); unify provider constraints with an upper bound; remove or prefix
    the backend key; reverse the `default_tags` merge order and add `environment` validation;
    correct the mechanism in the tfvars comment and §6.10c. Add a lint check that every
    `infra/live/*/providers.tf` matches `_common/providers.tf`.
13. **CH-INST-001 … 005** — retry `5xx` in `verify_health` and report the last code; per-binary
    AppArmor sentinel plus profile hashing in the twin; document or drop the four extra firewall
    ranges; assert `curl`/`openssl` in Phase 1; refresh `AGENTS.md:57` and `:64`.
14. **CH-DEV-001 … 006** — `_print_next_steps` from `dev_recreate`; `dev_env` on resume paths;
    distinct return code from `dev_disk_exists`; `DEV_DISK_MOUNT` derived from `DEV_DISK_NAME`;
    unify the health budget and fallback; drop the redundant `main` guard.
15. **CH-TWIN-001 … 007** — verdict on precondition failure; `sidecar-delta` in `mandatory`;
    replace or drop the journal ordering check; document the evidence-dir split; resolve
    `--fresh`/`--keep`; fix the two robustness gaps.
16. **CH-AUTH-012 … 016, CH-LZ-013** — split §6.10a–d into a changelog; emit `FLOCI_AUTH_MODE`;
    add the presign-secret threat model and rotation path; correct §9.3's closure claims; add the
    `TF_VAR_secret_key` story to §10.1; qualify §3's unbuilt scaffolding; remove `install.sh`.
17. **CH-META-001 … 003** — record the three corrections against their originating findings and
    convert the candidate standing rules into lessons-learned entries.

## User Decision

Recorded verbatim from the review session (2026-07-30). Numbering below is the session's
section numbering; the mapping table follows.

```
1.1 option 1
1.2 correct
1.3 OK
1.4 TRUE, Should have bats to validate it works
1.5 ok
1.6 ok
1.7 ok
1.8 ok
1.9 ok
1.10 ok
1.11 ok
all other are okay
```

| Session § | Finding | Decision |
|---|---|---|
| 1.1 | CH-AUTH-001 | **Option 1** — per-environment `FLOCI_DEFAULT_ACCOUNT_ID`; account axis moves from AKID to installer config |
| 1.2 | CH-AUTH-002 | Accepted ("correct") |
| 1.3 | CH-AUTH-003 | Accepted |
| 1.4 | CH-AUTH-004 | Accepted; **bats coverage required to prove the replacement works** (seven cases specified under the finding) |
| 1.5 | CH-AUTH-005 | Accepted |
| 1.6 | CH-AUTH-006 | Accepted |
| 1.7 | CH-AUTH-007 | Accepted |
| 1.8 | CH-AUTH-008 | Accepted |
| 1.9 | CH-AUTH-009 | Accepted |
| 1.10 | CH-AUTH-010 | Accepted |
| 1.11 | CH-AUTH-011 … 016 | Accepted (all six sub-items) |
| 2 | CH-INST-001…005, CH-DEV-001…006, CH-TWIN-001…007 | Accepted ("all other are okay") |
| 3 | CH-LZ-001…007, CH-LZ-011, CH-LZ-012, CH-LZ-013 | Accepted ("all other are okay") |
| — | CH-META-001, 002, 003 | Accepted; user intent is to generate lessons learned from these |
| — | **CH-LZ-008, CH-LZ-009, CH-LZ-010** | **NOT YET DECIDED** — discovered while preparing this advisory, after the review session. Not covered by "all other are okay". |

## Decision Rationale

CH-AUTH-001 option 1 preserves the environment-as-account contract in a form that survives
signature validation, at the cost of one Floci instance per environment. Options 2 (scope sigv4
to a single account) and 3 (probe only) were declined: option 2 abandons the promotion story
under auth, and option 3 defers rather than resolves. The probe is retained as a validation step
because outcome (b) — a 12-digit AKID accepted with an unchecked secret — would mean the
estate's headline security claim is unenforced regardless of which option is built.

CH-AUTH-004's bats requirement reflects that the defect is silent data loss in a file outside the
project's ownership; the fix is only credible with a test that proves neighbouring profiles
survive.

## Lessons-learned inputs

For the lessons-learned pass, in priority order.

| # | Missed point | Class | Candidate standing rule |
|---|---|---|---|
| 1 | CH-AUTH-001 — the AKID/SigV4 incompatibility was never examined across three review rounds, despite `multi-account.md:60` stating the qualifier plainly | Missing analysis of a documented precondition | When a design turns on a documented default, re-read the source line for qualifiers ("by default", "unless") and test the non-default path explicitly |
| 2 | CH-META-002 — an "A or B" recommendation was applied as "A and B" and inverted the guardrail | Ambiguous remediation wording | Recommendations must be single-valued, or state what happens if the alternatives are combined |
| 3 | CH-META-002 — IAM absent-key semantics were not consulted | Unverified security-control semantics | Any IAM `Condition` on a service-specific key must state which actions populate that key; any Deny intended as a ceiling needs a negative test before it counts as landed |
| 4 | CH-META-003 — two adjacent env vars conflated, then propagated into the matrix, a note, and a test spec | Source misread, then amplified | A finding that adds an env var must quote the source line documenting its default and effect |
| 5 | CH-META-001 — a causal mechanism was asserted without checking, and the resulting fix stopped short | Wrong mechanism, right action | Separate "what is wrong" from "why it is wrong"; the fix scope follows the mechanism, so a wrong mechanism yields an incomplete fix |
| 6 | CH-LZ-008 — a fix aimed at `dev.tfvars` was applied to the stage provider, deleting the canonical tags | Remediation applied to the wrong file | Remediations must name the exact file and lines; verify the post-fix state, not just the diff |
| 7 | CH-AUTH-002, CH-AUTH-005, CH-AUTH-009 — three remediations introduced new defects, and §9.3 recorded them as fixed | Fixes not validated | Do not mark a finding fixed without an executed check; distinguish *specified* from *verified* in the findings ledger |
| 8 | CH-AUTH-009 — a plan asserted a bash behaviour ("guard no longer needed") that fails on the interpreter actually in use | Untested platform assumption | Behavioural claims about the shell must be executed on the target interpreter and the output pasted into the finding |
| 9 | CH-LZ-002, CH-LZ-004, CH-LZ-007 — three security claims have no gate, and the one gate that exists passes when it cannot run | Unfalsifiable controls | Every "Enforced" row in a fidelity table needs a named gate; a gate that cannot establish its precondition must fail, not skip |
| 10 | CH-LZ-009, CH-LZ-010 — stage code drifted from `_common/` templates with no detection | Unenforced convention | If a convention says "keep these identical", add a check that fails when they are not |

## Verification

Commands executed for this advisory. Re-runnable.

```sh
# CH-AUTH-002 — the forbidden posture is reachable
FLOCI_AUTH_MODE=off FLOCI_AUTH_VALIDATE_SIGNATURES=true bash -c '
_v=""; _e=""
case "$FLOCI_AUTH_MODE" in
  off) _v=false; _e=false ;; sigv4) _v=true; _e=true ;;
esac
readonly FLOCI_AUTH_VALIDATE_SIGNATURES="${FLOCI_AUTH_VALIDATE_SIGNATURES:-$_v}"
readonly FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED="${FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED:-$_e}"
printf "signatures=%s enforcement=%s\n" "$FLOCI_AUTH_VALIDATE_SIGNATURES" \
  "$FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED"'
# → signatures=true enforcement=false

# CH-AUTH-004 — the following profile is destroyed
T=$(mktemp); printf '[tianlu-floci-dev]\nk = old\n\n[default]\nk = REAL\n' > "$T"
sed -i.bak '/^\[tianlu-floci-dev\]/,/^\[/d' "$T" && rm -f "$T.bak"; cat "$T"
# → "k = REAL" with no [default] header

# CH-AUTH-008 — flags collapse to one argument under IFS=$'\n\t'
/bin/bash -c 'IFS=$'"'"'\n\t'"'"'; V="-e A=1 -e B=2"; set -- $V; echo $#'
# → 1

# CH-AUTH-009 — empty-array expansion still fails on bash 3.2
/bin/bash --version | head -1
/bin/bash -c 'set -u; a=(); printf "%q " "${a[@]}"'
# → GNU bash, version 3.2.57 … / a[@]: unbound variable
/bin/bash -c 'set -u; a=(); echo "len=${#a[@]}"'
# → len=0   (length expansion is safe; ${a[@]} is not)
```

Primary sources cited:

- IAM absent-key evaluation —
  <https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_variables.html>
  ("Policy variables with no value")
- IAM policy check `EQUIVALENT_TO_NULL_FALSE` —
  <https://docs.aws.amazon.com/IAM/latest/UserGuide/access-analyzer-reference-policy-checks.html>
- Permissions boundaries apply to users and roles only —
  <https://docs.aws.amazon.com/IAM/latest/APIReference/API_PutUserPermissionsBoundary.html>
- Terraform S3 backend `force_path_style` deprecation and `use_lockfile` conditional PutObject —
  `internal/backend/remote-state/s3/{backend,client}.go`, hashicorp/terraform `main`
- Floci account resolution, signature validation, IAM service variables —
  `docs/scraped/multi-account.md:9-10,35,60,153,173`;
  `docs/scraped/environment-variables.md:10,21-22,160-162`;
  `docs/scraped/docker-images.md:78-79,86`

## Implementation Ticket

(pending — to be spawned after team review)
