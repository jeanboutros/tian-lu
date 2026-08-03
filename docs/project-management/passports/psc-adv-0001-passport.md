# Pipeline Passport: psc-adv-0001

## Task Identity

| Field | Value |
|-------|-------|
| Ticket | psc-adv-0001 |
| Title | Comprehensive advisory review of 5 artifacts: auth-plan, setup-floci.sh, dev-twin.sh, run-test.sh, landing-zone-design.md |
| Created | 2026-07-29 |
| PM | pm |

## Required Steps

Every step the pipeline requires for this task. Steps are checked off sequentially. No step may be skipped without a written justification in the Skipped Steps section below.

### Phase A — Requirements & Design

- [ ] A0: Task Definition — acceptance criteria, files, constraints, test strategy, doc plan. **Domain classification:** bash-scripting, security, infrastructure, documentation | **Roster:** SW, TX, DX, SX, BS, DXS
- [ ] A1: Specialist Review — all dispatched specialists review independently
  - [ ] A1-SW: Software Engineer
  - [ ] A1-TX: Test Engineer
  - [ ] A1-DX: Docs Writer
  - [ ] A1-SX: Security Reviewer
  - [ ] A1-BS: Bash Specialist
  - [ ] A1-DXS: DevOps Specialist
- [ ] A2: Dual-Model Challenge — primary pass + challenger pass
- [ ] A2b: Synthesis Artifact Creation — PM creates individual files in advisories/
- [ ] A2c: Decision Register Presentation — Supreme Leader presents findings to user, user rules on each
- [ ] A2a: ADR Creation — ADR file for every resolved design decision (if any decisions from review)
- [ ] A3: A-GATE — T3 ✅/❌ | T-ARCH ✅/❌ | ADRs present ✅/❌ | Artifacts created ✅/❌ | User decisions recorded ✅/❌ | Verdict: _______

### Phase C — Multi-Agent Verify (A-only path: C4 only)

- [ ] C4: PM Completion Review — Decision: CLOSE / CLOSE+NEW / BLOCK / RE-DISPATCH / CANCEL / ARCHIVE | Closure type: advisory

### Commit (Log Only)

- [ ] COMMIT — C4 decision CLOSE, advisory logged to advisories/

## Post-Completion Decision

After C4, the PM records the final decision here:

| Field | Value |
|-------|-------|
| Decision | (pending C4) |
| Closure type | advisory |
| Rationale | |
| New tickets spawned | |
| Replacement ticket | |
| Delta analysis ticket | |

## Step Log

Every step execution is logged here with timestamp, agent, and result.

| Step | Agent | Timestamp | Result | Notes |
|------|-------|-----------|--------|-------|
| A0 | code-architect | | | |
| A1-SW | software-engineer | | | |
| A1-TX | test-engineer | | | |
| A1-DX | docs-writer | | | |
| A1-SX | security-reviewer | | | |
| A1-BS | bash-specialist | | | |
| A1-DXS | devops-specialist | | | |
| A2-Primary | | | | |
| A2-Challenger | | | | |
| A2b-Artifacts | pm | | | |
| A2c-Decision-Register | supreme-leader | | | |
| A2a-ADR | | | | |
| A3-Gate | supreme-leader | | PASS/FAIL | T3: __ T-ARCH: __ ADRs: __ |
| C4 | pm | | | |

## Gate Results

| Gate | Tier | Attempt | Result | Retry Budget | Notes |
|------|------|---------|--------|---------------|-------|
| A-GATE | T3 | 1 | | 0/3 | |
| A-GATE | T-ARCH | 1 | | 0/3 | |

## Skipped Steps

Any step that was skipped MUST have a written justification here. If this section is empty, no steps were skipped.

| Step | Justification | Authorised By |
|------|--------------|---------------|
| | | |

## Loop History

Tracks all pipeline loops (A→B→A→B, B-unit retries, gate failures).

| Loop | From Step | To Step | Reason | Timestamp |
|------|-----------|---------|--------|-----------|
| | | | | |

## Correction Records

Produced by the `post-rejection-correction` skill. One record per retry. Required for every gate failure before the retry is dispatched. Permanent — must not be edited after stamping.

| Retry | Gate | Tier | RC Category | Root cause (why missed) | Corrective action | Codified where |
|-------|------|------|-------------|------------------------|-------------------|----------------|
| | | | | | | |