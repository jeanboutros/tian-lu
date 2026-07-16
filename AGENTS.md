# AGENTS.md

## Project

Infrastructure setup scripts for deploying Floci (AWS emulator) on Ubuntu Server using rootless Podman. No application code — bash scripts and scraped documentation only.

## Key files

- `setup-floci.sh` — main script (skeleton, implementation pending). Creates `floci` user, installs rootless Podman, configures Floci container with persistent storage + TLS, systemd user service, UFW firewall rules. Must be idempotent.
- `REVIEW.md` — design rationale, challenger review findings, corrected configuration. **Read this before editing `setup-floci.sh`** — it explains why each config value is what it is.
- `docs/design/` — design documents:
  - `solution-design.md` — full solution architecture for the Floci setup.
  - `dnsmasq-design.md` — LAN-wide DNS design for `tianlu-floci` → server IP (future stage).
  - `gaps-register.md` — unresolved items requiring runtime testing (only 2 open gaps remain).
- `docs/scraped/` — scraped Floci documentation (9 pages). Use `docs/scraped/INDEX.md` for keyword-based lookup; it maps topics to specific files.

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
- **`ProtectHome=yes` must NOT be used with `ReadWritePaths=%h`** — `ProtectHome=yes` masks `/home` entirely and `ReadWritePaths` cannot override it. Use `ProtectHome=read-only` if needed, or drop `ProtectHome` and rely on file permissions.
- **Multi-account isolation is automatic** via 12-digit AKIDs. There is no config flag to "enable" it.
- **`run_as_floci` helper must set `HOME`, `USER`, `PATH`, `XDG_RUNTIME_DIR`, and `DBUS_SESSION_BUS_ADDRESS`.** Missing `HOME` causes rootless Podman to read the wrong `~/.config/containers/` directory.
- **The script must poll for the user manager after `loginctl enable-linger`.** `enable-linger` starts the manager asynchronously. Poll `systemctl is-active --quiet user@<UID>.service` then `systemctl --user -M floci@.host is-active --quiet default.target`. Do NOT use `is-system-running` (fails on `degraded`).
- **`verify_health` must use `curl --resolve tianlu-floci:4566:127.0.0.1 -k`** — not `https://localhost`. This sends the correct `Host:` header, matches the cert SAN, and avoids needing DNS resolution.
- **The script adds `127.0.0.1 tianlu-floci` to `/etc/hosts`** with a managed marker block for host-side tooling. dnsmasq is NOT a prerequisite.

## Script conventions

- `set -euo pipefail` + `IFS=$'\n\t'` — fail fast.
- All parameters are `readonly` in a single configuration block at the top.
- Each phase is a separate small function with pydoc-style documentation.
- Every function must be idempotent (check before create/modify).
- Privilege model: root/sudo for setup steps (useradd, apt, ufw), then drop to `floci` user for Podman/systemd --user operations via a `run_as_floci` helper that sets `XDG_RUNTIME_DIR` and `DBUS_SESSION_BUS_ADDRESS`.

## Target environment

- Ubuntu 26.04 LTS, x86_64
- Multi-user server (home dir `0700`, subuid range collision check required)
- Firewall: UFW only (never mix raw iptables with ufw)
- Image: `floci/floci:1.5.33-compat` (pinned, compat variant includes AWS CLI + boto3)

## Future stage

- `setup-dnsmasq.sh` — LAN-wide DNS for `tianlu-floci` → server IP. Not a prerequisite; Floci works on localhost without it. See `docs/design/dnsmasq-design.md`.

## Open gaps

See `docs/design/gaps-register.md` for open risks, limitations, and unresolved items.