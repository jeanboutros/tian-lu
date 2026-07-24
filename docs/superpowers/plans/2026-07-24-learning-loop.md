# Learning Loop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a reusable, explicitly-invoked `/learn` slash command that runs a Socratic-challenge → parallel-research → adversarial-debate → synthesis → human-decision → document loop, walled off from the installer's real workflows.

**Architecture:** A project-scoped slash command (`.claude/commands/learn.md`) orchestrates three `learn-`-prefixed subagents (`.claude/agents/`): a challenger, N parallel researchers (one lens each), and a synthesizer. Subagents are read/analyze-only and return text; the command (main session) is the *only* writer, and writes exclusively under `docs/learning/`. Outputs are a per-round session transcript, an append-only journal, numbered ADRs, and Floci-vs-AWS gap findings.

**Tech Stack:** Claude Code slash commands + subagents (Markdown + YAML frontmatter). No runtime code. Research tools: WebSearch, WebFetch, context7 MCP, AWS docs MCP. In-repo authorities: `docs/scraped/`, `docs/design/gaps-register.md`.

## Global Constraints

- **Write scope:** The workflow writes **only** under `docs/learning/`. Never edit `setup-floci.sh`, `AGENTS.md`, `docs/design/`, `.omo/`, or `.remember/`.
- **Naming:** All subagent files and their `name:` frontmatter are prefixed `learn-`. The command is `learn`.
- **Writer centralization:** Subagents are read/analyze-only and MUST NOT write files or run mutating commands. Only the `/learn` command (main session) writes, using the templates.
- **Provenance:** Every researcher claim carries a source URL or is flagged `unverified`.
- **Dating:** All written entries are stamped with the current date from session context (format `YYYY-MM-DD`).
- **Git:** Commits are **deferred** per the user's decision — do NOT commit onto `feature/persistent-local-dev-twin`. When the user is ready, commits go on a dedicated `feature/learning-loop` branch, staging explicit paths only (shared-branch etiquette: linear history, no rewrite of shared commits). Each task below ends with a validation step; the commit is batched at the end.
- **Model hints (optional):** the `model:` frontmatter accepts a **list**; the runtime (VS Code / Copilot) picks the **first available**, so order = preference. Reasoning-heavy agents (challenger, synthesizer) lead with `Claude Opus 4.8 (copilot)`, then `glm-5.2:cloud (ollama-models)`, then `Claude Sonnet 5 (copilot)`. The parallel researchers lead with `glm-5.2:cloud (ollama-models)`, then `Claude Sonnet 5 (copilot)`, then `Claude Haiku 4.5 (copilot)`. Quote each entry (spaces/parens). Model-identifier strings must match exactly what the runtime exposes. Safe to omit the field entirely to inherit.

---

### Task 1: `docs/learning/` scaffold — README, templates, empty journal

**Files:**
- Create: `docs/learning/README.md`
- Create: `docs/learning/_templates/session.md`
- Create: `docs/learning/_templates/adr.md`
- Create: `docs/learning/_templates/finding.md`
- Create: `docs/learning/journal.md`
- Create: `docs/learning/sessions/.gitkeep`
- Create: `docs/learning/decisions/.gitkeep`
- Create: `docs/learning/findings/.gitkeep`

**Interfaces:**
- Consumes: nothing (first task).
- Produces: the write substrate the `/learn` command (Task 5) fills. Exact paths the command relies on:
  - sessions → `docs/learning/sessions/YYYY-MM-DD-<slug>.md`
  - decisions → `docs/learning/decisions/NNNN-<slug>.md`
  - findings → `docs/learning/findings/NNNN-<slug>.md`
  - journal → append to `docs/learning/journal.md`
  - templates → read from `docs/learning/_templates/`

- [ ] **Step 1: Create `docs/learning/README.md`**

