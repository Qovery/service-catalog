# Shared helpers for the *-service-rc mise tasks. Sourced, not executed.
#
# POSIX sh only: mise runs task scripts with `sh`, which is dash on Debian/Ubuntu. `set -o
# pipefail` is a bashism that aborts there with "Illegal option", so callers use `set -eu` and
# nothing here relies on pipefail.

# auth_header <token>
#
# Qovery accepts two kinds of token and they use *different* schemes: a console JWT is sent as
# `Bearer`, an organization API token as `Token`. Sending the wrong one is a flat 401. The CLI
# decides by testing whether the first dot-segment is base64 (utils/context.go); a JWT always
# starts with `eyJ` (base64 of `{"`) and has three segments, which is the same test without
# needing a base64 binary. Override with QOVERY_AUTH_SCHEME=Bearer|Token if ever needed.
auth_header() {
  local _scheme
  _scheme="${QOVERY_AUTH_SCHEME:-}"
  if [ -z "$_scheme" ]; then
    case "$1" in
      eyJ*.*.*) _scheme="Bearer" ;;
      *) _scheme="Token" ;;
    esac
  fi
  printf 'Authorization: %s %s' "$_scheme" "$1"
}

# call_api <curl args...>
#
# Prints the response body (pretty-printed when it is JSON) and returns non-zero on HTTP >= 400.
# Deliberately not `curl --fail-with-body`: that needs curl 7.76+ (2021) and Ubuntu 20.04 ships
# 7.68, where an unknown option aborts before the request is sent.
call_api() {
  # `local` keeps these out of the caller's scope — update-service-rc calls this twice in one
  # shell. Not POSIX, but dash/bash/ash/ksh all support it, which covers every shell mise uses.
  local _out _code
  _out="$(mktemp)"
  # curl runs inside `if` so a transport failure (DNS, TLS, timeout) does not trip `set -e`
  # before the temp file is removed — otherwise every failed call leaks one.
  if ! _code="$(curl -sS -o "$_out" -w '%{http_code}' "$@")"; then
    rm -f "$_out"
    echo "request failed before a response was received" >&2
    return 1
  fi
  if command -v jq >/dev/null 2>&1 && jq -e . "$_out" >/dev/null 2>&1; then
    jq . "$_out"
  else
    cat "$_out"
  fi
  rm -f "$_out"
  if [ "$_code" -ge 400 ]; then
    echo "HTTP $_code" >&2
    return 1
  fi
}

# inject_tag <rc_tag> <payload_json>
#
# Sets `.tag` on the payload so the tag lives in exactly one place: the command line. Keeps the
# JSON about the service config and stops the two drifting apart.
inject_tag() {
  printf '%s' "$2" | jq --arg tag "$1" '.tag = $tag'
}
