# Solution Design — Floci on Ubuntu Server with Rootless Podman

## 1. Overview

This document describes the architecture for deploying Floci (an AWS emulator) on Ubuntu 26.04 LTS using rootless Podman. The deployment is managed by a single idempotent bash script (`setup-floci.sh`) that creates a dedicated user, installs prerequisites, configures the Floci container, sets up a hardened systemd user service, and opens firewall ports.

Floci emulates AWS services (SQS, S3, DynamoDB, Lambda, RDS, ElastiCache, ECR, EKS, and more) on a single host. Some services spawn real containers (Lambda runtimes, PostgreSQL for RDS, Valkey for ElastiCache, OpenSearch, k3s for EKS, a registry sidecar for ECR). These sidecar containers require access to a container runtime socket.

## 2. Why rootless Podman

Running Floci as a rootless Podman container means the `floci` user never needs root privileges. If the Floci container or any sidecar is compromised, the attacker is confined to the `floci` user's UID namespace — no root access to the host.

Rootless Podman has specific requirements that Docker does not:

- **subuid/subgid ranges** — the user needs a contiguous UID/GID range in `/etc/subuid` and `/etc/subgid` for user namespace mapping. The `uidmap` package (`newuidmap`/`newgidmap`) must be installed.
- **Lingering** — `loginctl enable-linger <user>` must be enabled so the user's systemd session persists across logouts and boots. Without lingering, the Podman socket and user services stop when no one is logged in.
- **Podman socket** — the rootless API socket lives at `/run/user/<UID>/podman/podman.sock` (volatile tmpfs, recreated on session start), not at `/var/run/docker.sock`.
- **Named network** — the rootless default bridge does not assign reachable IPs between containers. A named Podman network (`floci-net`) must be pre-created so Floci and its sidecars can communicate.

## 3. Architecture

```
┌─────────────────────────────────────────────────────────┐
│  Ubuntu 26.04 LTS host (multi-user)                     │
│                                                         │
│  ┌───────────────┐    ┌──────────────────────────────┐  │
│  │ systemd --user │    │  floci user (/home/floci)    │  │
│  │ (linger on)    │───▶│  - podman.socket             │  │
│  │                │    │  - floci.service             │  │
│  └───────────────┘    │                              │  │
│                       │  ┌────────────────────────┐  │  │
│                       │  │ floci container         │  │  │
│                       │  │ (floci/floci:1.5.33-    │  │  │
│                       │  │  compat)                │  │  │
│                       │  │  --name tianlu-floci    │  │  │
│                       │  │                         │  │  │
│                       │  │  port 4566 (AWS API)    │  │  │
│                       │  │  port 6379-6399 (EC)    │  │  │
│                       │  │  port 7001-7099 (RDS)   │  │  │
│                       │  └──────────┬──────────────┘  │  │
│                       │             │                 │  │
│                       │  ┌──────────▼──────────────┐  │  │
│                       │  │ floci-net (podman net)  │  │  │
│                       │  │  - Lambda containers    │  │  │
│                       │  │  - RDS containers       │  │  │
│                       │  │  - ElastiCache          │  │  │
│                       │  │  - ECR registry         │  │  │
│                       │  │  - EKS k3s              │  │  │
│                       │  │  - OpenSearch           │  │  │
│                       │  └─────────────────────────┘  │  │
│                       └───────────────────────────────┘  │
│                                                         │
│  ┌───────────────┐                                      │
│  │ UFW firewall  │  allow from LAN /24 → Floci ports   │
│  │ (default deny)│  (opt-in: --firewall-scope=rfc1918)  │
│  └───────────────┘                                      │
└─────────────────────────────────────────────────────────┘
```

## 4. User model

A dedicated `floci` user is created with:

