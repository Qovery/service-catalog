#!/usr/bin/env bash
set -euo pipefail

# Delete a PR's prerelease tags from the remote.
#
#   usage: delete-pr-rc-tags.sh <pr_number> [keep_suffix]
#
# Two callers need this same filter, which is why it lives here rather than inline:
#   - validate.yml passes the current generation as keep_suffix, dropping the ones a new push
#     superseded;
#   - pr-prerelease-cleanup.yml passes no keep_suffix, dropping all of them when the PR closes.

PR="${1:?usage: delete-pr-rc-tags.sh <pr_number> [keep_suffix]}"
KEEP_SUFFIX="${2:-}"
REMOTE="${REMOTE:-origin}"

# Generated tags end in -pr{PR}.{short_sha}-rc. Match that whole shape, anchored: a published tag
# is free to contain "-pr${PR}." in its path or version and to end in -rc, and must survive.
PATTERN="-pr${PR}\.[0-9a-f]{7,40}-rc\$"

# A failed listing is not evidence of "no tags" — swallowing it would report success while leaving
# every tag behind, which is the exact failure this script exists to prevent.
if ! RAW=$(git ls-remote --tags "$REMOTE"); then
  echo "::error::Could not list remote tags for $REMOTE; refusing to report success without checking."
  exit 1
fi

# `--` before the pattern: it starts with '-', so grep would otherwise parse it as options and exit
# 2. With `|| true` swallowing that, the sweep would silently find nothing.
mapfile -t CANDIDATES < <(printf '%s\n' "$RAW" \
  | awk '{print $2}' \
  | sed 's|^refs/tags/||' \
  | grep -v -- '\^{}$' \
  | grep -E -- "$PATTERN" || true)

TAGS=()
if [ "${#CANDIDATES[@]}" -gt 0 ]; then
  for tag in "${CANDIDATES[@]}"; do
    [ -n "$tag" ] || continue
    # Suffix match, not `grep -F`: only a tag *ending* in the kept generation is the current one.
    if [ -n "$KEEP_SUFFIX" ] && [ "$tag" != "${tag%"$KEEP_SUFFIX"}" ]; then
      echo "Keeping $tag"
      continue
    fi
    TAGS+=("$tag")
  done
fi

if [ "${#TAGS[@]}" -eq 0 ]; then
  echo "No prerelease tags to delete for PR #${PR}."
  exit 0
fi

# Delete in one push so a single rejection fails the job. Without this the tags pile up silently:
# the repo's "Only admins can delete tags" ruleset covers ~ALL tags with no bypass actors, and only
# excludes `refs/tags/**/*-rc` — so a tag whose last segment does not end in `-rc` is undeletable
# by GITHUB_TOKEN.
REFS=()
for tag in "${TAGS[@]}"; do
  echo "Deleting $tag"
  REFS+=(":refs/tags/$tag")
done

if ! git push "$REMOTE" "${REFS[@]}"; then
  echo "::error::Could not delete prerelease tags. Check that the repository tag ruleset still excludes 'refs/tags/**/*-rc' from its deletion rule."
  exit 1
fi
