# COMMIT — psc-0003

## Commit Ready
- C4 decision: CLOSE (completed)
- CR-GATE: PASS
- CR3 Review Acceptance: Complete
- All gates passed
- All approvals issued

## Files Changed (19)
[List the 19 files from the ticket]

## Commit Message
```
feat: remediate 49 findings from challenge review psc-adv-0017

- Auth: posture derived unconditionally from FLOCI_AUTH_MODE (CH-AUTH-002)
- Auth: FLOCI_SERVICES_IAM_ENABLED=true in both branches (CH-AUTH-003)
- Auth: FLOCI_AUTH_MODE emitted to env file (CH-AUTH-013)
- Dev-twin: awk section-aware credential block rewrite (CH-AUTH-004)
- Dev-twin: delete_rc reachable under set -e (CH-AUTH-005)
- Dev-twin: atomic credential write + parse instead of source (CH-AUTH-007)
- Dev-twin: DEV_AUTH_MODE constant, rotation gated on mode (CH-AUTH-006, 011)
- Guest driver: array-based -e overrides (CH-AUTH-008)
- Test harness: wait_driver four-outcome dispatch (CH-AUTH-010)
- Test harness: launch_driver guard retained, [*]→[@] fix (CH-AUTH-009)
- Installer: verify_health 5xx retry (CH-INST-001)
- Installer: per-binary AppArmor sentinel (CH-INST-002)
- Installer: curl/openssl preflight (CH-INST-004)
- Dev-twin: dev_env on resume, dev_disk_exists return codes, DEV_DISK_MOUNT, health budget, main guard (CH-DEV-001-006)
- Test harness: precondition verdict, sidecar-delta, journal check removed, --fresh/--keep, HOST_HOME (CH-TWIN-001-007)
- IAM: three-statement permissions boundary policy (CH-LZ-001)
- Infra: governance tags restored, merge order reversed, environment validation (CH-LZ-008, 011)
- Infra: provider >= 6.56.0, backend key omitted, region unified to eu-west-2 (CH-LZ-005, 009, 010)
- Docs: auth plan §6.10a-d moved to appendix, presign threat model, lessons learned (CH-AUTH-012, 014-016)
- Docs: landing-zone G1 relabelled, §3 qualified, TF_VAR_secret_key documented (CH-LZ-003, 013)
- Preflight: G1/G3 skip→fail (false-negative security gate fixed)
- Tests: 22 new test cases across 4 files
- Remove root install.sh

Closes: psc-0003
```
