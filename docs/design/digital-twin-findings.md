# Digital-Twin Findings — Root-Cause Analysis from the Lima Harness Run

This document consolidates every root cause, failure mode, and correction
the Lima digital-twin harness surfaced while validating `setup-floci.sh`
end-to-end. Each entry records the symptom, the mechanism, the fix, and the
test that prevents regression. The twin proved its core purpose: it found
real production-impacting bugs that no static review caught.

For the actionable gotcha list (the short-form "must / must-not" rules), see
`AGENTS.md` → Critical gotchas. This document is the long-form RCA record
behind those rules.

See also:
- `digital-twin-testing-design.md` — what the twin is and how it works.
- `solution-design.md` §11.2 — the AppArmor / unprivileged-userns design.
- `gaps-register.md` — GAP-009 (closed by the twin) and GAP-014 (partially
  closed; reboot-health pending the x86_64 server).

---

## 1. Privilege-drop helper — `env -- "$@"` incompatibility

**Symptom.** The installer aborted at the Phase 3 user-manager poll with
`env: ‘--’: No such file or directory`, before any Podman command ran. The
in-VM harness helper `run_as_floci_guest` failed identically.

**Root cause.** `run_as_floci` constructed
`sudo -u "$FLOCI_USER" env HOME=… USER=… … -- "$@"`. GNU coreutils 9.4 `env`
only accepts `--` (end-of-options) **before** `VAR=val` assignments, not
after. When `--` follows the assignments, `env` treats `--` as the command
name and exits non-zero. Ubuntu 24.04/26.04 ship coreutils 9.4; macOS BSD
`env` accepts `--` anywhere, so the macOS bats suite never caught it.

**Fix.** Drop the trailing `--`: `sudo -u floci env VAR=val … "$@"`. sudo's
own `--` separator is unnecessary when no sudo option follows `-u <user>`.
Applied to both `setup-floci.sh` `run_as_floci` and the harness
`run_as_floci_guest`.

**Regression guard.** `mock-server/tests/assert_helpers.bats` asserts the
exact sudo-log line contains no `--` before the command. The twin's preflight
no longer aborts at the user-manager poll.

**Lesson.** A privilege-drop helper's exact `env` invocation is
coreutils-version-sensitive; do not assume BSD `env` semantics on GNU. Test
the helper on the target OS, not just the macOS dev host.

---

## 2. Read-only mount + non-executable installer

**Symptom.** `sudo /opt/tianlu/setup-floci.sh` failed with
`sudo: cannot execute ‘/opt/tianlu/setup-floci.sh’: Permission denied
(os error 13)` immediately, before Phase 1 ran.

**Root cause.** The twin mounts the repo read-only via 9p. `setup-floci.sh`
is committed without the executable bit (mode 0644). `sudo <path>` execs the
file directly, which the kernel refuses for a non-executable file. The
production server runs the script from a writable checkout where the bit may
be set; the read-only mount exposed the assumption.

**Fix.** Invoke as `sudo bash "$SETUP_SCRIPT"` in the guest driver (both
Run-1 and Run-2). `bash <file>` reads the file regardless of the exec bit.

**Regression guard.** The guest driver's two installer invocations both use
`sudo bash`; the harness README documents the read-only-mount contract.

**Lesson.** Read-only mounts surface hidden executable-bit assumptions.
When the runtime cannot chmod the mount, invoke interpreters explicitly.

---

## 3. Evidence staging path outside the mount

**Symptom.** The host orchestrator's `poll_sentinel` timed out: the driver
wrote `summary.md` and `FAILED`/`DONE` sentinels, but the host never saw them
on the virtiofs/9p mount. The final `sha256sum -c` then listed a
self-referential `./manifest.sha256.tmp` entry that no longer existed.

**Root cause (two bugs).** (a) The driver wrote to
`${EVIDENCE_HOST_DIR}.staging` — a **sibling** of the mounted evidence dir,
not inside it. Only `/opt/twin-evidence` was mounted; `.staging` was a
host-side path the guest could write but the host's mount-poll never
observed. (b) `publish_evidence`'s `find` excluded the final manifest name
(`manifest.sha256`) but not the `.tmp` sidecar the redirect creates, so the
manifest gained an entry for a file renamed away moments later.

**Fix.** (a) Both driver and orchestrator use `${EVIDENCE_HOST_DIR}/staging`
(inside the mount). (b) The `find` excludes `manifest.sha256`,
`manifest.sha256.tmp`, `DONE`, `DONE.tmp`, `FAILED`, and `*.bak`.

