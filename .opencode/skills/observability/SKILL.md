---
name: observability
description: "Language-agnostic observability standard: structured logging, metrics (RED/USE), distributed tracing, SLIs/SLOs and error budgets, alerting philosophy, health checks, runbooks, and the pre-release observability verification checkpoint. Triggered when adding or reviewing any service change that emits telemetry, defines alerts/dashboards, or touches startup/shutdown/readiness. Loaded by Software Engineer, Code Architect, DevOps Specialist, and Test Engineer."
---

# Observability

## Purpose

If it cannot be seen from telemetry, it does not exist. This skill defines the mandatory observability standard every service change must meet before it is considered done. It covers the three pillars (logs, metrics, traces), SLIs/SLOs and error budgets, alerting, health checks, runbooks, and — critically — the **pre-release verification checkpoint** that turns "observability was written" into "observability was proven".

This skill is language-agnostic. Domain skills (e.g. `python-standards`, `fastapi`) provide the language-specific *how* (which logging library, which OTel SDK); this skill provides the *what* and the acceptance bar.

## When to Trigger

- Loaded by **Software Engineer**, **Code Architect**, **DevOps Specialist**, and **Test Engineer**.
- Triggered when a change **emits telemetry** (logs, metrics, traces), **adds or changes an alert or dashboard**, or **touches startup, shutdown, or readiness**.
- Triggered during Phase C verification — "where is the metric for this new path?" is a normal review question.

---

## 1. The Three Pillars, Used Correctly

### 1.1 Logs

- **Structured JSON, one event per line.** No free-text log lines.
- **UTC ISO-8601 timestamps** to the millisecond (e.g. `2026-05-20T10:14:22.831Z`).
- **Stack traces are a structured field**, never multi-line free text spanning lines.
- **Log levels mean specific things:**

| Level | Meaning |
|-------|---------|
| `error` | Something requires human attention |
| `warn` | Degraded but auto-recovered |
| `info` | Notable lifecycle events |
| `debug` | High-volume, off in production unless investigating |

- **Log once, at the level you mean.** A logged-then-rethrown error is the most common cause of duplicate noise. See `silent-failure` for the log-or-rethrow rule.
- **Sampling** is acceptable for high-volume `info`; `error` is **never** sampled.

### 1.2 Required log fields

Every log line carries these fields. **Keys are `snake_case`.**

| Field | Example |
|-------|---------|
| `timestamp` | `2026-05-20T10:14:22.831Z` |
| `level` | `info` / `warn` / `error` / `debug` |
| `service` | `campaign-api` |
| `env` | `prod` / `staging` / `dev` |
| `trace_id` | `5f7b…` |
| `span_id` | `9a4c…` |
| `message` | short human-readable string |
| *(event-specific keys)* | bounded, meaningful context |

### 1.3 Metrics

- **RED** for request-driven services: **R**ate (req/s), **E**rrors (rate), **D**uration (latency histogram).
- **USE** for resources: **U**tilization (%), **S**aturation (queue/load), **E**rrors.
- **Business metrics** alongside technical ones (e.g. campaigns booked per minute, reports ingested per minute, screens reporting healthy).
- **Histograms over averages for latency.** `mean(latency)` hides the user experience. Track and alert on p50/p95/p99; watch p99.9 for outlier sensitivity.

**Naming**

- `snake_case`, prefixed by service or domain: `campaign_api_requests_total`, `playback_report_lag_seconds`.
- **Units in the name**: `_seconds`, `_bytes`, `_total`.
- Counters end in `_total`; histograms end in `_seconds` or `_bytes`.

**Tags / labels**

- **Bounded cardinality only.** Status code, route, method, region, instance — yes. `user_id`, `request_id`, customer name — never.
- A new tag is a deliberate decision. Tagging with an unbounded field bankrupts the metrics bill and destroys query performance.

### 1.4 Traces

- **Distributed tracing enabled in all services.** Trace context propagates across HTTP, gRPC, and async boundaries (message attributes).
- **Sample heuristically:** 100% for errors and slow requests; head-based sampling at a reasonable percentage for the rest.
- **Spans are named after the operation** (`POST /orders`, `db.query.orders.by_id`), not the function name.

---

## 2. Pre-Release Observability Verification (mandatory checkpoint)

A feature is **not releasable** until its observability has been *verified*, not just written. This is owned by the engineer making the change and confirmed by reviewers/QA in the PR — not after release.

| # | Check | Criterion |
|---|-------|-----------|
| 1 | Required telemetry exists | Structured logs with required fields; metrics follow naming + tag conventions; traces propagate across new boundaries |
| 2 | Dashboards reflect the change | New path appears on the service dashboard; existing panels still true; deploy markers overlay the release |
| 3 | Alerts have actually fired | Every new/changed alert is **manually triggered in staging** (or via synthetic conditions) to confirm it fires, routes to the correct on-call channel, opens a current runbook, and clears cleanly on resolution |
| 4 | Trace context propagates | Across any new HTTP / async / queue boundary the change introduces |
| 5 | Runbook present and current | A runbook exists for every new alert; updated for any alert whose semantics changed |
| 6 | Health endpoints behave | If the change touches startup, shutdown, or readiness |

