# AGENTS.md — tests/

## OVERVIEW

Tier-2 stubbed bats unit suite for `setup-floci.sh`: sources the script in a fresh subshell, runs one function per test, asserts what external commands would have been invoked and what state would have been written.

## STRUCTURE

Absolute paths under `/Users/jeanboutros/Projects/tian-lu/tests/`:

- `test_helper.bash` — shared setup. Exports `REPO_ROOT`, `SCRIPT` (setup-floci.sh path), `STUB_BIN`. Defines `setup_stub_env` (creates `TEST_TMP`, `FLOCI_HOME`, empty `STUB_LOG`, prepends `STUB_BIN` to `PATH`), `teardown_stub_env`, `stub_calls <name>` (greps STUB_LOG).
- `stubs/_stub` — generic logging stub. Logs `<basename> <args...>` to `$STUB_LOG`; honours `STUB_RC_<NAME>` (exit code) and `STUB_OUT_<NAME>` (stdout). `<NAME>` = upper-cased argv[0], non-alnum → `_`.
- `stubs/bin/` — 19 entries on PATH. 16 symlinks to `_stub` (`apparmor_parser`, `apt-get`, `curl`, `getent`, `hostname`, `id`, `install`, `ip`, `loginctl`, `openssl`, `passwd`, `sleep`, `sysctl`, `ufw`, `useradd`, `usermod`). 3 dedicated subcommand-aware stubs: `podman` (subcommand keys like `NETWORK_INSPECT`, `IMAGE_INSPECT`), `systemctl` (per-subcommand rc: `IS_ACTIVE`, `DAEMON_RELOAD`, `START`, `ENABLE`…), `sudo` (strips `-u user`, `env VAR=val…`, known sudo option flags, then `exec`s the underlying stub so the called command still logs).
- `smoke.bats` (45 lines) — sourceability, `main` defined, config overrides, direct execution hits `assert_root_or_sudo`.
- `phase1_2.bats` (538) — `assert_root_or_sudo`, `assert_ubuntu_version`, `assert_userns_allowed`, `detect_hostname_and_ip`, `parse_args`, `create_floci_user`, `lock_floci_password`, `configure_subuid_subgid`.
- `phase3_4.bats` (250) — `install_podman`, `enable_lingering`, `configure_xdg_runtime_dir`, `start_podman_socket`, `create_podman_network`, `pull_floci_image`.
- `phase5.bats` (349) — `create_data_directory`, `add_hosts_entry`, `generate_presign_secret`, `write_env_file`.
- `phase6_7.bats` (231) — `phase_pause`, `configure_firewall`, `verify_health`, `print_summary`.
- `quadlet.bats` (357) — `write_quadlet_unit` content/idempotency, `enable_systemd_service`.

## WHERE TO LOOK

| Need to test… | File |
| --- | --- |
| Pre-flight gates, user creation, subuid/subgid | `phase1_2.bats` |
| Podman install, lingering, socket, network, image pull | `phase3_4.bats` |
| Data dir, `/etc/hosts` entry, presign secret, env file | `phase5.bats` |
| Firewall (UFW), health probe, summary | `phase6_7.bats` |
| Quadlet content + idempotent backup | `quadlet.bats` |
| Sourcing works, `main` defined, overrides honoured | `smoke.bats` |
| Stub mechanics (rc/stdout env vars, argv logging) | `stubs/_stub`, `stubs/bin/{podman,systemctl,sudo}` |
| Path layout, scratch dir lifecycle | `test_helper.bash` |

The Lima-twin harness has its own separate suite at `mock-server/tests/` (8 files, own `stubs/`) — not part of this directory.

## CONVENTIONS

1. **`_run_fn "<overrides>" "fn_call"` launches a fresh `bash -c` subshell per test.** Inline overrides (e.g. `export STUB_OUT_ID=1000`) are inlined before `source "${SCRIPT}"`. Subshell isolation prevents `readonly` CONFIG vars from colliding across tests — never run two functions in the same shell.
2. **One function per test.** Each test sources `setup-floci.sh` once, calls exactly one phase function (or `;`-separated sequence), then asserts `STUB_LOG` contents and resulting file state.
3. **Quadlet tests install transparent wrappers** (`mkdir`, `tee`, `chmod`, `cp`, `mv`) in a per-test `TEST_BIN` dir. Each wrapper logs to `STUB_LOG` AND `exec`s the real system binary captured before `TEST_BIN` was prepended to `PATH` (`REAL_MKDIR`, `REAL_TEE`, …). This validates both the stub log AND the real on-disk file content/mode. The real-binary paths are resolved once in `setup()` via `command -v`, before the wrappers appear on PATH.
4. **UFW rule checks use `grep -qF` (literal substring), not exact-line match.** Arg ordering and flag positions vary across callers; port-anchored substrings (`"ufw allow from 10.0.0.0/8 to any port 4566 proto tcp"`) are the stable invariant.
5. **One generic `_stub` binary handles 19 commands** via `argv[0]` (`basename "$0"` → `STUB_RC_<NAME>`). Subcommand-aware stubs (`podman`, `systemctl`, `sudo`) exist only when per-subcommand rc control is needed; do not duplicate this logic in per-command scripts.
6. **Override semantics:** any CONFIG var that uses the `readonly VAR="${VAR:-default}"` form in `setup-floci.sh` is injectable via `export VAR=value` inside the `_run_fn` overrides string. This is how tests reshape `FLOCI_HOME`, `OS_RELEASE_FILE`, `USERNS_SYSCTL_FILE`, etc., without editing the script.
7. **`phase_pause` is invoked with stdin closed (`</dev/null`)** so the TTY-prompt branch never blocks bats — see `phase6_7.bats` `_run_fn`.

## ANTI-PATTERNS

1. **Never assert full `STUB_LOG` equality.** Fragile to arg ordering. Use `grep -qF "substring"` or `stub_calls <name>` + targeted greps.
2. **Never use `systemctl is-system-running`.** It fails on `degraded`; use `is-active --quiet` (see root AGENTS.md critical gotcha).
3. **Never assert `whoami` from inside the test-twin driver.** It is always `root` (the driver runs under `sudo systemd-run`); query via `getent passwd <user>` (root AGENTS.md gotcha).
4. **Never add a new external command without a symlink in `tests/stubs/bin/`.** If `setup-floci.sh` starts calling a new binary, add a symlink to `_stub` (or a dedicated stub if it needs subcommand awareness) — otherwise the test hits the real binary on PATH and produces host-dependent results.
5. **Never bypass the `_run_fn` subshell for readonly-var tests.** The subshell isolation is what makes per-test overrides safe; running in the bats parent shell hits `readonly: cannot assign`.
6. **Never write to a symlink in `STUB_BIN` that points to `_stub`.** Doing so overwrites the generic stub. Use `TEST_BIN` for per-test wrappers (see quadlet.bats).
7. **Never rely on host-installed `podman` / `systemctl` / `ufw`.** Tests assert the script's behaviour, not the host's. The `STUB_BIN` prefix on PATH guarantees isolation; phase3_4 uses an isolated `scratch_bin` with only the commands the test needs (and no `podman`) to prove `command -v podman` actually fails inside the subshell.