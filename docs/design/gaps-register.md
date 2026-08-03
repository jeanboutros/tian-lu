# Gaps Register

Unresolved items that require runtime testing to close. All mitigated and resolved risks have been folded into `docs/design/solution-design.md` as descriptive design content.

---

## GAP-009 — `verify_health` endpoint response format [CLOSED — captured by twin]

The `/_floci/init` endpoint response format was undocumented. The Lima digital-twin harness captures the response body at runtime to `mock-server/evidence/<UTC-ts>/health-init.json` (capture-only, no assertion on content). The installer's `verify_health` continues to check HTTP 200 via a retry loop using `curl --resolve tianlu-floci:4566:127.0.0.1 -k`; the captured body is available for inspection if a richer readiness signal is later needed.

---

## GAP-013b — EKS/k3s workload network exposure [OPEN]

If a service is hosted on the emulated EKS (k3s) with an externally-facing interface:

- **k3s API (6500-6599):** Uses k3s's own self-signed CA, not Floci's. Whether the k3s admin token is randomized by Floci or uses a static default is unverified.
- **k3s workloads:** A `Service` of `type: LoadBalancer` or `NodePort` attempts to bind ports on the k3s container. Whether these are host-reachable depends on the k3s container's network mode — Floci runs sidecars on `floci-net` (bridged), which may mean NodePort/LoadBalancer are NOT directly host-reachable. This must be verified by testing.
- **Lateral movement:** A compromised k3s pod can reach other sidecars on `floci-net` (RDS, ElastiCache, ECR) even if it cannot break out of the rootless Podman namespace.
- **UFW default INPUT policy** is the primary control — any k3s workload port not in the allowlist is blocked automatically.

**Action:** Verify k3s network mode and token generation by testing on the server.

---

## GAP-014 — rootless Quadlet socket dependency and boot ordering [PARTIALLY CLOSED — twin; full reboot-health pending x86_64 server]

The Lima digital-twin harness proved the structural and ordering claims:
- `floci.container` declares `After=podman.socket` / `Requires=podman.socket` — verified via `systemctl --user show -p After -p Requires floci.service` (both contain `podman.socket`).
- `[Install] WantedBy=default.target` triggers boot autostart — verified: the reboot journal shows `podman.socket` Listening immediately followed by `floci.service` Starting at boot, confirming the ordering edge fires before the service.
- `systemctl --user start floci.service` (not `enable`) is the correct activation — confirmed (Quadlet units are transient and cannot be `enable`d).

The full reboot-health-200 proof (Floci serving HTTP 200 immediately after a cold reboot) did NOT complete in the Lima twin across multiple evidence runs:

- **2026-07-25** (mock-server/evidence/20260725T175605Z/ and earlier): old RestartSec=5/StartLimitBurst=5/StartLimitIntervalSec=60; service exhausted 5 retries in ~16-20s and latched.
- **2026-07-26 morning** (mock-server/evidence/20260726T140607Z/): first GAP-014 fix attempt used a quoted space-separated RestartSec="5 10 15 20 30" (rejected by systemd 259 with "Invalid argument"); service exhausted 8 retries in ~5s.
- **2026-07-26 afternoon** (mock-server/evidence/20260726T143056Z/): corrected systemd 254+ API fix (RestartSec=5 RestartSteps=5 RestartMaxDelaySec=30 with StartLimitBurst=8 StartLimitIntervalSec=180) produces geometric backoffs 5s/7s/10s/15s/21s/30s/30s/30s = ~150s cumulative; service exhausted 8 retries in ~150s on the Lima VM. Manual restart also failed, indicating the AppArmor race persists for at least 2-3 minutes on this specific VM.

The race root cause is apparmor.service's cached boot reload not loading the newuidmap/newgidmap helper profiles before the user service starts in the Lima nested VM (profiles are present on disk but the boot-path cache timing leaves them ineffective when floci.service first fires). This is a Lima nested-VM AppArmor boot-timing quirk, not an installer bug: on a bare-metal x86_64 server, apparmor.service loads all profiles before user services start. The harness wait_for_reboot_health includes a reset+restart fallback that has historically proven the Quadlet-generated service runs post-reboot once AppArmor has settled; in the 2026-07-26 environment the race window exceeded the fallback's REBOOT_HEALTH_BUDGET.

