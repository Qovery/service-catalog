# Scaleway Object Storage Bucket

Creates a Scaleway Object Storage bucket with configurable ACL, versioning, and force-destroy options. The bucket name is automatically lowercased before creation. Bucket names are globally unique across all Scaleway regions.

## Variables

| Name                 | Type   | Required | Sensitive | Default   | Description                                                                                                                                                          |
| -------------------- | ------ | -------- | --------- | --------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `bucket_name`        | string | yes      |           | —         | Globally unique bucket name. Auto-lowercased. 3–63 chars; letters, digits, and hyphens only; must start and end with a letter or digit. Underscores are not allowed. |
| `acl`                | string | no       |           | `private` | Bucket ACL: `private`, `public-read`, or `public-read-write`.                                                                                                        |
| `versioning_enabled` | bool   | no       |           | `false`   | Enable object versioning                                                                                                                                             |
| `force_destroy`      | bool   | no       |           | `false`   | Allow bucket deletion even if it contains objects                                                                                                                    |

## Outputs

| Name              | Description              |
| ----------------- | ------------------------ |
| `bucket_name`     | Bucket name (lowercased) |
| `bucket_endpoint` | Bucket endpoint URL      |
