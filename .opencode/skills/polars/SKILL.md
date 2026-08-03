---
name: polars
description: "High-performance data transformation with Polars: lazy-first pipelines (scan_* + LazyFrame + collect), native columnar expressions over map_elements/iteration, predicate/projection pushdown, and streaming collect for larger-than-memory data. Triggered when writing or reviewing Polars data-processing code. Reference alongside performance-efficiency."
---

# Polars

## Purpose

Defines how analytical data transformations are written with Polars — a multithreaded, Arrow-backed query engine — to be fast and memory-efficient. The rule of thumb: build a **lazy** query, express work in **native expressions**, and let the optimizer do the rest.

## When to Trigger

- Loaded as a domain skill when the project tech stack includes Polars.
- Triggered when writing or reviewing dataframe/data-pipeline code, aggregations, joins, or CSV/Parquet ingestion.

---

## 1. Lazy-First

Favour `LazyFrame`: start with `scan_*` (not `read_*`), build the transformation, and call `.collect()` last. This lets the query planner apply predicate pushdown, projection pushdown, and other optimizations.

```python
import polars as pl

def category_revenue(path: str) -> pl.DataFrame:
    return (
        pl.scan_csv(path)                                   # lazy source
        .with_columns(
            pl.col("timestamp").str.to_datetime("%Y-%m-%d %H:%M:%S"),
            pl.col("purchase_amount").cast(pl.Float64),
            pl.col("coupon_applied").cast(pl.Boolean).fill_null(False),
        )
        .with_columns(
            pl.when(pl.col("coupon_applied"))
              .then(pl.col("purchase_amount") * 0.9)
              .otherwise(pl.col("purchase_amount"))
              .alias("effective_amount")
        )
        .filter(pl.col("effective_amount") > 5.0)           # pushed down to the scan
        .group_by("category")
        .agg(
            pl.col("effective_amount").sum().alias("total_revenue"),
            pl.col("effective_amount").mean().alias("avg_order_value"),
            pl.len().alias("order_count"),
        )
        .sort("total_revenue", descending=True)
        .collect()                                          # materialize once
    )
```

---

## 2. Native Expressions, Not Python Callbacks

- Express transformations with the expression API (`pl.col`, `pl.when/then/otherwise`, `.str`, `.dt`, `.list` namespaces).
- **Avoid `map_elements` / `apply` and row iteration in hot paths** — they drop to per-row Python and forfeit vectorization and multithreading.
- Reach for a Python UDF only when no native expression exists, and isolate it.

---

## 3. Memory Safety / Streaming

- For datasets larger than memory, collect in streaming mode: `.collect(engine="streaming")` (newer Polars) — process in chunks rather than materializing everything.
- Select only needed columns early; projection pushdown then reads less from disk.
- Prefer `scan_parquet` over CSV for large data; Parquet is columnar and typed.

---

## 4. Anti-Patterns (review-blocking)

- Eager `read_csv` + chained eager ops where a `scan_csv` lazy pipeline would optimize.
- `map_elements` / `apply` / `iter_rows` in hot paths instead of native expressions.
- Collecting a huge frame into memory when streaming would do.
- Falling back to pandas for work Polars expresses natively.
- Repeated `.collect()` mid-pipeline that defeats query optimization.

---

## References

- Polars user guide — lazy API: <https://docs.pola.rs/user-guide/lazy/>.
- Polars expressions: <https://docs.pola.rs/user-guide/expressions/>.
- Streaming / larger-than-memory: <https://docs.pola.rs/user-guide/concepts/streaming/>.
- Python API reference: <https://docs.pola.rs/api/python/stable/reference/index.html>.