```markdown
# Learning Loop

A reusable, explicitly-invoked workflow for learning and deciding how to build a
well-architected cloud platform **inside Floci** (this repo's rootless-Podman AWS
emulator). Invoke with `/learn <question>`.

This tree is **isolated from installer work**: it is written only by the `/learn`
command, and nothing here affects `setup-floci.sh`, `AGENTS.md`, or `docs/design/`.

## One round

1. **Challenge** — `learn-challenger` reframes your question, surfaces assumptions,
   asks 2-3 Socratic questions. You answer inline.
2. **Research** — 3 parallel `learn-researcher` agents, one lens each:
   AWS Well-Architected · real-world/community · Floci reconciliation.
3. **Debate** — divergent claims are steelmanned then refuted.
4. **Synthesis** — `learn-synthesizer` returns a recommendation, a disagreement map,
   Floci adjustments, and draft ADR + journal + finding.
5. **You decide** — accept · go deeper · stop.
6. **Document** — on accept: session transcript + journal entry + ADR (+ finding).

## Round-shape checklist (use to eyeball correctness)

- [ ] Challenge produced a sharpened problem statement + clarifying questions.
- [ ] Exactly 3 research briefs returned, each with source links or an `unverified` flag.
- [ ] The Floci lens cited `docs/scraped/` and/or `docs/design/gaps-register.md`.
- [ ] Synthesis surfaced at least one explicit disagreement (or stated there was none).
- [ ] A draft ADR and a draft journal entry were produced.
- [ ] All writes landed under `docs/learning/` and nowhere else.

## Layout

- `sessions/` — full transcript per round (`YYYY-MM-DD-<slug>.md`).
- `decisions/` — numbered ADRs (`NNNN-<slug>.md`).
- `findings/` — Floci-vs-AWS gap findings (`NNNN-<slug>.md`).
- `journal.md` — append-only learnings log, one entry per accepted round.
- `_templates/` — the templates the command fills.
```

- [ ] **Step 2: Create `docs/learning/_templates/session.md`**

```markdown
# Session: <TOPIC>

**Date:** <YYYY-MM-DD>
**Question:** <original question as invoked>
**Outcome:** <accepted | deeper | stopped>
**Decision record:** <../decisions/NNNN-slug.md or "none">

## Challenge
<sharpened problem statement, surfaced assumptions, clarifying questions + your answers>

## Research briefs
### Lens 1 — AWS Well-Architected
<claim · evidence+links · confidence · Floci caveats>
### Lens 2 — Real-world / community
<claim · evidence+links · confidence · Floci caveats>
### Lens 3 — Floci reconciliation
<claim · in-repo evidence (docs/scraped, gaps-register) · confidence>

## Debate
<disagreements: steelman then refutation, per divergent claim>

## Synthesis
<recommendation · disagreement map · Floci-specific adjustments/limits>

## Your decision
<accept / go deeper / stop + rationale>
```

- [ ] **Step 3: Create `docs/learning/_templates/adr.md`**

```markdown
# ADR NNNN: <TITLE>

**Date:** <YYYY-MM-DD>
**Status:** Accepted
**Context source:** ../sessions/<YYYY-MM-DD-slug>.md

## Context
<the problem, the constraints, what "good" looks like for the platform in Floci>

## Decision
<the chosen approach, stated as a decision>

## Floci-specific adjustments
<how this differs from vanilla AWS guidance because of Floci's emulation gaps>

## Consequences
<trade-offs accepted, what this enables/blocks, follow-ups>

## Alternatives considered
<the losing options and why they lost>
```

- [ ] **Step 4: Create `docs/learning/_templates/finding.md`**

```markdown
# Finding NNNN: <FLOCI GAP TITLE>

**Date:** <YYYY-MM-DD>
**Related ADR:** ../decisions/<NNNN-slug>.md
**Related session:** ../sessions/<YYYY-MM-DD-slug>.md

## AWS expectation
<what AWS guidance / a real AWS account would do here>

## Floci reality
<what Floci actually emulates — cite docs/scraped/ or gaps-register.md>

## Impact on the platform
<what this means for what we build; the workaround adopted>
```

- [ ] **Step 5: Create `docs/learning/journal.md`**

```markdown
# Learning Journal

Append-only. One entry per accepted round, newest at the bottom.

<!-- Entry format:
## YYYY-MM-DD — <topic>
**Learned:** <the one-paragraph insight>
**Decided:** <ADR NNNN, if any>
**Floci gap:** <Finding NNNN, if any>
-->
```

- [ ] **Step 6: Create the three `.gitkeep` files**

```bash
mkdir -p docs/learning/sessions docs/learning/decisions docs/learning/findings
touch docs/learning/sessions/.gitkeep docs/learning/decisions/.gitkeep docs/learning/findings/.gitkeep
```

- [ ] **Step 7: Validate the scaffold**

