data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

locals {
  iam_user_name = "${var.name_prefix}-bedrock"
  policy_name   = "${var.name_prefix}-bedrock-invoke"

  model_ids = compact([for m in split(",", var.allowed_model_ids) : trimspace(m)])

  # Only a literal "*" widens the grant. An empty or comma-only list used to land here as
  # `length == 0` and open up every model — it is rejected in variables.tf instead, so this
  # cannot fail open.
  all_models = contains(local.model_ids, "*")

  # A cross-region id (us.anthropic.…) names an inference profile, not a foundation model, and
  # invoking through one is authorized against BOTH arns — the profile in this account and the
  # foundation model in whichever region the request lands in. Hence the region wildcard on the
  # foundation-model arn: pinning it to var.aws_region would deny every cross-region invocation.
  base_model_ids = [
    for m in local.model_ids : replace(m, "/^(us|eu|apac|global|us-gov)\\./", "")
  ]

  foundation_model_arns = local.all_models ? [
    "arn:${data.aws_partition.current.partition}:bedrock:*::foundation-model/*",
    ] : [
    for m in local.base_model_ids :
    "arn:${data.aws_partition.current.partition}:bedrock:*::foundation-model/${m}"
  ]

  inference_profile_arns = local.all_models ? [
    "arn:${data.aws_partition.current.partition}:bedrock:${var.aws_region}:${data.aws_caller_identity.current.account_id}:inference-profile/*",
    "arn:${data.aws_partition.current.partition}:bedrock:${var.aws_region}:${data.aws_caller_identity.current.account_id}:application-inference-profile/*",
    ] : [
    for m in local.model_ids :
    "arn:${data.aws_partition.current.partition}:bedrock:${var.aws_region}:${data.aws_caller_identity.current.account_id}:inference-profile/${m}"
  ]

  tags = {
    "managed-by"     = "qovery"
    "qovery-cluster" = substr(var.qovery_cluster_name, 0, 256)
  }
}

data "aws_iam_policy_document" "invoke" {
  statement {
    sid    = "InvokeBedrockModels"
    effect = "Allow"

    actions = [
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream",
      "bedrock:Converse",
      "bedrock:ConverseStream",
    ]

    resources = concat(local.foundation_model_arns, local.inference_profile_arns)
  }

  # Discovery calls are account-wide by definition: there is no per-model arn to scope a list to.
  dynamic "statement" {
    for_each = var.allow_list_foundation_models ? [1] : []

    content {
      sid    = "DiscoverBedrockModels"
      effect = "Allow"

      actions = [
        "bedrock:ListFoundationModels",
        "bedrock:GetFoundationModel",
        "bedrock:ListInferenceProfiles",
        "bedrock:GetInferenceProfile",
      ]

      resources = ["*"]
    }
  }
}

resource "aws_iam_policy" "invoke" {
  name        = local.policy_name
  description = "Bedrock invoke access issued by the Qovery bedrock blueprint for cluster ${var.qovery_cluster_name}"
  policy      = data.aws_iam_policy_document.invoke.json
  tags        = local.tags
}

resource "aws_iam_user" "app" {
  count = var.create_iam_user ? 1 : 0

  name          = local.iam_user_name
  force_destroy = true
  tags          = local.tags
}

resource "aws_iam_user_policy_attachment" "app" {
  count = var.create_iam_user ? 1 : 0

  user       = aws_iam_user.app[0].name
  policy_arn = aws_iam_policy.invoke.arn
}

resource "aws_iam_access_key" "app" {
  count = var.create_iam_user ? 1 : 0

  user = aws_iam_user.app[0].name
}

# The keyless path: a workload that already has an AWS identity gets the same policy on its role
# instead of a static key.
resource "aws_iam_role_policy_attachment" "existing_role" {
  count = var.attach_to_role_name != "" ? 1 : 0

  role       = var.attach_to_role_name
  policy_arn = aws_iam_policy.invoke.arn
}
