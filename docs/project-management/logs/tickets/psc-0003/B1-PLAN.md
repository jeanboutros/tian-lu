# B1: PLAN — psc-0003

| Field | Value |
|-------|-------|
| Agent | code-architect |
| Timestamp | 2026-07-30T23:30:00Z |
| Step | B1 |
| Phase | B — Build |
| Ticket | psc-0003 |
| Source | psc-adv-0017-challenge-review (49 accepted findings) |
| Specialist inputs | A1-SW (14 SPECs), A1-TX (14 SPECs), A1-DX (13 SPECs), A1-SX (12 SPECs), A1-BS (19 SPECs), A1-DO (17 SPECs) |
| A2 synthesis | A2-dual-model-challenge.md (23 disagreements, 34 one-sided, 53 recommendations) |
| A2c decisions | 18 challenger wins, 4 primary wins, 1 backlog; 28 advisories accepted, 6 backlog; 63 clarifications backlog |

## Phase B Entry Gate: Three-Outcome Probe (CH-AUTH-001)

**MUST RUN BEFORE ANY IMPLEMENTATION.** Per D-2 (challenger win, confidence 85) and D-13 (challenger win, severity 10), the three-outcome probe is a keystone verification whose result determines whether multiple SPECs are meaningful. Outcome (b) means the estate's headline security claim is false and auth plan §8.3 + landing-zone §1.1 must be rewritten.

```sh
# Run against a sigv4 Floci instance:
AWS_ACCESS_KEY_ID=111111111111 AWS_SECRET_ACCESS_KEY=wrong-on-purpose \
  aws --endpoint-url http://localhost:4566 --region eu-west-2 sts get-caller-identity
```

| Outcome | Meaning | Action |
|---------|---------|--------|
| (a) Rejected | SigV4 validates the secret; 12-digit AKID with wrong secret is denied | Proceed with Unit 1 as designed |
| (b) Accepted, namespaced to 111111111111 | Secret is unchecked for 12-digit AKIDs; security claim is false | Rewrite auth plan §8.3 + landing-zone §1.1 before proceeding |
| (c) Accepted, mapped to FLOCI_DEFAULT_ACCOUNT_ID | Silent account relocation | Proceed with Unit 1; record relocation risk in gaps register |

**Record the result in `docs/design/gaps-register.md` as GAP-016 before any code is written.**

**Gate owner:** DO/BS (execution), SX (interpretation). The probe runs against the dev twin (`make dev-up` with `FLOCI_AUTH_MODE=sigv4`).

---

## Unit Breakdown

### Unit 1: Auth Configuration Surface
**Files:**
- `setup-floci.sh` — config block (FLOCI_AUTH_MODE, FLOCI_AUTH_UNSAFE_OVERRIDE, FLOCI_SERVICES_IAM_ENABLED, FLOCI_DEFAULT_ACCOUNT_ID, FLOCI_AUTH_MODE env emission)
- `docs/design/authentication-plan.md` — §4.2, §6.1, §6.2 code blocks and notes

**Findings covered:**
- CH-AUTH-001 — Per-environment `FLOCI_DEFAULT_ACCOUNT_ID`; account axis moves from AKID to installer config; caller-identity precondition
- CH-AUTH-002 — Rewrite §4.2 with `FLOCI_AUTH_UNSAFE_OVERRIDE` escape hatch; unset `_auth_*` helpers
- CH-AUTH-003 — `FLOCI_SERVICES_IAM_ENABLED=true` in both branches; correct §6.2 note
- CH-AUTH-013 — Emit `FLOCI_AUTH_MODE` to env file; surface in `dev_status`

**Acceptance criteria:**
1. `FLOCI_DEFAULT_ACCOUNT_ID` is configurable per environment (default `000000000000`, dev twin sets `111111111111`)
2. `FLOCI_AUTH_MODE` is a single enum (`off`/`sigv4`) that unconditionally derives `FLOCI_AUTH_VALIDATE_SIGNATURES` and `FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED`
3. `FLOCI_AUTH_UNSAFE_OVERRIDE=1` is the only way to set sub-variables independently (default `0`)
4. `FLOCI_AUTH_MODE=off` + `FLOCI_AUTH_VALIDATE_SIGNATURES=true` yields `false` in the env file
5. `FLOCI_SERVICES_IAM_ENABLED=true` (or absent, defaulting to `true`) in both `off` and `sigv4` modes
6. `FLOCI_AUTH_MODE` is written to `floci.env` during `write_env_file`
7. `_auth_on` (and all `_auth_*` helpers) are `unset` after use
8. `data.aws_caller_identity` precondition in `_common/providers.tf` asserts `var.account_id` matches resolved account
9. `access_key` in `_common/providers.tf` uses deployer's real AKID (from `DEV_CREDENTIALS_FILE`), not `var.account_id`
10. `preflight-floci.sh` G1 uses deployer credentials; `DEV_AKID` becomes the expected account id

**Dependencies:**
- **Blocks on:** Phase B entry gate (three-outcome probe result recorded)
- **Blocks:** Units 3, 7, 9, 10 (all depend on auth config)

**Build verification:**
```sh
make lint                                    # shellcheck + bash -n on setup-floci.sh
terraform -chdir=infra/_common fmt -check    # verify providers.tf changes
```

