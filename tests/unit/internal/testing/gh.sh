# shellcheck shell=bash
# Tests of internal/testing/bin/gh.
# shellcheck disable=SC2154 # work comes from setup.

gh=internal/testing/bin/gh

setup
fixture repos/o/r/thing '{"a":1}'
run "gh stub: a GET is answered from its fixture" ok "$gh" -- api repos/o/r/thing
expect stdout '{"a":1}'
expect no-calls
finish

setup
run "gh stub: a GET without a fixture is HTTP 404" fail "$gh" -- api repos/o/r/thing
expect message "gh: Not Found (HTTP 404)"
finish

setup
fixture repos/o/r/thing "HTTP 500"
run "gh stub: a fixture with HTTP 500 is a server error" fail "$gh" -- api repos/o/r/thing
expect message "gh: Server Error (HTTP 500)"
finish

setup
fixture "repos/o/r/items?per_page=100" '[1]'
next_page "repos/o/r/items?per_page=100" 2 '[2]'
run "gh stub: --paginate prints every page" ok "$gh" -- \
  api --paginate "repos/o/r/items?per_page=100" --jq '.[]'
expect stdout $'1\n2'
finish

setup
fixture repos/o/r/thing '{"a":1}'
transient_failures repos/o/r/thing 1
run "gh stub: a transient failure fails once" fail "$gh" -- api repos/o/r/thing
expect message "HTTP 504"
run "gh stub: the next request is answered" ok "$gh" -- api repos/o/r/thing
expect stdout '{"a":1}'
finish

setup
run "gh stub: a POST is recorded" ok "$gh" -- \
  api --silent -X POST repos/o/r/statuses/aaa -f state=success
expect call "POST repos/o/r/statuses/aaa state=success"
finish

setup
apply FAIL_ON=$'PATCH repos/o/r/x\nPOST repos/o/r/y 422'
run "gh stub: FAIL_ON fails a call with HTTP 502" fail "$gh" -- api -X PATCH repos/o/r/x
expect message "(HTTP 502)"
run "gh stub: FAIL_ON fails a call with its status" fail "$gh" -- api repos/o/r/y -f a=b
expect message "(HTTP 422)"
expect call "POST repos/o/r/y a=b"
finish

setup
fixture "graphql?owner=o&name=r" '{"data":{"n":1}}'
run "gh stub: a GraphQL request is answered and recorded" ok "$gh" -- \
  api graphql -f query='{ x }' -f owner=o -f name=r
expect stdout '{"data":{"n":1}}'
expect call "graphql owner=o name=r"
finish

setup
run "gh stub: a GraphQL request without a fixture is NOT_FOUND" fail "$gh" -- \
  api graphql -f query='{ x }' -f owner=o -f name=r
expect message '"type":"NOT_FOUND"'
finish

setup
fixture "graphql?owner=o" '{"data":null,"errors":[{"type":"FORBIDDEN"}]}'
run "gh stub: a GraphQL error fails" fail "$gh" -- api graphql -f owner=o
expect message '"type":"FORBIDDEN"'
finish

setup
fixture "graphql?owner=o" '{"data":{}}'
transient_failures "graphql?owner=o" 1 rate-limited
run "gh stub: a GraphQL rate limit fails once" fail "$gh" -- api graphql -f owner=o
expect message '"type":"RATE_LIMITED"'
run "gh stub: the next GraphQL request is answered" ok "$gh" -- api graphql -f owner=o
expect stdout '{"data":{}}'
finish

setup
run "gh stub: other commands are a usage error" fail "$gh" -- pr list
expect message "stub gh: unsupported: pr list"
finish

setup
run "gh stub: --silent prints no body of an error" fail "$gh" -- api --silent repos/o/r/thing
expect stdout ''
expect message "gh: Not Found (HTTP 404)"
finish

setup
fixture "graphql?owner=o" '{"data":{}}'
run "gh stub: --silent prints no body of a GraphQL answer" ok "$gh" -- \
  api --silent graphql -f owner=o
expect stdout ''
finish

# send_body BODY ARG...: gh ARG... with BODY on stdin.
send_body() {
  local body=$1
  shift
  printf '%s' "$body" | gh "$@"
}

