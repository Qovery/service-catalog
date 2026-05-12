# AWS S3 Bucket

Creates an S3 bucket with encryption, versioning, and public access block.

## Variables
| Name | Type | Required | Default | Description |
|------|------|----------|---------|-------------|
| bucket_name | string | yes | - | S3 bucket name (must be globally unique) |
| versioning | bool | no | true | Enable object versioning |
| encryption | bool | no | true | Enable AES-256 encryption |
| force_destroy | bool | no | false | Allow deletion with objects |

## Outputs
| Name | Description |
|------|-------------|
| bucket_arn | Bucket ARN |
| bucket_name | Bucket name |
| bucket_region | Bucket region |
