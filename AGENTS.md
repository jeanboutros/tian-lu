# AGENTS.md

## Project

Infrastructure setup scripts for deploying Floci (AWS emulator) on Ubuntu Server using rootless Podman. No application code — bash scripts and scraped documentation only.

## Key files

- `setup-floci.sh` — main script (skeleton, implementation pending). Creates `floci` user, installs rootless Podman, configures Floci container with persistent storage + TLS, systemd user service, UFW firewall rules. Must be idempotent.
- `REVIEW.md` — design rationale, challenger review findings, corrected configuration. **Read this before editing `setup-floci.sh`** — it explains why each config value is what it is.
- `docs/design/` — design documents:
  - `solution-design.md` — full solution architecture for the Floci setup.
  - `dnsmasq-design.md` — LAN-wide DNS design for `tianlu-floci` → server IP (future stage).
  - `gaps-register.md` — unresolved items requiring runtime testing (open gaps remain; see this file for the current count).
  - `digital-twin-testing-design.md` — design for the Lima digital-twin VM harness that validates `setup-floci.sh` end-to-end.
  - `digital-twin-testing-plan.md` — implementation plan for the digital-twin harness.
- `docs/scraped/` — scraped Floci documentation (9 pages). Use `docs/scraped/INDEX.md` for keyword-based lookup; it maps topics to specific files.
- `mock-server/` — Lima digital-twin harness. `lima/floci-twin.yaml` (twin definition), `in-vm/lib/assert.sh` (helpers incl. `run_as_floci_guest`), `in-vm/run-in-vm.sh` (guest driver), `run-test.sh` (host orchestrator), `evidence/` (git-ignored run artifacts). Run with `make twin-test`. See `docs/design/digital-twin-testing-design.md`.

## Critical gotchas

- **The Podman container must be named `tianlu-floci`** (matching `FLOCI_HOSTNAME`). Podman container DNS resolves the `--name` flag, not `FLOCI_HOSTNAME`. If they don't match, Lambda callback URLs and sidecar DNS resolution silently fail.
- **`FLOCI_STORAGE_PERSISTENT_PATH` is a container-side path** (`/app/data`), not a host path. The host path goes in `FLOCI_STORAGE_HOST_PERSISTENT_PATH` and is bind-mounted to the container path. Confusing these breaks persistence silently.
- **`FLOCI_HOSTNAME` must be hyphenated, not dotted.** Dotted names (e.g. `tianqi.floci`) don't resolve in Podman container DNS. Current value: `tianlu-floci`.
- **Rootless Podman requires two env vars that the Floci docs don't set by default:** `FLOCI_SERVICES_LAMBDA_DOCKER_NETWORK` (pre-created `floci-net`) and `FLOCI_SERVICES_LAMBDA_DOCKER_HOST_OVERRIDE` (for Lambda Runtime API callback). Do NOT set `FLOCI_DOCKER_DOCKER_HOST` — the socket is mounted at `/var/run/docker.sock` inside the container and Floci's default picks it up. See `docs/scraped/docker-configuration.md` — "Running on Podman (rootless)" section.
- **The Podman socket mount needs `:z`** (SELinux shared relabel), not `:Z`. On Ubuntu (no SELinux) it's a no-op but harmless and keeps the config portable to RHEL/Fedora.
- **Do NOT add ports 5100-5199 to the container's `-p` flags.** ECR sidecar binds directly on the host; adding them to Floci's port list causes conflicts and breaks `docker push`/`pull`.
- **The `floci` user uses `/bin/bash` with a locked password**, not `/usr/sbin/nologin`. A nologin shell prevents `systemd --user` from starting, which breaks rootless Podman.
- **`MemoryDenyWriteExecute` must NOT be set** in the systemd unit — Floci is JVM-based and will crash.
- **`RestrictNamespaces=yes` must NOT be set** in the systemd unit — Podman requires namespace creation to run rootless containers.
- **Ubuntu 23.10+ blocks unprivileged userns by default** via `kernel.apparmor_restrict_unprivileged_userns=1`, which makes rootless Podman fail at namespace setup (`could not create user namespace: Operation not permitted`). `assert_userns_allowed` (Phase 1) fixes this by installing a **scoped** AppArmor profile at `/etc/apparmor.d/podman-userns` granting only `userns` to `/usr/bin/podman` (and `crun`/`pasta` if present), loaded via `apparmor_parser -r`. It must **NEVER** set the sysctl to `0` or use `--security-opt apparmor=unconfined` — that breaches least privilege. Idempotent: no-op when a permitting profile is already loaded or the restriction is not in force. See `solution-design.md` §11.2.
- **The systemd unit is a Quadlet `.container`**, not a hand-written `.service` — it lives at `~/.config/containers/systemd/floci.container` and is activated with `systemctl --user daemon-reload` + `start floci.service` (Quadlet generates `floci.service`). Quadlet units are **transient** and CANNOT be `systemctl enable`d ("Unit … is transient or generated") — boot autostart is declared by `[Install] WantedBy=default.target` inside the `.container`. `podman generate systemd` is deprecated; do NOT use it. Quadlet auto-wires `--sdnotify=conmon` and same-name stale-container cleanup, so there is no `ExecStartPre`/`ExecStop`/`--rm`.
- **`ReadWritePaths` must be `%h %t`, not just `%h`.** Under `ProtectSystem=strict`, `/run/user/<UID>` (`%t`) — where the Podman runtime and mounted socket live — would be read-only and the container fails to start.
- **`ProtectHome` must NOT be set** — `ProtectHome=yes` masks `/home` entirely and `ReadWritePaths` cannot override it. The data dir and env file live under `/home/floci`; rely on `0700` permissions instead.
- **`PrivateNetwork` must NOT be set** — it breaks rootless container networking.
- **Multi-account isolation is automatic** via 12-digit AKIDs. There is no config flag to "enable" it.
- **`run_as_floci` helper must set `HOME`, `USER`, `PATH`, `XDG_RUNTIME_DIR`, and `DBUS_SESSION_BUS_ADDRESS`.** Missing `HOME` causes rootless Podman to read the wrong `~/.config/containers/` directory.
- **The script must poll for the user manager after `loginctl enable-linger`.** `enable-linger` starts the manager asynchronously. Poll `systemctl is-active --quiet user@<UID>.service` then `systemctl --user -M floci@.host is-active --quiet default.target`. Do NOT use `is-system-running` (fails on `degraded`).
- **`verify_health` must use `curl --resolve tianlu-floci:4566:127.0.0.1 -k`** — not `https://localhost`. This sends the correct `Host:` header, matches the cert SAN, and avoids needing DNS resolution.
- **The script adds `127.0.0.1 tianlu-floci` to `/etc/hosts`** with a managed marker block for host-side tooling. dnsmasq is NOT a prerequisite.

