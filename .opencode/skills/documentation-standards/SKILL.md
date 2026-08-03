---
name: documentation-standards
description: "Language-agnostic documentation standard: what must be documented (README, architecture page, runbook, API reference, ADR, diagrams, ownership), the minimum acceptable bar for each type, the ADR template, PR-as-source-of-update rule, and authoring guidelines. Triggered when creating or changing any documentation, or when a change alters behavior that docs describe. Loaded by Docs Writer."
---

# Documentation Standards

## Purpose

Documentation is part of the product, not an aside. The bar is **utility**: a document is good if the next person — possibly future us — can use it to get something done. A document that exists but cannot be used is worse than no document, because it suggests the question is already answered.

This skill defines what must be documented, the minimum acceptable bar for each document type, and the authoring rules. It is language-agnostic and complements `software-engineering-principles` (C4 diagrams, module docs). For C/C++ API-doc tooling see `doxygen-cpp`; for Python docstrings see `python-standards`.

## When to Trigger

- Loaded by **Docs Writer** (primary).
- Triggered when any change alters behavior — the PR that changes behavior also changes the docs.
- Triggered when creating a new repo, service, alert, significant feature, or architecture decision.

---

## 1. What Must Be Documented

Each of the following is mandatory; missing any is a defect:

| Scope | Required artifact |
|-------|-------------------|
| Per repository | README, ownership, contribution guide |
| Per service | Architecture page, runbook, API reference (if it exposes one), service-catalog entry |
| Per significant decision | An ADR |
| Per significant feature/capability | A design brief |
| Per alert | A runbook entry |
| Per incident (Sev-1 / significant Sev-2) | A postmortem |

---

## 2. Minimum Acceptable Bar per Document Type

### 2.1 README

Every repo's `README.md` answers, in order:

1. **What is this?** — one paragraph.
2. **Who owns it?** — team name; link to service catalog.
3. **How do I run it locally?** — command-line steps that work on a clean checkout.
4. **How do I test it?** — test commands and what "pass" looks like.
5. **How do I deploy it?** — link to the deploy pipeline; not the steps themselves.
6. **Where do I find help?** — channel, people, related docs.

**Acceptance test:** if a new engineer cannot get from `git clone` to running tests in **30 minutes** using only the README, the README is broken.

### 2.2 Architecture page (per service)

- **Purpose** — what business capability it provides.
- **Position** — where it sits; what calls it; what it calls.
- **Data model** — key entities and relationships, at the level needed to reason about the service.
- **Critical paths** — the 3–5 most important request/event flows, with sequence diagrams where useful.
- **Operational considerations** — scaling, failure modes, dependencies, degraded behaviour.
- **Last-reviewed date** at the top.

### 2.3 Runbook (per alert / known failure mode)

Alert name and meaning (plain language) · first checks (which dashboards) · common causes · mitigation steps (with rollback) · escalation contacts · severity guidance. Assume zero prior context; link to deeper docs. (See `observability` for the alert↔runbook rule.)

### 2.4 API reference (per HTTP API)

- **OpenAPI spec** as the source of truth, generated into reference docs.
- **Per endpoint:** purpose, request shape, response shape, error codes, authentication required, rate limits.
- **Versioning policy** and **deprecation notices** with dates for sunset endpoints.
- **Example requests and responses**, realistic enough to be helpful.

### 2.5 ADR (Architecture Decision Record)

```
# ADR <id>: <Title>

## Status
Proposed | Accepted | Deprecated | Superseded by ADR-<id>

## Context
What is the problem? What constraints are in play?

## Decision
What did we decide? Be specific.

## Consequences
What does this make easier? Harder? What follow-on work is now necessary?

## Alternatives considered
What else did we look at, and why not?
```

- ADRs are **short** (1–2 pages), **specific**, and **immutable** once accepted. A superseded ADR is replaced by a new ADR, not edited.
- ADRs live in the repository they relate to (e.g. `docs/adrs/`) or a central registry for cross-repo decisions. In this workflow, ADR IDs are allocated via `next-id.mjs` (`adr` kind) and written under the project's ADR directory.
- ADRs are linked from related PRs and design briefs.

### 2.6 Architecture diagrams

- **Two perspectives per service:** a context diagram (this service and its neighbours) and a component diagram (inside the service).
- **Diagrams reflect reality**, not aspiration. A diagram that disagrees with the code is a bug in the docs.
- **Use Mermaid** (per the project Diagram Standard) so diagrams render everywhere and are diffable. See `software-engineering-principles` for the C4 model levels.

### 2.7 Operational & ownership docs

- Service-catalog entry for every deployed artifact; deploy guide (pipeline, environments, rollback); DR runbook for tier-1 services; environment inventory.
- The **service catalog is the source of truth for ownership.** Every service, dashboard, runbook, alert, infra module, and shared library lists its owner.
- **Unowned artifacts** are removed or reassigned within 30 days of discovery.

---

## 3. Documentation Update Responsibility

- **PR-as-source-of-update.** A PR that changes behavior also changes the docs. Reviewers check this; PRs that change behavior but not docs are returned.
- **The owning team owns its docs.** Updates triggered by external changes still go to the owning team; consumers do not update producer docs.
- **Last-reviewed dates** on every major doc. Docs whose last review is older than the cadence get a ticket.

---

## 4. Authoring Guidelines

- **Write for the reader who knows less than you do.** Define acronyms on first use; link to deeper reading.
- **Be specific.** "We use cloud hosting" is not documentation; name the concrete runtime, region, and datastore.
- **Be concrete.** Examples over abstractions; real values over placeholders where confidentiality allows.
- **Be honest.** "We don't yet have a runbook for this" beats a misleading runbook.
- **Be brief.** Cut what does not help the reader take action.
- **Be linkable.** Meaningful headings; stable URLs; anchors.

---

## 5. Anti-Patterns We Explicitly Reject

- Documentation written once and forgotten.
- The same fact in three places with subtle differences.
- Architecture diagrams not updated in two years that now mislead.
- Runbooks that are step-by-step screenshots of a since-redesigned UI.
- "The wiki" as a junk drawer with no ownership, structure, or review.
- Pull requests that change behavior without updating docs.
- ADRs written after the fact to justify a decision already made — an ADR records the decision, it does not narrate it.
- READMEs that say "see the wiki" while the wiki says "see the README".

---

## References

- Company Documentation standard (source of truth for this skill).
- Architecture Decision Records (Michael Nygard): <https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions>.
- C4 model for software architecture: <https://c4model.com/>.
- Diátaxis documentation framework (tutorials / how-to / reference / explanation): <https://diataxis.fr/>.
- OpenAPI Specification: <https://spec.openapis.org/oas/latest.html>.
