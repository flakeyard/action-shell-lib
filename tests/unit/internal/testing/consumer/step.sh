# shellcheck shell=bash
# Tests of internal/testing/consumer/step.sh: a step gets the variables of its
# run line and of the stubs, and run_hostile fails a step or a library that
# the environment of the job reaches.
# shellcheck disable=SC2016 # the text of action.yml and of the scripts, not expanded here
# shellcheck disable=SC2034 # failed, passed and code_root are read by the checks
# shellcheck disable=SC2154 # root and work come from tests/run.sh and setup.

# A step that prints the variables it may get, and exits with STATUS.
readonly PROBE='printf "%s=%s\n" A "${A-unset}" B "${B-unset}" CALLS "${CALLS-unset}" \
  OWN_STUB "${OWN_STUB-unset}"
exit "${STATUS:-0}"'

# step_fixture: $work/consumer, whose action.yml runs the steps check, with A
# and STATUS, summary, with B, and leaky, with BASH_SOURCE, from which it
# finds the module scripts/lib/util.sh.
step_fixture() {
  mkdir -p "$work/consumer/scripts/step" "$work/consumer/scripts/lib"
  cat >"$work/consumer/action.yml" <<'ACTION'
runs:
  using: composite
  steps:
    - id: lib
      uses: flakeyard/action-shell-lib@0123456789abcdef0123456789abcdef01234567 # v0.1.0
    - shell: /usr/bin/bash --noprofile --norc -p -e -o pipefail {0}
      env:
        SHELL_LIB: ${{ steps.lib.outputs.path }}
      run: >-
        /usr/bin/bash -p "$SHELL_LIB/run-step.sh"
        "$GITHUB_ACTION_PATH/scripts/step" check A STATUS
    - shell: /usr/bin/bash --noprofile --norc -p -e -o pipefail {0}
      env:
        SHELL_LIB: ${{ steps.lib.outputs.path }}
      run: >-
        /usr/bin/bash -p "$SHELL_LIB/run-step.sh"
        "$GITHUB_ACTION_PATH/scripts/step" summary B
    - shell: /usr/bin/bash --noprofile --norc -p -e -o pipefail {0}
      env:
        SHELL_LIB: ${{ steps.lib.outputs.path }}
      run: >-
        /usr/bin/bash -p "$SHELL_LIB/run-step.sh"
        "$GITHUB_ACTION_PATH/scripts/step" leaky BASH_SOURCE
ACTION
  printf '%s\n' "$PROBE" >"$work/consumer/scripts/step/check.sh"
  printf '%s\n' "$PROBE" >"$work/consumer/scripts/step/summary.sh"
  echo 'source "${BASH_SOURCE[0]%/*}/../lib/util.sh"' >"$work/consumer/scripts/step/leaky.sh"
  echo ':' >"$work/consumer/scripts/lib/util.sh"
  apply SHELL_LIB="$root"
}

# hostile_suite LIBRARY STEP: run_hostile of STEP of $work/consumer with the
# library LIBRARY, as a suite of its own; prints its results and fails when
# its test fails.
hostile_suite() {
  local library=$1 step=$2 consumer=$work/consumer
  failed=0 passed=0 code_root=$consumer
  setup
  apply SHELL_LIB="$library"
  run_hostile "hostile" ok "$consumer" "$step"
  finish
  conclude
}

# missing_step: run_step of a step that action.yml of $work/consumer does not
# run.
missing_step() {
  run_step "missing" ok "$work/consumer" none
}

if require_yq internal/testing/consumer/step.sh; then
  setup
  step_fixture
  stub_variables=(OWN_STUB)
  apply A=a B=b OWN_STUB=o
  run_step "consumer step: the variables of the run line and of the stubs" ok \
    "$work/consumer" check
  stub_variables=()
  expect message "A=a"
  expect message "B=unset"
  expect message "CALLS=$work/calls"
  expect message "OWN_STUB=o"
  finish

  setup
  step_fixture
  apply A=a B=b
  run_step "consumer step: the variables of its own run line" ok "$work/consumer" summary
  expect message "A=unset"
  expect message "B=b"
  expect message "OWN_STUB=unset"
  finish

  setup
  step_fixture
  run_step "consumer step: the status of the step" fail "$work/consumer" check STATUS=3
  finish

  setup
  step_fixture
  run_lib "consumer step: a step that action.yml does not run fails" fail "" missing_step
  expect message "run_step: no one step none in $work/consumer/action.yml"
  finish

  setup
  step_fixture
  run_hostile "consumer step: run_hostile passes a step that the environment does not reach" \
    ok "$work/consumer" check
  finish

  setup
  step_fixture
  run_lib "consumer step: run_hostile fails a step that names BASH_SOURCE" fail "" \
    hostile_suite "$root" leaky
  expect message "FAIL hostile: the environment ran code: $work/consumer/scripts/lib/util.sh"
  finish

  setup
  step_fixture
  cp -R -- "$root" "$work/library"
  sed -i -e 's|"${0%/\*}/report.sh"|"${BASH_SOURCE[0]%/*}/report.sh"|' "$work/library/run-step.sh"
  if ! grep -qF 'BASH_SOURCE[0]%/*}/report.sh' "$work/library/run-step.sh"; then
    echo "consumer step: cannot change run-step.sh" >&2
    exit 2
  fi
  run_lib "consumer step: run_hostile fails a library that finds its modules from BASH_SOURCE" \
    fail "" hostile_suite "$work/library" check
  expect message "FAIL hostile: the environment ran code: $work/consumer/scripts/step/report.sh"
  finish
fi
