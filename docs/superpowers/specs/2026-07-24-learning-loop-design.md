# Learning Loop — Design Spec

**Date:** 2026-07-24
**Status:** Approved (design); pending implementation plan
**Author:** Jean Boutros (with Claude)

## Purpose

A reusable, explicitly-invoked agent workflow for learning and deciding how to build
a well-architected cloud platform *inside Floci* (the project's rootless-Podman AWS
emulator). One invocation runs a loop: ask → Socratic challenge → parallel research →
adversarial debate → synthesis → human decision → document.

Each accepted round produces **both** a learning-journal entry (understand the concept)
**and** an ADR-style decision record (act on it), plus a finding whenever Floci's
emulation diverges from AWS guidance.

The workflow is walled off from the installer's real workflows: it is a slash command
(never auto-fires), its subagents are `learn-`-prefixed, and it writes only under
`docs/learning/`.

## Non-goals

- Not part of installer development; never edits `setup-floci.sh`, `AGENTS.md`,
  `docs/design/`, `.omo/`, or `.remember/`.
- Not autonomous — the human gate between rounds is the loop's brake and its
  correctness guarantee.
- No auto-triggering skill (would risk firing during real installer work).

## Mechanism

Approach A — **slash command + project subagents**. Chosen over a Workflow script
(runs headless in the background, fights the per-round human gate) and over a Skill
(auto-triggers → conflict risk). A slash command is explicitly invoked and pauses
naturally between rounds.

## Directory layout & isolation

```
.claude/
  commands/
    learn.md                 # /learn — the orchestrator prompt (explicitly invoked)
  agents/
    learn-challenger.md      # Socratic interviewer / assumption-surfacer
    learn-researcher.md      # parallel researcher (spawned N times, one lens each)
    learn-synthesizer.md     # reconciles briefs + debate -> recommendation & drafts

docs/learning/
  README.md                  # how the loop works + round-shape checklist
  _templates/                # session.md, adr.md, finding.md
  sessions/                  # YYYY-MM-DD-<topic>.md  (full transcript per round)
  decisions/                 # NNNN-<slug>.md  (numbered ADRs)
  findings/                  # NNNN-<slug>.md  (Floci-vs-AWS gap findings)
  journal.md                 # append-only learnings log, one entry per accepted round
```

**Isolation guarantees**

- Every artifact is either under `docs/learning/` or a `learn-`-prefixed `.claude/` asset.
- The `learn-` prefix visibly distinguishes these subagents from any installer agent.
- The command runs only when the user types `/learn`.

## The loop (data flow per round)

1. **Invoke** — `/learn <question>`.
2. **Challenge** — `learn-challenger` reframes the question, surfaces hidden
   assumptions, asks 2–3 Socratic clarifying questions, states what "good" looks like.
   The user answers inline.
3. **Research fan-out** — orchestrator spawns **3 parallel `learn-researcher`** agents,
   each blind to the others, one lens each:
   - Lens 1 — current **AWS Well-Architected** best practice (AWS MCP docs + context7).
   - Lens 2 — **real-world / community** current practice + gotchas (WebSearch/WebFetch).
   - Lens 3 — **Floci reconciliation**: does Floci actually emulate this?
     (`docs/scraped/`, `docs/design/gaps-register.md`).
4. **Challenge-each-other** — the three briefs are cross-examined: each divergent claim
   is steelmanned then refuted; disagreements are made explicit.
5. **Synthesis** — `learn-synthesizer` outputs: recommendation · disagreement map ·
   Floci-specific adjustments/limits · **draft ADR** + **draft journal entry**
   (+ finding if a gap surfaced).
6. **Human gate** — user chooses: **accept** · **go deeper** (loop to step 3 with
   refined focus) · **stop**.
7. **Document** — on accept: append journal, write/number the ADR, write finding(s),
   save the session transcript.

## Subagent contracts

| Agent | Input | Output | Tools |
|---|---|---|---|
| `learn-challenger` | raw question + repo context | sharpened problem statement, surfaced assumptions, 2–3 clarifying Qs, success criteria | read-only + web |
| `learn-researcher` (×N, parameterized by lens) | sharpened problem + assigned lens | structured brief: claim · evidence+links · confidence · Floci caveats · "what would change my mind" | WebSearch, WebFetch, context7, AWS MCP docs, Read |
| `learn-synthesizer` | all briefs + debate notes | recommendation · disagreement map · Floci adjustments · draft ADR + journal entry + findings | Read only (returns draft text; the command writes) |

## Guardrails & error handling

- **Runaway guard** — default 3 researchers, one research round unless the user says
  "go deeper." The human gate stops the loop.
- **Non-conflict guard** — the command prompt states it may write **only** under
  `docs/learning/`; never installer files, `AGENTS.md`, or `docs/design/`.
- **Provenance** — every researcher claim carries a source link or is flagged
  `unverified`. Floci caveats are cross-checked against the in-repo authorities
  (`docs/scraped/`, `gaps-register.md`) before any web claim is trusted.
- **Shared-branch etiquette** — docs are additive, ADRs append-numbered, `journal.md`
  append-only → linear history; explicit path staging; no rewrite of shared commits.
- **Dating** — entries stamped with the current date from session context.

## Testing / validation

No code, so validation is a **dry run**: invoke `/learn` on a sample topic
(e.g. *"S3 bucket-per-account vs prefix isolation in Floci"*) and confirm the round
shape holds — challenge fires, 3 briefs return with links, synthesis produces a draft
ADR, and **all writes land only under `docs/learning/`**. `README.md` carries a
round-shape checklist for eyeballing correctness. The human gate is the correctness
guarantee.

## Reusability

`/learn <topic>` any time. Templates keep outputs consistent; `journal.md` accumulates
a personal curriculum; `decisions/` becomes the decision log for the platform built in
Floci.
