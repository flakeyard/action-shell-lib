# shellcheck shell=bash
# Tests of internal/testing/bin/gh.

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
