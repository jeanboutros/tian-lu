---
name: postgresql
description: "PostgreSQL access from Python using psycopg 3: connection pooling (psycopg_pool ConnectionPool/AsyncConnectionPool), parameterized queries only, transaction context management, row factories, and statement timeouts. Triggered when writing or reviewing database access code, repositories, or connection lifecycle. Reference alongside core skills security-principles (injection), backend-engineering (timeouts), and clean-architecture-python (repository layer)."
---

# PostgreSQL with psycopg 3

## Purpose

Defines safe, performant PostgreSQL access from Python using **psycopg 3** (the module is imported as `psycopg`). It covers connection pooling, injection-safe parameterized queries, transaction lifecycle, row factories, and timeouts. Raw SQL lives **only** in the repository layer (see `clean-architecture-python`).

> Driver note: this project standardises on **psycopg 3**, not psycopg2. Install with `pip install "psycopg[binary,pool]"` (or add `psycopg` + `psycopg_pool` via `uv`).

## When to Trigger

- Loaded as a domain skill when the project tech stack includes PostgreSQL.
- Triggered when writing or reviewing database access, repository classes, or connection/transaction lifecycle.

---

## 1. Connection Pooling

Never open a new physical connection per request. Manage a pool and reuse connections.

```python
from psycopg_pool import ConnectionPool

# open=True is the current default but is being deprecated to False — set it explicitly.
pool = ConnectionPool(conninfo, min_size=4, max_size=20, open=True)

with pool.connection() as conn:          # borrow; auto-returned at end of block
    conn.execute("SELECT 1")
```

- At the end of the `pool.connection()` block, the transaction is **committed** (normal exit) or **rolled back** (exception), and the connection returns to the pool.
- Prefer using the pool itself as a context manager (`with ConnectionPool(...) as pool:`) for deterministic cleanup; if used as a long-lived global, register `atexit.register(pool.close)`.
- Use `pool.wait()` after opening to fail fast if the database is misconfigured.
- Tune with `get_stats()`; the pool is usually **smaller than you think** (see HikariCP pool-sizing analysis).

### Async

```python
from psycopg_pool import AsyncConnectionPool

pool = AsyncConnectionPool(conninfo, min_size=4, max_size=20, open=False)
await pool.open()                        # opening an async pool in the ctor is deprecated

async with pool.connection() as conn:
    await conn.execute("SELECT 1")
```

Integrate with FastAPI via a `lifespan` (see `fastapi`): open the pool on startup, `await pool.close()` on shutdown.

---

## 2. Parameterized Queries Only (injection-safe)

**Never build SQL with string concatenation, `%`, `.format()`, or f-strings.** Use `%s` placeholders and pass parameters separately — psycopg performs correct, injection-safe conversion. (See `security-principles` §6.1.)

```python
from psycopg.rows import dict_row

def fetch_active_client(pool: ConnectionPool, client_id: str) -> dict | None:
    sql = "SELECT id, name, status FROM client_records WHERE id = %s AND status = 'active'"
    with pool.connection() as conn:
        with conn.cursor(row_factory=dict_row) as cur:
            return cur.execute(sql, (client_id,)).fetchone()
```

- Named placeholders `%(name)s` with a dict are also supported.
- To interpolate **identifiers** (table/column names) safely, use `psycopg.sql.SQL` / `Identifier`, never string formatting.
- `cur.execute(...)` returns the cursor, so you may chain `.fetchone()` / `.fetchall()`.

---

## 3. Transactions

- The `pool.connection()` (and `psycopg.connect()` `with`) block commits on normal exit and rolls back on exception.
- For an explicit atomic unit, use a **`conn.transaction()`** block:

```python
def transfer(pool: ConnectionPool, src: str, dst: str, amount: int) -> None:
    with pool.connection() as conn:
        with conn.transaction():                     # BEGIN … COMMIT / ROLLBACK
            conn.execute("UPDATE accounts SET balance = balance - %s WHERE id = %s", (amount, src))
            conn.execute("UPDATE accounts SET balance = balance + %s WHERE id = %s", (amount, dst))
```

`conn.transaction()` supports nesting via savepoints. Do not sprinkle manual `commit()`/`rollback()` when a context block expresses intent more clearly.

---

## 4. Timeouts & Resource Safety

- Configure a **statement timeout** so no query runs unbounded (see `backend-engineering` §4): set `options="-c statement_timeout=5000"` in `conninfo`, or `SET statement_timeout` per session/transaction.
- Set pool `timeout` (max wait for a connection) and handle `PoolTimeout`.
- Always use `with` blocks for connections and cursors so resources are released even on error.
- Return **domain models or plain dicts** from repositories — never leak live connections/cursors upward (see `clean-architecture-python`).

---

## 5. Anti-Patterns (review-blocking)

- String-built SQL / f-string interpolation of values — fails review.
- One new connection per request instead of a pool.
- Interpolating table/column identifiers with `%`/f-strings instead of `psycopg.sql`.
- Swallowing `psycopg.Error` without logging or rethrowing (see `silent-failure`).
- Default-to-infinity statement timeouts.
- Repositories returning ORM/DB session objects to the service layer.

---

## References

- Psycopg 3 basic usage: <https://www.psycopg.org/psycopg3/docs/basic/usage.html>.
- Passing parameters to SQL queries: <https://www.psycopg.org/psycopg3/docs/basic/params.html>.
- Transactions management: <https://www.psycopg.org/psycopg3/docs/basic/transactions.html>.
- Connection pools (`psycopg_pool`): <https://www.psycopg.org/psycopg3/docs/advanced/pool.html>.
- Row factories (`dict_row`): <https://www.psycopg.org/psycopg3/docs/advanced/rows.html>.
