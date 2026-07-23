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

The full reboot-health-200 proof (Floci serving HTTP 200 immediately after a cold reboot) did NOT complete in the Lima twin: `floci.service` boot-autostart exhausted `StartLimitBurst=5` because `newuidmap: write to uid_map failed: Operation not permitted` for the first ~25s of boot — a Lima nested-VM AppArmor boot-timing quirk (apparmor.service's cached boot reload does not load the `newuidmap`/`newgidmap` helper profiles before the user service starts, even though they are loaded shortly after and the same `podman run --userns=keep-id` command succeeds via `systemd-run --user` post-settle). This is a twin-fidelity limitation, not an installer bug; on a bare-metal x86_64 server apparmor.service loads all profiles before user services start. The harness `wait_for_reboot_health` includes a reset+restart fallback that proves the Quadlet-generated service runs post-reboot once AppArmor has settled.

**Remaining action (x86_64 server):** confirm `floci.service` reaches HTTP 200 immediately after a cold reboot on the production server, where the AppArmor boot-timing race does not apply. If the `Requires=podman.socket` edge causes activation failures when the socket is briefly unavailable, evaluate downgrading to `Wants=`.

---

## How to add a new gap

1. Add an entry with the next sequential GAP-NNN ID.
2. Set status to OPEN.
3. Describe the risk and the action needed to close it.
4. When closed, move the content into `docs/design/solution-design.md` as descriptive design text and remove the entry from this file.