- **Shell:** `/bin/bash` — required for `systemd --user` to start a user session. A `nologin` shell prevents PAM from initializing the user session, which breaks rootless Podman.
- **Password:** locked via `passwd -l` — no interactive login is possible, but systemd user services work.
- **Home:** `/home/floci` with `0700` permissions — on a multi-user server, no other user can read the Floci data directory (which contains the TLS private key for the self-signed certificate).
- **subuid/subgid:** a contiguous range (default 100000:262144) allocated in `/etc/subuid` and `/etc/subgid`. Under rootless Podman's default mapping, all containers share the same subuid range (not disjoint slices), so the range size governs per-container UID diversity, not container count. 262144 provides headroom for containers that use `--userns=auto` (disjoint per-container allocation). The script checks for collisions with existing entries before assigning and scans for the next free contiguous range if the default is taken. There is no kernel or `newuidmap` performance cost for a single large entry — the `subuid(5)` performance warning is about the number of *lines/users* in the file, not range size. There is no security benefit from a larger range (all mapped UIDs are unprivileged). The correctness constraint is therefore *non-overlapping ranges across users*, not the range size: the collision check exists to guarantee the `floci` range does not overlap another user's, while the 262144 count is purely `--userns=auto` headroom and is safe to shrink if a host's `/etc/subuid` is tightly packed.

## 5. Container runtime configuration

### 5.1 Podman socket

The rootless Podman socket is enabled via the user systemd unit `podman.socket`, which creates `/run/user/<UID>/podman/podman.sock`. The Floci container mounts this socket at `/var/run/docker.sock` with the `:z` flag (SELinux shared relabel — a no-op on Ubuntu but portable to RHEL/Fedora) so Floci can spawn sidecar containers through Podman's Docker-compatible API.

`FLOCI_DOCKER_DOCKER_HOST` is intentionally not set. The socket is mounted at `/var/run/docker.sock` inside the container, and Floci's default value (`unix:///var/run/docker.sock`) picks it up automatically. Setting it to the host-side Podman socket path would break sidecar spawning because that path does not exist inside the container.

The container must be started with `--name tianlu-floci` so that Podman's embedded DNS resolves the hostname for sidecar containers.

### 5.2 Named network

A named Podman network `floci-net` is pre-created before starting Floci. This network provides DNS resolution between containers and assigns reachable IPs — the rootless default bridge does neither reliably.

```
FLOCI_SERVICES_DOCKER_NETWORK=floci-net
FLOCI_SERVICES_LAMBDA_DOCKER_NETWORK=floci-net
```

### 5.3 Lambda Runtime API callback

Under rootless Podman, Floci's auto-detection of the host IP for Lambda Runtime API callbacks can fail. The override forces Lambda containers to reach Floci at the hostname resolved on the `floci-net` network:

```
FLOCI_SERVICES_LAMBDA_DOCKER_HOST_OVERRIDE=tianlu-floci
```

### 5.4 Hostname

`FLOCI_HOSTNAME=tianlu-floci` — hyphenated, not dotted. Dotted hostnames (e.g. `tianqi.floci`) do not resolve in Podman container DNS. The hyphenated name works natively inside the Podman network because the container is started with `--name tianlu-floci` — Podman DNS resolves the container name, not the `FLOCI_HOSTNAME` env var. The two must match. For LAN clients, dnsmasq (future stage) maps `tianlu-floci` to the server IP.

### 5.5 Host-side hostname resolution

The script adds `127.0.0.1 tianlu-floci` to `/etc/hosts` with a managed marker block so that host-side tooling (AWS CLI, SDKs, curl) can resolve the hostname without dnsmasq. The entry is written atomically (write-to-temp + `install`) and is idempotent. The `/etc/hosts` entry does not conflict with dnsmasq — dnsmasq maps to the LAN IP for other machines, not 127.0.0.1.

## 6. Storage

- **Mode:** `persistent` — synchronous disk write on every change. Data survives restarts.
- **Container path:** `/app/data` — the directory inside the Floci container where persistent data is stored.
- **Host path:** `/home/floci/floci-data` — bind-mounted to `/app/data` inside the container. Owned by `floci:floci`, mode `0700`.
- **Host persistent path:** `FLOCI_STORAGE_HOST_PERSISTENT_PATH=/home/floci/floci-data` — used for RDS, OpenSearch, MSK, and ECR child container volumes via bind mounts.

The distinction between `FLOCI_STORAGE_PERSISTENT_PATH` (container-side) and `FLOCI_STORAGE_HOST_PERSISTENT_PATH` (host-side) is critical. Confusing them breaks persistence silently.