**Regression guard.** The host staging dir is now visible (the twin's main
run reaches the manifest step); `sha256sum -c` passes; the manifest contains
no `.tmp` entries.

**Lesson.** The SSH-independent design requires every path the host polls to
be **inside** the mount, not a sibling. Atomic-rename patterns must exclude
both the final name and the `.tmp` sidecar from the manifest enumeration.

---

## 4. Short-name image pull on fresh rootless Podman

**Symptom.** `podman pull floci/floci:1.5.33-compat` failed with
`Error: short-name "floci/floci:1.5.33-compat" did not resolve to an alias
and no unqualified-search registries are defined in
"/etc/containers/registries.conf"`.

**Root cause.** A fresh rootless Podman install has no
`unqualified-search-registries` configured. Short-name pulls (no registry
prefix) require either a registries.conf default or a fully-qualified
reference. The installer used the short name.

**Fix.** Change `FLOCI_IMAGE` default to the fully-qualified
`docker.io/floci/floci:1.5.33-compat`. Updated every referencing site:
`setup-floci.sh` config + Quadlet `Image=`, the harness `assert_eq` for the
running image, all bats assertions, README, AGENTS, REVIEW, and
solution-design.

**Regression guard.** `tests/phase3_4.bats` asserts `podman pull
docker.io/floci/floci:1.5.33-compat`; `tests/quadlet.bats` asserts
`Image=docker.io/floci/floci:1.5.33-compat`.

**Lesson.** Rootless Podman does not inherit Docker's `docker.io` default for
short names. Pin fully-qualified image references so the install path does
not depend on registries.conf state.

---

## 5. Quadlet `[Service]` hardening vs rootless user units

The Quadlet hardening block went through three rounds of reduction. Each
directive that was removed has a distinct, kernel-verified failure mode.

### 5.1 `PrivateDevices` / `ProtectKernelModules` — `status=218/CAPABILITIES`

**Symptom.** `floci.service` exited with
`floci.service: Failed to drop capabilities: Operation not permitted`,
`status=218/CAPABILITIES`.

**Root cause.** In a rootless user unit, `PrivateDevices` and
`ProtectKernelModules` drop capabilities (`CAP_MKNOD`/`CAP_SYS_RAWIO`,
`CAP_SYS_MODULE`) via `PR_CAPBSET_DROP`, which requires `CAP_SETPCAP` the
unprivileged user lacks → the drop fails → systemd maps it to
`EXIT_CAPABILITIES` 218. (Confirmed against systemd 259 source:
`unit.c` computes the bounding-set reduction; `exec-invoke.c` maps the
failure to 218.)

**Fix.** Drop both directives. Keep only the seccomp-based subset.

### 5.2 `ProtectControlGroups` — system-service-only

**Symptom.** Same 218 path is theoretically possible; independently,
`ProtectControlGroups` is documented system-service-only in systemd 259 and
makes cgroupfs read-only, conflicting with Podman's cgroup management.

**Fix.** Drop it.

### 5.3 `ProtectSystem=strict` / `ReadWritePaths` / `PrivateTmp` / `ProtectKernelTunables` — systemd-executor implicit userns

**Symptom.** After removing 5.1/5.2, `floci.service` failed with
`cannot clone: Operation not permitted`. Kernel audit:
`execpath="/usr/lib/systemd/systemd-executor"`, profile `unprivileged_userns`
denying `cap_sys_admin`.

**Root cause.** Under systemd 259, the filesystem-sandbox directives
(`ProtectSystem=strict`, `ReadWritePaths`, `PrivateTmp`, `ProtectKernelTunables`)
make `systemd-executor` create an **implicit user namespace** to set up the
sandbox. On Ubuntu 26.04 with
`apparmor_restrict_unprivileged_userns=1`, AppArmor's `unprivileged_userns`
sandbox has no `userns` grant for `systemd-executor`, so it denies
`cap_sys_admin` → the clone fails → the service cannot start.

**Fix.** Drop all four filesystem-sandbox directives. The `[Service]` block
keeps only directives that do not require namespace creation:
`NoNewPrivileges`, `RestrictAddressFamilies`, `LockPersonality`,
`RestrictRealtime`, `SystemCallArchitectures=native`.

### 5.4 `RestrictSUIDSGID` — breaks Podman idmapped layer copy

**Symptom.** After adding `UserNS=keep-id:uid=1001,gid=1001` (see §7),
`floci.service` failed with
`storage-chown-by-maps: chmod usr/bin/chage: operation not permitted`.

