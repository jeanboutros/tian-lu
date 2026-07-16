# Environment Variables Reference

Floci is configured exclusively through environment variables. Every option below maps directly to a `FLOCI_*` variable — no YAML file is needed when running the published Docker image.

## Global

| Variable | Default | Description |
|---|---|---|
| `FLOCI_BASE_URL` | `http://localhost:4566` | Base URL embedded in response fields (SQS `QueueUrl`, pre-signed URLs, etc.) |
| `FLOCI_HOSTNAME` | *(none)* | Overrides only the hostname part of `FLOCI_BASE_URL`. Set to the Compose service name (e.g. `floci`) so other containers can reach Floci by DNS |
| `FLOCI_DEFAULT_REGION` | `us-east-1` | AWS region used in ARNs and API responses |
| `FLOCI_DEFAULT_ACCOUNT_ID` | `000000000000` | Fallback account ID used in ARNs when the request's access key is not exactly 12 digits. When the access key IS 12 digits, it is used directly as the account ID — see Multi-Account Isolation |
| `FLOCI_DEFAULT_AVAILABILITY_ZONE` | `us-east-1a` | Availability zone reported in EC2 and other responses |
| `FLOCI_MAX_REQUEST_SIZE` | `512` | Maximum HTTP request body size in megabytes |
| `FLOCI_ECR_BASE_URI` | `public.ecr.aws` | Base URI for public ECR image references |

## Authentication

| Variable | Default | Description |
|---|---|---|
| `FLOCI_AUTH_VALIDATE_SIGNATURES` | `false` | When `true`, verifies AWS Signature V4 on every request. Leave `false` for local development |
| `FLOCI_AUTH_PRESIGN_SECRET` | `local-emulator-secret` | Secret used to sign and verify pre-signed URLs |

## Browser CORS

| Variable | Default | Description |
|---|---|---|
| `FLOCI_SECURITY_EXTRA_CORS_ALLOWED_ORIGINS` | *(none)* | Comma-separated browser origins allowed to call Floci directly. Alias: `EXTRA_CORS_ALLOWED_ORIGINS` |
| `FLOCI_SECURITY_EXTRA_CORS_ALLOWED_HEADERS` | *(none)* | Additional header names to include in `Access-Control-Allow-Headers`. Alias: `EXTRA_CORS_ALLOWED_HEADERS` |
| `FLOCI_SECURITY_EXTRA_CORS_EXPOSE_HEADERS` | *(none)* | Additional header names to include in `Access-Control-Expose-Headers`. Alias: `EXTRA_CORS_EXPOSE_HEADERS` |
| `FLOCI_SECURITY_DISABLE_CORS_HEADERS` | `false` | Disable Floci's global CORS response headers. Alias: `DISABLE_CORS_HEADERS` |
| `FLOCI_SECURITY_CORS_ALLOW_PRIVATE_NETWORK` | `false` | Answer Private Network Access preflights with `Access-Control-Allow-Private-Network: true` |

## TLS / HTTPS

| Variable | Default | Description |
|---|---|---|
| `FLOCI_TLS_ENABLED` | `false` | Enable TLS/HTTPS on all endpoints (HTTP remains available simultaneously) |
| `FLOCI_TLS_CERT_PATH` | *(none)* | Path to a PEM certificate file. When set, disables auto-generation |
| `FLOCI_TLS_KEY_PATH` | *(none)* | Path to a PEM private key file. Required when `FLOCI_TLS_CERT_PATH` is set |
| `FLOCI_TLS_SELF_SIGNED` | `true` | Auto-generate and persist a self-signed certificate when no cert/key paths are provided |

## Wire Protocols

| Variable | Default | Description |
|---|---|---|
| `FLOCI_PROTOCOLS_STRICT_CLAIMING` | `false` | Reject RPC-signaled requests that no supported wire protocol claims |

## Storage

