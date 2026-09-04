---
name: qbm-authoring
description: Author or edit a blueprint in this catalog — its qbm.yml manifest, the Terraform/OpenTofu files that back it (main.tf, variables.tf, outputs.tf, providers.tf), the Helm values.yaml template, and the variable descriptions the Console form shows the user. Encodes every rule CI enforces plus the ones it cannot see. Use when adding a new blueprint, changing a blueprint's variables, engine block, context variables or outputs, or when writing or reviewing a variable description.
---

# Authoring a blueprint

A blueprint is a directory holding `qbm.yml` plus the engine files it points at. `qbm.yml` is the
contract: it declares the form the user fills in, the engine that runs, and the cluster context the
platform injects. Everything the user sees in the Console comes from it, and every deploy failure
traceable to authoring comes from it disagreeing with the `.tf` files next to it.

`AGENTS.md` is the normative rule list and CI enforces most of it. This skill is the authoring
procedure: what to write, in what order, and how to word the parts CI cannot check.

## The filename is `qbm.yml`

Discovery globs on exactly `qbm.yml` (`discover_version_dirs` in `tools/catalog-gen/src/main.rs`).
A `qbm.yaml` is not an error — the directory is simply skipped, so the blueprint never enters
`catalog.json` and never appears in the Console. If a blueprint is "missing" with no CI failure,
check the filename first.

## Order of work

1. **Pick the directory.** `{PROVIDER}/{service}/{software-major-version}/` — nothing else parses.
2. **Write `variables.tf` first** for a Terraform blueprint. The `qbm.yml` variable block is a view
   over it, and CI compares them name by name. Writing the manifest first means rewriting it.
3. **Write `qbm.yml`.**
4. **Write the descriptions deliberately** — see [Variable descriptions](#variable-descriptions).
5. **Bump `metadata.version`.**
6. **Regenerate the catalog**, sync `README.md`, run the local validators.
7. **Deploy it for real** — CI never applies anything. Use the `blueprint-e2e-test` skill.

## Directory and file set

```
{PROVIDER}/{service}/{software-major-version}/
```

- `PROVIDER` ∈ `AWS`, `SCW`, `GCP`, `AZURE`, `HELM`, `EXTERNAL`. Anything else fails validation.
  Extending the list is a platform change (q-core `BlueprintIacProvider`), not a catalog change.
- `software-major-version` is the major of the **software being deployed**, not the blueprint's
  semver: `AWS/postgres/17`, `HELM/redis/8`, `AWS/s3/default` when there is no meaningful version.
- A new software major means a **new directory**. Never repurpose an existing one.

| File | Terraform / OpenTofu | Helm |
| --- | --- | --- |
| `qbm.yml` | required | required |
| `variables.tf` | required (CI reads it) | — |
| `main.tf`, `outputs.tf`, `providers.tf` | required | — |
| `values.yaml` | — | required |
| `README.md` | required | required |

`EXTERNAL` is for third-party services not tied to the cluster's cloud (Cloudflare, MongoDB Atlas,
Kafka SaaS). It has no cluster credentials to reuse, so it **must** use `credentials.default: env`
and **must not** list `cluster` in `credentials.allowedValues`.

## `qbm.yml` — Terraform / OpenTofu

```yaml
apiVersion: "qovery.com/v1"          # required; presence is checked, and every blueprint uses this
kind: ServiceBlueprint               # required (StackBlueprint needs spec.stages instead)

metadata:
  name: "aws-rds-postgresql"         # required; by convention kebab-case, provider-then-service
  displayName: "Amazon RDS for PostgreSQL" # optional; customer-facing label
  primaryCategory: "Databases & Caches" # required; controlled Console section
  version: "3.1.0"                   # required, blueprint semver — bump on EVERY change
  description: "..."                 # one line, shown in the Console picker
  icon: "app://qovery-console/postgresql"
  serviceFamily: "postgres"
  categories: ["database", "postgresql", "rds"]

spec:
  engine:
    type: terraform                  # terraform | opentofu | helm
    provider: AWS                    # MUST equal the top-level directory name
    terraform:                       # block name must match `type`
      version: "1.9.7"               # required; must be in allowedValues when that is set
      allowedValues: ["1.9.7", "1.13.3"]
      overridable: true              # defaults to false — opt in explicitly
    credentials:
      default: cluster               # cluster | env  (EXTERNAL: env only)
      allowedValues: ["cluster", "env"]
      overridable: true
    backend:
      default: qovery                # qovery | user_provided
      allowedValues: ["qovery", "user_provided"]
      overridable: true
    timeout: 3600                    # seconds
    resources:
      cpu: "500m"
      ram: "512Mi"

  contextVariables: [...]            # see below
  variables: [...]
  outputs: [...]
```

