# _common/backend-prod.hcl — S3 remote-state backend for the PROD environment.
# Per stage:  terraform init -backend-config=_common/backend-prod.hcl \
#                            -backend-config="key=prod/<NN-stage>/terraform.tfstate"
# (infra/stage.sh passes both automatically.) Backend blocks cannot use var.*, so the
# per-environment values are fixed here — copy this file to add another environment.

bucket = "tf-state-prod"
region = "eu-west-2"
key    = "prod/PLACEHOLDER/terraform.tfstate"

# State locking via DynamoDB conditional writes (verify with preflight G3). On Terraform
# >= 1.11 you can drop dynamodb_table and set use_lockfile = true for S3-native locking.
dynamodb_table = "tf-locks-prod"

# access_key/secret_key are deliberately NOT set here (they would be written in cleartext
# to .terraform/terraform.tfstate and plan files). Export the environment's account-root
# credential before `terraform init`:
#   export AWS_ACCESS_KEY_ID="444444444444"      # prod AKID (selects the account, §4.1)
#   export AWS_SECRET_ACCESS_KEY="<account secret>"  # ignored by Floci today (see docs/issues/)

skip_credentials_validation = true
skip_metadata_api_check     = true
skip_region_validation      = true
skip_requesting_account_id  = true
use_path_style              = true

endpoints = {
  s3       = "http://localhost:4566"
  dynamodb = "http://localhost:4566"
}
