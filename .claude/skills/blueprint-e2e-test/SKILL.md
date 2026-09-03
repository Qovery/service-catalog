---
name: blueprint-e2e-test
description: Deploy a blueprint end to end against a real test environment and prove the cloud resource was actually created. Covers both the new-deploy flow and the update-from-a-published-tag flow, which is the one that reveals a change that would replace or destroy live infrastructure. Use when verifying a blueprint change before merge, when a PR touches any qbm.yml or .tf file, or when asked to test, deploy or validate a blueprint for real rather than just running CI.
---

# Testing a blueprint end to end

CI only proves a blueprint parses and that its Terraform is internally valid. It never applies
anything. Every failure this repo has hit in practice — an undeclared engine-injected variable, a
`default: ""` the provider rejects — passes CI and fails at apply. The only way to know a blueprint
works is to deploy it.

`AGENTS.md` explains the prerelease tag mechanism. This skill is the procedure for using it.

## Before anything is created

**This provisions real, billed cloud infrastructure.** An RDS instance, a Cloudflare zone, a
MongoDB Atlas cluster. Confirm the target with the operator before the first call, and state what
you are about to create.

Needs `QOVERY_API_TOKEN` for the target org, plus `mise`, `jq` and `curl`. Set the shell up once;
every snippet below reuses these:

```sh
export QOVERY_API_TOKEN=...                        # token for the TARGET org
API="${QOVERY_API_URL:-https://api.qovery.com}"
ENVIRONMENT_ID=...

curl -s -H "Authorization: Token $QOVERY_API_TOKEN" \
  "$API/environment/$ENVIRONMENT_ID" | jq '{name, mode, cluster_name}'
```

Proceed only against a test organization in `DEVELOPMENT` mode. Never production.

## Pick the tag

- **Testing a PR's change** → the rc tag from the PR comment `pr-prerelease` posts, e.g.
  `AWS/postgres/17/3.1.0-pr45.a1b2c3d-rc`. It is regenerated on every push, and the previous one is
  deleted — a service pinned to a deleted tag can no longer be deployed, so re-read the comment
  after each push.
- **Needing a base that persists** → a published tag, e.g. `AWS/postgres/17/3.0.0`.
  `git ls-remote --tags origin 'refs/tags/AWS/postgres/17/*'`.

This is API-only. The Console's blueprint picker reads `catalog.json` from `main`, which has no rc
tags, so a blueprint under test never appears there. There is no `qovery` CLI path either.

## Build the payload

The PR comment pre-fills every variable that has a `default:` in **this branch's** `qbm.yml`.
Variables that are required with no default are deliberately left out and listed above the command
— add them by hand. For `AWS/postgres` those are `db_name`, `db_username` and `db_password`. Mark
**only** `db_password` with `"is_secret": true`; `db_name` and `db_username` are ordinary
identifiers, and flagging them diverges from the generated payload for no benefit. Set `is_secret`
from the variable's `sensitive: true` in `qbm.yml`, not from a guess.

**Create and update take different shapes for `variables`.** Get this wrong and the call is
rejected or silently patches nothing:

```jsonc
// deploy-service-rc -- a LIST of entries, each carrying its own name
"variables": [
  { "name": "db_name",     "value": "probedb" },
  { "name": "db_password", "value": "…", "is_secret": true }
]

// update-service-rc -- a merge-patch MAP keyed by name, only the keys you are changing.
// The value is an OBJECT, not a bare string.
"variables": {
  "instance_class": { "value": "db.t3.small" },
  "db_password":    { "value": "…", "is_secret": true }
}
```

`mise.toml` names this: `deploy-service-rc` takes `variables`, `update-service-rc` takes a
`variables patch map`. An empty `{}` is valid and normal for an update that only moves the tag.

If in doubt, copy the shapes straight out of the PR comment — `.github/workflows/validate.yml`
generates both from the same manifest, so they are correct by construction.

Two rules that are not optional:

