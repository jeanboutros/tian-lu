# A3-SR: Skill Recruiter — psc-0003

| Field | Value |
|-------|-------|
| Agent | skill-recruiter |
| Timestamp | 2026-07-30T00:00:00Z |
| Step | A3-SR |
| Phase | A — A-GATE |
| Ticket | psc-0003 |
| Trigger | gate_execution (A-GATE) |
| Verdict | **GAP FOUND** |

## Self-Audit Checklist

| Category | Checked? | Finding or PASS |
|----------|----------|-----------------|
| Build passes (exit 0, no warnings) | N/A | No code changes — gap detection only |
| Typed enums / vocabulary types | N/A | Not applicable to skill gap detection |
| Documentation on new public symbols | N/A | No new public symbols |
| Spec/datasheet fidelity | yes | All domain signals cross-referenced against A0 task definition and AGENTS.md skill registry |
| Module boundary | yes | Gap detection scoped to psc-0003 domain signals only |
| Reserved/padding fields handled | N/A | Not applicable |
| No magic numbers in doc examples | N/A | Not applicable |
| Buffer safety | N/A | Not applicable |
| AGENTS.md compliance | yes | PASS — all gaps flagged per flag-protocol; skill registry read from AGENTS.md |
| Conventional commit ready | N/A | No commits from this step |

---

## 1. Domain Skill Coverage Check (A-GATE)

### Domain Signals from A0 Task Definition

| Domain Signal | Required Skill Category | Available Skill | Status |
|---------------|------------------------|-----------------|--------|
| bash-scripting | Shell scripting standards, defensive patterns, testing | `bash-scripting` | **COVERED** |
| security | Auth, IAM, secrets, OWASP mapping, credential handling | `security-principles` | **COVERED** |
| infrastructure | Terraform, IaC, provider management, state backends | — | **GAP** |
| documentation | Doc standards, cross-document consistency, ADR format | `documentation-standards`, `cross-document-consistency` | **COVERED** |
| CI/CD | Pipeline design, GitHub Actions, preflight gates | `ci-cd-pipeline`, `github-actions` | **COVERED** |

### Domain Gap Detail

| Domain | Missing Skill | Evidence | Severity |
|--------|---------------|----------|----------|
| infrastructure | `terraform-iac` or `infrastructure-as-code` | A1-SW covers 9 LZ findings (CH-LZ-001/005/006/008/009/010/011/012/013) with Terraform-specific patterns: provider version constraints, `default_tags` merge order, `backend.hcl` configuration, `-backend-config` overrides, `data.aws_caller_identity` preconditions, IAM condition key evaluation. A1-DO covers 5 additional Terraform findings (CH-LZ-005/006/007/008/009/010/011). No Terraform/IaC skill exists in the registry. | **HIGH** |

---

## 2. Pattern Gap Detection (A1 + A2 Outputs)

### Patterns Detected Across All 6 Specialists

