variable "aws_access_key_id" {
  type        = string
  sensitive   = true
  description = "Access key id of the AWS principal Terraform authenticates as. Needs IAM write access on users, policies and access keys — including the delete and detach actions, or destroy fails. The blueprint README lists the full set."

  validation {
    condition     = length(var.aws_access_key_id) > 0
    error_message = "aws_access_key_id must not be empty."
  }
}

variable "aws_secret_access_key" {
  type        = string
  sensitive   = true
  description = "Secret access key matching aws_access_key_id"

  validation {
    condition     = length(var.aws_secret_access_key) > 0
    error_message = "aws_secret_access_key must not be empty."
  }
}

variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "Region Bedrock is called in. Model availability differs per region — check the model you want is offered there before changing it."

  validation {
    condition     = can(regex("^[a-z]{2}(-gov)?-[a-z]+-[0-9]$", var.aws_region))
    error_message = "aws_region must be an AWS region id, e.g. us-east-1 or eu-west-3."
  }
}

variable "name_prefix" {
  type        = string
  description = "Prefix for the resources this blueprint names: the IAM user (<prefix>-bedrock) and its policy (<prefix>-bedrock-invoke). Must be unique within the AWS account."

  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9_.-]{0,47}$", var.name_prefix))
    error_message = "name_prefix must be 1-48 chars: letters, digits, and _ . - , starting with a letter or digit."
  }
}

variable "allowed_model_ids" {
  type        = string
  description = "Comma-separated Bedrock model ids the credentials may invoke, e.g. anthropic.claude-sonnet-4-5-20250929-v1:0. A cross-region id (us.anthropic.…) is expanded to both the inference profile and the underlying foundation model. Pass \"*\" to allow every foundation model in the account — deliberately not the default, since that also covers every model added in future."

  validation {
    condition     = length(compact([for m in split(",", var.allowed_model_ids) : trimspace(m)])) > 0
    error_message = "allowed_model_ids must list at least one model id, or \"*\" for all of them. An empty or comma-only value is rejected rather than silently granting every model."
  }
}

variable "allow_list_foundation_models" {
  type        = bool
  default     = true
  description = "Also allow read-only discovery calls (ListFoundationModels, GetFoundationModel, ListInferenceProfiles, GetInferenceProfile). Most SDK samples and model pickers call these before invoking."
}

variable "create_iam_user" {
  type        = bool
  default     = true
  description = "Create an IAM user with a long-lived access key. This is what makes Bedrock reachable from a cluster outside AWS, which has no IAM role to assume. Set false on an AWS cluster and use attach_to_role_name instead."
}

variable "attach_to_role_name" {
  type        = string
  default     = ""
  description = "Existing IAM role in the same account to attach the invoke policy to — the keyless path for a workload that already has an AWS identity (IRSA, EC2 instance profile). Unset = attach to nothing."
}

variable "qovery_cluster_name" {
  type        = string
  description = "Qovery cluster name, injected from the qbm.yml `cluster.name` context variable"
}
