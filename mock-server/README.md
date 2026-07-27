# Lima digital-twin harness

## Persistent local development environment

A separate persistent dev environment is available for interactive local AWS development — distinct from the disposable test twin below.

| Target | What it does |
| --- | --- |
| `make dev-up` | Create or resume the dev VM; installs Floci only on first creation (QEMU backend) |
| `make dev-down` | Stop the VM; data preserved |
| `make dev-status` | Show instance, disk, service, and health state |
| `make dev-shell` | Open a shell inside the VM |
| `make dev-env` | Configure AWS CLI `floci-dev` profile and print export instructions |
| `make dev-recreate` | Rebuild VM OS; retain the `floci-dev-data` data disk |
| `make dev-reset CONFIRM=reset` | Delete VM **and** data disk — permanent |

**Important**: `make dev-up` does **not** rerun the installer on an existing VM. Use `make dev-recreate` to rebuild the OS from the current checkout while retaining data.

Quick start:
```bash
brew install lima qemu
make dev-up
eval "$(make dev-env -- --export)"   # load AWS_PROFILE, AWS_ENDPOINT_URL, AWS_DEFAULT_REGION
aws s3 ls                             # uses https://tianlu-floci:4566 with self-signed TLS
```

To inspect rootless Podman inside the VM:
```bash
make dev-shell
# inside the VM:
sudo -u floci env HOME=/home/floci XDG_RUNTIME_DIR=/run/user/$(id -u floci) podman ps
```

---

## Test twin (disposable, for CI validation)

A fully-scripted, headless **Lima VM running Ubuntu (arm64)** that reproduces
the production server's OS, `systemd`, rootless Podman, AppArmor, and UFW —
used to validate `setup-floci.sh` end-to-end before it runs on the real
x86_64 server.

This is an **arm64 Ubuntu integration twin for installer control-plane
behavior**: it faithfully exercises systemd-logind, lingering, rootless
Podman, AppArmor enforcement, Quadlet generation, UFW/nftables rule
generation, and reboot autostart. It is **not** an exact x86_64 runtime twin:
the guest and the native Floci runtime are arm64, so architecture-specific
Floci/sidecar runtime behavior on x86_64 is out of scope and must be
validated on an x86_64 host. The installer itself is arch-agnostic bash, so
its logic is fully covered. See
[`docs/design/digital-twin-testing-design.md`](../docs/design/digital-twin-testing-design.md)
for the full fidelity framing.

## Prerequisites

- macOS **13+** on **Apple Silicon** (the test twin uses **QEMU** full emulation — this allows rootless user-namespace creation inside the guest, which the Virtualization.framework backend blocks).
- Lima: `brew install lima`.
- `shellcheck` and `bats-core` for the unit tests (`brew install shellcheck bats-core`).

## Run

One command builds the twin, runs `setup-floci.sh` inside it, drives it to a
live Floci (HTTP 200 + an arm64 Lambda sidecar), re-runs it to prove semantic
convergence (idempotency), optionally reboots for boot-autostart + Quadlet
ordering, and writes a manifest-validated evidence bundle:

```bash
./mock-server/run-test.sh --fresh --reboot-test
```

> **Note (after updating Lima templates):** If you have an existing `floci-twin` Lima
> instance created before the `floci-runner` username was pinned, delete it first:
> `make twin-test TWIN_FLAGS="--fresh --destroy"`. The `--keep` default will fail
> the pinned-user preflight check until the instance is recreated.

### Flags

| Flag | Effect |
| --- | --- |
| `--fresh` | Delete and recreate the twin from the template (default behavior for a first run). |
| `--keep` | Reuse the existing twin (default). Mutually exclusive with `--fresh` in effect (`--fresh` wins). |
| `--destroy` | Stop and delete the twin after the run. |
| `--no-sidecar` | Skip the Lambda sidecar smoke test (notes it in `summary.md`). |
| `--reboot-test` | After a passing run, stop + restart the twin and verify boot autostart + Quadlet socket ordering. |
| `--evidence-dir=<path>` | Override the host evidence destination (default `~/.cache/tianlu-twin/evidence`). |

The script prints `TWIN: PASS` or `TWIN: FAIL` and exits 0/1 accordingly.

## Evidence

Each run writes a timestamped evidence bundle to
`mock-server/evidence/<UTC-ts>/` (git-ignored — run artifacts and secrets are
never committed). The bundle contains:

- `summary.md` — the named criterion checklist (`preflight-ok`, `run1-exit-0`,
  `floci-service-active`, `health-200`, `s3-smoke`, `sidecar-delta`,
  `run2-exit-0`, `idempotency-hosts`, `idempotency-subuid`,
  `idempotency-hashes`, `reboot-health-200`, `reboot-ordering`).
- `health-init.json` — the captured `/_floci/init` body (GAP-009, capture-only).
- `podman-events.ndjson` — sidecar create + start events (not `podman ps` sampling).
- `semantic-convergence-diff.txt` — Run-1 vs Run-2 state snapshot diff (empty = idempotent).
- `reboot-journal.log` — post-reboot journal proving `podman.socket` → `floci.service` ordering.
- `manifest.sha256` + a `DONE` sentinel — the host validates the manifest with
  `sha256sum -c` before issuing a verdict.
- Redacted `floci.env` (`FLOCI_AUTH_PRESIGN_SECRET` masked), `floci.container`,
  UFW rules, AppArmor profile, `/etc/hosts`, `/etc/subuid`, `/etc/subgid`,
  service status/journal, `podman ps`/`images`/`info`, twin arch info.

## Design docs

- [`docs/design/digital-twin-testing-design.md`](../docs/design/digital-twin-testing-design.md) — what the twin is.
- [`docs/design/digital-twin-testing-plan.md`](../docs/design/digital-twin-testing-plan.md) — how it is built.