| Variable | Default | Description |
|---|---|---|
| `FLOCI_STORAGE_MODE` | `memory` | Global storage backend: `memory`, `persistent`, `hybrid`, or `wal` |
| `FLOCI_STORAGE_PERSISTENT_PATH` | `./data` | Container-side directory for persistent and hybrid storage |
| `FLOCI_STORAGE_HOST_PERSISTENT_PATH` | `./data` | Host-side path for Docker volume bind-mounts (RDS, OpenSearch, MSK, ECR data). When unset, Floci uses named Docker volumes |
| `FLOCI_STORAGE_PRUNE_VOLUMES_ON_DELETE` | `false` | Remove named Docker volumes immediately when the resource is deleted |
| `FLOCI_STORAGE_WAL_COMPACTION_INTERVAL_MS` | `30000` | How often (ms) the WAL compaction runs. Only applies when `FLOCI_STORAGE_MODE=wal` |

### Per-service storage overrides

Each service can override the global storage mode and flush interval. Replace `<SERVICE>` with the uppercase service name:

```
FLOCI_STORAGE_SERVICES_<SERVICE>_MODE=hybrid
FLOCI_STORAGE_SERVICES_<SERVICE>_FLUSH_INTERVAL_MS=5000
```

Available service names: `SSM`, `SQS`, `S3`, `DYNAMODB`, `SNS`, `LAMBDA`, `CLOUDWATCHLOGS`, `CLOUDWATCHMETRICS`, `SECRETSMANAGER`, `ACM`, `OPENSEARCH`, `RDS`, `ELASTICACHE`, `APPCONFIG`, `APPCONFIGDATA`, `BACKUP`.

## Docker Daemon

| Variable | Default | Description |
|---|---|---|
| `FLOCI_DOCKER_DOCKER_HOST` | `unix:///var/run/docker.sock` | Docker daemon socket path or TCP address |
| `FLOCI_DOCKER_DOCKER_CONFIG_PATH` | *(none)* | Path to a directory containing Docker's `config.json` for registry auth |
| `FLOCI_DOCKER_IMAGE_REGISTRY_BASE` | *(none)* | Optional registry/repository base for every Docker image Floci launches |
| `FLOCI_DOCKER_LOG_MAX_SIZE` | `10m` | Log rotation max size for spawned containers |
| `FLOCI_DOCKER_LOG_MAX_FILE` | `3` | Number of rotated log files to keep for spawned containers |
| `FLOCI_DOCKER_RESOURCE_NAMESPACE` | *(none)* | Optional namespace prefix for managed child Docker container and volume names |

### Registry credentials

Provide credentials for private registries. Use incrementing indexes (`0`, `1`, `2`, …):

| Variable | Description |
|---|---|
| `FLOCI_DOCKER_REGISTRY_CREDENTIALS_0__SERVER` | Registry hostname (e.g. `ghcr.io`) |
| `FLOCI_DOCKER_REGISTRY_CREDENTIALS_0__USERNAME` | Registry username |
| `FLOCI_DOCKER_REGISTRY_CREDENTIALS_0__PASSWORD` | Registry password or token |

## DNS

Floci's embedded DNS server always resolves the following wildcard suffixes to Floci's container IP — no configuration required:
- `localhost.floci.io` and `*.localhost.floci.io`
- `localhost.localstack.cloud` and `*.localhost.localstack.cloud`

| Variable | Default | Description |
|---|---|---|
| `FLOCI_DNS_EXTRA_SUFFIXES` | *(none)* | Comma-separated list of additional hostname suffixes to resolve to Floci's container IP |

## Initialization Hooks

| Variable | Default | Description |
|---|---|---|
| `FLOCI_INIT_HOOKS_SHELL_EXECUTABLE` | `/bin/sh` | Shell used to execute hook scripts |
| `FLOCI_INIT_HOOKS_TIMEOUT_SECONDS` | `30` | Maximum time a single hook script may run |
| `FLOCI_INIT_HOOKS_SHUTDOWN_GRACE_PERIOD_SECONDS` | `2` | Time allowed for stop hooks to complete during shutdown |

