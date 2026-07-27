# Testing Guide — `setup-floci.sh`

This guide explains the three test tiers, how to run each, and how to wire
them so they run automatically after **every change to `setup-floci.sh`** —
locally before a commit (pre-commit hook) and before pushing (`make twin-test`).

For the design of each tier see:
- Unit tests — `tests/` (mocked, fast; pattern documented in `AGENTS.md`).
- Harness unit tests — `mock-server/tests/` (mocked Lima/podman logic).
- End-to-end twin — `docs/design/digital-twin-testing-design.md`.
- Findings the twin has surfaced — `docs/design/digital-twin-findings.md`.

---

## 1. The three tiers

| Tier | Command | What it checks | Where it runs | Cost |
| --- | --- | --- | --- | --- |
| **1. Lint** | `make lint` | `shellcheck` + `bash -n` on `setup-floci.sh` and every harness script | macOS/Linux, no VM | seconds |
| **2. Unit (bats, stubbed)** | `make test` | installer logic + harness logic with `podman`/`systemctl`/`limactl`/`curl`/`nft`/`ufw`/`apparmor_parser`/… replaced by logging PATH stubs | macOS/Linux, no VM | seconds |
| **3. End-to-end twin** | `make twin-test` | builds a headless Ubuntu arm64 Lima VM, runs `setup-floci.sh` as sudo, drives to a live Floci (HTTP 200 + arm64 Lambda sidecar), re-runs for idempotency (semantic convergence), reboots for boot-autostart + Quadlet ordering, writes a manifest-validated evidence bundle | macOS 13+ Apple Silicon with Lima + QEMU | ~15–30 min |

Tier 3 is the one that catches real runtime bugs (it surfaced 13 installer
bugs that tiers 1–2 missed — see `digital-twin-findings.md`). Tiers 1–2 are
fast regression guards for the logic and the findings' regression tests.

### Prerequisites

```bash
brew install shellcheck bats-core lima qemu    # tiers 1–3 on macOS/Apple Silicon
# Linux dev box: apt-get install shellcheck bats-core ; tiers 1–2 only (twin is macOS-only)
```

---

## 2. Running each tier manually

### Tier 1 — lint

```bash
make lint
```

Runs `shellcheck` and `bash -n` over `setup-floci.sh`, the stubs, and every
harness script (`mock-server/run-test.sh`, `mock-server/in-vm/run-in-vm.sh`,
`mock-server/in-vm/lib/assert.sh`, the harness stubs). Zero findings is the
pass bar.

### Tier 2 — unit tests

```bash
make test
```

Runs `bats tests/` (installer unit tests) and `bats mock-server/tests/`
(harness unit tests). External commands are logging stubs on `PATH`
(`tests/stubs/bin/`, `mock-server/tests/stubs/bin/`), so tests assert *what
the script would run* and drive idempotency branches without a VM. No real
`podman`/`limactl` is invoked.

### Tier 3 — end-to-end Lima twin

```bash
make twin-test
# or, with explicit flags:
./mock-server/run-test.sh --fresh --reboot-test
```

`make twin-test` is the canonical one-command run. Flags:

| Flag | Effect |
| --- | --- |
| `--fresh` | Delete and recreate the twin from the template (use after a `setup-floci.sh` change so the run starts clean). |
| `--keep` | Reuse the existing twin (faster, but state from a prior run may mask a regression — prefer `--fresh` for change validation). |
| `--destroy` | Stop and delete the twin after the run (frees disk; use in CI). |
| `--no-sidecar` | Skip the Lambda sidecar smoke test (faster; notes it in `summary.md`). |
| `--reboot-test` | After a passing run, stop + restart the twin and verify boot autostart + Quadlet socket ordering. |
| `--evidence-dir=<path>` | Override the host evidence destination. |

The script prints `TWIN: PASS` or `TWIN: FAIL` and exits 0/1. Evidence lands
in `mock-server/evidence/<UTC-ts>/` (git-ignored) and
`~/.cache/tianlu-twin/evidence/<UTC-ts>/`. The `summary.md` criterion
checklist is the human-readable verdict; `sha256sum -c manifest.sha256`
validates the bundle integrity.

> **After editing `setup-floci.sh`, always run with `--fresh`.** A `--keep`
> run reuses a twin whose state was produced by the *previous* installer
> version and can mask regressions (e.g. a function you changed may have
> already-mutated state in the kept twin).

---

## 3. Run after every change to `setup-floci.sh`

Two layers: a local pre-commit hook (fast feedback before you commit) and a
remote CI workflow (authoritative check on push/PR). Both are wired to fire
when `setup-floci.sh` (or the harness) changes.

### 3.1 Local — pre-commit hook

A git pre-commit hook runs tiers 1 and 2 on every commit. They are fast
(seconds) and catch most logic regressions locally before the slow twin run.
Tier 3 is intentionally **not** in the pre-commit hook (15–30 min is too
slow for an interactive commit); run `make twin-test` manually before
pushing.

To install the hook (one-time, per clone):