Rules CI checks on this block:

- `spec.engine.provider` must equal the directory. `catalog.json` takes the provider from the
  manifest while the manifest fetch path is built from the directory — a mismatch 404s in the
  Console.
- The version block is named after the engine type. A `terraform:` block under `type: opentofu`
  (or vice versa) is an error, as is either block under `type: helm`.
- `credentials.default` and `backend.default` must be in their universe *and* in their own
  `allowedValues` when that list is present.
- `backend.default: user_provided` requires a `backend.user_provided` block with a non-empty
  `type` (`s3`, `gcs`, `azurerm`, …).
- `overridable` defaults to `false` — fail-closed. If users must be able to change the value, say
  so explicitly.

### Catalog categories

`primaryCategory` is the single customer-facing section where the Console displays a blueprint.
Use exactly one of these values:

| Primary category | Use for |
| --- | --- |
| `Databases & Caches` | Relational, document, time-series, and in-memory data stores |
| `Storage` | Object storage |
| `Analytics` | Data warehouses and analytical datasets |
| `Messaging & Streaming` | Queues, brokers, Kafka, and event streams |
| `Compute & Runtime` | Serverless runtimes and durable workflow execution |
| `Networking & Edge` | DNS, CDNs, and traffic delivery |
| `Observability` | Monitoring, logs, tracing, and metrics |
| `AI` | AI model access and AI-specific infrastructure |

Do not use a provider name or engine type (`AWS`, `EXTERNAL`, `helm`, `terraform`) as a
primary category. Those describe how the blueprint is delivered, not the job a customer is trying
to do.

`categories` remains a list of flexible lowercase search/filter tags, such as
`["database", "postgresql", "rds"]`. Keep those tags specific and additive; do not put the
display section name in this list.

## `qbm.yml` — Helm

```yaml
spec:
  engine:
    type: helm
    chart:
      repository: "https://groundhog2k.github.io/helm-charts/"
      name: "redis"
      version: "2.4.1"               # pin to the latest published chart version
    arguments: []
    allowClusterWideResources: false
  variables: [...]
  outputs: [...]
```

- **No Bitnami charts** (`charts.bitnami.com/bitnami`). Bitnami moved its free Docker Hub images to
  `bitnamilegacy/` and deletes pinned tags, so pods stall at "StatefulSet is not ready". Prefer a
  community chart wrapping the **official upstream image** (e.g. `groundhog2k/*`).
- Check the repo's `index.yaml` for the latest chart version, and read its `appVersion` — that is
  what sets the software major and therefore the directory.
- Always set resource **requests and limits** in `values.yaml`. Chart defaults are usually too low
  and the pod OOMs before readiness.
- Keep the variable contract stable inside a software major. A rename is a major bump.

## Variable declarations

```yaml
  variables:
    - name: "db_name"                # must exist in variables.tf (terraform/opentofu)
      type: "string"                 # string | number | bool; omitted = string
      required: true
      sensitive: false
      default: "..."
      description: "..."
      allowedValues: [...]
      pattern: "^...$"               # string only
      minLength: 1                   # string only
      maxLength: 63                  # string only
      min: 1150                      # number only
      max: 65535                     # number only
```

### required vs default — and never `default: ""`

Two questions, in order:

1. **Must the caller always supply a value?** → `required: true`, no `default`. If a value has to be
   passed, the variable is not optional; do not fake it with an empty default.
2. **Otherwise it is optional and has a default.** Declare it (`default: "gp3"`) — *unless that
   default would be the empty string*, in which case **omit the `default:` line entirely** and say
   what unset means in the description.

Why: the Qovery Terraform provider rejects an empty variable value (`Variable.Validate()` returns
`variable value is required` for `Value == ""`, before any API call). q-core materialises a manifest
default into a real variable, so `default: ""` sends an empty-valued variable, the provider refuses
it while the engine applies the meta-module, and **no Terraform service is ever created**. This
holds on every provider, with any credentials mode. Helm blueprints interpolate `values.yaml`
instead and never reach that check — but the rule is uniform, so keep it.