**Root cause.** `RestrictSUIDSGID` strips SUID/SGID bits. Podman's idmapped
layer copy (triggered by `UserNS=keep-id`) must **preserve** the SUID bit on
setuid-root binaries (e.g. `usr/bin/chage`); stripping it makes the chown
fail.

**Fix.** Drop `RestrictSUIDSGID`. Verified empirically: the exact Quadlet
`podman run --userns=keep-id` command succeeds under `systemd-run --user`
with the full remaining seccomp block (minus `RestrictSUIDSGID`).

**Regression guard.** `tests/quadlet.bats` asserts all the dropped
directives are ABSENT and the kept seccomp subset is PRESENT.

**Lesson.** Rootless user units cannot use the full systemd hardening
menu. The safe subset is the seccomp-based directives that neither create
namespaces, drop capabilities via `PR_CAPBSET_DROP`, nor strip SUID/SGID
bits. Each removal was kernel-audit-verified, not guessed.

---

## 6. AppArmor conflicting-attachment on Ubuntu 26.04

**Symptom.** `podman run` failed with `failed to reexec: Permission denied`
even after the podman-userns profile granted `userns` to `/usr/bin/podman`.

**Root cause.** Ubuntu 26.04's `apparmor-profiles` package ships its own
`/etc/apparmor.d/podman` (and `crun`/`pasta`) profile that already grants
`userns`. The installer's `assert_userns_allowed` wrote a **second** profile
(`podman-userns`) attached to the same `/usr/bin/podman` binary, creating a
**conflicting attachment**. AppArmor then transitions podman into the
restrictive `unprivileged_userns` sandbox on userns creation, denying the
re-exec. Kernel audit:
`info="conflicting profile attachments" profile="unconfined" name="/usr/bin/podman"`.

**Fix.** `assert_userns_allowed` calls `_system_profile_grants_userns` to
detect when any profile under `/etc/apparmor.d` already attaches to a binary
with a `userns` rule, and skips installing its own for that binary. The check
is per-binary, not global, because the uid-map helpers (§8) still need
profiles.

**Regression guard.** `tests/phase1_2.bats` has a dedicated test that seeds
a system-style `podman` profile granting `userns` and asserts
`assert_userns_allowed` does NOT call `apparmor_parser` and does NOT write
the conflicting `podman-userns` file.

**Lesson.** Never attach a second AppArmor profile to a binary that already
has one. Detect-and-skip is required whenever the base OS may ship its own
profile for the same binary.

---

## 7. `UserNS=keep-id` for the Floci image uid

**Symptom.** `floci.service` started the container, but Floci crashed:
`java.nio.file.AccessDeniedException: /app/data/tls`.

**Root cause.** The Floci image runs as container uid 1001 (gid 0). Rootless
Podman's default subuid mapping maps host `floci` (uid 1000) to container
root (uid 0). A host bind mount of `/home/floci/floci-data` is therefore
root-owned (mode 0700) inside the container, and the container's `floci`
user (1001) cannot write to `/app/data` → Floci cannot persist its TLS
certificate → startup aborts.

**Fix.** Add `UserNS=keep-id:uid=1001,gid=1001` to the Quadlet `[Container]`.
This maps host `floci` (1000) to container `floci` (1001), keeping the host
dir owned by `floci` while making it writable by the container's `floci`
user. Verified empirically: `touch /app/data/test-write` returns 0; the
chown-to-101000 alternative also works but changes the host owner, so
`keep-id` is preferred.

**Regression guard.** `tests/quadlet.bats` asserts
`UserNS=keep-id:uid=1001,gid=1001` is present.

**Lesson.** Rootless bind mounts are uid-mapped, not passthrough. The
container image's default user uid must align with the host bind-mount
owner via `UserNS=keep-id:uid=<container-uid>,gid=<container-gid>`, or the
host dir must be chowned to the subuid-mapped host uid.

---

## 8. `newuidmap` / `newgidmap` userns profiles at boot

**Symptom.** The reboot test (GAP-014) failed: `floci.service` boot-autostart
exhausted `StartLimitBurst=5` with
`newuidmap: write to uid_map failed: Operation not permitted`.

**Root cause.** Ubuntu 26.04's `apparmor-profiles` ships userns-granting
profiles for `podman`/`crun`/`pasta` but **not** for `newuidmap`/`newgidmap`.
The `[Install] WantedBy=default.target` service starts at boot and calls
`newuidmap` to set up the uid map; without a userns profile, AppArmor denies
the `/proc/self/uid_map` write.