## Services — Shared

| Variable | Default | Description |
|---|---|---|
| `FLOCI_SERVICES_DOCKER_NETWORK` | *(none)* | Docker network name used by all container-backed services (Lambda, RDS, ElastiCache, ECS, OpenSearch, EKS, MSK). Per-service overrides take precedence |

## Services — Core

### SSM (Parameter Store)
- `FLOCI_SERVICES_SSM_ENABLED` (default `true`) — Enable the SSM service
- `FLOCI_SERVICES_SSM_MAX_PARAMETER_HISTORY` (default `5`) — Maximum number of historical versions kept per parameter

### SQS
- `FLOCI_SERVICES_SQS_ENABLED` (default `true`)
- `FLOCI_SERVICES_SQS_DEFAULT_VISIBILITY_TIMEOUT` (default `30`)
- `FLOCI_SERVICES_SQS_MAX_MESSAGE_SIZE` (default `1048576` = 1 MB)
- `FLOCI_SERVICES_SQS_CLEAR_FIFO_DEDUPLICATION_CACHE_ON_PURGE` (default `false`)

### SNS
- `FLOCI_SERVICES_SNS_ENABLED` (default `true`)

### S3
- `FLOCI_SERVICES_S3_ENABLED` (default `true`)
- `FLOCI_SERVICES_S3_DEFAULT_PRESIGN_EXPIRY_SECONDS` (default `3600`)

### DynamoDB
- `FLOCI_SERVICES_DYNAMODB_ENABLED` (default `true`)

### Lambda
- `FLOCI_SERVICES_LAMBDA_ENABLED` (default `true`)
- `FLOCI_SERVICES_LAMBDA_EPHEMERAL` (default `false`) — Remove Lambda containers immediately after each invocation
- `FLOCI_SERVICES_LAMBDA_DEFAULT_MEMORY_MB` (default `128`)
- `FLOCI_SERVICES_LAMBDA_DEFAULT_TIMEOUT_SECONDS` (default `3`)
- `FLOCI_SERVICES_LAMBDA_RUNTIME_API_BASE_PORT` (default `9200`) — First port in the Lambda Runtime API port range
- `FLOCI_SERVICES_LAMBDA_RUNTIME_API_MAX_PORT` (default `9299`) — Last port in the Lambda Runtime API port range
- `FLOCI_SERVICES_LAMBDA_CODE_PATH` (default `./data/lambda-code`) — Container path where Lambda deployment ZIPs are stored
- `FLOCI_SERVICES_LAMBDA_POLL_INTERVAL_MS` (default `1000`)
- `FLOCI_SERVICES_LAMBDA_CONTAINER_IDLE_TIMEOUT_SECONDS` (default `300`)
- `FLOCI_SERVICES_LAMBDA_REGION_CONCURRENCY_LIMIT` (default `1000`)
- `FLOCI_SERVICES_LAMBDA_UNRESERVED_CONCURRENCY_MIN` (default `100`)
- `FLOCI_SERVICES_LAMBDA_HOT_RELOAD_ENABLED` (default `false`)
- `FLOCI_SERVICES_LAMBDA_HOT_RELOAD_ALLOWED_PATHS` (default *(none)*)
- `FLOCI_SERVICES_LAMBDA_DOCKER_NETWORK` (default *(none)*)
- `FLOCI_SERVICES_LAMBDA_DOCKER_HOST_OVERRIDE` (default *(none)*) — Explicit host/IP Lambda containers use to reach the Runtime API, bypassing auto-detection (e.g. rootless Podman)
- `FLOCI_SERVICES_LAMBDA_AWS_CONFIG_PATH` (default *(none)*)