**This is a `qbm.yml` rule only. Leave `variables.tf` alone.** `default = ""` there is correct and
must stay: it is read by the deployed Terraform job, a different execution from the one that
rejects. Omitting the variable falls back to that default and the usual
`count = var.record_name != "" ? 1 : 0` guard does the right thing. Deleting it makes the variable
required; `default = null` with `!= null` is worse, because `!= ""` also covers a value explicitly
set to empty.

`required: true` with a `default:` is legal and used for sizing knobs the user should confirm rather
than accept blindly (`instance_class`, `allocated_storage`). Note that the PR prerelease payload is
built from variables that have a `default:`, so this shape stays testable.

### Constraints — which ones are legal where

| Constraint | Legal on | CI rejects |
| --- | --- | --- |
| `pattern`, `minLength`, `maxLength` | `string` (or omitted type) | on `number` / `bool` |
| `min`, `max` | `number` | on `string` / `bool`; also `min > max` |
| `allowedValues` | `string`, `number` | on `bool`; also a `default` not in the list |
| `pattern` | must compile as a regex | invalid regex |

Constraints are enforced **server-side at deploy** (`BlueprintVariableValidation` in q-core checks
pattern, min/max, length, allowed values, required and sensitivity, and rejects unknown variable
names). They are not previewed in the Console input, so the user meets them as a rejection after
submitting — which is exactly why the description has to state them (below).

### Sensitive variables

Any variable whose name matches
`(^|_)(password|passwd|secret|token|credential|api[_-]?key|access[_-]?key|private[_-]?key)($|_)`
**must** carry `sensitive: true`, or be renamed. For Terraform blueprints the flag must match
`variables.tf` exactly in both directions: `sensitive = true` there without `sensitive: true` here
is an error, and so is the reverse. The Console renders a sensitive variable as a password input,
and q-core rejects a submitted sensitive variable that is not marked secret.

### `outputs`

`spec.outputs` mirrors `outputs.tf` (name + description, `sensitive: true` where relevant). Nothing
validates it, and q-core's manifest model ignores it — it feeds the auto-generated GitHub release
notes. Keep it in sync anyway: it is the only place a reader sees what the blueprint hands back.

## Variable descriptions

**There is exactly one text field: `description`. There is no `hint`.** q-core's manifest model
(`BlueprintManifest.Variable`) carries `description` only, and the Console renders it *as* the
field's hint (`hint={field.description}`). The YAML parser runs with
`FAIL_ON_UNKNOWN_PROPERTIES=false`, so a `hint:` key parses without complaint and is **silently
dropped** — it never reaches the form. Do not write one.

Where the text actually surfaces:

| Variable shape | Console rendering | Description shown? |
| --- | --- | --- |
| `string` / `number` | text input | yes, as hint text under the field |
| `bool` | toggle | yes, as the toggle's description |
| any type with `allowedValues` | dropdown | **no** — the description is dropped entirely |

So for an `allowedValues` variable the description exists for the README and the release notes only.
Do not spend a sentence there explaining which values are allowed: the dropdown is the list.

Two more constraints on length: the release-note generator truncates every description at 80
characters (`truncate_description`), and the field is read in a form, mid-task, by someone deciding
whether they have to type anything. Both push the same way — the decisive information goes first.

### What a description is for

One or two sentences, in this order, and nothing else:

1. **The decision the reader has to make** — what the value controls, or (for an optional variable)
   what happens if they leave it alone.
2. **Only the constraints that would make their input fail**, stated once.

### Lead with what unset does

An optional variable's description is read by someone deciding whether they must fill the field.
Put that answer first.

**When Qovery derives the value, open with "Leave empty".** The field is an escape hatch, not an
input:

```yaml
description: "Leave empty — derived from the Qovery cluster's workers security group. Set it
  (comma-separated ids) only on a cluster with a user-provided VPC, where that lookup finds nothing."
```

Not `"Optional comma-separated security group ids override. Empty = the Qovery cluster workers
security group."` — same facts, but it opens by implying the value is wanted and buries the default
at the end, so the field reads as required. That wording had people supplying security group ids by
hand on clusters where the lookup already worked.

**When the *provider* picks the default, keep the plain form** — `"… Empty = AWS default."`,
`"Unset = create no record"`. "Leave empty" would overclaim: nothing on the Qovery side is deriving
anything, and empty may not be the right choice for that blueprint.

**When Qovery generates the value, say so and say what it generates:**

