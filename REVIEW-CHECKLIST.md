# setup-floci.sh — Implementation Review Checklist

Verification guide for the full implementation run (Units R, 0, 1–5 + one whole-branch fix).
Every change below lists the **commit hash**, the **file + final line numbers** (at current
`HEAD` = `ae04a83`), and a **command** to view the exact diff. There is **no git remote**, so
"links" are local `git` commands — run them yourself, or paste their output to an AI for
explanation.

- **Repo:** `/Users/ukcci1jbo/projects/tianlu`
- **HEAD:** `ae04a83` on branch `feature/lima-digital-twin`
- **Verify everything at once:** `make check` (shellcheck + `bash -n` + bats) → expect **100/100** green, ~22s.
- **Full run diff:** `git diff 0c91ec0..ae04a83 -- setup-floci.sh` (all script changes since the skeleton).
- **See a whole commit:** `git show <hash>` · **one file in a commit:** `git show <hash> -- <path>` · **a function's history:** `git log -L :<func>:setup-floci.sh`.

---

## ⚠️ Branch decision needed (read first)

A session fork split the work across two branches:

| Branch | Points at | Contains |
|---|---|---|
| `main` | `860539b` | Units R–5 (the 7 unit commits) — **no** detect fix |
| `feature/lima-digital-twin` (HEAD) | `ae04a83` | Units R–5 **+** `68cc8a5` (mock-server scaffold, **not from this run**) **+** the detect fix |

