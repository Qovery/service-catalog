variable "snowflake_organization_name" {
  type        = string
  description = "Snowflake organization name — the first half of the account identifier (SHOW ORGANIZATION ACCOUNTS, or the ORGNAME in ORGNAME-ACCOUNTNAME)"

  validation {
    condition     = length(var.snowflake_organization_name) > 0
    error_message = "snowflake_organization_name must not be empty."
  }
}

variable "snowflake_account_name" {
  type        = string
  description = "Snowflake account name — the second half of the account identifier (the ACCOUNTNAME in ORGNAME-ACCOUNTNAME), not the legacy account locator"

  validation {
    condition     = length(var.snowflake_account_name) > 0
    error_message = "snowflake_account_name must not be empty."
  }
}

variable "snowflake_user" {
  type        = string
  description = "Snowflake user Terraform authenticates as. Its RSA public key must already be registered on the user (ALTER USER … SET RSA_PUBLIC_KEY)."

  validation {
    condition     = length(var.snowflake_user) > 0
    error_message = "snowflake_user must not be empty."
  }
}

variable "snowflake_private_key" {
  type        = string
  sensitive   = true
  description = "PEM-encoded PKCS#8 private key matching the public key registered on snowflake_user"

  validation {
    condition     = can(regex("-----BEGIN [A-Z ]*PRIVATE KEY-----", var.snowflake_private_key))
    error_message = "snowflake_private_key must be the PEM contents (starting with -----BEGIN PRIVATE KEY-----), not a file path."
  }
}

variable "snowflake_private_key_passphrase" {
  type        = string
  sensitive   = true
  default     = ""
  description = "Passphrase protecting snowflake_private_key. Empty = the key is unencrypted."
}

variable "snowflake_role" {
  type        = string
  default     = "ACCOUNTADMIN"
  description = "Role Terraform runs as. It must be able to create databases, warehouses and account roles, and to grant them — SYSADMIN alone cannot create a role, so a custom role needs CREATE ROLE and CREATE USER on the account as well."
}

variable "database_name" {
  type        = string
  description = "Database to create. Upper-cased before use, so it stays an unquoted Snowflake identifier."

  # 246, not Snowflake's 255: the derived warehouse/role/user names append up to "_APP_USER", so a
  # 255-char database name would produce a 264-char identifier that fails at apply. The cap is
  # unconditional — setting the three names explicitly does not lift it. Nine characters is not
  # worth three cross-variable validations and two ways for the limit to disagree.
  validation {
    condition     = can(regex("^[A-Za-z_][A-Za-z0-9_$]*$", var.database_name)) && length(var.database_name) <= 246
    error_message = "database_name must start with a letter or underscore, contain only letters, digits, underscores and $, and be at most 246 chars (the derived names append up to 9 more)."
  }
}

variable "schema_name" {
  type        = string
  default     = "APP"
  description = "Schema created inside the database. Upper-cased before use."

  validation {
    condition     = can(regex("^[A-Za-z_][A-Za-z0-9_$]*$", var.schema_name)) && length(var.schema_name) <= 255
    error_message = "schema_name must start with a letter or underscore and contain only letters, digits, underscores and $."
  }
}

variable "warehouse_name" {
  type        = string
  default     = ""
  description = "Leave empty — derived from the database name as <database_name>_WH. Set it only to match an existing naming convention."

  validation {
    condition     = var.warehouse_name == "" || (can(regex("^[A-Za-z_][A-Za-z0-9_$]*$", var.warehouse_name)) && length(var.warehouse_name) <= 255)
    error_message = "warehouse_name must be a Snowflake identifier: start with a letter or underscore, letters/digits/underscores/$ only, at most 255 chars."
  }
}

variable "warehouse_size" {
  type        = string
  default     = "XSMALL"
  description = "Compute size of the created warehouse. Each step up doubles the credit burn per second of runtime."

  validation {
    condition = contains([
      "XSMALL", "SMALL", "MEDIUM", "LARGE", "XLARGE", "XXLARGE", "XXXLARGE", "X4LARGE",
    ], var.warehouse_size)
    error_message = "warehouse_size must be one of: XSMALL, SMALL, MEDIUM, LARGE, XLARGE, XXLARGE, XXXLARGE, X4LARGE."
  }
}

variable "auto_suspend_seconds" {
  type        = number
  default     = 60
  description = "Idle seconds before the warehouse suspends. This is the main cost control: a warehouse bills for every second it stays up."

  validation {
    condition     = var.auto_suspend_seconds >= 60 && var.auto_suspend_seconds <= 3600
    error_message = "auto_suspend_seconds must be between 60 and 3600."
  }
}

variable "data_retention_time_in_days" {
  type        = number
  default     = 1
  description = "Time Travel window on the database, in days. Above 1 requires Enterprise Edition; 0 disables Time Travel and with it UNDROP."

  validation {
    condition     = var.data_retention_time_in_days >= 0 && var.data_retention_time_in_days <= 90
    error_message = "data_retention_time_in_days must be between 0 and 90."
  }
}

variable "role_name" {
  type        = string
  default     = ""
  description = "Leave empty — derived from the database name as <database_name>_APP. This is the account role granted the privileges below."

  validation {
    condition     = var.role_name == "" || (can(regex("^[A-Za-z_][A-Za-z0-9_$]*$", var.role_name)) && length(var.role_name) <= 255)
    error_message = "role_name must be a Snowflake identifier: start with a letter or underscore, letters/digits/underscores/$ only, at most 255 chars."
  }
}

variable "schema_privileges" {
  type        = string
  default     = "USAGE,CREATE TABLE,CREATE VIEW,CREATE STAGE"
  description = "Comma-separated privileges granted to the role on the schema itself"
}

variable "table_privileges" {
  type        = string
  default     = "SELECT,INSERT,UPDATE,DELETE"
  description = "Comma-separated privileges granted to the role on future tables in the schema. Applies to tables created after this deployment, which is every table when the schema is new."
}

variable "grant_future_table_privileges" {
  type        = bool
  default     = true
  description = "Grant table_privileges on future tables in the schema. Set false to manage table grants yourself."
}

variable "create_service_user" {
  type        = bool
  default     = true
  description = "Create a SERVICE user with a generated RSA key pair and grant it the role, so an application on any cloud can connect. Set false to attach your own users to the role."
}

variable "service_user_name" {
  type        = string
  default     = ""
  description = "Leave empty — derived from the database name as <database_name>_APP_USER. Only used when create_service_user is true."

  validation {
    condition     = var.service_user_name == "" || (can(regex("^[A-Za-z_][A-Za-z0-9_$]*$", var.service_user_name)) && length(var.service_user_name) <= 255)
    error_message = "service_user_name must be a Snowflake identifier: start with a letter or underscore, letters/digits/underscores/$ only, at most 255 chars."
  }
}

variable "grant_role_to_user" {
  type        = string
  default     = ""
  description = "Existing Snowflake user to also grant the role to. Unset = grant it to nobody beyond the created service user."

  validation {
    condition     = var.grant_role_to_user == "" || (can(regex("^[A-Za-z_][A-Za-z0-9_$]*$", var.grant_role_to_user)) && length(var.grant_role_to_user) <= 255)
    error_message = "grant_role_to_user must be a Snowflake identifier: start with a letter or underscore, letters/digits/underscores/$ only, at most 255 chars."
  }
}

variable "qovery_cluster_name" {
  type        = string
  description = "Qovery cluster name, injected from the qbm.yml `cluster.name` context variable"
}
