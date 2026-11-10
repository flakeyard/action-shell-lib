# shellcheck shell=bash
# Static tests of the workflows of a repository: jq expressions over a
# workflow, with the helpers of WORKFLOW_DEFS, through yaml_check. Source this
# file after yaml.sh; it is not public API of the library (ADR-0001).

# Helpers of the expressions of workflow_check:
# - condition: the if of a job or a step, "" without one, with every run of
#   whitespace as one space, however a folded scalar breaks its lines.
readonly WORKFLOW_DEFS='
  def condition: (.if // "") | gsub("\\s+"; " ");
'

# load_workflow FILE: print the workflow .github/workflows/FILE of code_root
# as JSON.
load_workflow() {
  local file=$1
  load_yaml ".github/workflows/$file"
}

# workflow_check WORKFLOW NAME FILTER [JQ_ARG...]: test NAME: FILTER, a jq
# expression over WORKFLOW, the JSON of load_workflow, with the helpers of
# WORKFLOW_DEFS, is true. JQ_ARG are options of jq, such as --arg NAME VALUE;
# a repository puts helpers of its own before FILTER.
workflow_check() {
  local workflow=$1 name=$2 filter=$3
  shift 3
  yaml_check "$workflow" "$name" "$WORKFLOW_DEFS $filter" "$@"
}