| # | Pattern | Evidence (Specialist + Finding) | Skill Gap | Severity |
|---|---------|-------------------------------|-----------|----------|
| 1 | **Terraform provider/backend patterns** | SW SPEC-SW-007/008/009/010/011/012, DO SPEC-DO-011/012/014/015/016/017 — provider version constraints, `backend.hcl` wiring, `-backend-config` overrides, `default_tags` merge order, `terraform validate`/`fmt -check`, `endpoints` maps, `force_path_style` deprecation | `terraform-iac` | **HIGH** |
| 2 | **AWS IAM policy condition key evaluation** | SW SPEC-SW-006, SX SPEC-SX-008/009 — `StringNotEquals` matching null values, `iam:PermissionsBoundary` presence/absence in request context, `EQUIVALENT_TO_NULL_FALSE`, three-statement boundary split, ABAC tag-match conditions | `aws-iam-policy` (partial — `security-principles` covers principles but not AWS-specific mechanics) | **MEDIUM** |
| 3 | **AppArmor profile management** | BS SPEC-BS-008, DO SPEC-DO-002 — `apparmor_parser -r`, per-binary sentinels, `aa-status`, `_system_profile_grants_userns`, `kernel.apparmor_restrict_unprivileged_userns`, profile attachment conflicts on Ubuntu 26.04 | `apparmor` | **MEDIUM** |
| 4 | **Rootless Podman + systemd Quadlet** | BS SPEC-BS-001/006/007/008/009/014/020 — Quadlet `.container` files, `UserNS=keep-id:uid=1001,gid=1001`, `WantedBy=default.target`, `ExecCondition`, systemd user services, `loginctl enable-linger`, `systemctl --user`, subuid/subgid range collision | `podman-quadlet` | **MEDIUM** |
| 5 | **Lima VM management** | BS SPEC-BS-010/011/012/013/014/015/016/017/018/019, DO SPEC-DO-005/006/007/008/009 — `limactl start/stop/delete/shell`, `limactl disk list/create`, 9p mounts, `--tty=false`, `2>/dev/null` stderr suppression, `floci-twin.yaml`/`floci-dev.yaml` templates | `lima-vm` | **MEDIUM** |
| 6 | **Floci (AWS emulator) configuration** | SW SPEC-SW-001/002/003/005, SX SPEC-SX-001/002/003/007 — `FLOCI_AUTH_MODE`, `FLOCI_AUTH_VALIDATE_SIGNATURES`, `FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED`, `FLOCI_SERVICES_IAM_ENABLED`, `FLOCI_AUTH_PRESIGN_SECRET`, `FLOCI_DEFAULT_ACCOUNT_ID`, 12-digit AKID multi-account resolution, SigV4 enforcement, presign-secret IAM bypass | `floci-config` | **MEDIUM** |
| 7 | **Credential rotation lifecycle** | SX SPEC-SX-005/006/007, BS SPEC-BS-002/003 — atomic credential file writes (`.tmp`+`chmod`+`mv -f`), `source`-vs-`parse` for credential files, rotation gating on auth mode, `|| delete_rc=$?` under `set -e`, credential lifecycle management (5 credential types) | `credential-rotation` (partial — `security-principles` covers secrets management but not rotation-specific patterns) | **LOW** |
| 8 | **Bats testing framework patterns** | TX SPEC-TX-100 through SPEC-TX-114 — `_run_fn` subshell pattern, `STUB_BIN` on PATH, stub infrastructure (`_stub` symlinks), `STUB_OUT_*`/`STUB_RC_*` control variables, per-subcommand stub control, `TEST_TMP` redirection, `export HOME="${TEST_TMP}"` pattern | `bats-testing` (partial — `bash-scripting` mentions BATS but lacks detailed stub/test patterns) | **LOW** |

---

## 3. Phase B Skill Loading Recommendations

Based on the gap analysis, the following skills should be loaded by agents entering Phase B:

### Skills Already Available (Load These)

| Skill | Loaded By | Rationale |
|-------|-----------|-----------|
| `bash-scripting` | BS, SW, DO, TX | All shell script work — installer, dev twin, test harness, preflight |
| `security-principles` | SX, SW, DO | IAM policy design, credential handling, OWASP mapping |
| `documentation-standards` | DX | Auth plan, landing-zone, solution-design, gaps-register updates |
| `cross-document-consistency` | DX | 10 cross-document consistency relationships traced in A1-DX |
| `ci-cd-pipeline` | DO | Preflight gates, twin test harness, CI workflow design |
| `github-actions` | DO | `.github/workflows/test.yml` and `opencode.yml` security hardening |
| `silent-failure` | BS, SW, SX | `set -e` error handling, `|| true` masking, `wait_driver` signal-kill misattribution |
| `reliability-scalability` | DO | Deployment safety, state locking, health check retry budgets |
| `observability` | DO, SX | Post-install security observability, health check diagnostics |
| `software-engineering-principles` | SW | SOLID assessment, module boundary analysis, Clean Architecture |
| `review-confidence` | All | Confidence scoring on all findings |
| `self-audit-checklist` | All | Self-audit before verdict issuance |
| `authoritative-reference` | All | Reference validation on all claims |
| `compliance-gate` | Supreme Leader | T3 + T-ARCH gate checks |
| `flag-protocol` | All | Structured flag format for gap findings |
| `post-rejection-correction` | All | Root-cause correction on CONDITIONAL PASS findings |

### Skills Missing (Gaps to Address)

