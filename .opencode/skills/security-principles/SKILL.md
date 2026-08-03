---
name: security-principles
description: "Language-agnostic security standard: secure-by-default, least privilege, defense in depth, secrets management, API security, OWASP Top 10 mapping, and common vulnerability prevention (injection, broken access control, XSS, SSRF, insecure deserialization, dependency vulnerabilities). Triggered for any change touching auth, data access, external surface area, third-party integrations, or secrets. Loaded by Security Reviewer, Software Engineer, and Code Architect."
---

# Security Principles

## Purpose

Security is built in from intake to production, not bolted on at release. This skill defines the mandatory security standard applied to every change that touches authentication, authorization, data access, external surfaces, third-party integrations, or secrets. It maps our defenses to the OWASP Top 10 and lists the common vulnerabilities we prevent and the anti-patterns we reject.

This skill is language-agnostic. Domain skills provide the language-specific enforcement (e.g. `fastapi` for schema validation and auth dependencies, `postgresql` for parameterized queries).

## When to Trigger

- Loaded by **Security Reviewer** (primary), **Software Engineer**, and **Code Architect**.
- Triggered when a change introduces a **new external surface**, a **new third-party integration**, or modifies **auth or data access**.
- Triggered when code handles secrets, user input, outbound requests, serialization, or IAM/permissions.

---

## 1. Governance

- **Security review** is required for new external surfaces, new third-party integrations, and changes to auth or data access. Reviewer: security lead or a designated engineer.
- **Dependency scanning** runs on every PR. High/critical severity **blocks merges**; medium has a 30-day SLA.
- **Penetration tests** run annually for production external surfaces, with findings tracked and remediated on a defined schedule.

---

## 2. Secure-by-Default Mindset

- **Default deny.** Every new resource (endpoint, queue, bucket) is private until explicitly opened, scoped, and reviewed.
- **Least privilege.** Services and humans get the narrowest IAM role that works. Wildcards (`*`) on policies are flagged in review.
- **Defense in depth.** Assume any one layer can fail. WAF + authN + authZ + input validation + output encoding — each layer assumes the others may have a bug.

---

## 3. Secrets Management

- Secrets live in the **central secret manager**. Code receives them via **environment injection at deploy time**, never from files in the repo.
- **Rotation is automated.** Static, long-lived credentials are an incident waiting to happen.
- **Pre-commit hooks and CI scan every commit** for likely secrets (e.g. gitleaks). A detection **blocks the merge and triggers rotation**.
- Developers do **not** have production secrets on laptops. Local dev uses scoped, non-production credentials.

---

## 4. API Security

Particular care for surfaces exposed to advertisers, agencies, partners, and operators:

- **Authentication required** on every endpoint by default; public endpoints are explicitly marked and reviewed.
- **Rate limiting** at the gateway, per principal.
- **Input validation** by schema at the boundary.
- **Output minimization** — endpoints return only what the caller needs, not the whole row.
- **CORS** is explicit and narrow; no `*` for credentialed endpoints.
- **No detailed error messages** to clients on 5xx — generic message + correlation ID; details in logs. (See `backend-engineering` for RFC 9457 error contracts.)
- **Versioned and documented** so deprecations and breaking changes go through a managed process.

---

## 5. OWASP Top 10 Mapping

| Risk | Our defense |
|------|-------------|
| **Broken Access Control** | AuthZ at every entry point; object-level checks against the specific resource ID; logged decisions on high-value resources |
| **Cryptographic Failures** | TLS 1.2+ everywhere; KMS-managed keys; field-level encryption for sensitive PII |
| **Injection** | Parameterized queries only; schema-validated inputs; no dynamic shell from user input |
| **Insecure Design** | Threat modeling for sensitive features; design review for external surfaces |
| **Security Misconfiguration** | IaC + config rules + WAF defaults; baseline hardening reviewed quarterly |
| **Vulnerable Components** | SCA on every PR; patch SLAs; annual dependency review |
| **Identification & Auth Failures** | Central IdP; short-lived tokens; MFA enforced; rate-limited login |
| **Software & Data Integrity** | Signed builds; verified artifacts; locked dependency files |
| **Logging & Monitoring Failures** | Structured logging; audit logs on sensitive actions; alerts on unusual access patterns |
| **Server-Side Request Forgery (SSRF)** | Outbound URLs allowlisted; egress proxy blocks metadata endpoints |

---

## 6. Common Vulnerabilities and How We Prevent Them

### 6.1 Injection (SQL, command, LDAP)

- **Parameterized queries only.** String-built SQL fails review.
- **No dynamic shell from user input.** If unavoidable, allowlist arguments and use the language's safe-exec API.

### 6.2 Broken Access Control

- Authorization is checked at **every entry point** — HTTP handler, async job consumer, everything.
- **Object-level checks:** verify the requester owns or is permitted on the specific resource ID, not just that they are logged in.

### 6.3 XSS / Output Encoding

- Templating engines auto-escape by default. Raw HTML insertion goes through a single, reviewed sanitization helper.

### 6.4 Server-Side Request Forgery (SSRF)

- Any outbound URL from user input is allowlisted, resolves to a non-private IP, and hits a dedicated egress proxy that blocks metadata endpoints.

### 6.5 Dependency Vulnerabilities

- Dependency scanning runs on every PR. High/critical findings block merges; medium findings get a 30-day SLA.
- Pin and lock dependency versions; reproduce builds from lockfiles.

### 6.6 Insecure Deserialization & SSTI

- **Never deserialize user input into language-native object graphs** (no `pickle.loads`, no untrusted YAML with arbitrary tags). Use schemas and parse into known types.

---

## 7. Anti-Patterns We Explicitly Reject

- "Internal-only" services left unauthenticated because the network is "trusted".
- Personal API tokens checked into config files for "testing".
- Bypassing authN for "test" or "local dev" in ways that ship to production behind a flag.
- Sensitive data in logs because "we'll filter it later".
- Pinning a CVE-affected dependency and silencing the scanner without a remediation plan.
- Long-lived IAM access keys on developer laptops.
- Vendors granted blanket access "because they need it to integrate".

---

## References

- Company Security Principles (source of truth for this skill).
- OWASP Top 10: <https://owasp.org/www-project-top-ten/>.
- OWASP API Security Top 10: <https://owasp.org/API-Security/editions/2023/en/0x00-header/>.
- OWASP Application Security Verification Standard (ASVS): <https://owasp.org/www-project-application-security-verification-standard/>.
- OWASP Cheat Sheet Series (Injection, Access Control, SSRF, Deserialization): <https://cheatsheetseries.owasp.org/>.
