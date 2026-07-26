# setup-floci.sh — Review & Build Plan

## 1. Completed Work

### 1.1 Documentation Scraped
All 9 Floci doc pages saved to `docs/scraped/`:
- `environment-variables.md` — every `FLOCI_*` variable
- `docker-images.md` — image taxonomy, tag matrix, compat contents
- `docker-compose.md` — compose examples, multi-container networking
- `ports.md` — port reference, which need compose mapping
- `multi-account.md` — 12-digit AKID isolation (automatic, no flag)
- `storage.md` — memory/persistent/hybrid/wal modes
- `tls.md` — TLS config, self-signed auto-gen, SDK examples
- `initialization-hooks.md` — boot/start/ready/stop lifecycle hooks
- `docker-configuration.md` — **rootless Podman known-working config** (critical find)

### 1.2 AI-Usable Index
`docs/scraped/INDEX.md` — 9 pages with descriptions, keyword tags, and a quick-lookup table for agent search.

---

## 2. Challenger Reviews (3 parallel adversarial agents)

All three reviewers independently agreed the original plan was **not ready to build**. Key findings:

| # | Finding | Reviewers |
|---|---|---|
| 1 | `FLOCI_STORAGE_PERSISTENT_PATH` was a host path assigned to a container-side var | 3/3 |
| 2 | `FLOCI_HOSTNAME="tianqi.floci"` (dotted) breaks container DNS | 2/3 |
| 3 | `FLOCI_DOCKER_DOCKER_HOST` unset — defaults to docker.sock (doesn't exist in rootless Podman) | 2/3 |
| 4 | `FLOCI_SERVICES_LAMBDA_DOCKER_HOST_OVERRIDE` unset — Lambda invocations hang | 2/3 |
| 5 | `FLOCI_SERVICES_DOCKER_NETWORK` unset — auto-attach only works under Compose | 2/3 |
| 6 | nologin + systemd + rootless Podman trilemma — user unit needs `/bin/bash` + locked password | 1/3 |
| 7 | No compose/Quadlet file generation specified | 1/3 |
| 8 | Firewall would expose unauthenticated Redis/RDS to network | 2/3 |
| 9 | `FLOCI_AUTH_PRESIGN_SECRET` uses default value | 1/3 |
| 10 | No image version pinned | 2/3 |
| 11 | `uidmap`/`newuidmap`/`subuid` not checked | 2/3 |
| 12 | EC2 service exposes SSH/IMDS ports | 1/3 |
| 13 | Multi-account isolation is automatic (no flag) — "enable it" is a non-action | 2/3 |

### Critical Discovery (Reviewer #3)
The Floci docs have a **"Running on Podman (rootless)"** page (`docker-configuration.md`) with the exact known-working configuration:
```sh
podman network create floci-net
podman run -d --name floci \
  --network floci-net \
  -p 4566:4566 \
  -v /run/user/$(id -u)/podman/podman.sock:/var/run/docker.sock:z \
  -e FLOCI_SERVICES_LAMBDA_DOCKER_NETWORK=floci-net \
  -e FLOCI_HOSTNAME=floci \
  floci/floci
```
- `:z` on socket mount for SELinux relabel
- `FLOCI_SERVICES_LAMBDA_DOCKER_HOST_OVERRIDE=floci` when Runtime API unreachable

---

## 3. Resolved Decisions (User Answers)

| Question | Answer |
|---|---|
| Ubuntu version | **26.04 LTS** (resolute) — Podman 5.x, Quadlet available |
| Systemd scope | **User unit + linger** — canonical rootless model |
| TLS certs | **Floci self-signed** — `FLOCI_TLS_SELF_SIGNED=true` (default) |
| Hostname resolution | **dnsmasq in separate script** — `setup-dnsmasq.sh` (future stage, not a prerequisite), maps `tianlu-floci` → server IP for LAN convenience |
| Firewall scope | **Default: auto-detect LAN /24** (opt-in `--firewall-scope=rfc1918` for broader access) |
| Image tag | **1.5.33-compat** (user-confirmed exists on Docker Hub) |
| Image variant | **Compat** (Python 3 + AWS CLI + boto3) |
| Init hooks | **Not used** (no hook directories mounted) |
| Services | **Core + ElastiCache + RDS + ECR + EKS** |
| EC2 service | **Enabled**, EC2 ports exposed to trusted subnet |
| Server type | **Multi-user** — home 0700, careful subuid ranges |
| Server hostname | **Auto-detect** |

---

## 4. Corrected Configuration

| Variable | Original (wrong) | Corrected | Why |
|---|---|---|---|
| `FLOCI_STORAGE_PERSISTENT_PATH` | `/home/floci/floci-data` | `/app/data` | This is a **container-side** path |
| `FLOCI_STORAGE_HOST_PERSISTENT_PATH` | (unset) | `/home/floci/floci-data` | **Host-side** path for bind mounts |
| `FLOCI_DOCKER_DOCKER_HOST` | (unset → docker.sock) | **NOT SET** (removed) | Socket mounted at `/var/run/docker.sock` inside container; Floci default handles it. Setting to host path breaks sidecars. |
| `FLOCI_SERVICES_LAMBDA_DOCKER_NETWORK` | (unset) | `floci-net` | Pre-created Podman network |
| `FLOCI_SERVICES_LAMBDA_DOCKER_HOST_OVERRIDE` | (unset) | `tianlu-floci` | Rootless Podman Lambda Runtime API |
| `FLOCI_BASE_URL` | (unset → http://localhost:4566) | `https://tianlu-floci:4566` | HTTPS scheme + correct host in URLs |
| `FLOCI_TLS_ENABLED` | (unset → false) | `true` | Enable HTTPS |
| `FLOCI_AUTH_PRESIGN_SECRET` | (unset → default) | `openssl rand -hex 32` | Security: not the default |
| `FLOCI_HOSTNAME` | `tianqi.floci` (dotted) | `tianlu-floci` (hyphenated) | Dotted breaks container DNS; hyphenated resolves natively in Podman + can be mapped by dnsmasq for LAN |
| Container name | (not specified) | `--name tianlu-floci` | Podman DNS resolves container name, not FLOCI_HOSTNAME — must match |
| Image | `x.y.z-compat` (placeholder) | `docker.io/floci/floci:1.5.33-compat` | Pinned version (user-confirmed exists); fully-qualified so rootless Podman does not require short-name resolution |

---

## 5. Function List (20 functions + 3 helpers)

| # | Function | Purpose | Idempotency guard |
|---|---|---|---|
| — | `log_info/warn/error` | Colored stderr logging | N/A |
| — | `run_as_floci` | `sudo -u floci` with `XDG_RUNTIME_DIR` + `DBUS_SESSION_BUS_ADDRESS` | N/A |
| 1 | `assert_root_or_sudo` | Verify root/sudo for setup phase | Always |
| 2 | `assert_ubuntu_version` | Check Ubuntu >= 24.04 (target 26.04) | Always |
| 3 | `detect_hostname_and_ip` | Read `hostname`, `hostname -I`, auto-detect LAN IP | Always |
| 4 | `create_floci_user` | `useradd` if `getent passwd floci` fails | `getent` check |
| 5 | `lock_floci_password` | `passwd -l floci` | Check shadow field |
| 6 | `configure_subuid_subgid` | Allocate free range in `/etc/subuid`/`/etc/subgid` | `grep` before add |
| 7 | `install_podman` | `apt install podman uidmap slirp4netns fuse-overlayfs` if missing | `command -v podman` |
| 8 | `enable_lingering` | `loginctl enable-linger floci` | `loginctl show-user floci` |
| 9 | `configure_xdg_runtime_dir` | Ensure `/run/user/<UID>` exists | `[[ -d ]]` check |
| 10 | `start_podman_socket` | `systemctl --user enable --now podman.socket` (as floci) | `systemctl status` |
| 11 | `create_podman_network` | `podman network create floci-net` | `podman network inspect` |
| 12 | `pull_floci_image` | `podman pull docker.io/floci/floci:1.5.33-compat` | `podman image inspect` |
| 13 | `create_data_directory` | `mkdir -p floci-data`, `chown floci:floci`, `chmod 0700` | `[[ -d ]]` |
| 14 | `generate_presign_secret` | `openssl rand -hex 32`, store in env file | `grep` in env file |
| 15 | `write_env_file` | Generate `floci.env` with all `FLOCI_*` vars | Backup before overwrite |
| 16 | `write_systemd_unit` | Write `floci.service` (user unit) with hardening | Backup before overwrite |
| 17 | `enable_systemd_service` | `systemctl --user daemon-reload && enable --now` | `is-enabled` check |
| 18 | `configure_firewall` | `ufw allow from <CIDR>` for each port (if ufw active) | `ufw status` grep |
| 19 | `verify_health` | Poll `https://tianlu-floci:4566/_floci/init` for ready | Retry with timeout |
| 20 | `print_summary` | Output connection info + warnings | N/A |

---

## 6. Port Mapping

### Container `-p` flags (in `podman run`)
Only proxy-in-Floci ports need mapping:
- `4566:4566` — AWS API
- `6379-6399:6379-6399` — ElastiCache proxy
- `7001-7099:7001-7099` — RDS proxy

**NOT mapped** (direct-bind by Podman):
- `5100-5199` — ECR registry sidecar
- `6500-6599` — EKS k3s API
- `9400-9499` — OpenSearch
- `2200-2299` — EC2 SSH
- `9169` — EC2 IMDS

**Never mapped** (internal only):
- `9200-9299` — Lambda Runtime API

### UFW rules (to RFC1918)
```sh
ufw allow from 10.0.0.0/8 to any port 4566
ufw allow from 10.0.0.0/8 to any port 6379:6399 proto tcp
ufw allow from 10.0.0.0/8 to any port 7001:7099 proto tcp
ufw allow from 10.0.0.0/8 to any port 5100:5199 proto tcp
ufw allow from 10.0.0.0/8 to any port 6500:6599 proto tcp
ufw allow from 10.0.0.0/8 to any port 9400:9499 proto tcp
ufw allow from 10.0.0.0/8 to any port 2200:2299 proto tcp
ufw allow from 10.0.0.0/8 to any port 9169 proto tcp
# Repeat for 172.16.0.0/12 and 192.168.0.0/16
```

---

## 7. systemd User Unit (Hardened)

```ini
[Unit]
Description=Floci AWS Emulator (rootless Podman)
After=podman.socket
Requires=podman.socket

[Service]
Type=simple
EnvironmentFile=%h/.config/floci/floci.env
ExecStartPre=-/usr/bin/podman rm -f tianlu-floci
ExecStart=/usr/bin/podman run --rm --name tianlu-floci \
  --network floci-net \
  -p 4566:4566 \
  -p 6379-6399:6379-6399 \
  -p 7001-7099:7001-7099 \
  -v /run/user/%U/podman/podman.sock:/var/run/docker.sock:z \
  -v %h/floci-data:/app/data:z \
  docker.io/floci/floci:1.5.33-compat
ExecStop=/usr/bin/podman stop --time 30 tianlu-floci
Restart=on-failure
# Progressive backoff gives the cold-boot AppArmor profile-attach race time to settle;
# see docs/design/digital-twin-findings.md §9 for the empirical ~25s measurement.
RestartSec="5 10 15 20 30"   # progressive backoff (5+10+15+20+30=80s)
StartLimitIntervalSec=120     # window must exceed cum. backoff
StartLimitBurst=8             # 8 retries over ~80s = ~3x the empirical 25s cold-boot AppArmor race
# Hardening — seccomp-based subset only (no namespace creation or SUID stripping)
NoNewPrivileges=yes
RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6 AF_NETLINK
LockPersonality=yes
RestrictRealtime=yes
SystemCallArchitectures=native
# NOTE: MemoryDenyWriteExecute NOT set (Floci is JVM-based)
# NOTE: RestrictNamespaces NOT set (Podman requires namespace creation)
# NOTE: ProtectHome NOT set (masks /home, breaks data dir + env file access)
# NOTE: ProtectSystem, ReadWritePaths, PrivateTmp, ProtectKernelTunables NOT set
#       — under systemd 259 they make systemd-executor create an IMPLICIT user
#       namespace; on Ubuntu 26.04 with apparmor_restrict_unprivileged_userns=1
#       the unprivileged_userns sandbox denies cap_sys_admin → "cannot clone:
#       Operation not permitted" → the service fails to start.
# NOTE: PrivateDevices NOT set — drops CAP_MKNOD/CAP_SYS_RAWIO via PR_CAPBSET_DROP
#       which needs CAP_SETPCAP unavailable to a rootless user → status=218/CAPABILITIES.
# NOTE: ProtectKernelModules NOT set — same 218 mechanism (drops CAP_SYS_MODULE).
# NOTE: RestrictSUIDSGID NOT set — strips SUID/SGID bits, which breaks Podman's
#       idmapped layer copy under UserNS=keep-id (must preserve SUID on setuid
#       root binaries like usr/bin/chage) → "storage-chown-by-maps: chmod
#       usr/bin/chage: operation not permitted".
# NOTE: ProtectControlGroups NOT set — systemd 259 marks it system-service-only
#       and it conflicts with Podman cgroup management.

[Install]
WantedBy=default.target
```

---

## 8. Environment File (`floci.env`)

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
File permissions: `0600`, owned by `floci:floci`. Written atomically with `install -m 0600 -o floci -g floci` to avoid TOCTOU race on the presign secret.

---

## 9. Gaps & Risks (documented in script)

| ID | Gap | Risk | Mitigation |
|---|---|---|---|
| ~~GAP-001~~ | ~~Dotted `FLOCI_HOSTNAME=tianqi.floci` may not resolve in Podman network DNS~~ | ~~Medium~~ | **CLOSED** — changed to hyphenated `tianlu-floci` which resolves natively in Podman DNS |
| ~~GAP-002~~ | ~~Image tag `1.5.33-compat` not verified~~ | ~~Low~~ | **CLOSED** — user-confirmed exists on Docker Hub |
| GAP-003 | `FLOCI_AUTH_VALIDATE_SIGNATURES=false` — LAN users can create resources | Medium | Firewall restricts to RFC1918; enable signature validation if untrusted users on LAN |
| GAP-004 | AppArmor may interfere with rootless Podman on Ubuntu 26.04 | Low | Script doesn't modify AppArmor; check `dmesg \| grep apparmor` if Podman fails |
| ~~GAP-005~~ | ~~`setup-dnsmasq.sh` prerequisite not yet written~~ | ~~Medium~~ | **DEFERRED** — dnsmasq is a future stage, NOT a prerequisite. Floci works on localhost without it. dnsmasq only adds LAN-wide hostname convenience |
| GAP-006 | subuid/subgid range collision on multi-user server | Low | Script checks `/etc/subuid` and finds next free range |
| GAP-007 | EC2 service exposes SSH/IMDS ports | Medium | Exposed to RFC1918 per user choice; consider `FLOCI_SERVICES_EC2_MOCK=true` |

---

## 10. Execution Order

```
assert_root_or_sudo
  → assert_ubuntu_version
  → detect_hostname_and_ip
  → create_floci_user
  → lock_floci_password
  → configure_subuid_subgid
  → install_podman
  → enable_lingering
  → configure_xdg_runtime_dir
  → start_podman_socket
  → create_podman_network
  → pull_floci_image
  → create_data_directory
  → generate_presign_secret
  → write_env_file
  → write_systemd_unit
  → enable_systemd_service
  → configure_firewall
  → verify_health
  → print_summary
```

---

## 11. Next Steps

1. **User approves this plan** → I implement all 20 functions in `setup-floci.sh`
2. **Future stage**: `setup-dnsmasq.sh` (separate script for LAN-wide hostname convenience — NOT a prerequisite)
3. **Post-implementation**: Run 3 more challenger agents to review the actual code