Run:
```bash
test -f docs/learning/README.md \
 && test -f docs/learning/_templates/session.md \
 && test -f docs/learning/_templates/adr.md \
 && test -f docs/learning/_templates/finding.md \
 && test -f docs/learning/journal.md \
 && test -d docs/learning/sessions \
 && test -d docs/learning/decisions \
 && test -d docs/learning/findings \
 && grep -q "Round-shape checklist" docs/learning/README.md \
 && echo "SCAFFOLD OK"
```
Expected: prints `SCAFFOLD OK`.

---

### Task 2: `learn-challenger` subagent

**Files:**
- Create: `.claude/agents/learn-challenger.md`

**Interfaces:**
- Consumes: nothing at runtime (dispatched by the command with the raw question + repo context).
- Produces: text the command captures as the "Challenge" section — a sharpened problem statement, a bulleted list of surfaced assumptions, 2-3 numbered clarifying questions, and a one-line "what good looks like."

- [ ] **Step 1: Create `.claude/agents/learn-challenger.md`**

```markdown
---
name: learn-challenger
description: Socratic challenger for the /learn loop. Reframes a cloud-architecture question, surfaces the user's hidden assumptions, and asks 2-3 sharp clarifying questions before any research happens. Read/analyze-only.
tools: Read, Grep, Glob, WebSearch, WebFetch
model: ["Claude Opus 4.8 (copilot)", "glm-5.2:cloud (ollama-models)", "Claude Sonnet 5 (copilot)"]
---

You are the **challenger** in a learning loop about building a well-architected cloud
platform inside Floci (a rootless-Podman AWS emulator with known limitations).

You are read/analyze-only. NEVER write files or run mutating commands.

Given a raw question, do exactly this and return it as Markdown:

1. **Sharpened problem statement** — one paragraph restating the real decision behind
   the question, at the right altitude (not too broad, not too narrow).
2. **Surfaced assumptions** — a bullet list of the assumptions the question smuggles in
   (about scale, cost, AWS parity, Floci's capabilities, who operates it).
3. **Clarifying questions** — 2-3 numbered questions whose answers would most change the
   recommendation. Prefer questions that expose a fork in the design.
4. **What "good" looks like** — one line stating the success criteria for a strong answer.

Be concise and pointed. Do NOT research or recommend a solution — your job is to make the
question sharp enough that the researchers aim well. If you glance at the repo, you may
read `AGENTS.md`, `docs/scraped/`, and `docs/design/gaps-register.md` for context only.
```

- [ ] **Step 2: Validate frontmatter parses and required sections are present**

Run:
```bash
python3 - <<'PY'
import re, yaml, sys
p = ".claude/agents/learn-challenger.md"
t = open(p).read()
m = re.match(r"^---\n(.*?)\n---\n", t, re.S)
assert m, "no frontmatter"
fm = yaml.safe_load(m.group(1))
assert fm["name"] == "learn-challenger", fm.get("name")
assert fm["description"].strip(), "empty description"
body = t[m.end():]
for kw in ["Sharpened problem statement","Surfaced assumptions","Clarifying questions","read/analyze-only".lower()]:
    assert kw.lower() in body.lower(), f"missing: {kw}"
print("CHALLENGER OK")
PY
```
Expected: prints `CHALLENGER OK`.

---

### Task 3: `learn-researcher` subagent

**Files:**
- Create: `.claude/agents/learn-researcher.md`

**Interfaces:**
- Consumes: a sharpened problem statement + an assigned lens (`aws` | `community` | `floci`), passed in the dispatch prompt by the command.
- Produces: a structured Markdown brief with these exact headings: `## Claim`, `## Evidence`, `## Confidence`, `## Floci caveats`, `## What would change my mind`.

- [ ] **Step 1: Create `.claude/agents/learn-researcher.md`**

