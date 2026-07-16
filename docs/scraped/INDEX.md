# Floci Documentation Index for AI Agents

> This index is a machine-readable map of the scraped Floci documentation.
> Each entry lists the page title, file path, a concise description, and
> keyword tags that an agent can use to locate the right reference quickly.

---

## Pages

### 1. Environment Variables Reference
- **File**: `docs/scraped/environment-variables.md`
- **URL**: https://floci.io/floci/configuration/environment-variables/
- **Description**: Complete reference for every `FLOCI_*` environment variable used to configure Floci at runtime. Covers global settings, authentication, CORS, TLS, storage, Docker daemon, DNS, initialization hooks, and per-service enable/behaviour flags for all emulated AWS services (SSM, SQS, SNS, S3, DynamoDB, Lambda, API Gateway, IAM, KMS, Kinesis, Firehose, EventBridge, Scheduler, CloudWatch Logs/Metrics, Secrets Manager, Cognito, Step Functions, CloudFormation, ACM, SES, Pipes, ElastiCache, RDS, OpenSearch, MSK, ECR, EKS, ECS, EC2, Athena, Glue, AppSync, Bedrock, Textract, Transfer, Route53, ELBv2, AutoScaling, CodeBuild, CodeDeploy, Backup, AppConfig).
- **Keywords**: environment variables, FLOCI_*, configuration, global, authentication, FLOCI_AUTH_VALIDATE_SIGNATURES, FLOCI_AUTH_PRESIGN_SECRET, CORS, FLOCI_SECURITY_EXTRA_CORS_ALLOWED_ORIGINS, TLS, FLOCI_TLS_ENABLED, FLOCI_TLS_CERT_PATH, FLOCI_TLS_KEY_PATH, FLOCI_TLS_SELF_SIGNED, storage, FLOCI_STORAGE_MODE, FLOCI_STORAGE_PERSISTENT_PATH, FLOCI_STORAGE_HOST_PERSISTENT_PATH, FLOCI_STORAGE_PRUNE_VOLUMES_ON_DELETE, FLOCI_STORAGE_WAL_COMPACTION_INTERVAL_MS, per-service storage override, docker daemon, FLOCI_DOCKER_DOCKER_HOST, FLOCI_DOCKER_DOCKER_CONFIG_PATH, FLOCI_DOCKER_IMAGE_REGISTRY_BASE, FLOCI_DOCKER_LOG_MAX_SIZE, FLOCI_DOCKER_LOG_MAX_FILE, FLOCI_DOCKER_RESOURCE_NAMESPACE, registry credentials, DNS, FLOCI_DNS_EXTRA_SUFFIXES, init hooks, FLOCI_INIT_HOOKS_SHELL_EXECUTABLE, FLOCI_INIT_HOOKS_TIMEOUT_SECONDS, FLOCI_INIT_HOOKS_SHUTDOWN_GRACE_PERIOD_SECONDS, services shared, FLOCI_SERVICES_DOCKER_NETWORK, SSM, SQS, SNS, S3, DynamoDB, Lambda, FLOCI_SERVICES_LAMBDA_DOCKER_HOST_OVERRIDE, FLOCI_SERVICES_LAMBDA_EPHEMERAL, FLOCI_SERVICES_LAMBDA_HOT_RELOAD_ENABLED, API Gateway, IAM, FLOCI_SERVICES_IAM_SEED_DEPLOYER_PRINCIPAL, KMS, Kinesis, Firehose, EventBridge, Scheduler, CloudWatch Logs, CloudWatch Metrics, Secrets Manager, Cognito, Step Functions, CloudFormation, ACM, SES, Pipes, ElastiCache, RDS, OpenSearch, MSK, ECR, EKS, ECS, EC2, Athena, Glue, AppSync, Bedrock, Textract, Transfer, Route53, ELBv2, AutoScaling, CodeBuild, CodeDeploy, Backup, AppConfig

