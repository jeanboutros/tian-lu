# C0: T1 Re-run — psc-0003

## Results
| Command | Exit Code | Details |
|---------|-----------|---------|
| make lint | 0 | shellcheck + bash -n passed on all scripts |
| make test | 2 | 133/133 main tests passed; 1 failure in mock-server/tests/dev_twin.bats (test 77: `dev_up Absent path: disk create before limactl start`) |

## Verdict
FAIL

## Failure Detail
- **Test 77** (`dev_up Absent path: disk create before limactl start`) in `mock-server/tests/dev_twin.bats:381` — `[ "$status" -eq 0 ]` failed.
- This is a pre-existing failure in the dev-twin test suite, not introduced by psc-0003.
- All 133 main installer tests (`tests/`) passed.
