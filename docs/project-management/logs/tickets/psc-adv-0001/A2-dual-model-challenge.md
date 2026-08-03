# A2: Dual-Model Challenge Synthesis — psc-adv-0001

## Overview

6 specialist reviews (A1) were challenged by 6 independent challenger reviews (A2) using a different model (glm-5.2). The primary reviews produced **79 findings** across all domains. The challengers identified **19 disagreements** (primary position challenged) and **33 one-sided findings** (issues the primaries missed entirely). All 12 reviews returned CONDITIONAL PASS verdicts, but the challengers expanded the blocking-finding set significantly — from ~30 primary-blocking findings to ~50+ after incorporating challenger additions.

| Domain | Primary Findings | Disagreements | Missed (One-Sided) | Primary Verdict | Challenger Verdict |
|--------|-----------------|---------------|-------------------|-----------------|-------------------|
| SW (Software Engineer) | 12 | 4 | 5 | CONDITIONAL PASS | CONDITIONAL PASS (with rework) |
| TX (Test Engineer) | 15 | 4 | 6 | CONDITIONAL PASS | CONDITIONAL PASS (upheld) |
| DX (Docs Writer) | 14 | 1 | 5 | CONDITIONAL PASS | CONDITIONAL PASS (upheld) |
| SX (Security Reviewer) | 11 | 3 | 7 | CONDITIONAL PASS | CONDITIONAL PASS (upheld) |
| BS (Bash Specialist) | 11 | 4 | 4 | CONDITIONAL PASS | CONDITIONAL PASS (upheld) |
| DXS (DevOps Specialist) | 16 | 3 | 6 | CONDITIONAL PASS | CONDITIONAL PASS (with corrections) |
| **Total** | **79** | **19** | **33** | — | — |

---

## Disagreements

Each entry below presents the primary position, the challenger position, and a synthesis recommendation.

### D-SW-001: `readonly` inside `case` — severity understated (SW)

- **Primary (F-SW-009, conf 70):** `readonly` inside a `case` branch is "unconventional" and "may cause test friction"; severity MODERATE.
- **Challenger (conf 88):** This is a concrete testability *bug*, not stylistic. The project's `${VAR:-default}` bats-injection convention is broken for the three auth vars because `readonly` is hit on the first `source`. The auth plan's own §6.11 test requirements (two modes in one bats file) cannot both run under the proposed pattern. Severity should be HIGH (80+).
- **Recommendation:** Adopt the primary's first alternative: compute values into non-readonly locals inside the `case`, then declare `readonly` vars at the top level. Rewrite auth plan §4.2 code block before Phase B implementation. **Raise severity to HIGH.**

### D-SW-002: `merge()` duplicate-key failure mode mis-stated (SW)

- **Primary (F-SW-005, conf 85):** Claims Terraform `merge()` will error with "Duplicate key" for `Project`/`Environment`/`ManagedBy`.
- **Challenger (conf 82):** `merge()` does NOT error on duplicate keys — later maps silently overwrite earlier ones (per official Terraform docs). The actual bug is *worse*: a **silent value override** where `Environment = "development"` (from tfvars) silently overrides `Environment = "dev"` (from `var.environment`), breaking ABAC tag-match queries. The primary's failure-mode claim contradicts the official `merge` docs.
- **Recommendation:** Keep the fix (remove trio from `dev.tfvars`), but **correct the rationale**: the failure mode is silent ABAC tag drift, not a plan-time error. The silent nature raises severity.

### D-SW-003: "Circular dependency" framing is incorrect (SW)

- **Primary (F-SW-003, conf 95):** Notes "This is a circular dependency even if fixed" but does not resolve it.
- **Challenger (conf 80):** There is NO cycle — it is a linear DAG: `general_app_boundary data → general_app_boundary resource → platform_admin data → platform_admin resource`. The "circular" label is wrong and could mislead the implementer into thinking Terraform's graph resolver will choke.
- **Recommendation:** Keep the resource-addition fix. **Strike the "circular dependency" sentence.** The implementer should place the `general_app_boundary` resource block after its data source and before the `platform_admin` data source.

### D-SW-004: `merge({})` template deviation buried in sub-clause (SW)

- **Primary (F-SW-005, second paragraph):** Notes the `merge({}, var.default_tags)` deviation from `_common/` template but treats it as a sub-clause of F-SW-005.
- **Challenger (conf 78):** This is a **distinct, standalone architectural violation** of `infra/AGENTS.md` conventions. Even if the tfvars duplicate is fixed, this stage will still produce untagged resources. Deserves its own finding.
- **Recommendation:** Split into a separate finding. Track both fixes independently: (1) remove trio from `dev.tfvars`, (2) restore canonical trio in `10-management-iam/providers.tf:33`.

### D-TX-001: F-TX-007 is factually wrong — harness tests ARE in CI (TX)

- **Primary (F-TX-007, conf 80):** Claims `make test` runs only `tests/*.bats`; harness suite `mock-server/tests/*.bats` is NOT in CI.
- **Challenger (conf 92):** False. The `Makefile` `test` target runs both `bats tests/` AND `bats mock-server/tests/`. CI invokes `make test`, so all 7 harness `.bats` files execute on every push/PR. The primary did not read the Makefile before asserting.
- **Recommendation:** **Withdraw F-TX-007.** The CI gap it describes does not exist. If the intent was separate harness-test reporting, reclassify as advisory-only.

### D-TX-002: F-TX-009 overstates "unconditional" overwrite (TX)

- **Primary (F-TX-009, conf 70):** Journal check "unconditionally sets `ordering_result='FAIL'` if journal lines are out of order."
- **Challenger (conf 78):** The code is a **conditional** (`if [[ -z ... || ... -ge ... ]]`), not unconditional. The real bug is subtler: when a journal line is empty (parse failure), the test sets FAIL and discards the systemctl PASS. The primary's framing is self-contradictory.
- **Recommendation:** Re-state F-TX-009: "journal check downgrades a systemctl PASS to FAIL when either journal line is unparseable. Fix: preserve systemctl-based result when lines are missing; only set FAIL when both lines are present AND misordered."

### D-TX-003: F-TX-005 `source` "silent failure" mechanism partly wrong (TX)

