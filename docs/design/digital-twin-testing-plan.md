# Digital-Twin Testing Plan — Implementation Roadmap

This is the implementation plan for the [digital-twin testing harness](digital-twin-testing-design.md).

## 1. Prerequisites

The implementation requires a macOS host (13+) on Apple Silicon with the following tools:
- **Lima:** `brew install lima` (minimum version 2.0.0).
- **Testing:** `shellcheck` and `bats-core` for harness unit tests.

## 2. Architecture Framing

The harness is built as an arm64 integration twin using the Lima `vz` backend. It runs native arm64 Ubuntu and Floci images.
- **Installer:** The `setup-floci.sh` script is arch-agnostic bash, allowing its logic to be fully exercised on arm64.
- **Diagnostic Lane:** An optional x86_64 lane using Rosetta is supported for non-gating diagnostic checks, verified via `/proc/sys/fs/binfmt_misc/rosetta`.

## 3. Phased Build Steps

### 3.1 Scaffolding
- Establish the directory structure under `mock-server/`.
- Create `mock-server/in-vm/lib/` for shared guest helpers.
- Configure `.gitignore` to exclude the `evidence/` directory and `.cache/` artifacts.

### 3.2 Twin Definition
- Implement `mock-server/lima/floci-twin.yaml`.
- Configure `9p` mounts for the repository (read-only) and evidence staging (read-write).
- Define the provisioning script to install operator prerequisites (`ufw`, `nftables`, `apparmor`) while ensuring Podman is absent to test the installer's installation logic.

### 3.3 Guest Driver
- Implement `mock-server/in-vm/run-in-vm.sh`.
- Implement `run_as_floci_guest` to mirror the installer's `run_as_floci` pattern, ensuring every Podman or systemd user command is executed with the correct environment (HOME, XDG_RUNTIME_DIR, DBUS_SESSION_BUS_ADDRESS).
- Implement preflight checks for AppArmor userns restrictions.
- Implement semantic-convergence checks that snapshot the environment and compare state between successive runs.

### 3.4 Host Orchestrator
- Implement `mock-server/run-test.sh`.
- Use `systemd-run --wait` to launch the guest driver, ensuring the host waits for completion without relying on persistent SSH sessions that could be interrupted by UFW.
- Implement the polling mechanism for the `DONE` sentinel and the manifest validation.

### 3.5 Verification & Acceptance
- Unit testing: `make lint` (shellcheck) and `bats mock-server/tests`.
- Integration: Execution of `./mock-server/run-test.sh --fresh --reboot-test` resulting in a `TWIN: PASS` verdict.

## 4. Semantic Convergence Snapshot

The harness verifies idempotency by snapshotting the following surface area:
- The managed block in `/etc/hosts`.
- `floci` user tuples in `/etc/subuid` and `/etc/subgid`.
- UFW numbered status and AppArmor profile presence.
- User lingering state and `floci.service` activation status.
- SHA256 hashes of `floci.env` and `floci.container`.

The check excludes `.bak` files, which are treated as volatile backup artifacts.

## 5. Evidence Design

Evidence is managed through a staged publication design:
1. **Staging:** The guest driver writes all logs, snapshots, and redacted configuration to the `9p` mount.
2. **Atomic Sentinel:** After the driver completes all tasks, it writes `manifest.sha256` followed by a `DONE` sentinel file.
3. **Publication:** The host orchestrator detects the sentinel, validates the manifest using `sha256sum -c`, and performs a host-side `cp` from the mount to the final timestamped evidence directory.

This design ensures that partial or corrupted evidence is never published as a successful run.
