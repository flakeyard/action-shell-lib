# shellcheck shell=bash
# Responses of the gh stub and the time of the date stub, as files in the
# fixtures of the test. Source this file after case.sh; bin/gh and bin/date
# source it too. It is not public API of the library (ADR-0001).
#
# A request is named by its PATH, as gh api takes it. A GraphQL request is
# named "graphql?" and its fields other than query, as NAME=VALUE joined by "&"
# in the order given, such as "graphql?owner=o&name=r".

# fixtures_dir: print the directory of the fixtures of the test.
fixtures_dir() {
  printf '%s\n' "${FIXTURES:-$work/fixtures}"
}

# fixture_file PATH: print the file that answers the request PATH.
fixture_file() {
  local path=$1
  printf '%s\n' "$(fixtures_dir)/${path//[\/?&=]/_}"
}

# fixture PATH BODY: answer the request PATH with BODY. A BODY that contains
# "HTTP 500" is a server error.
fixture() {
  local path=$1 body=$2
  printf '%s\n' "$body" >"$(fixture_file "$path")"
}

# next_page PATH PAGE BODY: answer page PAGE, 2 or more, of the request PATH
# with --paginate.
next_page() {
  local path=$1 page=$2 body=$3
  printf '%s\n' "$body" >"$(fixture_file "$path").$page"
}

# transient_failures PATH COUNT [KIND]: fail the next COUNT requests PATH with
# KIND: gateway-timeout (HTTP 504, the default) or rate-limited (the GraphQL
# error RATE_LIMITED).
transient_failures() {
  local path=$1 count=$2 kind=${3:-gateway-timeout}
  printf '%s %s\n' "$count" "$kind" >"$(fixture_file "$path").transient"
}

# file_fixture REPOSITORY PATH REF CONTENT: answer the contents API of
# REPOSITORY, owner/repo, for the file PATH at REF, with the base64 wrapped at
# 60 characters like the API does.
file_fixture() {
  local repository=$1 path=$2 ref=$3 content=$4 encoded
  encoded=$(printf '%s' "$content" | base64 -w 60 | paste -sd '#' | sed 's/#/\\n/g')
  fixture "repos/$repository/contents/$path?ref=$ref" \
    "{\"type\":\"file\",\"encoding\":\"base64\",\"content\":\"$encoded\"}"
}

# fixed_time TIME: the time that the date stub takes as now, such as
# 2026-11-10T12:00:00Z.
fixed_time() {
  local time=$1
  printf '%s\n' "$time" >"$(fixtures_dir)/now"
}