**An alert that has never fired is a hypothesis, not a control.** If any item is missing, the change is **not Done**.

---

## 3. SLIs, SLOs, and Error Budgets

### 3.1 SLIs — user-facing measurements

- **Availability:** share of requests that succeed (not 5xx, not timed out).
- **Latency:** share of requests served within a target time.
- **Correctness:** share of operations whose output is correct.
- **Freshness:** age of derived data (e.g. reporting lag).

### 3.2 SLOs — target values over a window

- Written, agreed with product, visible on the service dashboard, reviewed quarterly.
- Tied to a real customer outcome.
- Example: 99.9% availability over 28 days; p99 latency < 500 ms over 28 days.

### 3.3 Error budgets

- An SLO of 99.9% ≈ 43 minutes of budget per month.
- When budget burn exceeds the configured rate, **non-urgent deploys pause** until burn slows.
- Budget exhaustion triggers a reliability investment for the next cycle.
- **100% targets are anti-patterns** — they reward hiding failures rather than measuring them.

---

## 4. Alerting Philosophy

**Alert on symptoms users feel, not on every internal cause.** Cause-based dashboards exist for investigation; alerts exist to wake someone up.

### 4.1 Severity levels

| Severity | Meaning | Response |
|----------|---------|----------|
| **P1 / Critical** | Customer-facing outage, revenue impact, data-loss risk | Page immediately, 24/7, respond within 15 min |
| **P2 / High** | Significant degradation, SLO at risk, partial outage | Page in business hours; ticket otherwise, same day |
| **P3 / Medium** | Operational concern, no immediate customer impact | Ticket, within the week |
| **P4 / Low / Info** | Trend/warning to investigate | Dashboard or log; not paged |

### 4.2 What counts as actionable

An alert is actionable only if a human can do something useful within 30 minutes, the runbook is linked, the owning team is unambiguous, and the threshold reflects user-visible behaviour. Alerts failing any of these are tuned, deleted, or downgraded. **Pager noise is a reliability issue.**

### 4.3 Alert hygiene

- Target **≤ 2 actionable pages per on-call shift per service**; sustained higher load triggers a reliability investigation.
- **Pages without runbooks are bugs.** Adding a page without a runbook is not allowed.
- Stale alerts are pruned each quarter.

---

## 5. Dashboards

- **One canonical service dashboard per service.** Golden signals first, then dependencies, then business metrics.
- **Standard layout:** row 1 RED, row 2 USE, row 3 dependencies, row 4 business metrics.
- **Owner contact + last-reviewed date** at the top of every dashboard.
- **Deploy markers** overlaid so on-call can correlate regressions with releases.
- Linked from the service catalog and from every alert.
- Custom dashboards layer on top and expire after their investigation ends.

---

## 6. Health Checks

| Endpoint | Question | Behaviour |
|----------|----------|-----------|
| `/health/live` | Is the process running? | 200 if the runtime is alive |
| `/health/ready` | Can it serve traffic? | 200 only when dependencies (DB, cache, downstream auth) are reachable and startup is finished; 503 during graceful shutdown |

- **No business logic** in health checks — they exist for orchestration, not end-to-end testing.
- Cache health-check results appropriately to avoid hammering dependencies on every probe.

---

## 7. Runbooks

Every alert has a linked runbook containing: what the alert means, what to check first, common causes, mitigation steps (with rollback), and escalation contacts.

- Written for the on-call who has **never seen this alert before**.
- Tested at least once per quarter and updated when reality changes.
- A runbook nobody has executed is a hypothesis, not a runbook.

---

## 8. Production Debugging Expectations

- Debug **from telemetry**, not by SSHing to nodes. Live debuggers in production are a last resort, scoped and reviewed.
- High-cardinality questions ("why did *this* user's request fail?") are answered with traces and structured logs, not by adding new logs to find out.
- Treat "I can't tell what's happening" as a P2 bug: observability gaps degrade reliability.

---

## 9. Anti-Patterns (review-blocking)

- `log.info("done")` — context-free logs are noise.
- Metrics tagged by `user_id`, `request_id`, or unbounded inputs.
- Dashboards built after the incident rather than before launch.
- Alerts that fire weekly but go unaddressed.
- SSHing into nodes to "see what's going on" instead of relying on telemetry.
- Treating "we'll add observability later" as a valid plan.
- `console.log` / `print` / ad-hoc stdout in production code — use the structured logger.
- PII or secrets in logs — route through a central redactor.

---

## References

- Company Observability Principles (source of truth for this skill).
- Google SRE Book — *Service Level Objectives* and *Monitoring Distributed Systems*: <https://sre.google/sre-book/service-level-objectives/>.
- RED method (Tom Wilkie) and USE method (Brendan Gregg): <https://www.brendangregg.com/usemethod.html>.
- OpenTelemetry specification (traces, metrics, logs, context propagation): <https://opentelemetry.io/docs/specs/otel/>.