| Gap | Recommended Action | Priority |
|-----|-------------------|----------|
| `terraform-iac` | Search GitHub topics `terraform`, `infrastructure-as-code` for agent skills covering provider version constraints, backend configuration, `default_tags` merge patterns, `terraform validate`/`fmt -check` | **HIGH** — 14 Terraform findings across SW and DO; Phase B implementers need Terraform-specific guidance |
| `aws-iam-policy` | Search for IAM policy design skills covering condition key evaluation, `StringNotEquals` null-matching, permissions boundaries, ABAC | **MEDIUM** — 3 IAM-specific findings (CH-LZ-001, CH-LZ-002, CH-LZ-011); `security-principles` covers principles but not AWS mechanics |
| `apparmor` | Search for AppArmor profile management skills covering `apparmor_parser`, per-binary profiles, `aa-status`, userns grants | **MEDIUM** — 1 finding (CH-INST-002) but high complexity (Ubuntu 26.04 system profile conflicts) |
| `podman-quadlet` | Search for rootless Podman + systemd Quadlet skills covering `.container` files, `UserNS`, `WantedBy`, `ExecCondition` | **MEDIUM** — Multiple BS findings reference Quadlet patterns; AGENTS.md has 15+ gotchas on this topic |
| `lima-vm` | Search for Lima VM management skills covering `limactl` lifecycle, disk management, 9p mounts | **MEDIUM** — 10+ BS/DO findings reference Lima patterns |
| `floci-config` | Consider synthesising from `docs/scraped/` — the scraped docs already exist; a skill would codify the env var surface, multi-account resolution, and SigV4 enforcement patterns | **MEDIUM** — 5 SW/SX findings reference Floci-specific configuration |
| `credential-rotation` | Consider synthesising from recurring patterns in A1-SX and A1-BS — atomic writes, parse-not-source, rotation gating, `|| delete_rc=$?` under `set -e` | **LOW** — `security-principles` covers the principles; rotation is a specific workflow |
| `bats-testing` | Consider synthesising from recurring patterns in A1-TX — `_run_fn`, stub infrastructure, `STUB_OUT_*`/`STUB_RC_*`, per-subcommand control | **LOW** — `bash-scripting` covers BATS basics; the stub patterns are project-specific |

---

## 4. Conversation Synthesis Check

### Recurring Pattern Detection

No recurring conversation patterns detected for psc-0003 at this gate. The A1 and A2 outputs are first-pass analyses of a single advisory (psc-adv-0017). The following patterns are candidates for future synthesis if they recur across multiple tickets:

| Pattern | Occurrences (This Ticket) | Threshold for Synthesis |
|---------|---------------------------|------------------------|
| `set -e` / `errexit` error-handling patterns (`\|\| delete_rc=$?`, `\|\| true` masking) | 4 (CH-AUTH-005, CH-AUTH-007, CH-INST-001, M-BS-004) | ≥3 across sessions — **candidate** if pattern recurs in future tickets |
| Atomic file write pattern (`.tmp` + `chmod` + `mv -f`) | 3 (CH-AUTH-007, `write_env_file`, `write_quadlet_unit`) | ≥3 across sessions — **candidate** if pattern recurs |
| IAM condition key absent-value matching | 2 (CH-LZ-001, CH-META-002) | ≥3 across sessions — monitor |
| AppArmor userns profile management on Ubuntu 26.04 | 2 (CH-INST-002, digital-twin-findings.md §9) | ≥3 across sessions — monitor |

---

## 5. Safety Scan

No external skill imports were requested at this gate. No safety scans were performed.

---

## 6. Verdict

**GAP FOUND** — 1 domain gap, 8 pattern gaps detected.

### Domain Gaps

| Domain | Missing Skill | Severity |
|--------|---------------|----------|
| infrastructure | `terraform-iac` | **HIGH** |

### Pattern Gaps

| # | Pattern | Missing Skill | Severity |
|---|---------|---------------|----------|
| 1 | Terraform provider/backend patterns | `terraform-iac` | **HIGH** |
| 2 | AWS IAM policy condition key evaluation | `aws-iam-policy` | **MEDIUM** |
| 3 | AppArmor profile management | `apparmor` | **MEDIUM** |
| 4 | Rootless Podman + systemd Quadlet | `podman-quadlet` | **MEDIUM** |
| 5 | Lima VM management | `lima-vm` | **MEDIUM** |
| 6 | Floci (AWS emulator) configuration | `floci-config` | **MEDIUM** |
| 7 | Credential rotation lifecycle | `credential-rotation` | **LOW** |
| 8 | Bats testing framework patterns | `bats-testing` | **LOW** |

### Flags Raised

