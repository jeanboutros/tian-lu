# AGENTS.md — mock-server/

## OVERVIEW
Lima/QEMU digital-twin harness that drives `setup-floci.sh` end-to-end on a real Ubuntu VM, plus a persistent dev twin for hands-on iteration. Misleading name: NOT an HTTP mock server.

## STRUCTURE
```
mock-server/
├── run-test.sh          # Host orchestrator (test twin, 563L)
├── dev-twin.sh          # Dev lifecycle (538L)
├── lima/
│   ├── floci-twin.yaml  # QEMU, rootless-userns, 9p evidence, arm64
│   └── floci-dev.yaml   # Persistent dev VM (port forwards + 9p)
├── in-vm/
│   ├── run-in-vm.sh     # Guest driver (357L)
│   └── lib/assert.sh    # Guest helpers incl. run_as_floci_guest
├── tests/               # bats harness tests + stubs/bin/
└── evidence/            # git-ignored local mirror (see CONVENTIONS)
```

## WHERE TO LOOK
| Task | File |
|---|---|
| Add a new test phase (reboot, idempotency) | `run-test.sh` orchestrator + `in-vm/run-in-vm.sh` driver |
| Add a guest-side assertion or fixture | `in-vm/lib/assert.sh` (helpers), `in-vm/run-in-vm.sh` (phases) |
| Change evidence artifact (new file captured) | `in-vm/run-in-vm.sh` writer + `run-test.sh` manifest stage |
| Tweak Lima VM (disk, ports, mounts) | `lima/floci-twin.yaml` (test) or `lima/floci-dev.yaml` (dev) |
| Add dev-twin command (`make dev-X`) | `dev-twin.sh` + `../Makefile` target |
| Test the harness itself | `tests/*.bats` with `tests/stubs/bin/` on PATH |
| Design rationale / findings | `../docs/design/digital-twin-{design,findings}.md` |

## CONVENTIONS

**9p evidence staging.** Guest writes evidence files into a 9p mount (`/opt/tianlu/evidence`), not over the network. 9p survives UFW (no firewall hole needed) and avoids Lima's `sshfs` quirks on macOS. `run-test.sh` waits for `DONE` sentinel on 9p, then copies to host + seals `manifest.sha256`. Do not switch to `sshfs` or `rsync` — re-introduces the very issue 9p was chosen to fix.

**Guest driver runs as transient systemd unit.** `run-test.sh:194` invokes `sudo systemd-run --quiet --wait --unit=tianlu-driver -- /opt/tianlu/mock-server/in-vm/run-in-vm.sh ...`. The driver runs as root inside the unit, not under the Lima-pinned user. Always verify Lima-pinned identity via `getent passwd <user>` (uid), never `whoami`.

**Evidence dual-location.** `evidence/` in-repo is git-ignored and a convenience mirror. Authoritative copy is `~/.cache/tianlu-twin/evidence/<UTC-timestamp>/` (overridable via `EVIDENCE_DIR_ROOT` / `--evidence-dir=`). The timestamp directory is sealed by `sha256sum -c manifest.sha256`; the manifest deliberately excludes its own `.tmp` sidecar to prevent self-referential entries. Override location when debugging, but always read from the canonical cache path in CI.

**Manifest-validated evidence.** Every run produces `manifest.sha256` listing all staged files. `run-test.sh:272` runs `sha256sum -c` and treats failure as `FAIL_REASON='evidence manifest validation failed'`. When adding a new evidence file, write it to `$EVIDENCE_STAGING` on 9p (not to a host path) so it lands in the manifest.

**Test twin vs dev twin share zero state.** `floci-twin` (disposable, `make twin-test`) and `floci-dev` (persistent, `make dev-*`) are separate Lima instances with separate disks, separate user managers, separate Quadlets. Edits to one never affect the other. Do not add cross-references between `run-test.sh` and `dev-twin.sh`.

**Test twin purges podman to exercise installer.** `run-test.sh:328` runs `run_as_floci_guest podman rm -f tianlu-floci` on reboot to force the installer through `install_podman()` and prove Quadlet ordering survives a fresh container. Keep this purge — removing it lets a stale container mask boot-autostart regressions. The dev twin never purges; `make dev-recreate` rebuilds from current checkout.

**Stubs are harness-specific, not installer stubs.** `tests/stubs/bin/` shadows `limactl`, `systemd-run`, `systemctl`, `getent`, `sha256sum`, etc. for harness testing. These are unrelated to `../tests/stubs/bin/` (which mocks the installer). The two stub trees are independent — keep them separate.