```markdown
---
name: learn-researcher
description: Parallel researcher for the /learn loop. Given a sharpened problem and one assigned lens (aws | community | floci), returns a single evidence-backed brief on how to build well-architected cloud patterns inside Floci. Read/analyze-only; spawned up to 3x in parallel, one lens each.
model: ["glm-5.2:cloud (ollama-models)", "Claude Sonnet 5 (copilot)", "Claude Haiku 4.5 (copilot)"]
---

You are one **researcher** in a learning loop about building a well-architected cloud
platform inside Floci (a rootless-Podman AWS emulator with known limitations). You are
one of three parallel researchers and you are BLIND to the others — argue only your lens.

You are read/analyze-only. NEVER write files or run mutating commands.

Your dispatch prompt names your **lens**. Follow it strictly:

- **aws** — current AWS Well-Architected best practice. Prefer AWS official docs. Use the
  AWS documentation MCP tools and context7 (load their schemas via ToolSearch first, e.g.
  `ToolSearch("select:mcp__plugin_deploy-on-aws_awsknowledge__aws___search_documentation")`
  and `ToolSearch("context7")`). Cite the AWS pillar(s) that apply.
- **community** — how practitioners actually do this in 2026, plus gotchas. Use WebSearch
  and WebFetch (load via ToolSearch). Favor recent, reputable sources; note dates.
- **floci** — does Floci actually emulate what the other lenses assume? This lens is the
  authority on limitations. Read `docs/scraped/` (start at `docs/scraped/INDEX.md`) and
  `docs/design/gaps-register.md` FIRST — these in-repo files outrank any web claim. Only
  then check upstream Floci docs on the web if needed.

Return exactly these Markdown headings, nothing before them:

## Claim
<your one-paragraph recommendation from your lens>

## Evidence
<bullets, each ending with a source URL or an in-repo path; if you cannot source a
statement, write it and tag it `(unverified)`>

## Confidence
<high | medium | low + one sentence why>

## Floci caveats
<how Floci's emulation changes or breaks this; for the floci lens this is the main event,
for the others it is your best guess flagged for the floci lens to confirm>

## What would change my mind
<the single strongest counter-argument or missing fact>
```

- [ ] **Step 2: Validate frontmatter and required output headings are documented**

Run:
```bash
python3 - <<'PY'
import re, yaml
p = ".claude/agents/learn-researcher.md"
t = open(p).read()
m = re.match(r"^---\n(.*?)\n---\n", t, re.S)
assert m, "no frontmatter"
fm = yaml.safe_load(m.group(1))
assert fm["name"] == "learn-researcher", fm.get("name")
body = t[m.end():]
for h in ["## Claim","## Evidence","## Confidence","## Floci caveats","## What would change my mind"]:
    assert h in body, f"missing heading: {h}"
for lens in ["aws","community","floci"]:
    assert lens in body, f"missing lens: {lens}"
assert "gaps-register.md" in body and "docs/scraped" in body, "missing in-repo authorities"
print("RESEARCHER OK")
PY
```
Expected: prints `RESEARCHER OK`.

---

### Task 4: `learn-synthesizer` subagent

**Files:**
- Create: `.claude/agents/learn-synthesizer.md`

**Interfaces:**
- Consumes: the three briefs (verbatim) + the challenge section, passed in the dispatch prompt.
- Produces: Markdown with these exact headings: `## Recommendation`, `## Disagreement map`, `## Floci adjustments`, `## Draft ADR`, `## Draft journal entry`, `## Draft finding` (the last may say "none"). The `## Draft ADR` / `## Draft finding` bodies follow the templates from Task 1 so the command can write them verbatim.

- [ ] **Step 1: Create `.claude/agents/learn-synthesizer.md`**

```markdown
---
name: learn-synthesizer
description: Synthesizer for the /learn loop. Reconciles the three research briefs plus the challenge into a single recommendation, an explicit disagreement map, Floci-specific adjustments, and draft ADR/journal/finding text ready for the command to write. Read/analyze-only.
tools: Read, Grep, Glob
model: ["Claude Opus 4.8 (copilot)", "glm-5.2:cloud (ollama-models)", "Claude Sonnet 5 (copilot)"]
---

You are the **synthesizer** in a learning loop about building a well-architected cloud
platform inside Floci (a rootless-Podman AWS emulator with known limitations).

You are read/analyze-only. NEVER write files. You return draft text; the /learn command
does the writing.

You receive the challenge section and three lens briefs (aws, community, floci). Weigh the
**floci** lens as the authority on what is actually possible here — a beautiful AWS
recommendation that Floci cannot emulate must be downgraded or adapted, not asserted.

Return exactly these Markdown headings:

## Recommendation
<the single recommended approach, one or two paragraphs, decision-shaped>

## Disagreement map
<each point where the lenses diverged: state the strongest version of each side
(steelman), then which one wins here and why. If there was no real disagreement, say so.>

## Floci adjustments
<how the recommendation departs from vanilla AWS guidance because of Floci's gaps>

## Draft ADR
<fill the ADR template from docs/learning/_templates/adr.md — Title, Context, Decision,
Floci-specific adjustments, Consequences, Alternatives considered. Leave the NNNN number
as `NNNN` for the command to assign. Stamp today's date from the dispatch prompt.>

## Draft journal entry
<3-5 lines: Learned / Decided / Floci gap, per docs/learning/journal.md's entry format>

## Draft finding
<if a genuine Floci-vs-AWS gap surfaced, fill docs/learning/_templates/finding.md;
otherwise write exactly: none>
```