## 7. TLS

TLS is enabled with Floci's built-in self-signed certificate generation:

```
FLOCI_TLS_ENABLED=true
FLOCI_TLS_SELF_SIGNED=true
```

Floci auto-generates a self-signed certificate at startup, persists it to `{persistent-path}/tls/`, and includes `FLOCI_HOSTNAME` (`tianlu-floci`) and `FLOCI_BASE_URL` hostnames in the SANs. The certificate is regenerated when hostname configuration changes between restarts.

No external certificate generation is needed. Clients must disable TLS verification (e.g. `--no-verify-ssl` for AWS CLI, `verify=False` for boto3) because the self-signed CA is not in the system trust store.

The self-signed certificate provides encryption but no authentication — MITM is possible on the LAN by any host that can ARP-spoof or control a switch. For a locally running server with no outside users, this is acceptable. IoT devices on the same LAN are a potential MITM vector — the bar for "trusted" is high. If untrusted users are on the LAN, use external certificates from a trusted CA and do not disable verification.

## 8. Authentication

`FLOCI_AUTH_VALIDATE_SIGNATURES` defaults to `false` — clients can use any access key ID (e.g. `test`) without valid SigV4 signatures. The script generates a random `FLOCI_AUTH_PRESIGN_SECRET` via `openssl rand -hex 32` and persists it. It is not regenerated on subsequent runs (that would invalidate existing pre-signed URLs).

Multi-account isolation is automatic via 12-digit numeric access key IDs — there is no config flag to enable it. When the AKID is exactly 12 digits, it is used as the account ID. Otherwise, `FLOCI_DEFAULT_ACCOUNT_ID` (`000000000000`) is the fallback.

## 9. systemd user service

The Floci container runs as a **systemd user service** managed by a **Quadlet** unit — the current recommended way to run Podman containers under systemd (Podman 4.4+). Quadlet reads a declarative `.container` file and generates the backing `floci.service` on `systemctl --user daemon-reload`, wiring `Type=notify` + `--sdnotify=conmon` and same-name stale-container cleanup automatically. (`podman generate systemd` is deprecated and is not used.)

The unit lives at `~/.config/containers/systemd/floci.container` and is activated as the `floci` user (which requires `loginctl enable-linger`):

```bash
systemctl --user daemon-reload            # regenerate floci.service from the .container
systemctl --user start floci.service      # boot autostart comes from [Install] below
```

Quadlet-generated units are **transient** and cannot be `systemctl enable`d (systemd reports "Unit … is transient or generated"). Boot autostart is declared by `[Install] WantedBy=default.target` inside the `.container`, which Quadlet materialises on `daemon-reload`; the script therefore only needs `start` (idempotent — a no-op if already active).

**`[Container]` section:**

| Directive | Value | Notes |
|---|---|---|
| `Image` | `docker.io/floci/floci:1.5.33-compat` | pinned; fully-qualified so rootless Podman does not require short-name resolution |
| `ContainerName` | `tianlu-floci` | must match `FLOCI_HOSTNAME` for Podman DNS |
| `Network` | `floci-net` | references the network created imperatively in Phase 4 (no `.network` Quadlet, to avoid double-management) |
| `EnvironmentFile` | `%h/.config/floci/floci.env` | all `FLOCI_*` vars; file is mode `0600`, `floci:floci`, written atomically |
| `PublishPort` | `4566:4566`, `6379-6399:6379-6399`, `7001-7099:7001-7099` | proxy-in-Floci ports |
| `Volume` | `%t/podman/podman.sock:/var/run/docker.sock:z` | rootless Podman socket, for sidecar spawning |
| `Volume` | `%h/floci-data:/app/data:z` | persistent storage |

`%h` = the user's home (`/home/floci`), `%t` = the runtime dir (`/run/user/<UID>`); Quadlet expands both. The `.container` also sets `After=podman.socket` and `Requires=podman.socket` in its `[Unit]` section — Quadlet does **not** add this automatically, and the socket must be active before the container starts (the mounted `%t/podman/podman.sock` must exist). `podman.socket` is a user-scoped unit enabled separately in Phase 3.

