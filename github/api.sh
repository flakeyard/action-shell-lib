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
# Errors of gh that may pass on their own; every other failure, such as a
# missing token, a wrong command line or a GraphQL error, is not retried:
# - HTTP 5xx: a server error; HTTP 429: too many requests;
# - i/o timeout, TLS handshake timeout and Client.Timeout exceeded: the
#   network or the server did not answer in time;
# - connection reset by peer, connection refused and unexpected EOF: the
#   connection broke or was not accepted, as while GitHub fails over;
# - network is unreachable: the runner had no route to GitHub for a moment;
# - server sent GOAWAY: GitHub closed an HTTP/2 connection, as while it
#   restarts a server, before it answered; another GOAWAY, which Go itself
#   takes as a lasting error, is not retried;
# - no such host: a failed DNS lookup, which runners see now and then;
# - the GraphQL error RATE_LIMITED, which gh prints with HTTP 200.
readonly _API_TRANSIENT_ERROR='HTTP (5[0-9][0-9]|429)|i/o timeout|TLS handshake timeout|Client\.Timeout exceeded|connection reset by peer|connection refused|unexpected EOF|network is unreachable|server sent GOAWAY|no such host'
readonly _API_TRANSIENT_GRAPHQL_ERROR='"type": *"RATE_LIMITED"'
readonly _API_NOT_FOUND_ERROR='HTTP 404'
# Requests that change nothing, and so may be repeated: these methods, and a
# GraphQL query, whose text starts with "{" or the keyword query; a mutation, or
# a query that gh reads from a file (query=@FILE), is not repeated.
readonly _API_IDEMPOTENT_METHOD='^(GET|HEAD)$'
readonly _API_GRAPHQL='graphql'
readonly _API_GRAPHQL_QUERY='^[[:space:]]*(\{|query([^A-Za-z0-9_]|$))'
readonly _API_FIELD_FLAG='^-[fF]$'

# _api_is_transient DIR: true when the failed request, with the error of gh
# and the response body in DIR, may pass on its own.
_api_is_transient() {
  local dir=$1
  grep -Eq "$_API_TRANSIENT_ERROR" "$dir/error" \
    || grep -Eq "$_API_TRANSIENT_GRAPHQL_ERROR" "$dir/body"
}

# _api_is_query ARG...: the fields ARG... of gh api, given with -f or -F,
# have a query field whose text is a GraphQL query.
_api_is_query() {
  while (($# >= 2)); do
    if [[ $1 =~ $_API_FIELD_FLAG && $2 == query=* ]]; then
      [[ ${2#query=} =~ $_API_GRAPHQL_QUERY ]]
      return
    fi
    shift
  done
  return 1
}

# _api_is_idempotent METHOD PATH [ARG...]: the request changes nothing.
_api_is_idempotent() {
  local method=$1 path=$2
  shift 2
  [[ $method =~ $_API_IDEMPOTENT_METHOD ]] && return 0
  [[ $method == POST && $path == "$_API_GRAPHQL" ]] && _api_is_query "$@"
}

# _api_should_retry STATUS ATTEMPT ATTEMPTS DIR: true when the attempt
# ATTEMPT of ATTEMPTS, which exited with STATUS and left its error and body in
# DIR, may be repeated.
_api_should_retry() {
  local status=$1 attempt=$2 attempts=$3 dir=$4
  ((status != 0 && attempt < attempts)) || return 1
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
# of a request that changes nothing are retried, _API_ATTEMPTS times in all;
# other requests are tried once.
api_request() {
  local method=$1 path=$2 tmp status attempt=1 attempts=1 delay=$_API_RETRY_DELAY result=0
  shift 2
  if _api_is_idempotent "$method" "$path" "$@"; then attempts=$_API_ATTEMPTS; fi
  tmp=$(mktemp -d)
  while :; do
    status=0
    gh api -X "$method" "$path" "$@" >"$tmp/body" 2>"$tmp/error" || status=$?
    _api_should_retry "$status" "$attempt" "$attempts" "$tmp" || break
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
