# ADR psc-adr-0001: Per-environment account selection via FLOCI_DEFAULT_ACCOUNT_ID

## Status
Accepted

## Context

CH-AUTH-001 identified a fundamental architectural defect in the landing-zone authentication model. The original design derived the AWS account axis from the deployer's access key ID (AKID), meaning the same Terraform code would apply to different accounts based solely on which credentials were used to deploy it. This created several critical defects:

1. **Promotion model collapse** (CH-LZ-009/010 implications): The landing-zone §4.2 promotion model ("copy tfvars, change AKID, same code applies") is architecturally false when the account axis is derived from AKID. Promotion now requires a new Floci instance per environment, not just a tfvars change.

2. **Three-outcome probe is a keystone gate** (D-2, D-13): The CH-AUTH-001 three-outcome probe (outcome a: sigv4 validates; b: sigv4 fails but off mode works; c: both fail) is a keystone verification whose outcome determines whether multiple SPECs are meaningful. Outcome (b) means the estate's headline security claim ("sigv4 enforcement works") is false. This must be a Phase B entry gate, not a deferrable acceptance criterion (SPEC-SW-001 acceptance criterion #6).

3. **Severity 10 keystone gate** (D-13): SX SPEC-SX-001 severity was raised from 9 to 10 (Critical) because it is the foundational defect making every other IAM-related finding conditional. Severity 9 implies "fix alongside others"; severity 10 implies "resolve this first, then reassess the rest."

The user ruled (A2c, D-2, D-13, A-1) to resolve this by:
- Moving the account axis from AKID to a per-instance `FLOCI_DEFAULT_ACCOUNT_ID` installer configuration
- Changing `_common/providers.tf` `access_key` to the deployer's real AKID (not a placeholder)
- Adding a `data.aws_caller_identity` precondition to verify the deployer's identity
- Updating landing-zone §4.1/§4.2 to reflect the new model
- Making the three-outcome probe a Phase B entry gate (G0) — no implementation SPEC proceeds until the probe result is known and recorded in the gaps register

## Decision

1. **Account axis moves from AKID to installer config**: The account axis is now explicitly configured per Floci instance via `FLOCI_DEFAULT_ACCOUNT_ID` in the installer configuration, not derived from the deployer's AKID.

2. **Provider access_key uses deployer's real AKID**: `_common/providers.tf` uses the deployer's actual access key ID, not a placeholder. This makes the provider configuration explicit and auditable.

3. **Three-outcome probe as Phase B entry gate (G0)**: The CH-AUTH-001 three-outcome probe is a prerequisite gate that must execute and record its outcome (a/b/c) before any implementation SPEC proceeds. Execution routed to DO/BS, interpretation to SX. Outcome recorded in gaps register.

4. **Landing-zone documentation updated**: §4.1 and §4.2 are updated to reflect that promotion now requires a new Floci instance per environment, not just a tfvars change. The "promotion model collapse" (M-10) is documented as an architectural change, not just a documentation update.

5. **Landing-zone §1.1/§5.2/§12 qualified until probe passes**: These sections are marked "Specified — not yet verified" (A-13) until the probe outcome is known.

## Consequences

**Enables:**
- Explicit, auditable account selection per Floci instance
- The three-outcome probe becomes a meaningful gate: outcome (a) validates the security model; outcome (b) invalidates the headline security claim and triggers architectural reassessment; outcome (c) blocks deployment entirely
- Landing-zone promotion model is honest about requiring per-environment Floci instances
- IAM boundary evaluation (CH-LZ-002, SPEC-SW-015, G6 gate) can be meaningfully tested against a known account

**Trade-offs:**
- Promotion workflow changes from "copy tfvars, change AKID" to "provision new Floci instance with correct FLOCI_DEFAULT_ACCOUNT_ID"
- Deployer must have a real AKID configured in `_common/providers.tf` (not a placeholder)
- The three-outcome probe becomes a blocking prerequisite for all Phase B implementation work
- If probe outcome is (b), the entire IAM enforcement architecture must be reassessed

## References

- **Challenge finding**: CH-AUTH-001 (A2-challenger-SX, A2-challenger-SW, A2-challenger-TX, A2-challenger-DX)
- **Disagreement**: D-2 (SPEC-SW-001 under-weights three-outcome probe as Phase B gate) — resolved: challenger
- **Disagreement**: D-13 (SPEC-SX-001 severity should be 10, not 9) — resolved: challenger
- **A2 synthesis**: A2-dual-model-challenge.md §4 Agreements A-1, §6.1 D-2/D-13, §6.2 M-12
- **A2c decision register**: A2c-decision-register.md §4 Implementation Impact (D-2, D-13, R-2, R-11)
- **User decision**: 2026-07-30, Supreme Leader ruling — "Resolved: Challenger" for D-2 and D-13; "Accepted" for M-12