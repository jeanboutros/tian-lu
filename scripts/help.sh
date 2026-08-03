#!/usr/bin/env bash
set -euo pipefail

cat <<'EOF'

Tianlu — Floci on Ubuntu with rootless Podman

BUILD & CI (no VM required):
  lint             shellcheck + bash -n on setup-floci.sh and all harness scripts.
  test             bats unit tests with command mocking via PATH stubs.
                     Fast (~seconds). No real Podman, systemd, or UFW needed.
  check            lint + test. Run before every commit (pre-commit hook does this).
  ci-test          make check inside disposable podman containers (ubuntu:24.04 + ubuntu:26.04).
                     Uses the real podman/crun/pasta/uidmap binary chain — catches host bugs
                     that pass on macOS (where those binaries are absent) but fail in CI.
                     Requires: podman (brew install podman; podman machine init/start).
                     Override: make ci-test CI_TEST_IMAGES="ubuntu:26.04"
  twin-test        Build + drive the Lima digital twin end-to-end (Apple Silicon, macOS 13+).
                     Boots a headless Ubuntu arm64 VM, runs setup-floci.sh, proves idempotency,
                     spawns an arm64 Lambda sidecar, optionally reboots for autostart proof.
                     Affects: mock-server/evidence/<UTC-ts>/ (git-ignored run artifacts).
                     Requires: lima, qemu (brew install lima qemu).
                     Override: make twin-test TWIN_FLAGS="--fresh --reboot-test --destroy"
                     When to use: before pushing any setup-floci.sh or harness change.

PERSISTENT DEV TWIN (local Floci for interactive AWS development):
  dev-up           Create or resume the floci-dev Lima VM.
                     Runs setup-floci.sh only on first creation; subsequent calls resume fast.
                     Affects: ~/.lima/floci-dev (VM), /etc/hosts (tianlu-floci block),
                              ~/.cache/tianlu-floci/dev/account.secret (account credential).
                     Your real ~/.aws is never written to.
                     When to use: daily start — resumes without reinstalling.
  dev-down         Stop the floci-dev VM. AWS data on the data disk is preserved.
                     When to use: free RAM/CPU without losing AWS state.
  dev-status       Show instance, disk, floci.service, and health state for floci-dev.
                     When to use: first thing to check if anything seems off.
  dev-shell        Open an interactive shell inside the floci-dev VM.
  dev-recreate     Delete and recreate the VM OS; retain all AWS data on the data disk.
                     Affects: ~/.lima/floci-dev (rebuilt); floci-dev-data disk is KEPT.
                     When to use: after installer/harness changes to re-run setup-floci.sh cleanly.
  dev-reset        Delete the VM AND the data disk — PERMANENT. Requires: CONFIRM=reset.
                     Affects: deletes ~/.lima/floci-dev, floci-dev-data disk, /etc/hosts block,
                              and ~/.cache/tianlu-floci/ (profile store + account secret).
                     When to use: starting over from scratch. All AWS state is lost.
  dev-env          Configure the project-local ns-tianlu-floci-dev AWS CLI profile and print
                     the connect block.
                     Affects: ~/.cache/tianlu-floci/aws/{config,credentials} only — your real
                              ~/.aws is left untouched.
                     When to use: once per clone, for interactive `aws` commands.
  dev-env-export   The same, printing ONLY the export lines, for: eval "$(make dev-env-export)"
                     Terraform needs neither: infra/stage.sh reads the account secret from
                     ~/.cache/tianlu-floci/dev/account.secret and derives the AKID from the
                     tfvars, so `make -C infra apply` works with nothing exported.

PREREQUISITES:
  lint/test/check  brew install shellcheck bats-core
  ci-test          brew install podman  (then: podman machine init && podman machine start)
  twin-test/dev-*  brew install lima qemu

EOF