## Script conventions

- `set -euo pipefail` + `IFS=$'\n\t'` — fail fast.
- All parameters are `readonly` in a single configuration block at the top, using the `readonly VAR="${VAR:-default}"` form so tests can inject overrides (e.g. a tmp `HOME`/root) before sourcing.
- Each phase is a separate small function with pydoc-style documentation.
- Every function must be idempotent (check before create/modify).
- Privilege model: root/sudo for setup steps (useradd, apt, ufw), then drop to `floci` user for Podman/systemd --user operations via a `run_as_floci` helper that sets `XDG_RUNTIME_DIR` and `DBUS_SESSION_BUS_ADDRESS`.

## Testing

Local tests run on macOS; the Ubuntu-only runtime (Podman/systemd/UFW) is mocked.

- `make lint` — `shellcheck` + `bash -n` on `setup-floci.sh`.
- `make test` — `bats` unit tests in `tests/`. External commands (`podman`, `systemctl`, `loginctl`, `ufw`, `apt-get`, `useradd`, `passwd`, `openssl`, `curl`, `apparmor_parser`, …) are replaced by logging stubs on `PATH` (`tests/stubs/bin/`), so tests assert *what the script would run* and drive idempotency branches.
- `make check` — both. Requires `shellcheck` and `bats-core` (`brew install shellcheck bats-core`).
- `make twin-test` — runs `mock-server/run-test.sh`, the Lima digital-twin harness. Requires Lima on Apple Silicon (macOS 13+). Builds/boots a headless Ubuntu arm64 VM, runs `setup-floci.sh` inside it, drives it to a live Floci + an arm64 Lambda sidecar, re-runs for idempotency (semantic convergence), optionally reboots for boot-autostart + Quadlet ordering, and writes a manifest-validated evidence bundle. The twin is an arm64 integration twin; architecture-specific Floci/sidecar runtime behavior on x86_64 is out of scope. See `docs/design/digital-twin-testing-design.md`.
- The script is **sourceable** (guarded `main` at the bottom: `if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then main "$@"; fi`) so bats can load functions without executing them.
- Runtime behaviour that cannot be mocked is covered by the Lima digital twin (`make twin-test`); remaining x86_64-runtime-specific gaps are tracked in `docs/design/gaps-register.md`.

## Target environment

- Ubuntu 26.04 LTS, x86_64
- Multi-user server (home dir `0700`, subuid range collision check required)
- Firewall: UFW only (never mix raw iptables with ufw)
- Image: `floci/floci:1.5.33-compat` (pinned, compat variant includes AWS CLI + boto3)

## Future stage

- `setup-dnsmasq.sh` — LAN-wide DNS for `tianlu-floci` → server IP. Not a prerequisite; Floci works on localhost without it. See `docs/design/dnsmasq-design.md`.

## Open gaps

See `docs/design/gaps-register.md` for open risks, limitations, and unresolved items.