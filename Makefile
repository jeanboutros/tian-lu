# Development tasks for the tianlu setup scripts.
#
#   make lint       shellcheck + bash -n on the installer and harness scripts
#   make test       bats unit tests (command mocking via PATH stubs)
#   make check      both
#   make ci-test    make check inside disposable containers for every image in
#                   CI_TEST_IMAGES (default: ubuntu:24.04 — the current GitHub
#                   Actions ubuntu-latest — and ubuntu:26.04 — the project's
#                   target production OS). Each has the real podman/crun/
#                   pasta/uidmap binary chain, which catches
#                   host-filesystem-dependent test bugs that pass on macOS
#                   (where those binaries are absent) but fail there.
#                   override via, e.g., make ci-test CI_TEST_IMAGES="ubuntu:26.04"
#   make twin-test  build + drive the Lima digital twin (Apple Silicon, macOS 13+)
#                   override flags via TWIN_FLAGS, e.g. make twin-test TWIN_FLAGS="--fresh --reboot-test --destroy"
#
# Requires: shellcheck, bats-core  (brew install shellcheck bats-core)
# ci-test also requires: podman  (brew install podman; podman machine init/start on macOS)
# twin-test also requires: lima, qemu  (brew install lima qemu)

SHELL := /bin/bash
SCRIPT := setup-floci.sh
STUB := tests/stubs/_stub
MOCK_STUB := mock-server/tests/stubs/_stub
DEV_TWIN_SCRIPT := mock-server/dev-twin.sh
MOCK_SHELLS := mock-server/run-test.sh mock-server/in-vm/run-in-vm.sh mock-server/in-vm/lib/assert.sh $(DEV_TWIN_SCRIPT)
MOCK_SUDO := mock-server/tests/stubs/bin/sudo
HOOK := scripts/pre-commit
TWIN_FLAGS ?= --fresh --reboot-test
CI_TEST_IMAGES ?= ubuntu:24.04 ubuntu:26.04

.PHONY: help lint test check ci-test twin-test dev-up dev-down dev-status dev-shell dev-recreate dev-reset dev-env

