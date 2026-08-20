resource "aiven_kafka" "this" {
  project      = var.project
  service_name = var.service_name
  cloud_name   = var.cloud_name
  plan         = var.plan

  kafka_user_config {
    kafka_version = var.kafka_version
  }
}