**Fix.** `assert_userns_allowed` installs userns-granting blocks for
`newuidmap` and `newgidmap` (when present and no system profile already
grants them — same conflicting-attachment avoidance as §6). Two sub-bugs
surfaced and were fixed:

- **Early-return skip.** The function originally returned early when
  podman's system profile granted userns, which skipped installing the
  helper profiles too. Restructured to determine per-binary which chain
  members still need a profile, short-circuit only when the full set is
  covered, and write the podman block conditionally while still emitting
  the helper blocks.
- **Phase-ordering idempotency.** `assert_userns_allowed` ran in Phase 1
  (before `install_podman`), so on Run-1 the helper binaries did not exist
  yet → their blocks were gated out → profile empty; on Run-2 they existed
  → blocks written → semantic-convergence snapshot diverged. Moved
  `assert_userns_allowed` to Phase 3, immediately after `install_podman`,
  so the helper binaries exist on every run and the profile is written
  identically across runs.
- **abi version.** The profile used `abi <abi/4.0>` while Ubuntu 26.04's
  system profiles use `abi <abi/5.0>`. The mismatched abi is skipped by
  `apparmor.systemd`'s cached boot reload (`/var/cache/apparmor`) — the
  profile loads via manual `apparmor_parser -r` (force parse) but NOT at
  boot. Aligned to `abi <abi/5.0>`.

**Regression guard.** `tests/phase1_2.bats` has a presence test (helpers
exist → blocks written), absence assertions (helpers absent → blocks
omitted), the skip-when-system-profile-grants-userns test (§6), and an
`abi <abi/5.0>` assertion. The semantic-convergence snapshot covers the
profile content across runs.

**Lesson.** A userns profile for the main binary is not enough — every
binary in the rootless-Podman chain that creates or maps a namespace needs
its own grant. The profile's `abi` version must match the base OS's
apparmor-profiles so the cached boot reload picks it up. Phase ordering must
ensure the binaries the profile references exist before the profile is
generated, or idempotency breaks.

---

## 9. Reboot-health-200 — Lima AppArmor boot-race (twin fidelity limit)

**Symptom.** Even with the helper profiles installed and loaded in the
kernel (verified: `podman unshare true` and `podman run --userns=keep-id`
both succeed via `systemd-run --user` post-settle, with the full seccomp
hardening block), `floci.service` boot-autostart still fails in the first
~25s of a Lima reboot with the same `newuidmap: write to uid_map failed`.

**Root cause.** `apparmor.service`'s cached boot reload does not load the
`newuidmap`/`newgidmap` profiles before the user service starts in the Lima
nested VM. The profiles are present on disk and load via manual
`apparmor_parser -r`, but the boot-path cache timing leaves them ineffective
when `floci.service` first fires. This is a **Lima nested-VM boot-timing
quirk**, not an installer bug: on a bare-metal x86_64 server
`apparmor.service` loads all profiles before user services start.

**What IS proven.** The reboot journal shows `podman.socket` Listening
immediately followed by `floci.service` Starting at boot — the Quadlet
`After=podman.socket`/`Requires=podman.socket` ordering edge fires
correctly. `systemctl --user show -p After -p Requires floci.service`
confirms both contain `podman.socket`. `start` (not `enable`) is the
correct activation. The harness `wait_for_reboot_health` includes a
reset+restart fallback that proves the Quadlet-generated service runs
post-reboot once AppArmor has settled.

**Status.** GAP-014 is partially closed: ordering + boot-autostart attempt
proven; full `reboot-health-200` pending the x86_64 server, where the
AppArmor boot-race does not apply. Recorded in `gaps-register.md`.

**Lesson.** A nested-VM twin cannot reproduce every bare-metal boot-timing
property. When a reboot-dependent proof is blocked by a twin-fidelity
limit, prove the structural invariants (ordering edges, activation model)
in the twin and defer the timing-sensitive health proof to the target
hardware, documenting the gap rather than masking it.

---

## 10. Harness-side Lima / bash portability findings

These are not installer bugs; they are harness-build findings recorded so
the harness stays maintainable.

