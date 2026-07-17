# AWS S3 Bucket

Creates an S3 bucket with encryption, versioning, and public access block configured. The bucket name is automatically lowercased before creation.

## Variables

| Name            | Type   | Required | Sensitive | Default | Description                                                                                                                                                                                                                |
| --------------- | ------ | -------- | --------- | ------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `bucket_name`   | string | yes      |           | —       | Globally unique bucket name. Auto-lowercased. 3–63 chars; letters, digits, and hyphens only; must start and end with a letter or digit. Underscores, IP-address format, `xn--` prefix, and `-s3alias` suffix are rejected. |
| `versioning`    | bool   | no       |           | `true`  | Enable object versioning                                                                                                                                                                                                   |
| `encryption`    | bool   | no       |           | `true`  | Enable AES-256 server-side encryption                                                                                                                                                                                      |
| `force_destroy` | bool   | no       |           | `false` | Allow bucket deletion even if it contains objects                                                                                                                                                                          |
| `bucket_policy` | bool   | no       |           | `true` | Attach the default bucket policy                                                                                                                                                                                            |

## Outputs

| Name            | Description              |
| --------------- | ------------------------ |
| `bucket_arn`    | Bucket ARN               |
| `bucket_name`   | Bucket name (lowercased) |
| `bucket_region` | Bucket region            |

## Required AWS IAM permissions

The credentials used to deploy this blueprint must allow the actions below. Resource scope: `arn:aws:s3:::*` (bucket-level) and `arn:aws:s3:::*/*` (object-level, only needed when `force_destroy = true`).

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
        "s3:DeleteObjectVersion",
        "s3:ListBucketVersions"
      ],
      "Resource": "arn:aws:s3:::*/*"
    }
  ]
}
```
