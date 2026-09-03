resource "mongodbatlas_advanced_cluster" "this" {
  project_id             = var.project_id
  name                   = var.cluster_name
  cluster_type           = "REPLICASET"
  backup_enabled         = var.backup_enabled
  mongo_db_major_version = var.mongo_db_major_version

  replication_specs {
    region_configs {
      electable_specs {
        instance_size = var.instance_size
        node_count    = 3
      }
      provider_name = var.provider_name
      region_name   = var.region_name
      priority      = 7
    }
  }
}

resource "random_password" "master" {
  length      = 32
  special     = false
  min_lower   = 1
  min_upper   = 1
  min_numeric = 1
}

locals {
  db_password = var.db_password != "" ? var.db_password : random_password.master.result
}

resource "mongodbatlas_database_user" "this" {
  project_id         = var.project_id
  username           = var.db_username
  password           = local.db_password
  auth_database_name = "admin"

  roles {
    role_name     = "readWriteAnyDatabase"
    database_name = "admin"
  }
}

resource "mongodbatlas_project_ip_access_list" "this" {
  project_id = var.project_id
  cidr_block = var.ip_access_list_cidr
  comment    = "Managed by Qovery blueprint"
}
