# AWS Bedrock Access

Provisions scoped access to [Amazon Bedrock](https://aws.amazon.com/bedrock/): an IAM policy
(`aws_iam_policy`) allowing invocation of the models you name, and by default an IAM user with a
long-lived access key (`aws_iam_user`, `aws_iam_access_key`), via the official `hashicorp/aws`
provider (`~> 6.0`).

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
as variables (`credentials.default: env`). The principal needs:

| Action | Why |
| --- | --- |
| `iam:CreatePolicy`, `iam:DeletePolicy` | the invoke policy |
| `iam:CreateUser`, `iam:DeleteUser`, `iam:CreateAccessKey`, `iam:DeleteAccessKey`, `iam:AttachUserPolicy`, `iam:DetachUserPolicy` | the IAM user and its key (`create_iam_user = true`) |
| `iam:TagUser`, `iam:TagPolicy` | every resource here is tagged |
| `iam:AttachRolePolicy`, `iam:DetachRolePolicy` | attaching to an existing role (`attach_to_role_name`) |
| `iam:GetUser`, `iam:GetPolicy`, `iam:ListAttachedUserPolicies`, `sts:GetCallerIdentity` | reads Terraform makes on every plan |

No `bedrock:*` permission is needed — the blueprint only writes IAM.

## Variables

### Required

| Name                    | Type   | Sensitive | Description                                                          |
| ----------------------- | ------ | --------- | ---------------------------------------------------------------------- |
| `aws_access_key_id`     | string | yes       | Access key id Terraform authenticates as                              |
| `aws_secret_access_key` | string | yes       | Matching secret access key                                            |
| `name_prefix`           | string |           | Prefix for the user and policy. Unique within the account             |
| `allowed_model_ids`     | string |           | Comma-separated model ids the credentials may invoke, or `*` for all  |

### Optional

| Name                           | Type   | Default     | Description                                                                    |
| ------------------------------ | ------ | ----------- | -------------------------------------------------------------------------------- |
| `aws_region`                   | string | `us-east-1` | Region Bedrock is called in. Model availability differs per region              |
| `allow_list_foundation_models` | bool   | `true`      | Also allow the read-only discovery calls most SDKs make before invoking         |
| `create_iam_user`              | bool   | `true`      | Create the IAM user and access key                                             |
| `attach_to_role_name`          | string |             | Existing IAM role to attach the policy to. Unset = attach to nothing           |

## Outputs

| Name                 | Sensitive | Description                                                    |
| -------------------- | --------- | ---------------------------------------------------------------- |
| `aws_region`         |           | Region the credentials call Bedrock in                          |
| `account_id`         |           | AWS account the access was created in                           |
| `policy_arn`         |           | Invoke policy ARN, for attaching to further principals          |
| `iam_user_name`      |           | IAM user holding the policy (empty when not created)            |
| `access_key_id`      | yes       | Set as `AWS_ACCESS_KEY_ID`                                      |
| `secret_access_key`  | yes       | Set as `AWS_SECRET_ACCESS_KEY`                                  |
| `bedrock_endpoint`   |           | Bedrock runtime endpoint, built from the partition DNS suffix   |
| `allowed_model_arns` |           | Model and inference profile ARNs the credentials may invoke     |

## Notes

- **Invocation logging is deliberately not managed here.** Bedrock keeps one logging configuration
  per account per region, so a per-service blueprint that owned it would overwrite whatever the
  account already had on create and remove logging for every other workload in that region on
  destroy. Configure it once at the account level instead
  (`aws_bedrock_model_invocation_logging_configuration` in your account baseline, or the console).
- **A cross-region model id is expanded to two ARNs.** Invoking `us.anthropic.claude-…` is
  authorized against both the inference profile in your account and the underlying foundation model
  in whichever region the request is routed to, so the foundation-model ARN is emitted with a region
  wildcard. Pinning it to `aws_region` would deny every cross-region invocation — which is how the
  Claude models are normally called.
- **`allowed_model_ids` is required, with no default.** `*` is accepted but has to be typed: it
  grants every foundation model in the account, including ones added after the key is issued. An
  empty or comma-only value is rejected rather than being treated as `*`.
- **The access key is long-lived.** It is surfaced as a sensitive output and stored encrypted by
  Qovery. Rotating it means tainting `aws_iam_access_key.app` and redeploying. Prefer
  `create_iam_user = false` plus `attach_to_role_name` wherever the workload already has an AWS
  identity.
- **`force_destroy` is set on the IAM user**, so destroying the blueprint removes the user together
  with the keys it still holds instead of failing.
- Guardrails, knowledge bases and provisioned throughput are out of scope: each is a substantial
  configuration of its own and belongs in its own blueprint.