- **Primary (F-TX-005, conf 70):** "`source` may fail silently or produce empty vars."
- **Challenger (conf 68):** Under `set -e`, a syntactically malformed file aborts hard — it does NOT "fail silently." The silent-downgrade risk is specifically the *empty-but-valid* file (or one missing the two vars). The recommendation (validate AKID/secret format) is still correct.
- **Recommendation:** Keep the finding but reframe: the silent-downgrade risk is the empty-but-valid file case. Add post-`source` non-empty + format check.

### D-TX-004: F-TX-010 cites wrong line for stderr suppression (TX)

- **Primary (F-TX-010, conf 60):** "stderr from `_run_as_floci_guest` is suppressed (`2>/dev/null` on line 334)."
- **Challenger (conf 55):** The `2>/dev/null` is on line 337 (the `limactl shell` invocation), not line 334. The functional effect is real but the citation is wrong.
- **Recommendation:** Fix the line reference to 337. Clarify suppression is at the `limactl shell` boundary.

### D-DX-001: F-DX-009 contains a factual error — `FLOCI_BOOTSTRAP_AKID` does not exist in the code (DX)

- **Primary (F-DX-009, conf 85):** Claims `aws_admin` "partially implements" auth plan §6.9 because `FLOCI_BOOTSTRAP_AKID` is referenced.
- **Challenger (conf 92):** Factually wrong. The actual code uses `$DEV_AKID` (hardcoded), not `${FLOCI_BOOTSTRAP_AKID:-$DEV_AKID}`. A global `rg "FLOCI_BOOTSTRAP"` returns zero matches. The primary copied the *proposed* code from the auth plan and presented it as current code.
- **Recommendation:** Rewrite F-DX-009 to reflect actual code: `aws_admin` uses `$DEV_AKID` and literal `test`; neither `FLOCI_BOOTSTRAP_*` variable exists. The recommendation stays the same but the "partially implements" framing must be removed.

### D-SX-004: F-SX-004 confidence overstated — AWS CLI enforces 0600 at read time (SX)

- **Primary (F-SX-004, conf 85):** MODERATE severity; script should set permissions proactively.
- **Challenger (conf 78):** AWS CLI hard-aborts on mode >0600 — this is enforced behaviour, not a soft check. The residual risk is only the window between write and first CLI use. MODERATE overstates a finding with no network exposure and a self-correcting failure mode.
- **Recommendation:** Keep the fix (`chmod 0600`), but **retier to LOW-MODERATE** (conf 78).

### D-SX-007: F-SX-007 severity overstated for a root-only input path (SX)

- **Primary (F-SX-007, conf 75):** MODERATE; cites `..` traversal and symlink following.
- **Challenger (conf 60):** The threat model is mis-specified. `FLOCI_HOST_PERSISTENT_PATH` is set by the operator running as root — it is not untrusted input. A "vulnerability" requiring the operator to attack their own install is a footgun, not a vulnerability.
- **Recommendation:** **Retier to LOW** (conf 60-65). Keep `realpath` canonicalization as defense-in-depth but do not block A-GATE on it.

### D-SX-009: F-SX-009 recommendation is unimplementable in rootless model (SX)

- **Primary (F-SX-009, conf 70):** Recommends `aide`/`auditd` for env file integrity monitoring.
- **Challenger (conf 55):** `auditd` is a system service the unprivileged `floci` user cannot install; `aide` requires a root-owned baseline DB. The recommendation contradicts the rootless threat model. The env file is already 0600 inside a 0700 home — that IS the integrity control.
- **Recommendation:** Drop the `aide`/`auditd` recommendation. Reclassify as informational (conf ≤55).

### D-BS-001: Reference-rigor lapses — `mktemp` is not POSIX, `install` cites wrong source (BS)

- **Primary (F-BS-002 refs):** Labels `mktemp` as POSIX.1-2017; cites POSIX `mv` for `install` atomicity.
- **Challenger (conf 80):** `mktemp` is a BSD invention, not POSIX. `install` atomicity should cite `install(1)` man page, not POSIX `mv`. These are reference-rigor lapses, not findings-blocking the verdict.
- **Recommendation:** Relabel `mktemp` citation to `[Source: BSD/GNU coreutils]`. Cite `install(1)` for atomicity.

### D-BS-002: F-BS-010 `read -t` mechanism misstated; finding is weaker than scored (BS)

- **Primary (F-BS-010, conf 40):** "`read -t` timeout only applies when reading from a terminal or pipe — not a regular file. The 30-second timeout is effectively dead code in non-TTY mode."
- **Challenger (conf 75):** The `confirm_reset` function gates on TTY first (line 266-272) and returns early in non-TTY mode BEFORE reaching `read -t`. The `read -t` line is only reachable when stdin IS a TTY, where the timeout is honored. The finding is moot.
- **Recommendation:** **Drop F-BS-010 entirely**, or reframe as informational (conf ≤20). The `is_tty` gate makes the path correct.

### D-BS-003: F-BS-006 `cp` non-atomic — context missed, fix is harmful (BS)

- **Primary (F-BS-006, conf 70):** `cp` in `_write_hosts_file` is non-atomic; recommends `mv` instead.
- **Challenger (conf 70):** The `cp` branch only executes for test-harness paths (when `hosts_file != "/etc/hosts"`). The primary's `mv` fix would **break the caller** — the caller expects `$tmpfile` to still exist for its own `rm -f`. This is a use-after-unlink.
- **Recommendation:** **Downgrade to LOW (conf 45). Do NOT apply the `mv` fix.** If atomicity is desired, use `install` without `sudo`/`-o root`.

### D-BS-004: F-BS-002 trap fix incomplete for idempotent-restart case (BS)

- **Primary (F-BS-002, conf 80):** Recommends `trap cleanup_temp_files EXIT INT TERM` with `rm -f "${APPARMOR_USERNS_PROFILE}.tmp.$$"`.
- **Challenger (conf 60):** `$$` in the trap only cleans the *current* run's temp files. If a previous run crashed leaving `.tmp.<oldpid>` files, the new run's `$$` differs and the trap won't clean orphaned files. A global `TEMP_FILES=()` array is more robust.
- **Recommendation:** Track temp files in a global array (`TEMP_FILES+=("$tmp")` after each creation; trap iterates and `rm -f`). Finding stays 80; fix confidence is 60.

