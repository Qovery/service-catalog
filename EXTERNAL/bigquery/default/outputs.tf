output "dataset_id" {
  description = "BigQuery dataset id"
  value       = google_bigquery_dataset.this.dataset_id
}

output "project_id" {
  description = "Project the dataset lives in"
  value       = google_bigquery_dataset.this.project
}

output "location" {
  description = "Dataset location"
  value       = google_bigquery_dataset.this.location
}

output "dataset_reference" {
  description = "Fully qualified dataset reference (project.dataset), the form BigQuery SQL and client libraries expect"
  value       = "${google_bigquery_dataset.this.project}.${google_bigquery_dataset.this.dataset_id}"
}

output "self_link" {
  description = "Dataset REST resource URI"
  value       = google_bigquery_dataset.this.self_link
}

output "service_account_email" {
  description = "Email of the created service account (empty when create_service_account is false)"
  value       = var.create_service_account ? google_service_account.app[0].email : ""
}

output "service_account_key_json" {
  description = "Service account key as raw JSON — write it to a file and point GOOGLE_APPLICATION_CREDENTIALS at it, or feed it to the client library directly (empty when create_service_account is false)"
  value       = var.create_service_account ? base64decode(google_service_account_key.app[0].private_key) : ""
  sensitive   = true
}

output "service_account_key_base64" {
  description = "Same key, still base64-encoded as the API returns it — the friendlier form for a single-line environment variable (empty when create_service_account is false)"
  value       = var.create_service_account ? google_service_account_key.app[0].private_key : ""
  sensitive   = true
}
