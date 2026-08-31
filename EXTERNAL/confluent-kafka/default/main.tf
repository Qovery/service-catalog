resource "confluent_environment" "this" {
  display_name = var.environment_name
}

resource "confluent_kafka_cluster" "this" {
  display_name = var.cluster_name
  availability = var.availability
  cloud        = var.cloud
  region       = var.region

  basic {}

  environment {
    id = confluent_environment.this.id
  }
}

# Service account + API key give a consuming app SASL credentials scoped to this cluster.
resource "confluent_service_account" "app" {
  display_name = var.service_account_name
  description  = "Client identity for Kafka cluster ${var.cluster_name} (managed by Qovery blueprint)"
}

resource "confluent_api_key" "app" {
  display_name = "${var.service_account_name}-kafka-key"
  description  = "Kafka API key for ${var.service_account_name}"

  owner {
    id          = confluent_service_account.app.id
    api_version = confluent_service_account.app.api_version
    kind        = confluent_service_account.app.kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.this.id
    api_version = confluent_kafka_cluster.this.api_version
    kind        = confluent_kafka_cluster.this.kind

    environment {
      id = confluent_environment.this.id
    }
  }
}

