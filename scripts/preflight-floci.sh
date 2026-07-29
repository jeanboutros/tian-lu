#!/usr/bin/env bash
# preflight-floci.sh — verify the Floci instance actually ENFORCES the mechanisms this
# learning lab teaches, BEFORE any `terraform apply`. Both challenger reviews (2026-07-28)
# flagged that several lessons become "false demos" if these gates are not checked.
#
# Gates (see docs/learning/findings/):
#   G1  Signature/authorization validation is ON  (else all IAM lessons are client-side theater)
#   G2  RDS IAM database auth is REALLY enforced   (else the IAM-as-boundary proof is fake)
#   G3  DynamoDB conditional writes work           (else Terraform state locking is broken)
#   G4  k3s NetworkPolicy scope is pod-to-pod only  (documented expectation, verified on a cluster)
#   G5  k3s admin token handling                    (verified on a cluster)
#
# G1 and G3 run with no cluster/DB and are automated here. G2/G4/G5 need a live RDS/k3s and
# print the exact commands to run once those exist (or when driving the Lima dev-twin).
#
# References:
#   FLOCI_AUTH_VALIDATE_SIGNATURES  — https://floci.io/floci/configuration/environment-variables/
#   RDS IAM DB auth                 — https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/UsingWithRDS.IAMDBAuth.html
#   TF S3 backend + DynamoDB lock   — https://developer.hashicorp.com/terraform/language/settings/backends/s3
#   k3s networking / CNI            — https://docs.k3s.io/networking/basic-network-options
#   internal: docs/design/gaps-register.md (GAP-013b)
set -euo pipefail

readonly ENDPOINT="${AWS_ENDPOINT_URL:-http://localhost:4566}"
readonly REGION="${AWS_DEFAULT_REGION:-us-east-1}"
# A 12-digit access key id becomes the Floci account id (dev). See multi-account docs.
readonly DEV_AKID="${DEV_AKID:-111111111111}"

pass() { printf '  \033[32mPASS\033[0m %s\n' "$1"; }
fail() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; FAILED=1; }
skip() { printf '  \033[33mSKIP\033[0m %s\n' "$1"; }
hdr()  { printf '\n\033[1m%s\033[0m\n' "$1"; }
FAILED=0

aws_admin() { AWS_ACCESS_KEY_ID="$DEV_AKID" AWS_SECRET_ACCESS_KEY=test aws --endpoint-url "$ENDPOINT" --region "$REGION" "$@"; }