**Specialist SPECs implemented:** SPEC-SW-001, SPEC-SW-002, SPEC-SW-003, SPEC-SW-005, SPEC-BS-001, SPEC-SX-001, SPEC-SX-002, SPEC-SX-003

---

### Unit 2: Credential Block Replacement (awk rewrite + atomic write)
**Files:**
- `mock-server/dev-twin.sh` — `dev_env()` function: replace `sed` range delete with `awk` section-aware rewrite + atomic `.tmp+chmod+mv`
- `mock-server/tests/dev_twin.bats` — 7 new test cases (SPEC-TX-101-1 through 101-7)

**Findings covered:**
- CH-AUTH-004 — Replace `sed` range delete with `awk` section-aware rewrite + atomic write; 7 bats cases

**Acceptance criteria:**
1. `[tianlu-floci-dev]` followed by `[default]` → `[default]` header and both keys survive verbatim; managed block replaced, not duplicated
2. `[tianlu-floci-dev]` as the last section → replaced cleanly, no residue
3. `[tianlu-floci-dev]` absent → block appended, all pre-existing profiles byte-identical
4. Two pre-existing unrelated profiles surrounding the managed block → both intact
5. File absent → created with mode 0600, single block, `dev_env` exits 0
6. Idempotency: two consecutive `dev_env` runs produce byte-identical output
7. Resulting file mode is 0600 and the first non-blank line is a section header

**Dependencies:**
- **Blocks on:** Nothing (independent of auth config)
- **Blocks:** Unit 7 (dev_env changes affect dev twin resume paths)

**Build verification:**
```sh
shellcheck mock-server/dev-twin.sh
bats mock-server/tests/dev_twin.bats --filter 'SPEC-TX-101'
```

**Specialist SPECs implemented:** SPEC-BS-013 (awk rewrite), SPEC-TX-101 (7 bats cases), SPEC-SX-004

---

### Unit 3: Credential Rotation Fixes
**Files:**
- `mock-server/dev-twin.sh` — `_rotate_bootstrap_credentials()`: `|| delete_rc=$?`, atomic `.tmp+chmod+mv`, parse instead of `source`, `DEV_AUTH_MODE` constant, gate rotation on mode, `_print_next_steps` from `dev_recreate`
- `mock-server/tests/dev_twin.bats` — SPEC-TX-100-1, SPEC-TX-102-1/2, SPEC-TX-104-1/2

**Findings covered:**
- CH-AUTH-005 — `|| delete_rc=$?` for delete under `set -e`
- CH-AUTH-006 — Introduce `DEV_AUTH_MODE`; call `_print_next_steps` from `dev_recreate`; bats case
- CH-AUTH-007 — Atomic `.tmp+chmod+mv` for credential file; parse instead of `source`
- CH-AUTH-011 — `DEV_AUTH_MODE` constant; gate rotation on mode; pass to installer

**Acceptance criteria:**
1. `delete_rc=0; _run_as_floci_guest "… delete-access-key …" || delete_rc=$?` — handler is reachable under `set -e`
2. Credential file written atomically: `.tmp` → `chmod 0600` → `mv -f`
3. Credential file parsed with `while IFS='=' read -r k v` instead of `source` (removes SC1090 suppressions)
4. `readonly DEV_AUTH_MODE="${DEV_AUTH_MODE:-sigv4}"` in constants block
5. `_rotate_bootstrap_credentials` early-returns when `DEV_AUTH_MODE=off`
6. `FLOCI_AUTH_MODE="$DEV_AUTH_MODE"` passed to installer (not hardcoded `sigv4`)
7. `_print_next_steps` called at end of `dev_recreate`
8. Bats: `FLOCI_AUTH_MODE=off` + `FLOCI_AUTH_VALIDATE_SIGNATURES=true` → env file has `false`
9. Bats: sigv4 security section appears for both `dev_up`-fresh and `dev_recreate`
10. Bats: rotation is no-op in `off` mode; stale credential file not consumed in `off` mode

**Dependencies:**
- **Blocks on:** Unit 1 (needs `DEV_AUTH_MODE` from CH-AUTH-011, which depends on auth config)
- **Blocks:** Unit 7 (dev twin resume paths use `dev_env` and `_print_next_steps`)

**Build verification:**
```sh
shellcheck mock-server/dev-twin.sh
bats mock-server/tests/dev_twin.bats --filter 'SPEC-TX-100|SPEC-TX-102|SPEC-TX-104'
```

**Specialist SPECs implemented:** SPEC-BS-002, SPEC-BS-003, SPEC-BS-006, SPEC-BS-007 (partial — `_print_next_steps`), SPEC-BS-010, SPEC-TX-100, SPEC-TX-102, SPEC-TX-104, SPEC-SX-005, SPEC-SX-006

---

### Unit 4: Guest Driver Array Fixes
**Files:**
- `mock-server/in-vm/run-in-vm.sh` — array-based `-e` overrides for `aws_creds_env`
- `mock-server/run-test.sh` — `launch_driver`: retain `${arr[@]+…}` guard; `printf '%q '` with `[@]`

**Findings covered:**
- CH-AUTH-008 — Array-based `-e` overrides in guest driver (not unquoted string)
- CH-AUTH-009 — Retain `${arr[@]+…}` guard in `launch_driver`; decide bash-3.2 support explicitly