### 2. Docker Images
- **File**: `docs/scraped/docker-images.md`
- **URL**: https://floci.io/floci/configuration/docker-images/
- **Description**: Explains the Floci image taxonomy on Docker Hub (`floci/floci`). Two independent axes — variant (Standard vs Compat) and channel (Release vs Nightly). Documents the full tag matrix (`latest`, `latest-compat`, `x.y.z`, `x.y.z-compat`, `nightly`, `nightly-compat`, dated nightlies), multi-arch support (amd64/arm64), the contents of the compat image (Python 3 + AWS CLI + boto3), and pre-set AWS environment variables inside the images.
- **Keywords**: docker images, floci/floci, Docker Hub, variant, standard, compat, compat image, channel, release, nightly, tag matrix, pinned version, latest, latest-compat, x.y.z, x.y.z-compat, nightly-compat, multi-arch, amd64, arm64, Python 3, AWS CLI, boto3, AWS_DEFAULT_REGION, AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_ENDPOINT_URL, AWS_CONFIG_FILE, local development, Dockerfile.native

### 3. Docker Compose
- **File**: `docs/scraped/docker-compose.md`
- **URL**: https://floci.io/floci/configuration/docker-compose/
- **Description**: How to run Floci with Docker / Docker Compose. Covers quick start (`docker run`), minimal stateless compose, persistence with volumes, ElastiCache and RDS with Docker socket access, multi-container networking (`FLOCI_HOSTNAME`), initialization hooks mounting, CI pipeline example, and a table of common environment variables. Explains that all configuration is via environment variables — no config files needed.
- **Keywords**: docker, docker run, docker compose, quick start, stateless, persistence, volumes, floci-data, ElastiCache, RDS, docker.sock, multi-container networking, FLOCI_HOSTNAME, AWS_ENDPOINT_URL, depends_on, CI pipeline, GitHub Actions, GitLab CI, services, init hooks, boot.d, start.d, ready.d, stop.d, latest-compat, common environment variables, FLOCI_STORAGE_MODE, FLOCI_STORAGE_PERSISTENT_PATH, FLOCI_SERVICES_DOCKER_NETWORK, FLOCI_SERVICES_LAMBDA_EPHEMERAL

### 4. Ports Reference
- **File**: `docs/scraped/ports.md`
- **URL**: https://floci.io/floci/configuration/ports/
- **Description**: Complete port reference for Floci. Lists every port/range, protocol, purpose, and whether a docker-compose `ports:` mapping is required. Explains the two exposure patterns: proxy-in-Floci (ElastiCache 6379-6399, RDS 7001-7099) vs direct container binding (ECR 5100-5199, EKS 6500-6599, OpenSearch 9400-9499). Port 4566 is the main AWS API. Lambda Runtime API 9200-9299 is internal only. Warns not to expose ECR ports on the floci service.
- **Keywords**: ports, 4566, 5100-5199, ECR registry, 6379-6399, ElastiCache, Redis, 6500-6599, EKS, k3s, API server, 7001-7099, RDS, 9200-9299, Lambda Runtime API, 9400-9499, OpenSearch, proxy-in-floci, direct container binding, docker-compose mapping, FLOCI_SERVICES_ELASTICACHE_PROXY_BASE_PORT, FLOCI_SERVICES_RDS_PROXY_BASE_PORT, FLOCI_SERVICES_EKS_API_SERVER_BASE_PORT, FLOCI_SERVICES_OPENSEARCH_PROXY_BASE_PORT, FLOCI_SERVICES_LAMBDA_RUNTIME_API_BASE_PORT

### 5. Multi-Account Isolation
- **File**: `docs/scraped/multi-account.md`
- **URL**: https://floci.io/floci/configuration/multi-account/
- **Description**: Documents Floci's per-account resource isolation. A 12-digit numeric Access Key ID becomes the account ID; non-12-digit keys fall back to `FLOCI_DEFAULT_ACCOUNT_ID`. Covers STS AssumeRole temporary credential routing, default single-account behavior, enabling multi-account with CLI/SDK examples (Java, Python), ARN account ID embedding, isolation scope across all services, signature validation toggle, and persistence namespacing. Compatible with LocalStack's multi-account convention.
- **Keywords**: multi-account, account isolation, Access Key ID, AKID, 12-digit, FLOCI_DEFAULT_ACCOUNT_ID, SigV4, Authorization header, AssumeRole, AssumeRoleWithWebIdentity, AssumeRoleWithSAML, GetFederationToken, GetSessionToken, ASIA, temporary credentials, STS, ARN, namespace, LocalStack compatibility, FLOCI_AUTH_VALIDATE_SIGNATURES, FLOCI_AUTH_PRESIGN_SECRET, persistence, storage keys, CLI profiles, boto3, Java SDK, Python SDK