**Remaining action (x86_64 server):** confirm `floci.service` reaches HTTP 200 immediately after a cold reboot on the production server, where the AppArmor boot-timing race does not apply. If the `Requires=podman.socket` edge causes activation failures when the socket is briefly unavailable, evaluate downgrading to `Wants=`.

---

## GAP-015 — Floci presents a root principal, not a root credential [ACCEPTED]

Floci has no root *credential* (no email/password login), but it does present a root *principal*: a
12-digit AKID authenticates as `arn:aws:iam::<account>:root`, and a non-12-digit key that matches no
IAM user resolves to `FLOCI_DEFAULT_ACCOUNT_ID` (`000000000000`) root. Because a 12-digit AKID is the
only per-account identity Floci accepts (IAM-user keys resolve to the default account), **deployment
runs as account root**. This is an accepted limitation.

**Impact:**
- A permissions boundary cannot constrain root, so `platform-admin` and the boundary are authored for
  real-AWS fidelity but not exercised on Floci (Terraform runs as account root).
- The `floci-deployer` IAM user is seeded but unused for deployment; it is kept for a future Floci
  build that can authenticate a per-account IAM user.
- AWS Organizations, SCPs, and root-user MFA are not emulated — documented rather than enforced.

**Reference:** `authentication-plan.md` §3.

---

## GAP-016 — Missing domain skills for Terraform/IAM infrastructure work

**Severity:** HIGH (urgent — needed for Phase B of psc-0003)
**Status:** Open
**Identified:** 2026-07-30 (A3-SR gate check for psc-0003)

The Skill Recruiter identified 8 missing skills that would improve specialist velocity and correctness for the Terraform/IAM/infrastructure work in psc-0003:

| Priority | Missing Skill | Domain | Impact |
|----------|---------------|--------|--------|
| HIGH | terraform-iac | Terraform provider/backend patterns, HCL validation | 14 Terraform findings across SW and DO |
| MEDIUM | aws-iam-policy | IAM condition key evaluation, policy syntax | CH-LZ-001 three-statement policy |
| MEDIUM | apparmor | Profile management, idempotency sentinels | CH-INST-002 per-binary sentinel |
| MEDIUM | podman-quadlet | Rootless Podman + systemd Quadlet patterns | CH-INST-001/002, CH-DEV-005 |
| MEDIUM | lima-vm | Lima VM management, disk lifecycle | CH-DEV-003/004/005 |
| MEDIUM | floci-config | Floci emulator configuration, env vars | CH-AUTH-001/003/014 |
| LOW | credential-rotation | Credential lifecycle patterns | CH-AUTH-005/007 |
| LOW | bats-testing | Bats testing framework patterns | 30+ new test cases across 5 files |

**Recommendation:** Import the HIGH-priority `terraform-iac` skill before Phase B implementation begins. The MEDIUM skills can be imported opportunistically during Phase B. The LOW skills are nice-to-have.

**Related:** psc-0003 A3-SR, psc-adv-0017

---

## GAP-017 — Floci does not verify SigV4 signatures [OPEN — upstream]

Floci `1.5.33-compat` does not verify SigV4 signatures even with `FLOCI_AUTH_VALIDATE_SIGNATURES=true`
and `FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED=true`. A request signed with the wrong secret is accepted,
so IAM policy enforcement has no verified principal to evaluate. Reproduced in
[`docs/issues/floci-signature-validation-ignored.md`](../issues/floci-signature-validation-ignored.md).

**Impact:** IAM is the intended primary security boundary but is authored, not enforced, on this build.
The trusted-network firewall scope is the real control until the upstream fix lands.

**Action:** File the issue upstream (draft in `docs/issues/`); when a fixed Floci build is available,
re-run the repro and preflight G1 to confirm enforcement, then remove the "target state" caveats from
the design docs.

**Reference:** `authentication-plan.md` §2.

---

## GAP-018 — `floci` subuid range is 65536, not the installer's 262144 [OPEN]

`configure_subuid_subgid` skips allocation when `/etc/subuid` already contains a line for
the user. Ubuntu's `useradd` allocates a 65536 range at user-creation time, and
`create_floci_user` runs first, so the installer's 262144 range is never written on Ubuntu.
Observed on the dev twin:

```
floci-runner:100000:65536
floci:165536:65536
```

**Impact.** None for the current configuration: the Quadlet uses `UserNS=keep-id`, which
maps a single uid/gid pair and needs no headroom. A container started with `--userns=auto`
would draw disjoint slices from this range and exhaust it far sooner than the design
intends.