**Acceptance criteria:**
1. `aws_creds_env=(-e AWS_ACCESS_KEY_ID=floci -e AWS_SECRET_ACCESS_KEY=floci)` — array, not string
2. Lambda step: `-e` flags inserted before `bash`, not inside the heredoc script
3. `${driver_args[@]+"${driver_args[@]}"}` guard retained in `launch_driver`
4. `[*]` → `[@]` for multi-element array correctness under `IFS=$'\n\t'`
5. Bash-3.2 support decision documented: keep the guard (no bash-4+ precondition per D-18 challenger win)

**Dependencies:**
- **Blocks on:** Nothing (independent)
- **Blocks:** Nothing (no downstream dependencies)

**Build verification:**
```sh
shellcheck mock-server/in-vm/run-in-vm.sh
shellcheck mock-server/run-test.sh
```

**Specialist SPECs implemented:** SPEC-BS-004, SPEC-BS-005, SPEC-TX-008 (implicit — array correctness)

---

### Unit 5: wait_driver Fix
**Files:**
- `mock-server/run-test.sh` — `wait_driver`: re-derive hang; distinguish killed-after-timeout from driver failure
- `mock-server/tests/completion_protocol.bats` — SPEC-TX-103-1/2/3/4

**Findings covered:**
- CH-AUTH-010 — Re-derive `wait_driver` hang before specifying SPEC-TX-013; distinct killed-after-timeout verdict

**Acceptance criteria:**
1. `wait_driver` returns 0 for successful driver (exit 0)
2. `wait_driver` records `driver exited nonzero` for failed driver (exit 1)
3. `wait_driver` produces distinct `killed after timeout` verdict for exit 143 (not `driver exited nonzero`)
4. `wait_driver` with empty `DRIVER_SHELL_PID` produces distinct verdict (not `driver exited nonzero (127)`)

**Dependencies:**
- **Blocks on:** Nothing (independent)
- **Blocks:** Unit 8 (CH-TWIN-007 empty PID fix is shared with SPEC-TX-103-4)

**Build verification:**
```sh
shellcheck mock-server/run-test.sh
bats mock-server/tests/completion_protocol.bats --filter 'SPEC-TX-103'
```

**Specialist SPECs implemented:** SPEC-BS-019, SPEC-TX-103, SPEC-TX-111-2 (shared)

---

### Unit 6: Installer Fixes
**Files:**
- `setup-floci.sh` — `verify_health` (retry 5xx), `assert_userns_allowed` (per-binary sentinel), firewall ranges (document or drop), Phase 1 (assert curl/openssl)
- `mock-server/in-vm/run-in-vm.sh` — idempotency hash set (extend to include AppArmor profile)
- `AGENTS.md` — refresh lines 60 and 67

**Findings covered:**
- CH-INST-001 — Retry 5xx in `verify_health`; report last code in timeout message
- CH-INST-002 — Per-binary AppArmor sentinel; extend twin hash set to include profile
- CH-INST-003 — Document or drop the four extra firewall ranges
- CH-INST-004 — Assert `curl` and `openssl` in Phase 1
- CH-INST-005 — Refresh `AGENTS.md:60` and `:67` (corrected line numbers per D-10)

**Acceptance criteria:**
1. `verify_health` retries on `000` and `5xx`; fails fast on `4xx`; timeout message includes last observed code
2. Per-binary AppArmor sentinel: each binary's profile checked independently via `_profile_loaded()`
3. Twin hash set includes AppArmor profile files (guards non-idempotent rewrite regression)
4. Four extra firewall ranges either documented with rationale or removed from UFW rules
5. `curl` and `openssl` asserted in Phase 1 (fail fast before mutating work)
6. `AGENTS.md:60` references `run_as_floci systemctl --user` (not `-M floci@.host`)
7. `AGENTS.md:67` references `dev-twin.sh` line 484 (not 322)

**Dependencies:**
- **Blocks on:** Nothing (independent)
- **Blocks:** Nothing (no downstream dependencies)

**Build verification:**
```sh
make lint                                    # shellcheck + bash -n on setup-floci.sh
shellcheck mock-server/in-vm/run-in-vm.sh
```

**Specialist SPECs implemented:** SPEC-BS-007 (verify_health), SPEC-BS-008, SPEC-BS-009, SPEC-DO-001, SPEC-DO-002, SPEC-DO-003, SPEC-DO-004, SPEC-DX-006, SPEC-DX-007

---

### Unit 7: Dev Twin Fixes
**Files:**
- `mock-server/dev-twin.sh` — `dev_recreate` (_print_next_steps), `dev_up` (dev_env on resume paths), `dev_disk_exists` (distinct return codes), `DEV_DISK_MOUNT` (derived from `DEV_DISK_NAME`), health budget unification, drop redundant `main` guard

**Findings covered:**
- CH-DEV-001 — `_print_next_steps` from `dev_recreate`
- CH-DEV-002 — `dev_env` on resume paths (Running and Stopped branches)
- CH-DEV-003 — Distinct return codes from `dev_disk_exists` (0=present, 1=absent, 2=query failed)
- CH-DEV-004 — `DEV_DISK_MOUNT` derived from `DEV_DISK_NAME`
- CH-DEV-005 — Unify health budget and fallback (use `_resume_health_check` for both)
- CH-DEV-006 — Drop redundant `main` guard

