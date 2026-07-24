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

.PHONY: lint test check ci-test twin-test dev-up dev-down dev-status dev-shell dev-recreate dev-reset dev-env

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