**`[Service]` hardening** (applied to the generated unit):

`NoNewPrivileges`, `ProtectSystem=strict`, **`ReadWritePaths=%h %t`**, `PrivateTmp`, `ProtectKernelTunables`, `RestrictAddressFamilies`, `LockPersonality`, `RestrictRealtime`, `RestrictSUIDSGID`, `SystemCallArchitectures=native`, plus `Restart=on-failure`, `RestartSec=5`, and a start limit of 5 per 60s to prevent crash loops.

`PrivateDevices`, `ProtectKernelModules`, and `ProtectControlGroups` are excluded: in a rootless user unit the first two drop capabilities (`CAP_MKNOD`/`CAP_SYS_RAWIO`, `CAP_SYS_MODULE`) via `PR_CAPBSET_DROP`, which requires `CAP_SETPCAP` the unprivileged user lacks when systemd's implicit user-namespace setup is unavailable (e.g. under AppArmor `apparmor_restrict_unprivileged_userns`) — the service then exits with `status=218/CAPABILITIES`. `ProtectControlGroups` is documented system-service-only in systemd 259 and conflicts with Podman's cgroup management. `MemoryDenyWriteExecute` is excluded (JVM JIT) and `RestrictNamespaces` is excluded (Podman needs namespace creation).

- **`ReadWritePaths` must include `%t`, not only `%h`.** Under `ProtectSystem=strict` the filesystem is read-only except the listed paths. The Podman runtime and the mounted socket live under `/run/user/<UID>` (`%t`); omitting it makes the socket read-only and the container fails to start.

**Directives that must NOT be set** (each breaks rootless Podman or the JVM):

- `MemoryDenyWriteExecute` — Floci is JVM-based and needs write+execute memory pages.
- `RestrictNamespaces` — Podman must create namespaces for rootless containers.
- `ProtectHome` — masks `/home` entirely; `ReadWritePaths` cannot override it. The data dir and env file live under `/home/floci`; rely on `0700` permissions instead.
- `PrivateNetwork` — breaks rootless container networking.

Quadlet removes the hand-authored lifecycle plumbing the earlier design carried: no `ExecStartPre` stale-container removal, no `ExecStop`, no `--rm` juggling — `--sdnotify=conmon` handles readiness and Quadlet clears a leftover same-name container on start.

**Manual-unit fallback (Podman < 4.4).** If Quadlet is unavailable, write a plain `floci.service` running `podman run` with `Type=notify`, `--sdnotify=conmon`, and `--cidfile=%t/floci.cid` (so `ExecStop` can `podman stop --cidfile %t/floci.cid`), plus `ExecStartPre=-/usr/bin/podman rm -f tianlu-floci` and the identical hardening block including `ReadWritePaths=%h %t`. This is a fallback only; Quadlet is preferred.

### 9.1 Lingering and user manager readiness

After `loginctl enable-linger floci`, the user manager starts asynchronously. The script polls for readiness using a two-stage check before any `systemctl --user` call:

```bash
uid=$(id -u floci)
for ((i=1; i<=30; i++)); do
  if systemctl is-active --quiet "user@${uid}.service" \
     && run_as_floci systemctl --user is-active --quiet default.target; then
    break
  fi
  sleep 1
done
```

`user@<UID>.service` (system scope, queried as root) returns `active` as soon as the user manager process is up, regardless of `degraded` state. The user-scope `default.target` check goes through `run_as_floci` — the same privilege-drop helper used everywhere else — so it inherits the correct `XDG_RUNTIME_DIR`/`DBUS_SESSION_BUS_ADDRESS` and confirms the manager reached its default target. `is-active` is used instead of `is-system-running` to avoid false failures when any unrelated user unit has failed. The poll count and per-iteration sleep are configurable so the sleep can be stubbed out under test.

## 10. Port mapping

### 10.1 Container `-p` flags

Only proxy-in-Floci ports need explicit mapping in `podman run`:

| Port range | Service | Why mapping is needed |
|---|---|---|
| 4566 | AWS API | All AWS SDK/CLI calls |
| 6379-6399 | ElastiCache | TCP proxy runs inside Floci container |
| 7001-7099 | RDS | TCP proxy runs inside Floci container |