### D-DXS-001: F-DXS-001 action-pinning recommendation cites stale v4.x SHA (DXS)

- **Primary (F-DXS-001, conf 90):** Recommends pinning `actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2`.
- **Challenger (conf 92):** The SHA is from v4.2.2 (2024) — a **downgrade of three major versions** from the current v7. v7.0.0 introduced a critical security fix blocking fork-PR checkouts for `pull_request_target`. The primary did not cite any source for the SHA and never verified against the releases page.
- **Recommendation:** Pin to `actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1`. This is a **blocking correction** — applying the primary's recommendation as written would introduce a security regression.

### D-DXS-002: F-DXS-007 rollback recommendation misapplies reliability-scalability skill (DXS)

- **Primary (F-DXS-007, conf 70):** "Per reliability-scalability skill §7, every deploy should be reversible within 5 minutes." Recommends `--rollback` flag.
- **Challenger (conf 60):** The reliability-scalability skill §7 addresses continuous deployment of running services, not one-shot idempotent installers. The installer's idempotency IS the rollback strategy. A `.bak`-based `--rollback` flag adds complexity for marginal value.
- **Recommendation:** Reframe F-DXS-007 as a **diagnostics improvement** (transaction log / phase tracking) rather than a rollback gap. The installer's idempotency already satisfies the recovery principle.

### D-DXS-003: F-DXS-011 has a formatting error (DXS)

- **Primary (F-DXS-011):** Finding header reads `Confidence = 65` instead of `| Confidence | 65 |`.
- **Challenger (conf 85):** Mechanical formatting defect that breaks the table structure.
- **Recommendation:** Fix the table row to match the other findings' format.

---

## One-Sided Findings (Primary Missed)

Findings the challengers identified that the primary reviews missed entirely, grouped by specialist domain.

### Software Engineer (SW) — 5 missed

| ID | Confidence | Description | Severity |
|----|-----------|-------------|----------|
| M-SW-001 | 90 | Region inconsistency: auth plan hardcodes `eu-west-1` but Terraform/dev.tfvars uses `eu-west-2`. AWS SigV4 signs the region into the signature — this mismatch breaks the entire rotation flow in sigv4 mode. **Runtime-correctness blocker for the auth plan's central feature.** | CRITICAL |
| M-SW-002 | 82 | `platform_admin` Deny statement (`main.tf:49-63`) scopes `resources` to only the boundary policy ARN, but the denied actions (`DeleteRolePermissionsBoundary`, `DeleteUserPermissionsBoundary`, `DeletePolicy`) act on role/user/policy ARNs — the Deny never matches. The delegated-administration guardrail is **non-functional**. | HIGH |
| M-SW-003 | 85 | `10-management-iam/providers.tf:12` hardcodes `bucket = "tf-state-dev"`, breaking the `_common/backend.hcl` environment-promotion pattern. Promoting to `uat`/`prod` requires editing stage code — violating the "stage code unchanged" rule. | HIGH |
| M-SW-004 | 80 | `dev.tfvars:27` sets `Environment = "development"` — a fourth, undocumented environment label distinct from `dev`/`uat`/`prod`. Even if deduplication worked, ABAC tag-match queries would fail because principals are tagged `Environment=dev` while resources get `development`. | HIGH |
| M-SW-005 | 72 | Auth plan §6.5 rotation deletes the old key with **zero verification** that the new key works. If `create-access-key` returns a malformed response, the script deletes the only working credential and persists a broken one — total lockout. | MODERATE |

### Test Engineer (TX) — 6 missed

| ID | Confidence | Description | Severity |
|----|-----------|-------------|----------|
| M-TX-001 | 82 | No test for rotation gating in `auth_mode=off`. If `_rotate_bootstrap_credentials` runs unconditionally in off mode, it could delete the working `floci`/`floci` bootstrap. The auth plan §6.5 needs an explicit `DEV_AUTH_MODE` guard. | HIGH |
| M-TX-002 | 80 | No test that `DEV_CREDENTIALS_FILE` is NOT consumed in `auth_mode=off`. A stale creds file from a prior sigv4 run would be sourced and used in off mode, where the rotated creds fail auth. | HIGH |
| M-TX-003 | 72 | `wait_driver` success path (line 229) has the same un-killed-wait defect as the failure path (F-TX-003). If the driver hangs after publishing DONE, `wait_driver` blocks indefinitely on the success path too. | MODERATE |
| M-TX-004 | 62 | No test for `chmod 0600` failure on `DEV_CREDENTIALS_FILE`. Under `set -e`, a `chmod` failure after key rotation (new key created, old key deleted) aborts without persisting — permanent lockout. | MODERATE |
| M-TX-005 | 70 | `_print_next_steps` security-warning test and `dev_reset` deletes-credentials-file test are listed in auth plan §6.11 but omitted from the primary's 15 findings. | MODERATE |
| M-TX-006 | 68 | No coverage for the §7.3 test-matrix cross-cutting concern: `podman exec -e ...` overrides must appear consistently across s3-smoke, Lambda sidecar, and G1 preflight steps. A single test per step misses the cross-step consistency requirement. | MODERATE |

### Docs Writer (DX) — 5 missed

