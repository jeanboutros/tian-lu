# live/10-management-iam/backend.tf — stage-specific backend key.
# bucket/region/dynamodb_table/credentials come from -backend-config at init time — see
# infra/_common/backend.hcl.example for the file, or infra/README.md for the full command.
terraform {
  backend "s3" {}
}