help:
	@printf '\n'
	@printf 'Tianlu — Floci on Ubuntu with rootless Podman\n'
	@printf '\n'
	@printf 'BUILD & CI (no VM required):\n'
	@printf '  %-16s %s\n' 'lint'          'shellcheck + bash -n on setup-floci.sh and all harness scripts.'
	@printf '  %-16s %s\n' 'test'          'bats unit tests with command mocking via PATH stubs.'
	@printf '  %-16s %s\n' ''              '  Fast (~seconds). No real Podman, systemd, or UFW needed.'
	@printf '  %-16s %s\n' 'check'         'lint + test. Run before every commit (pre-commit hook does this).'
	@printf '  %-16s %s\n' 'ci-test'       'make check inside disposable podman containers (ubuntu:24.04 + ubuntu:26.04).'
	@printf '  %-16s %s\n' ''              '  Uses the real podman/crun/pasta/uidmap binary chain — catches host bugs'
	@printf '  %-16s %s\n' ''              '  that pass on macOS (where those binaries are absent) but fail in CI.'
	@printf '  %-16s %s\n' ''              '  Requires: podman (brew install podman; podman machine init/start).'
	@printf '  %-16s %s\n' ''              '  Override: make ci-test CI_TEST_IMAGES="ubuntu:26.04"'
	@printf '  %-16s %s\n' 'twin-test'     'Build + drive the Lima digital twin end-to-end (Apple Silicon, macOS 13+).'
	@printf '  %-16s %s\n' ''              '  Boots a headless Ubuntu arm64 VM, runs setup-floci.sh, proves idempotency,'
	@printf '  %-16s %s\n' ''              '  spawns an arm64 Lambda sidecar, optionally reboots for autostart proof.'
	@printf '  %-16s %s\n' ''              '  Affects: mock-server/evidence/<UTC-ts>/ (git-ignored run artifacts).'
	@printf '  %-16s %s\n' ''              '  Requires: lima, qemu (brew install lima qemu).'
	@printf '  %-16s %s\n' ''              '  Override: make twin-test TWIN_FLAGS="--fresh --reboot-test --destroy"'
	@printf '  %-16s %s\n' ''              '  When to use: before pushing any setup-floci.sh or harness change.'
	@printf '\n'
	@printf 'PERSISTENT DEV TWIN (local Floci for interactive AWS development):\n'
	@printf '  %-16s %s\n' 'dev-up'        'Create or resume the floci-dev Lima VM.'
	@printf '  %-16s %s\n' ''              '  Runs setup-floci.sh only on first creation; subsequent calls resume fast.'
	@printf '  %-16s %s\n' ''              '  Affects: ~/.lima/floci-dev (VM), /etc/hosts (tianlu-floci block),'
	@printf '  %-16s %s\n' ''              '           ~/.aws/{config,credentials} (floci-dev profile).'
	@printf '  %-16s %s\n' ''              '  When to use: daily start — resumes without reinstalling.'
	@printf '  %-16s %s\n' 'dev-down'      'Stop the floci-dev VM. AWS data on the data disk is preserved.'
	@printf '  %-16s %s\n' ''              '  When to use: free RAM/CPU without losing AWS state.'
	@printf '  %-16s %s\n' 'dev-status'    'Show instance, disk, floci.service, and health state for floci-dev.'
	@printf '  %-16s %s\n' ''              '  When to use: first thing to check if anything seems off.'
	@printf '  %-16s %s\n' 'dev-shell'     'Open an interactive shell inside the floci-dev VM.'
	@printf '  %-16s %s\n' 'dev-recreate'  'Delete and recreate the VM OS; retain all AWS data on the data disk.'
	@printf '  %-16s %s\n' ''              '  Affects: ~/.lima/floci-dev (rebuilt); floci-dev-data disk is KEPT.'
	@printf '  %-16s %s\n' ''              '  When to use: after installer/harness changes to re-run setup-floci.sh cleanly.'
	@printf '  %-16s %s\n' 'dev-reset'     'Delete the VM AND the data disk — PERMANENT. Requires: CONFIRM=reset.'
	@printf '  %-16s %s\n' ''              '  Affects: deletes ~/.lima/floci-dev, floci-dev-data disk, /etc/hosts block.'
	@printf '  %-16s %s\n' ''              '  When to use: starting over from scratch. All AWS state is lost.'
	@printf '  %-16s %s\n' 'dev-env'       'Configure the AWS CLI floci-dev profile; print export instructions.'
	@printf '  %-16s %s\n' ''              '  Affects: ~/.aws/config, ~/.aws/credentials (adds floci-dev profile + creds).'
	@printf '  %-16s %s\n' ''              '  When to use: once per clone, then: eval "$$(make dev-env -- --export)"'
	@printf '\n'
	@printf 'PREREQUISITES:\n'
	@printf '  %-16s %s\n' 'lint/test/check'  'brew install shellcheck bats-core'
	@printf '  %-16s %s\n' 'ci-test'          'brew install podman  (then: podman machine init && podman machine start)'
	@printf '  %-16s %s\n' 'twin-test/dev-*'  'brew install lima qemu'
	@printf '\n'

lint:
	shellcheck $(SCRIPT) $(STUB) $(MOCK_SHELLS) $(MOCK_STUB) $(MOCK_SUDO) $(HOOK)
	bash -n $(SCRIPT) $(MOCK_SHELLS) $(HOOK)

test:
	bats tests/
	bats mock-server/tests/

check: lint test

# ci-test: reproduce the GitHub Actions ubuntu-latest job (plus the project's
# target 26.04 production OS) locally in disposable podman containers, one
# per image in CI_TEST_IMAGES. The real /usr/bin/{podman,crun,pasta,
# newuidmap,newgidmap} binary chain is present here (unlike a bare macOS dev
# box), which is what surfaced the phase1_2.bats CI-only failures — tests
# that pass because a binary is ABSENT on macOS must explicitly point unused
# binary vars at a nonexistent path rather than relying on the host.
ci-test:
	@set -e; \
	for image in $(CI_TEST_IMAGES); do \
	  echo "=== ci-test: $$image ==="; \
	  podman run --rm \
	    -v "$(CURDIR)":/repo:ro \
	    -w /repo \
	    "$$image" \
	    bash -c 'set -e; \
	      export DEBIAN_FRONTEND=noninteractive; \
	      apt-get update -qq; \
	      apt-get install -y -qq make shellcheck bats podman crun passt uidmap >/dev/null; \
	      make check'; \
	done

twin-test:
	./mock-server/run-test.sh $(TWIN_FLAGS)

dev-up:
	$(DEV_TWIN_SCRIPT) up

dev-down:
	$(DEV_TWIN_SCRIPT) down

dev-status:
	$(DEV_TWIN_SCRIPT) status

dev-shell:
	$(DEV_TWIN_SCRIPT) shell

dev-recreate:
	$(DEV_TWIN_SCRIPT) recreate

dev-reset:
	$(DEV_TWIN_SCRIPT) reset

dev-env:
	$(DEV_TWIN_SCRIPT) env
