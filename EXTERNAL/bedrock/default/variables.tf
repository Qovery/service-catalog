variable "aws_access_key_id" {
  type        = string
  sensitive   = true
  description = "Key of the principal Terraform runs as. Needs IAM write on users, policies and access keys, delete and detach included; see the README."

  validation {
    condition     = length(var.aws_access_key_id) > 0
    error_message = "aws_access_key_id must not be empty."
  }
}

variable "aws_secret_access_key" {
  type        = string
  sensitive   = true
  description = "Matches aws_access_key_id"

  validation {
    condition     = length(var.aws_secret_access_key) > 0
    error_message = "aws_secret_access_key must not be empty."
  }
}

variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "Region Bedrock is called in. Model availability differs per region: check yours is offered there."

  validation {
    condition     = can(regex("^[a-z]{2}(-gov)?-[a-z]+-[0-9]$", var.aws_region))
    error_message = "aws_region must be an AWS region id, e.g. us-east-1 or eu-west-3."
  }
}

variable "name_prefix" {
  type        = string
  description = "Names the IAM user (<prefix>-bedrock) and its policy (<prefix>-bedrock-invoke). Must be unique within the AWS account."

  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9_.-]{0,47}$", var.name_prefix))
    error_message = "name_prefix must be 1-48 chars: letters, digits, and _ . - , starting with a letter or digit."
  }
}

variable "allowed_model_ids" {
  type        = string
  description = "Comma-separated model ids, e.g. anthropic.claude-sonnet-4-5-20250929-v1:0; a cross-region id (us.…) also covers its base model. * allows every model."

  validation {
    condition     = length(compact([for m in split(",", var.allowed_model_ids) : trimspace(m)])) > 0
    error_message = "allowed_model_ids must list at least one model id, or \"*\" for all of them. An empty or comma-only value is rejected rather than silently granting every model."
  }
}

variable "allow_list_foundation_models" {
  type        = bool
  default     = true
  description = "Also allow read-only discovery calls (List/Get FoundationModel, InferenceProfile), which most SDK samples and model pickers make before invoking."
}

variable "create_iam_user" {
  type        = bool
  default     = true
  description = "Create an IAM user with a long-lived key, needed outside AWS where there is no role to assume. On an AWS cluster, turn off and use attach_to_role_name."
}

variable "attach_to_role_name" {
  type        = string
  default     = ""
  description = "Unset = attach to nothing. Else an existing IAM role in the account (IRSA, EC2 instance profile) to attach the invoke policy to."
}

variable "qovery_cluster_name" {
  type        = string
  description = "Qovery cluster name, injected from the qbm.yml `cluster.name` context variable"
}
