# AGENTS.md

Operating rules for agents (and humans) editing this repo. These mirror what CI enforces (`.github/workflows/`) — break them and the PR fails. Read this before touching any blueprint.

## What this repo is

A catalog of **blueprints** — pre-built definitions Qovery uses to provision cloud resources (Terraform/OpenTofu) and Kubernetes services (Helm). Each blueprint is a directory with a `qbm.yml` manifest plus its engine files. A generated `catalog.json` at the root is the machine-readable index the platform consumes.

## Directory layout — NON-NEGOTIABLE

```
{PROVIDER}/{service}/{software-major-version}/
```

- `PROVIDER` — `AWS`, `SCW`, `GCP`, `AZURE`, `HELM` (Helm has no cloud provider), `EXTERNAL` (third-party services not tied to the cluster's cloud provider — Cloudflare, MongoDB Atlas, Kafka SaaS…; the console shows them for every cloud).
- `EXTERNAL` blueprints **must** use `credentials.default: env` and must not list `cluster` in `credentials.allowedValues` — there are no cluster cloud credentials to reuse. CI enforces this.
- `software-major-version` — the **major version of the software being deployed**, NOT the blueprint's semver. Examples: `AWS/postgres/17` (PostgreSQL 17), `HELM/redis/8` (Redis 8), `HELM/rabbitmq/4` (RabbitMQ 4), `AWS/s3/default` (no meaningful version → `default`).
- **A new software major = a new directory.** Bumping Redis 7 → 8 means creating `HELM/redis/8/`, not editing `HELM/redis/7/`. Do not repurpose an existing version dir for a different major.

Files per blueprint:

| File                                                       | Terraform / OpenTofu | Helm                            |
| ---------------------------------------------------------- | -------------------- | ------------------------------- |
| `qbm.yml`                                                  | required             | required                        |
| `main.tf` / `variables.tf` / `outputs.tf` / `providers.tf` | required             | —                               |
| `values.yaml`                                              | —                    | required (Helm values template) |
| `README.md`                                                | required             | required                        |

## `metadata.version` — MUST bump on every change (CI: `check-version-bump`)

- It is an **independent semver for the blueprint**, unrelated to the directory's software-major number. `HELM/rabbitmq/4` can be at `metadata.version: 2.0.0`.
- Any change to a blueprint's files **must** bump `metadata.version` vs `origin/main`, or CI fails.
  - **major** (`x.0.0`) — breaking: chart/provider swap, removed/renamed variable, incompatible default that forces recreation.
  - **minor** (`x.y.0`) — backward-compatible feature: new optional variable, new output.
  - **patch** (`x.y.z`) — fix / docs / non-behavioral.
- A brand-new blueprint directory starts at `1.0.0`.
- On merge to `main`, CI (`auto-tag`) creates a tag/release `{PROVIDER}/{service}/{major}/{metadata.version}` (e.g. `HELM/redis/8/1.0.0`).

### Testing a blueprint change before merge (CI: `pr-prerelease`)

Every PR whose branch lives on this repo gets prerelease tags for the blueprints it changed.
Pushing a branch here needs write access, which only Qovery org teams grant, so in practice that
means org members. Fork PRs are excluded — and GitHub makes their `GITHUB_TOKEN` read-only, so
they could not push a tag anyway:
`{PROVIDER}/{service}/{major}/{metadata.version}-pr{PR}.{short_sha}-rc` (e.g.
`AWS/postgres/17/3.1.0-pr45.a1b2c3d-rc`). CI comments them on the PR once validation passes, with
a ready-to-run command per blueprint.

A PR holds **one generation at a time**: each push tags its own head, then deletes the previous
push's tags and replaces the comment, so the only rc tags that exist are the ones the current
comment names. Anything pinned to an older tag stops being deployable at that point.

Two properties of that name matter:

- **The SHA** makes a tag identify its content — unique per commit, idempotent across workflow
  re-runs, never force-updated (which the tag ruleset forbids).
- **The `-rc` ending** is what makes cleanup possible. The ruleset excludes `refs/tags/**/*-rc`
  from its deletion rule, and fnmatch `*` does not cross `/`, so only a tag whose last segment
  ends in `-rc` can be deleted. `catalog-gen prerelease` rejects a suffix that does not.

To test one, run it against a **test organization** (needs `QOVERY_API_TOKEN`, `mise`, `jq`):

```sh
mise run deploy-service-rc $ENVIRONMENT_ID AWS/postgres/17/3.1.0-pr45.a1b2c3d-rc '<json>'
mise run update-service-rc $BLUEPRINT_ID   AWS/postgres/17/3.1.0-pr45.a1b2c3d-rc '<json>'
```

The tag is a separate argument and gets injected into the payload, so the JSON stays about the
service config and cannot drift from the tag under test. `deploy-service-rc` creates and deploys a
new service; `update-service-rc` repoints an existing one and redeploys it. The PR comment
pre-fills each payload with the blueprint's icon and required variables read from **this branch's**
`qbm.yml`.

This works because `tag` is a per-request field and q-core validates only its shape (4 segments,
`^[A-Za-z0-9_.-]+$`) before reading `qbm.yml` at that git ref — `catalog.json` is never consulted.

Two limits worth knowing:

- **This is API-only.** The Console's blueprint picker lists `catalog.json` from `main`, which has
  no rc tags, so the blueprint will not show up there. There is no `qovery` CLI path either — the
  CLI's `blueprint` commands are RDE-portal, a different feature.
- **`update-service-rc` is for throwaway services only.** It pins the service to an rc tag that is
  deleted by the next push to the PR (and on close), and a service on a deleted tag cannot be
  deployed — so re-run it with the tag from the refreshed PR comment after each push. Every push
  re-tags while the blueprint still differs from `main`, so a docs-only push still produces a new
  tag; only reverting the blueprint back to `main` leaves no rc tag at all. To test the update path
  without risking
  anything, create a throwaway on the currently published tag first, then upgrade that — the PR
  comment renders both steps.
- **Pass variables from this branch's `qbm.yml`**, not main's. The Console's variable form is built
  from the catalog on `main` and will be wrong if the PR changed variables.

The tags are never released (`auto-tag` only releases tags pointing at `main`'s HEAD). Deletion
happens twice: `pr-prerelease` sweeps the superseded generations on every push, and
`pr-prerelease-cleanup` sweeps the rest when the PR closes. Both call
`.github/scripts/delete-pr-rc-tags.sh` — the only difference is that the per-push call passes the
current generation as a keep-suffix. If the ruleset ever stops excluding `refs/tags/**/*-rc`,
either sweep fails loudly rather than leaving tags behind silently.

Two runs of `pr-prerelease` can overlap when pushes land in quick succession, so the job first
re-reads the PR head and does nothing at all if it has moved on — otherwise the older run would
delete the newer run's tags and comment.

To inspect locally without touching the repo:

```sh
catalog-gen prerelease --base-ref origin/main --suffix pr0.local-rc --dry-run
```

`--dry-run` writes no refs. `--no-push` is different: it **does** create the tags locally and only
skips the push, so the refs stay behind and a later run on the same commit reports
`already exists, skipping`. It prints the `git tag -d` lines to undo itself. On macOS, git's loose
refs are case-insensitive, so a local run can also collide with this repo's legacy lowercase tags
(`aws/...`); CI on Linux is unaffected.

### Retiring a blueprint major

`auto-tag` only ever _creates_ tags. To fully retire a major (e.g. Redis 7 → 8), use `mise run retire-blueprint <path>` (e.g. `HELM/redis/7`) — it removes the directory, regenerates `catalog.json` (staged for a PR), and deletes the tags + GitHub releases (applied immediately). It is DESTRUCTIVE and dry-run unless `CONFIRM=yes`. **Deleting a tag makes any service still pinned to it undeployable** (services reference the blueprint by immutable git tag and the engine re-fetches it on every deploy) — first check dependents (`SELECT * FROM blueprint WHERE tag LIKE '<path>/%'` in q-core) and migrate them.

## `catalog.json` — MUST be regenerated and committed (CI: `check-catalog`)

After any blueprint add/edit/remove:

```sh
mise run generate-catalog   # -> writes catalog.json
git add catalog.json
```

CI regenerates it and diffs (ignoring `generatedAt`); a stale `catalog.json` fails the build. Never hand-edit `catalog.json`.

## Manifest validation (CI: `validate-qbm`)

`catalog-gen validate` checks every `qbm.yml` against the schema and (for Terraform) that `qbm.yml` variables align with `variables.tf`. Key rules:

- **Sensitive variables:** any variable whose name matches `password|secret|token|api_key|access_key|private_key|credential` **must** be `sensitive: true` (or rename it). For Terraform blueprints, `qbm.yml` `sensitive` must equal `variables.tf` `sensitive = true`.
- Each Terraform `qbm.yml` variable must exist in `variables.tf`.
- **Engine-injected variables:** every Terraform blueprint must declare `region` and `qovery_cluster_name` in `variables.tf`. Missing either fails the build — see [Context variables](#context-variables--must-be-declared-ci-validate-qbm).
- `spec.engine.type` ∈ `terraform | opentofu | helm`; `terraform`/`opentofu` require a `version`; `helm` requires a `chart` `{repository, name, version}`.

Terraform blueprints are additionally `terraform init -backend=false && terraform validate`d (CI: `validate-terraform`).

## Keep `README.md` in sync with `qbm.yml`

Not CI-enforced, but expected on every PR: if a variable's `required` flag, default, type, or description changes in `qbm.yml`, update the matching row in `README.md`'s `## Variables` tables — including moving the row between the `### Required` table and its sizing/optional table when `required` flips. The `### Required` tables have no `Default` column; when a variable that still ships a `default:` in `qbm.yml` becomes required, fold that default into the description as "Default suggestion: `<value>`" rather than dropping it.

## PR title (CI: `pr-title`)

Must match: `feat|fix|patch|chore(<scope>): <message>` — e.g. `fix(redis): move off Bitnami chart`.

## Terraform blueprint conventions

### Context variables — MUST be declared (CI: `validate-qbm`)

The engine passes `region` and `qovery_cluster_name` as `-var` to **every** Terraform blueprint, on
every provider — including `EXTERNAL`, whose resources live outside Qovery entirely. Terraform
aborts when handed a `-var` the root module does not declare:

```
Error: Value for undeclared variable
A variable named "region" was assigned on the command line, but the root
module does not declare a variable of that name.
```

So every Terraform blueprint MUST declare both, in **both** files.

`qbm.yml` — a `contextVariables` block, sitting between `spec.engine` and `spec.variables`:

```yaml
  contextVariables:
    - name: "region"
      source: "cluster.region"
      overridable: true
    - name: "qovery_cluster_name"
      source: "cluster.name"
```

`variables.tf`:

```hcl
variable "qovery_cluster_name" {
  type        = string
  description = "Qovery cluster name, injected by the engine on every Terraform blueprint"
}

variable "region" {
  type        = string
  description = "Qovery cluster region, injected by the engine on every Terraform blueprint"
}
```

The resources do not have to reference either one. Declaring them is what satisfies the contract;
leaving them unused is fine and is what the `EXTERNAL` blueprints do.

`validate-qbm` fails the build when either declaration is missing from `variables.tf`, naming the
blueprint and the variable. It checks `variables.tf` rather than requiring a `contextVariables`
entry, because `variables.tf` is what terraform actually reads — a blueprint whose own
`spec.variables` already supplies `region` satisfies the check without declaring it twice.

That check exists because nothing used to catch this. `validate-qbm` walked `contextVariables` +
`variables` and required each to exist in `variables.tf`, which catches a *half*-finished job
(a `contextVariables` entry with no matching `variable` block) but knew nothing about what the
engine injects — so declaring **neither** was internally consistent and passed clean.
`validate-terraform` passed too, because the configuration on its own is valid. The failure surfaced
only at `terraform apply` against a live environment, and all nine `EXTERNAL` blueprints shipped and
stayed green in CI in exactly that state while every one of them was undeployable.

**Never name a user-facing variable `region`.** The engine sends its own `region` regardless, so a
user-facing one collides with it and the blueprint does not control which value wins. A
provider-specific region needs a provider-specific name — `confluent_region`, `planetscale_region`,
`region_code` — or it belongs in `contextVariables` with `overridable: true`, which is how a user
overrides the injected value.

## Helm blueprint conventions

- **Do NOT use Bitnami charts** (`charts.bitnami.com/bitnami`). Bitnami moved its free Docker Hub images to `bitnamilegacy/` and deletes pinned tags → image pull fails → pods stick at "StatefulSet is not ready". Prefer a community chart that wraps the **official upstream image** (e.g. `groundhog2k/*`).
- Pin `chart.version` to the **latest published** chart version (check the repo's `index.yaml`). Note the chart's `appVersion` — it sets the software major and therefore the directory.
- Always set resource **requests and limits**; don't rely on chart defaults (they are often too low → OOM before readiness).
- Keep the `qbm.yml` variable contract stable across a software major when possible (rename = major bump).
- `values.yaml` is a template — user inputs are interpolated as `{{ variable_name }}`.

### `values.yaml` templating — what the engine actually does

Rendered with **Tera** (`tera::Tera::default()`), so filters and control flow are available:
`{{ var | slugify }}`, `{% if var %}…{% else %}…{% endif %}`. Three things are not obvious:

- **Two variables are injected for free**, whether or not `qbm.yml` declares them:
  `qovery_cluster_name` (the Qovery cluster's own name, verbatim) and `region`. This is why the
  Terraform blueprints name their context variable `qovery_cluster_name` — the injection is keyed on
  that exact name, not on the `contextVariables` block, which only drives the console's form.
- **Cluster names are unconstrained** — q-core accepts any string, so `qovery_cluster_name` can
  carry uppercase, underscores or spaces and may not satisfy the chart's expectations. Pipe it
  through `slugify` when the chart needs RFC1123, and quote the result: a name that slugifies to
  `true` or `123` is otherwise parsed as a YAML bool or number.
- **An omitted optional variable is NOT filled in from `default:`.** The platform sends only the
  variables the client supplied, so `{{ var }}` for an omitted optional is *undefined* and the whole
  deployment fails while generating terraform files, before Helm runs. The error is
  `Failed to render 'values.yaml'` with no indication of which variable. Guard anything optional with
  `{% if var %}` or `| default(value=…)`. Note `default` covers undefined only — a client sending an
  empty string still yields an empty value, which is why `{% if %}` is the safer form. Tracked as
  QOV-2196.

## Commit / PR messages

Keep them synthetic, for developers and SRE readers with no business context. Explain the _why_, not just the _what_.

The PR title is CI-enforced and accepts **only** `feat`, `fix`, `patch`, `chore` (see [PR title](#pr-title-ci-pr-title)). The conventional-commit types you may reach for out of habit — `docs`, `refactor`, `test`, `ci`, `build`, `perf` — are all rejected. A docs-only or tooling-only change lands as `chore`.
