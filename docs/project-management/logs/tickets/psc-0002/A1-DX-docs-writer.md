# A1-DX: Docs Writer Requirements — psc-0002

| Field | Value |
|-------|-------|
| Agent | docs-writer |
| Timestamp | 2026-07-30T11:00:00Z |
| Step | A1-DX |
| Phase | A |
| Ticket | psc-0002 |
| Artifact reviewed | `docs/design/authentication-plan.md` (653 lines) |
| Cross-checked | `docs/design/solution-design.md`, `docs/design/landing-zone-design.md`, `docs/design/gaps-register.md`, `AGENTS.md`, `mock-server/dev-twin.sh` |

## Verdict

**CONDITIONAL PASS** — The auth plan is structurally sound and already incorporates most DX findings from the advisory review. Seven documentation specifications are required before Phase B implementation. No blocking issues.

---

## Documentation Specifications

### SPEC-DX-001: Gap entry GAP-015 — Floci's lack of root user concept

**Source:** F-DX-003 (accepted, confidence 85)
**File:** `docs/design/gaps-register.md`
**Location:** After GAP-014, before the "How to add a new gap" section.

**Content to add:**

```markdown
## GAP-015 — Floci has no root user concept [OPEN]

Floci has no root user — `FLOCI_DEFAULT_ACCOUNT_ID` (`000000000000`) is a fallback namespace identifier, not an authenticated principal. Any request with a non-12-digit AKID resolves to this account, but there is no "root login" with email+password credentials as in real AWS.

**Impact:**
- The `floci-deployer` IAM user (seeded by `FLOCI_SERVICES_IAM_SEED_DEPLOYER_PRINCIPAL=true`) serves as the de-facto root-equivalent for bootstrap. It has unbounded `AdministratorAccess` and well-known `floci`/`floci` credentials.
- There is no mechanism to recover from a lost or deleted `floci-deployer` credential short of wiping Floci state (`dev-reset` or deleting the persistent data directory).
- AWS Organizations, SCPs, and root-user MFA are not emulated — organization-level guardrails are documented rather than enforced.

**Mitigation:** Rotate `floci-deployer` credentials immediately after first boot (see `authentication-plan.md` §5). Create a bounded `platform-admin` via landing-zone stage 10 for ongoing operations. Do not use `floci-deployer` for anything beyond bootstrap.

**Reference:** `authentication-plan.md` §3.2, `landing-zone-design.md` §5.1.
```

---

### SPEC-DX-002: IAM identity lifecycle note in solution-design.md

**Source:** F-DX-004 (accepted, confidence 80)
**File:** `docs/design/solution-design.md`
**Location:** Replace the current §8 (Authentication) with an expanded section that cross-references the auth plan.

**Current state:** `solution-design.md` §8 is 5 lines — it only mentions `FLOCI_AUTH_VALIDATE_SIGNATURES` defaulting to `false` and the presign secret. It does not mention `FLOCI_AUTH_MODE`, the IAM hierarchy, or the auth plan.

**Content to add (replace §8 entirely):**

```markdown
## 8. Authentication

Authentication is controlled by a single `FLOCI_AUTH_MODE` parameter with two valid values:

| Mode | Signatures | IAM Enforcement | Deployer Seeded | Use Case |
|------|-----------|-----------------|-----------------|----------|
| `sigv4` (default) | `true` | `true` | `true` | Production — SigV4 verification + IAM policy enforcement |
| `off` | `false` | `false` | `false` | Trusted-LAN dev — no authentication |

The `FLOCI_AUTH_MODE` parameter collapses three independent Floci toggles into two coherent states, preventing the dangerous `signatures=on, enforcement=off` combination (crypto theater — looks secure, authorizes everyone). See [`authentication-plan.md`](authentication-plan.md) §4 for the full design rationale.

### 8.1 IAM identity lifecycle

The IAM hierarchy has three layers:

| Layer | Identity | Lifecycle |
|-------|----------|-----------|
| Root-equivalent | `FLOCI_DEFAULT_ACCOUNT_ID` (`000000000000`) | Permanent — namespace only, not an authenticated principal |
| Bootstrap admin | `floci-deployer` IAM user | Created at first boot with `floci`/`floci` credentials; rotated immediately. Superseded after landing-zone stage 10. |
| Platform admin | `platform-admin` IAM user/group/role | Created by Terraform stage `10-management-iam`. Bounded by a permissions boundary. Used for ongoing operations. |

```
floci-deployer (bootstrap, floci/floci → rotated)
  │
  │  terraform apply (stage 10-management-iam)
  │  using floci-deployer credentials
  ▼
platform-admin (bounded by permissions boundary)
  │
  │  ongoing operations
  ▼
