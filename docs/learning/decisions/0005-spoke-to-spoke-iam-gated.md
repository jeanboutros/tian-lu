# ADR 0005: Spoke-to-spoke access is IAM-gated (TGW routing modeled, not enforced)

**Date:** 2026-07-28
**Status:** Accepted (Phase 2)
**Context source:** ../sessions/2026-07-28-centralized-eks-landing-zone-on-floci.md
**Related finding:** ../findings/0006-no-transit-gateway-or-vpc-peering.md

## Context
App-Alpha (a namespace in the shared cluster) must reach **App-Beta's** Postgres in a different
workload spoke — a spoke-to-spoke flow that, in real AWS, routes through the hub Transit Gateway and
is gated by security groups + IAM. App-Beta is "just a database": an RDS **PostgreSQL** with
[write-ahead logging](https://www.postgresql.org/docs/16/runtime-config-wal.html) (optionally
[logical replication](https://www.postgresql.org/docs/16/logical-replication.html)).

## Decision
- Record the Alpha↔Beta path in the hub's **`transit` route-intent locals** (documented L3 intent).
- **Enforce** what Floci honors:
  - a Kubernetes [NetworkPolicy](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
    allowing egress from the `app-alpha` namespace to Beta's DB endpoint; and
  - a **cross-app IAM grant**: `role-alpha` gets `rds-db:connect` on Beta's DB
    ([RDS IAM auth](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/UsingWithRDS.IAMDBAuth.html))
    plus the matching PostgreSQL `GRANT`.
- Because **AKID = environment** (ADR 0004), Alpha and Beta share the dev account → **no
  cross-account role chaining** is needed (contrast the real centralized-multi-account pattern).

## Floci-specific adjustments
- Connectivity is physically flat (`floci-net`), so the demo "works" at L3 regardless; the *lesson*
  is that the **enforced** controls are IAM + NetworkPolicy (Finding 0005), not the TGW/SG metadata.

## Consequences
- Removing either the IAM grant **or** the NetworkPolicy must break `/peer-db` — this is the
  falsifiable test (see verification in `infra/README.md`).

## Alternatives considered
- **Real TGW route + SG rules** — unimplemented / unenforced in Floci (Findings 0006, 0001).
- **Cross-account role chaining** — unnecessary here since AKID encodes environment, not function.