**Acceptance criteria:**
1. `make dev-recreate` prints next-steps block including credential location and rotation instructions
2. After `make dev-down && make dev-up`, `~/.aws/credentials` reflects current rotated credentials
3. `dev_disk_exists` returns 0 (present), 1 (absent), 2 (query failed); all callers branch on all three
4. `readonly DEV_DISK_MOUNT="${DEV_DISK_MOUNT:-/mnt/lima-${DEV_DISK_NAME}}"` used at all four hardcoded sites
5. Fresh install uses same 300s health budget and `_reset_floci_service` fallback as resume
6. Inner `[[ "${BASH_SOURCE[0]}" == "${0}" ]]` guard removed from `main` (bottom guard suffices)

**Dependencies:**
- **Blocks on:** Unit 2 (dev_env awk rewrite), Unit 3 (DEV_AUTH_MODE, _print_next_steps)
- **Blocks:** Nothing (leaf unit)

**Build verification:**
```sh
shellcheck mock-server/dev-twin.sh
```

**Specialist SPECs implemented:** SPEC-BS-010, SPEC-BS-011, SPEC-BS-012, SPEC-BS-014, SPEC-BS-015, SPEC-BS-016, SPEC-DO-005

---

### Unit 8: Test Harness Fixes
**Files:**
- `mock-server/run-test.sh` — `assert_preconditions` (route through FAIL_REASON), `mandatory` array (add sidecar-delta), journal ordering check (replace or drop), stale-sentinel cleanup, `--fresh`/`--keep` semantics, `HOST_HOME` fallback, `DRIVER_SHELL_PID` empty guard
- `mock-server/tests/orchestrator_args.bats` — SPEC-TX-105-1/2, SPEC-TX-110-1/2/3, SPEC-TX-111-1
- `mock-server/tests/completion_protocol.bats` — SPEC-TX-106-1/2, SPEC-TX-107-1, SPEC-TX-108-1
- `docs/design/digital-twin-testing-design.md` — evidence-dir split documentation

**Findings covered:**
- CH-TWIN-001 — Verdict on precondition failure (route through `FAIL_REASON` + `print_verdict`)
- CH-TWIN-002 — `sidecar-delta` in mandatory array
- CH-TWIN-003 — Replace or drop journal ordering check
- CH-TWIN-004 — Fix stale-sentinel cleanup path
- CH-TWIN-005 — Document evidence-dir split in usage and design doc
- CH-TWIN-006 — Resolve `--fresh`/`--keep` semantics (per D-22: `--fresh` implies `--destroy`; mutually exclusive)
- CH-TWIN-007 — Fix `wait "${DRIVER_SHELL_PID:-}"` and `HOST_HOME` fallback

**Acceptance criteria:**
1. Precondition failures produce `TWIN: FAIL: <reason>` on stderr (machine-readable contract)
2. `sidecar-delta` added to `mandatory` array; `NO_SIDECAR=true` allows SKIPPED
3. Journal line-number comparison removed; property assertions (`After=`/`Requires=`) are the real evidence
4. Stale-sentinel cleanup targets `$STAGING` (or redundant lines removed since `rm -rf "$STAGING"` handles it)
5. `usage` and design doc explain: `--evidence-dir` relocates final copy only; 9p staging is fixed
6. `--fresh` implies `--destroy`; `--keep` is default; mutually exclusive (last wins or error)
7. `HOST_HOME` fallback fails with clear error (not username-derived path)
8. `wait_driver` handles empty `DRIVER_SHELL_PID` with distinct verdict (shared with Unit 5)

**Dependencies:**
- **Blocks on:** Unit 5 (wait_driver changes for CH-TWIN-007 empty PID)
- **Blocks:** Nothing (leaf unit)

**Build verification:**
```sh
shellcheck mock-server/run-test.sh
bats mock-server/tests/orchestrator_args.bats
bats mock-server/tests/completion_protocol.bats
```

**Specialist SPECs implemented:** SPEC-BS-017, SPEC-BS-018, SPEC-TX-105, SPEC-TX-106, SPEC-TX-107, SPEC-TX-108, SPEC-TX-109, SPEC-TX-110, SPEC-TX-111, SPEC-DO-006, SPEC-DO-007, SPEC-DO-008, SPEC-DO-009

---

### Unit 9: Landing Zone IAM Policy + Preflight Gates
**Files:**
- `infra/live/10-management-iam/main.tf` — replace `DenyAllExceptBoundary` with three-statement form; drop `iam:DeleteGroupPermissionsBoundary`
- `scripts/preflight-floci.sh` — G1 relabel (name both enforcement variables), G1 fail-on-unestablished, G6 permissions-boundary gate, G3b S3 conditional PutObject gate
- `tests/preflight.bats` (NEW) — SPEC-TX-112-1/2/3, SPEC-TX-113-1/2, SPEC-TX-114-1
- `tests/stubs/bin/aws` — subcommand-aware stub (like `podman` stub pattern)

**Findings covered:**
- CH-LZ-001 — Replace `DenyAllExceptBoundary` with three-statement form; drop non-existent group action; add G6 negative test
- CH-LZ-002 — Add G6 permissions-boundary evaluation gate; qualify §1.1 and §5.2/§12; record gap (standalone SPEC per D-3)
- CH-LZ-003 — Relabel G1 to name both enforcement variables; add to §1.1 and §10.1
- CH-LZ-004 — G1 must fail (not skip) when probe cannot be established; main exit non-zero on any SKIP among automated gates
- CH-LZ-007 — Add G3b for S3 conditional PutObject, or mark use_lockfile unverified

