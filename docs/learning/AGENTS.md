# AGENTS.md — docs/learning/

## OVERVIEW

Socratic research-and-decision loop for building well-architected AWS-shaped platforms inside Floci; invoked by `/learn <question>`.

## STRUCTURE

- `sessions/` — round transcripts
- `decisions/` — ADRs
- `findings/` — Floci-vs-AWS gap findings
- `diagrams/` — Mermaid sources (color-coded: green=REAL, grey-dashed=METADATA)
- `_templates/` — `session.md`, `adr.md`, `finding.md` (the only allowed shapes)
- `journal.md` — append-only per-round log

## WHERE TO LOOK

| Need | Path |
|---|---|
| Round-shape checklist, one-round flow | `README.md` |
| Past transcript (raw dialogue + subagent output) | `sessions/YYYY-MM-DD-<slug>.md` |
| Accepted decision | `decisions/NNNN-<slug>.md` |
| Floci vs AWS gap, unverified behavior | `findings/NNNN-<slug>.md` |
| Visual cross-cutting summary | `diagrams/solution.mmd` |
| Per-round entry tying them together | `journal.md` (bottom = newest) |
| Schema for a new ADR / finding / session | `_templates/{adr,finding,session}.md` |
| Last accepted round | `journal.md` last entry → linked `decisions/`, `sessions/`, `findings/` |

## CONVENTIONS

- **Numbering**: `decisions/` and `findings/` use sequential `NNNN` (no date prefix). `sessions/` use `YYYY-MM-DD-<slug>.md`.
- **Provenance**: every claim carries a source URL or an `(unverified)` flag. No anonymous assertions.
- **Cross-links**: every ADR must link its source session; every finding must link its ADR (or vice versa); `journal.md` entry links all three.
- **Floci lens**: research briefs that touch Floci must cite `docs/scraped/INDEX.md` and/or `docs/design/gaps-register.md` — not training-data memory.
- **Branching**: `/learn` work commits to a `feature/learning-loop` branch with linear history. Stage explicit paths; no mixed commits with installer changes.
- **Isolation**: do this work in a separate git worktree (see `../superpowers/WORKTREE-GUIDE.md`) so learning branches never touch installer branches.
- **Templates are the only source of truth** — do not invent frontmatter, sections, or filenames outside `_templates/`.
- **Diagram color code** (binding): REAL components = green solid; METADATA-only / modeling artifacts = grey dashed.

## ANTI-PATTERNS

- **Manual edits** to anything in `docs/learning/` — only `/learn` writes here.
- **Cross-contamination**: do not modify `setup-floci.sh`, root `AGENTS.md`, `docs/design/`, `.omo/`, or `.remember/` from this workflow.
- **Rewriting history**: `journal.md` is append-only at the bottom; never edit or reorder prior entries.
- **Date-prefixed ADRs/findings** (`2026-07-28-...` in `decisions/` or `findings/` is wrong; that prefix is for `sessions/` only).
- **Skipping the Floci lens** — every round must reconcile against `docs/scraped/` and/or `gaps-register.md`; otherwise it is not a learning round, it is a generic essay.
- **Fewer or more than 3 research briefs** — the round shape is fixed at 3 lenses (Well-Architected, real-world/community, Floci reconciliation).
- **Silent disagreements** — synthesis must surface at least one explicit disagreement, or explicitly state "no disagreement found".
- **Off-tree writes** during a round — all artifacts land under `docs/learning/`; nothing else.
