# Qovery-injected variables (auto-filled from cluster context)
variable "region" {
  type        = string
  description = "AWS region"
}

variable "qovery_cluster_name" {
  type        = string
  description = "Qovery cluster name"
}

variable "qovery_cluster_id" {
  type        = string
  description = "Qovery cluster short id; the cluster VPC and workers security group are tagged with it."
}

variable "qovery_cluster_long_id" {
  type        = string
  description = "Qovery cluster long id."
}

# User-provided variables
variable "broker_name" {
  type        = string
  description = "Unique in the AWS account and region. Letters, digits, hyphens, underscores; max 50 chars."

  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]{1,50}$", var.broker_name))
    error_message = "broker_name must be 1 to 50 characters: letters, digits, hyphens and underscores only."
  }
}

variable "engine_version" {
  type        = string
  default     = "4.3"
  description = "RabbitMQ version (Amazon MQ applies patches)"

  validation {
    condition     = contains(["4.2", "4.3"], var.engine_version)
    error_message = "engine_version must be 4.2 or 4.3."
  }
}

variable "host_instance_type" {
  type        = string
  default     = "mq.m7g.medium"
  description = "Broker instance type; mq.m7g.large or above for production"

  validation {
    condition     = can(regex("^mq\\.m7g\\.(medium|large|xlarge|2xlarge|4xlarge|8xlarge|12xlarge|16xlarge)$", var.host_instance_type))
    error_message = "host_instance_type must be an mq.m7g type (mq.m7g.medium to mq.m7g.16xlarge): RabbitMQ 4 runs on mq.m7g only."
  }
}

variable "deployment_mode" {
  type        = string
  default     = "SINGLE_INSTANCE"
  description = "Single node or three-node cluster; changing it replaces the broker"

  validation {
    condition     = contains(["SINGLE_INSTANCE", "CLUSTER_MULTI_AZ"], var.deployment_mode)
    error_message = "deployment_mode must be SINGLE_INSTANCE or CLUSTER_MULTI_AZ."
  }
}

variable "admin_username" {
  type        = string
  default     = "qoveryadmin"
  description = "Set at creation only. 2–100 chars: letters, digits, - . _ ~; guest is refused."

  validation {
    condition     = can(regex("^[a-zA-Z0-9._~-]{2,100}$", var.admin_username))
    error_message = "admin_username must be 2 to 100 characters: letters, digits, '-', '.', '_' and '~' only."
  }

  validation {
    condition     = lower(var.admin_username) != "guest"
    error_message = "admin_username must not be guest."
  }
}

variable "admin_password" {
  type        = string
  sensitive   = true
  default     = ""
  description = "Leave empty and Qovery generates one. 12–250 chars, no comma, colon or equals sign, at least 4 distinct characters; set at creation only."

  validation {
    condition     = var.admin_password == "" || (length(var.admin_password) >= 12 && length(var.admin_password) <= 250)
    error_message = "admin_password must be between 12 and 250 characters."
  }

  validation {
    condition     = var.admin_password == "" || length(distinct(split("", var.admin_password))) >= 4
    error_message = "admin_password must contain at least 4 distinct characters."
  }

  validation {
    condition     = !can(regex("[,:=]", var.admin_password))
    error_message = "admin_password must not contain a comma, a colon or an equals sign."
  }
}

variable "publicly_accessible" {
  type        = bool
  default     = false
  description = "A public broker has no security group: anyone with the credentials can connect. Changing it replaces the broker."
}

variable "subnet_ids" {
  type        = string
  default     = ""
  description = "Leave empty — derived from the cluster's DB subnet group. Set it (comma-separated, one per AZ) only on a user-provided VPC."
}

variable "security_group_ids" {
  type        = string
  default     = ""
  description = "Leave empty for the blueprint's group (opens 5671, 443, 16001-16003 to allowed_cidrs). Else comma-separated ids; set at creation only."
}

variable "allowed_cidrs" {
  type        = string
  default     = ""
  description = "Leave empty to allow the whole VPC (every cluster pod). Else comma-separated IPv4 CIDRs; only affects the blueprint's security group."

  validation {
    # cidrhost also accepts IPv6, which the IPv4-only cidr_blocks would reject at apply.
    condition     = var.allowed_cidrs == "" || alltrue([for c in split(",", var.allowed_cidrs) : can(regex("^[0-9.]+/[0-9]+$", trimspace(c))) && can(cidrhost(trimspace(c), 0))])
    error_message = "allowed_cidrs must be comma-separated IPv4 CIDRs, e.g. 10.0.0.0/16,192.168.1.0/24."
  }
}

variable "apply_changes_now" {
  type        = bool
  default     = false
  description = "Apply changes immediately (the broker reboots) instead of during the maintenance window"
}

variable "maintenance_day_of_week" {
  type        = string
  default     = "SUNDAY"
  description = "Maintenance window day"

  validation {
    condition     = contains(["MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY", "SUNDAY"], var.maintenance_day_of_week)
    error_message = "maintenance_day_of_week must be a day of the week in capitals, e.g. SUNDAY."
  }
}

variable "maintenance_time_of_day" {
  type        = string
  default     = "03:00"
  description = "Start time, hh:mm in 24-hour format"

  validation {
    condition     = can(regex("^([01][0-9]|2[0-3]):[0-5][0-9]$", var.maintenance_time_of_day))
    error_message = "maintenance_time_of_day must be hh:mm in 24-hour format, e.g. 03:00."
  }
}

variable "maintenance_time_zone" {
  type        = string
  default     = "UTC"
  description = "IANA name, e.g. UTC or Europe/Paris"
}

variable "general_logs" {
  type        = bool
  default     = false
  description = "Send broker logs to CloudWatch Logs (billed by CloudWatch). Adds a CloudWatch Logs resource policy; AWS allows 10 per region."
}

variable "kms_key_id" {
  type        = string
  default     = ""
  description = "Empty = an AWS-owned key. Set a KMS key ARN to use yours; changing it replaces the broker."
}

variable "consumer_timeout_ms" {
  type        = number
  default     = 1800000
  description = "Delivery acknowledgement timeout in ms (RabbitMQ consumer_timeout); a consumer that does not ack in time has its channel closed. 0 = no timeout."

  validation {
    condition     = var.consumer_timeout_ms >= 0 && var.consumer_timeout_ms <= 2147483647 && floor(var.consumer_timeout_ms) == var.consumer_timeout_ms
    error_message = "consumer_timeout_ms must be a whole number between 0 and 2147483647."
  }
}

variable "heartbeat_seconds" {
  type        = number
  default     = 60
  description = "Seconds without traffic before RabbitMQ considers a connection dead (60-3600)"

  validation {
    condition     = var.heartbeat_seconds >= 60 && var.heartbeat_seconds <= 3600 && floor(var.heartbeat_seconds) == var.heartbeat_seconds
    error_message = "heartbeat_seconds must be a whole number between 60 and 3600."
  }
}

variable "extra_configuration" {
  type        = string
  default     = ""
  description = "Extra rabbitmq.conf lines, separated by ';'. Amazon MQ rejects keys it does not allow at apply."
}
