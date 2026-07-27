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

## How to add a new gap

1. Add an entry with the next sequential GAP-NNN ID.
2. Set status to OPEN.
3. Describe the risk and the action needed to close it.
4. When closed, move the content into `docs/design/solution-design.md` as descriptive design text and remove the entry from this file.