- [ ] **Step 2: Validate frontmatter and required output headings**

Run:
```bash
python3 - <<'PY'
import re, yaml
p = ".claude/agents/learn-synthesizer.md"
t = open(p).read()
m = re.match(r"^---\n(.*?)\n---\n", t, re.S)
assert m, "no frontmatter"
fm = yaml.safe_load(m.group(1))
assert fm["name"] == "learn-synthesizer", fm.get("name")
body = t[m.end():]
for h in ["## Recommendation","## Disagreement map","## Floci adjustments","## Draft ADR","## Draft journal entry","## Draft finding"]:
    assert h in body, f"missing heading: {h}"
print("SYNTHESIZER OK")
PY
```
Expected: prints `SYNTHESIZER OK`.

---

### Task 5: `/learn` command (orchestrator)

**Files:**
- Create: `.claude/commands/learn.md`

**Interfaces:**
- Consumes: `$ARGUMENTS` (the topic/question); the three subagents by name (`learn-challenger`, `learn-researcher`, `learn-synthesizer`); the templates and paths from Task 1.
- Produces: on accept — writes `docs/learning/sessions/<date>-<slug>.md`, a numbered `docs/learning/decisions/NNNN-<slug>.md`, optionally `docs/learning/findings/NNNN-<slug>.md`, and appends to `docs/learning/journal.md`.

- [ ] **Step 1: Create `.claude/commands/learn.md`**

```markdown
---
description: Run one round of the learning loop (challenge -> parallel research -> debate -> synthesis -> your decision -> document) for a cloud-architecture question about building inside Floci.
argument-hint: <topic or question>
---

Run the learning loop for: **$ARGUMENTS**

You are the orchestrator and the ONLY writer. Follow these rules the whole way:

- Write ONLY under `docs/learning/`. Never touch `setup-floci.sh`, `AGENTS.md`,
  `docs/design/`, `.omo/`, or `.remember/`.
- Stamp every written date with today's date from your session context (`YYYY-MM-DD`).
- Do the writing yourself using the templates in `docs/learning/_templates/`. Subagents
  only return text.

Execute the round:

1. **Challenge.** Dispatch the `learn-challenger` subagent with the question and tell it
   it may read `AGENTS.md`, `docs/scraped/`, `docs/design/gaps-register.md` for context.
   Present its output to me and WAIT for my answers to its clarifying questions. Fold my
   answers into a sharpened problem statement.

2. **Research fan-out.** In a SINGLE message, dispatch THREE `learn-researcher` subagents
   in parallel, one per lens — pass each the sharpened problem and its lens:
   - one with lens `aws`
   - one with lens `community`
   - one with lens `floci`
   Collect the three briefs.

3. **Debate.** Identify every point where the briefs diverge. For each, write the
   steelman of each side, then note which is stronger given Floci's real constraints.
   (Do this yourself from the briefs; no extra subagent needed.)

4. **Synthesis.** Dispatch the `learn-synthesizer` subagent with the challenge section,
   the three briefs verbatim, the debate notes, and today's date. It returns a
   recommendation, disagreement map, Floci adjustments, and draft ADR/journal/finding.

5. **Human gate.** Present the synthesis to me and ask me to choose:
   - **accept** — go to step 6.
   - **go deeper** — I give a refined focus; return to step 2 with it.
   - **stop** — write only the session transcript (Outcome: stopped) and end.

6. **Document (on accept).** Do all of this yourself:
   - Compute `<slug>` = kebab-case of the topic. Compute the next zero-padded ADR number
     `NNNN` = (highest existing number in `docs/learning/decisions/` + 1, else `0001`);
     same scheme for findings.
   - Write `docs/learning/sessions/<date>-<slug>.md` from the `session.md` template,
     filled with the challenge, three briefs, debate, synthesis, and my decision.
   - Write `docs/learning/decisions/NNNN-<slug>.md` from the synthesizer's Draft ADR,
     assigning the real `NNNN` and cross-linking the session.
   - If the Draft finding is not `none`, write `docs/learning/findings/NNNN-<slug>.md`
     and cross-link it from the ADR and session.
   - Append the Draft journal entry to `docs/learning/journal.md`.
   - Report the exact paths you wrote. Do NOT commit (commits are deferred to a dedicated
     branch per project convention).
```

