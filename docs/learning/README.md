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
