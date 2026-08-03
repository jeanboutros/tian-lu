# ADR psc-adr-0004: Three-statement permissions boundary enforcement

## Status
Accepted

## Context

CH-LZ-001 identified that the `DenyAllExceptBoundary` IAM policy statement in `infra/live/10-management-iam/main.tf:49-69` is architecturally unsound. The statement uses `StringNotEquals` on `iam:PermissionsBoundary` to deny all actions except those where a permissions boundary is present. However:

1. **Null key matching**: For most IAM actions (e.g., `s3:GetObject`, `ec2:RunInstances`), the `iam:PermissionsBoundary` condition key is **absent** from the request context (not present, not null). `StringNotEquals` treats an absent key as "not equal to the value," so the condition evaluates to `true` and the deny applies — creating an **unconditional deny** for all actions that don't carry a permissions boundary in the request context.

2. **Invalid action**: The statement includes `iam:DeleteGroupPermissionsBoundary`, which is not a valid IAM API action (verified against AWS IAM API reference).

3. **EQUIVALENT_TO_NULL_FALSE**: AWS IAM Access Analyzer's `EQUIVALENT_TO_NULL_FALSE` check confirms that `StringNotEquals` on an absent key behaves as an unconditional deny.

The challenge advisory (A2-challenger-SX, A2-challenger-SW) and the SX primary both identified this. The architectural fix is to split the statement by whether the condition key exists in the request context for each action — three statements, each scoped to actions where the key's presence/absence is known.

The user ruled (A2c, D-3, A-33) to accept the challenger position: create SPEC-SW-015 for CH-LZ-002 with G6 gate, and implement the three-statement fix for CH-LZ-001.

## Decision

1. **Replace `DenyAllExceptBoundary` with three statements**, split by condition key presence in request context:

   **Statement 1 — Actions where `iam:PermissionsBoundary` is present in request context:**
   ```hcl
   {
     Sid    = "DenyIfNoBoundaryOnBoundaryActions"
     Effect = "Deny"
     Action = [
       "iam:CreateRole",
       "iam:CreateUser",
       "iam:PutRolePermissionsBoundary",
       "iam:PutUserPermissionsBoundary",
       "iam:DeleteRolePermissionsBoundary",
       "iam:DeleteUserPermissionsBoundary"
     ]
     Condition = {
       StringNotEquals = {
         "iam:PermissionsBoundary" = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/PlatformPermissionsBoundary"
       }
     }
   }
   ```

   **Statement 2 — Actions where `iam:PermissionsBoundary` is absent (most actions):**
   ```hcl
   {
     Sid    = "AllowNonBoundaryActions"
     Effect = "Allow"
     Action = [
       "s3:*",
       "ec2:*",
       "dynamodb:*",
       "lambda:*",
       "logs:*",
       "cloudwatch:*",
       "iam:Get*",
       "iam:List*",
       "iam:Simulate*",
       "sts:*"
     ]
     # No condition — these actions don't carry a permissions boundary
   }
   ```

   **Statement 3 — Explicit deny for boundary modification without boundary (defense in depth):**
   ```hcl
   {
     Sid    = "DenyBoundaryModificationWithoutBoundary"
     Effect = "Deny"
     Action = [
       "iam:PutRolePermissionsBoundary",
       "iam:PutUserPermissionsBoundary",
       "iam:DeleteRolePermissionsBoundary",
       "iam:DeleteUserPermissionsBoundary"
     ]
     Condition = {
       StringNotEquals = {
         "iam:PermissionsBoundary" = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/PlatformPermissionsBoundary"
       }
     }
   }
   ```

2. **Drop `iam:DeleteGroupPermissionsBoundary`** — not a valid IAM action.

3. **G6 gate (SPEC-SW-015 / CH-LZ-002)**: A negative test proving the boundary actually restricts permissions:
   - Create role with `PlatformPermissionsBoundary` → allow `s3:*`
   - Create role WITHOUT boundary → deny `s3:*` (assert denied)
   - This test is a prerequisite gate (G6) — no landing-zone deployment proceeds until G6 passes

4. **§1.1/§5.2/§12 qualification**: Landing-zone documentation sections claiming "Enforced" for permissions boundary must be qualified as "Specified — not yet verified" until G6 passes (per CH-AUTH-015 / A-13).

## Consequences

**Enables:**
- Permissions boundary enforcement that actually works — denies only the actions where the boundary is relevant
- Most AWS actions (S3, EC2, DynamoDB, etc.) remain allowed without a boundary, as intended
- G6 negative test provides empirical evidence the boundary evaluation functions
- Architecture is honest about what is verified vs. specified

**Trade-offs:**
- More complex policy (3 statements vs 1) but each is semantically correct
- Requires maintaining the action-to-condition-key mapping as AWS adds new actions
- G6 gate blocks deployment until the negative test passes — may reveal Floci doesn't evaluate boundaries at all (outcome (b) of CH-AUTH-001 probe)
- Documentation must carry "Specified — not yet verified" qualification until G6 passes

## References

- **Challenge finding**: CH-LZ-001 (A2-challenger-SX, A2-challenger-SW)
- **Disagreement**: D-3 (SPEC-SW-006 conflates CH-LZ-001 with CH-LZ-002) — resolved: challenger
- **Advisory**: M-2 (CH-LZ-002 has no standalone SPEC), M-8 (CH-LZ-007 missing from SW)
- **A2 synthesis**: A2-dual-model-challenge.md §4 Agreements A-33, §6.1 D-3, §6.2 M-2
- **A2c decision register**: A2c-decision-register.md §4 Implementation Impact (D-3, R-3)
- **AWS References**: 
  - IAM Condition Keys: https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_condition-keys.html
  - IAM Access Analyzer EQUIVALENT_TO_NULL_FALSE: https://docs.aws.amazon.com/IAM/latest/UserGuide/access-analyzer-policy-checks.html
- **User decision**: 2026-07-30, Supreme Leader ruling — "Resolved: Challenger" for D-3; "Accepted" for A-33