**Acceptance criteria:**
1. `DenyAllExceptBoundary` replaced with three statements: `DenyPrincipalCreationWithoutBoundary`, `DenyBoundaryPolicyMutation`, `DenyBoundaryDetach`
2. `iam:DeleteGroupPermissionsBoundary` removed (not a real IAM action)
3. `terraform destroy` on stage 10 succeeds; `terraform apply` succeeds with policy version rotation
4. G6 gate: mint role with boundary denying `s3:*`, identity allowing `s3:ListAllMyBuckets`, assume → **denied**
5. G6 positive control: same role without boundary → `s3:ListAllMyBuckets` succeeds
6. G1 label names both `FLOCI_AUTH_VALIDATE_SIGNATURES` and `FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED`
7. G1 calls `fail` (not `skip`) when `create-access-key` fails; distinguishes "IAM unreachable" from "IAM reachable and permissive"
8. `main` exits non-zero on any SKIP among automated gates (G1, G3, G3b, G6); manual-notes gates (G2, G4, G5) may SKIP
9. G3b gate: `aws s3api put-object --if-none-match '*'` twice; second must fail with `PreconditionFailed`
10. `aws` stub created in `tests/stubs/bin/` with per-subcommand control (per D-8 challenger win)

**Dependencies:**
- **Blocks on:** Unit 1 (needs new credential model for G1: deployer AKID, not `DEV_AKID`)
- **Blocks:** Unit 11 (LZ Terraform coherence references the IAM policy)

**Build verification:**
```sh
terraform -chdir=infra/live/10-management-iam fmt -check
terraform -chdir=infra/live/10-management-iam validate
shellcheck scripts/preflight-floci.sh
bats tests/preflight.bats
```

**Specialist SPECs implemented:** SPEC-SW-006, SPEC-SW-015 (CH-LZ-002 standalone), SPEC-SX-008, SPEC-SX-009, SPEC-SX-010, SPEC-SX-011, SPEC-TX-112, SPEC-TX-113, SPEC-TX-114, SPEC-DO-010, SPEC-DO-013

---

### Unit 10: Landing Zone Terraform Coherence
**Files:**
- `infra/_common/providers.tf` — reverse `default_tags` merge order; add `environment` validation; restore governance tags template
- `infra/_common/versions.tf` — unify provider constraint to `>= 6.56.0` (NO upper bound per D-1); delete unresolved note
- `infra/_common/backend.hcl.example` — align region with `dev.tfvars`; update `use_lockfile` comment
- `infra/live/10-management-iam/providers.tf` — restore governance tags; restore `sns`/`sqs` endpoints; omit `key` from backend; unify provider constraint
- `infra/environments/dev.tfvars` — correct mechanism comment; `Owner` only in `default_tags`
- `docs/design/authentication-plan.md` — §6.10b: reduce to `-backend-config=../../_common/backend.hcl` + per-stage key
- `docs/design/landing-zone-design.md` — §7 record version decision; §4.1 document single-source-of-truth region

**Findings covered:**
- CH-LZ-005 — Align backend region with tfvars region; unify five region literals
- CH-LZ-006 — Reduce §6.10b to `-backend-config=../../_common/backend.hcl` + per-stage key
- CH-LZ-008 — Restore governance tags in `_common/providers.tf` template; Owner is general tag; `dev.tfvars` carries only Owner; add lint check
- CH-LZ-009 — Unify provider constraints to `>= 6.56.0` with NO upper bound (per D-1 challenger win)
- CH-LZ-010 — Omit key from `providers.tf` to force `-backend-config` override
- CH-LZ-011 — Reverse `default_tags` merge order; add environment validation
- CH-LZ-012 — Correct mechanism in `dev.tfvars` comment and §6.10c

**Acceptance criteria:**
1. `backend.hcl.example` region matches `dev.tfvars` region (both `eu-west-2`)
2. `setup-floci.sh` `FLOCI_DEFAULT_REGION`, `preflight-floci.sh` `REGION`, `dev-twin.sh` `DEV_REGION` all `eu-west-2`
3. §6.10b prescribes `-backend-config=../../_common/backend.hcl` + `-backend-config="key=dev/10-management-iam/terraform.tfstate"` only
4. No deprecated `force_path_style` or `endpoint` CLI arguments in §6.10b
5. `_common/providers.tf` `default_tags` merge includes `Project`, `Environment`, `ManagedBy`
6. `10-management-iam/providers.tf` `default_tags` merge includes same trio; `sns`/`sqs` endpoints restored
7. `dev.tfvars` `default_tags` contains only `Owner`
8. All stages use `aws >= 6.56.0` (no upper bound); `_common/versions.tf` is canonical source
9. `versions.tf:13-14` note removed; decision recorded in landing-zone §7
10. `key` omitted from `10-management-iam/providers.tf` backend block; `terraform init` without override fails loudly
11. `merge(var.default_tags, {Project, Environment, ManagedBy})` — governance tags always win
12. `variable "environment"` has validation: `contains(["dev", "uat", "prod"], var.environment)`
13. `dev.tfvars` comment states real mechanism: merge precedence, silent override, no diagnostic
14. Lint check exists verifying `infra/live/*/providers.tf` matches `_common/providers.tf` template

**Dependencies:**
- **Blocks on:** Unit 9 (IAM policy changes in same stage)
- **Blocks:** Nothing (leaf unit)