```bash
cp scripts/pre-commit .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

The hook (`scripts/pre-commit`) is committed to the repo so every clone can
install it. It:
1. Runs `make lint` and `make test`.
2. If `setup-floci.sh` or any harness script is staged, prints a reminder to
   run `make twin-test` before pushing (does not block — the twin is slow).
3. Exits non-zero if lint or tests fail, aborting the commit.

To bypass in an emergency: `git commit --no-verify` (use sparingly; CI will
still enforce).

### 3.2 Remote — GitHub Actions CI

`.github/workflows/test.yml` has one hosted job: `lint-and-unit`.

- **lint-and-unit** (runs on every push/PR, ~30 s): `make lint` + `make test`
  on an Ubuntu runner. This is the always-on gate.

The twin is **not** in hosted CI. GitHub's `macos-14` runner is M1, and
Apple's Virtualization.framework does not expose nested virtualisation to M1
runner VMs, so QEMU fails immediately with `HV_UNSUPPORTED`. Nested virt on
Apple silicon needs M3+ and macOS 15+, which GitHub's hosted fleet does not
offer yet.

Run `make twin-test` locally before pushing any `setup-floci.sh` or harness
change.

Future path: a self-hosted x86_64 Linux runner with `/dev/kvm` could run the
twin in CI. The harness is portable; install `lima` + `qemu` on the runner and
point the job at a self-hosted `ubuntu-latest` machine.

Enable branch protection → required status checks → `lint-and-unit` (the only
hosted CI job).

---

## 4. What each tier catches (and what it does not)

- **Lint** catches syntax errors, unused vars, SC warnings. It does NOT
  catch runtime behavior.
- **Unit (stubbed)** catches: arg-parsing regressions, idempotency-branch
  logic, the exact `podman`/`systemctl`/`apparmor_parser` commands the
  installer would run, the Quadlet `[Service]` directive set (the
  rootless-incompatible directives are asserted ABSENT), the `UserNS=keep-id`
  line, the `env`-without-`--` form, the `abi/5.0` profile line, etc. It does
  NOT catch: real Podman/systemd/AppArmor interactions, boot timing, uid
  mapping.
- **Twin** catches the real runtime bugs tiers 1–2 cannot — every finding in
  `digital-twin-findings.md` was surfaced by the twin. It does NOT catch
  x86_64-runtime-specific Floci/sidecar behavior (the twin is arm64); those
  must be validated on the x86_64 server.

So: **edit `setup-floci.sh` → `make check` (lint+unit) locally → commit →
`make twin-test` locally → push.** If the twin passes, the
installer's control-plane behavior is validated for the production server's
OS stack; only x86_64-runtime specifics remain to check on the real server.

---

## 5. Interpreting twin evidence on a failure

When `make twin-test` prints `TWIN: FAIL`, open the latest
`mock-server/evidence/<UTC-ts>/`:

- `summary.md` — which criterion failed (the checklist).
- `FAILED` sentinel (in staging) — the driver's failure reason.
- `run1.log` / `run2.log` — full installer output for Run-1 / Run-2.
- `semantic-convergence-diff.txt` — non-empty means Run-1 vs Run-2 state
  diverged (an idempotency regression).
- `reboot-journal.log` — post-reboot `floci.service` journal (boot-autostart
  + ordering).
- `podman-events.ndjson` — sidecar create/start events.
- `floci.env` (redacted), `floci.container`, `ufw-status.txt`,
  `apparmor-profiles.txt`, `podman-userns-profile.txt`,
  `service-journal.log` — the actual generated state.

For the known twin-fidelity limit (reboot-health-200 under the Lima AppArmor
boot-race), see `docs/design/digital-twin-findings.md` §9 and
`docs/design/gaps-register.md` GAP-014 — that specific failure is a nested-VM
quirk, not an installer bug.

---

## 6. Quick reference

```bash
# Fast local loop (seconds) — run before every commit:
make check              # = make lint && make test

# Full validation (15–30 min) — run before pushing a setup-floci.sh change:
make twin-test          # = ./mock-server/run-test.sh --fresh --reboot-test

# Install the pre-commit hook (one-time per clone):
cp scripts/pre-commit .git/hooks/pre-commit && chmod +x scripts/pre-commit .git/hooks/pre-commit

# Inspect the latest evidence after a twin run:
ls -dt mock-server/evidence/*/ | head -1
```

| You changed… | Run |
| --- | --- |
| `setup-floci.sh` (any phase) | `make check` → `make twin-test` |
| `mock-server/**` (harness) | `make check` → `make twin-test` |
| `tests/**` (unit tests) | `make test` |
| `docs/**` only | nothing (no twin run needed; CI runs lint+unit regardless of path) |

---

## 4. Local development environment

For interactive local AWS development (not testing), use the persistent dev twin. Unlike the test twin, this environment persists AWS state across restarts.

```bash
brew install lima qemu   # one-time prerequisites
make dev-up              # create or resume (~30s resume, ~10-15 min first run)
eval "$(make dev-env -- --export)"  # load AWS CLI profile into this shell
make dev-status          # check instance, disk, service, and health
make dev-down            # stop without losing data
make dev-recreate        # rebuild VM OS, keep all AWS data
make dev-reset CONFIRM=reset  # erase VM and all AWS data (permanent)
```

See `mock-server/README.md` for the complete target reference and `AGENTS.md` for gotchas.
