locals {
  # Snowflake upper-cases unquoted identifiers, while the provider creates objects with the exact
  # string it is given. Upper-casing here keeps every name an ordinary unquoted identifier instead
  # of a case-sensitive one that only works when double-quoted in SQL.
  database_name     = upper(var.database_name)
  schema_name       = upper(var.schema_name)
  warehouse_name    = upper(var.warehouse_name != "" ? var.warehouse_name : "${var.database_name}_WH")
  role_name         = upper(var.role_name != "" ? var.role_name : "${var.database_name}_APP")
  service_user_name = upper(var.service_user_name != "" ? var.service_user_name : "${var.database_name}_APP_USER")

  # Grants take a list; qbm.yml variables are scalars, so they arrive comma-separated. Blank entries
  # are dropped, which makes a trailing comma harmless.
  schema_privileges = compact([for p in split(",", var.schema_privileges) : trimspace(p)])
  table_privileges  = compact([for p in split(",", var.table_privileges) : trimspace(p)])

  # Grants on a schema object want the fully qualified, quoted name.
  qualified_schema = "\"${local.database_name}\".\"${local.schema_name}\""

  comment = "Managed by Qovery — cluster ${var.qovery_cluster_name}"
}

resource "snowflake_database" "this" {
  name                        = local.database_name
  comment                     = local.comment
  data_retention_time_in_days = var.data_retention_time_in_days
}

resource "snowflake_schema" "this" {
  database                    = snowflake_database.this.name
  name                        = local.schema_name
  comment                     = local.comment
  data_retention_time_in_days = var.data_retention_time_in_days
}

resource "snowflake_warehouse" "this" {
  name           = local.warehouse_name
  comment        = local.comment
  warehouse_size = var.warehouse_size

  # A warehouse bills per second while it is up, so it starts suspended and suspends itself again
  # once idle; the first query resumes it.
  auto_suspend        = var.auto_suspend_seconds
  auto_resume         = "true"
  initially_suspended = true
}

resource "snowflake_account_role" "app" {
  name    = local.role_name
  comment = local.comment
}

resource "snowflake_grant_privileges_to_account_role" "database" {
  account_role_name = snowflake_account_role.app.name
  privileges        = ["USAGE"]

  on_account_object {
    object_type = "DATABASE"
    object_name = snowflake_database.this.name
  }
}

resource "snowflake_grant_privileges_to_account_role" "warehouse" {
  account_role_name = snowflake_account_role.app.name
  privileges        = ["USAGE", "OPERATE"]

  on_account_object {
    object_type = "WAREHOUSE"
    object_name = snowflake_warehouse.this.name
  }
}

resource "snowflake_grant_privileges_to_account_role" "schema" {
  account_role_name = snowflake_account_role.app.name
  privileges        = local.schema_privileges

  on_schema {
    schema_name = local.qualified_schema
  }

  depends_on = [snowflake_schema.this]
}

# Future grants rather than a one-shot grant on existing tables: the schema is created here, so
# every table it will ever hold is a future one at apply time.
resource "snowflake_grant_privileges_to_account_role" "future_tables" {
  count = var.grant_future_table_privileges ? 1 : 0

  account_role_name = snowflake_account_role.app.name
  privileges        = local.table_privileges

  on_schema_object {
    future {
      object_type_plural = "TABLES"
      in_schema          = local.qualified_schema
    }
  }

  depends_on = [snowflake_schema.this]
}

# The service user is what makes this blueprint usable from a cluster on any cloud: there is no
# federated identity to lean on, so the application authenticates with the key pair generated here.
resource "tls_private_key" "app" {
  count = var.create_service_user ? 1 : 0

  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "snowflake_service_user" "app" {
  count = var.create_service_user ? 1 : 0

  name    = local.service_user_name
  comment = local.comment

  # SERVICE users cannot hold a password at all — key-pair auth is the only way in, which is the
  # reason to use this user type for an application rather than a regular one.
  rsa_public_key = trimspace(replace(
    replace(tls_private_key.app[0].public_key_pem, "/-----(BEGIN|END) PUBLIC KEY-----/", ""),
    "\n",
    "",
  ))

  default_role      = snowflake_account_role.app.name
  default_warehouse = snowflake_warehouse.this.name
  default_namespace = "${snowflake_database.this.name}.${snowflake_schema.this.name}"
}

resource "snowflake_grant_account_role" "app_user" {
  count = var.create_service_user ? 1 : 0

  role_name = snowflake_account_role.app.name
  user_name = snowflake_service_user.app[0].name
}

resource "snowflake_grant_account_role" "existing_user" {
  count = var.grant_role_to_user != "" ? 1 : 0

  role_name = snowflake_account_role.app.name
  user_name = var.grant_role_to_user
}
