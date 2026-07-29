variable "environment" {
  type = string
}

variable "account_id" {
  type = string # 12-digit AKID => Floci account
}
variable "secret_key" {
  type      = string
  sensitive = true
}
variable "region" {
  type = string
}
variable "floci_endpoint" {
  type = string
}
variable "default_tags" {
  type    = map(string)
  default = {}
}
