---
name: pytest-testing
description: "Python testing with pytest: mandatory conftest.py and fixtures, parametrize with ids, test layout mirroring src, markers registered in pyproject.toml, edge-case coverage, and integration tests using real dependencies (Testcontainers) with transactional-rollback isolation and httpx AsyncClient. Triggered when writing or reviewing Python tests. Reference alongside core test-driven-development for the testing pyramid and QA strategy."
---

# Python Testing with pytest

## Purpose

Defines how automated tests are written in Python. `pytest` is the only permitted framework. This skill is the Python realization of the core `test-driven-development` testing strategy (pyramid, Dev/QA split, "every bug is a missing test"); it covers fixtures, parametrization, layout, markers, edge cases, and integration testing.

## When to Trigger

- Loaded as a domain skill when the project tech stack includes Python.
- Triggered when writing, reviewing, or scaffolding tests, or configuring the test runner.

---

## 1. Framework & Configuration

- **pytest only** — no `unittest`, no `nose`. All tests run via `pytest`.
- Configure in `pyproject.toml` under `[tool.pytest.ini_options]`:

```toml
[tool.pytest.ini_options]
minversion = "8.0"
addopts = ["-ra", "-q", "--strict-markers"]
testpaths = ["tests"]
pythonpath = ["src"]
asyncio_mode = "auto"                     # if using pytest-asyncio
markers = [
    "unit: fast, no external dependencies",
    "integration: requires external services or databases",
    "slow: takes longer than ~1s",
    "smoke: critical-path checks",
]
```

- `--strict-markers` makes an undeclared marker an error. Register **every** marker here.

---

## 2. Fixtures (mandatory for reuse)

- Anything used more than once (DB connections, clients, config, test data) is a **fixture**, not duplicated setup.
- A root **`tests/conftest.py` is mandatory**; it holds session-scoped and widely-shared fixtures. Layer-level `conftest.py` files hold layer-specific fixtures.
- Choose scope deliberately (`function`, `class`, `module`, `session`); expensive resources use wider scopes. Fixtures clean up after themselves (temp files, sessions, containers).

| Fixture used by | Location |
|-----------------|----------|
| 2+ layers | `tests/conftest.py` |
| One layer | `tests/<layer>/conftest.py` |
| One file | inline in the test file |

---

## 3. Parametrization

Use `@pytest.mark.parametrize` for multiple input/output combinations and edge cases, always with `ids` for readable output.

```python
@pytest.mark.parametrize(
    "value,expected",
    [(0, "zero"), (1, "one"), (-1, "negative"), (1_000_000, "large")],
    ids=["zero", "single", "negative", "large"],
)
def test_classify_number(value: int, expected: str) -> None:
    """Classify numbers across boundary conditions (zero, unit, negative, large)."""
    assert classify_number(value) == expected
```

---

## 4. Layout, Naming & Docstrings

- Test tree **mirrors `src/`** layout (core/domain/application/infrastructure/interfaces).
- Test names are specifications: `test_<unit>_<scenario>_<expected>` — e.g. `test_transfer_rejects_negative_amount`, not `test_amount_2`.
- Arrange–Act–Assert; one assertion theme per test; deterministic (no wall-clock/random without injection); no inter-test ordering dependencies.
- Load test data from a versioned `tests/test_data/` repository via helpers, not hardcoded blobs.

---

## 5. Edge Cases (mandatory coverage)

For each unit, consider: empty inputs (`""`, `[]`, `None`); boundaries (`0`, `-1`, max/min); type boundaries; error conditions; concurrency (if applicable); resource exhaustion (large inputs).

```python
def test_process_user_rejects_missing_email(invalid_user: dict) -> None:
    """Raise ValidationError when a required field is absent."""
    with pytest.raises(ValidationError, match="email"):
        process_user(invalid_user)
```

---

## 6. Integration Testing

Per the core strategy: **test real boundaries; do not mock what we own.**

- Use **real dependencies** via ephemeral containers (Testcontainers / `docker-compose`) — a real PostgreSQL, not a mocked one.
- Isolate each test with a **transactional rollback**: run inside a transaction and roll back on teardown so the database state is pristine between tests.
- Live in a **separate suite** (marker `integration`) run pre-merge, not on every keystroke.
- **Idempotency and migration tests** are mandatory for state-changing endpoints and schema changes (see `reliability-scalability`, `backend-engineering`).

```python
import pytest
from httpx import ASGITransport, AsyncClient
from myapp.main import app
from myapp.deps import get_db

@pytest.fixture
async def client(db_session):
    async def _override_db():
        yield db_session
    app.dependency_overrides[get_db] = _override_db
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
        yield c
    app.dependency_overrides.clear()

@pytest.mark.integration
async def test_create_account(client: AsyncClient) -> None:
    """POST /v1/accounts persists and returns the created account."""
    resp = await client.post("/v1/accounts",
        json={"username": "testuser", "email": "test@example.com", "credit_limit": 100.0})
    assert resp.status_code == 201
    assert resp.json()["username"] == "testuser"
```

`db_session` yields an `AsyncSession`/connection bound to a transaction that is **rolled back** after the test.

---

## 7. Quality Gates (a suite is incomplete if…)

- `tests/conftest.py` is missing, or `pyproject.toml` lacks the pytest config.
- Markers are used but not registered (fails under `--strict-markers`).
- Parametrized tests lack `ids`; fixtures are duplicated instead of shared.
- Edge cases are uncovered; a fixed bug has no regression test in the same PR (see `test-driven-development`).
- Our own database/repository is mocked for read/write logic instead of tested for real.

---

## References

- pytest: <https://docs.pytest.org/en/stable/>.
- pytest fixtures: <https://docs.pytest.org/en/stable/how-to/fixtures.html>.
- pytest-asyncio: <https://pytest-asyncio.readthedocs.io/en/latest/>.
- HTTPX `ASGITransport` / `AsyncClient`: <https://www.python-httpx.org/async/>.
- Testcontainers for Python: <https://testcontainers-python.readthedocs.io/en/latest/>.