- All 7 unit commits are on **both** branches (they're ancestors of HEAD).
- The whole-branch fix (`ae04a83`) is **only** on `feature/lima-digital-twin`.
- `68cc8a5 chore(mock-server): scaffold VM harness layout` was committed **outside this run** (it sits between Unit 5 and the fix).

**I did not move any branch pointers.** Decide how you want these reconciled — e.g. cherry-pick `ae04a83` onto `main`, fast-forward `main` (which would also pull in `68cc8a5`), or leave as-is. Tell me and I'll do it.

Inspect: `git log --oneline --graph --all -12`

---

## Commit-level checklist

| ✔ | Unit | Commit | Subject | View |
|---|---|---|---|---|
| ☐ | R | `5defe4c` | docs: add project README | `git show 5defe4c` |
| ☐ | 0 | `4214449` | test: add bats+shellcheck harness, make script sourceable | `git show 4214449` |
| ☐ | 1 | `6428453` | feat: migrate Floci systemd unit to Quadlet (.container) | `git show 6428453` |
| ☐ | 2 | `bb9e1cf` | feat: Phase 1-2 preflight + user setup w/ scoped AppArmor userns | `git show bb9e1cf` |
| ☐ | 3 | `d53f827` | feat: Phase 3-4 rootless Podman, lingering, socket, network, image | `git show d53f827` |
| ☐ | 4 | `a4ff4bd` | feat: Phase 5 Floci config files (data dir, hosts, env, secret) | `git show a4ff4bd` |
| ☐ | 5 | `860539b` | feat: Phase 6-7 firewall/health/summary and wire main() | `git show 860539b` |
| ☐ | fix | `ae04a83` | fix: guard detect_hostname_and_ip pipelines against set -e abort | `git show ae04a83` |

All 8 commits are **SSH-signed** (verify: `git log --show-signature 0c91ec0..ae04a83` → each `Good "git" signature … jean.boutros@bauermediaoutdoor.com`).

---

## Function-level checklist (final line numbers at HEAD)

Each row: the function, where it lives now, what it does, and the commit that introduced it.
View a function's full current body: `sed -n '<start>,<end>p' setup-floci.sh` — or its history: `git log -L :<func>:setup-floci.sh`.

### CONFIG block (`setup-floci.sh:37–146`) — introduced 4214449, extended each unit
- ☐ Test-injectable `readonly VAR="${VAR:-default}"` form (line 37+). `git show 4214449 -- setup-floci.sh`
- ☐ Ports arrays (64–86), firewall scope + RFC1918 (88–95), paths (97–101), hosts/log (104–108), OS (111–112), poll knobs (115–120), XDG base (123), AppArmor/userns paths (126–129), runtime bins (132–134), sub{uid,gid} files (137–138).

### Phase helpers & service (Unit 1, `6428453`)
- ☐ `run_as_floci` — `setup-floci.sh:173` — privilege-drop (HOME/USER/PATH/XDG/DBUS). `git show 6428453 -- setup-floci.sh`
- ☐ `write_quadlet_unit` — `202` — atomic Quadlet `.container` write, backup-before-overwrite. (PublishPort lines later made dynamic in Unit 5.)
- ☐ `enable_systemd_service` — `269` — `daemon-reload` + idempotent `start` (NOT `enable` — Quadlet units are transient).

### Phase 1 – Preflight (Unit 2, `bb9e1cf`)
- ☐ `assert_root_or_sudo` — `284`
- ☐ `assert_ubuntu_version` — `292` — exact `ID=ubuntu`, `sort -V` version gate
- ☐ `assert_userns_allowed` — `345` — **scoped** AppArmor `podman-userns` profile; never disables the sysctl / never `apparmor=unconfined`
- ☐ `detect_hostname_and_ip` — `406` — awk-parsed IP + /24 (IFS-immune); **pipelines guarded `|| true`** by fix `ae04a83` (lines 409/414)
- ☐ `parse_args` — `432` — `--interactive`, `--firewall-scope=auto|rfc1918`

### Phase 2 – User setup (Unit 2, `bb9e1cf`)
- ☐ `create_floci_user` — `463` · ☐ `lock_floci_password` — `472` · ☐ `configure_subuid_subgid` — `485` (non-overlapping range scan)

### Phase 3 – Podman (Unit 3, `d53f827`)
- ☐ `install_podman` — `527` · ☐ `enable_lingering` — `537` (+ two-stage user-manager poll, §9.1) · ☐ `configure_xdg_runtime_dir` — `568` · ☐ `start_podman_socket` — `581` (`enable --now podman.socket` — a real distro unit)

### Phase 4 – Network & image (Unit 3, `d53f827`)
- ☐ `create_podman_network` — `600` · ☐ `pull_floci_image` — `608`

### Phase 5 – Floci config (Unit 4, `a4ff4bd`)
- ☐ `create_data_directory` — `622` · ☐ `add_hosts_entry` — `640` (managed marker block, `cmp -s` skip-when-unchanged) · ☐ `generate_presign_secret` — `687` (reuse-if-exists, `grep -m1`) · ☐ `write_env_file` — `712` (all 15 §12 keys, 0600, backup; `FLOCI_DOCKER_DOCKER_HOST` never emitted)

### Phase 6-7 + main (Unit 5, `860539b`)
- ☐ `phase_pause` — `749` (TTY-guarded, Ctrl-D safe)
- ☐ `configure_firewall` — `762` — asserts UFW active + default deny/reject; **never enables UFW** (anti-lockout); port-anchored idempotency
- ☐ `verify_health` — `803` — `curl --resolve` retry loop (§15.1)
- ☐ `print_summary` — `827` — scope + UNAUTHENTICATED risk statement + connection info
- ☐ `main` — `852` — full §15 phase sequence
- ☐ SC2034 blanket disable **removed**; `FLOCI_PORTS_CONTAINER` wired into `write_quadlet_unit`. Verify: `grep -c disable=SC2034 setup-floci.sh` → `0`

---

## Documentation changes

- ☐ `README.md` — new (Unit R `5defe4c`). `git show 5defe4c`
- ☐ `docs/design/solution-design.md` §9/§9.1/§15 → Quadlet (Unit 1). `git show 6428453 -- docs/design/solution-design.md`
- ☐ §4 (subuid constraint) + §11.2 (AppArmor userns) + §15 (Unit 2). `git show bb9e1cf -- docs/design/solution-design.md`
- ☐ §9.1 poll → run_as_floci (Unit 3). `git show d53f827 -- docs/design/solution-design.md`
- ☐ §10.4 LAN-detection wording (Unit 5). `git show 860539b -- docs/design/solution-design.md`
- ☐ `AGENTS.md` gotchas (Units 0/1/2). `git log -p -- AGENTS.md`
- ☐ `docs/design/gaps-register.md` GAP-014 (Unit 1). `git show 6428453 -- docs/design/gaps-register.md`

---

## Tests & harness

- ☐ `make check` → **100/100** bats, shellcheck clean, `bash -n` OK.
- ☐ `tests/smoke.bats` (Unit 0, updated Unit 5) · `tests/quadlet.bats` (18, Unit 1) · `tests/phase1_2.bats` (Unit 2, +2 in fix) · `tests/phase3_4.bats` (Unit 3) · `tests/phase5.bats` (Unit 4) · `tests/phase6_7.bats` (Unit 5)
- ☐ Stubs: generic `tests/stubs/_stub` (bash-3.2 fix in Unit 2); dedicated per-subcommand `sudo`/`systemctl` (Unit 1), `podman` (Unit 3); `hostname` (Unit 2), `sleep` (Unit 3).

---

## QA trail — what the Opus challenger caught & fixed (per unit)

| Unit | Verdict | Findings fixed before commit |
|---|---|---|
| 1 | SHIP | `enable`→`start` (Quadlet transient units can't be enabled) — caught in review; docs+code corrected |
| 2 | fixed then SHIP | **HIGH:** `detect_hostname_and_ip` IFS word-split bug (empty IP) + it had zero tests → awk rewrite + tests |
| 3 | SHIP | MED: install test host-dependent (would false-fail on Ubuntu); LOW: poll assertions, podman-stub flags, §5.2 comment |
| 4 | SHIP | MED: `grep -m1` (dup-key safety); MED: `cmp -s` idempotency (no /etc/hosts churn); LOW: CRLF, empty-value test |
| 5 | SHIP | MED: anchored firewall port grep (superstring couldn't mask a port); MED: anti-lockout test; LOW: reject policy, Ctrl-D, empty-array |
| whole-branch | fixed | Integration bug: bare global `SERVER_IP="$(pipe)"` aborts under `set -e`+pipefail → `|| true` guards (`ae04a83`) |

View any fix in context: `git show <unit-hash>` (the fixes are folded into each unit's single commit).

---

## Server integration checklist (you run on the Ubuntu box — macOS can't run Podman/systemd/UFW)

Unit tests mock every external command; these must be verified on a real Ubuntu 24.04+ host:
- ☐ Fresh run creates user/linger/socket/network/image/service; container reaches `active`.
- ☐ `verify_health` returns 200 — capture the `/_floci/init` body to close **GAP-009**.
- ☐ Re-run is a clean no-op (idempotency).
- ☐ Firewall scope correct; reboot (with lingering) auto-starts `floci.service` after `podman.socket` — **GAP-014**.
- ☐ k3s network mode + token — **GAP-013b**.
- ☐ On a host with **no default route**, confirm the detect fallback works (the `ae04a83` fix) rather than aborting.
