#!/usr/bin/env bats
#
# Unit tests for Phase 5 functions:
#   create_data_directory, add_hosts_entry, generate_presign_secret,
#   write_env_file.

load test_helper

# ---------------------------------------------------------------------------
# _run_fn: source the script with injectable overrides and run one function
# (or a ";"-separated sequence of function calls / prints).
#
# Usage: _run_fn "VAR=val ..." "fn_call [args]"
#
# Each test runs the script in a fresh bash -c subshell so that `readonly`
# CONFIG vars do not collide between tests.
# ---------------------------------------------------------------------------
_run_fn() {
  local overrides="$1"
  local fn_call="$2"
  bash -c "
    export PATH='${PATH}'
    export STUB_LOG='${STUB_LOG}'
    export STUB_OUT_ID='1001'
    export FLOCI_HOME='${FLOCI_HOME}'
    export FLOCI_ENV_DIR='${FLOCI_ENV_DIR}'
    export FLOCI_ENV_FILE='${FLOCI_ENV_FILE}'
    export FLOCI_DATA_DIR='${FLOCI_DATA_DIR}'
    export HOSTS_FILE='${HOSTS_FILE}'
    ${overrides}
    source '${SCRIPT}'
    ${fn_call}
  "
}

setup() {
  setup_stub_env
  export FLOCI_ENV_DIR="${FLOCI_HOME}/.config/floci"
  export FLOCI_ENV_FILE="${FLOCI_ENV_DIR}/floci.env"
  export FLOCI_DATA_DIR="${TEST_TMP}/floci-data"
  export HOSTS_FILE="${TEST_TMP}/hosts"
}

teardown() {
  teardown_stub_env
}

_stat_mode() {
  stat -c '%a' "$1" 2>/dev/null || stat -f '%A' "$1"
}

# ===========================================================================
# create_data_directory
# ===========================================================================

@test "create_data_directory: uses FLOCI_HOST_PERSISTENT_PATH override" {
  local custom_path=/tmp/custom-data
  rm -rf "$custom_path"

  run _run_fn "export FLOCI_HOST_PERSISTENT_PATH='${custom_path}'" "create_data_directory"
  [ "$status" -eq 0 ]
  [ -d "$custom_path" ]
  [ "$(_stat_mode "$custom_path")" = "700" ]
  rm -rf "$custom_path"
}

@test "create_data_directory: creates the dir with mode 0700" {
  run _run_fn "" "create_data_directory"
  [ "$status" -eq 0 ]
  [ -d "$FLOCI_DATA_DIR" ]
  [ "$(_stat_mode "$FLOCI_DATA_DIR")" = "700" ]
}

@test "create_data_directory: idempotent on second run" {
  run _run_fn "" "create_data_directory"
  [ "$status" -eq 0 ]
  run _run_fn "" "create_data_directory"
  [ "$status" -eq 0 ]
  [ -d "$FLOCI_DATA_DIR" ]
  [ "$(_stat_mode "$FLOCI_DATA_DIR")" = "700" ]
}

# ===========================================================================
# add_hosts_entry
# ===========================================================================

@test "add_hosts_entry: adds marker block, preserves unrelated entries" {
  printf '%s\n' \
    '127.0.0.1 localhost' \
    '192.168.1.5 someotherhost' \
    >"$HOSTS_FILE"

  run _run_fn "" "add_hosts_entry"
  [ "$status" -eq 0 ]

  grep -qF '127.0.0.1 localhost' "$HOSTS_FILE"
  grep -qF '192.168.1.5 someotherhost' "$HOSTS_FILE"
  grep -qF '# BEGIN tianlu-floci (managed by setup-floci.sh)' "$HOSTS_FILE"
  grep -qF '127.0.0.1 tianlu-floci' "$HOSTS_FILE"
  grep -qF '# END tianlu-floci (managed by setup-floci.sh)' "$HOSTS_FILE"
}

@test "add_hosts_entry: idempotent — second run produces byte-identical file" {
  printf '%s\n' \
    '127.0.0.1 localhost' \
    '192.168.1.5 someotherhost' \
    >"$HOSTS_FILE"

  run _run_fn "" "add_hosts_entry"
  [ "$status" -eq 0 ]
  local first_sum
  first_sum="$(md5sum "$HOSTS_FILE" 2>/dev/null || md5 -q "$HOSTS_FILE")"

  run _run_fn "" "add_hosts_entry"
  [ "$status" -eq 0 ]
  local second_sum
  second_sum="$(md5sum "$HOSTS_FILE" 2>/dev/null || md5 -q "$HOSTS_FILE")"

  [ "$first_sum" = "$second_sum" ]
  # Exactly one BEGIN marker — no duplicate block.
  local marker_count
  marker_count="$(grep -c '# BEGIN tianlu-floci' "$HOSTS_FILE")"
  [ "$marker_count" -eq 1 ]
}

