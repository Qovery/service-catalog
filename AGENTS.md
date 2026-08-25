# AGENTS.md

Operating rules for agents (and humans) editing this repo. These mirror what CI enforces (`.github/workflows/`) — break them and the PR fails. Read this before touching any blueprint.

## What this repo is

A catalog of **blueprints** — pre-built definitions Qovery uses to provision cloud resources (Terraform/OpenTofu) and Kubernetes services (Helm). Each blueprint is a directory with a `qbm.yml` manifest plus its engine files. A generated `catalog.json` at the root is the machine-readable index the platform consumes.

## Directory layout — NON-NEGOTIABLE

```
{PROVIDER}/{service}/{software-major-version}/
```

- `PROVIDER` — `AWS`, `SCW`, `HELM` (Helm has no cloud provider).
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

Every PR opened by a **Qovery organization member** from a branch on this repo gets prerelease
tags for the blueprints it changed (fork PRs and outside collaborators are excluded — the job
checks `author_association`, not merely push access):
`{PROVIDER}/{service}/{major}/{metadata.version}-pr{PR}.{short_sha}-rc` (e.g.
`AWS/postgres/17/3.1.0-pr45.a1b2c3d-rc`). CI comments them on the PR once validation passes, with
a ready-to-run command per blueprint.

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
  deleted when the PR closes, and a service on a deleted tag cannot be deployed. To test the
  update path without risking anything, create a throwaway on the currently published tag first,
  then upgrade that — the PR comment renders both steps.
- **Pass variables from this branch's `qbm.yml`**, not main's. The Console's variable form is built
  from the catalog on `main` and will be wrong if the PR changed variables.

The tags are never released (`auto-tag` only releases tags pointing at `main`'s HEAD), and are
deleted when the PR closes. If the ruleset ever stops excluding `refs/tags/**/*-rc`, that cleanup
job fails loudly rather than leaving tags behind silently.

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
- `spec.engine.type` ∈ `terraform | opentofu | helm`; `terraform`/`opentofu` require a `version`; `helm` requires a `chart` `{repository, name, version}`.

Terraform blueprints are additionally `terraform init -backend=false && terraform validate`d (CI: `validate-terraform`).

## Keep `README.md` in sync with `qbm.yml`

Not CI-enforced, but expected on every PR: if a variable's `required` flag, default, type, or description changes in `qbm.yml`, update the matching row in `README.md`'s `## Variables` tables — including moving the row between the `### Required` table and its sizing/optional table when `required` flips. The `### Required` tables have no `Default` column; when a variable that still ships a `default:` in `qbm.yml` becomes required, fold that default into the description as "Default suggestion: `<value>`" rather than dropping it.

## PR title (CI: `pr-title`)

Must match: `feat|fix|patch|chore(<scope>): <message>` — e.g. `fix(redis): move off Bitnami chart`.

## Helm blueprint conventions

- **Do NOT use Bitnami charts** (`charts.bitnami.com/bitnami`). Bitnami moved its free Docker Hub images to `bitnamilegacy/` and deletes pinned tags → image pull fails → pods stick at "StatefulSet is not ready". Prefer a community chart that wraps the **official upstream image** (e.g. `groundhog2k/*`).
- Pin `chart.version` to the **latest published** chart version (check the repo's `index.yaml`). Note the chart's `appVersion` — it sets the software major and therefore the directory.
- Always set resource **requests and limits**; don't rely on chart defaults (they are often too low → OOM before readiness).
- Keep the `qbm.yml` variable contract stable across a software major when possible (rename = major bump).
- `values.yaml` is a template — user inputs are interpolated as `{{ variable_name }}`.

## Commit / PR messages

Keep them synthetic, for developers and SRE readers with no business context. Explain the _why_, not just the _what_.
