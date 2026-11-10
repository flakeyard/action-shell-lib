# shellcheck shell=bash
# Tests of internal/testing/workflow.sh.
# shellcheck disable=SC2016 # jq expressions, not expansions.
# shellcheck disable=SC2034 # failed, passed and code_root are read by the checks.
# shellcheck disable=SC2154 # work comes from setup.

# workflow_fixture: $work/repo with the workflow test.yaml, whose job has a
# condition over several lines and whose step has none.
workflow_fixture() {
  mkdir -p "$work/repo/.github/workflows"
  printf '%s\n' "jobs:" "  unit:" "    if: >-" "      \${{ always()" "        &&  !cancelled() }}" \
    "    steps:" "      - run: echo" >"$work/repo/.github/workflows/test.yaml"
}

# workflow_checks FILTER [JQ_ARG...]: workflow_check of FILTER over test.yaml
# of $work/repo, as a suite of its own; prints its result and fails when it
# fails.
workflow_checks() {
  failed=0 passed=0 code_root=$work/repo
  workflow_check "$(load_workflow test.yaml)" "workflow: probe" "$@"
  conclude
}

if require_yq internal/testing/workflow.sh; then
  # FILTER#JQ_ARG#EXPECTED: a check of the fixture, which passes (ok) or fails.
  while IFS='#' read -r filter arg expected; do
    setup
    workflow_fixture
    read -ra args <<<"$arg"
    run_lib "workflow: $filter ${arg:+with $arg }is $expected" "$expected" "" \
      workflow_checks "$filter" "${args[@]}"
    finish
  done <<'CASES'
.jobs.unit | condition == "${{ always() && !cancelled() }}"##ok
.jobs.unit.steps[0] | condition == ""##ok
.jobs.unit | condition == ""##fail
.jobs.unit.steps[0].run == $run#--arg run echo#ok
.jobs.unit.steps[0].run == $run#--arg run true#fail
CASES

  setup
  workflow_fixture
  run_lib "workflow: a false check fails as its own test" fail "" workflow_checks '.jobs == {}'
  expect message "FAIL workflow: probe: not true"
  finish
fi
