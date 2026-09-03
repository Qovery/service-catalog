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

```sh
curl -s -H "Authorization: Token $QOVERY_API_TOKEN" \
  "$API/environment/$ENVIRONMENT_ID" | jq '{name, mode, cluster_name}'
```

Proceed only against a test organization in `DEVELOPMENT` mode. Never production.

Needs `QOVERY_API_TOKEN` for the target org, plus `mise`, `jq` and `curl`.
`API` is `https://api.qovery.com` unless `QOVERY_API_URL` says otherwise.

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
— add them by hand. For `AWS/postgres` that is `db_name`, `db_username`, and `db_password` with
`"is_secret": true`.

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
mise run deploy-service-rc "$ENVIRONMENT_ID" "$TAG" '<json>'
```

**This fails for every `EXTERNAL` blueprint** with:

```
Cannot chain deploy=true: credentialsMode=ENV requires cloud env vars to be populated on the service first.
```

The task posts `?deploy=true`, which q-core refuses for `credentialsMode=ENV` — which every
`EXTERNAL` blueprint uses, non-overridably. For those, split it into two calls:

```sh
# 1. create (no deploy chaining) -- returns the blueprint id
curl -s -X POST "$API/environment/$ENVIRONMENT_ID/blueprint" \
  -H "Authorization: Token $QOVERY_API_TOKEN" -H "Content-Type: application/json" \
  -d '<json with "tag" included>' | jq -r .id

# 2. deploy it
curl -s -X POST "$API/blueprint/$BLUEPRINT_ID/deploy" -H "Authorization: Token $QOVERY_API_TOKEN"
```

AWS, GCP and SCW blueprints use cluster credentials and work with the mise task directly.

## Flow B — update from a published tag

This is the flow that reveals a change which would **replace or destroy** live infrastructure, and
it is the one bugs hide in. Creating a service directly at the tag under test diffs it against
itself and shows nothing.

```sh
# 1. create the throwaway on the currently PUBLISHED tag
mise run deploy-service-rc "$ENVIRONMENT_ID" AWS/postgres/17/3.0.0 '<json>'

# 2. wait for it to finish -- see below; step 3 against a half-built service proves nothing

# 3. move that service to the tag under test
mise run update-service-rc "$BLUEPRINT_ID" AWS/postgres/17/3.1.0-pr45.a1b2c3d-rc '<json>'
```

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

## Clean up — part of the test, not an afterthought

The throwaway is a live billing resource. Delete it, and name explicitly what was deleted.

```sh
curl -s -X DELETE "$API/blueprint/$BLUEPRINT_ID" -H "Authorization: Token $QOVERY_API_TOKEN"
```

Then confirm it is gone from `GET /environment/$ENVIRONMENT_ID/terraform`, and check the cloud
provider console for anything the delete left behind — a final snapshot, a retained volume, a DNS
zone.

If the PR merges or closes while a service is still pinned to one of its rc tags, that tag is
deleted and the service can no longer be deployed *or* cleanly torn down. Delete the throwaway
before closing the PR.
