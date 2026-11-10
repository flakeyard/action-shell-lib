# shellcheck shell=bash
# Tests of github/api.sh: a missing resource is told from an error, and only
# errors that may pass on their own are retried.

lib=github/api.sh

# missing_is_not_found PATH: api_request returns NOT_FOUND for PATH.
missing_is_not_found() {
  local path=$1 status=0
  api_request GET "$path" || status=$?
  ((status == NOT_FOUND))
}

setup
fixture repos/o/r/thing '{"a":1}'
run_lib "api: a resource is printed" ok "$lib" api_get repos/o/r/thing
expect stdout '{"a":1}'
expect sleeps ""
finish

setup
run_lib "api: a missing resource fails api_get" fail "$lib" api_get repos/o/r/thing
expect message "repos/o/r/thing: Not Found (HTTP 404)"
finish

setup
run_lib "api: a missing resource is NOT_FOUND" ok "$lib" missing_is_not_found repos/o/r/thing
expect stdout ''
expect sleeps ""
finish

setup
fixture repos/o/r/thing "HTTP 500"
run_lib "api: a server error is an error" fail "$lib" api_request GET repos/o/r/thing
expect message "HTTP 500"
finish

setup
fixture repos/o/r/thing '{"a":1}'
transient_failures repos/o/r/thing 2
run_lib "api: a gateway timeout is retried with a growing delay" ok "$lib" \
  api_get repos/o/r/thing
expect stdout '{"a":1}'
expect sleeps "5 10"
finish

setup
fixture repos/o/r/thing '{"a":1}'
transient_failures repos/o/r/thing 3
run_lib "api: a gateway timeout fails after the last attempt" fail "$lib" \
  api_get repos/o/r/thing
expect message "HTTP 504"
expect sleeps "5 10"
finish

setup
transient_failures repos/o/r/thing 1
run_lib "api: a missing resource after a retry is NOT_FOUND" ok "$lib" \
  missing_is_not_found repos/o/r/thing
expect sleeps "5"
finish

setup
run_lib "api: arguments reach gh" ok "$lib" \
  api_request POST repos/o/r/statuses/aaa -f state=success
expect call "POST repos/o/r/statuses/aaa state=success"
finish

setup
apply FAIL_ON="PATCH repos/o/r/x 422"
run_lib "api: a client error is not retried" fail "$lib" api_request PATCH repos/o/r/x
expect message "HTTP 422"
expect sleeps ""
finish

setup
fixture "graphql?owner=o" '{"data":{"n":1}}'
transient_failures "graphql?owner=o" 1 rate-limited
run_lib "api: a GraphQL rate limit is retried" ok "$lib" \
  api_request POST graphql -f query='{ x }' -f owner=o
expect stdout '{"data":{"n":1}}'
expect sleeps "5"
finish

setup
run_lib "api: another GraphQL error is not retried" fail "$lib" \
  api_request POST graphql -f query='{ x }' -f owner=o
expect message "Could not resolve"
expect sleeps ""
finish

# with_failing_gh MESSAGE FUNCTION [ARG...]: run FUNCTION with a gh that
# always fails with MESSAGE on stderr and no HTTP status.
with_failing_gh() {
  local message=$1
  shift
  # shellcheck disable=SC2329 # called by api_request
  gh() {
    printf '%s\n' "$message" >&2
    return 1
  }
  "$@"
}

# Failures of gh without an HTTP status: MESSAGE|SLEEPS, where SLEEPS are the
# waits before each retry; none for a failure that does not pass on its own.
while IFS='|' read -r message sleeps; do
  setup
  run_lib "api: '$message' is tried ${sleeps:+again}${sleeps:-once}" fail "$lib" \
    with_failing_gh "$message" api_request GET repos/o/r/thing
  expect message "$message"
  expect sleeps "$sleeps"
  finish
done <<'CASES'
To get started with GitHub CLI, please run:  gh auth login|
unknown flag: --bogus|
bash: line 1: gh: command not found|
gh: Could not resolve to a Repository with the name 'o/r'.|
Get "https://api.github.com/x": dial tcp 140.82.112.6:443: i/o timeout|5 10
Get "https://api.github.com/x": net/http: TLS handshake timeout|5 10
Get "https://api.github.com/x": context deadline exceeded (Client.Timeout exceeded while awaiting headers)|5 10
Get "https://api.github.com/x": read tcp 10.1.0.4:5000->140.82.112.6:443: read: connection reset by peer|5 10
Get "https://api.github.com/x": dial tcp 140.82.112.6:443: connect: connection refused|5 10
Get "https://api.github.com/x": unexpected EOF|5 10
Get "https://api.github.com/x": dial tcp: lookup api.github.com: no such host|5 10
CASES