@test "add_hosts_entry: stale managed block (wrong IP) gets replaced, not duplicated" {
  printf '%s\n' \
    '127.0.0.1 localhost' \
    '# BEGIN tianlu-floci (managed by setup-floci.sh)' \
    '10.9.9.9 tianlu-floci' \
    '# END tianlu-floci (managed by setup-floci.sh)' \
    >"$HOSTS_FILE"

  run _run_fn "" "add_hosts_entry"
  [ "$status" -eq 0 ]

  grep -qF '127.0.0.1 localhost' "$HOSTS_FILE"
  grep -qF '127.0.0.1 tianlu-floci' "$HOSTS_FILE"
  run grep -qF '10.9.9.9 tianlu-floci' "$HOSTS_FILE"
  [ "$status" -ne 0 ]
  local marker_count
  marker_count="$(grep -c '# BEGIN tianlu-floci' "$HOSTS_FILE")"
  [ "$marker_count" -eq 1 ]
}

@test "add_hosts_entry: final file mode is 0644" {
  printf '%s\n' '127.0.0.1 localhost' >"$HOSTS_FILE"
  run _run_fn "" "add_hosts_entry"
  [ "$status" -eq 0 ]
  [ "$(_stat_mode "$HOSTS_FILE")" = "644" ]
}

@test "add_hosts_entry: second run on an unchanged file leaves inode untouched" {
  printf '%s\n' \
    '127.0.0.1 localhost' \
    '192.168.1.5 someotherhost' \
    >"$HOSTS_FILE"

  run _run_fn "" "add_hosts_entry"
  [ "$status" -eq 0 ]

  local inode_before
  inode_before="$(stat -c '%i' "$HOSTS_FILE" 2>/dev/null || stat -f '%i' "$HOSTS_FILE")"

  run _run_fn "" "add_hosts_entry"
  [ "$status" -eq 0 ]

  local inode_after
  inode_after="$(stat -c '%i' "$HOSTS_FILE" 2>/dev/null || stat -f '%i' "$HOSTS_FILE")"

  [ "$inode_before" = "$inode_after" ]
}

@test "add_hosts_entry: recognizes a CRLF managed block and does not duplicate it" {
  printf '%s\r\n%s\r\n%s\r\n%s\r\n' \
    '127.0.0.1 localhost' \
    '# BEGIN tianlu-floci (managed by setup-floci.sh)' \
    '127.0.0.1 tianlu-floci' \
    '# END tianlu-floci (managed by setup-floci.sh)' \
    >"$HOSTS_FILE"

  run _run_fn "" "add_hosts_entry"
  [ "$status" -eq 0 ]

  local marker_count
  marker_count="$(grep -c '# BEGIN tianlu-floci' "$HOSTS_FILE")"
  [ "$marker_count" -eq 1 ]

  # The preserved (non-managed) CRLF line must survive with its CR intact.
  grep -qF $'127.0.0.1 localhost\r' "$HOSTS_FILE"
}

# ===========================================================================
# generate_presign_secret
# ===========================================================================

@test "generate_presign_secret: generates via openssl when no env file exists" {
  local fixed_secret
  fixed_secret="$(printf 'ab%.0s' $(seq 1 32))" # 64 hex chars ("ab" x 32)

  run _run_fn \
    "export STUB_OUT_OPENSSL='${fixed_secret}'" \
    "generate_presign_secret; printf '%s' \"\$PRESIGN_SECRET\""
  [ "$status" -eq 0 ]
  [ "$output" = "$fixed_secret" ]
}

@test "generate_presign_secret: reuses existing secret, does not call openssl" {
  mkdir -p "$FLOCI_ENV_DIR"
  printf 'FLOCI_AUTH_PRESIGN_SECRET=existingsecret123\n' >"$FLOCI_ENV_FILE"

  run _run_fn \
    "export STUB_OUT_OPENSSL='shouldnotappear'" \
    "generate_presign_secret; printf '%s' \"\$PRESIGN_SECRET\""
  [ "$status" -eq 0 ]
  [ "$output" = "existingsecret123" ]

  run grep "openssl" "$STUB_LOG"
  [ "$status" -ne 0 ]
}

