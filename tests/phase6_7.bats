#!/usr/bin/env bats
#
# Unit tests for Phase 6-7 functions:
#   phase_pause, configure_firewall, verify_health, print_summary.

load test_helper

# ---------------------------------------------------------------------------
# _run_fn: source the script with injectable overrides and run one function
# (or a ";"-separated sequence of function calls / prints).
#
# Usage: _run_fn "<overrides script text>" "fn_call [args]"
#
# Each test runs the script in a fresh bash -c subshell so that `readonly`
# CONFIG vars do not collide between tests. Stdin is explicitly closed
# (</dev/null) so phase_pause can never block waiting on bats' own stdin.
# ---------------------------------------------------------------------------
_run_fn() {
  local overrides="$1"
  local fn_call="$2"
  bash -c "
    export PATH='${PATH}'
    export STUB_LOG='${STUB_LOG}'
    ${overrides}
    source '${SCRIPT}'
    ${fn_call}
  " </dev/null
}

setup() {
  setup_stub_env
}

teardown() {
  teardown_stub_env
}

# ===========================================================================
# phase_pause
# ===========================================================================

@test "phase_pause: INTERACTIVE=false returns 0 without prompting" {
  run _run_fn "export INTERACTIVE=false" "phase_pause; echo AFTER"
  [ "$status" -eq 0 ]
  [[ "$output" == *"AFTER"* ]]
}

@test "phase_pause: INTERACTIVE=true but stdin is not a TTY returns 0 (never hangs)" {
  run _run_fn "export INTERACTIVE=true" "phase_pause; echo AFTER"
  [ "$status" -eq 0 ]
  [[ "$output" == *"AFTER"* ]]
}

# ===========================================================================
# configure_firewall
# ===========================================================================

@test "configure_firewall: rejects when ufw status lacks Status: active" {
  run _run_fn \
    "export FIREWALL_SCOPE=rfc1918; export STUB_OUT_UFW='Status: inactive'" \
    "configure_firewall"
  [ "$status" -ne 0 ]
  [[ "$output" == *"active"* ]]
}

@test "configure_firewall: rejects when active but default policy is not deny (incoming)" {
  local ufw_out
  ufw_out=$'Status: active\nDefault: allow (incoming), deny (outgoing), disabled (routed)'
  local overrides
  overrides="export FIREWALL_SCOPE=rfc1918
export STUB_OUT_UFW='${ufw_out}'"

  run _run_fn "$overrides" "configure_firewall"
  [ "$status" -ne 0 ]
  [[ "$output" == *"deny"* ]]
}

@test "configure_firewall: rfc1918 scope adds allow rules for all RFC1918 subnets" {
  local ufw_out
  ufw_out=$'Status: active\nDefault: deny (incoming), allow (outgoing), disabled (routed)'
  local overrides
  overrides="export FIREWALL_SCOPE=rfc1918
export STUB_OUT_UFW='${ufw_out}'"

  run _run_fn "$overrides" "configure_firewall"
  [ "$status" -eq 0 ]

  grep -qF "ufw allow from 10.0.0.0/8 to any port 4566 proto tcp" "$STUB_LOG"
  grep -qF "ufw allow from 172.16.0.0/12 to any port 4566 proto tcp" "$STUB_LOG"
  grep -qF "ufw allow from 192.168.0.0/16 to any port 4566 proto tcp" "$STUB_LOG"

  # Anti-lockout invariant: configure_firewall must never enable UFW or
  # touch the default policy — only the operator does that, up front.
  run grep -qE '^ufw (enable|--force enable|default)' "$STUB_LOG"
  [ "$status" -ne 0 ]
}

@test "configure_firewall: never enables UFW or changes the default policy" {
  local ufw_out
  ufw_out=$'Status: active\nDefault: deny (incoming), allow (outgoing), disabled (routed)'
  local overrides
  overrides="export FIREWALL_SCOPE=rfc1918
export STUB_OUT_UFW='${ufw_out}'"

  run _run_fn "$overrides" "configure_firewall"
  [ "$status" -eq 0 ]

  run grep -qE '^ufw (enable|--force enable|default)' "$STUB_LOG"
  [ "$status" -ne 0 ]
}

@test "configure_firewall: accepts default policy reject (incoming) and still adds rules" {
  local ufw_out
  ufw_out=$'Status: active\nDefault: reject (incoming), allow (outgoing), disabled (routed)'
  local overrides
  overrides="export FIREWALL_SCOPE=rfc1918
export STUB_OUT_UFW='${ufw_out}'"

  run _run_fn "$overrides" "configure_firewall"
  [ "$status" -eq 0 ]

  grep -qF "ufw allow from 10.0.0.0/8 to any port 4566 proto tcp" "$STUB_LOG"
  grep -qF "ufw allow from 172.16.0.0/12 to any port 4566 proto tcp" "$STUB_LOG"
  grep -qF "ufw allow from 192.168.0.0/16 to any port 4566 proto tcp" "$STUB_LOG"
}

