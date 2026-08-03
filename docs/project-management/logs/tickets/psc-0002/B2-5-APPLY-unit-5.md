# B2-5: APPLY Unit 5 — psc-0002

| Field | Value |
|-------|-------|
| Agent | code-architect |
| Timestamp | 2026-07-30T15:20:00Z |
| Step | B2-5 |
| Unit | 5 — §6.6, §6.7 region + profile + masked output |
| Build result | PASS — bash -n on extracted dev_env and _print_next_steps functions; grep for eu-west-1 and floci-dev returns zero matches in code blocks |

## Changes

### §6.6 dev_env (SPEC-SW-001, SPEC-DX-006)
1. Replaced `eu-west-1` with `$DEV_REGION` in config profile printf and export lines (2 occurrences)
2. Replaced all `floci-dev` profile references with `tianlu-floci-dev` (5 occurrences: grep, printf config, sed, printf creds, export)
3. Updated the non-export message to reference `tianlu-floci-dev`

### §6.7 _print_next_steps (SPEC-SW-001, SPEC-DX-005, SPEC-DX-006)
1. Replaced `eu-west-1` with `$DEV_REGION` in manual rotation command
2. Replaced `AWS_PROFILE=floci-dev` with `AWS_PROFILE=tianlu-floci-dev`
3. Replaced fallback path: masked `floci`/`floci` literal, references docs instead (SPEC-DX-005)
   - Before: `printf '   floci/floci is in use...'` + literal `AWS_ACCESS_KEY_ID=floci AWS_SECRET_ACCESS_KEY=floci`
   - After: `printf '   credential is in use...'` + `See docs/design/authentication-plan.md §5.2 for rotation steps.`

### §9.3 Challenger findings
Updated historical reference from `AWS_PROFILE=floci-dev` to `AWS_PROFILE=tianlu-floci-dev`.

## Acceptance criteria

- [x] No `eu-west-1` literals remain in §6.6 or §6.7
- [x] No `floci-dev` profile references remain (all use `tianlu-floci-dev`)
- [x] §6.7 fallback path does not echo `floci`/`floci` literally
- [x] §6.7 fallback path references `docs/design/authentication-plan.md §5.2` for rotation steps