- [ ] **Step 2: Validate the command frontmatter and required orchestration steps**

Run:
```bash
python3 - <<'PY'
import re, yaml
p = ".claude/commands/learn.md"
t = open(p).read()
m = re.match(r"^---\n(.*?)\n---\n", t, re.S)
assert m, "no frontmatter"
fm = yaml.safe_load(m.group(1))
assert fm["description"].strip(), "empty description"
assert "argument-hint" in fm, "missing argument-hint"
body = t[m.end():]
assert "$ARGUMENTS" in body, "command must consume $ARGUMENTS"
for kw in ["learn-challenger","learn-researcher","learn-synthesizer",
           "in parallel","aws","community","floci","Human gate","docs/learning/",
           "Do NOT commit".lower()]:
    assert kw.lower() in body.lower(), f"missing: {kw}"
print("COMMAND OK")
PY
```
Expected: prints `COMMAND OK`.

---

### Task 6: Dry-run validation of the full loop

**Files:**
- No files created. This task exercises the assembled workflow and confirms isolation.

**Interfaces:**
- Consumes: everything from Tasks 1-5.
- Produces: one real session's worth of outputs under `docs/learning/`, used as the acceptance evidence.

- [ ] **Step 1: Confirm the command and agents are discoverable**

Run:
```bash
ls .claude/commands/learn.md .claude/agents/learn-challenger.md \
   .claude/agents/learn-researcher.md .claude/agents/learn-synthesizer.md \
 && echo "ASSETS PRESENT"
```
Expected: prints `ASSETS PRESENT`. (In an interactive session, also confirm `/learn` appears in the slash-command list and the three `learn-*` agents appear in the agent list.)

- [ ] **Step 2: Snapshot the protected paths (isolation pre-check)**

Run:
```bash
git status --porcelain | grep -E '(setup-floci\.sh|AGENTS\.md|docs/design/)' && echo "UNEXPECTED CHANGES" || echo "PROTECTED PATHS CLEAN"
```
Expected: prints `PROTECTED PATHS CLEAN`.

- [ ] **Step 3: Run the loop on a sample topic**

In the interactive session, run:
```
/learn S3 bucket-per-account vs shared-bucket prefix isolation in Floci
```
Drive it through: answer the challenger's questions, let the 3 researchers return, review synthesis, choose **accept**.

- [ ] **Step 4: Verify the round shape and isolation held**

Run:
```bash
python3 - <<'PY'
import glob, os
sess = glob.glob("docs/learning/sessions/*-*.md")
adr  = glob.glob("docs/learning/decisions/[0-9][0-9][0-9][0-9]-*.md")
assert sess, "no session transcript written"
assert adr, "no ADR written"
j = open("docs/learning/journal.md").read()
assert j.count("## ") >= 1, "journal entry not appended"
print("ROUND OUTPUTS OK:", os.path.basename(sess[-1]), os.path.basename(adr[-1]))
PY
git status --porcelain | grep -E '(setup-floci\.sh|AGENTS\.md|docs/design/)' && echo "ISOLATION VIOLATED" || echo "ISOLATION OK"
```
Expected: prints `ROUND OUTPUTS OK: ...` and `ISOLATION OK`.

- [ ] **Step 5: Confirm against the README round-shape checklist**

Open the written session file and confirm every box in `docs/learning/README.md`'s
"Round-shape checklist" is satisfiable from it (3 briefs with links, Floci lens cited
in-repo authorities, at least one disagreement or an explicit "none", a draft ADR).

---

## Deferred commit (end of implementation)

Per the user's decision, do NOT commit during implementation and do NOT commit onto
`feature/persistent-local-dev-twin`. When the user confirms they are ready:

```bash
git checkout -b feature/learning-loop
git add docs/learning docs/superpowers/specs/2026-07-24-learning-loop-design.md \
        docs/superpowers/plans/2026-07-24-learning-loop.md \
        .claude/commands/learn.md .claude/agents/learn-challenger.md \
        .claude/agents/learn-researcher.md .claude/agents/learn-synthesizer.md
git commit -m "feat(learning): add /learn Socratic research loop, isolated under docs/learning"
```

(Stage explicit paths only; keep history linear; the dry-run outputs under
`docs/learning/sessions|decisions|findings` may be included or discarded as the user
prefers.)