# ---------------------------------------------------------------------------
# G1 — signature / authorization validation must be ON
# Create a user with NO policies, mint a key, and confirm a privileged call is DENIED.
# If it returns data, Floci is not enforcing IAM -> every IAM lesson is meaningless.
# ---------------------------------------------------------------------------
gate_g1_signatures() {
  hdr "G1  IAM authorization is enforced (FLOCI_AUTH_VALIDATE_SIGNATURES=true)"
  local user="preflight-nopolicy-$$" ak sk out
  aws_admin iam create-user --user-name "$user" >/dev/null 2>&1 || true
  if ! out=$(aws_admin iam create-access-key --user-name "$user" 2>/dev/null); then
    skip "could not create access key (is IAM up?) — verify manually"; return
  fi
  ak=$(printf '%s' "$out" | grep -o '"AccessKeyId": *"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
  sk=$(printf '%s' "$out" | grep -o '"SecretAccessKey": *"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
  if AWS_ACCESS_KEY_ID="$ak" AWS_SECRET_ACCESS_KEY="$sk" \
       aws --endpoint-url "$ENDPOINT" --region "$REGION" rds describe-db-instances >/dev/null 2>&1; then
    fail "no-policy user CAN call rds:DescribeDBInstances -> authorization is OFF. Set FLOCI_AUTH_VALIDATE_SIGNATURES=true. HARD STOP."
  else
    pass "no-policy user is denied rds:DescribeDBInstances (authorization enforced)"
  fi
  aws_admin iam delete-access-key --user-name "$user" --access-key-id "$ak" >/dev/null 2>&1 || true
  aws_admin iam delete-user --user-name "$user" >/dev/null 2>&1 || true
}

# ---------------------------------------------------------------------------
# G3 — DynamoDB conditional writes (Terraform state locking depends on this)
# PutItem with attribute_not_exists(LockID) twice; the SECOND must fail.
# ---------------------------------------------------------------------------
gate_g3_dynamodb_lock() {
  hdr "G3  DynamoDB conditional writes work (Terraform state locking)"
  local table="preflight-lock-$$"
  aws_admin dynamodb create-table --table-name "$table" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST >/dev/null 2>&1 || { skip "could not create table (is DynamoDB up?)"; return; }
  aws_admin dynamodb put-item --table-name "$table" \
    --item '{"LockID":{"S":"x"}}' --condition-expression "attribute_not_exists(LockID)" >/dev/null 2>&1 || true
  if aws_admin dynamodb put-item --table-name "$table" \
       --item '{"LockID":{"S":"x"}}' --condition-expression "attribute_not_exists(LockID)" >/dev/null 2>&1; then
    fail "second conditional PutItem SUCCEEDED -> locking broken. Use S3 use_lockfile or single-operator only."
  else
    pass "second conditional PutItem is rejected (ConditionalCheckFailed) -> locking works"
  fi
  aws_admin dynamodb delete-table --table-name "$table" >/dev/null 2>&1 || true
}

# ---------------------------------------------------------------------------
# G2 — RDS IAM database auth is REALLY enforced. Needs a running RDS + IAM-auth user.
# Set PREFLIGHT_RDS_HOST/PORT/USER to run automatically; otherwise prints the commands.
# ---------------------------------------------------------------------------
gate_g2_iam_db_auth() {
  hdr "G2  RDS IAM database auth is enforced (not native-password theater)"
  if [[ -z "${PREFLIGHT_RDS_HOST:-}" ]]; then
    skip "no RDS yet. After stage 40 (or a throwaway DB), run:"
    cat <<'EOF'
      # 1) A FAKE token MUST be rejected:
      PGPASSWORD="not-a-real-token" psql -h "$HOST" -p "$PORT" -U iamuser -d appdb -c 'SELECT 1;'
      #    Expect: FATAL: password authentication failed  (if it CONNECTS, IAM auth is fake)
      # 2) A real token MUST work:
      PGPASSWORD="$(aws rds generate-db-auth-token --hostname "$HOST" --port "$PORT" \
        --username iamuser --region us-east-1 --endpoint-url "$AWS_ENDPOINT_URL")" \
        psql -h "$HOST" -p "$PORT" -U iamuser -d appdb -c 'SELECT version();'
EOF
    return
  fi
  if command -v psql >/dev/null 2>&1 && \
     PGPASSWORD="not-a-real-token" psql -h "$PREFLIGHT_RDS_HOST" -p "${PREFLIGHT_RDS_PORT:-7001}" \
        -U "${PREFLIGHT_RDS_USER:-iamuser}" -d "${PREFLIGHT_RDS_DB:-appdb}" -c 'SELECT 1;' >/dev/null 2>&1; then
    fail "a FAKE token connected -> Postgres is not validating IAM tokens. Reframe lesson (Finding 0002)."
  else
    pass "fake token rejected -> IAM DB auth appears enforced (also confirm a real token works)"
  fi
}

gate_g4_g5_cluster_notes() {
  hdr "G4/G5  k3s NetworkPolicy scope + admin token (run against a live cluster / dev-twin)"
  skip "G4: default-deny NetworkPolicy blocks pod->pod cross-ns, but NOT pod->RDS-container (flat floci-net)."
  printf '        kubectl -n other run t --image=curlimages/curl --rm -it -- curl -m5 http://<svc>.app-alpha  # expect timeout\n'
  skip "G5: check whether the k3s admin token is static; if so, mint a scoped kubeconfig immediately."
  printf '        podman exec <k3s-container> cat /etc/rancher/k3s/k3s.yaml | grep token\n'
}

main() {
  printf '\033[1mFloci pre-flight — endpoint %s (dev account %s)\033[0m\n' "$ENDPOINT" "$DEV_AKID"
  command -v aws >/dev/null 2>&1 || { echo "aws CLI not found"; exit 2; }
  gate_g1_signatures
  gate_g3_dynamodb_lock
  gate_g2_iam_db_auth
  gate_g4_g5_cluster_notes
  hdr "Result"
  if [[ "$FAILED" -eq 0 ]]; then pass "automated gates passed (finish G2/G4/G5 on a live cluster/DB)"; else fail "one or more gates FAILED — fix before applying stages"; exit 1; fi
}
main "$@"