### 6. Storage Modes
- **File**: `docs/scraped/storage.md`
- **URL**: https://floci.io/floci/configuration/storage/
- **Description**: Details the four storage backends: `memory`, `persistent`, `hybrid`, and `wal`. Explains durability, write performance, and use cases for each. Covers global config, per-service overrides (SSM, SQS, S3, DynamoDB, SNS, Lambda, CloudWatch Logs/Metrics, Secrets Manager, ACM, AppSync, OpenSearch, RDS), recommended profiles (fast CI, local dev, durable, mixed), and container storage for RDS/OpenSearch/MSK/ECR using named Docker volumes with `floci=true` labels. Includes host-path bind mount advanced mode.
- **Keywords**: storage, storage modes, memory, persistent, hybrid, wal, write-ahead log, compaction, FLOCI_STORAGE_MODE, FLOCI_STORAGE_PERSISTENT_PATH, FLOCI_STORAGE_WAL_COMPACTION_INTERVAL_MS, per-service override, FLOCI_STORAGE_SERVICES_*_MODE, FLOCI_STORAGE_SERVICES_*_FLUSH_INTERVAL_MS, flush interval, recommended profiles, fast CI, local development, durable, mixed, container storage, named volumes, floci=true label, volume lifecycle, FLOCI_STORAGE_PRUNE_VOLUMES_ON_DELETE, FLOCI_STORAGE_HOST_PERSISTENT_PATH, bind mount, RDS, OpenSearch, MSK, ECR

### 7. TLS / HTTPS
- **File**: `docs/scraped/tls.md`
- **URL**: https://floci.io/floci/configuration/tls/
- **Description**: How to enable TLS/HTTPS on Floci. Both HTTP and HTTPS served simultaneously. Covers self-signed certificate auto-generation (persisted, with SANs for localhost and custom hostnames from `FLOCI_HOSTNAME`/`FLOCI_BASE_URL`), user-provided certificates via `FLOCI_TLS_CERT_PATH`/`FLOCI_TLS_KEY_PATH`, WebSocket wss:// support, SDK configuration examples (JavaScript v3, Java v2, Python boto3) for disabling verification, and troubleshooting guide.
- **Keywords**: TLS, HTTPS, SSL, FLOCI_TLS_ENABLED, FLOCI_TLS_CERT_PATH, FLOCI_TLS_KEY_PATH, FLOCI_TLS_SELF_SIGNED, self-signed certificate, PEM, certificate, private key, SAN, Subject Alternative Names, localhost, FLOCI_HOSTNAME, FLOCI_BASE_URL, mkcert, corporate CA, Let's Encrypt, WebSocket, wss://, Vert.x, SDK configuration, JavaScript v3, NodeHttpHandler, rejectUnauthorized, NODE_TLS_REJECT_UNAUTHORIZED, Java v2, ApacheHttpClient, TrustManager, X509TrustManager, Python boto3, verify=False, troubleshooting, DEPTH_ZERO_SELF_SIGNED_CERT, PKIX, keytool