**Build verification:**
```sh
terraform -chdir=infra/_common fmt -check
terraform -chdir=infra/live/10-management-iam fmt -check
terraform -chdir=infra/live/10-management-iam validate
make lint                                    # for shell script region changes
```

**Specialist SPECs implemented:** SPEC-SW-007, SPEC-SW-008, SPEC-SW-009, SPEC-SW-010, SPEC-SW-011, SPEC-SW-012, SPEC-SW-013, SPEC-SX-012, SPEC-DO-011, SPEC-DO-012, SPEC-DO-014, SPEC-DO-015, SPEC-DO-016, SPEC-DO-017, SPEC-DX-010, SPEC-DX-011

---

### Unit 11: Documentation Updates
**Files:**
- `docs/design/authentication-plan.md` — §6.10a–d split into changelog/appendix; §9.3 mark items specified-not-verified; §4.1/§8.3 replace "Crypto theater"; §8 cross-reference presign threat model; §9.4 lessons-learned cross-references
- `docs/design/landing-zone-design.md` — §1.1 qualify API authorization row (name both enforcement variables, boundary evaluation unverified); §4.1/§4.2 update account selection model; §5.2 add verification-status note; §12 qualify permissions-boundary claim; §3 qualify unbuilt scaffolding; §10.1 add `TF_VAR_secret_key` story; §12 cross-link presign secret
- `docs/design/solution-design.md` — §8.2 expand presign-secret section (threat model, rotation path, reuse-if-exists); §8.3 qualify multi-account isolation
- `docs/design/gaps-register.md` — GAP-016 (three-account trade-off), GAP-017 (boundary evaluation unverified)
- `docs/learning/` — specify three lessons-learned entries (CH-META-001/002/003); standing rules for skills
- Root `install.sh` — **REMOVE** from repository

**Findings covered:**
- CH-AUTH-012 — Split §6.10a–d into changelog/appendix
- CH-AUTH-014 — Add presign-secret threat model, rotation path, and reuse-if-exists note
- CH-AUTH-015 — Mark §9.3 items as specified-not-verified
- CH-AUTH-016 — Replace "Crypto theater" with "Authenticates callers and then ignores their policies"
- CH-LZ-013 — Remove root `install.sh`; qualify §3 unbuilt scaffolding; add `TF_VAR_secret_key` story to §10.1; cross-link presign secret to CH-AUTH-014
- CH-META-001 — Record corrected mechanism for M-SW-001; fix five remaining region literals
- CH-META-002 — Record lesson; add standing rule for IAM Condition absent-key evaluation
- CH-META-003 — Record lesson; add standing rule for env-var source-line quoting

**Acceptance criteria:**
1. §6.10a–d split: landed changes in appendix, pending changes in §6
2. §9.3 items marked "Specified — not yet verified" with CH-finding references
3. No occurrence of "Crypto theater" or "crypto theater" in any documentation file
4. `solution-design.md` §8.2 has threat model, rotation path, reuse-if-exists note
5. `landing-zone-design.md` §1.1 names both enforcement variables; boundary evaluation marked unverified
6. `landing-zone-design.md` §4.1/§4.2 updated with per-instance account selection model
7. `landing-zone-design.md` §5.2 has verification-status note
8. `landing-zone-design.md` §3 has implementation-status note (stages 00, 10 built; 20–60 specified)
9. `landing-zone-design.md` §10.1 documents `TF_VAR_secret_key` sourcing from `DEV_CREDENTIALS_FILE`
10. `landing-zone-design.md` §12 cross-references presign-secret threat model
11. `gaps-register.md` has GAP-016 (three-account trade-off) and GAP-017 (boundary evaluation unverified)
12. Three lessons-learned entries specified with standing rules
13. Root `install.sh` removed; no documentation references it
14. All cross-document consistency relationships verified (10 relationships per DX analysis)

**Dependencies:**
- **Blocks on:** All prior units (documents the as-implemented state)
- **Blocks:** Nothing (final documentation pass)

**Build verification:**
```sh
# Manual review — no automated build for markdown docs
# Verify cross-references with grep:
grep -rn 'Crypto theater\|crypto theater' docs/        # must return nothing
grep -rn 'install\.sh' docs/                           # must return nothing (except this plan)
ls install.sh                                          # must not exist
```

**Specialist SPECs implemented:** SPEC-SW-004, SPEC-SW-014, SPEC-DX-001 through SPEC-DX-013, SPEC-SX-007

---

### Unit 12: Test Implementation (All Bats Cases)
**Files:**
- `tests/phase5.bats` — SPEC-TX-100-1
- `mock-server/tests/dev_twin.bats` — SPEC-TX-101-1 through 101-7, SPEC-TX-102-1/2, SPEC-TX-104-1/2
- `mock-server/tests/completion_protocol.bats` — SPEC-TX-103-1/2/3/4, SPEC-TX-106-1/2, SPEC-TX-107-1, SPEC-TX-108-1
- `mock-server/tests/orchestrator_args.bats` — SPEC-TX-105-1/2, SPEC-TX-110-1/2/3, SPEC-TX-111-1
- `tests/preflight.bats` (NEW) — SPEC-TX-112-1/2/3, SPEC-TX-113-1/2, SPEC-TX-114-1
- `tests/stubs/bin/aws` (NEW) — subcommand-aware stub
- `mock-server/tests/stubs/bin/uname` (NEW) — symlink to `_stub`

