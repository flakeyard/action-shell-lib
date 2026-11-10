# shellcheck shell=bash
# Calls of the GitHub API through the gh on PATH, which tell a missing
# resource from an error and retry errors that may pass on their own.

# Sourcing this file twice, also through other modules, defines its read-only
# constants once. A variable of the environment with the same name is not
# read-only, and the constant replaces it.
[[ $(declare -p NOT_FOUND 2>/dev/null) != "declare -r"* ]] || return 0

# Status of api_request when the resource does not exist (HTTP 404).
readonly NOT_FOUND=3
# Attempts of a request that fails in a way that may pass on its own, and the
# seconds to wait before the second one, doubled before each next one.
readonly _API_ATTEMPTS=3
readonly _API_RETRY_DELAY=5
# Errors of gh that may pass on their own: a server error, a rate limit or a
# lost connection, and the GraphQL rate limit, which gh prints with HTTP 200.
readonly _API_TRANSIENT_ERROR='HTTP (5[0-9][0-9]|429)|timeout|connection reset|unexpected EOF'
readonly _API_TRANSIENT_GRAPHQL_ERROR='"type": *"RATE_LIMITED"'
readonly _API_HTTP_STATUS='HTTP [0-9]'
readonly _API_GRAPHQL_ERRORS='"errors"'
readonly _API_NOT_FOUND_ERROR='HTTP 404'

# _api_is_transient DIR: true when the failed request, with the error of gh
# and the response body in DIR, may pass on its own: a transient error, or no
# HTTP status and no GraphQL error at all.
_api_is_transient() {
  local dir=$1
  grep -Eq "$_API_TRANSIENT_ERROR" "$dir/error" && return 0
  grep -Eq "$_API_TRANSIENT_GRAPHQL_ERROR" "$dir/body" && return 0
  ! grep -q "$_API_HTTP_STATUS" "$dir/error" && ! grep -q "$_API_GRAPHQL_ERRORS" "$dir/body"
}

# _api_should_retry STATUS ATTEMPT DIR: true when the attempt ATTEMPT, which
# exited with STATUS and left its error and body in DIR, may be repeated.
_api_should_retry() {
  local status=$1 attempt=$2 dir=$3
  ((status != 0 && attempt < _API_ATTEMPTS)) || return 1
  _api_is_transient "$dir"
}

# _api_result DIR STATUS: print the body in DIR after success; otherwise
# return NOT_FOUND for HTTP 404, or print the error and return 1.
_api_result() {
  local dir=$1 status=$2
  if ((status == 0)); then
    cat -- "$dir/body"
  elif grep -q "$_API_NOT_FOUND_ERROR" "$dir/error"; then
    return "$NOT_FOUND"
  else
    cat -- "$dir/error" >&2
    return 1
  fi
}

# api_request METHOD PATH [ARG...]: run gh api -X METHOD PATH ARG... and print
# the response body. Returns 0 on success, NOT_FOUND when the resource does not
# exist and 1 on any other error, after printing it on stderr. Transient errors
# are retried, _API_ATTEMPTS times in all.
api_request() {
  local method=$1 path=$2 tmp status attempt=1 delay=$_API_RETRY_DELAY result=0
  shift 2
  tmp=$(mktemp -d)
  while :; do
    status=0
    gh api -X "$method" "$path" "$@" >"$tmp/body" 2>"$tmp/error" || status=$?
    _api_should_retry "$status" "$attempt" "$tmp" || break
    sleep "$delay"
    attempt=$((attempt + 1)) delay=$((delay * 2))
  done
  _api_result "$tmp" "$status" || result=$?
  rm -rf -- "$tmp"
  return "$result"
}

# api_get PATH: print the resource PATH. Returns 0 on success and 1 on any
# error, also when it does not exist, after printing it on stderr.
api_get() {
  local path=$1 status=0
  api_request GET "$path" || status=$?
  if ((status == NOT_FOUND)); then
    printf '%s: Not Found (HTTP 404)\n' "$path" >&2
  fi
  ((status == 0)) || return 1
}