- **Never send `"value": ""`.** The Qovery terraform provider rejects an empty variable value
  (`variable value is required`) while the engine applies the meta-module, and no service is ever
  created. Omit the variable instead — its `variables.tf` default applies.
- **Pick values that exercise the change.** Testing network discovery on an RDS blueprint means
  setting `multi_az = true`, because that is what forces the DB subnet group to span two AZs. A
  payload of minimal defaults proves the blueprint deploys, not that the change works.

Set teardown-friendly values up front where the blueprint offers them —
`deletion_protection = false`, `skip_final_snapshot = true` — or cleanup will fight you.

## Flow A — new deploy

```sh
TAG=AWS/postgres/17/3.1.0-pr45.a1b2c3d-rc     # from the PR comment
mise run deploy-service-rc "$ENVIRONMENT_ID" "$TAG" '<json, variables as a LIST>'
```

**This fails for every `EXTERNAL` blueprint** with:

```
Cannot chain deploy=true: credentialsMode=ENV requires cloud env vars to be populated on the service first.
```

The task posts `?deploy=true`, which q-core refuses for `credentialsMode=ENV` — which every
`EXTERNAL` blueprint uses, non-overridably. For those, split it into two calls:

```sh
# 1. create (no deploy chaining). The mise task injects the tag; here you add it yourself.
BLUEPRINT_ID=$(curl -s -X POST "$API/environment/$ENVIRONMENT_ID/blueprint" \
  -H "Authorization: Token $QOVERY_API_TOKEN" -H "Content-Type: application/json" \
  -d '{"name":"…","icon":"…","tag":"'"$TAG"'","variables":[…]}' | jq -r .id)

# 2. deploy it
curl -s -X POST "$API/blueprint/$BLUEPRINT_ID/deploy" -H "Authorization: Token $QOVERY_API_TOKEN"
```

AWS, GCP and SCW blueprints use cluster credentials and work with the mise task directly.

## Flow B — update from a published tag

This is the flow that reveals a change which would **replace or destroy** live infrastructure, and
it is the one bugs hide in. Creating a service directly at the tag under test diffs it against
itself and shows nothing.

```sh
# 1. create the throwaway on the currently PUBLISHED tag -- variables is a LIST.
#    The task echoes a "POST <url>" line before the body, so trim to the JSON
#    before parsing; piping it straight into jq fails on that first line.
BLUEPRINT_ID=$(mise run deploy-service-rc "$ENVIRONMENT_ID" AWS/postgres/17/3.0.0 '{
  "name": "rc-test-postgres-17",
  "icon": "app://qovery-console/postgresql",
  "variables": [
    { "name": "db_name",     "value": "probedb" },
    { "name": "db_username", "value": "probeuser" },
    { "name": "db_password", "value": "…", "is_secret": true },
    { "name": "multi_az",    "value": "true" }
  ]
}' | sed -n '/^{/,$p' | jq -r .id)

# 2. wait for it to finish -- see below; step 3 against a half-built service proves nothing

# 3. move that service to the tag under test -- variables is a MERGE-PATCH MAP.
#    {} keeps every value from step 1 and changes only the tag, which is what you
#    usually want: the diff then shows the blueprint change, not a config change.
mise run update-service-rc "$BLUEPRINT_ID" AWS/postgres/17/3.1.0-pr45.a1b2c3d-rc '{
  "name": "rc-test-postgres-17",
  "icon": "app://qovery-console/postgresql",
  "variables": {}
}'
```

`$BLUEPRINT_ID` is the `id` returned by step 1 — the blueprint id, not the service id. Passing the
service id gets you `Cannot find organization for Blueprint <id>`.

Read the plan in step 3 carefully. `Plan: N to add, 0 to change, 0 to destroy` on an *update* means
the change is additive. Any `to destroy`, or a `must be replaced`, is the finding — that is a
blueprint change that would take a customer's database with it.

You do not need to cut a temporary stable tag for this: the published tag is the base and it
persists. The exception is a **brand-new blueprint**, which has no published tag at all — its
update path cannot be tested until its first release, and saying so is a better answer than
inventing a base.

