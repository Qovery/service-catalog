output "account_identifier" {
  description = "Account identifier (ORGNAME-ACCOUNTNAME), the form connectors and the CLI expect"
  value       = "${var.snowflake_organization_name}-${var.snowflake_account_name}"
}

output "account_url" {
  description = "Account URL to connect to"
  value       = "https://${var.snowflake_organization_name}-${var.snowflake_account_name}.snowflakecomputing.com"
}

output "database_name" {
  description = "Database created by this blueprint"
  value       = snowflake_database.this.name
}

output "schema_name" {
  description = "Schema created inside the database"
  value       = snowflake_schema.this.name
}

output "warehouse_name" {
  description = "Warehouse created by this blueprint"
  value       = snowflake_warehouse.this.name
}

output "role_name" {
  description = "Account role holding the grants on the database, schema and warehouse"
  value       = snowflake_account_role.app.name
}

output "service_user_name" {
  description = "SERVICE user granted the role (empty when create_service_user is false)"
  value       = var.create_service_user ? snowflake_service_user.app[0].name : ""
}

output "service_user_private_key" {
  description = "PEM-encoded PKCS#8 private key for the SERVICE user — what the Snowflake drivers expect for key-pair auth (empty when create_service_user is false)"
  value       = var.create_service_user ? tls_private_key.app[0].private_key_pem_pkcs8 : ""
  sensitive   = true
}

output "jdbc_url" {
  description = "JDBC URL preset to the created database, schema, warehouse and role. Key-pair auth is passed by the driver, not in the URL."
  value       = "jdbc:snowflake://${var.snowflake_organization_name}-${var.snowflake_account_name}.snowflakecomputing.com/?db=${snowflake_database.this.name}&schema=${snowflake_schema.this.name}&warehouse=${snowflake_warehouse.this.name}&role=${snowflake_account_role.app.name}"
}
