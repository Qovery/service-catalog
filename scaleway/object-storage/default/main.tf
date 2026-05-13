# -----------------------------------------------------------------------------
# Scaleway Object Storage Bucket
# -----------------------------------------------------------------------------

resource "scaleway_object_bucket" "this" {
  name   = var.bucket_name
  region = var.region
  acl    = var.acl

  force_destroy = var.force_destroy

  versioning {
    enabled = var.versioning_enabled
  }

  tags = {
    managed-by   = "qovery-blueprint"
    blueprint    = "scaleway-object-storage"
    cluster-name = var.qovery_cluster_name
  }
}
