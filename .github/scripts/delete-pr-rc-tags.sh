#!/usr/bin/env bash
set -euo pipefail

#   usage: delete-pr-rc-tags.sh <pr_number> [keep_suffix]
# keep_suffix is the generation to preserve: validate.yml passes it per push,
# pr-prerelease-cleanup.yml omits it to sweep everything when the PR closes.

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

# One push so a single rejection fails the job. The tag ruleset only excludes
# `refs/tags/**/*-rc` from its deletion rule; anything else is undeletable by GITHUB_TOKEN.
REFS=()
for tag in "${TAGS[@]}"; do
  echo "Deleting $tag"
  REFS+=(":refs/tags/$tag")
done

if ! git push "$REMOTE" "${REFS[@]}"; then
  echo "::error::Could not delete prerelease tags. Check that the repository tag ruleset still excludes 'refs/tags/**/*-rc' from its deletion rule."
  exit 1
fi
