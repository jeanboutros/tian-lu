---
description: "Run one round of the learning loop (challenge -> parallel research -> debate -> synthesis -> your decision -> document) for a cloud-architecture question about building inside Floci."
argument-hint: "<topic or question>"
agent: agent
---
Run the learning loop for the topic or question above (if none was given, ask me for one before continuing).

You are the orchestrator and the ONLY writer. Follow these rules the whole way:

- Write ONLY under `docs/learning/`. Never touch `setup-floci.sh`, `AGENTS.md`,
  `docs/design/`, `.omo/`, or `.remember/`.
- Stamp every written date with today's date from your session context (`YYYY-MM-DD`).
- Do the writing yourself using the templates in `docs/learning/_templates/`. Subagents
  only return text — dispatch them with the `runSubagent` tool and the matching
  `agentName`.

Execute the round:

1. **Challenge.** Dispatch the `learn-challenger` subagent with the question and tell it
   it may read `AGENTS.md`, `docs/scraped/`, `docs/design/gaps-register.md` for context.
   Present its output to me and WAIT for my answers to its clarifying questions. Fold my
   answers into a sharpened problem statement.

2. **Research fan-out.** Dispatch THREE `learn-researcher` subagents in parallel (single
   batch of tool calls), one per lens — pass each the sharpened problem and its lens:
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
