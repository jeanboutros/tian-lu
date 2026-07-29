# Finding 0003: NodePort / LoadBalancer host-reachability is unverified — use port-forward

**Date:** 2026-07-28
**Related ADR:** ../decisions/0003-centralized-eks-placement.md
**Related session:** ../sessions/2026-07-28-centralized-eks-landing-zone-on-floci.md

## AWS expectation
On real EKS, a `Service` of type `LoadBalancer` provisions an ELB with a reachable address, and
`NodePort` opens a port on every node — both are dependable ingress paths.

## Floci reality
Floci runs the k3s cluster as a container on the bridged `floci-net`; whether a `NodePort` or
`LoadBalancer` service is reachable from the host depends on the container's network mode and is
**unverified** — internal `GAP-013b` in [docs/design/gaps-register.md](../../design/gaps-register.md)
("Whether these are host-reachable … must be verified by testing"). The k3s **API server** *is*
exposed on a host port (6500–6599, [ports](https://floci.io/floci/configuration/ports/)).

## Impact on the platform
- "How to access the application" uses `kubectl port-forward` through the k3s API server — the
  reliable path — rather than NodePort/LoadBalancer.
- The `Makefile` `pf-alpha` target wraps this; if a later twin run proves NodePort works, we can add
  it as an alternative.
