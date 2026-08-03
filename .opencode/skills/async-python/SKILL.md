---
name: async-python
description: "Asynchronous Python with asyncio: preventing event-loop starvation (never block the loop), offloading blocking work with run_in_executor, structured concurrency with TaskGroup/gather, and timeouts with wait_for/timeout. Triggered when writing or reviewing async def code, coroutines, or concurrency. Reference alongside reliability-scalability (timeouts) and performance-efficiency."
---

# Asynchronous Python (asyncio)

## Purpose

`asyncio` runs coroutines cooperatively on a single-threaded event loop. Throughput collapses if any coroutine blocks the loop. This skill defines the rules for non-blocking async code: keep the loop free, offload blocking work, use structured concurrency, and bound everything with timeouts.

## When to Trigger

- Loaded as a domain skill when the project uses `asyncio` (e.g. FastAPI, async database access).
- Triggered when writing or reviewing `async def` functions, coroutines, executors, or concurrency primitives.

---

## 1. Never Block the Event Loop

A blocking call inside a coroutine stalls **every** concurrent task on that loop.

- **Do not** call blocking, synchronous APIs directly in `async def` — synchronous file I/O, `requests`, legacy SDKs, CPU-bound loops, `time.sleep()`.
- Use `await asyncio.sleep()` to yield, never `time.sleep()`.
- Use async-native clients (async HTTP client, `psycopg` `AsyncConnectionPool`) for I/O.

If throughput is `T` and a blocking op takes `t_block` seconds, running it inline caps the loop at `T ≤ 1 / t_block`. Offloading restores concurrency.

---

## 2. Offload Blocking Work

Wrap unavoidable blocking/CPU-bound calls in an executor so the loop stays free.

```python
import asyncio
from concurrent.futures import ThreadPoolExecutor

_pool = ThreadPoolExecutor(max_workers=10)

def heavy_parse(data: bytes) -> str:      # blocking, synchronous
    ...

async def process(data: bytes) -> str:
    loop = asyncio.get_running_loop()
    return await asyncio.wait_for(
        loop.run_in_executor(_pool, heavy_parse, data),
        timeout=3.0,
    )
```

- `asyncio.to_thread(func, *args)` is the simple form for one-off thread offloading.
- CPU-bound work that must scale beyond the GIL belongs in a **process** pool.

---

## 3. Structured Concurrency

Run independent coroutines concurrently — prefer `asyncio.TaskGroup` (Python 3.11+) for automatic cancellation and error aggregation.

```python
async def fetch_all(ids: list[str]) -> list[Record]:
    async with asyncio.TaskGroup() as tg:
        tasks = [tg.create_task(fetch_one(i)) for i in ids]
    return [t.result() for t in tasks]     # TaskGroup awaits + propagates exceptions
```

- Use `asyncio.gather(...)` when you need a flat result list and control over `return_exceptions`.
- **Do not create floating tasks.** Every `create_task` is owned by a `TaskGroup` or explicitly awaited/cancelled — an un-awaited task is a silent failure (see `silent-failure`, `backend-engineering` §7).

---

## 4. Timeouts (mandatory)

Every awaited external operation is bounded (see `reliability-scalability` §2, `backend-engineering` §4).

```python
async with asyncio.timeout(5.0):          # Python 3.11+
    result = await downstream_call()
# or, for a single awaitable:
result = await asyncio.wait_for(downstream_call(), timeout=5.0)
```

Handle `TimeoutError` explicitly — degrade or surface the failure; never let it silently pass.

---

## 5. Anti-Patterns (review-blocking)

- `time.sleep()`, `requests`, or blocking file/DB I/O inside `async def`.
- CPU-bound loops on the event loop without offloading.
- `asyncio.create_task(...)` whose result/exception is never observed (floating task).
- Unbounded `await` with no timeout on external calls.
- Mixing sync and async DB/HTTP clients ad hoc instead of using async-native adapters.

---

## References

- `asyncio` — Coroutines and Tasks: <https://docs.python.org/3/library/asyncio-task.html>.
- `asyncio.TaskGroup`: <https://docs.python.org/3/library/asyncio-task.html#task-groups>.
- `asyncio.timeout()` / `wait_for()`: <https://docs.python.org/3/library/asyncio-task.html#timeouts>.
- `loop.run_in_executor` / `asyncio.to_thread`: <https://docs.python.org/3/library/asyncio-eventloop.html#asyncio.loop.run_in_executor>.