- **Lima 2.x `limactl start` API.** `limactl start NAME FILE.yaml` (two
  positional args) is the Lima 1.x form; Lima 2.x rejects it ("at most 1
  arg"). Use `limactl start --name=<instance> <template>` for create+start,
  `limactl start <name>` for an existing instance.
- **`limactl start` needs `--tty=false` in non-interactive contexts.** Lima
  2.x opens an interactive editor/confirmation prompt on a TTY by default.
  Under `make` (non-interactive) or piped stdout the run hangs. Pass
  `--tty=false` to every `limactl start` call: create, resume, and reboot
  restart. It is a no-op when already non-interactive. Fixed in
  `mock-server/dev-twin.sh` (commit 103acfa) and `mock-server/run-test.sh`
  (commit 93e31b6).
- **No host-path template variable.** Lima YAML `location` supports
  `{{.Home}}`, `{{.Dir}}`, `{{.Name}}`, `{{.Param.Key}}` etc., but no
  arbitrary-host-path variable. Mount the repo via `--set` yq override
  (`.mounts[0].location="<abs path>"`) at create time; use a placeholder
  absolute default so `limactl validate` passes.
- **Login-shell `cd` noise.** `limactl shell <name> -- <cmd>` runs a login
  shell that `cd`s to the host CWD, which does not exist in the guest,
  emitting `cd: ... No such file or directory` on stderr. A bare command
  chain (`test -d … && test -d …`) can pick up a non-zero from this and
  fail. Wrap guest commands in `bash -c '…'` so the `cd` noise does not
  break the check. Add `2>/dev/null` to the `limactl shell` call itself to
  suppress both host-side `limactl` stderr and guest-side `cd` noise.
  Fixed in `mock-server/dev-twin.sh` (commit a4039d0) and applied to
  `mock-server/run-test.sh` when the harness was updated.
- **`sudo systemd-run` runs the driver as root — do not `whoami`-check the
  driver user.** The test-twin driver is launched via `sudo systemd-run
  --unit=tianlu-driver` (`run-test.sh launch_driver`), so the driver runs
  as root. An assertion that checks `whoami` against the Lima-pinned user
  (`floci-runner`) will always fail — `whoami` returns `root`. To verify
  the Lima-pinned default user (from `floci-twin.yaml` `user:`), query
  `getent passwd floci-runner` and check the uid; do NOT use `whoami`. The
  driver being root is correct (it needs sudo for `setup-floci.sh`); the
  pinned-user check is about the VM's default login identity, not the
  driver's runtime identity.
- **`set -u` empty-array expansion.** `"${arr[@]}"` under `set -u` is an
  unbound-variable error on macOS bash 3.2 when the array is empty. Use
  `${arr[@]+"${arr[@]}"}` (only expand if set).
- **`vmType: vz` blocks unprivileged userns.** The macOS
  Virtualization.framework backend does not permit unprivileged user-namespace
  creation inside the guest (`unshare -rU` fails with EPERM on
  `/proc/self/uid_map` for every unprivileged user). Rootless Podman
  requires unprivileged userns, so the twin must use `vmType: qemu`. QEMU
  full-emulation permits it. `mountType` changes from `virtiofs` (requires
  vz) to `9p` (non-SSH, survives UFW enable).
- **`26.04` does NOT ship podman.** The Ubuntu 26.04 server-cloudimg-arm64
  manifest confirms no `podman`/`uidmap`/`passt`/`containers-common` in the
  base image. An earlier misdiagnosis (polluted instance from a manual
  debug run) suggested otherwise; the manifest is authoritative.

---

## 11. Methodological learnings

- **The twin's preflight must distinguish AppArmor-enforcement from
  nested-VM userns blocking.** The preflight asserts `sudo -u nobody unshare
  -rU true` MUST FAIL with EPERM — on a real server that proves AppArmor
  enforcement; in a vz Lima VM it proves the VZ userns block. Both produce
  EPERM. The twin now uses qemu, where the EPERM is genuinely AppArmor.
- **Debug cycles pollute the instance.** Running the installer manually in
  the guest to see an error installs podman / corrupts Podman storage,
  which then makes a fresh `--fresh` orchestrator run's preflight fail
  (`podman-present`) or hit storage-layer corruption
  (`invalid internal status / podman system migrate`). Rule: once the
  orchestrator launches the driver, do not run installer/podman commands
  manually in the same guest; delete and recreate the twin for a clean run.
- **Bisection via `systemd-run --user -p <directive>` is definitive for
  Quadlet `[Service]` hardening.** It runs a command under
  `systemd-executor` with a specified directive, no file editing or
  StartLimitBurst exhaustion, and isolates exactly which directive breaks.
  Use it before guessing.
- **Kernel audit (`dmesg` / `journalctl`) is the source of truth for
  AppArmor denials.** The denial line names the exact profile, the binary,
  the capability/operation, and the transition target. Read it before
  theorizing.