# AWS Bedrock Access

Provisions scoped access to [Amazon Bedrock](https://aws.amazon.com/bedrock/): an IAM policy
(`aws_iam_policy`) allowing model invocation, by default an IAM user with a long-lived access key
(`aws_iam_user`, `aws_iam_access_key`), and optional invocation logging to CloudWatch
(`aws_bedrock_model_invocation_logging_configuration`), via the official `hashicorp/aws` provider
(`~> 6.0`).

**Available on every cloud.** This is an `EXTERNAL` blueprint: the AWS credentials come in as
variables rather than from the cluster, so a GCP, Azure or Scaleway cluster can consume Bedrock, and
an AWS cluster can reach a Bedrock account other than its own. The generated access key is the
point — a workload outside AWS has no IAM role to assume, so a static key is the only way in. On an
AWS cluster, set `create_iam_user = false` and pass `attach_to_role_name` to stay keyless.

It provisions **access**, not models: Bedrock model access is granted per account in the console and
is not manageable through this provider. Enable the models you want first, or every invocation
returns `AccessDeniedException` regardless of the IAM policy.

## Credentials

An AWS access key pair in `aws_access_key_id` + `aws_secret_access_key` (both sensitive), supplied
as variables (`credentials.default: env`). The principal needs IAM write access (`iam:CreateUser`,
`iam:CreatePolicy`, `iam:CreateAccessKey`, `iam:AttachUserPolicy`), plus
`bedrock:PutModelInvocationLoggingConfiguration`, `logs:*` on the log group and `iam:CreateRole`
when `enable_invocation_logging` is true.

## Variables

### Required

| Name                    | Type   | Sensitive | Description                                                          |
| ----------------------- | ------ | --------- | ---------------------------------------------------------------------- |
| `aws_access_key_id`     | string | yes       | Access key id Terraform authenticates as                              |
| `aws_secret_access_key` | string | yes       | Matching secret access key                                            |
| `name_prefix`           | string |           | Prefix for the user, policy and log group. Unique within the account  |

### Optional

| Name                               | Type   | Default     | Description                                                                             |
| ---------------------------------- | ------ | ----------- | ----------------------------------------------------------------------------------------- |
| `aws_region`                       | string | `us-east-1` | Region Bedrock is called in. Model availability differs per region                       |
| `allowed_model_ids`                | string | `*`         | Comma-separated model ids the credentials may invoke. `*` = every foundation model       |
| `allow_list_foundation_models`     | bool   | `true`      | Also allow the read-only discovery calls most SDKs make before invoking                  |
| `create_iam_user`                  | bool   | `true`      | Create the IAM user and access key                                                       |
| `attach_to_role_name`              | string |             | Existing IAM role to attach the policy to. Unset = attach to nothing                     |
| `enable_invocation_logging`        | bool   | `false`     | Turn on invocation logging. **Account-wide per region** — see notes                       |
| `log_retention_days`               | number | `30`        | Log group retention. `0` = keep forever                                                  |
| `log_text_prompts_and_completions` | bool   | `false`     | Include prompt and completion text in the logs                                           |

## Outputs

| Name                 | Sensitive | Description                                                    |
| -------------------- | --------- | ---------------------------------------------------------------- |
| `aws_region`         |           | Region the credentials call Bedrock in                          |
| `account_id`         |           | AWS account the access was created in                           |
| `policy_arn`         |           | Invoke policy ARN, for attaching to further principals          |
| `iam_user_name`      |           | IAM user holding the policy (empty when not created)            |
| `access_key_id`      | yes       | Set as `AWS_ACCESS_KEY_ID`                                      |
| `secret_access_key`  | yes       | Set as `AWS_SECRET_ACCESS_KEY`                                  |
| `bedrock_endpoint`   |           | Bedrock runtime endpoint for the region                         |
| `allowed_model_arns` |           | Model and inference profile ARNs the credentials may invoke     |
| `log_group_name`     |           | Log group receiving invocation logs (empty when logging is off) |

## Notes

- **Invocation logging is account-wide per region.** Bedrock stores one logging configuration per
  account per region, so enabling it here overwrites whatever that account already had, and
  destroying this blueprint removes logging for everything else in that region — not just for this
  user. That is why it defaults to `false`. Leave it off if anything else owns that setting.
- **A cross-region model id is expanded to two ARNs.** Invoking `us.anthropic.claude-…` is
  authorized against both the inference profile in your account and the underlying foundation model
  in whichever region the request is routed to, so the foundation-model ARN is emitted with a region
  wildcard. Pinning it to `aws_region` would deny every cross-region invocation — which is how the
  Claude models are normally called.
- **`allowed_model_ids = "*"` grants every current and future foundation model.** Narrow it to the
  ids you actually call for a least-privilege key.
- **The access key is long-lived.** It is surfaced as a sensitive output and stored encrypted by
  Qovery. Rotating it means tainting `aws_iam_access_key.app` and redeploying. Prefer
  `create_iam_user = false` plus `attach_to_role_name` wherever the workload already has an AWS
  identity.
- **`force_destroy` is set on the IAM user**, so destroying the blueprint removes the user together
  with the keys it still holds instead of failing.
- Guardrails, knowledge bases and provisioned throughput are out of scope: each is a substantial
  configuration of its own and belongs in its own blueprint.