| ID | Confidence | Description | Severity |
|----|-----------|-------------|----------|
| M-DX-001 | 95 | F-DX-010 is built on a false premise. ADRs **do exist** in `docs/learning/decisions/` (0001–0005) covering exactly the landing-zone decisions the primary listed as missing. The primary only checked `docs/adr/` (which doesn't exist) and missed the entire ADR registry. The recommendation to create ADRs in `docs/adr/` contradicts `docs/learning/AGENTS.md` isolation rules. | HIGH |
| M-DX-002 | 88 | F-DX-002 understates the inconsistency. Auth plan §3.1's Lifecycle column asserts `platform-admin` IS created by `10-management-iam` as a present-tense fact, and §3.3's lifecycle diagram depicts `floci-deployer → platform-admin → app roles` as operational. These are forward-looking claims reading as current-state facts — the same defect as F-DX-001. | HIGH |
| M-DX-003 | 75 | Auth plan §6.3 proposed `print_summary` echoes `secret=floci` to stdout. Echoing a live secret to stdout (captured in logs, terminal scrollback, CI output) is a credential-exposure vector the auth plan neither acknowledges in §2.2 nor mitigates. | MODERATE |
| M-DX-004 | 70 | Auth plan §4.3 states dev twin default is `sigv4`, but `make dev-up` on an existing VM does NOT re-invoke the installer (per AGENTS.md gotcha). The resume path (`_resume_health_check`) is not addressed — `FLOCI_AUTH_MODE` cannot be changed without `dev-recreate`. | MODERATE |
| M-DX-005 | 90 | Cross-document report DC-1 ("ADRs found: 0") and DC-3 ("No ADRs to trace") are both false — they inherit the M-DX-001 false premise. DC-1 should read "ADRs found: 5 (docs/learning/decisions/0001–0005)." | HIGH |

### Security Reviewer (SX) — 7 missed

| ID | Confidence | Description | Severity |
|----|-----------|-------------|----------|
| M-SX-001 | 85 | CI workflow `test.yml` has no `permissions:` block — `GITHUB_TOKEN` defaults to read/write for all scopes. The primary's F-SX-005 only flagged missing secret scanning, not the over-privileged token. | MODERATE |
| M-SX-002 | 80 | `actions/checkout@v7` and `anomalyco/opencode/github@latest` are unpinned to a commit SHA — supply-chain substitution risk. `@latest` is the most dangerous form (auto-updates on every run). | HIGH |
| M-SX-003 | 72 | Auth plan rotation writes credentials with `printf >` (non-atomic). A crash mid-write leaves a truncated/empty credentials file, and the next `dev_env` silently falls back to `test/test` — defeating the rotation. The installer's own `write_env_file` uses atomic `.tmp` + `mv`, but the rotation design does not. | MODERATE |
| M-SX-004 | 68 | Auth plan `dev-recreate` rotation path trusts `DEV_CREDENTIALS_FILE` content without validating it still authenticates. If the operator manually deleted the key between `dev-down` and `dev-recreate`, both the rotation AND the fallback silently fail. | LOW-MODERATE |
| M-SX-005 | 82 | Landing-zone design §5.4 IRSA stand-in never specifies `DurationSeconds` for the `sts:AssumeRole` call. Without an explicit bound, the session duration defaults to 1h but can be up to 12h — the exposure window is unspecified. | MODERATE |
| M-SX-006 | 70 | `FLOCI_AUTH_PRESIGN_SECRET` has no documented threat model and no rotation path. It is an independent authentication secret that bypasses the IAM layer the entire auth plan is about. The auth plan covers `floci-deployer` rotation extensively but never mentions this secret. | MODERATE |
| M-SX-007 | 75 | `opencode.yml` exposes `id-token: write` to an unpinned `@latest` third-party action with `secrets.OLLAMA_API_KEY` access. This is the canonical GitHub Actions takeover → cloud impersonation chain. | HIGH |

### Bash Specialist (BS) — 4 missed

| ID | Confidence | Description | Severity |
|----|-----------|-------------|----------|
| M-BS-001 | 85 | No `set -o errtrace` / `set -E` in any script. Without `errtrace`, an ERR trap (which F-BS-008 recommends adding) only fires in the top-level scope, not inside functions — defeating the purpose for a 1020-line function-structured installer. This is a **prerequisite** for F-BS-008's fix to work. | HIGH |
| M-BS-002 | 82 | Orphaned `systemd-run` unit + `limactl shell` on SIGINT in `run-test.sh`. The guest-side `tianlu-driver.service` transient unit keeps running inside the Lima VM after host SIGINT. Partial evidence without a manifest seal is a test-harness *correctness* issue, not just hygiene. | HIGH |
| M-BS-003 | 80 | `local var="$(cmd)"` pattern masks `errexit` in functions. Bash's `local` returns 0 even when `cmd` fails, so `set -e` does not fire. This appears in safety-critical paths (uid construction for `XDG_RUNTIME_DIR`/`DBUS_SESSION_BUS_ADDRESS`). | HIGH |
| M-BS-004 | 65 | `_write_hosts_file` uses `sudo install -g wheel` — the `wheel` group is macOS/BSD-specific and does not exist on Ubuntu by default. A reader porting the dev twin to Linux would get `install: invalid group 'wheel'`. | LOW |

### DevOps Specialist (DXS) — 6 missed

| ID | Confidence | Description | Severity |
|----|-----------|-------------|----------|
| M-DXS-001 | 92 | `opencode.yml` uses `anomalyco/opencode/github@latest` — unpinned mutable branch reference in a workflow with `id-token: write` and `secrets.OLLAMA_API_KEY` access. This is the **highest-severity finding in the repository**: a compromised action gets OIDC token + API key. The primary only reviewed `test.yml` and missed `opencode.yml` entirely. | CRITICAL |
| M-DXS-002 | 75 | `opencode.yml` triggers on `issue_comment` events with untrusted comment body input. Any user (including drive-by commenters on a public repo) can trigger a workflow that runs an unpinned action with `id-token: write`. | MODERATE |
| M-DXS-003 | 80 | No `timeout-minutes` on any CI job. Default is 360 minutes (6 hours). A hung step burns 6 hours of runner time. For `opencode.yml` (with secret access), a hung run also prolongs the credential-exposure window. | HIGH |
| M-DXS-004 | 70 | CI installs `shellcheck` and `bats` via `apt-get` on every run with no caching — adds ~10-20s of cold-install latency per run. | LOW |
| M-DXS-005 | 70 | `dev_env` profile name `[floci-dev]` can collide with a user's pre-existing real AWS profile of the same name. The grep guard skips the append, silently leaving real credentials in place. | MODERATE |
| M-DXS-006 | 65 | `configure_firewall` `case` uses `*)` catch-all for unknown `FIREWALL_SCOPE` values — typos silently fall through to `auto` instead of failing with a clear error. | LOW |

---

## Agreements

Findings where primary and challenger agree after independent verification. These are consolidated into action items below.

### Software Engineer (SW) — 9 agreements

F-SW-001, F-SW-002, F-SW-003 (substance agreed; recommendation refined by D-SW-003), F-SW-004, F-SW-006, F-SW-007 (positive), F-SW-008, F-SW-010, F-SW-011, F-SW-012 (positive)

### Test Engineer (TX) — 10 agreements

F-TX-001, F-TX-002, F-TX-003, F-TX-004, F-TX-005 (reframed per D-TX-003), F-TX-008, F-TX-009 (reframed per D-TX-002), F-TX-010 (line ref fixed per D-TX-004), F-TX-011, F-TX-012, F-TX-013, F-TX-014, F-TX-015

### Docs Writer (DX) — 12 agreements

F-DX-001, F-DX-002 (strengthened per M-DX-002), F-DX-003, F-DX-004, F-DX-005, F-DX-006, F-DX-007, F-DX-008, F-DX-009 (corrected per D-DX-001), F-DX-010 (corrected per M-DX-001), F-DX-011 (positive), F-DX-012 (positive), F-DX-013 (positive), F-DX-014

### Security Reviewer (SX) — 11 agreements

F-SX-001, F-SX-002, F-SX-003, F-SX-004 (retiered per D-SX-004), F-SX-005, F-SX-006, F-SX-007 (retiered per D-SX-007), F-SX-008, F-SX-009 (reclassified per D-SX-009), F-SX-010, F-SX-011

### Bash Specialist (BS) — 8 agreements

F-BS-001, F-BS-002 (fix refined per D-BS-004), F-BS-003, F-BS-004 (raised per M-BS-002), F-BS-005, F-BS-007, F-BS-008 (prerequisite M-BS-001 needed), F-BS-009, F-BS-011

### DevOps Specialist (DXS) — 13 agreements

F-DXS-001 (partial — SHA corrected per D-DXS-001), F-DXS-002, F-DXS-003, F-DXS-004, F-DXS-005, F-DXS-006, F-DXS-007 (reframed per D-DXS-002), F-DXS-008, F-DXS-009, F-DXS-010, F-DXS-011, F-DXS-012, F-DXS-013, F-DXS-014, F-DXS-015, F-DXS-016

---

## Recommendations

Challenger recommendations that don't fit the above categories.

### Cross-Cutting

1. **Unify temp-file tracking across all three scripts (R-BS-001).** Adopt a global `TEMP_FILES=()` array pattern with trap cleanup. Fixes F-BS-002, F-BS-003, F-BS-004, and the idempotent-restart orphan issue (D-BS-004).

2. **Add `set -o errtrace` before adding ERR traps (R-BS-002).** This is a prerequisite for F-BS-008's stack-backtrace fix to work inside functions.

3. **Split `local x="$(cmd)"` assignments (R-BS-003).** Audit all sites in the three scripts. Split into `local x; x="$(cmd)"` + explicit `rc` check. Closes a silent-failure class that `set -e` does not catch (M-BS-003).

4. **Reference-rigor cleanup (R-BS-005).** Relabel `mktemp` from POSIX to BSD/GNU coreutils. Cite `install(1)` for atomicity, not POSIX `mv`. Separate `cp -a` evidence-copy from atomic-write discussion.

5. **Self-audit improvements.** The primary reviews had several self-audit gaps: TX marked AGENTS.md compliance PASS but F-TX-007 was factually wrong (Makefile not read); DX had no ADR-inventory check row; SX had no CI/CD supply-chain row. Recommend each specialist add domain-specific self-audit rows.

### Security-Specific

6. **Close rotation-design gaps before implementation (SX challenger).** M-SX-003 (non-atomic credential write) and M-SX-004 (stale-file trust on dev-recreate) are design defects in the auth plan itself. Implement a design-revision pass on `authentication-plan.md` §6.5 before code implementation.

7. **Add `FLOCI_AUTH_PRESIGN_SECRET` to auth plan scope (M-SX-006).** The current plan ignores an independent secret that bypasses the IAM layer.

8. **STS session duration (M-SX-005).** Add `DurationSeconds` bound + re-assumption cadence to `landing-zone-design.md` §5.4.

### CI/CD-Specific

9. **Review ALL workflow files, not just `test.yml` (DXS challenger).** The primary only reviewed `test.yml` and missed `opencode.yml` entirely — which contains the highest-severity finding (M-DXS-001).

10. **Restrict opencode workflow triggers to trusted users (M-DXS-002).** Add `github.event.comment.author_association` check.

11. **Consider apt caching in CI (M-DXS-004).** Advisory — reduces feedback latency.

12. **Namespace the dev-env AWS profile (M-DXS-005).** Use `tianlu-floci-dev` instead of `floci-dev` to avoid collisions with real AWS profiles.

13. **Validate `FIREWALL_SCOPE` explicitly (M-DXS-006).** Replace `*)` catch-all with an explicit error for unknown values.

### Documentation-Specific

14. **Escalate M-DX-003 (secret in stdout) to Security Reviewer.** The auth plan §6.3 proposed code prints `secret=floci` to stdout. Whether this is acceptable (given §8.1 "public knowledge" justification) is a security judgment.

15. **Split DX blocking list into docs-blocking vs code-blocking.** The current blocking list conflates "must fix before Docs review passes" with "must fix before the code is correct."

---

## Consolidated Action Items

Prioritized list of all actions needed, with source attribution. Blocking items (confidence ≥80) are marked **[BLOCKING]**.

### P0 — Must Fix Before Phase B (Design Defects + Runtime Blockers)

| # | Action | Source(s) | Domain |
|---|--------|-----------|--------|
| 1 | **[BLOCKING]** Fix region inconsistency: replace all `eu-west-1` literals in auth plan with `DEV_REGION` constant (default `eu-west-2`). SigV4 signs region into signature — mismatch breaks rotation. | M-SW-001 (conf 90) | SW |
| 2 | **[BLOCKING]** Rewrite `DenyAllExceptBoundary` statement resources to `["*"]` or use `StringNotEquals` condition on `iam:PermissionsBoundary`. Current scoping makes the Deny a no-op. | M-SW-002 (conf 82) | SW |
| 3 | **[BLOCKING]** Remove hardcoded `bucket = "tf-state-dev"` from `10-management-iam/providers.tf`; use `-backend-config` pattern. | M-SW-003 (conf 85) | SW |
| 4 | **[BLOCKING]** Remove `Environment = "development"` from `dev.tfvars`; add validation that `Environment ∈ {dev,uat,prod}`. | M-SW-004 (conf 80), D-SW-002 | SW |
| 5 | **[BLOCKING]** Rewrite auth plan §4.2 code block: move `readonly` out of `case` to preserve `${VAR:-default}` test-injection convention. | D-SW-001 (conf 88) | SW |
| 6 | **[BLOCKING]** Add `resource "aws_iam_policy" "general_app_boundary"` to `10-management-iam/main.tf`. Strike "circular dependency" framing. | F-SW-003, D-SW-003 | SW |
| 7 | **[BLOCKING]** Reconcile provider version: align `10-management-iam/providers.tf` with `_common/versions.tf` (`>= 5.95.0, < 7.0.0`). | F-SW-004 (conf 90) | SW |
| 8 | **[BLOCKING]** Fix `merge({}, var.default_tags)` in `10-management-iam/providers.tf:33` to restore canonical trio injection matching `_common/providers.tf`. | D-SW-004 (conf 78), F-SW-005 | SW |
| 9 | **[BLOCKING]** Add `FLOCI_SERVICES_IAM_ENABLED=true` to `sigv4` branch of `FLOCI_AUTH_MODE` case statement. | F-SW-001 (conf 85) | SW |
| 10 | **[BLOCKING]** Add `secret_key` to `dev.tfvars` with documented default; cross-reference with `FLOCI_BOOTSTRAP_SECRET`/`DEV_BOOTSTRAP_SECRET` in auth plan. | F-SW-006 (conf 80) | SW |
| 11 | **[BLOCKING]** Add verification step (`sts get-caller-identity`) between create and delete in rotation flow. | M-SW-005 (conf 72) | SW |
| 12 | **[BLOCKING]** Make credential-file write atomic in rotation: write to `.tmp`, `chmod 0600`, `mv -f` — mirroring `write_env_file` pattern. | M-SX-003 (conf 72) | SX |
| 13 | **[BLOCKING]** Add `set -o errtrace` to all three scripts (prerequisite for ERR traps to fire in functions). | M-BS-001 (conf 85) | BS |
| 14 | **[BLOCKING]** Split `local x="$(cmd)"` assignments to expose command failures (silent-failure class under `set -e`). | M-BS-003 (conf 80) | BS |
| 15 | **[BLOCKING]** Add signal trap + orphan cleanup to `run-test.sh` (orphaned `systemd-run` unit + stale evidence on SIGINT). | M-BS-002 (conf 82), F-BS-004 | BS |
| 16 | **[BLOCKING]** Pin `anomalyco/opencode/github` in `opencode.yml` to a full commit SHA. `@latest` + `id-token: write` + `secrets.OLLAMA_API_KEY` is a critical supply-chain risk. | M-DXS-001 (conf 92), M-SX-002 (conf 80), M-SX-007 (conf 75) | DXS/SX |
| 17 | **[BLOCKING]** Pin `actions/checkout` to v7.0.1 SHA `3d3c42e5aac5ba805825da76410c181273ba90b1` (NOT the primary's stale v4.2.2 SHA). | D-DXS-001 (conf 92) | DXS |
| 18 | **[BLOCKING]** Add `permissions: contents: read` to `test.yml`; add `concurrency` group. | F-DXS-001 (conf 90), M-SX-001 (conf 85) | DXS/SX |
| 19 | **[BLOCKING]** Add `timeout-minutes` to all CI jobs (15 min test, 30 min opencode). | M-DXS-003 (conf 80) | DXS |
| 20 | **[BLOCKING]** Add Dependabot config for GitHub Actions (`.github/dependabot.yml`). | F-DXS-002 (conf 85) | DXS |
| 21 | **[BLOCKING]** Add guard to `wait_driver` for empty `DRIVER_SHELL_PID` (false-positive when PID unset). | F-DXS-004 (conf 85) | DXS |
| 22 | **[BLOCKING]** Add UFW rule cleanup on firewall scope change in `configure_firewall`. | F-DXS-006 (conf 80) | DXS |
| 23 | **[BLOCKING]** Document dev-twin-only `ExecCondition` Quadlet override in AGENTS.md Critical gotchas. | F-DXS-012 (conf 80) | DXS |
| 24 | **[BLOCKING]** Add `$*` → `printf '%q '` fix in `_run_as_floci_guest` (argument boundary loss). | F-BS-001 (conf 85) | BS |
| 25 | **[BLOCKING]** Add trap cleanup for temp files in `setup-floci.sh` and `dev-twin.sh` (use global `TEMP_FILES=()` array pattern). | F-BS-002 (conf 80), F-BS-003 (conf 80), D-BS-004 | BS |
| 26 | **[BLOCKING]** Add ERR trap / stack backtrace to all three scripts (after `errtrace` is set). | F-BS-008 (conf 70→75) | BS |
| 27 | **[BLOCKING]** Add auth plan status banner: "Status: Design proposal — NOT YET IMPLEMENTED." | F-DX-001 (conf 90) | DX |
| 28 | **[BLOCKING]** Add `platform-admin` "policy only — pending Phase 1" caveat to auth plan §3.1/§3.3 and landing-zone design §5.1. | F-DX-002 (conf 85), M-DX-002 (conf 88) | DX |
| 29 | **[BLOCKING]** Create gap entry GAP-015 in `gaps-register.md` for Floci's lack of root user concept. | F-DX-003 (conf 90) | DX |
| 30 | **[BLOCKING]** Add IAM identity lifecycle note to `solution-design.md` §10. | F-DX-004 (conf 90) | DX |
| 31 | **[BLOCKING]** Correct F-DX-010: ADRs exist in `docs/learning/decisions/` (0001–0005). Narrow recommendation to auth-plan-specific ADRs only. Determine correct ADR location (PM decision). | M-DX-001 (conf 95) | DX |
| 32 | **[BLOCKING]** Correct cross-document report DC-1/DC-3 to reflect 5 existing ADRs. | M-DX-005 (conf 90) | DX |
| 33 | **[BLOCKING]** Implement `FLOCI_AUTH_MODE` parameter in `setup-floci.sh` (config block, `write_env_file`, `print_summary` conditional). | F-SX-003 (conf 95), F-SW-002 (conf 90) | SX/SW |
| 34 | **[BLOCKING]** Implement `_rotate_bootstrap_credentials` in `dev-twin.sh` with `DEV_CREDENTIALS_FILE`, `DEV_AUTH_MODE`, and `dev_env` rotation integration. | F-SX-001 (conf 95), F-DX-005 (conf 95) | SX/DX |
| 35 | **[BLOCKING]** Implement `FLOCI_BOOTSTRAP_*` env var support in `preflight-floci.sh` `aws_admin`. | F-SX-002 (conf 90), F-DX-009 (corrected per D-DX-001) | SX/DX |
| 36 | **[BLOCKING]** Add `--auth-mode` flag to `run-test.sh` and `AUTH_MODE` passthrough to guest driver. | F-DX-008 (conf 85) | DX |
| 37 | **[BLOCKING]** Add `chmod 0600` on `~/.aws/credentials` and `~/.aws/config` in `dev_env`. | F-SX-004 (conf 85→78) | SX |
| 38 | **[BLOCKING]** Add IRSA stand-in controls: rotation schedule, `immutable: true`, RBAC restriction, audit logging, pre-flight gate G6. | F-SX-006 (conf 85) | SX |
| 39 | **[BLOCKING]** Add STS `DurationSeconds` bound + re-assumption cadence to landing-zone design §5.4. | M-SX-005 (conf 82) | SX |
| 40 | **[BLOCKING]** Add `FLOCI_AUTH_PRESIGN_SECRET` section to auth plan: threat model, rotation procedure, cross-link from F-SX-001. | M-SX-006 (conf 70) | SX |
| 41 | **[BLOCKING]** Restrict opencode workflow triggers to trusted users (`author_association` check). | M-DXS-002 (conf 75) | DXS |
| 42 | **[BLOCKING]** Add `kill`-before-`wait` to both `wait_driver` (success path) and failure-path `wait` in `main`. | M-TX-003 (conf 72), F-TX-003 | TX |
| 43 | **[BLOCKING]** Add mode-gating tests: rotation is no-op in `auth_mode=off`; stale `DEV_CREDENTIALS_FILE` is not consumed in off mode. | M-TX-001 (conf 82), M-TX-002 (conf 80) | TX |
| 44 | **[BLOCKING]** Add `_rotate_bootstrap_credentials` unit tests (5 cases: fresh install, dev-recreate, fallback, partial failure, file permissions). | F-TX-001 (conf 90) | TX |
| 45 | **[BLOCKING]** Add `run-in-vm.sh` auth-mode tests and `--auth-mode` flag parsing tests. | F-TX-002 (conf 85) | TX |
| 46 | **[BLOCKING]** Add `FLOCI_AUTH_MODE` invalid-value and empty-value tests. | F-TX-011 (conf 85) | TX |
| 47 | **[BLOCKING]** Add `write_env_file` auth-var emission tests (off mode, sigv4 mode, backward compat). | F-TX-012 (conf 85) | TX |
| 48 | **[BLOCKING]** Add `print_summary` sigv4 message content tests. | F-TX-013 (conf 85) | TX |
| 49 | **[BLOCKING]** Add `dev_env` sed-replace and credential-rotation tests. | F-TX-014 (conf 80) | TX |
| 50 | **[BLOCKING]** Add `_print_next_steps` security-warning test and `dev_reset` deletes-credentials-file test. | M-TX-005 (conf 70) | TX |
| 51 | **[BLOCKING]** Add parametrized harness test for cross-cutting `podman exec -e ...` overrides in sigv4 mode (s3-smoke, Lambda, G1). | M-TX-006 (conf 68) | TX |
| 52 | **[BLOCKING]** Add `preflight-floci.sh` tests (`aws_admin` credential handling). | F-TX-015 (conf 75) | TX |
| 53 | **[BLOCKING]** Add `FLOCI_HOST_PERSISTENT_PATH` invalid-character parametrized tests. | F-TX-008 (conf 70) | TX |
| 54 | **[BLOCKING]** Add `chmod` failure test for `DEV_CREDENTIALS_FILE` persistence. | M-TX-004 (conf 62) | TX |
| 55 | **[BLOCKING]** Reorder rotation: persist new creds BEFORE deleting old key (prevents lockout on write failure). | M-TX-004, M-SX-003 | TX/SX |
| 56 | **[BLOCKING]** Add `dev-recreate` credential validation probe (`sts get-caller-identity`) before trusting persisted file. | M-SX-004 (conf 68) | SX |

### P1 — Should Fix (Advisory, Non-Blocking)

| # | Action | Source(s) | Domain |
|---|--------|-----------|--------|
| 57 | Add `--refresh-image` flag to `setup-floci.sh` for forced re-pull of pinned image. | F-DXS-008 (conf 75) | DXS |
| 58 | Add Terraform CI/CD pipeline section (§10.4) to landing-zone design (future). | F-DXS-009 (conf 80) | DXS |
| 59 | Document bootstrap state backup strategy in landing-zone design §9. | F-DXS-010 (conf 75) | DXS |
| 60 | Add `terraform_remote_state` coupling trade-off note to landing-zone design §3.2. | F-DXS-011 (conf 65) | DXS |
| 61 | Add `realpath` canonicalization for `FLOCI_HOST_PERSISTENT_PATH` (defense-in-depth). | F-SX-007 (conf 75→60) | SX |
| 62 | Add `dev_env_remove` function for AWS profile cleanup; call from `dev_reset`. | F-DXS-005 (conf 75) | DXS |
| 63 | Add transaction log / phase tracking to installer for better failure diagnostics. | F-DXS-007 (conf 70→60) | DXS |
| 64 | Add comment documenting `sort -V` GNU dependency or switch to `dpkg --compare-versions`. | F-BS-005 (conf 60) | BS |
| 65 | Add comment documenting `-g wheel` macOS-ism in `_write_hosts_file`. | M-BS-004 (conf 65) | BS |
| 66 | Add `FIREWALL_SCOPE` explicit validation (reject unknown values instead of catch-all `auto`). | M-DXS-006 (conf 65) | DXS |
| 67 | Namespace dev-env AWS profile to `tianlu-floci-dev` to avoid collisions. | M-DXS-005 (conf 70) | DXS |
| 68 | Document auth plan resume-path behavior: `make dev-up` on existing VM does not re-invoke installer. | M-DX-004 (conf 70) | DX |
| 69 | Escalate M-DX-003 (secret in stdout) to Security Reviewer for cross-validation. | M-DX-003 (conf 75) | DX |
| 70 | Add secret scanning (gitleaks/truffleHog) to CI pipeline with `.gitleaks.toml` baseline. | F-SX-005 (conf 80) | SX |
| 71 | Add `_resume_health_check` reset counter (limit to 1 reset, matching test twin behavior). | F-DXS-013 (conf 70) | DXS |
| 72 | Add comment above `FLOCI_PORTS_CONTAINER` explaining why 5100-5199 is excluded. | F-DXS-014 (conf 60) | DXS |
| 73 | Add overall timeout to `run-test.sh` (watchdog or `timeout` wrapper). | F-DXS-016 (conf 75) | DXS |
| 74 | Consider apt caching in CI (pre-baked image or `actions/cache`). | M-DXS-004 (conf 70) | DXS |
| 75 | Add `dev_env` idempotency fix: use `sed -i.bak` replace-then-write pattern for credential updates. | F-DX-014 (conf 80) | DX |
| 76 | Fix `_install_exec_condition` error suppression: check exit codes between `limactl` calls. | F-BS-011 (conf 50→60) | BS |
| 77 | Fix `_run_as_floci_guest` function signature documentation to match single-string implementation. | F-BS-009 (conf 75) | BS |
| 78 | Fix `driver_args[*]` expansion in `run-test.sh:194` using `printf '%q '`. | F-BS-007 (conf 65→70) | BS |
| 79 | Fix `_resume_health_check` start-failure logging (log before `|| true` suppression). | F-TX-010 (conf 60→55) | TX |
| 80 | Fix `run_reboot_test` journal ordering check: preserve systemctl PASS when journal lines are missing. | F-TX-009 (conf 70→78) | TX |
| 81 | Validate `DEV_CREDENTIALS_FILE` content after `source` (non-empty + AKIA prefix + secret length). | F-TX-005 (conf 70→68) | TX |
| 82 | Replace `grep -o`/`sed` JSON parsing with `jq` or add empty-result validation. | F-TX-004 (conf 80) | TX |
| 83 | Validate repo mirror evidence copy or document cache as authoritative. | F-TX-006 (conf 65) | TX |
| 84 | Add `dev_env` separate credentials file option (`~/.aws/floci-credentials`) to avoid polluting main file. | F-DXS-005 (conf 75) | DXS |
| 85 | Add `CODEOWNERS` file covering `.github/workflows/`. | F-DXS-001 | DXS |
| 86 | Fix F-DXS-011 table formatting (`Confidence = 65` → `| Confidence | 65 |`). | D-DXS-003 (conf 85) | DXS |

### P2 — Informational / Dropped

| # | Action | Source(s) | Domain |
|---|--------|-----------|--------|
| 87 | **Withdraw F-TX-007.** Harness tests ARE in CI (`make test` runs both `tests/` and `mock-server/tests/`). | D-TX-001 (conf 92) | TX |
| 88 | **Drop F-BS-010.** `read -t` timeout is correct — the `is_tty` gate ensures it only runs on a TTY. | D-BS-002 (conf 75) | BS |
| 89 | **Drop F-BS-006 `mv` fix.** The `cp` branch is test-only; `mv` would break the caller's `rm -f`. | D-BS-003 (conf 70) | BS |
| 90 | **Drop F-SX-009 `aide`/`auditd` recommendation.** Unimplementable in rootless model; 0600+0700 is adequate. | D-SX-009 (conf 55) | SX |
| 91 | **Correct F-DX-009 factual error.** `aws_admin` uses `$DEV_AKID`, not `${FLOCI_BOOTSTRAP_AKID:-$DEV_AKID}`. | D-DX-001 (conf 92) | DX |
| 92 | **Correct F-SW-005 failure-mode rationale.** `merge()` silently overrides, does not error on duplicate keys. | D-SW-002 (conf 82) | SW |
| 93 | **Relabel `mktemp` citation** from POSIX to BSD/GNU coreutils. | D-BS-001 (conf 80) | BS |
| 94 | Add structured logging to installer/test harness (future improvement). | F-DXS-015 (conf 65) | DXS |
| 95 | Document that dev twin TLS-off is loopback-only; add notice in `_print_next_steps`. | F-SX-010 (conf 80) | SX |
| 96 | Document test twin uses `floci`/`floci` without rotation (rotation is dev-twin concern). | F-SX-011 (conf 75) | SX |

---

## Verdict Summary

All 12 reviews returned **CONDITIONAL PASS**. The primary reviews identified 79 findings across 6 domains. The challengers confirmed the substance of most findings but identified:

- **19 disagreements** where the primary's position was challenged (4 mechanism errors, 3 severity misratings, 2 factual errors, 2 missing-context findings, 2 reference-rigor lapses, 2 fix-is-harmful findings, 1 false-positive finding, 1 stale-data recommendation, 1 formatting error, 1 scope gap)
- **33 one-sided findings** the primaries missed entirely (5 SW, 6 TX, 5 DX, 7 SX, 4 BS, 6 DXS)

The most critical missed findings are:

1. **M-SW-001 (conf 90):** Region mismatch (`eu-west-1` vs `eu-west-2`) breaks SigV4 rotation — the auth plan's central feature.
2. **M-SW-002 (conf 82):** `DenyAllExceptBoundary` statement is a non-functional guardrail (wrong resource scoping).
3. **M-DXS-001 (conf 92):** `@latest` action + `id-token: write` + secret access in `opencode.yml` — highest-severity supply-chain risk in the repo.
4. **M-BS-001 (conf 85):** Missing `errtrace` defeats ERR traps in functions — prerequisite for F-BS-008.
5. **M-BS-003 (conf 80):** `local x="$(cmd)"` silent-failure class under `set -e`.

The consolidated action items list contains **56 blocking items (P0)** and **30 advisory items (P1)** plus **10 informational/dropped items (P2)**. The blocking set is significantly larger than any single primary review identified, reflecting the value of the dual-model challenge in surfacing blind spots across all six specialist domains.