## Watching it, without being fooled

There are two phases and only the second one builds anything.

1. **Blueprint dispatch** — about 10 seconds. Creates the Qovery service. `latest_deployment.status`
   goes to `RUNNING` and `terminated_at` is set. **This is not the deploy finishing.**
2. **Terraform apply** — runs afterwards, as the linked service. Minutes. An RDS multi-AZ instance
   took 13m23s. The environment sits in `DEPLOYING` throughout.

Reading only the blueprint status makes a still-running deploy look finished.

```sh
# blueprint dispatch outcome + linked service id
curl -s -H "Authorization: Token $QOVERY_API_TOKEN" "$API/blueprint/$BLUEPRINT_ID" \
  | jq '{service_id, service_type, latest_deployment}'

# whether the environment is still working
curl -s -H "Authorization: Token $QOVERY_API_TOKEN" \
  "$API/environment/$ENVIRONMENT_ID/status" | jq '{state, last_deployment_state}'
```

`latest_deployment.error_message` carries the engine's actual failure text. That is where a
provider rejection surfaces.

**Do not wait on `environment/{id}/status.state`.** After you trigger a deploy the environment
keeps its *previous* terminal state for a while, so `state != DEPLOYING` reads as "finished" for a
deployment that has not started yet — and a stale `DEPLOYMENT_ERROR` from an earlier round looks
like your run failed. Wait on the deployment record instead:

Scope that to **your** service, not `.results[0]`. Each history record carries the services it
covers, so filter on the `service_id` instead of taking the newest deployment in the environment —
otherwise on a shared environment you are watching whatever somebody else deployed last:

```sh
while true; do
  S=$(curl -s -H "Authorization: Token $QOVERY_API_TOKEN" \
    "$API/environment/$ENVIRONMENT_ID/deploymentHistory" \
    | jq -r --arg svc "$SERVICE_ID" '
        [.results[] | select(any(.terraforms[]?; .id == $svc))][0] as $d
        | if $d == null then "NOT_IN_WINDOW"
          else ([$d.terraforms[] | select(.id == $svc) | .status][0] // "UNKNOWN") end')
  case "$S" in
    *QUEUED|DEPLOYING|BUILDING|DELETING|""|null) sleep 20 ;;
    *) echo "terminal: $S"; break ;;
  esac
done
```

Three details that matter, all of them observed rather than assumed:

- The entries are keyed `.terraforms[].id` — the service id directly. There is no
  `.identifier.service_id` here, unlike the per-service status blocks elsewhere in the API.
- Read the status off the **service** entry, not the record. They differ: a record reporting
  `DEPLOYED` at environment level had `DELETED` for the service that had just been torn down.
- The history window is finite and `pageSize` is ignored (asking for 3 returns 20), so a service
  whose deployment has aged out returns nothing. That is `NOT_IN_WINDOW` above, and it means "no
  longer visible", not "still running" — treat it as terminal-unknown rather than looping forever.

Use `.helms[]?` instead of `.terraforms[]?` for a Helm blueprint. There is no per-service
deployment-status endpoint, so this filter is the only way to scope the wait; a dedicated
environment avoids the problem entirely and is worth it if you have one.

The same aggregation applies to the environment-level state, which covers **every** service in the
environment. On a shared test environment a `DEPLOYMENT_ERROR` there is usually somebody else's
broken service; judge your own run by its scoped deployment status and its service logs, never by
the environment.

**Check the HTTP status, don't just `jq` the body.** This API answers an unknown route with
`404` and a JSON error object, so `jq '.results | length'` on it prints `0` and
`jq '{state}'` prints `null` — both look like a real "absent" answer and will send you chasing a
non-existent bug. Use `curl -o /dev/null -w '%{http_code}'`, or `curl -i`, whenever a result is
surprisingly empty.

These endpoints **do not exist** — reaching for them wastes time:
`/terraform/{id}/status`, `/terraform/{id}/deploymentStatus`,
`/environment/{id}/service/{id}/deploymentStatus`, `/environment/{id}/service/status`,
`/environment/{id}/terraform/status`.

