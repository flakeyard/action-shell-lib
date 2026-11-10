# shellcheck shell=bash
# Static tests of YAML files, such as action.yml or a workflow: jq expressions
# over the file, read as JSON with mikefarah yq v4, which GitHub-hosted
# runners have. Source this file after case.sh; it is not public API of the
# library (ADR-0001).
# shellcheck disable=SC2154 # code_root comes from the suite.
# shellcheck disable=SC2034 # current is the test that report and finish count.

# have_yq: mikefarah yq v4 is installed.
have_yq() {
  command -v yq >/dev/null && [[ $(yq --version 2>&1) == *mikefarah* ]]
}

# require_yq FILE: true when yq is installed; otherwise fails a test of FILE.
require_yq() {
  local file=$1
  have_yq && return 0
  setup
  current="$file: yq is installed"
  report "the static tests need mikefarah yq v4; run them with: nix shell nixpkgs#yq-go -c tests/run.sh"
  finish
  return 1
}

# load_yaml FILE: print FILE, a path in code_root, as JSON.
load_yaml() {
  local file=$1
  yq -o=json . "$code_root/$file"
}

# yaml_check JSON NAME FILTER [JQ_ARG...]: test NAME: FILTER, a jq expression
# over JSON, is true; JQ_ARG are options of jq, such as --arg NAME VALUE.
yaml_check() {
  local json=$1 name=$2 filter=$3
  shift 3
  setup
  current=$name
  jq -e "$@" "$filter" <<<"$json" >/dev/null || report "not true: $filter"
  finish
}