**Findings covered:**
- All TX test specifications (SPEC-TX-100 through 114)
- 26 new + 3 modified test cases across 7 test files (reconciled count per D-6)

**Acceptance criteria:**
1. All 29 test cases pass (`make test` exits 0)
2. `aws` stub created with per-subcommand control (like `tests/stubs/bin/podman`)
3. `uname` stub created as `mock-server/tests/stubs/bin/uname -> ../_stub`
4. `scripts/preflight-floci.sh` added to `make lint` scope (per M-7 accepted)
5. `tests/preflight.bats` follows existing `tests/AGENTS.md` conventions

**Dependencies:**
- **Blocks on:** All implementation units (Units 1–11) — tests verify the fixes
- **Blocks:** Unit 13 (final integration)

**Build verification:**
```sh
make test                                    # all bats tests
make lint                                    # includes preflight-floci.sh
```

**Specialist SPECs implemented:** SPEC-TX-100 through SPEC-TX-114 (all TX specifications)

---

### Unit 13: Final Integration — Remove install.sh, make check, make twin-test
**Files:**
- Root `install.sh` — **REMOVE** (if not already removed in Unit 11)
- `.github/workflows/test.yml` — add `permissions: { contents: read }` (per M-6 accepted)
- `Makefile` — add `scripts/preflight-floci.sh` to lint scope (per M-7 accepted)
- `mock-server/tests/stubs/bin/` — verify all stubs present

**Findings covered:**
- CH-LZ-013 (install.sh removal — final verification)
- M-6 — test.yml permissions (accepted)
- M-7 — make lint coverage (accepted)
- M-21 — opencode.yml pin SHA + concurrency (accepted)
- M-22 — opencode.yml concurrency (accepted)
- M-23 — terraform-validate CI job (accepted)

**Acceptance criteria:**
1. `install.sh` does not exist in repository root
2. `make check` passes (lint + unit tests)
3. `make twin-test` passes (Lima digital twin integration test)
4. `test.yml` has `permissions: { contents: read }`
5. `make lint` covers `scripts/preflight-floci.sh`
6. `opencode.yml` action pinned to full SHA; `concurrency:` group added
7. CI `terraform-validate` job added (or deferred with explicit rationale)

**Dependencies:**
- **Blocks on:** All prior units (Units 1–12)
- **Blocks:** B-FINAL-GATE

**Build verification:**
```sh
make check                                   # lint + unit tests
make twin-test                               # Lima digital twin
```

**Specialist SPECs implemented:** SPEC-DO-018, SPEC-DO-019, SPEC-DO-020, SPEC-DO-021, SPEC-DO-022, SPEC-DO-023

---

## Implementation Order

```
Phase B Entry Gate: Three-Outcome Probe (CH-AUTH-001)
│  └─ Record result in gaps-register.md as GAP-016
│
├─ Unit 1: Auth Configuration Surface
│  └─ Foundation for all auth-dependent work
│
├─ Unit 2: Credential Block Replacement ─────────────────────┐
├─ Unit 4: Guest Driver Array Fixes                           │
├─ Unit 5: wait_driver Fix ──────────────────────────────────┤
├─ Unit 6: Installer Fixes                                   │
│                                                             │
├─ Unit 3: Credential Rotation Fixes ◄── depends on Unit 1   │
│  └─ Needs DEV_AUTH_MODE from auth config                   │
│                                                             │
├─ Unit 9: LZ IAM Policy + Preflight ◄── depends on Unit 1   │
│  └─ Needs new credential model for G1                      │
│                                                             │
├─ Unit 7: Dev Twin Fixes ◄── depends on Units 2, 3          │
│  └─ Needs dev_env awk rewrite + DEV_AUTH_MODE              │
│                                                             │
├─ Unit 8: Test Harness Fixes ◄── depends on Unit 5          │
│  └─ Needs wait_driver changes for CH-TWIN-007              │
│                                                             │
├─ Unit 10: LZ Terraform Coherence ◄── depends on Unit 9     │
│  └─ References IAM policy in same stage                    │
│                                                             │
├─ Unit 11: Documentation Updates ◄── depends on all above   │
│  └─ Documents the as-implemented state                     │
│                                                             │
├─ Unit 12: Test Implementation ◄── depends on all above      │
│  └─ Tests verify all fixes                                 │
│                                                             │
└─ Unit 13: Final Integration ◄── depends on all above       │
   └─ make check + make twin-test + CI fixes                 │
```

**Parallelism:** Units 2, 4, 5, 6 can run in parallel after the entry gate. Units 1, 3, 9, 7, 8, 10 are sequential within their dependency chains. Units 11, 12, 13 are sequential final passes.

---

## Backlog Items (Not in Phase B)

The following findings are **deferred to future work** and are NOT implemented in this ticket:

