# AGENTS.md

## Project

Infrastructure setup scripts for deploying Floci (AWS emulator) on Ubuntu Server using rootless Podman. No application code — bash scripts and scraped documentation only.

## Key files

- `setup-floci.sh` — main script (skeleton, implementation pending). Creates `floci` user, installs rootless Podman, configures Floci container with persistent storage + TLS, systemd user service, UFW firewall rules. Must be idempotent.
- `REVIEW.md` — design rationale, challenger review findings, corrected configuration. **Read this before editing `setup-floci.sh`** — it explains why each config value is what it is.
- `docs/design/` — design documents:
  - `solution-design.md` — full solution architecture for the Floci setup.
  - `landing-zone-design.md` — architecture of the Terraform AWS landing zone that runs *on* Floci (IAM delegation, hub-and-spoke, centralized EKS/k3s, RDS, environment=account, `infra/` layout, deploy steps).
  - `dnsmasq-design.md` — LAN-wide DNS design for `tianlu-floci` → server IP (future stage).
  - `gaps-register.md` — unresolved items requiring runtime testing (open gaps remain; see this file for the current count).
  - `digital-twin-testing-design.md` — design for the Lima digital-twin VM harness that validates `setup-floci.sh` end-to-end.
  - `digital-twin-testing-plan.md` — implementation plan for the digital-twin harness.
  - `digital-twin-findings.md` — root-cause analysis of every installer bug and rootless-Podman/systemd/AppArmor interaction the twin surfaced (symptom, mechanism, fix, regression guard). Long-form companion to the Critical gotchas below.
- `docs/scraped/` — scraped Floci documentation (9 pages). Use `docs/scraped/INDEX.md` for keyword-based lookup; it maps topics to specific files.
- `docs/testing-guide.md` — the three test tiers (lint, stubbed unit, Lima twin) and how to wire them to run after every `setup-floci.sh` change (pre-commit hook; the twin runs locally — CI covers lint+unit only).
- `scripts/pre-commit` — pre-commit hook (lint + unit tests); install with `cp scripts/pre-commit .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit`.
- `.github/workflows/test.yml` — CI: lint+unit on every push/PR only (twin is a local pre-push gate — see `docs/testing-guide.md`).
- `mock-server/` — Lima digital-twin harness. `lima/floci-twin.yaml` (twin definition), `in-vm/lib/assert.sh` (helpers incl. `run_as_floci_guest`), `in-vm/run-in-vm.sh` (guest driver), `run-test.sh` (host orchestrator), `evidence/` (git-ignored run artifacts). Run with `make twin-test`. See `docs/design/digital-twin-testing-design.md`.
- `mock-server/dev-twin.sh` — persistent local dev lifecycle script (`make dev-up`, `dev-down`, `dev-status`, `dev-shell`, `dev-recreate`, `dev-reset`, `dev-env`). Uses a separate `floci-dev` Lima instance; shares no state with the test twin (`floci-twin`).
- `mock-server/lima/floci-dev.yaml` — Lima template for the persistent dev VM (Ubuntu 26.04 arm64 QEMU, standalone `floci-dev-data` disk, all service ports forwarded to `127.0.0.1`; Lambda Runtime API ports 9200-9299 are **not** forwarded).

## Critical gotchas

