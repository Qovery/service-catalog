# AWS S3 Bucket

Creates an S3 bucket with encryption, versioning, and public access block configured. The bucket name is automatically lowercased before creation.

## Variables

| Name            | Type   | Required | Sensitive | Default | Description                                                                                                                                                                                                                |
| --------------- | ------ | -------- | --------- | ------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `bucket_name`   | string | yes      |           | —       | Globally unique bucket name. Auto-lowercased. 3–63 chars; letters, digits, and hyphens only; must start and end with a letter or digit. Underscores, IP-address format, `xn--` prefix, and `-s3alias` suffix are rejected. |
| `versioning`    | bool   | no       |           | `true`  | Enable object versioning                                                                                                                                                                                                   |
| `encryption`    | bool   | no       |           | `true`  | Enable AES-256 server-side encryption                                                                                                                                                                                      |
| `force_destroy` | bool   | no       |           | `false` | Allow bucket deletion even if it contains objects                                                                                                                                                                          |
| `bucket_policy` | bool   | no       |           | `true`  | Enforce TLS: attach a bucket policy that denies plain HTTP requests                                                                                                                                                        |

## Outputs

| Name            | Description              |
| --------------- | ------------------------ |
| `bucket_arn`    | Bucket ARN               |
| `bucket_name`   | Bucket name (lowercased) |
| `bucket_region` | Bucket region            |

## Upgrading to 1.2.0

`bucket_policy` defaults to `true`, so upgrading an existing bucket attaches the TLS policy. S3 holds a single policy per bucket: this one **replaces** any policy attached outside the blueprint. Preview the update before applying it (the plan shows `aws_s3_bucket_policy.this[0]` being created), and set `bucket_policy = false` if the bucket relies on a policy managed elsewhere. Setting it to `false` after the policy was replaced deletes the policy; it does not restore the previous one.

## Assuming an IAM role

Optional. Set the blueprint's `role_arn` override (`spec_overrides.role_arn`; the blueprint opts in through `spec.engine.roleArn`) to make it assume an IAM role instead of using the configured credentials directly; leave it unset to use them as is.

- Format: `arn:aws:iam::<account-id>:role/<name>`.
- The role must be in the **same AWS account** as the credentials; cross-account roles are not supported.
- The deploy credentials need `sts:AssumeRole` on that role, **and** the role's trust policy must allow the deploy credentials' IAM principal to assume it. Without both, the deployment fails with `AccessDenied`.
- The role itself must carry the permissions listed in [Required AWS IAM permissions](#required-aws-iam-permissions).

## Required AWS IAM permissions

> When the `role_arn` override is set, Terraform makes these AWS calls as the assumed role, so the permissions below belong to that role; the deploy credentials then only need `sts:AssumeRole` on it (see [Assuming an IAM role](#assuming-an-iam-role)).

Unless the `role_arn` override is set, the credentials used to deploy this blueprint must allow the actions below. Resource scope: `arn:aws:s3:::*` (bucket-level) and `arn:aws:s3:::*/*` (object-level, only needed when `force_destroy = true`).

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:CreateBucket",
        "s3:DeleteBucket",
        "s3:ListBucket",
        "s3:ListBucketVersions",
        "s3:GetBucketLocation",
        "s3:GetBucketVersioning",
        "s3:PutBucketVersioning",
        "s3:GetEncryptionConfiguration",
        "s3:PutEncryptionConfiguration",
        "s3:GetBucketPublicAccessBlock",
        "s3:PutBucketPublicAccessBlock",
        "s3:GetBucketTagging",
        "s3:PutBucketTagging",
        "s3:GetBucketPolicy",
        "s3:PutBucketPolicy",
        "s3:DeleteBucketPolicy",
        "s3:GetBucketAcl",
        "s3:GetBucketCORS",
        "s3:GetBucketWebsite",
        "s3:GetBucketLogging",
        "s3:GetLifecycleConfiguration",
        "s3:GetReplicationConfiguration",
        "s3:GetAccelerateConfiguration",
        "s3:GetBucketRequestPayment",
        "s3:GetBucketObjectLockConfiguration",
        "s3:GetBucketOwnershipControls"
      ],
      "Resource": "arn:aws:s3:::*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:DeleteObject",
        "s3:DeleteObjectVersion"
      ],
      "Resource": "arn:aws:s3:::*/*"
    }
  ]
}
```