### Backlogged Advisories (6)
| ID | Finding | Reason |
|----|---------|--------|
| M-9 | CH-LZ-003/004 missing from SW analysis | Process improvement — SW analysis coverage gap; findings themselves are implemented |
| M-16 | DX lessons-learned entries capture only 3 of 10 advisory rows | Deferred — remaining 7 lessons to be captured in future learning pass |
| M-17 | SX missed CH-LZ-009 + CH-LZ-010 | Process improvement — SX analysis coverage gap; findings themselves are implemented |
| M-24 | DO dropped CH-TWIN-002/004/007, CH-DEV-001–004/006 | Process improvement — DO analysis coverage gap; findings themselves are implemented |
| M-31 | DX CH-INST-004 doc-consistency impact dropped | Low confidence (75) — deferred |
| M-35 | BS _run_as_floci_guest injection surface | Low confidence (78) — deferred |
| M-36 | BS generate_presign_secret no error check | Low confidence (75) — deferred |
| M-37 | DO no assessment of deployment safety/rollback for infra/ | Low confidence (75) — deferred |
| M-39 | BS write_quadlet_unit empty publish_ports | Low confidence (72) — deferred |
| M-40 | BS wait_driver signal-kill misattribution | Low confidence (70) — deferred |
| M-41 | BS enable_lingering C-style for loop bashism | Low confidence (68) — deferred |
| M-42 | BS preflight_ports printf '%b' obscure | Low confidence (65) — deferred |
| M-43 | DO self-audit checklist largely "N/A" | Low confidence (70) — deferred |

### Backlogged Recommendations (53)
All 53 recommendations (R-1 through R-53) from the A2 dual-model challenge are backlogged. These are process improvements, additional test cases, documentation enhancements, and CI/CD hardening that do not block the core remediation. See `docs/project-management/logs/tickets/psc-0003/A2c-decision-register.md` §3 for the full list.

### Backlogged Disagreement (1)
| ID | Finding | Reason |
|----|---------|--------|
| D-23 | DO SPEC-DO-014 lint check should be terraform validate, not shell diff | Advisory confidence (75) — deferred |

---

## Total Units: 13

| Unit | Name | Files Changed | Findings Covered | Build Verification |
|------|------|---------------|------------------|--------------------|
| Gate | Three-Outcome Probe | gaps-register.md | CH-AUTH-001 (probe only) | Manual execution |
| 1 | Auth Configuration Surface | 2 | CH-AUTH-001, 002, 003, 013 | `make lint` |
| 2 | Credential Block Replacement | 2 | CH-AUTH-004 | `shellcheck` + `bats` |
| 3 | Credential Rotation Fixes | 2 | CH-AUTH-005, 006, 007, 011 | `shellcheck` + `bats` |
| 4 | Guest Driver Array Fixes | 2 | CH-AUTH-008, 009 | `shellcheck` |
| 5 | wait_driver Fix | 2 | CH-AUTH-010 | `shellcheck` + `bats` |
| 6 | Installer Fixes | 3 | CH-INST-001–005 | `make lint` |
| 7 | Dev Twin Fixes | 1 | CH-DEV-001–006 | `shellcheck` |
| 8 | Test Harness Fixes | 4 | CH-TWIN-001–007 | `shellcheck` + `bats` |
| 9 | LZ IAM Policy + Preflight | 4 | CH-LZ-001, 002, 003, 004, 007 | `terraform validate` + `shellcheck` + `bats` |
| 10 | LZ Terraform Coherence | 7 | CH-LZ-005, 006, 008, 009, 010, 011, 012 | `terraform validate` + `make lint` |
| 11 | Documentation Updates | 6 | CH-AUTH-012, 014, 015, 016, CH-LZ-013, CH-META-001–003 | Manual review |
| 12 | Test Implementation | 7 | All SPEC-TX (100–114) | `make test` |
| 13 | Final Integration | 4 | CH-LZ-013 (install.sh), M-6, M-7, M-21, M-22, M-23 | `make check` + `make twin-test` |

**Total files touched:** 19 (matching ticket scope)
**Total findings implemented:** 49 accepted findings (all 49 ticket acceptance criteria)
**Total findings backlogged:** 64 (6 advisories + 53 recommendations + 5 low-confidence one-sided)

---

## Specialist SPEC Coverage

| Specialist | SPECs | Units Implementing |
|------------|-------|-------------------|
| SW (Software Engineer) | SPEC-SW-001 through 015 | Units 1, 9, 10, 11 |
| TX (Test Engineer) | SPEC-TX-100 through 114 | Units 2, 3, 5, 8, 9, 12 |
| DX (Docs Writer) | SPEC-DX-001 through 014 | Units 6, 10, 11 |
| SX (Security Reviewer) | SPEC-SX-001 through 013 | Units 1, 2, 3, 9, 10, 11 |
| BS (Bash Specialist) | SPEC-BS-001 through 019 | Units 1, 2, 3, 4, 5, 6, 7, 8 |
| DO (DevOps Specialist) | SPEC-DO-001 through 023 | Units 6, 7, 8, 9, 10, 13 |

---

## Risk Register

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Probe outcome (b) — security claim false | Unknown (probe not yet run) | Critical — rewrites auth plan §8.3 + landing-zone §1.1 | Probe is Phase B entry gate; no implementation until outcome known |
| CH-AUTH-004 awk rewrite introduces new edge case | Low | High — data loss in user's ~/.aws/credentials | 7 bats cases cover all known edge cases; idempotency test guards regression |
| CH-LZ-001 three-statement form has undiscovered null-key action | Low | High — another unconditional deny | G6 negative test proves boundary evaluation; IAM Access Analyzer check |
| Unit ordering creates merge conflicts | Medium | Medium — rework | Units designed for minimal file overlap; parallel units touch disjoint files |
| make twin-test fails on arm64-specific behaviour | Low | Medium — delayed integration | Twin test is final gate (Unit 13); all unit-level verification passes first |
