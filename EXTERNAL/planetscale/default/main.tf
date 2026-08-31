# The database is created implicitly with its first (production) branch. NOTE: destroying
# this blueprint deletes the branch and therefore the database and all its data — same
# teardown semantics as the other managed-database blueprints in this catalog.
resource "planetscale_vitess_branch" "main" {
  organization = var.organization
  database     = var.database_name
  name         = var.branch_name
  cluster_size = var.cluster_size == "" ? null : var.cluster_size
  region       = var.region == "" ? null : var.region
}

resource "planetscale_vitess_branch_password" "app" {
  organization = var.organization
  database     = var.database_name
  branch       = planetscale_vitess_branch.main.name
  name         = "qovery-app"
  role         = var.role
}
