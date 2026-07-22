# Development tasks for the tianlu setup scripts.
#
#   make lint    shellcheck + bash -n on the script
#   make test    bats unit tests (command mocking via PATH stubs)
#   make check   both
#
# Requires: shellcheck, bats-core  (brew install shellcheck bats-core)

SHELL := /bin/bash
SCRIPT := setup-floci.sh
STUB := tests/stubs/_stub

.PHONY: lint test check

lint:
	shellcheck $(SCRIPT) $(STUB)
	bash -n $(SCRIPT)

test:
	bats tests/

check: lint test
