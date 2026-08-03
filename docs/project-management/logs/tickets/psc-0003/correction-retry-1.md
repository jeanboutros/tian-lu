# Correction Retry 1 — psc-0003

| Field | Value |
|-------|-------|
| Agent | code-architect |
| Timestamp | 2026-07-30T00:00:00Z |
| Trigger | Phase C verification — 3 critical items |
| Status | All fixes applied, shellcheck passes |

## Fix 1: G1/G3 skip→fail in preflight-floci.sh

**File:** `scripts/preflight-floci.sh`

**Root cause:** The `skip` function does not set `FAILED=1`, so when IAM or DynamoDB is unreachable, `main` reports "automated gates passed" and exits 0. This is a false-negative security gate — the gate the design calls a "hard stop" reports success on precisely the configuration it exists to police.

**Changes:**
- Line 47 (G1): `skip "could not create access key (is IAM up?) — verify manually"` → `fail "could not create access key (is IAM up?) — verify manually"`
- Line 71 (G3): `skip "could not create table (is DynamoDB up?)"` → `fail "could not create table (is DynamoDB up?)"`

`fail` sets `FAILED=1` and `main` exits non-zero when any gate fails.

## Fix 2: Region literals

**Root cause:** `setup-floci.sh` defaulted to `eu-west-1` and `preflight-floci.sh` defaulted to `us-east-1`. The project standard is `eu-west-2`.

**Changes:**
- `setup-floci.sh` line 57: `readonly FLOCI_DEFAULT_REGION="${FLOCI_DEFAULT_REGION:-eu-west-1}"` → `readonly FLOCI_DEFAULT_REGION="${FLOCI_DEFAULT_REGION:-eu-west-2}"`
- `scripts/preflight-floci.sh` line 25: `readonly REGION="${AWS_DEFAULT_REGION:-us-east-1}"` → `readonly REGION="${AWS_DEFAULT_REGION:-eu-west-2}"`

Note: `dev-twin.sh` already uses `eu-west-2` (line 27: `DEV_REGION="${DEV_REGION:-eu-west-2}"`). The `dev_env()` function in `dev-twin.sh` still writes `eu-west-1` to `~/.aws/config` and exports `AWS_DEFAULT_REGION=eu-west-1` — this is a separate issue tracked in the Phase C findings.

## Fix 3: dev_status surfaces auth mode

**File:** `mock-server/dev-twin.sh`

**Root cause:** `dev_status()` showed instance state, disk, service, and health but not the active auth mode. Since `FLOCI_AUTH_MODE` cannot change without `make dev-recreate`, surfacing it in status output prevents the user from assuming the wrong mode is active.

**Change:** Added auth mode read + display to `dev_status()` (lines 756-759):
```bash
# Surface the installed auth mode
local auth_mode
auth_mode="$(_run_as_floci_guest "grep '^FLOCI_AUTH_MODE=' /home/floci/floci-data/env.file 2>/dev/null | cut -d= -f2" || true)"
printf '   Auth mode:        %s\n' "${auth_mode:-unknown}"
```

Uses `_run_as_floci_guest` to read the env file from inside the guest. Falls back to `unknown` if the file is absent or unreadable (e.g. instance not running).

## Build verification

```bash
$ shellcheck setup-floci.sh
(exit 0, zero warnings)

$ shellcheck scripts/preflight-floci.sh
(exit 0, zero warnings)

$ shellcheck mock-server/dev-twin.sh
(exit 0, zero warnings)
```

All three files pass shellcheck cleanly.

## Self-reflection

**Why were these missed?**
- Fix 1: The `skip`/`fail` distinction is a semantic one — both print colored output. The difference in `FAILED` state is invisible without reading the function bodies. A reviewer scanning for "does this gate report failure?" would see the colored output and assume it works.
- Fix 2: Region literals are scattered across multiple files with no single source of truth. The `dev-twin.sh` already had `eu-west-2` but `setup-floci.sh` and `preflight-floci.sh` lagged.
- Fix 3: The auth mode was already a known gotcha in AGENTS.md ("FLOCI_AUTH_MODE cannot change without make dev-recreate") but the status command didn't surface it.

**What procedural safeguard would have caught them?**
- Fix 1: A T1 mechanical check that greps for `skip` in gate functions and flags any that should be `fail` (i.e. where the gate cannot proceed without the dependency).
- Fix 2: A single `REGION` constant shared across all scripts, or a T1 check that greps all region literals and flags mismatches.
- Fix 3: A "status command completeness" checklist — every status command must surface every configuration value that has a "cannot change without recreate" constraint.
