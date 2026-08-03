---
name: backend-engineering
description: "Language-agnostic backend service standard: API versioning, RFC 9457 problem+json error contracts, retry/idempotency handling, secrets, rate limiting, timeout control, no-silent-failures, and Controller->Service->Repository layering. Triggered when designing or reviewing any HTTP/event backend service, API surface, or integration. Loaded by Software Engineer, Code Architect, DevOps Specialist, and Security Reviewer."
---

# Backend Engineering Standards

## Purpose

Backends carry the revenue paths: bookings, scheduling, selection, ingest, reporting, billing. They must be **safe to change, easy to observe, and unsurprising under load.** This skill defines the language-agnostic contracts and patterns every backend service follows. The concrete stack (framework, runtime, cloud primitives) belongs in the downstream project's `AGENTS.md` and its domain skills (e.g. `fastapi`, `postgresql`), **not** here.

## When to Trigger

- Loaded by **Software Engineer**, **Code Architect**, **DevOps Specialist**, and **Security Reviewer**.
- Triggered when designing or reviewing an HTTP or event-driven service, an API surface, an error contract, a retry/timeout policy, or a service integration.

---

## 1. API Versioning

- HTTP APIs are versioned with a **URL prefix**: `/v1/...`. Do not version with headers.
- Within a major version, changes are **additive only** — adding optional fields, new endpoints, new enum values is fine; removing fields, changing types, or tightening validation is not.
- **Breaking changes ship as a new major version.** Old versions are deprecated with a written sunset date, a deprecation header on responses, and a named migration owner per consumer.
- Keep the previous major version live for **at least 90 days** after the deprecation announcement, longer for partner-facing APIs.
- **Internal events are versioned by schema** (`v1`, `v2`). Producers can publish multiple versions simultaneously during transitions.

---

## 2. Error Contracts

- Every error response uses **`application/problem+json` (RFC 9457, which obsoletes RFC 7807)** with at least: `type`, `title`, `status`, `detail`, `instance`, plus the extensions `code` and `trace_id`.
- **Error `code` values are stable, documented, and form an enumerable contract.** Clients branch on `code`, never on `detail` text.
- **4xx errors include enough detail for the client to recover** (e.g. which field failed validation).
- **5xx errors are intentionally vague to the client** but rich in logs and traces. Never leak stack traces, internal IDs, or vendor error messages to clients. (See `security-principles` §4 and `observability`.)

---

## 3. Retry Handling

- **Inbound:** APIs accept retries via **idempotency keys**; duplicate keys return the original result.
- **Outbound to other services:** retries with exponential backoff and **full jitter**, **only on idempotent operations**, with an overall deadline.
- **Outbound to external vendors:** a per-vendor retry policy in a **shared client wrapper**. Do not roll your own retries scattered through call sites.
- **Retry budgets are bounded.** Never retry past the caller's deadline. Never retry a write you cannot prove is idempotent. (Full policy in `reliability-scalability`.)

---

## 4. Timeout Control

- Every HTTP client is constructed via a shared wrapper that **requires a timeout to be set**.
- Every database client has **statement timeouts** configured.
- Every serverless/function invocation specifies a timeout that is the **minimum that works** for the path, not the maximum allowed.
- **Default-to-infinity timeouts are CI failures**, not optional warnings.

---

## 5. Secrets Handling

- Secrets come from the central secret manager, **loaded once at startup, never logged**.
- Local development uses scoped, non-production credentials provisioned by tooling — never production secrets.
- Rotation is automated where the secret manager supports it. (Full policy in `security-principles` §3.)

---

## 6. Rate Limiting

- Public APIs have **rate limits per principal** (API key, user, or IP for unauthenticated). Limits are documented in the API reference.
- Limits are enforced at the **gateway / WAF**; service code does not implement its own rate limiting in the request path.
- Internal service-to-service limiting is via **circuit breaker + concurrency limits** in the shared HTTP client.
- Rate-limit responses return **`429` with a `Retry-After` header**.

---

## 7. No Silent Failures

- Every caught error is **either** logged with full context **or** rethrown — never swallowed. (See `silent-failure`.)
- "It didn't crash, so it must have worked" is not a reliability strategy. **Assert post-conditions or emit a success-path metric** so the *absence* of success shows up.
- **Ban floating async work** — every asynchronous operation is awaited, joined, or explicitly handed to a supervised background runner. Unobserved futures/promises/tasks are a review-blocking smell.

---

## 8. Layering

- **Controller → Service → Repository.** Business logic does not live in controllers; database calls do not leak out of repositories. (See `software-engineering-principles` for the dependency-direction rule; `clean-architecture-python` for the Python realization.)
- **No shared mutable in-process caches** in services with multiple replicas — they will diverge.
- **Use the Strategy pattern** instead of `if`/`switch` sprawl for pluggable behaviour.

---

## 9. Anti-Patterns We Explicitly Reject

- Business logic in controllers; DB calls leaking out of repositories.
- Shared mutable in-process caches across replicas.
- "Just one more synchronous call" pushing a critical path over its latency budget.
- Hand-rolled parsing of API payloads without a schema.
- Logs as the primary diagnosis tool when a metric or trace would answer faster.
- Custom DSLs — strictly avoided.
- Default-to-infinity timeouts; unbounded retries; non-idempotent writes retried.

---

## References

- Company Backend Engineering Standards (source of truth; product-specific stack stripped per the Pipeline Generality Principle).
- RFC 9457 — Problem Details for HTTP APIs (obsoletes RFC 7807): <https://www.rfc-editor.org/rfc/rfc9457>.
- Stripe idempotency keys pattern: <https://docs.stripe.com/api/idempotent_requests>.
- Strategy pattern: <https://refactoring.guru/design-patterns/strategy>.
