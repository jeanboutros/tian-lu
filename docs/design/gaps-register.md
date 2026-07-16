# Gaps Register

Unresolved items that require runtime testing to close. All mitigated and resolved risks have been folded into `docs/design/solution-design.md` as descriptive design content.

---

## GAP-009 — `verify_health` endpoint response format undocumented [OPEN]

The `/_floci/init` endpoint is confirmed to exist in `docs/scraped/initialization-hooks.md` but the response format (JSON? status code? what field indicates "ready"?) is not documented.

**Current handling:** The script checks HTTP 200 from `/_floci/init` via a retry loop using `curl --resolve tianlu-floci:4566:127.0.0.1 -k`. In interactive mode, the user can observe the raw response at the phase 6 pause.

**Action:** Capture the actual response body at runtime (during the interactive pause) and document it. If the format is richer than a status code, update `verify_health` to parse it.

---

## GAP-013b — EKS/k3s workload network exposure [OPEN]

If a service is hosted on the emulated EKS (k3s) with an externally-facing interface:

- **k3s API (6500-6599):** Uses k3s's own self-signed CA, not Floci's. Whether the k3s admin token is randomized by Floci or uses a static default is unverified.
- **k3s workloads:** A `Service` of `type: LoadBalancer` or `NodePort` attempts to bind ports on the k3s container. Whether these are host-reachable depends on the k3s container's network mode — Floci runs sidecars on `floci-net` (bridged), which may mean NodePort/LoadBalancer are NOT directly host-reachable. This must be verified by testing.
- **Lateral movement:** A compromised k3s pod can reach other sidecars on `floci-net` (RDS, ElastiCache, ECR) even if it cannot break out of the rootless Podman namespace.
- **UFW default INPUT policy** is the primary control — any k3s workload port not in the allowlist is blocked automatically.

**Action:** Verify k3s network mode and token generation by testing on the server.

---

## How to add a new gap

1. Add an entry with the next sequential GAP-NNN ID.
2. Set status to OPEN.
3. Describe the risk and the action needed to close it.
4. When closed, move the content into `docs/design/solution-design.md` as descriptive design text and remove the entry from this file.