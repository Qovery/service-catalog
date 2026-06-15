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

## Required Scaleway IAM permissions

Scaleway IAM permissions are granted via **permission sets** on a policy attached to the application/user whose API key is used.

Attach a policy with the following permission sets, scoped to the target Project:

| Permission set               | Why                                                  |
| ---------------------------- | ---------------------------------------------------- |
| `ObjectStorageFullAccess`    | Create / read / update / delete the bucket, including ACL, versioning, and tags. |
| `ProjectReadOnly`            | Resolve the project context for the API call.       |

The minimum scope is the Project where Qovery deploys this blueprint. If your cluster has its own project, attach the policy there.

When `force_destroy = true`, the same `ObjectStorageFullAccess` set also covers object-level deletes during teardown.
