output "database_name" {
  description = "Database name"
  value       = planetscale_vitess_branch.main.database
}

output "branch_name" {
  description = "Production branch name"
  value       = planetscale_vitess_branch.main.name
}

output "mysql_address" {
  description = "MySQL address for the branch"
  value       = planetscale_vitess_branch.main.mysql_address
}

output "mysql_edge_address" {
  description = "MySQL edge address for the branch"
  value       = planetscale_vitess_branch.main.mysql_edge_address
}

output "access_host_url" {
  description = "Connection host for the generated password"
  value       = planetscale_vitess_branch_password.app.access_host_url
}

output "username" {
  description = "Generated database username"
  value       = planetscale_vitess_branch_password.app.username
}

output "password" {
  description = "Generated database password (only available at creation time)"
  value       = planetscale_vitess_branch_password.app.plain_text
  sensitive   = true
}

output "connection_uri" {
  description = "Ready-to-use MySQL connection URI with credentials embedded"
  value       = "mysql://${planetscale_vitess_branch_password.app.username}:${planetscale_vitess_branch_password.app.plain_text}@${planetscale_vitess_branch_password.app.access_host_url}/${var.database_name}?sslaccept=strict"
  sensitive   = true
}