@test "generate_presign_secret: falls through to openssl when existing line has empty value" {
  mkdir -p "$FLOCI_ENV_DIR"
  printf 'FLOCI_AUTH_PRESIGN_SECRET=\n' >"$FLOCI_ENV_FILE"

  local fixed_secret
  fixed_secret="$(printf 'cd%.0s' $(seq 1 32))" # 64 hex chars ("cd" x 32)

  run _run_fn \
    "export STUB_OUT_OPENSSL='${fixed_secret}'" \
    "generate_presign_secret; printf '%s' \"\$PRESIGN_SECRET\""
  [ "$status" -eq 0 ]
  [ "$output" = "$fixed_secret" ]

  run grep "openssl" "$STUB_LOG"
  [ "$status" -eq 0 ]
}

# ===========================================================================
# write_env_file
# ===========================================================================

@test "write_env_file: emits the configurable host persistence path" {
  run _run_fn \
    "export FLOCI_HOST_PERSISTENT_PATH=/tmp/custom-data; export STUB_OUT_OPENSSL='deadbeefcafe'" \
    "generate_presign_secret; write_env_file"
  [ "$status" -eq 0 ]
  grep -q '^FLOCI_STORAGE_HOST_PERSISTENT_PATH=/tmp/custom-data$' "$FLOCI_ENV_FILE"
}

@test "persistence path: no override uses FLOCI_HOME/floci-data everywhere" {
  local default_path="${FLOCI_HOME}/floci-data"

  run _run_fn \
    "unset FLOCI_HOST_PERSISTENT_PATH FLOCI_DATA_DIR; export STUB_OUT_OPENSSL='deadbeefcafe'" \
    "generate_presign_secret; create_data_directory; write_env_file; printf '%s' \"\$FLOCI_DATA_DIR\""
  [ "$status" -eq 0 ]
  [ -d "$default_path" ]
  [ "$output" = "$default_path" ]
  grep -qF "FLOCI_STORAGE_HOST_PERSISTENT_PATH=${default_path}" "$FLOCI_ENV_FILE"
}

@test "create_data_directory: FLOCI_DATA_DIR remains a fallback alias" {
  local alternate_path=/tmp/alt-data
  rm -rf "$alternate_path"

  run _run_fn "unset FLOCI_HOST_PERSISTENT_PATH; export FLOCI_DATA_DIR='${alternate_path}'" "create_data_directory"
  [ "$status" -eq 0 ]
  [ -d "$alternate_path" ]
  [ "$(_stat_mode "$alternate_path")" = "700" ]
  rm -rf "$alternate_path"
}

@test "persistence path: relative host path is rejected" {
  run _run_fn "export FLOCI_HOST_PERSISTENT_PATH=relative/path" "true"
  [ "$status" -eq 1 ]
  [[ "$output" == *"must be absolute"* ]]
}

@test "write_env_file: renders all §12 keys with correct values" {
  run _run_fn \
    "export STUB_OUT_OPENSSL='deadbeefcafe'" \
    "generate_presign_secret; write_env_file"
  [ "$status" -eq 0 ]

  grep -q '^FLOCI_HOSTNAME=tianlu-floci$' "$FLOCI_ENV_FILE"
  grep -q '^FLOCI_BASE_URL=https://tianlu-floci:4566$' "$FLOCI_ENV_FILE"
  grep -q '^FLOCI_DEFAULT_REGION=eu-west-1$' "$FLOCI_ENV_FILE"
  grep -q '^FLOCI_DEFAULT_ACCOUNT_ID=000000000000$' "$FLOCI_ENV_FILE"
  grep -q '^FLOCI_STORAGE_MODE=persistent$' "$FLOCI_ENV_FILE"
  grep -q '^FLOCI_STORAGE_PERSISTENT_PATH=/app/data$' "$FLOCI_ENV_FILE"
  grep -q "^FLOCI_STORAGE_HOST_PERSISTENT_PATH=${FLOCI_DATA_DIR}$" "$FLOCI_ENV_FILE"
  grep -q '^FLOCI_TLS_ENABLED=true$' "$FLOCI_ENV_FILE"
  grep -q '^FLOCI_TLS_SELF_SIGNED=true$' "$FLOCI_ENV_FILE"
  grep -q '^FLOCI_SERVICES_DOCKER_NETWORK=floci-net$' "$FLOCI_ENV_FILE"
  grep -q '^FLOCI_SERVICES_LAMBDA_DOCKER_NETWORK=floci-net$' "$FLOCI_ENV_FILE"
  grep -q '^FLOCI_SERVICES_LAMBDA_DOCKER_HOST_OVERRIDE=tianlu-floci$' "$FLOCI_ENV_FILE"
  grep -q '^FLOCI_AUTH_PRESIGN_SECRET=deadbeefcafe$' "$FLOCI_ENV_FILE"
  grep -q '^FLOCI_DOCKER_LOG_MAX_SIZE=10m$' "$FLOCI_ENV_FILE"
  grep -q '^FLOCI_DOCKER_LOG_MAX_FILE=3$' "$FLOCI_ENV_FILE"
}