### 10.2 Direct-bind ports (no `-p` flag needed)

These ports are bound directly on the host by Podman when sidecar containers start:

| Port range | Service |
|---|---|
| 5100-5199 | ECR registry sidecar |
| 6500-6599 | EKS k3s API server |
| 9400-9499 | OpenSearch data plane |
| 2200-2299 | EC2 SSH |
| 9169 | EC2 IMDS |

Adding 5100-5199 to the Floci container's `-p` flags causes a port conflict with the ECR sidecar and breaks `docker push`/`pull`.

### 10.3 Internal ports (never exposed)

| Port range | Service |
|---|---|
| 9200-9299 | Lambda Runtime API (container-network only) |

### 10.4 Firewall

The script defaults to the server's auto-detected LAN `/24` subnet. `detect_hostname_and_ip` derives the server IP from the source address of the default route (`ip route get 1.1.1.1`, falling back to `hostname -I`), then zeroes the final octet to form the `/24`. An explicit `--firewall-scope=rfc1918` flag opens to all RFC1918 ranges (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16) for operators who want broader access.

With `FLOCI_AUTH_VALIDATE_SIGNATURES=false` (default) AND RFC1918 scope, any host in those ranges has full unauthenticated control of all Floci resources. This is acceptable only on a fully trusted single-tenant network with no guest WiFi, no VPN peers, and no IoT devices on the same subnet. `print_summary` prints the resolved scope and a risk statement on every run.

If the server's IP changes (moved to a different network), the firewall rules become stale. Re-run the script to re-detect, or configure a static IP via `/etc/netplan/` to avoid this.

UFW is the only firewall tool used — mixing raw iptables with UFW causes rule ordering bugs. The script asserts UFW default INPUT policy is `deny` so that any k3s workload port not in the allowlist is blocked automatically.

### 10.5 EC2 service

The EC2 service is enabled. It binds SSH range 2200-2299 and IMDS port 9169 directly on the host, opened in UFW to the configured subnet. EC2 mock containers may have default or no credentials. If real EC2 containers are not needed, set `FLOCI_SERVICES_EC2_MOCK=true` to avoid spawning real containers while keeping the API responses.

### 10.6 EKS/k3s workloads

The EKS service runs k3s as a sidecar container on `floci-net`. The k3s API server (6500-6599) uses k3s's own self-signed CA, not Floci's. A `Service` of `type: LoadBalancer` or `NodePort` in the emulated EKS cluster may attempt to bind ports on the k3s container — whether these are host-reachable depends on the k3s container's network mode. UFW default-deny INPUT policy is the primary control: any k3s workload port not in the allowlist is blocked automatically. Do NOT open k3s workload ports in UFW — use a reverse proxy (nginx/caddy) with auth and TLS for any externally-needed service.

A compromised k3s pod can reach other sidecars on `floci-net` (RDS, ElastiCache, ECR) even if it cannot break out of the rootless Podman namespace — lateral movement within the namespace is the real risk, not breakout.

## 11. Security posture

### 11.1 Podman socket access

The rootless Podman socket at `/run/user/<UID>/podman/podman.sock` is accessible by root and any user who can `sudo -u floci`. Access to the `floci` user IS access to the Podman socket — sudoers cannot safely restrict Podman subcommands because the socket is a direct API accessible from any binary (curl, python, bash) run as the floci user.

**Guidance:**
- Do not grant `sudo -u floci` to any user unless you would grant them full Floci control.
- Untrusted Lambda code must not be deployed to this Floci instance on a shared host. A malicious Lambda can spawn containers, mount host paths under `/home/floci`, exfiltrate the TLS private key, and pivot to other sidecars on `floci-net`. This is inherent to Floci's architecture (it needs the socket to spawn sidecars).
- If limited access is needed, use a root-owned wrapper script (`/usr/local/bin/floci-ctl`, mode 0755, root:root) that internally calls `podman logs`/`ps` with hardcoded arguments — never exposes the socket or a shell to the caller.
- The script does not create a sudoers.d file — sudoers policy is an operator responsibility.