# status_of PATH: print the HTTP status of a GET of PATH, from the status line
# that gh api -i prints also when the request fails, as a script reads it.
status_of() {
  local path=$1 response
  response=$(gh api -i "$path" 2>/dev/null) || true
  awk 'NR == 1 { print $2 }' <<<"$response"
}

setup
printf '{\n  "a": [1, 2]\n}\n' >"$work/body.json"
run "gh stub: --input FILE is recorded as compact JSON" ok "$gh" -- \
  api --silent -X PUT repos/o/r/x --input "$work/body.json"
expect call 'PUT repos/o/r/x --input={"a":[1,2]}'
run "gh stub: the fields of --input are the query string" ok "$gh" -- \
  api -X PUT "repos/o/r/q?a=1" --input "$work/body.json" -f b=c -F d=2
expect call 'PUT repos/o/r/q?a=1&b=c&d=2 --input={"a":[1,2]}'
fixture "repos/o/r/q?b=c" '{"n":1}'
run "gh stub: a GET with --input is answered for its query string" ok "$gh" -- \
  api -X GET repos/o/r/q --input "$work/body.json" -f b=c
expect stdout '{"n":1}'
run "gh stub: a GraphQL request takes no --input" fail "$gh" -- \
  api graphql --input "$work/body.json"
expect message "stub gh: unsupported: graphql --input"
run "gh stub: --input makes the request a POST" ok "$gh" -- \
  api repos/o/r/y --input "$work/body.json"
expect call 'POST repos/o/r/y --input={"a":[1,2]}'
finish

setup
run_lib "gh stub: --input - reads the body from stdin" ok "" \
  send_body '{ "a": true }' api -X PATCH repos/o/r/x --input - -f b=c
expect call 'PATCH repos/o/r/x?b=c --input={"a":true}'
run_lib "gh stub: a body that is not JSON is recorded as a string" ok "" \
  send_body $'plain\ntext\n\n' api -X PATCH repos/o/r/z --input -
expect call 'PATCH repos/o/r/z --input="plain\ntext\n\n"'
finish

setup
run_lib "gh stub: JSON with more after it is recorded as one string" ok "" \
  send_body '{"a":1} more' api -X PATCH repos/o/r/x --input -
expect stdout ''
expect call 'PATCH repos/o/r/x --input="{\"a\":1} more"'
run_lib "gh stub: two JSON values are recorded as one string" ok "" \
  send_body '1 2' api -X PATCH repos/o/r/y --input -
expect call 'PATCH repos/o/r/y --input="1 2"'
run "gh stub: an --input that cannot be read fails like gh" fail "$gh" -- \
  api -X PUT repos/o/r/z --input "$work/missing.json"
expect message "open $work/missing.json: no such file or directory"
expect no-call 'repos/o/r/z'
run_lib "gh stub: each body is one line of CALLS" ok "" cat -- "$work/calls"
expect stdout 'PATCH repos/o/r/x --input="{\"a\":1} more"
PATCH repos/o/r/y --input="1 2"'
finish

setup
fixture repos/o/r/thing '{"a":1}'
run_lib "gh stub: -i prints the status line of an answer" ok "" status_of repos/o/r/thing
expect stdout 200
run_lib "gh stub: -i prints the status line of an error" ok "" status_of repos/o/r/other
expect stdout 404
run_lib "gh stub: -i prints the status line of a GraphQL error" ok "" status_of graphql
expect stdout 200
apply FAIL_ON="GET repos/o/r/thing 409"
run_lib "gh stub: FAIL_ON fails a GET" ok "" status_of repos/o/r/thing
expect stdout 409
finish

# The headers that gh api -i prints before an answer with HTTP 200, without
# the headers themselves; written out here as an independent oracle.
ok_headers=$'HTTP/2.0 200 OK\n\r\n'

setup
fixture "repos/o/r/items?per_page=100" '[1]'
next_page "repos/o/r/items?per_page=100" 2 '[2]'
run "gh stub: -i prints the headers of each page" ok "$gh" -- \
  api -i --paginate "repos/o/r/items?per_page=100"
expect stdout "${ok_headers}[1]"$'\n\n'"${ok_headers}[2]"
run "gh stub: -i prints the headers also with --silent" ok "$gh" -- \
  api -i --silent "repos/o/r/items?per_page=100"
expect stdout $'HTTP/2.0 200 OK\n\r'
run "gh stub: -i prints the headers of an error with --silent" fail "$gh" -- \
  api -i --silent repos/o/r/other