To find the linked service id another way:
`GET /environment/{id}/terraform` (or `/helm`, per `service_type`) and match on `blueprint_id`.

## Prove the resource exists

A green status is not evidence. Read the terraform output from the service logs — Qovery MCP
`get_service_logs` with the environment id and the `service_id` from above — and assert on:

- `Terraform has been successfully initialized!` then `Success! The configuration is valid.`
- the plan line: `Plan: N to add, 0 to change, 0 to destroy`
- `Apply complete! Resources: N added, 0 changed, 0 destroyed.`
- data-source `Read complete` lines, and the resolved values of whatever the change touched — if
  you fixed subnet discovery, the subnet ids actually resolved are the finding, not the exit code

A failure at the provider with deliberately invalid credentials (`401`, `Unauthenticated`,
`request not authenticated`) still proves the blueprint itself is sound: it rendered, planned, and
reached the provider. That is a legitimate result when you have no real account for the service —
say "installs correctly, not usable" rather than claiming a green deploy.

### Then check the outputs reached the environment

The terraform outputs become environment variables named
`QOVERY_OUTPUT_TERRAFORM_Z<first 8 of the service id>_<OUTPUT NAME>`, split across two endpoints by
sensitivity — an output declared `sensitive: true` in `qbm.yml` becomes a secret, everything else a
plain variable. Both are `BUILT_IN`, and both are removed when the service is deleted:

```sh
SHORT="Z$(echo "$SERVICE_ID" | cut -c1-8 | tr a-z A-Z)"

# sensitive outputs (values are never returned)
curl -s -H "Authorization: Token $QOVERY_API_TOKEN" "$API/environment/$ENVIRONMENT_ID/secret" \
  | jq -r --arg s "$SHORT" '.results[] | select(.key|test($s)) | .key'

# plain outputs, with values
curl -s -H "Authorization: Token $QOVERY_API_TOKEN" \
  "$API/environment/$ENVIRONMENT_ID/environmentVariable" \
  | jq -r --arg s "$SHORT" '.results[] | select(.key|test($s)) | "\(.key) = \(.value)"'
```

`GET /environment/{id}/variable` does **not** exist — it 404s, and `jq` on that body reports zero
variables, which reads exactly like "the outputs were never created".

These land only once the deployment finishes, so an empty result on a still-running deploy means
nothing.

## Clean up — part of the test, not an afterthought

The throwaway is a live billing resource. Delete it, and name explicitly what was deleted.

Delete the **linked service**, not the blueprint: `/blueprint/{id}` only allows
`GET,HEAD,PATCH,OPTIONS`, so `DELETE` there returns `405` and destroys nothing. `DELETE` lives on
the service, which is what owns the terraform state:

```sh
# 202 Accepted — this queues a terraform destroy, it does not delete synchronously
curl -s -X DELETE "$API/terraform/$SERVICE_ID" -H "Authorization: Token $QOVERY_API_TOKEN"
```

`$SERVICE_ID` is the blueprint's `service_id` (use `/helm/{id}` when `service_type` is `HELM`).
Then wait for the teardown deployment to reach a terminal status with the `deploymentHistory` loop
above — a `202` only means the destroy was queued.

Then confirm all of:

- the service is gone from `GET /environment/$ENVIRONMENT_ID/terraform`
- `GET /blueprint/$BLUEPRINT_ID` returns `404` (deleting the service removes the blueprint record)
- its `QOVERY_OUTPUT_TERRAFORM_*` variables and secrets are gone from the two endpoints above
- the cloud provider console has nothing left behind — a final snapshot, a retained volume, a DNS
  zone. Without credentials for that account you cannot check this, so say so rather than implying
  the cloud side was verified.

If the PR merges or closes while a service is still pinned to one of its rc tags, that tag is
deleted and the service can no longer be deployed *or* cleanly torn down. Delete the throwaway
before closing the PR.
