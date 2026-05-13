# Scaleway Object Storage Bucket

Creates a Scaleway Object Storage bucket with configurable ACL, versioning, and force-destroy options.

## Variables

| Name | Type | Required | Default | Description |
|------|------|----------|---------|-------------|
| `bucket_name` | string | yes | — | Bucket name (must be unique within region) |
| `acl` | string | no | `private` | Bucket ACL (private, public-read, public-read-write) |
| `versioning_enabled` | bool | no | `false` | Enable object versioning |
| `force_destroy` | bool | no | `false` | Allow bucket deletion even if it contains objects |

## Outputs

| Name | Description |
|------|-------------|
| `bucket_name` | Bucket name |
| `bucket_endpoint` | Bucket endpoint URL |