@test "configure_firewall: auto scope adds allow rules for SERVER_LAN_SUBNET" {
  local ufw_out
  ufw_out=$'Status: active\nDefault: deny (incoming), allow (outgoing), disabled (routed)'
  local overrides
  overrides="export FIREWALL_SCOPE=auto
export SERVER_LAN_SUBNET=192.168.1.0/24
export STUB_OUT_UFW='${ufw_out}'"

  run _run_fn "$overrides" "configure_firewall"
  [ "$status" -eq 0 ]

  grep -qF "ufw allow from 192.168.1.0/24 to any port 4566 proto tcp" "$STUB_LOG"
}

@test "configure_firewall: auto scope with empty SERVER_LAN_SUBNET fails" {
  local ufw_out
  ufw_out=$'Status: active\nDefault: deny (incoming), allow (outgoing), disabled (routed)'
  local overrides
  overrides="export FIREWALL_SCOPE=auto
export SERVER_LAN_SUBNET=
export STUB_OUT_UFW='${ufw_out}'"

  run _run_fn "$overrides" "configure_firewall"
  [ "$status" -ne 0 ]
}

@test "configure_firewall: idempotent — an already-present port+subnet rule is not re-issued" {
  local ufw_out
  ufw_out=$'Status: active\nDefault: deny (incoming), allow (outgoing), disabled (routed)\n4566/tcp                   ALLOW IN    10.0.0.0/8'
  local overrides
  overrides="export FIREWALL_SCOPE=rfc1918
export STUB_OUT_UFW='${ufw_out}'"

  run _run_fn "$overrides" "configure_firewall"
  [ "$status" -eq 0 ]

  # The already-present rule for 10.0.0.0/8 port 4566 must NOT be re-issued.
  run grep -qF "ufw allow from 10.0.0.0/8 to any port 4566 proto tcp" "$STUB_LOG"
  [ "$status" -ne 0 ]

  # A different port for the same subnet, not already present, must still be added.
  grep -qF "ufw allow from 10.0.0.0/8 to any port 6379:6399 proto tcp" "$STUB_LOG"
}

@test "configure_firewall: idempotency check is port-anchored — a rule for port 24566 does not mask port 4566" {
  local ufw_out
  ufw_out=$'Status: active\nDefault: deny (incoming), allow (outgoing), disabled (routed)\n24566/tcp                  ALLOW IN    10.0.0.0/8'
  local overrides
  overrides="export FIREWALL_SCOPE=rfc1918
export STUB_OUT_UFW='${ufw_out}'"

  run _run_fn "$overrides" "configure_firewall"
  [ "$status" -eq 0 ]

  # A pre-existing rule for port 24566 must not cause port 4566 to be
  # skipped as if it were already allowed (substring false-positive).
  grep -qF "ufw allow from 10.0.0.0/8 to any port 4566 proto tcp" "$STUB_LOG"
}

# ===========================================================================
# verify_health
# ===========================================================================

@test "verify_health: returns 0 on HTTP 200 and calls curl with --resolve and the health path" {
  run _run_fn "export STUB_OUT_CURL=200" "verify_health"
  [ "$status" -eq 0 ]
  grep -qF -- "--resolve tianlu-floci:4566:127.0.0.1" "$STUB_LOG"
  grep -qF "https://tianlu-floci:4566/_floci/init" "$STUB_LOG"
}

@test "verify_health: exits non-zero immediately on an error HTTP code" {
  run _run_fn "export STUB_OUT_CURL=503" "verify_health"
  [ "$status" -ne 0 ]
  [[ "$output" == *"503"* ]]
}

@test "verify_health: times out (non-zero) quickly when curl always returns 000" {
  run _run_fn \
    "export STUB_OUT_CURL=000; export HEALTH_POLL_TRIES=2; export HEALTH_POLL_SLEEP=0" \
    "verify_health"
  [ "$status" -ne 0 ]
  [[ "$output" == *"timed out"* ]]
}

@test "verify_health: times out (non-zero) when curl itself fails (connection refused, rc=7)" {
  run _run_fn \
    "export STUB_RC_CURL=7; export STUB_OUT_CURL=''; export HEALTH_POLL_TRIES=2; export HEALTH_POLL_SLEEP=0" \
    "verify_health"
  [ "$status" -ne 0 ]
  [[ "$output" == *"timed out"* ]]
}

# ===========================================================================
# print_summary
# ===========================================================================

@test "print_summary: prints scope, an unauthenticated/risk statement, and the base URL" {
  run _run_fn \
    "export FIREWALL_SCOPE=rfc1918" \
    "UFW_TRUSTED_SUBNETS=(10.0.0.0/8 172.16.0.0/12 192.168.0.0/16); print_summary"
  [ "$status" -eq 0 ]
  [[ "$output" == *"rfc1918"* ]]
  [[ "$output" == *"UNAUTHENTICATED"* || "$output" == *"RISK"* || "$output" == *"risk"* ]]
  [[ "$output" == *"https://tianlu-floci:4566"* ]]
}