```yaml
description: 'Leave empty and Qovery generates a 32-character alphanumeric password. To set your
  own: 8–128 chars, must not contain /, @, ", or spaces.'
```

The distinction is who fills the gap, not whether the variable is optional. Both kinds are optional.

### Which constraints earn a sentence

Include a constraint only when a wrong value would be **rejected or would silently misbehave**, and
the reader could not have guessed it:

- **Yes** — character classes and forbidden characters (`letters, digits, underscores; must start
  with a letter`, `hyphens are not allowed`), length limits, reserved names the provider refuses
  (`admin`, `rdsadmin`, anything starting with `pg_`), value shapes (`format
  ddd:hh24:mi-ddd:hh24:mi`), cross-variable requirements (`Required when monitoring_interval > 0`,
  `Requires backup_retention_period > 0`), and the fact that a knob only applies in some
  configuration (`Only meaningful with io1/io2 (always) or gp3 (≥400 GiB)`).
- **No** — anything the form already shows (the `allowedValues` dropdown), the variable's own type,
  restating the name, or the resource attribute it maps to.

Whatever you state must **agree with the machine-readable constraints on the same variable**. A
description saying "max 63 chars" next to `maxLength: 128` is worse than no description: the user
trusts the prose and the API rejects the value.

### Anti-patterns

| Anti-pattern | Example | Fix |
| --- | --- | --- |
| Restating the name | `bucket_name: "The name of the bucket"` | Say what makes a *valid* one, or drop the field to the constraints only. |
| Saying the same thing twice | `"Database port. The port used by the database (RDS reserves ports below 1150)."` | One clause: `"Database port (RDS reserves ports below 1150)"`. |
| Opening with "Optional." | `"Optional. Instance class for read replicas…"` | The form already shows it is optional. Open with what unset does: `"Empty = same as the primary."` |
| Contradicting a constraint | prose `"max 63 chars"` with `maxLength: 128` | Make the prose follow the constraint, or fix the constraint. |
| Listing `allowedValues` in prose | `"EBS storage type: gp2, gp3, io1, io2"` | The dropdown is the list, and the description is not even rendered. Write `"EBS storage type"`. |
| Describing implementation | `"Passed to aws_db_instance.allocated_storage"` | Describe the effect: `"Allocated storage in GiB"`. |
| Selling the feature | `"Improve performance with powerful read replicas!"` | State the mechanism and the cost: `"Number of same-region read replicas (0 disables; max 15). Requires backup_retention_period > 0."` |
| Burying the escape hatch | `"…override. Empty = the cluster's security group."` | Lead with `"Leave empty — derived from …"`. |

### Worked examples

```yaml
# Required, with provider rules the user cannot guess. Constraints stated once, mirrored by
# pattern/minLength/maxLength.
- name: "db_name"
  type: "string"
  required: true
  description: "PostgreSQL database name. Letters, digits, underscores only; must start with a letter; max 63 chars. Hyphens are not allowed."
  pattern: "^[a-zA-Z][a-zA-Z0-9_]{0,62}$"
  minLength: 1
  maxLength: 63

# Optional, Qovery-derived. "Leave empty" first, then the one case where the user must act.
- name: "db_subnet_group_name"
  type: "string"
  required: false
  description: "Leave empty — derived from the Qovery cluster's DB subnet group. Set it only on a cluster with a user-provided VPC, where that lookup finds nothing."

# Optional, provider-defaulted. Plain form, no "leave empty".
- name: "option_group_name"
  type: "string"
  required: false
  description: "Optional option group name. Empty = AWS default."

# allowedValues: the dropdown is the documentation. One short phrase.
- name: "storage_type"
  type: "string"
  required: false
  default: "gp3"
  description: "EBS storage type"
  allowedValues: ["gp2", "gp3", "io1", "io2"]

# Conditional knob: say when it applies and what the neutral value does.
- name: "disk_iops"
  type: "number"
  required: false
  default: "0"
  description: "Provisioned IOPS. Only meaningful with io1/io2 (always) or gp3 (≥400 GiB). 0 lets AWS choose the default."
  min: 0
  max: 256000
```

### The same sentence lives in three places

`qbm.yml` `description`, the `variables.tf` `description`, and the `README.md` variable row must
state the same facts. Wording may compress — the `variables.tf` line can be shorter, since its
reader is looking at the `validation` blocks right below it — but they must not disagree.

## `contextVariables` — declare what you consume