### 11.2 AppArmor and unprivileged user namespaces

Ubuntu 23.10+ (including 24.04 and 26.04) ships with
`kernel.apparmor_restrict_unprivileged_userns=1`. This sysctl makes the kernel
refuse `unshare(CLONE_NEWUSER)` for any program that is not covered by an
AppArmor profile carrying the `userns` permission. Rootless Podman relies on
unprivileged user-namespace creation for **every** container start, so on a
stock install Podman fails at namespace setup — typically with
`Error: could not create user namespace: Operation not permitted` or a
`newuidmap`/`unshare` EPERM. This is the single most likely
"configured-correctly-but-won't-start" failure on a fresh Ubuntu server, and
it is silent unless you check `dmesg | grep -i apparmor`.

**Resolution — a scoped AppArmor profile (`assert_userns_allowed`, Phase 1).**
The preflight reads `/proc/sys/kernel/apparmor_restrict_unprivileged_userns`.
If it is `0` (or the file is absent, i.e. the restriction is not in force),
there is nothing to do. If it is `1`, the script checks whether a profile that
already permits userns for the Podman binary is loaded; if not, it **installs a
narrowly-scoped profile** at `/etc/apparmor.d/podman-userns` that grants only
the `userns` capability to `/usr/bin/podman` and loads it with
`apparmor_parser -r`. The profile body is:

```
abi <abi/4.0>,
include <tunables/global>

profile podman-userns /usr/bin/podman flags=(unconfined) {
  userns,
  include if exists <local/podman-userns>
}
```

Helper binaries that Podman execs and that also create namespaces —
`/usr/bin/crun` (or `runc`) and `/usr/bin/pasta` — receive the same scoped
treatment if they are present, so rootless networking (pasta) and container
launch (crun) are not blocked either.

**What the script must never do.** It must **not** set
`kernel.apparmor_restrict_unprivileged_userns=0`, and it must **not** apply
`--security-opt apparmor=unconfined` to the container. Both re-enable
unconstrained unprivileged userns creation host-wide (or drop confinement for
the workload), which breaches least privilege — the whole point of the Ubuntu
default is to deny userns to everything *except* explicitly-permitted binaries.
The scoped profile grants exactly one capability to exactly the binaries that
need it and nothing else.

This step is idempotent: a re-run detects the already-loaded permitting profile
(or an already-permissive sysctl) and makes no changes. See GAP items in
`docs/design/gaps-register.md` if profile naming collides with a
distribution-shipped Podman profile on a future Ubuntu release.

## 12. Environment file

All Floci configuration is in `~/.config/floci/floci.env` (mode `0600`):

```ini
FLOCI_HOSTNAME=tianlu-floci
FLOCI_BASE_URL=https://tianlu-floci:4566
FLOCI_DEFAULT_REGION=eu-west-1
FLOCI_DEFAULT_ACCOUNT_ID=000000000000
FLOCI_STORAGE_MODE=persistent
FLOCI_STORAGE_PERSISTENT_PATH=/app/data
FLOCI_STORAGE_HOST_PERSISTENT_PATH=/home/floci/floci-data
FLOCI_TLS_ENABLED=true
FLOCI_TLS_SELF_SIGNED=true
FLOCI_SERVICES_DOCKER_NETWORK=floci-net
FLOCI_SERVICES_LAMBDA_DOCKER_NETWORK=floci-net
FLOCI_SERVICES_LAMBDA_DOCKER_HOST_OVERRIDE=tianlu-floci
FLOCI_AUTH_PRESIGN_SECRET=<random-64-hex>
FLOCI_DOCKER_LOG_MAX_SIZE=10m
FLOCI_DOCKER_LOG_MAX_FILE=3
```

`FLOCI_DOCKER_DOCKER_HOST` is intentionally absent — the socket is mounted at `/var/run/docker.sock` inside the container and Floci's default handles it.

## 13. Idempotency

Every function in the script checks before creating or modifying:

