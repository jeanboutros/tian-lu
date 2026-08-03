# _common/backend-dev.hcl — S3 remote-state backend for the DEV environment.
# Per stage:  terraform init -backend-config=_common/backend-dev.hcl \
#                            -backend-config="key=dev/<NN-stage>/terraform.tfstate"
# (infra/stage.sh passes both automatically.) Backend blocks cannot use var.*, so the
# per-environment values are fixed here — copy this file to add another environment.
#
# The state bucket + lock table are created by live/00-backend-bootstrap (LOCAL state,
# chicken/egg); every other stage uses this S3 backend.

bucket = "tf-state-dev"
region = "eu-west-2"
key    = "dev/PLACEHOLDER/terraform.tfstate"

# State locking via DynamoDB conditional writes (verify with preflight G3). On Terraform
# >= 1.11 you can drop dynamodb_table and set use_lockfile = true for S3-native locking.
dynamodb_table = "tf-locks-dev"

# access_key/secret_key are deliberately NOT set here: this file is committed, and Terraform
# copies backend config verbatim into .terraform/ and plan files, which would persist the
# secret in cleartext.
#
# You do NOT need to export them by hand -- `make init` / `stage.sh` derive the account-root
# credential at runtime: AWS_ACCESS_KEY_ID from account_id in environments/<env>.tfvars (a
# 12-digit AKID selects the Floci account, section 4.1), and AWS_SECRET_ACCESS_KEY from the
# first of AWS_SECRET_ACCESS_KEY, TF_VAR_secret_key, or the dev twin's cached secret at
# ~/.cache/tianlu-floci/dev/account.secret. Note the backend does NOT read
# var.account_id/var.secret_key -- those configure only the `provider "aws"` block -- which
# is why this derivation exists at all.
# Setting AWS_ACCESS_KEY_ID to a different account is refused rather than silently honoured.

skip_credentials_validation = true
skip_metadata_api_check     = true
skip_region_validation      = true
skip_requesting_account_id  = true
use_path_style              = true

endpoints = {
  s3       = "http://localhost:4566"
  dynamodb = "http://localhost:4566"
}
