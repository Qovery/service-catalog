locals {
  uri_username = replace(urlencode(local.db_username), "+", "%20")
  uri_password = replace(urlencode(local.db_password), "+", "%20")
}

output "cluster_id" {
  description = "Atlas cluster ID"
  value       = mongodbatlas_advanced_cluster.this.cluster_id
}

output "cluster_name" {
  description = "Cluster name"
  value       = mongodbatlas_advanced_cluster.this.name
}

output "connection_string_standard" {
  description = "Standard connection string (mongodb://)"
  value       = mongodbatlas_advanced_cluster.this.connection_strings[0].standard
}

output "connection_string_srv" {
  description = "SRV connection string (mongodb+srv://) — insert the db user credentials"
  value       = mongodbatlas_advanced_cluster.this.connection_strings[0].standard_srv
}

output "mongo_db_version" {
  description = "Running MongoDB version"
  value       = mongodbatlas_advanced_cluster.this.mongo_db_version
}

output "db_username" {
  description = "Created database username"
  value       = mongodbatlas_database_user.this.username
}

output "db_password" {
  description = "Database user password"
  value       = local.db_password
  sensitive   = true
}

output "connection_uri" {
  description = "Ready-to-use SRV connection URI with the db user credentials embedded"
  value = replace(
    mongodbatlas_advanced_cluster.this.connection_strings[0].standard_srv,
    "mongodb+srv://",
    "mongodb+srv://${local.uri_username}:${local.uri_password}@"
  )
  sensitive = true
}
