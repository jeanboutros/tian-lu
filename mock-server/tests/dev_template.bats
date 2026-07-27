#!/usr/bin/env bats

TEMPLATE="${BATS_TEST_DIRNAME}/../../mock-server/lima/floci-dev.yaml"

@test "limactl validate passes" {
  if ! command -v limactl >/dev/null 2>&1; then
    skip "limactl not available"
  fi
  run limactl validate "$TEMPLATE"
  [ "$status" -eq 0 ]
}

@test "template has floci-dev-data disk" {
  grep -q 'name: floci-dev-data' "$TEMPLATE"
}

@test "template formats disk as ext4" {
  grep -q 'format: true' "$TEMPLATE"
  grep -q 'fsType: ext4' "$TEMPLATE"
}

@test "template has exactly 9 hostIP 127.0.0.1 entries" {
  count=$(grep -c 'hostIP: "127.0.0.1"' "$TEMPLATE")
  [ "$count" -eq 9 ]
}

@test "template has guestPort 4566" {
  grep -q 'guestPort: 4566' "$TEMPLATE"
}

@test "template has guestPort 9169" {
  grep -q 'guestPort: 9169' "$TEMPLATE"
}

@test "template has ElastiCache range 6379-6399" {
  grep -q 'guestPortRange: \[6379, 6399\]' "$TEMPLATE"
}

@test "template has RDS range 7001-7099" {
  grep -q 'guestPortRange: \[7001, 7099\]' "$TEMPLATE"
}

@test "template has ECR range 5100-5199" {
  grep -q 'guestPortRange: \[5100, 5199\]' "$TEMPLATE"
}

@test "template has EKS range 6500-6599" {
  grep -q 'guestPortRange: \[6500, 6599\]' "$TEMPLATE"
}

@test "template does not include 9200-9299 (Lambda Runtime API)" {
  run grep '9200' "$TEMPLATE"
  [ "$status" -ne 0 ]
}

@test "template does not reference floci-twin" {
  run grep 'floci-twin' "$TEMPLATE"
  [ "$status" -ne 0 ]
}

@test "template has writable: false for repo mount" {
  grep -q 'writable: false' "$TEMPLATE"
}

@test "template does not have writable: true" {
  run grep 'writable: true' "$TEMPLATE"
  [ "$status" -ne 0 ]
}