- **`make dev-up` does NOT rerun the installer on an existing VM.** It only starts the VM and verifies Floci health. Use `make dev-recreate` to rebuild the OS from the current checkout while retaining the `floci-dev-data` data disk.
- **The Podman container must be named `tianlu-floci`** (matching `FLOCI_HOSTNAME`). Podman container DNS resolves the `--name` flag, not `FLOCI_HOSTNAME`. If they don't match, Lambda callback URLs and sidecar DNS resolution silently fail.
- **`FLOCI_STORAGE_PERSISTENT_PATH` is a container-side path** (`/app/data`), not a host path. The host path goes in `FLOCI_STORAGE_HOST_PERSISTENT_PATH` and is bind-mounted to the container path. Confusing these breaks persistence silently.
- **The Quadlet must set `UserNS=keep-id:uid=1001,gid=1001`.** The Floci image runs as container uid 1001 (gid 0). Rootless Podman's default subuid mapping maps host `floci` (uid 1000) to container root (uid 0), so a host bind mount of `/home/floci/floci-data` is root-owned inside the container and the container's `floci` user (1001) cannot write to `/app/data` → `java.nio.file.AccessDeniedException: /app/data/tls` and Floci fails to start. `keep-id:uid=1001,gid=1001` maps host `floci` (1000) to container `floci` (1001), keeping the host dir owned by `floci` while making it writable inside.
- **`FLOCI_HOSTNAME` must be hyphenated, not dotted.** Dotted names (e.g. `tianqi.floci`) don't resolve in Podman container DNS. Current value: `tianlu-floci`.
- **Rootless Podman requires two env vars that the Floci docs don't set by default:** `FLOCI_SERVICES_LAMBDA_DOCKER_NETWORK` (pre-created `floci-net`) and `FLOCI_SERVICES_LAMBDA_DOCKER_HOST_OVERRIDE` (for Lambda Runtime API callback). Do NOT set `FLOCI_DOCKER_DOCKER_HOST` — the socket is mounted at `/var/run/docker.sock` inside the container and Floci's default picks it up. See `docs/scraped/docker-configuration.md` — "Running on Podman (rootless)" section.
- **The Podman socket mount needs `:z`** (SELinux shared relabel), not `:Z`. On Ubuntu (no SELinux) it's a no-op but harmless and keeps the config portable to RHEL/Fedora.
- **Do NOT add ports 5100-5199 to the container's `-p` flags.** ECR sidecar binds directly on the host; adding them to Floci's port list causes conflicts and breaks `docker push`/`pull`.
- **The `floci` user uses `/bin/bash` with a locked password**, not `/usr/sbin/nologin`. A nologin shell prevents `systemd --user` from starting, which breaks rootless Podman.
- **`MemoryDenyWriteExecute` must NOT be set** in the systemd unit — Floci is JVM-based and will crash.
- **`RestrictNamespaces=yes` must NOT be set** in the systemd unit — Podman requires namespace creation to run rootless containers.
- **Ubuntu 23.10+ blocks unprivileged userns by default** via `kernel.apparmor_restrict_unprivileged_userns=1`, which makes rootless Podman fail at namespace setup (`could not create user namespace: Operation not permitted`). `assert_userns_allowed` (Phase 1) fixes this by installing a **scoped** AppArmor profile at `/etc/apparmor.d/podman-userns` granting only `userns` to `/usr/bin/podman` (and `crun`/`pasta`/`newuidmap`/`newgidmap` if present), loaded via `apparmor_parser -r`. It must **NEVER** set the sysctl to `0` or use `--security-opt apparmor=unconfined` — that breaches least privilege. Idempotent: no-op when a permitting profile is already loaded or the restriction is not in force. **On Ubuntu 26.04+** the `apparmor-profiles` package ships its own `/etc/apparmor.d/podman` (and `crun`/`pasta`) profile that already grants `userns`; `assert_userns_allowed` MUST detect this via `_system_profile_grants_userns` and skip installing its own for that binary, because attaching a second profile to the same binary creates a **conflicting attachment** — AppArmor then transitions podman into the restrictive `unprivileged_userns` sandbox on userns creation, denying the re-exec (`podman: failed to reexec: Permission denied`). The `newuidmap`/`newgidmap` helpers do NOT have system profiles on 26.04, so the installer installs userns blocks for them — without those, rootless Podman fails at boot with `newuidmap: write to uid_map failed: Operation not permitted` (the `[Install] WantedBy=default.target` service starts before the helpers can map UIDs). See `solution-design.md` §11.2.
- **The systemd unit is a Quadlet `.container`**, not a hand-written `.service` — it lives at `~/.config/containers/systemd/floci.container` and is activated with `systemctl --user daemon-reload` + `start floci.service` (Quadlet generates `floci.service`). Quadlet units are **transient** and CANNOT be `systemctl enable`d ("Unit … is transient or generated") — boot autostart is declared by `[Install] WantedBy=default.target` inside the `.container`. `podman generate systemd` is deprecated; do NOT use it. Quadlet auto-wires `--sdnotify=conmon` and same-name stale-container cleanup, so there is no `ExecStartPre`/`ExecStop`/`--rm`.
- **`ProtectHome` must NOT be set** — `ProtectHome=yes` masks `/home` entirely. The data dir and env file live under `/home/floci`; rely on `0700` permissions instead.
- **`PrivateNetwork` must NOT be set** — it breaks rootless container networking.
- **`PrivateDevices`, `ProtectKernelModules`, `ProtectControlGroups`, `ProtectSystem=strict`, `ReadWritePaths`, `PrivateTmp`, `ProtectKernelTunables`, and `RestrictSUIDSGID` must NOT be set in the Quadlet `[Service]`.** Under systemd 259, the filesystem-sandbox directives (`ProtectSystem=strict`, `ReadWritePaths`, `PrivateTmp`, `ProtectKernelTunables`) make `systemd-executor` create an IMPLICIT user namespace to set up the sandbox; on Ubuntu 26.04 with `apparmor_restrict_unprivileged_userns=1`, AppArmor's `unprivileged_userns` sandbox (which has no `userns` grant for `systemd-executor`) denies `cap_sys_admin` → `cannot clone: Operation not permitted` → the service fails to start. `PrivateDevices` and `ProtectKernelModules` drop capabilities (`CAP_MKNOD`/`CAP_SYS_RAWIO`, `CAP_SYS_MODULE`) via `PR_CAPBSET_DROP`, which requires `CAP_SETPCAP` the unprivileged user lacks → `status=218/CAPABILITIES`. `RestrictSUIDSGID` strips SUID/SGID bits, which breaks Podman's idmapped layer copy under `UserNS=keep-id` (the copy must preserve the SUID bit on setuid root binaries like `usr/bin/chage`) → `storage-chown-by-maps: chmod usr/bin/chage: operation not permitted`. `ProtectControlGroups` is documented system-service-only in systemd 259 and conflicts with Podman's cgroup management. The `[Service]` block keeps ONLY the seccomp-based subset that does NOT require namespace creation or SUID stripping: `NoNewPrivileges`, `RestrictAddressFamilies`, `LockPersonality`, `RestrictRealtime`, `SystemCallArchitectures=native`.
- **`run_as_floci` must invoke `env` WITHOUT a trailing `--` before `"$@"`.** `sudo -u floci env VAR=val ... -- "$@"` fails on GNU coreutils 9.4+ with `env: ‘--’: No such file or directory` because GNU `env` only accepts `--` before VAR=val assignments, not after. Use `sudo -u floci env VAR=val ... "$@"` (no `--`); sudo's own `--` separator is unnecessary when no sudo option follows `-u <user>`.
- **Multi-account isolation is automatic** via 12-digit AKIDs. There is no config flag to "enable" it.
- **`run_as_floci` helper must set `HOME`, `USER`, `PATH`, `XDG_RUNTIME_DIR`, and `DBUS_SESSION_BUS_ADDRESS`.** Missing `HOME` causes rootless Podman to read the wrong `~/.config/containers/` directory.
- **The script must poll for the user manager after `loginctl enable-linger`.** `enable-linger` starts the manager asynchronously. Poll `systemctl is-active --quiet user@<UID>.service` then `systemctl --user -M floci@.host is-active --quiet default.target`. Do NOT use `is-system-running` (fails on `degraded`).
- **`verify_health` must use `curl --resolve tianlu-floci:4566:127.0.0.1 -k`** — not `https://localhost`. This sends the correct `Host:` header, matches the cert SAN, and avoids needing DNS resolution.
- **The script adds `127.0.0.1 tianlu-floci` to `/etc/hosts`** with a managed marker block for host-side tooling. dnsmasq is NOT a prerequisite.
- **First `make twin-test` after pinning `floci-runner`:** Existing Lima instances have the old host-derived username. Run `make twin-test TWIN_FLAGS="--fresh --destroy"` once to recreate the twin; subsequent runs can use the default `--keep`.
- **Every `limactl start` call must pass `--tty=false`** — Lima 2.x opens an interactive confirmation prompt on a TTY by default; under `make`/CI it hangs the run. `--tty=false` is a no-op when already non-interactive. Apply to create, resume, and reboot-restart paths in both `run-test.sh` and `dev-twin.sh`.
- **Every non-interactive `limactl shell` call must be wrapped in `-- bash -c '...' 2>/dev/null`** (or `-- sudo bash -c '...' 2>/dev/null`) — Lima's login shell `cd`s to the host CWD (absent in the guest), producing `cd: /Users/...: No such file or directory` on stderr for every call. The `2>/dev/null` suppresses both host-side `limactl` stderr and the guest-side `cd` noise.
- **The test-twin driver runs as root (`sudo systemd-run`) — verify the Lima-pinned user via `getent passwd`, not `whoami`.** `run-test.sh` launches the driver with `sudo systemd-run`, so `whoami` inside the driver is always `root`. To verify the Lima-pinned default user (`floci-runner`, uid 1001 from `floci-twin.yaml` `user:`), query `getent passwd floci-runner` and check the uid. Do NOT assert `whoami == floci-runner` — it can never pass from inside the driver.
- **The dev twin disables TLS (`FLOCI_TLS_ENABLED=false`).** The production installer keeps TLS on (`FLOCI_TLS_ENABLED=true`, self-signed cert), but the dev twin overrides it to `false` at invocation time (`dev-twin.sh` line 322). This matches the working native-podman setup and avoids the Floci UI sidecar's Node backend rejecting the self-signed cert. With TLS off, Floci serves plain HTTP on 4566 and the built-in UI launcher injects `http://tianlu-floci:4566` — no cert issue.
- **Do NOT launch the `floci-ui` container manually.** Floci's built-in UI launcher (PR #1313) serves a landing page at `GET /` (with `Accept: text/html`); `GET /_floci/ui` lazily spawns the `floci-ui` sidecar with `FLOCI_ENDPOINT` injected automatically. A manual `floci-ui` container reverts to the image default on restart and blocks Floci's launcher (which adopts an existing container). To use the UI: open `http://localhost:4566/` in a browser → click "Open Floci UI" → the sidecar loads. In native podman the sidecar port is bound on Mac localhost directly (no forward needed); in the Lima dev twin the port is bound on the VM's localhost and must be forwarded in `floci-dev.yaml` — probe-identify the port via `/_floci/ui/status` `url` field after `make dev-recreate`. (PR #1471 documents the native-vs-container split.)

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
- `make twin-test` — runs `mock-server/run-test.sh`, the Lima digital-twin harness. Requires Lima + QEMU on Apple Silicon (macOS 13+). Builds/boots a headless Ubuntu arm64 VM, runs `setup-floci.sh` inside it, drives it to a live Floci + an arm64 Lambda sidecar, re-runs for idempotency (semantic convergence), optionally reboots for boot-autostart + Quadlet ordering, and writes a manifest-validated evidence bundle. The twin is an arm64 integration twin; architecture-specific Floci/sidecar runtime behavior on x86_64 is out of scope. See `docs/design/digital-twin-testing-design.md`.
- The script is **sourceable** (guarded `main` at the bottom: `if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then main "$@"; fi`) so bats can load functions without executing them.
- Runtime behaviour that cannot be mocked is covered by the Lima digital twin (`make twin-test`); remaining x86_64-runtime-specific gaps are tracked in `docs/design/gaps-register.md`.
- **Run after every change to `setup-floci.sh`:** `make check` (fast, local) before commit, `make twin-test` before push. The pre-commit hook (`scripts/pre-commit`) runs lint+unit automatically; CI (`.github/workflows/test.yml`) runs lint+unit on every push/PR. Run `make twin-test` locally before pushing installer changes. See `docs/testing-guide.md` for the full guide.

## Target environment

- Ubuntu 26.04 LTS, x86_64
- Multi-user server (home dir `0700`, subuid range collision check required)
- Firewall: UFW only (never mix raw iptables with ufw)
- Image: `docker.io/floci/floci:1.5.33-compat` (pinned, compat variant includes AWS CLI + boto3; fully-qualified so rootless Podman's short-name resolution is not required)

## Future stage

- `setup-dnsmasq.sh` — LAN-wide DNS for `tianlu-floci` → server IP. Not a prerequisite; Floci works on localhost without it. See `docs/design/dnsmasq-design.md`.

## Open gaps

See `docs/design/gaps-register.md` for open risks, limitations, and unresolved items.