### 8. Initialization Hooks
- **File**: `docs/scraped/initialization-hooks.md`
- **URL**: https://floci.io/floci/configuration/initialization-hooks/
- **Description**: Floci init hook scripts that run at defined lifecycle phases: boot (before storage), start (HTTP ready), ready (after start hooks), stop (during shutdown). Documents hook directories (Floci-native and LocalStack-compat paths), script types (.sh, .py), lexicographical execution order, fail-fast behavior, timeouts. Covers the compat image with pre-configured AWS CLI/boto3, mounting hook directories in compose, migration from LocalStack, and examples for seeding resources and cleanup.
- **Keywords**: initialization hooks, init hooks, lifecycle, boot, start, ready, stop, boot.d, start.d, ready.d, stop.d, shutdown.d, /etc/floci/init/, /etc/localstack/init/, LocalStack compatibility, script types, .sh, .py, shell executable, python3, lexicographical order, fail-fast, timeout, FLOCI_INIT_HOOKS_SHELL_EXECUTABLE, FLOCI_INIT_HOOKS_TIMEOUT_SECONDS, FLOCI_INIT_HOOKS_SHUTDOWN_GRACE_PERIOD_SECONDS, compat image, AWS CLI, boto3, AWS_ENDPOINT_URL, seeding resources, cleanup, mounting volumes, docker-compose, /_floci/init, /_localstack/init

### 9. Docker Configuration (incl. Podman Rootless)
- **File**: `docs/scraped/docker-configuration.md`
- **URL**: https://floci.io/floci/configuration/docker/
- **Description**: Docker daemon configuration for Floci — socket path, private registry authentication (Docker config mount vs explicit per-registry credentials), container log rotation, and shared Docker network for spawned containers. **Critically includes the "Running on Podman (rootless)" section** with the exact known-working configuration: `podman network create floci-net`, socket mount with `:z` SELinux relabel, `FLOCI_SERVICES_LAMBDA_DOCKER_NETWORK`, `FLOCI_HOSTNAME`, and `FLOCI_SERVICES_LAMBDA_DOCKER_HOST_OVERRIDE` for when Runtime API auto-detection fails.
- **Keywords**: docker configuration, docker daemon, socket, FLOCI_DOCKER_DOCKER_HOST, private registry, credentials, FLOCI_DOCKER_DOCKER_CONFIG_PATH, FLOCI_DOCKER_REGISTRY_CREDENTIALS, log rotation, FLOCI_DOCKER_LOG_MAX_SIZE, FLOCI_DOCKER_LOG_MAX_FILE, docker network, FLOCI_SERVICES_DOCKER_NETWORK, Podman, rootless Podman, floci-net, podman.sock, :z, SELinux, FLOCI_SERVICES_LAMBDA_DOCKER_NETWORK, FLOCI_SERVICES_LAMBDA_DOCKER_HOST_OVERRIDE, ECONNREFUSED, Runtime API, broken pipe

---

## Quick Keyword Lookup

| Topic | Page(s) |
|---|---|
| All `FLOCI_*` env vars | environment-variables |
| Image tags, variants, compat | docker-images |
| docker-compose.yml examples | docker-compose |
| Which ports to expose | ports |
| 12-digit account ID, multi-account | multi-account |
| memory / persistent / hybrid / wal | storage |
| TLS, HTTPS, certificates | tls |
| Init scripts, boot/start/ready/stop | initialization-hooks |
| `FLOCI_HOSTNAME` | environment-variables, docker-compose, tls |
| `FLOCI_STORAGE_MODE` | environment-variables, storage, docker-compose |
| `FLOCI_SERVICES_DOCKER_NETWORK` | environment-variables, docker-compose |
| `FLOCI_SERVICES_LAMBDA_DOCKER_HOST_OVERRIDE` (rootless Podman) | environment-variables |
| `FLOCI_TLS_ENABLED` | environment-variables, tls |
| Docker socket access | docker-compose, ports |
| ECR port warning (5100-5199) | ports, docker-compose |
| Named volume labels (`floci=true`) | storage |
| AssumeRole / STS temp credentials | multi-account |
| Hook script extensions (.sh, .py) | initialization-hooks |
| **Podman rootless setup (known-working)** | docker-configuration |
| Socket mount `:z` for SELinux | docker-configuration |
| `FLOCI_SERVICES_LAMBDA_DOCKER_HOST_OVERRIDE` | docker-configuration, environment-variables |
| Private registry auth | docker-configuration |
| Container log rotation | docker-configuration |