variable "aws_access_key_id" {
  type        = string
  sensitive   = true
  description = "Access key id of the AWS principal Terraform authenticates as. Needs IAM write access plus bedrock:* for the optional logging configuration."

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
  description = "Prefix for every resource this blueprint names: the IAM user (<prefix>-bedrock), its policy (<prefix>-bedrock-invoke) and the log group (/aws/bedrock/<prefix>). Must be unique within the AWS account."

  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9_.-]{0,47}$", var.name_prefix))
    error_message = "name_prefix must be 1-48 chars: letters, digits, and _ . - , starting with a letter or digit."
  }
}

variable "allowed_model_ids" {
  type        = string
  default     = "*"
  description = "Comma-separated Bedrock model ids the credentials may invoke, e.g. anthropic.claude-sonnet-4-5-20250929-v1:0. * = every foundation model in the account. A cross-region id (us.anthropic.…) is expanded to both the inference profile and the underlying foundation model."
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

variable "enable_invocation_logging" {
  type        = bool
  default     = false
  description = "Turn on Bedrock model invocation logging to CloudWatch. Off by default because the setting is account-wide per region, not per user: enabling it here overwrites whatever the account already had, and destroying this blueprint removes it for everything else in that region."
}

variable "log_retention_days" {
  type        = number
  default     = 30
  description = "Retention of the created log group, in days. 0 = keep forever."

  validation {
    condition = contains(
      [0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653],
      var.log_retention_days,
    )
    error_message = "log_retention_days must be one of the retention periods CloudWatch accepts: 0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653."
  }
}

variable "log_text_prompts_and_completions" {
  type        = bool
  default     = false
  description = "Include prompt and completion text in the invocation logs. Off by default: prompts routinely carry user data, and the logs are readable by anyone with CloudWatch access."
}

variable "qovery_cluster_name" {
  type        = string
  description = "Qovery cluster name, injected from the qbm.yml `cluster.name` context variable"
}
