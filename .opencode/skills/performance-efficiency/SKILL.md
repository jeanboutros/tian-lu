---
name: performance-efficiency
description: "Language-agnostic performance standard: measure before optimizing, performance as a budget, when to optimize and when not, and CI benchmark gates for hot paths. Triggered when a change touches a hot path, when profiling reveals a hotspot, or when a latency/throughput budget is at risk. Loaded by Software Engineer, Code Architect, and DevOps Specialist."
---

# Performance & Efficiency

## Purpose

Performance work is disciplined, not intuitive. This skill defines when to optimize, when not to, and how performance is treated as a budget rather than a vague goal. It is language-agnostic; domain skills provide language-specific techniques (e.g. `polars` for columnar data, `async-python` for concurrency, `postgresql` for query performance).

## When to Trigger

- Loaded by **Software Engineer**, **Code Architect**, and **DevOps Specialist**.
- Triggered when a change touches a hot path or scale-sensitive logic, when profiling reveals a hotspot, or when a latency/throughput budget is at risk.

---

## 1. Performance Mindset

- **Measure before optimizing.** Profile in conditions that resemble production: real data shapes, real concurrency. Microbenchmarks lie.
- **Performance is a budget, not a goal.** Each service has a latency budget per request that sums to the user-facing target. Optimize against the budget, not toward "faster".
- **Optimize the common path** before the rare one.
- **Readable code is the default.** A performance win must beat readability by a margin worth paying for — typically **2× or more, not 10%**.

---

## 2. When to Optimize — and When Not

**Optimize when:**

- A metric crosses an SLO (see `observability` and `reliability-scalability`).
- Profiling shows a clear hotspot.
- The change yields a **2× win without 2× complexity**.

**Do not optimize:**

- Code that runs once per deploy.
- Cleverness that beats readability by **< 10%**.
- "Fast" code paths that nobody calls.

---

## 3. Performance Regressions Are Bugs

- Hot paths have a **benchmark suite in CI**; regressions over a threshold **block merge**.
- Pre-release load tests for changes touching hot paths or scale-sensitive logic, with realistic traffic shapes — not "10k RPS, all identical requests".
- Pre-launch capacity rehearsal for known traffic events (major campaign launches, marketing pushes, seasonality). See `reliability-scalability` for capacity planning.

---

## References

- Company Performance & Efficiency standard (source of truth for this skill).
- Brendan Gregg — *Systems Performance* and the USE method: <https://www.brendangregg.com/usemethod.html>.
- Google SRE Workbook — *Eliminating Toil* and load/capacity practices: <https://sre.google/workbook/table-of-contents/>.