`spec.contextVariables` decides which cluster context q-core resolves and sends. A blueprint
receives exactly the sources it declares, nothing more:

```yaml
  contextVariables:
    - name: "region"
      source: "cluster.region"
      overridable: true
    - name: "qovery_cluster_name"
      source: "cluster.name"
    - name: "qovery_cluster_id"
      source: "cluster.id"
```

| `source` | fills |
| --- | --- |
| `cluster.region` | the declared name, with the cluster's region (Scaleway zones reduce to a region) |
| `cluster.name` | the declared name, with the cluster's name verbatim |
| `cluster.id` | the declared name with the cluster **short id** (`z` + first 8 of the uuid), **and** `qovery_cluster_long_id` with the uuid |

- One entry per context input, not one per Terraform variable — `cluster.id` covers both id forms,
  because a module needing the cluster identity needs both.
- An entry with no `source`, or an unknown `source`, is a build error. This is checked for every
  engine type, Helm included.
- For Terraform, everything a source fills must be declared in `variables.tf` **without a
  `default`**. `qovery_cluster_id` once shipped with `default = ""`; nothing injected it, the empty
  string flowed into the VPC and security-group lookups, and the deploy failed with `no matching EC2
  VPC found` — three repos from the cause, a whole minor release later. With no default, a missing
  injection fails at variable resolution and names the variable.
- A resource does not have to reference a declared context variable. Declaring it is what satisfies
  the contract; leaving it unused is fine.
- **A user-facing `region` is allowed only if the blueprint does not declare `cluster.region`.**
  `EXTERNAL/confluent-kafka` and `EXTERNAL/planetscale` do that: their `region` is a provider slug
  of their own (`us-east` is not an AWS region). Declaring both puts two writers on one variable and
  the blueprint does not control which wins. If you need both, give the user-facing one a
  provider-specific name (`confluent_region`) or mark the context entry `overridable: true`.
- Adding a new `source` means changing three places: q-core's `BlueprintContextResolver`,
  `source_targets` in `tools/catalog-gen`, and the table above.

## Terraform file conventions

`providers.tf` — pin `required_version` and every provider, and let the engine supply credentials:

```hcl
terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" {
  region = var.region
  # Credentials injected by the engine from cluster config.
}
```

An `EXTERNAL` blueprint has no cluster credentials, so its provider block reads them from declared
sensitive variables (`var.atlas_public_key`, `var.atlas_private_key`) which the user supplies.

`variables.tf` — two sections, Qovery context first, user inputs second. Context variables carry no
default (see above). User inputs carry `validation` blocks with error messages that repeat the rule
in plain words, because that message is what a failed apply shows:

```hcl
variable "bucket_name" {
  description = "S3 bucket name (must be globally unique, 3–63 chars, letters/digits/hyphens only — automatically lowercased)"
  type        = string

  validation {
    # Underscores, spaces, and other special chars are forbidden even after lowercasing.
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", lower(var.bucket_name)))
    error_message = "bucket_name must contain only letters, digits, and hyphens, and must start and end with a letter or digit. Underscores are not allowed."
  }
}
```

A `validation` block can express things `pattern` cannot (`startswith`, `endswith`,
cross-variable conditions). Cross-variable validation needs Terraform 1.9+, so pin
`spec.engine.terraform.version` accordingly.

`main.tf` — tag every resource that supports tags with the Qovery context, so cost reporting and
identification match native managed services:

```hcl
  tags = {
    ManagedBy   = "terraform"
    Service     = "s3"
    ClusterName = var.qovery_cluster_name

    cluster_id      = var.qovery_cluster_id
    cluster_long_id = var.qovery_cluster_long_id
    region          = var.region
  }
```

`outputs.tf` — every output gets a `description`, and anything secret gets `sensitive = true`. Mirror
the list in `spec.outputs`. Where a value only exists in some configurations, say so in the
description (`"Read replica endpoints (empty when read_replica_count = 0)"`) rather than leaving the
reader to discover an empty string.

**Keep the network override variables.** `db_subnet_group_name`, `security_group_ids` and
`subnet_ids` look derivable, and the tag lookups do derive them on a Qovery-managed network. They
are the only escape hatch on a **user-provided** network: the engine creates no worker security
group there and tags no VPC with `ClusterId`, so both lookups resolve to nothing. Removing them
makes those clusters undeployable with no remedy.

## `values.yaml` templating (Helm)

