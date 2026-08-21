resource "redpanda_resource_group" "this" {
  name = var.resource_group_name
}

resource "redpanda_serverless_cluster" "this" {
  name              = var.cluster_name
  resource_group_id = redpanda_resource_group.this.id
  serverless_region = var.serverless_region
}
