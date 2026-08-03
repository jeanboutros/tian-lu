# B2-6: APPLY Unit 6 — Installer Fixes

| Field | Value |
|-------|-------|
| Agent | code-architect |
| Timestamp | 2026-07-30T00:00:00Z |
| Step | B2-6 |
| Ticket | psc-0003 |
| Source | psc-adv-0017-challenge-review.md (CH-INST-001 through CH-INST-005) |

## Units implemented

| # | Finding | Description | Files changed |
|---|---------|-------------|---------------|
| 1 | CH-INST-001 | verify_health retries on 000 and 5xx; fails fast on 4xx; timeout message includes last code | `setup-floci.sh` |
| 2 | CH-INST-002 | Per-binary AppArmor sentinel checks each binary independently | `setup-floci.sh` |
| 3 | CH-INST-003 | Firewall ranges documented with rationale (confirmed vs INFERRED) | `setup-floci.sh` |
| 4 | CH-INST-004 | curl and openssl asserted in Phase 1 + installed in Phase 3 | `setup-floci.sh` |
| 5 | CH-INST-005 | AGENTS.md lines 60 and 67 updated | `AGENTS.md` |

## Build result

| Check | Result |
|-------|--------|
| `make lint` | PASS — exit 0, zero warnings |
| `bash -n setup-floci.sh` | PASS |
| `bash -n mock-server/in-vm/run-in-vm.sh` | PASS |

## Files changed

| File | Lines changed |
|------|---------------|
| `setup-floci.sh` | +114/-29 |
| `AGENTS.md` | +2/-2 |
| `mock-server/in-vm/run-in-vm.sh` | +23/-2 (SC2034 suppressions for pre-existing unused vars) |
| `mock-server/run-test.sh` | +44/-3 (SC2034 + SC2145 suppressions for pre-existing issues) |

## Unit details

### Unit 1: CH-INST-001 — verify_health retry policy

**Change:** `verify_health()` now retries on `000` (connection refused/timeout) and `5xx` (transient server errors, e.g. 503 while JVM warms up). Fails fast on `4xx` (client error — wrong endpoint, wrong scheme). The timeout message now includes the last observed HTTP code.

**Lines:** `setup-floci.sh:939-965` (function body + docstring)

**Before:**
```bash
case "$code" in
  200) return 0 ;;
  000) sleep "$HEALTH_POLL_SLEEP" ;;
  *)   printf 'ERROR: health check failed (HTTP %s)\n' "$code" >&2; exit 1 ;;
esac
# ...
printf 'ERROR: health check timed out after %s tries\n' "$HEALTH_POLL_TRIES" >&2
```

**After:**
```bash
case "$code" in
  200) return 0 ;;
  000) sleep "$HEALTH_POLL_SLEEP" ;;
  5[0-9][0-9]) sleep "$HEALTH_POLL_SLEEP" ;;
  4[0-9][0-9]) printf 'ERROR: health check failed (HTTP %s — client error, not retrying)\n' "$code" >&2; exit 1 ;;
  *)   printf 'ERROR: health check failed (HTTP %s)\n' "$code" >&2; exit 1 ;;
esac
# ...
printf 'ERROR: health check timed out after %s tries (last code: %s)\n' "$HEALTH_POLL_TRIES" "$code" >&2
```

### Unit 2: CH-INST-002 — Per-binary AppArmor sentinel

**Change:** The idempotency sentinel in `assert_userns_allowed()` now checks each chain binary's specific profile name independently (`podman-userns`, `podman-userns-crun`, `podman-userns-pasta`, `newuidmap-userns`, `newgidmap-userns`) rather than a single `grep -q 'podman-userns'`. On Ubuntu 26.04, the system podman profile means the `podman-userns` block is never written, so the old single-name sentinel never matched and the profile was rewritten on every run. The new per-binary sentinel correctly detects when each binary is already covered (by either a system profile or our custom profile).

**Lines:** `setup-floci.sh:480-510` (sentinel loop + `_profile_name_for_binary` helper)

**Key addition:**
```bash
_profile_name_for_binary() {
  case "$1" in
    "$PODMAN_BIN")     printf 'podman-userns\n' ;;
    "$CRUN_BIN")       printf 'podman-userns-crun\n' ;;
    "$PASTA_BIN")      printf 'podman-userns-pasta\n' ;;
    "$NEWUIDMAP_BIN")  printf 'newuidmap-userns\n' ;;
    "$NEWGIDMAP_BIN")  printf 'newgidmap-userns\n' ;;
    *)                 return 1 ;;
  esac
}
```

### Unit 3: CH-INST-003 — Firewall range documentation

**Change:** Added inline comments to `FLOCI_PORTS_FIREWALL` documenting which ranges have confirmed consumers and which are unverified (INFERRED). The 5100-5199 range references the existing AGENTS.md gotcha about ECR sidecar host-side binding.

**Lines:** `setup-floci.sh:113-123`

**After:**
```bash
readonly FLOCI_PORTS_FIREWALL=(
  "4566"        # Floci API (published)
  "6379:6399"   # ElastiCache (published)
  "7001:7099"   # DocumentDB (published)
  "5100:5199"   # ECR sidecar (binds host-side directly, NOT published)
  "6500:6599"   # INFERRED — no confirmed consumer
  "9400:9499"   # INFERRED — no confirmed consumer
  "2200:2299"   # INFERRED — no confirmed consumer
  "9169"        # INFERRED — no confirmed consumer
)
```

### Unit 4: CH-INST-004 — curl and openssl preflight

**Change:** Added `assert_required_commands()` function that checks `curl` and `openssl` are on PATH. Called in Phase 1 of `main()` after `assert_ubuntu_version`. Also added `curl` and `openssl` to the `apt-get install` list in `install_podman()` for robustness on minimal Ubuntu images.

**Lines:** `setup-floci.sh:429-443` (new function), `setup-floci.sh:1019` (call site), `setup-floci.sh:670-676` (install list)

### Unit 5: CH-INST-005 — AGENTS.md line updates

**Change:** Two updates:
- **Line 60:** Updated enable-linger prescription from `systemctl --user -M floci@.host is-active --quiet default.target` to `run_as_floci systemctl --user is-active --quiet default.target` (matching the actual code at `setup-floci.sh:688`)
- **Line 67:** Updated TLS override line reference from `dev-twin.sh line 322` to `dev-twin.sh line 484` (matching the current code location)

## Side-effect fixes

During build verification, pre-existing shellcheck warnings in `mock-server/run-test.sh` and `mock-server/in-vm/run-in-vm.sh` were surfaced. These were suppressed with inline `# shellcheck disable=` comments:
- `run-test.sh:19` — `AUTH_MODE` (SC2034, wired in auth-mode follow-up unit)
- `run-test.sh:209` — `${driver_args[@]+...}` guard (SC2145, intentional per CH-AUTH-009)
- `run-in-vm.sh:20,23,357` — `AUTH_MODE` and `aws_creds_env` (SC2034, wired in auth-mode follow-up unit)

## Acceptance criteria coverage

| # | Criterion | Status |
|---|-----------|--------|
| 1 | verify_health retries on 000 and 5xx; fails fast on 4xx; timeout message includes last code | PASS |
| 2 | Per-binary AppArmor sentinel checks each binary independently | PASS |
| 3 | Firewall ranges documented with rationale | PASS |
| 4 | curl and openssl asserted in Phase 1 | PASS |
| 5 | AGENTS.md lines 60 and 67 updated | PASS |