@test "write_env_file: FLOCI_BASE_URL uses http when FLOCI_TLS_ENABLED=false" {
  run _run_fn \
    "export STUB_OUT_OPENSSL='deadbeefcafe'; export FLOCI_TLS_ENABLED=false" \
    "generate_presign_secret; write_env_file"
  [ "$status" -eq 0 ]
  grep -q '^FLOCI_BASE_URL=http://tianlu-floci:4566$' "$FLOCI_ENV_FILE"
  ! grep -q '^FLOCI_BASE_URL=https://' "$FLOCI_ENV_FILE"
}

@test "write_env_file: explicit FLOCI_BASE_URL override wins over TLS-derived default" {
  run _run_fn \
    "export STUB_OUT_OPENSSL='deadbeefcafe'; export FLOCI_TLS_ENABLED=false; export FLOCI_BASE_URL=https://custom.example:8443" \
    "generate_presign_secret; write_env_file"
  [ "$status" -eq 0 ]
  grep -q '^FLOCI_BASE_URL=https://custom.example:8443$' "$FLOCI_ENV_FILE"
}

@test "write_env_file: FLOCI_DOCKER_DOCKER_HOST is absent" {
  run _run_fn \
    "export STUB_OUT_OPENSSL='deadbeefcafe'" \
    "generate_presign_secret; write_env_file"
  [ "$status" -eq 0 ]
  run grep -q "FLOCI_DOCKER_DOCKER_HOST" "$FLOCI_ENV_FILE"
  [ "$status" -ne 0 ]
}

@test "write_env_file: file mode is 0600" {
  run _run_fn \
    "export STUB_OUT_OPENSSL='deadbeefcafe'" \
    "generate_presign_secret; write_env_file"
  [ "$status" -eq 0 ]
  [ "$(_stat_mode "$FLOCI_ENV_FILE")" = "600" ]
}

@test "write_env_file: secret preserved across a re-run" {
  run _run_fn \
    "export STUB_OUT_OPENSSL='firstsecretvalue'" \
    "generate_presign_secret; write_env_file"
  [ "$status" -eq 0 ]
  grep -q '^FLOCI_AUTH_PRESIGN_SECRET=firstsecretvalue$' "$FLOCI_ENV_FILE"

  # Second run: openssl would emit a different value, but must not be used.
  run _run_fn \
    "export STUB_OUT_OPENSSL='secondsecretvalue'" \
    "generate_presign_secret; write_env_file"
  [ "$status" -eq 0 ]
  grep -q '^FLOCI_AUTH_PRESIGN_SECRET=firstsecretvalue$' "$FLOCI_ENV_FILE"
  run grep -q '^FLOCI_AUTH_PRESIGN_SECRET=secondsecretvalue$' "$FLOCI_ENV_FILE"
  [ "$status" -ne 0 ]
}

@test "write_env_file: second run creates a .bak backup" {
  run _run_fn \
    "export STUB_OUT_OPENSSL='deadbeefcafe'" \
    "generate_presign_secret; write_env_file"
  [ "$status" -eq 0 ]
  [ ! -f "${FLOCI_ENV_FILE}.bak" ]

  run _run_fn \
    "export STUB_OUT_OPENSSL='deadbeefcafe'" \
    "generate_presign_secret; write_env_file"
  [ "$status" -eq 0 ]
  [ -f "${FLOCI_ENV_FILE}.bak" ]
}
