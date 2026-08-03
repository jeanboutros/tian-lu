---
name: test-driven-development
description: "TDD loop (red-green-refactor) plus the team testing strategy: the testing pyramid (unit/integration/contract/E2E/exploratory), Dev/QA ownership, do-not-mock-what-we-own, flaky-test quarantine, test-data management, and the definition of test-complete. Language-agnostic; load pytest-testing (Python) or tdd-cpp (C++) for mechanics."
---

# Test-Driven Development

## Overview

Write the test first. Watch it fail. Write minimal code to pass.

Core principle: **If you didn't watch the test fail, you don't know if it tests the right thing.**

## When to Use

- New function, module, or component implementation
- New protocol or transformation logic
- Bug fixes (write the test that would have caught it)
- Refactoring (tests prove no regression)

## The TDD Cycle

```
RED ──→ GREEN ──→ REFACTOR
 ↑                    │
 └────────────────────┘
```

### RED: Write the Failing Test

Write a test for the behaviour you're about to implement — before writing any implementation code. Run it. It must fail.

If the test passes before you write the implementation, the test is wrong.

### GREEN: Implement Minimal Code

Write just enough code to make the test pass. No more. Resist the urge to generalise prematurely.

### REFACTOR: Clean Up

- Remove duplication
- Improve naming
- Add documentation
- Add edge case tests (boundary values, error paths)

The tests must still pass after refactoring.

## Test Categories

### 1. Happy Path Tests

Verify the function does what it should for valid inputs:

```
assert compute(known_input) == expected_output
```

### 2. Round-Trip / Encode-Decode Tests

For any serialise/deserialise or encode/decode pair:

```
assert decode(encode(value)) == value
assert encode(decode(bytes)) == bytes
```

### 3. Edge Case Tests

```
assert f(MAX_VALUE)   == expected
assert f(MIN_VALUE)   == expected
assert f(ZERO)        == expected
assert f(EMPTY)       == expected
```

### 4. Error Path Tests

```
assert f(invalid_input) raises Error
assert f(null_input)    returns default_or_error
```

### 5. Regression Tests

After every bug fix, write a test that would have caught it:

```
# This test documents the bug and proves it is fixed
assert f(previously_broken_input) == correct_output
```

## Rules

1. **Test file must exist before implementation** — even if empty
2. **The test must fail before implementation** — proves the test is real
3. **The test must pass after implementation** — proves correctness
4. **Never delete a test to make code pass** — fix the code instead
5. **Edge cases are not optional** — boundary values and error paths always tested
6. **One failing test at a time** — don't write multiple failing tests before implementing

## Testing Strategy & QA

Tests are documentation that runs. TDD produces the units; this strategy defines the layers, ownership, and the bar for "done".

### The Testing Pyramid

| Layer | What it tests | Notes |
|-------|---------------|-------|
| **Unit** | A single function/class/pure module in isolation | Milliseconds; no I/O, clock, or randomness without injection; ~80% branch coverage on logic-heavy modules as a guide, not a target |
| **Integration** | Real boundaries — real DB, cache, broker | Ephemeral containers (e.g. Testcontainers); **do not mock what we own** |
| **Contract** | Cross-service compatibility | Consumer-driven contracts; a producer cannot ship a breaking change without the consumer contract failing in CI |
| **E2E** | 5–10 critical user journeys | Production-like environment on a deploy gate; not feature parity |
| **Exploratory** | Human investigation, ad-hoc paths | A scheduled activity, not "if there's time" |

### Principles

- **Quality is the whole team's responsibility.** Engineering owns automated tests (unit/integration/contract); QA owns quality strategy, exploratory testing, E2E curation, and release-readiness sign-off. Both own the result.
- **Every bug is a missing test.** A regression that escapes gets a test in the **same PR as the fix**.
- **Test behaviour, not implementation.** Refactoring must not break tests that did not change behaviour.
- **Mock at boundaries we do not own**, not at the boundaries we do. Mocking our own repositories is a smell.
- **Tests are deterministic.** A flaky test is a broken test. **Flaky E2E tests are quarantined within 24 hours** and fixed within a week — never silenced indefinitely.
- **Fast feedback over thorough late feedback.** Unit + integration run locally before push; CI mirrors local (same images/scripts).

### Test Data

- **Synthetic data first.** Production data is not used in non-production environments without reviewed anonymization (scramble names/emails/IDs/financials; preserve relationships).
- **Factories in code** produce realistic shapes; each test sets up and tears down its own state. No hand-edited rows in shared environments.

### Definition of Test-Complete

A change is test-complete when: unit tests exist for new and affected logic; integration tests exist for any new/changed boundary; contract tests pass where relevant; a regression test exists for any fixed bug; the suite is green locally and in CI; and, where a QA partner exists, they agree no further coverage is required.

> Language-specific mechanics live in domain skills — e.g. `pytest-testing` for Python, `tdd-cpp` for C++.

## Self-Reflection Clause

After a bug that tests didn't catch:
1. **Why didn't a test catch this?** — Missing coverage, wrong assertion, or wrong test?
2. **Write the test now** — Add it to prevent regression.
3. **Update the knowledge base** — Add the pattern to `docs/learning/` if it's a recurring gap.
