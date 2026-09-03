locals {
  # BigQuery label values accept only lowercase letters, digits, dashes and underscores, while a
  # Qovery cluster name accepts anything — sanitize before using it as a label.
  cluster_label = substr(lower(replace(var.qovery_cluster_name, "/[^a-zA-Z0-9_-]/", "-")), 0, 63)

  # A dataset id may contain underscores and uppercase, neither of which a service account id
  # allows. Trailing dashes are stripped because the 30-char truncation can land on one.
  derived_service_account_id = replace(
    substr(lower("qovery-bq-${replace(var.dataset_id, "_", "-")}"), 0, 30),
    "/-+$/",
    "",
  )

  service_account_id = var.service_account_id != "" ? var.service_account_id : local.derived_service_account_id
}

resource "google_bigquery_dataset" "this" {
  project       = var.gcp_project_id
  dataset_id    = var.dataset_id
  location      = var.location
  friendly_name = var.friendly_name != "" ? var.friendly_name : null
  description   = var.dataset_description != "" ? var.dataset_description : null

  # 0 is the "unset" sentinel: qbm.yml manifests cannot express an empty default, and the API
  # rejects any positive value below one hour.
  default_table_expiration_ms     = var.default_table_expiration_ms > 0 ? var.default_table_expiration_ms : null
  default_partition_expiration_ms = var.default_partition_expiration_ms > 0 ? var.default_partition_expiration_ms : null

  delete_contents_on_destroy = var.delete_contents_on_destroy

  labels = {
    managed-by     = "qovery"
    qovery-cluster = local.cluster_label
  }
}

# The dedicated account is what makes this blueprint cloud-agnostic: an application on an AWS,
# Azure or Scaleway cluster has no Google workload identity to fall back on, so it authenticates
# with the key below.
resource "google_service_account" "app" {
  count = var.create_service_account ? 1 : 0

  project      = var.gcp_project_id
  account_id   = local.service_account_id
  display_name = "Qovery BigQuery access to ${var.dataset_id}"
  description  = "Created by the Qovery bigquery blueprint for cluster ${var.qovery_cluster_name}"
}

resource "google_bigquery_dataset_iam_member" "app" {
  count = var.create_service_account ? 1 : 0

  project    = var.gcp_project_id
  dataset_id = google_bigquery_dataset.this.dataset_id
  role       = var.service_account_role
  member     = "serviceAccount:${google_service_account.app[0].email}"
}

# Running a query creates a BigQuery job, which is a project-level right — no dataset role grants
# it, so a data-only grant leaves the account able to read rows but unable to SELECT.
resource "google_project_iam_member" "job_user" {
  count = var.create_service_account && var.grant_job_user ? 1 : 0

  project = var.gcp_project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.app[0].email}"
}

resource "google_service_account_key" "app" {
  count = var.create_service_account ? 1 : 0

  service_account_id = google_service_account.app[0].name
}
