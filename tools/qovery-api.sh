# Shared helpers for the *-service-rc mise tasks. Sourced, not executed.
#
# POSIX sh only: mise runs task scripts with `sh`, which is dash on Debian/Ubuntu. `set -o
# pipefail` is a bashism that aborts there with "Illegal option", so callers use `set -eu` and
# nothing here relies on pipefail.

# call_api <curl args...>
#
# Prints the response body (pretty-printed when it is JSON) and returns non-zero on HTTP >= 400.
# Deliberately not `curl --fail-with-body`: that needs curl 7.76+ (2021) and Ubuntu 20.04 ships
# 7.68, where an unknown option aborts before the request is sent.
call_api() {
  _out="$(mktemp)"
  _code="$(curl -sS -o "$_out" -w '%{http_code}' "$@")"
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
