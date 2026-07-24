# Development tasks for the tianlu setup scripts.
#
#   make lint       shellcheck + bash -n on the installer and harness scripts
#   make test       bats unit tests (command mocking via PATH stubs)
#   make check      both
#   make twin-test  build + drive the Lima digital twin (Apple Silicon, macOS 13+)
#                   override flags via TWIN_FLAGS, e.g. make twin-test TWIN_FLAGS="--fresh --reboot-test --destroy"
#
# Requires: shellcheck, bats-core  (brew install shellcheck bats-core)
# twin-test also requires: lima, qemu  (brew install lima qemu)

SHELL := /bin/bash
SCRIPT := setup-floci.sh
STUB := tests/stubs/_stub
MOCK_STUB := mock-server/tests/stubs/_stub
MOCK_SHELLS := mock-server/run-test.sh mock-server/in-vm/run-in-vm.sh mock-server/in-vm/lib/assert.sh
MOCK_SUDO := mock-server/tests/stubs/bin/sudo
HOOK := scripts/pre-commit
TWIN_FLAGS ?= --fresh --reboot-test

.PHONY: lint test check twin-test

lint:
	shellcheck $(SCRIPT) $(STUB) $(MOCK_SHELLS) $(MOCK_STUB) $(MOCK_SUDO) $(HOOK)
	bash -n $(SCRIPT) $(MOCK_SHELLS) $(HOOK)

test:
	bats tests/
	bats mock-server/tests/

check: lint test

twin-test:
	./mock-server/run-test.sh $(TWIN_FLAGS)