**Action.** Decide whether the installer should widen an existing range rather than accept
it. Widening `/etc/subuid` for a user with running containers changes their mappings, so
the check must compare the range size and only act when no rootless container is running.
Until then, treat 65536 as the effective range on Ubuntu.

---

## How to add a new gap

1. Add an entry with the next sequential GAP-NNN ID.
2. Set status to OPEN.
3. Describe the risk and the action needed to close it.
4. When closed, move the content into `docs/design/solution-design.md` as descriptive design text and remove the entry from this file.

---

## Lessons Learned

The following meta-corrections were identified during the psc-0003 challenge review
([`psc-adv-0017-challenge-review.md`](../project-management/advisories/psc-adv-0017-challenge-review.md)).
They are recorded here as standing rules to prevent recurrence.

### LL-001 — Verify causal mechanisms against primary sources before recording blockers

**Source:** CH-META-001 (psc-adv-0001 M-SW-001)

**What happened.** A finding claimed that a region mismatch (`eu-west-1` vs `eu-west-2`) would
break SigV4 signature validation because "AWS SigV4 signs the region into the signature." The
action (adopt `DEV_REGION`) was correct, but the causal claim was wrong: the region is part of
the request's own credential scope and the server derives it from the `Authorization` header.
Two clients signing for different regions each verify correctly and independently. The real
consequence is resource/ARN divergence — resources created against one region are not visible
to a client querying another.

**Why it matters.** A finding whose mechanism is wrong cannot be verified by a test derived
from it. The fix stopped at the auth plan's own literals, leaving five other region sites
untouched (CH-LZ-005), precisely because the stated mechanism pointed at signing rather than
at configuration coherence.

**Standing rule.** Before recording a finding as a blocker, verify the causal mechanism against
the primary source (datasheet, spec, or authoritative documentation). If the mechanism is
wrong, the severity may still be right, but the fix scope will be incomplete.

### LL-002 — IAM Condition absent-key evaluation is a recurring trap; never apply "A or B" alternatives as "A and B"

**Source:** CH-META-002 (psc-adv-0001 M-SW-002)

**What happened.** A recommendation offered two alternatives for an IAM policy condition:
"Rewrite resources to `["*"]` **or** use `StringNotEquals` condition." Both were applied.
AWS documents that inverted condition operators (`StringNotEquals`, `ArnNotLike`, etc.)
**match** a null value when the condition key is absent from the request context.
`iam:PermissionsBoundary` is absent from the request context for the denied actions
(`iam:DeleteRolePermissionsBoundary`, etc.), so the Deny now fires unconditionally on
`Resource = "*"` — the guardrail became a blanket deny.

**Why it matters.** Three compounding factors: (a) the recommendation offered two alternatives
joined by "or" without stating that combining them changes the semantics; (b) neither
alternative was checked against IAM's absent-key evaluation rules; (c) no test accompanied
the fix, and on Floci a permissions-boundary test may not even be possible — so the change
was unfalsifiable by construction.

**Standing rule.** Any IAM `Condition` on a service-specific key must state which actions
populate that key. Any Deny intended as a ceiling needs a negative test before it counts as
landed. When a recommendation offers "A or B" alternatives, applying both is a semantic
change that must be explicitly evaluated.

### LL-003 — Verify environment variable purpose against the authoritative source before propagating a finding

**Source:** CH-META-003 (psc-adv-0001 F-SW-001)

**What happened.** A finding claimed that `FLOCI_SERVICES_IAM_ENABLED` is "required for Floci
to enforce IAM signatures." The authoritative source (`docs/scraped/environment-variables.md:160`)
documents it as the IAM **service** on/off switch (default `true`), not the enforcement toggle.
Enforcement is `FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED` (`:161`), which the plan already set.
The remediation propagated the conflation into the mode matrix, a summary note, and a test
specification — setting `IAM_ENABLED=false` in `off` mode disables IAM entirely, which would
break preflight G1 and stage 10 if applied.

**Why it matters.** A misread variable purpose cascades: the mode matrix, the env-file
specification, the test cases, and the summary output all inherited the wrong semantics.
The fix required reversing a test case (SPEC-TX-006 case 3) and correcting documentation
in three places.

**Standing rule.** Before citing an environment variable's purpose in a finding, verify it
against the authoritative source (scraped docs, upstream README, or source code). If the
source describes a different purpose than the finding assumes, the finding's premise is
wrong and the remediation will propagate the error.