application roles (one per app, bounded by boundary + least-privilege policy)
```

`floci-deployer` is **bootstrap-only**. After the landing-zone Terraform creates `platform-admin`, the deployer credentials should be rotated out and the platform-admin used for ongoing operations. See [`authentication-plan.md`](authentication-plan.md) §3 and [`landing-zone-design.md`](landing-zone-design.md) §5.1.

### 8.2 Presign secret

The script generates a random `FLOCI_AUTH_PRESIGN_SECRET` via `openssl rand -hex 32` and persists it. It is not regenerated on subsequent runs (that would invalidate existing pre-signed URLs).

### 8.3 Multi-account isolation

Multi-account isolation is automatic via 12-digit numeric access key IDs — there is no config flag to enable it. When the AKID is exactly 12 digits, it is used as the account ID. Otherwise, `FLOCI_DEFAULT_ACCOUNT_ID` (`000000000000`) is the fallback.
```

---

### SPEC-DX-003: Fix dev_env idempotency — sed replace-then-write pattern

**Source:** F-DX-014 (accepted, confidence 85)
**File:** `docs/design/authentication-plan.md` §6.6
**Status:** **Already specified correctly.** The auth plan §6.6 (lines 406-410) already uses the correct pattern:

```bash
sed -i.bak '/^\[floci-dev\]/,/^\[/d' "$creds_file" && rm -f "${creds_file}.bak"
printf '\n[floci-dev]\naws_access_key_id = %s\naws_secret_access_key = %s\n' "$ak" "$sk" >> "$creds_file"
```

This replaces existing `[floci-dev]` blocks (handling stale creds from a previous mode) rather than the current `dev-twin.sh:768` pattern which only appends if missing. **No change needed in the auth plan.** The implementation gap is in `dev-twin.sh` (not yet implemented per the auth plan).

**Note:** The profile name `floci-dev` in this section will be updated to `tianlu-floci-dev` per SPEC-DX-006.

---

### SPEC-DX-004: Document resume-path behavior — FLOCI_AUTH_MODE cannot change without dev-recreate

**Source:** M-DX-004 (accepted, confidence 80)
**Files affected:** `docs/design/authentication-plan.md` §4.3, `AGENTS.md` Critical gotchas

**Content to add to auth plan §4.3 (after the defaults table):**

```markdown
### 4.4 Changing `FLOCI_AUTH_MODE` on an existing VM

`make dev-up` does **not** re-invoke the installer on an existing VM — it only starts the VM and verifies Floci health. The `FLOCI_AUTH_MODE` is written to the Floci env file during `_install_absent` and is not re-evaluated on resume. To change `FLOCI_AUTH_MODE` on an existing dev twin:

1. Run `make dev-recreate` — this rebuilds the OS from the current checkout while retaining the `floci-dev-data` data disk, re-running the installer with the new `FLOCI_AUTH_MODE`.
2. Alternatively, run `make dev-reset` to wipe all state and start fresh.

Changing `FLOCI_AUTH_MODE` without `dev-recreate` has no effect — the env file retains the value from the original install.
```

**Content to add to AGENTS.md Critical gotchas (after the existing `make dev-up` entry at line 38):**

```markdown
- **`FLOCI_AUTH_MODE` cannot change without `make dev-recreate`.** `make dev-up` does not re-invoke the installer, so the `FLOCI_AUTH_MODE` value written during the original install persists. To switch between `sigv4` and `off`, use `make dev-recreate` (retains data disk) or `make dev-reset` (wipes all state).
```

---

### SPEC-DX-005: Masked output — show file location instead of echoing secret

**Source:** M-DX-003 (accepted, confidence 85)
**File:** `docs/design/authentication-plan.md` §6.3, §6.7

**Change in §6.3 `print_summary` (lines 266-270):**

Replace:
```bash
  echo "      Bootstrap admin: floci-deployer (AKID=floci, secret=floci)."
  echo "      Create a bounded platform-admin via landing-zone stage 10 for"
  echo "      ongoing operations; rotate the deployer credentials after."
```

With:
```bash
  echo "      Bootstrap admin: floci-deployer (well-known public credential)."
  echo "      The credential is documented in the Floci public docs — rotate it"
  echo "      immediately. See dev-twin _print_next_steps for rotation instructions."
  echo "      Create a bounded platform-admin via landing-zone stage 10 for"
  echo "      ongoing operations; rotate the deployer credentials after."
```

**Change in §6.7 `_print_next_steps` fallback path (lines 452-459):**

Replace:
```bash
      printf '   WARNING: rotation failed — the well-known public credential\n'
      printf '   floci/floci is in use with full AdministratorAccess. Rotate\n'
      printf '   manually as soon as possible:\n'
      printf '\n'
      printf '      AWS_ACCESS_KEY_ID=floci AWS_SECRET_ACCESS_KEY=floci \\\n'
      printf '        aws --endpoint-url http://localhost:4566 \\\n'
      printf '        iam create-access-key --user-name floci-deployer\n'
      printf '      # ... then delete the floci/floci key and update ~/.aws/credentials\n'
```

