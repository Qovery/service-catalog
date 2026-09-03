# Google BigQuery Dataset

Provisions a [BigQuery](https://cloud.google.com/bigquery) dataset (`google_bigquery_dataset`) and,
by default, a dedicated service account with a key (`google_service_account`,
`google_service_account_key`) plus the IAM bindings an application needs to query it, via the
official `hashicorp/google` provider (`~> 7.0`).

**Available on every cloud.** This is an `EXTERNAL` blueprint: it authenticates with a service
account key supplied as a variable, never with the cluster's own cloud identity, so it deploys the
same way from an AWS, Azure, Scaleway or GCP cluster. The generated key is what lets a workload
outside Google Cloud authenticate — there is no workload identity to fall back on there.

## Credentials

A Google **service account JSON key** in `gcp_service_account_key` (sensitive), supplied as a
variable (`credentials.default: env`). The account it belongs to needs:

| Role                          | Why                                                   |
| ----------------------------- | ------------------------------------------------------ |
| `roles/bigquery.admin`        | create the dataset and set dataset IAM                 |
| `roles/iam.serviceAccountAdmin` | create the application service account (`create_service_account = true`) |
| `roles/iam.serviceAccountKeyAdmin` | issue its key (`create_service_account = true`)   |
| `roles/resourcemanager.projectIamAdmin` | grant `roles/bigquery.jobUser` (`grant_job_user = true`, the default) |

Drop the last three by setting `create_service_account = false` and managing access yourself.

## Variables

### Required

| Name                      | Type   | Sensitive | Description                                                         |
| ------------------------- | ------ | --------- | -------------------------------------------------------------------- |
| `gcp_service_account_key` | string | yes       | JSON key Terraform authenticates as                                  |
| `gcp_project_id`          | string |           | Project the dataset is created in                                    |
| `dataset_id`              | string |           | Dataset id — letters, digits, underscores (`^[a-zA-Z0-9_]+$`, ≤1024) |

### Optional

| Name                              | Type   | Default                     | Description                                                                                     |
| --------------------------------- | ------ | --------------------------- | ------------------------------------------------------------------------------------------------ |
| `location`                        | string | `US`                        | Multi-region (`US`, `EU`) or region (`europe-west1`). Immutable — changing it recreates the dataset |
| `friendly_name`                   | string |                             | Display name. Empty = show the dataset id                                                        |
| `dataset_description`             | string |                             | Dataset description. Empty = none                                                                |
| `default_table_expiration_ms`     | number | `0`                         | Default table lifetime in ms. `0` = never expire; BigQuery rejects anything below `3600000`       |
| `default_partition_expiration_ms` | number | `0`                         | Default partition lifetime in ms. `0` = never expire                                             |
| `delete_contents_on_destroy`      | bool   | `false`                     | Allow destroying a dataset that still holds tables                                               |
| `create_service_account`          | bool   | `true`                      | Create the application service account and key                                                   |
| `service_account_id`              | string |                             | Leave empty — derived as `qovery-bq-<dataset>`. Set it only on a collision                        |
| `service_account_role`            | string | `roles/bigquery.dataEditor` | `dataViewer`, `dataEditor` or `dataOwner`, granted on the dataset                                |
| `grant_job_user`                  | bool   | `true`                      | Also grant `roles/bigquery.jobUser` on the project, without which the account cannot run a query  |

## Outputs

| Name                         | Sensitive | Description                                                        |
| ---------------------------- | --------- | ------------------------------------------------------------------- |
| `dataset_id`                 |           | Dataset id                                                          |
| `project_id`                 |           | Project the dataset lives in                                        |
| `location`                   |           | Dataset location                                                    |
| `dataset_reference`          |           | `project.dataset`, the form SQL and client libraries expect         |
| `self_link`                  |           | Dataset REST resource URI                                           |
| `service_account_email`      |           | Application service account email (empty when not created)          |
| `service_account_key_json`   | yes       | Key as raw JSON — for `GOOGLE_APPLICATION_CREDENTIALS` or a client  |
| `service_account_key_base64` | yes       | Same key base64-encoded, for a single-line environment variable     |

## Notes

- **`grant_job_user` is not optional in practice.** BigQuery splits data access from job creation:
  a dataset role lets the account read and write rows, but running a `SELECT` creates a job, which
  is a project-level right. Turning it off yields an account that fails every query with
  `Permission bigquery.jobs.create denied`.
- **The service account key must be a real key object.** The variable rejects any JSON that is not
  an object carrying `type: "service_account"`, `client_email` and `private_key`, so a wrong paste
  fails at variable resolution rather than as an opaque OAuth error minutes into the apply.
- **The service account key is a long-lived credential.** It is surfaced as a sensitive output and
  stored encrypted by Qovery. On a GCP cluster you can set `create_service_account = false` and use
  Workload Identity instead; on any other cloud the key is the only option.
- **`location` is immutable.** BigQuery cannot move a dataset, so a change here recreates it and
  destroys every table in it.
- **Destroy is guarded.** With `delete_contents_on_destroy = false` (the default) destroying the
  blueprint fails while the dataset still holds tables, rather than dropping them.
- Tables are deliberately out of scope: schemas belong with the application that owns them, and a
  blueprint variable cannot express one. Create them from your migration tooling against
  `dataset_reference`.