### API Gateway
- `FLOCI_SERVICES_APIGATEWAY_ENABLED` (default `true`) — Enable the API Gateway v1 (REST) service
- `FLOCI_SERVICES_APIGATEWAYV2_ENABLED` (default `true`) — Enable the API Gateway v2 (HTTP + WebSocket) service

### IAM
- `FLOCI_SERVICES_IAM_ENABLED` (default `true`)
- `FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED` (default `false`) — When `true`, enforce IAM policies on API calls
- `FLOCI_SERVICES_IAM_SEED_DEPLOYER_PRINCIPAL` (default `false`) — Create a local `floci-deployer` IAM user with `AdministratorAccess` and static `floci`/`floci` credentials

### KMS
- `FLOCI_SERVICES_KMS_ENABLED` (default `true`)

### Kinesis
- `FLOCI_SERVICES_KINESIS_ENABLED` (default `true`)

### Firehose
- `FLOCI_SERVICES_FIREHOSE_ENABLED` (default `true`)

### EventBridge
- `FLOCI_SERVICES_EVENTBRIDGE_ENABLED` (default `true`)

### Scheduler
- `FLOCI_SERVICES_SCHEDULER_ENABLED` (default `true`)
- `FLOCI_SERVICES_SCHEDULER_INVOCATION_ENABLED` (default `true`) — When `false`, schedules are stored but never invoked
- `FLOCI_SERVICES_SCHEDULER_TICK_INTERVAL_SECONDS` (default `10`)

### CloudWatch Logs
- `FLOCI_SERVICES_CLOUDWATCHLOGS_ENABLED` (default `true`)
- `FLOCI_SERVICES_CLOUDWATCHLOGS_MAX_EVENTS_PER_QUERY` (default `10000`)

### CloudWatch Metrics
- `FLOCI_SERVICES_CLOUDWATCHMETRICS_ENABLED` (default `true`)

### Secrets Manager
- `FLOCI_SERVICES_SECRETSMANAGER_ENABLED` (default `true`)
- `FLOCI_SERVICES_SECRETSMANAGER_DEFAULT_RECOVERY_WINDOW_DAYS` (default `30`)

### Cognito
- `FLOCI_SERVICES_COGNITO_ENABLED` (default `true`)

### Step Functions
- `FLOCI_SERVICES_STEPFUNCTIONS_ENABLED` (default `true`)

### CloudFormation
- `FLOCI_SERVICES_CLOUDFORMATION_ENABLED` (default `true`)

### ACM (Certificate Manager)
- `FLOCI_SERVICES_ACM_ENABLED` (default `true`)
- `FLOCI_SERVICES_ACM_VALIDATION_WAIT_SECONDS` (default `0`) — Simulated delay before a requested certificate transitions to `ISSUED`

### SES (Simple Email Service)
- `FLOCI_SERVICES_SES_ENABLED` (default `true`)
- `FLOCI_SERVICES_SES_SMTP_HOST` (default *(none)*) — SMTP relay host for outbound email
- `FLOCI_SERVICES_SES_SMTP_PORT` (default `25`)
- `FLOCI_SERVICES_SES_SMTP_USER` (default *(none)*)
- `FLOCI_SERVICES_SES_SMTP_PASS` (default *(none)*)
- `FLOCI_SERVICES_SES_SMTP_STARTTLS` (default `DISABLED`) — `DISABLED`, `OPTIONAL`, or `REQUIRED`

### Pipes
- `FLOCI_SERVICES_PIPES_ENABLED` (default `true`)

## Services — Container-Backed

These services spawn Docker containers. They require access to the Docker socket (`/var/run/docker.sock`).