With:
```bash
      printf '   WARNING: rotation failed — the well-known public bootstrap\n'
      printf '   credential is in use with full AdministratorAccess. Rotate\n'
      printf '   manually as soon as possible. The credential values are\n'
      printf '   documented in the Floci public docs (floci-deployer user).\n'
      printf '   See docs/design/authentication-plan.md §5.2 for rotation steps.\n'
```

**Rationale:** The literal `floci`/`floci` values are public knowledge (documented in Floci's own docs), but echoing them to stdout on every `dev-up`/`dev-env` normalizes secret-in-stdout as a pattern. The masked output shows the file location and references the docs instead.

---

### SPEC-DX-006: Namespace dev-env AWS profile — use `tianlu-floci-dev` instead of `floci-dev`

**Source:** F-DXS-005 (accepted, confidence 80)
**File:** `docs/design/authentication-plan.md` §6.6, §6.7

**Change all occurrences of `floci-dev` as an AWS profile name to `tianlu-floci-dev`:**

In §6.6 `dev_env`:
- `grep -q '\[profile floci-dev\]'` → `grep -q '\[profile tianlu-floci-dev\]'`
- `printf '\n[profile floci-dev]\nregion = eu-west-1\n...'` → `printf '\n[profile tianlu-floci-dev]\nregion = eu-west-1\n...'`
- `sed -i.bak '/^\[floci-dev\]/,/^\[/d'` → `sed -i.bak '/^\[tianlu-floci-dev\]/,/^\[/d'`
- `printf '\n[floci-dev]\naws_access_key_id = ...'` → `printf '\n[tianlu-floci-dev]\naws_access_key_id = ...'`
- `export AWS_PROFILE=floci-dev` → `export AWS_PROFILE=tianlu-floci-dev`
- All printf messages referencing `floci-dev` → `tianlu-floci-dev`

In §6.7 `_print_next_steps`:
- `AWS_PROFILE=floci-dev` → `AWS_PROFILE=tianlu-floci-dev`

**Rationale:** The `floci-dev` profile name is generic and could collide with a real AWS profile on a developer's machine. The `tianlu-` prefix namespaces it to this project, following the same convention as `tianlu-floci` (container name) and `tianlu-twin` (cache directory).

---

### SPEC-DX-007: Document dev-twin-only ExecCondition Quadlet override in AGENTS.md Critical gotchas

**Source:** F-DXS-012 (accepted, confidence 80)
**File:** `AGENTS.md` — Critical gotchas section

**Content to add (after the existing `make dev-up` entry at line 38, before the Podman container name entry):**

```markdown
- **The dev twin installs an `ExecCondition` Quadlet override that does NOT exist in production.** `dev-twin.sh:_install_exec_condition` (lines 442-451) writes `/home/floci/.config/systemd/user/floci.service.d/mount-condition.conf` with `ExecCondition=/bin/bash -c 'findmnt -no FSTYPE,SOURCE /mnt/lima-floci-dev-data ...'`. This checks that the `floci-dev-data` disk is mounted before starting the Floci service. The production installer (`setup-floci.sh`) does NOT create this override — `/mnt/lima-floci-dev-data` only exists in the Lima dev VM. Copying the dev Quadlet or service configuration to a production server would cause the service to fail to start (ExecCondition fails, no such mount point). The override is dev-twin-specific infrastructure, not part of the Floci configuration.
```

---

## Cross-Document Consistency Report

### DC-1: ADR Cross-Reference
**N/A** — No ADRs exist for psc-0002 yet. ADRs will be created in step A2a.

### DC-2: Schema Consistency
**PASS** — The IAM identity hierarchy is consistent across documents:

| Identity | `authentication-plan.md` | `solution-design.md` (proposed) | `landing-zone-design.md` |
|----------|--------------------------|--------------------------------|--------------------------|
| `floci-deployer` | §3.1 — bootstrap admin, `floci`/`floci`, rotated immediately | §8.1 — same | §5.1 — referenced as bootstrap credential source |
| `platform-admin` | §3.3 — bounded delegated admin, created by stage 10 | §8.1 — same | §5.1 — assumable admin identity, permissions boundary conditioned |
| `FLOCI_DEFAULT_ACCOUNT_ID` | §3.2 — namespace, not authenticated principal | §8.1 — same | §4.1 — account namespace |

No contradictions found.

### DC-3: Decision-to-Document Trace
**PASS** — The auth plan's key decisions are traceable:

| Decision | Auth Plan § | Cross-Referenced In |
|----------|------------|---------------------|
| Single `FLOCI_AUTH_MODE` parameter | §4 | `solution-design.md` §8 (proposed) |
| `floci-deployer` bootstrap-only | §3.3 | `solution-design.md` §8.1 (proposed), `landing-zone-design.md` §5.1 |
| Credential rotation after first boot | §5 | `solution-design.md` §8.1 (proposed) |
| Floci's lack of root user | §3.2 | `gaps-register.md` GAP-015 (proposed) |

### DC-4: SQL-vs-Decision Validation
**N/A** — No SQL schemas are involved in the auth plan.

---

## Structural Changes to the Auth Plan

### 1. Status banner (required)

The auth plan should clearly indicate it is a **specification, not yet implemented**. Add at the top of the document, after the title line:

```markdown
> **Status:** Specification — not yet implemented. This document describes the complete design for
> Floci authentication (SigV4, IAM enforcement, credential rotation). The code changes in §6 are
> implementation specifications for Phase B. See psc-0002 for the implementation ticket.
```

### 2. AGENTS.md — list the auth plan under Key files

The auth plan is not listed in AGENTS.md's Key files section. Add after the `landing-zone-design.md` entry (line 13):

```markdown
  - `authentication-plan.md` — Floci SigV4 authentication, IAM enforcement, credential rotation, and `FLOCI_AUTH_MODE` design. Implementation specification for psc-0002.
```

### 3. solution-design.md §8 — cross-reference the auth plan

Already covered by SPEC-DX-002 above. The current §8 is 5 lines and does not mention the auth plan, `FLOCI_AUTH_MODE`, or the IAM hierarchy. The replacement in SPEC-DX-002 adds a full cross-reference.

### 4. No other structural changes needed

The auth plan's organization (§1 Overview → §2 Problem → §3 IAM hierarchy → §4 FLOCI_AUTH_MODE → §5 Credential rotation → §6 Code changes → §7 Test twin → §8 Security → §9 Challenger findings → §10 Out of scope) is logical and complete. The seven specifications above are additive, not restructuring.

---

## Self-Audit Checklist

| Category | Checked? | Finding or PASS |
|----------|----------|-----------------|
| Build passes | N/A | No code changes in this step — documentation specification only |
| Typed vocabulary | N/A | No code changes |
| Documentation on new public symbols | N/A | No code changes |
| Spec/datasheet fidelity | N/A | No hardware specs involved |
| Module boundary | N/A | No code changes |
| Reserved/padding fields handled | N/A | No code changes |
| No magic numbers in doc examples | PASS | All proposed doc content uses named references, not raw values |
| Buffer safety | N/A | No code changes |
| AGENTS.md compliance | PASS | All proposed changes follow AGENTS.md conventions (Critical gotchas format, Key files listing) |
| Conventional commit ready | N/A | Documentation specification — no commit yet |

---

## References

| Claim / Decision | Source | Verification |
|-----------------|--------|-------------|
| Auth plan §3.2 describes Floci's lack of root user | `authentication-plan.md:67-76` | Verified — text explicitly states "Floci has no root user concept" |
| Auth plan §6.6 already specifies sed replace-then-write | `authentication-plan.md:406-410` | Verified — `sed -i.bak` delete + `printf` append pattern present |
| Current dev-twin.sh uses append-if-missing only | `dev-twin.sh:768-769` | Verified — `if ! grep -q` guard, no replace logic |
| AGENTS.md line 38 documents dev-up resume behavior | `AGENTS.md:38` | Verified — "does NOT rerun the installer on an existing VM" |
| AGENTS.md does NOT mention ExecCondition override | `AGENTS.md:36-65` (full Critical gotchas) | Verified — grep for `ExecCondition` returns zero matches |
| AGENTS.md does NOT list authentication-plan.md | `AGENTS.md:9-34` (Key files) | Verified — grep for `authentication-plan` returns zero matches |
| solution-design.md §8 is 5 lines, no auth plan reference | `solution-design.md:128-132` | Verified — only mentions `FLOCI_AUTH_VALIDATE_SIGNATURES` and presign secret |
| gaps-register.md ends at GAP-014 | `gaps-register.md:43` | Verified — last entry is GAP-014, no GAP-015 |
| landing-zone-design.md §5.1 describes platform-admin consistently | `landing-zone-design.md:208-216` | Verified — "assumable administrative identity" with permissions boundary condition |
| Auth plan §6.6 uses `floci-dev` profile name | `authentication-plan.md:393,409,413,415` | Verified — all occurrences use `floci-dev` |
| Auth plan §6.3 echoes secret to stdout | `authentication-plan.md:268` | Verified — `"Bootstrap admin: floci-deployer (AKID=floci, secret=floci)."` |
| Auth plan §6.7 fallback echoes secret to stdout | `authentication-plan.md:453` | Verified — `printf '   floci/floci is in use...'` |
