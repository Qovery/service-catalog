terraform {
  required_version = ">= 1.9"

  required_providers {
    snowflake = {
      source  = "snowflakedb/snowflake"
      version = "~> 2.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

# EXTERNAL blueprint: Snowflake is not tied to the cluster's cloud provider, so the caller supplies
# the account credentials as variables and the blueprint deploys the same way from an AWS, Azure,
# Scaleway or GCP cluster.
#
# Key-pair (JWT) auth rather than a password: Snowflake blocks password auth for SERVICE users and
# is deprecating single-factor password sign-in for humans, so a password would be the one
# credential shape guaranteed to stop working.
provider "snowflake" {
  organization_name = var.snowflake_organization_name
  account_name      = var.snowflake_account_name
  user              = var.snowflake_user
  authenticator     = "SNOWFLAKE_JWT"
  private_key       = var.snowflake_private_key

  private_key_passphrase = var.snowflake_private_key_passphrase != "" ? var.snowflake_private_key_passphrase : null

  role = var.snowflake_role
}