### ElastiCache
- `FLOCI_SERVICES_ELASTICACHE_ENABLED` (default `true`)
- `FLOCI_SERVICES_ELASTICACHE_PROXY_BASE_PORT` (default `6379`)
- `FLOCI_SERVICES_ELASTICACHE_PROXY_MAX_PORT` (default `6399`)
- `FLOCI_SERVICES_ELASTICACHE_DEFAULT_IMAGE` (default `valkey/valkey:8`)
- `FLOCI_SERVICES_ELASTICACHE_DOCKER_NETWORK` (default *(none)*)

### RDS
- `FLOCI_SERVICES_RDS_ENABLED` (default `true`)
- `FLOCI_SERVICES_RDS_MOCK` (default `false`) — When `true`, DB clusters and instances are created instantly without a real container or auth proxy (API only)
- `FLOCI_SERVICES_RDS_PROXY_BASE_PORT` (default `7001`)
- `FLOCI_SERVICES_RDS_PROXY_MAX_PORT` (default `7099`)
- `FLOCI_SERVICES_RDS_DEFAULT_POSTGRES_IMAGE` (default `postgres:16-alpine`)
- `FLOCI_SERVICES_RDS_DEFAULT_MYSQL_IMAGE` (default `mysql:8.0`)
- `FLOCI_SERVICES_RDS_DEFAULT_MARIADB_IMAGE` (default `mariadb:11`)
- `FLOCI_SERVICES_RDS_DOCKER_NETWORK` (default *(none)*)
- `FLOCI_SERVICES_RDS_DATA_ENABLED` (default `true`) — Requires `FLOCI_SERVICES_RDS_ENABLED=true`
- `FLOCI_SERVICES_RDS_DATA_TRANSACTION_TTL_SECONDS` (default `180`)

### OpenSearch
- `FLOCI_SERVICES_OPENSEARCH_ENABLED` (default `true`)
- `FLOCI_SERVICES_OPENSEARCH_MOCK` (default `false`)
- `FLOCI_SERVICES_OPENSEARCH_DEFAULT_IMAGE` (default `opensearchproject/opensearch:2`)
- `FLOCI_SERVICES_OPENSEARCH_PROXY_BASE_PORT` (default `9400`)
- `FLOCI_SERVICES_OPENSEARCH_PROXY_MAX_PORT` (default `9499`)
- `FLOCI_SERVICES_OPENSEARCH_KEEP_RUNNING_ON_SHUTDOWN` (default `false`)

### MSK (Managed Streaming for Kafka)
- `FLOCI_SERVICES_MSK_ENABLED` (default `true`)
- `FLOCI_SERVICES_MSK_MOCK` (default `false`)
- `FLOCI_SERVICES_MSK_DEFAULT_IMAGE` (default `redpandadata/redpanda:latest`)

### ECR (Elastic Container Registry)
- `FLOCI_SERVICES_ECR_ENABLED` (default `true`)
- `FLOCI_SERVICES_ECR_REGISTRY_IMAGE` (default `registry:2`)
- `FLOCI_SERVICES_ECR_REGISTRY_CONTAINER_NAME` (default `floci-ecr-registry`)
- `FLOCI_SERVICES_ECR_REGISTRY_BASE_PORT` (default `5100`)
- `FLOCI_SERVICES_ECR_REGISTRY_MAX_PORT` (default `5199`)
- `FLOCI_SERVICES_ECR_TLS_ENABLED` (default `false`)
- `FLOCI_SERVICES_ECR_KEEP_RUNNING_ON_SHUTDOWN` (default `true`)
- `FLOCI_SERVICES_ECR_URI_STYLE` (default `hostname`) — `hostname` or `path`
- `FLOCI_SERVICES_ECR_DOCKER_NETWORK` (default *(none)*)