expect stdout $'HTTP/2.0 404 Not Found\n\r'
fixture "graphql?owner=o" '{"data":null,"errors":[{"type":"FORBIDDEN"}]}'
run "gh stub: -i prints the headers of an answer with GraphQL errors" fail "$gh" -- \
  api -i graphql -f owner=o
expect stdout "$ok_headers"'{"data":null,"errors":[{"type":"FORBIDDEN"}]}'
finish

setup
fixture repos/o/r/thing '{"a":1}'
apply LOG_GETS=1
run "gh stub: LOG_GETS records a GET" ok "$gh" -- api --paginate repos/o/r/thing
expect call "GET repos/o/r/thing"
finish

setup
apply MISSING_IS_EMPTY=1
run "gh stub: MISSING_IS_EMPTY answers a GET without a fixture empty" ok "$gh" -- \
  api repos/o/r/thing --jq .a
expect stdout ''
run_lib "gh stub: MISSING_IS_EMPTY answers it with HTTP 200" ok "" status_of repos/o/r/thing
expect stdout 200
finish

setup
variable_fixture BOT_APP_ID 42
run "gh stub: gh variable get prints the fixture" ok "$gh" -- \
  variable get --org fy BOT_APP_ID
expect stdout 42
expect no-calls
run "gh stub: gh variable get fails without a fixture" fail "$gh" -- \
  variable get OTHER --org fy
expect message "variable OTHER was not found"
apply LOG_GETS=1
run "gh stub: LOG_GETS records gh variable get" ok "$gh" -- variable get BOT_APP_ID
expect call "variable get BOT_APP_ID"
finish

setup
run "gh stub: gh variable set is recorded" ok "$gh" -- \
  variable set BOT_APP_ID --org fy --visibility all --body 42
expect call "variable set BOT_APP_ID --org fy --visibility all --body 42"
run_lib "gh stub: gh secret set is recorded without its value" ok "" \
  send_body s3cret secret set KEY --repo fy/x --env release
expect call "secret set KEY --repo fy/x --env release"
expect no-call s3cret
run "gh stub: gh secret set --body needs no stdin" ok "$gh" -- secret set KEY --body v
expect call "secret set KEY --body v"
run "gh stub: other subcommands are a usage error" fail "$gh" -- variable delete X
expect message "stub gh: unsupported: variable delete"
run "gh stub: gh variable without a subcommand is a usage error" fail "$gh" -- variable
expect message "stub gh: unsupported: variable"
run "gh stub: gh secret without a subcommand is a usage error" fail "$gh" -- secret
expect message "stub gh: unsupported: secret"
finish

setup
variable_fixture value 1
variable_fixture BOT_APP_ID 42
run "gh stub: gh variable get rejects --json" fail "$gh" -- \
  variable get --json value BOT_APP_ID
expect message "stub gh: unsupported flag --json"
expect stdout ''
run "gh stub: gh variable get rejects --jq" fail "$gh" -- \
  variable get BOT_APP_ID -q .value
expect message "stub gh: unsupported flag -q"
run "gh stub: gh variable get rejects --template" fail "$gh" -- \
  variable get BOT_APP_ID '--template={{.value}}'
expect message "stub gh: unsupported flag --template={{.value}}"
finish

# stdin_left BODY ARG...: gh ARG... with BODY on stdin, then print what gh
# left of it.
stdin_left() {
  local body=$1
  shift
  printf '%s\n' "$body" | {
    gh "$@"
    cat
  }
}

setup
printf 'KEY=v\n' >"$work/secrets.env"
run_lib "gh stub: gh secret set -f FILE does not read stdin" ok "" \
  stdin_left rest secret set -f "$work/secrets.env" --org fy
expect stdout rest
expect call "secret set -f $work/secrets.env --org fy"
run_lib "gh stub: gh secret set --env-file=FILE does not read stdin" ok "" \
  stdin_left rest secret set --env-file="$work/secrets.env"
expect stdout rest
run_lib "gh stub: gh secret set -f - reads stdin" ok "" \
  stdin_left KEY=v secret set -f -
expect stdout ''
run_lib "gh stub: gh secret set reads stdin without --body" ok "" \
  stdin_left v secret set KEY
expect stdout ''
finish
