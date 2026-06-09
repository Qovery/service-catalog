# AWS S3 Bucket

Creates an S3 bucket with encryption, versioning, and public access block configured. The bucket name is automatically lowercased before creation.

## Variables

| Name            | Type   | Required | Sensitive | Default | Description                                                                                                                                                                                                                |
| --------------- | ------ | -------- | --------- | ------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `bucket_name`   | string | yes      |           | —       | Globally unique bucket name. Auto-lowercased. 3–63 chars; letters, digits, and hyphens only; must start and end with a letter or digit. Underscores, IP-address format, `xn--` prefix, and `-s3alias` suffix are rejected. |
| `versioning`    | bool   | no       |           | `true`  | Enable object versioning                                                                                                                                                                                                   |
| `encryption`    | bool   | no       |           | `true`  | Enable AES-256 server-side encryption                                                                                                                                                                                      |
| `force_destroy` | bool   | no       |           | `false` | Allow bucket deletion even if it contains objects                                                                                                                                                                          |

## Outputs

| Name            | Description              |
| --------------- | ------------------------ |
| `bucket_arn`    | Bucket ARN               |
| `bucket_name`   | Bucket name (lowercased) |
| `bucket_region` | Bucket region            |