### EKS (Elastic Kubernetes Service)
- `FLOCI_SERVICES_EKS_ENABLED` (default `true`)
- `FLOCI_SERVICES_EKS_MOCK` (default `false`)
- `FLOCI_SERVICES_EKS_PROVIDER` (default `k3s`)
- `FLOCI_SERVICES_EKS_DEFAULT_IMAGE` (default `rancher/k3s:latest`)
- `FLOCI_SERVICES_EKS_API_SERVER_BASE_PORT` (default `6500`)
- `FLOCI_SERVICES_EKS_API_SERVER_MAX_PORT` (default `6599`)
- `FLOCI_SERVICES_EKS_KEEP_RUNNING_ON_SHUTDOWN` (default `false`)
- `FLOCI_SERVICES_EKS_DOCKER_NETWORK` (default *(none)*)

### ECS (Elastic Container Service)
- `FLOCI_SERVICES_ECS_ENABLED` (default `true`)
- `FLOCI_SERVICES_ECS_MOCK` (default `false`)
- `FLOCI_SERVICES_ECS_DEFAULT_MEMORY_MB` (default `512`)
- `FLOCI_SERVICES_ECS_DEFAULT_CPU_UNITS` (default `256`)
- `FLOCI_SERVICES_ECS_DOCKER_NETWORK` (default *(none)*)

### EC2
- `FLOCI_SERVICES_EC2_ENABLED` (default `true`)
- `FLOCI_SERVICES_EC2_MOCK` (default `false`)
- `FLOCI_SERVICES_EC2_IMDS_PORT` (default `9169`)
- `FLOCI_SERVICES_EC2_SSH_PORT_RANGE_START` (default `2200`)
- `FLOCI_SERVICES_EC2_SSH_PORT_RANGE_END` (default `2299`)

### Athena
- `FLOCI_SERVICES_ATHENA_ENABLED` (default `true`)
- `FLOCI_SERVICES_ATHENA_MOCK` (default `false`)
- `FLOCI_SERVICES_ATHENA_DEFAULT_IMAGE` (default `floci/floci-duck:latest`)
- `FLOCI_SERVICES_ATHENA_DUCK_URL` (default *(none)*)

## Services — Additional

| Variable | Default | Description |
|---|---|---|
| `FLOCI_SERVICES_GLUE_ENABLED` | `true` | Enable the Glue service |
| `FLOCI_SERVICES_APPSYNC_ENABLED` | `true` | Enable the AppSync service |
| `FLOCI_SERVICES_BEDROCK_RUNTIME_ENABLED` | `true` | Enable the Bedrock Runtime service |
| `FLOCI_SERVICES_TEXTRACT_ENABLED` | `true` | Enable the Textract service |
| `FLOCI_SERVICES_TRANSFER_ENABLED` | `true` | Enable the Transfer Family service |
| `FLOCI_SERVICES_ROUTE53_ENABLED` | `true` | Enable the Route 53 service |
| `FLOCI_SERVICES_ELBV2_ENABLED` | `true` | Enable the ELBv2 (ALB/NLB) service |
| `FLOCI_SERVICES_ELBV2_MOCK` | `false` | When `true`, load balancers are registered but no containers are spawned |
| `FLOCI_SERVICES_AUTOSCALING_ENABLED` | `true` | Enable the Auto Scaling service |
| `FLOCI_SERVICES_CODEBUILD_ENABLED` | `true` | Enable the CodeBuild service |
| `FLOCI_SERVICES_CODEBUILD_DOCKER_NETWORK` | *(none)* | Docker network for CodeBuild build containers |
| `FLOCI_SERVICES_CODEDEPLOY_ENABLED` | `true` | Enable the CodeDeploy service |
| `FLOCI_SERVICES_BACKUP_ENABLED` | `true` | Enable the AWS Backup service |
| `FLOCI_SERVICES_BACKUP_JOB_COMPLETION_DELAY_SECONDS` | `3` | Simulated delay before backup jobs transition to `COMPLETED` |
| `FLOCI_SERVICES_APPCONFIG_ENABLED` | `true` | Enable the AppConfig service |
| `FLOCI_SERVICES_APPCONFIGDATA_ENABLED` | `true` | Enable the AppConfig Data service |