| Operation | Guard |
|---|---|
| `useradd` | `getent passwd floci` |
| `passwd -l` | Check shadow field for `!` prefix |
| subuid/subgid | `grep "^floci:" /etc/subuid` |
| `apt install` | `command -v podman` |
| `loginctl enable-linger` | `loginctl show-user floci -p Linger` |
| `podman network create` | `podman network inspect floci-net` |
| `podman pull` | `podman image inspect <image>` |
| `mkdir` data dir | `[[ -d ]]` |
| `/etc/hosts` entry | Match hostname regardless of IP, managed marker block |
| env file write | Backup before overwrite |
| systemd unit write | Backup before overwrite |
| `systemctl enable` | `systemctl --user is-enabled floci.service` |
| UFW rules | `ufw status \| grep` |

## 14. Privilege model

The script runs as root (or via sudo) for the setup phase:

- `useradd`, `usermod`, `passwd`
- `apt install`
- `loginctl enable-linger`
- `ufw`

After setup, it drops to the `floci` user for Podman and systemd operations via a `run_as_floci` helper that sets `HOME`, `USER`, `PATH`, `XDG_RUNTIME_DIR=/run/user/<UID>`, and `DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/<UID>/bus`.

## 15. Script execution order

The script is structured in named phases. With `--interactive`, it pauses at each phase boundary (`phase_pause` function — guards with `[[ -t 0 ]]` so it self-disables on non-TTY stdin). Without `--interactive`, all phases run continuously.

```
Phase 1: Preflight
  parse_args (--interactive, --firewall-scope)   # first, so --interactive gates this phase's pause
  → assert_root_or_sudo
  → assert_ubuntu_version
  → assert_userns_allowed (scoped AppArmor userns profile; never disables the sysctl)
  → detect_hostname_and_ip
  [phase_pause]

Phase 2: User setup
  → create_floci_user
  → lock_floci_password
  → configure_subuid_subgid
  [phase_pause]

Phase 3: Podman setup
  → install_podman
  → enable_lingering (+ poll user@<UID>.service, then default.target)
  → configure_xdg_runtime_dir
  → start_podman_socket
  [phase_pause]

Phase 4: Network & image
  → create_podman_network
  → pull_floci_image
  [phase_pause]

Phase 5: Floci config
  → create_data_directory
  → add_hosts_entry (127.0.0.1 tianlu-floci, managed marker block)
  → generate_presign_secret (idempotent: reuse if exists)
  → write_env_file (atomic: install -m 0600 -o floci -g floci)
  → write_quadlet_unit (~/.config/containers/systemd/floci.container)
  [phase_pause]

Phase 6: Start & verify
  → enable_systemd_service (systemctl --user daemon-reload; start floci.service — Quadlet units are transient; autostart via [Install])
  → configure_firewall (assert UFW default deny, auto-detect /24 or RFC1918)
  → verify_health (curl --resolve tianlu-floci:4566:127.0.0.1 -k, retry loop)
  [phase_pause]

Phase 7: Summary
  → print_summary (firewall scope, risk statement, connection info)
```

### 15.1 Health verification

`verify_health` polls `https://tianlu-floci:4566/_floci/init` using `curl --resolve tianlu-floci:4566:127.0.0.1 -k` — this sends the correct `Host:` header, matches the cert SAN, and avoids needing DNS resolution. The retry loop checks HTTP status codes explicitly:

```bash
code=$(curl -s -o /dev/null -w '%{http_code}' \
       --resolve tianlu-floci:4566:127.0.0.1 \
       --connect-timeout 5 --max-time 10 \
       -k "https://tianlu-floci:4566/_floci/init") || code=000
```

HTTP 200 = ready, 000 = not yet started (retry), any other code = error (fail immediately).

In interactive mode, the user can observe the raw curl output at the phase 6 pause point and manually inspect the response.

## 16. Future stage: dnsmasq

`setup-dnsmasq.sh` is planned as a future stage for LAN-wide DNS resolution. It maps `tianlu-floci` to the server's LAN IP so that other machines on the network can use the hostname instead of the IP. It is not a prerequisite — Floci works on localhost without it, and the `/etc/hosts` entry added by `setup-floci.sh` handles host-side resolution. See `docs/design/dnsmasq-design.md`.

## 17. Open items

See `docs/design/gaps-register.md` for unresolved items that require runtime testing to close.