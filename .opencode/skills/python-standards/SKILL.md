---
name: python-standards
description: "Python coding standard (the language-specific 'how' for code-quality): PEP 8 layout, snake_case/PascalCase naming, mandatory type hints, PEP 257 docstrings, guard clauses, standard-library-first (itertools/functools/collections), enums for arguments, immutability with frozen dataclasses and __slots__, context managers for cleanup, lazy evaluation and memory/CPU efficiency, boundary input validation/sanitization, exception handling with custom exception hierarchies, UTC timestamps, and structured JSON logging. Triggered when writing, reviewing, or refactoring Python. Reference alongside core skills software-engineering-principles, security-principles, observability, and performance-efficiency."
---

# Python Standards

## Purpose

This skill is the Python-specific realization of the company code-quality, documentation, and observability standards. Where the core skills define *what* good code, docs, and telemetry look like, this skill defines *how* in Python: naming, typing, docstrings, control flow, and logging. It applies to Python ≥ 3.11 (prefer the project's declared minimum in `AGENTS.md`).

## When to Trigger

- Loaded as a domain skill when the project tech stack includes Python.
- Triggered when writing, reviewing, or refactoring `.py` files, or configuring linters/formatters/type checkers.

---

## 1. Tooling Baseline

| Concern | Tool | Rule |
|---------|------|------|
| Formatting | `ruff format` (or `black`) | Formatting is not a review topic — the formatter decides. |
| Linting | `ruff` | Lint errors block merge; do not disable rules without a debt ticket. |
| Type checking | `mypy` (or `pyright`) strict | Public and internal APIs are fully typed. |
| Dependency mgmt | `uv` (preferred) | Reproducible installs from a lockfile. |

---

## 2. Naming Conventions (Python)

The company naming rules, expressed for Python (the source standard's camelCase is TypeScript and does **not** apply here):

- **Modules / files:** `snake_case` (e.g. `telemetry_helper.py`).
- **Functions / methods / variables:** `snake_case` (e.g. `retrieve_active_sessions`).
- **Classes / types:** `PascalCase` (e.g. `DatabaseConnector`).
- **Constants:** `UPPER_SNAKE_CASE` for module-level immutable primitives.
- **Booleans:** prefixed `is_`, `has_`, `can_`, `should_` (e.g. `is_authenticated`, `has_expired`) — never `flag`, `status`, `enabled` alone.
- **No abbreviations** except industry-standard ones (`url`, `id`, `db`, `api`). `cmp`, `mgr`, `usr` are forbidden.
- **No `data`, `info`, `manager`, `helper`, or `util`** without a qualifier.
- **Async functions:** do **not** add an `Async` suffix — the return type says it.
- **Domain terms** match the ubiquitous language used by product and operations.

---

## 3. Type Annotations (mandatory)

- Every public and internal function, method, and class attribute has full type annotations.
- Use modern syntax: `list[str]`, `dict[str, int]`, `X | None` (PEP 604) — not `List`, `Dict`, `Optional` from `typing` for new code.
- Prefer `Protocol` for structural interfaces (see `clean-architecture-python`).
- Avoid `Any`. If unavoidable, isolate it at the boundary and document why.

```python
def calculate_adjusted_metric(base_value: float, factor: float, offset: float = 0.0) -> float:
    """Compute an adjusted operational metric based on scaling factors.

    Args:
        base_value: The baseline measurement.
        factor: The multiplication scale factor to apply.
        offset: Optional additive adjustment to the output.

    Returns:
        The calculated metric.

    Raises:
        ValueError: If ``factor`` is less than or equal to zero.
    """
    if factor <= 0.0:
        raise ValueError("factor must be greater than zero")
    return (base_value * factor) + offset
```

---

## 4. Docstrings (PEP 257, Google style)

- Every public module, class, and function has a docstring documenting inputs, outputs, raised exceptions, and side effects.
- Use Google-style sections: `Args:`, `Returns:`, `Raises:`, `Note:`, `Example:`.
- Docstrings explain **why and how to use**; comments explain **why**, never restate **what**.
- No commented-out code on the main branch — version control remembers.

---

## 5. Control Flow

- **Guard clauses and early returns** to minimize nesting. Put the happy path last, unindented.
- **No redundant `else`** after a terminal `return`/`raise`.
- Functions do one thing — if the name needs "and", split it.
- Most functions fit on a screen (~40 lines); functions over 100 lines need a reason that survives review.

---

## 6. Standard Library First

Reach for the standard library before writing bespoke logic or adding a dependency. Recreating primitives is verbose, slower, and a bug surface.

- **`itertools`** for iteration: `chain`, `groupby`, `islice`, `product`, `combinations`, `accumulate`, `batched` (3.12+). Prefer these over hand-rolled loops and index bookkeeping.
- **`functools`**: `cache` / `lru_cache` (memoize pure hot functions), `reduce`, `partial`, `cached_property`.
- **`collections`**: `defaultdict`, `Counter`, `deque`, `ChainMap`.
- **`operator`**, **`contextlib`**, **`dataclasses`**, **`enum`**, **`pathlib`** over manual equivalents.

```python
from itertools import batched          # 3.12+

def chunk_records(records: list[Record], size: int = 500) -> Iterator[tuple[Record, ...]]:
    """Yield fixed-size batches without manual index slicing."""
    return batched(records, size)
```

---

## 7. Enumerations for Argument Passing

Use an `Enum` for any argument or state with a constrained set of values — never bare strings or magic integers. Enums give type checking, autocomplete, exhaustiveness, and readable logs.

- **`StrEnum`** (3.11+) when the value serializes to a string; **`IntEnum`** for integer wire values; **`IntFlag`** for bit flags.
- See `clean-architecture-python` for how enums fit the type-selection guide.

```python
from enum import StrEnum

class Mode(StrEnum):
    READ = "read"
    WRITE = "write"

def open_channel(mode: Mode) -> Channel:   # not: mode: str
    ...
```

---

## 8. Data Modelling, Immutability & Memory

- **Immutable by default.** Model internal value objects as **frozen dataclasses**: `@dataclass(frozen=True, slots=True)`. Immutability removes a class of aliasing bugs and makes values hashable/cacheable.
- **`__slots__`** (via `slots=True` or an explicit `__slots__`) removes the per-instance `__dict__`, cutting memory and speeding attribute access — use it for classes instantiated in bulk. Note the trade-offs: no dynamic attributes, and care with multiple inheritance; document any class that must opt out.
- **`NamedTuple`** for simple immutable records; a `tuple` over a `list` when the size is fixed.
- Full selection matrix (frozen dataclass / TypedDict / NamedTuple / Pydantic / StrEnum) lives in `clean-architecture-python`.

```python
from dataclasses import dataclass

@dataclass(frozen=True, slots=True)
class Money:
    amount_minor: int
    currency: str
```

---

## 9. Resource Management with Context Managers

Any resource that needs cleanup — files, sockets, DB connections/cursors, locks, temp dirs, timers, spans — is managed with a `with` (or `async with`) block. Never rely on `__del__` or a hand-written `try/finally` when a context manager exists.

- Author your own with `contextlib.contextmanager` or `__enter__`/`__exit__`.
- Use `contextlib.ExitStack` for a dynamic number of resources; `contextlib.suppress(SpecificError)` for a *deliberate* ignore (never a bare `except`).

```python
from contextlib import contextmanager

@contextmanager
def acquired(lock: Lock) -> Iterator[None]:
    lock.acquire()
    try:
        yield
    finally:
        lock.release()          # guaranteed cleanup even on exception
```

---

## 10. Lazy Evaluation & Efficiency

Memory and CPU efficiency are first-class design concerns — achieved primarily by choosing efficient primitives, not by cleverness.

- **Prefer generators and generator expressions** over building intermediate lists; **stream** large sequences and files rather than materializing them (see `polars` for dataframes).
- **Lazy loading:** defer expensive imports and computation until needed (`functools.cached_property`, `importlib`, module-level lazies). Do not do heavy work at import time.
- **Memoize** pure, hot functions with `functools.cache` / `lru_cache`.
- **Then measure.** Per `performance-efficiency`: profile before deeper optimization, optimize the common path first, and keep readability unless a change wins ≥ 2×. Efficient primitives are the default; micro-optimization that hurts readability is not.

```python
def total_effective(rows: Iterable[Row]) -> int:
    return sum(r.effective_amount for r in rows)   # generator expr — no intermediate list
```

---

## 11. Input Validation & Sanitization at the Boundary

**Parse, don't validate:** all external input is validated and parsed into typed objects **at the system boundary**, then trusted internally. Invalid input is rejected early with a clear error.

- Validate by **schema** at the edge (Pydantic in FastAPI — see `fastapi`); internal functions assume validated inputs rather than re-checking everywhere.
- **Sanitize/encode for the sink**, not generically: parameterized SQL (see `postgresql`), argument allowlists for shell, HTML escaping for output (see `security-principles`).
- **Never deserialize untrusted input into native objects** (no `pickle.loads`, no untrusted YAML tags) — parse into known types.

---

## 12. Exception Handling & Custom Exceptions

- **Define a project exception hierarchy** rooted at a base `AppError`, and raise **domain-specific** exceptions (`RecordNotFound`, `InvalidCredentials`, …). Specific types make logs precise and let callers handle exactly what they mean to.
- **Catch the narrowest type**; never a bare `except:`. Follow the log-or-rethrow rule (see `silent-failure`).
- **Preserve the cause chain** with `raise NewError(...) from err`, and attach structured context to the log `extra`.
- **Do not use exceptions for normal control flow.** Validating at the boundary keeps the happy path free of deep `try/except`.
- The **domain layer raises domain exceptions**; adapters translate them to transport errors (see `fastapi` RFC 9457, `clean-architecture-python`).

```python
class AppError(Exception):
    """Base for all application errors."""

class RecordNotFound(AppError):
    """A requested entity does not exist."""

def load_account(repo: AccountRepository, account_id: str) -> Account:
    account = repo.get(account_id)
    if account is None:
        raise RecordNotFound(f"account {account_id!r} not found")
    return account
```

---

## 13. Time & Timestamps (UTC)

- **Always use timezone-aware UTC.** Use `datetime.now(tz=UTC)` (`from datetime import UTC`, 3.11+); **never** the naive `datetime.utcnow()` / `datetime.now()`.
- Store, transmit, and log timestamps in **UTC ISO-8601 to the millisecond** (matches the `observability` required fields). Convert to a local zone only at display boundaries, using `zoneinfo`.
- Measure **durations** with a monotonic clock — `time.monotonic()`, not `time.time()`.

```python
from datetime import datetime, UTC

created_at = datetime.now(tz=UTC)      # aware, UTC
```

---

## 14. Observability in Python

Implements the core `observability` standard:

- **Never use `print`** for application tracing — use the `logging` module (or `structlog`) emitting **structured JSON**.
- Pass context via `extra=` dictionaries; keys are `snake_case` (`trace_id`, `span_id`, `service`, `env`).
- Capture exceptions with `logger.exception(...)` or `exc_info=True` inside handlers.
- **Libraries default to `logging.NullHandler()`** — handlers/formatters are configured only at the application composition root, never in library or domain code.

```python
import logging

logger = logging.getLogger(__name__)
logger.addHandler(logging.NullHandler())  # library default

def process_payload(payload_id: str) -> None:
    try:
        ...  # business logic
        logger.info("payload processed", extra={"payload_id": payload_id, "status": "processed"})
    except Exception:
        logger.exception("payload extraction failed", extra={"payload_id": payload_id})
        raise  # log-or-rethrow; never swallow (see silent-failure)
```

---

## 15. Anti-Patterns (review-blocking)

- Untyped public/internal functions; `Any` used to dodge the type checker.
- `print()` in library or production code.
- Bare `except:` or `except Exception: pass` (see `silent-failure`).
- Mutable default arguments (`def f(x=[])`).
- Business logic importing framework or I/O concretions (see `clean-architecture-python`).
- Disabling `ruff`/`mypy` rules in the same PR that introduces the violation without a debt ticket.
- Re-implementing `itertools` / `functools` / `collections` primitives with manual loops and accumulators.
- Bare strings or magic integers for constrained arguments instead of an `Enum`.
- Manual `open`/`close` or `try/finally` where a context manager exists.
- Building a full list where a generator would stream; heavy work at import time.
- Naive datetimes or `datetime.utcnow()` instead of aware UTC.
- Trusting unvalidated external input past the boundary; catching broad `Exception` instead of a domain-specific type.
- Mutable value objects where a frozen dataclass would do.

---

## References

- PEP 8 — Style Guide for Python Code: <https://peps.python.org/pep-0008/>.
- PEP 257 — Docstring Conventions: <https://peps.python.org/pep-0257/>.
- PEP 484 / PEP 585 / PEP 604 — type hints, generics, union syntax: <https://peps.python.org/pep-0484/>.
- Google Python Style Guide: <https://google.github.io/styleguide/pyguide.html>.
- Ruff: <https://docs.astral.sh/ruff/> · uv: <https://docs.astral.sh/uv/> · mypy: <https://mypy.readthedocs.io/>.
- `itertools` / `functools` / `collections`: <https://docs.python.org/3/library/itertools.html>.
- `contextlib` (context managers): <https://docs.python.org/3/library/contextlib.html>.
- `dataclasses` (`frozen`, `slots`): <https://docs.python.org/3/library/dataclasses.html> · `enum`: <https://docs.python.org/3/library/enum.html>.
- `datetime` (UTC-aware) & `zoneinfo`: <https://docs.python.org/3/library/datetime.html>.
- "Parse, don't validate": <https://lexi-lambda.github.io/blog/2019/11/05/parse-don-t-validate/>.
