# Digital-Twin Testing Design — Lima VM Harness

## 1. Overview

The digital-twin testing harness is an arm64 Ubuntu integration twin designed to exercise the `setup-floci.sh` installer's control-plane behavior. It provides a high-fidelity environment for validating systemd-logind interaction, lingering, rootless Podman configuration, AppArmor enforcement, Quadlet unit generation, UFW/nftables rule generation, and reboot autostart.

The twin is not an exact x86_64 runtime twin. While the guest and the native Floci runtime within the twin are arm64, architecture-specific behavior of Floci or its sidecars on x86_64 is out of scope. Such behavior must be validated on an x86_64 host. Because the installer itself is arch-agnostic bash, its logic is fully covered by the arm64 twin.

## 2. Architecture

The harness orchestrates interaction between the macOS host and a Lima-managed Ubuntu guest.

```
┌─────────────────────────────────────────────────────────┐
│  macOS Host (Apple Silicon)                             │
│                                                         │
│  ┌──────────────────────┐      ┌─────────────────────┐  │
│  │ mock-server/         │      │ .cache/tianlu-twin/ │  │
│  │   run-test.sh        │─────▶│   evidence/         │  │
│  └──────────┬───────────┘      └──────────▲──────────┘  │
│             │                             │             │
│             │ SSH (vsock) / systemd-run   │ 9p          │
│             ▼                             │ (rw)        │
└─────────────┼─────────────────────────────┼─────────────┘
              │                             │
┌─────────────┼─────────────────────────────┼─────────────┘
│  Lima VM (Ubuntu 26.04 arm64)             │
│                                           │
│  ┌──────────────────────┐      ┌──────────┴──────────┐  │
│  │ /opt/tianlu (repo)   │      │ /opt/twin-evidence  │  │
│  │ (9p ro mount)       │      │ (staging area)      │  │
│  └──────────┬───────────┘      └──────────▲──────────┘  │
│             │                             │             │
│             │ driver launch               │ writes      │
│             ▼                             │             │
│  ┌────────────────────────────────────────┴──────────┐  │
│  │ mock-server/in-vm/run-in-vm.sh                    │  │
│  │ (Guest Driver)                                    │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

The design is SSH-independent for result reporting. The host orchestrator (`run-test.sh`) launches the guest driver via `systemd-run` as a transient unit. The driver writes results to a staging directory on a `9p` mount. This mount is pinned so that guest writes survive the enablement of the UFW firewall, which would otherwise block SSH-based file transfers. The driver signals completion by writing an atomic sentinel file and a SHA256 manifest. The host polls the mount and publishes evidence via host-side `cp`.

## 3. Fidelity to the production server

The harness reproduces the following production server characteristics:

- **User session management:** `user@<UID>.service`, `loginctl` lingering, and user D-Bus/runtime directories.
- **Container runtime:** Rootless Podman with `subuid`/`subgid` mapping, `podman.socket`, and `floci-net` network with `pasta`/`slirp4netns` stack.
- **Service orchestration:** Quadlet `.container` unit generation and systemd user service lifecycle.
- **Security:** AppArmor `apparmor_restrict_unprivileged_userns` enforcement and profile installation.
- **Firewall:** UFW/nftables rule generation and state verification.
- **Configuration:** Managed `/etc/hosts` blocks and `/etc/subuid`/`/etc/subgid` semantics.

### 3.1 CPU architecture

The twin runs on arm64 (guest and host), while the production server is x86_64. The `setup-floci.sh` installer is arch-agnostic bash. The Floci compat image is multi-arch and resolves natively on arm64, ensuring the gating path does not require Rosetta. An optional, non-gating x86_64 diagnostic lane is available via Rosetta where required.

### 3.2 Networking

The twin uses Lima's NAT/vsock networking. While UFW/nftables rule generation is faithfully exercised and verified, packet-level enforcement against physical LAN source paths is not fully reproducible in the VM environment. UFW is validated at the rule-generation level. An optional packet-level ingress test is performed when the Lima network configuration permits both an allowed and a denied source class.

### 3.3 Runtime behavior

Architecture-specific behavior of Floci or its sidecar containers on x86_64 is out of scope for the integration twin and must be verified on native hardware.

## 4. Components

The harness consists of the following components:

- **`mock-server/lima/floci-twin.yaml`:** The VM definition. It specifies `vmType: qemu` (the macOS `vz` backend blocks unprivileged user-namespace creation inside the guest, which rootless Podman requires), `arch: aarch64`, and `mountType: 9p` (a non-SSH mount transport so guest writes survive UFW enable; `virtiofs` would require `vz`). It targets Ubuntu 26.04 arm64. Provisioning installs only operator-prerequisite packages (`curl`, `ca-certificates`, `apparmor`, `apparmor-utils`, `ufw`, `nftables`) to ensure the installer's `install_podman` logic is genuinely exercised.
- **`mock-server/in-vm/lib/assert.sh`:** A library of pure bash helpers and the `run_as_floci_guest` helper, which mirrors the `run_as_floci` pattern in the installer for consistent privilege drop.
- **`mock-server/in-vm/run-in-vm.sh`:** The guest driver. It performs preflight checks, establishes operator prerequisites, executes the installer (Run-1), validates sidecar spawning, verifies semantic convergence (Run-2), and redacts secrets from evidence.
- **`mock-server/run-test.sh`:** The host orchestrator. It manages the VM lifecycle, launches the guest driver, polls for the completion sentinel, and validates the evidence manifest.
- **`mock-server/evidence/<UTC-ts>/`:** A git-ignored directory containing the redacted evidence bundle and `summary.md`.

## 5. How to run

Prerequisites:
- Lima on Apple Silicon (macOS 13+).
- Installation: `brew install lima`.

To execute the harness:
```bash
./mock-server/run-test.sh --fresh --reboot-test
```

Flags:
- `--fresh`: Recreate the VM from scratch.
- `--keep`: Retain the VM after the test (default).
- `--destroy`: Delete the VM after the test.
- `--no-sidecar`: Skip Lambda sidecar validation.
- `--reboot-test`: Perform a reboot and verify autostart.
- `--evidence-dir`: Override the default evidence destination.

Evidence is published to `mock-server/evidence/<UTC-ts>/`.

## 6. Evidence & acceptance criteria

The harness evaluates success based on the following criteria recorded in `summary.md`:

- **`preflight-ok`:** Environment supports systemd, AppArmor, and UFW.
- **`run1-exit-0`:** Initial installation completes successfully.
- **`floci-service-active`:** The `floci.service` is running in the user session.
- **`health-200`:** The Floci health endpoint is reachable and returns HTTP 200.
- **`s3-smoke`:** S3 bucket creation and listing succeed via the sidecar.
- **`sidecar-delta`:** Podman events confirm sidecar container creation and start.
- **`run2-exit-0`:** Idempotent re-run completes successfully.
- **`idempotency-hosts`:** `/etc/hosts` contains exactly one managed block.
- **`idempotency-subuid`:** `/etc/subuid` contains exactly one `floci` entry.
- **`idempotency-hashes`:** Sensitive configuration hashes (env, container unit) remain unchanged.
- **`reboot-health-200`:** Floci is healthy after a VM reboot.
- **`reboot-ordering`:** Journal evidence proves `podman.socket` starts before `floci.service`.

Verification includes validating the `manifest.sha256` using `sha256sum -c`. Secrets such as `FLOCI_AUTH_PRESIGN_SECRET` are redacted from all published evidence.

## 7. Relationship to the `tests/` bats suite

The `tests/` directory contains unit tests for the harness logic itself, such as argument parsing and helper functions. These tests use stubs for system commands (`limactl`, `podman`, `curl`, `nft`) on the `PATH`. The twin harness is the integration deliverable that provides end-to-end validation of the installer.

## 8. Coverage of `gaps-register.md`

The harness addresses specific gaps identified in the register:

- **GAP-009:** Captures the response body of the `/_floci/init` endpoint to `health-init.json` for documentation (capture-only, no content assertion).
- **GAP-014:** Proves reboot autostart and Quadlet dependency ordering. The harness verifies that `After` and `Requires` directives in the unit are respected and that the journal shows the correct socket-to-service sequence.

GAP-013b (EKS/k3s workload network exposure) remains out of scope and requires validation on the production x86_64 server.

## 9. Implementation

The build steps for this harness are in [docs/design/digital-twin-testing-plan.md](digital-twin-testing-plan.md).