Rendered with Tera (`tera::Tera::default()`), so filters and control flow are available:
`{{ var | slugify }}`, `{% if var %}…{% else %}…{% endif %}`. Three non-obvious rules:

- **Cluster context must be declared, exactly like a Terraform blueprint.** A
  `{{ qovery_cluster_name }}` resolves only if `qbm.yml` declares the matching `contextVariables`
  entry. Tera aborts the render on the first unresolved placeholder, so an undeclared one breaks the
  deploy rather than rendering empty.
- **Cluster names are unconstrained.** q-core accepts any string, so `qovery_cluster_name` may carry
  uppercase, underscores or spaces. Pipe it through `slugify` when the chart needs RFC1123, and
  quote the result — a name that slugifies to `true` or `123` is otherwise parsed as a YAML bool or
  number.
- **An omitted optional variable is NOT filled in from `default:`.** The platform sends only the
  variables the client supplied, so `{{ var }}` for an omitted optional is *undefined* and the whole
  deployment fails while generating Terraform files, before Helm runs. The error is
  `Failed to render 'values.yaml'` with no indication of which variable. Guard anything optional with
  `{% if var %}` or `| default(value=…)`. `default` covers undefined only — a client sending an empty
  string still yields an empty value, which is why `{% if %}` is the safer form. (QOV-2196.)

## Version bump, catalog, README

- **`metadata.version` must be bumped on every change** to a blueprint's files, or
  `check-version-bump` fails against `origin/main`. It is an independent semver, unrelated to the
  directory's software-major number.
  - **major** — breaking: chart or provider swap, removed or renamed variable, an incompatible
    default that forces recreation.
  - **minor** — backward-compatible: new optional variable, new output.
  - **patch** — fix, docs, non-behavioural.
  - A brand-new blueprint directory starts at `1.0.0`.
- **Regenerate the catalog** after any add, edit or removal, and commit it. Never hand-edit
  `catalog.json`.
  ```sh
  mise run generate-catalog
  git add catalog.json
  ```
- **Keep `README.md` in sync.** Not CI-enforced but expected on every PR: if a variable's `required`
  flag, default, type or description changes, update the matching row in the `## Variables` tables —
  including moving it between the `### Required` table and the optional/sizing one when `required`
  flips. The `### Required` tables have no `Default` column, so a variable that still ships a
  `default:` while being required folds it into the description as "Default suggestion: `<value>`"
  rather than dropping it.
- **PR title** must match `feat|fix|patch|chore(<scope>): <message>`. `docs`, `refactor`, `test`,
  `ci`, `build` and `perf` are all rejected — a docs-only or tooling-only change lands as `chore`.

## Verify

There is no mise task for validation — CI runs `catalog-gen validate --root .` from a binary it
builds out of the PR's own source. Locally, run the same thing through cargo:

```sh
# schema + qbm.yml ↔ variables.tf contract; prints "OK: <path>" per blueprint
cargo run --release --manifest-path tools/catalog-gen/Cargo.toml -- validate --root .

terraform -chdir=AWS/postgres/17 init -backend=false
terraform -chdir=AWS/postgres/17 validate

mise run generate-catalog && git diff --stat catalog.json
```

Common validator messages and what they mean:

| Message | Cause |
| --- | --- |
| `'x' declared in qbm.yml but not in variables.tf` | Manifest variable with no Terraform declaration. |
| `source 'cluster.id' fills 'qovery_cluster_long_id' but variables.tf does not declare it` | `cluster.id` fills two variables; declare both. |
| `'x' is filled by source '…', so it must not have a default in variables.tf` | Remove the default so a missing injection fails loudly. |
| `'x' name looks sensitive — add sensitive: true` | Name matches the sensitive pattern. Add the flag or rename. |
| `spec.engine.provider 'AWS' does not match top-level directory 'SCW'` | Manifest and directory disagree; the Console would 404. |
| `EXTERNAL blueprints require spec.engine.credentials.default = env` | No cluster credentials exist for `EXTERNAL`. |

## What none of this proves

CI only proves the blueprint parses and its Terraform is internally valid. It never applies
anything. Every failure this repo has hit in practice — an undeclared engine-injected variable, a
`default: ""` the provider rejects, a `values.yaml` render on an omitted optional — passes CI and
fails at apply. Before merging, deploy the blueprint against a test organization using the
`blueprint-e2e-test` skill, and test **both** the new-deploy flow and the update-from-a-published-tag
flow: the second one is what reveals a change that would replace or destroy live infrastructure.