```
FLAG: type=task, priority=high, blocking=no
Title: Missing terraform-iac skill for Phase B implementation
Body: 14 Terraform-specific findings across SW (CH-LZ-001/005/006/008/009/010/011/012/013) and DO (CH-LZ-005/006/007/008/009/010/011) require Terraform-specific guidance. No terraform-iac or infrastructure-as-code skill exists in the registry. Phase B implementers will need provider version constraint patterns, backend.hcl wiring, default_tags merge order, terraform validate/fmt -check, and IAM condition key evaluation guidance.
Recommended search: github topic:terraform agent-skills, github topic:infrastructure-as-code agent-skills
```

```
FLAG: type=task, priority=medium, blocking=no
Title: Five medium-severity pattern gaps for Phase B
Body: apparmor, podman-quadlet, lima-vm, floci-config, and aws-iam-policy skills are missing. These cover AppArmor profile management (CH-INST-002), rootless Podman Quadlet patterns (multiple BS findings), Lima VM lifecycle (10+ BS/DO findings), Floci env var surface (5 SW/SX findings), and AWS IAM condition key evaluation (3 findings). Phase B can proceed without these — the existing skills (bash-scripting, security-principles) provide partial coverage — but specialist velocity will be lower without domain-specific guidance.
Recommended search: agentskills.io, github topics for each domain
```

### Self-Reflection

1. **Why was the terraform-iac gap not detected earlier?** The project's AGENTS.md skill registry is comprehensive for the embedded/hardware domain (BLE, nRF24, ESP-IDF, C++) and the Python backend domain (FastAPI, PostgreSQL, Clean Architecture), but the infrastructure/IaC domain has no dedicated skill. The `ci-cd-pipeline` and `github-actions` skills cover the pipeline layer but not the Terraform provisioning layer. This gap existed before psc-0003 — it was simply not exercised until the landing-zone Terraform work reached the challenge-review stage.

2. **What procedural safeguard would have caught it?** A domain-coverage check at project initialization: when `infra/` was added as a secondary project, the skill registry should have been audited for Terraform/IaC coverage. The `skill-recruiter` agent should be dispatched at project-structure changes, not just at pipeline gates.

3. **Knowledge update:** Add to the `skill-recruiter` skill's gap detection protocol: "When a new project subdirectory is added (e.g., `infra/`), re-run the domain-coverage check against the skill registry. A new domain without a matching skill is a gap that should be flagged before any work begins in that domain."

---

## 7. Routing

Output to supreme-leader for A-GATE synthesis. The A-GATE can proceed to PASS — the gaps are advisory (no skill is strictly required for Phase B implementation; the existing skills provide partial coverage). The HIGH-severity `terraform-iac` gap should be addressed before Phase B Terraform work begins to avoid specialist velocity loss.

## 8. References

| Claim / Decision | Source | Verification |
|-----------------|--------|-------------|
| Domain signals: bash-scripting, security, infrastructure, documentation, CI/CD | A0-task-definition.md:27 | CITED — "Domain signals detected: [bash-scripting] [security] [infrastructure] [documentation] [CI/CD]" |
| Skill registry: 60+ skills loaded | AGENTS.md `<available_skills>` block | VERIFIED — full registry read |
| 14 Terraform findings across SW and DO | A1-SW (SPEC-SW-006 through SPEC-SW-014), A1-DO (SPEC-DO-011 through SPEC-DO-017) | VERIFIED — cross-referenced against A1 outputs |
| AppArmor profile management patterns | A1-BS SPEC-BS-008, A1-DO SPEC-DO-002 | VERIFIED — `assert_userns_allowed`, per-binary sentinels, Ubuntu 26.04 system profile conflicts |
| Rootless Podman Quadlet patterns | A1-BS SPEC-BS-001/006/007/008/009/014/020, AGENTS.md Critical gotchas | VERIFIED — 15+ gotchas on Quadlet, `UserNS`, `WantedBy`, `ExecCondition` |
| Lima VM management patterns | A1-BS SPEC-BS-010 through SPEC-BS-019, A1-DO SPEC-DO-005 through SPEC-DO-009 | VERIFIED — `limactl` lifecycle, disk management, 9p mounts |
| Floci env var surface | A1-SW SPEC-SW-001/002/003/005, A1-SX SPEC-SX-001/002/003/007, `docs/scraped/` | VERIFIED — `FLOCI_AUTH_MODE`, `FLOCI_AUTH_VALIDATE_SIGNATURES`, `FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED`, `FLOCI_SERVICES_IAM_ENABLED`, `FLOCI_AUTH_PRESIGN_SECRET`, `FLOCI_DEFAULT_ACCOUNT_ID` |
