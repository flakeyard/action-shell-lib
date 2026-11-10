# shellcheck shell=bash
# Tests of internal/testing/consumer/action.sh: its tests pass for a consumer
# that uses the library as the README shows, and each change below fails
# exactly the tests that it breaks.
# shellcheck disable=SC2016 # the text of action.yml, not expanded here
# shellcheck disable=SC2034 # failed, passed and code_root are read by the checks
# shellcheck disable=SC2154 # work comes from setup.

# Two commits of the library.
readonly PIN=flakeyard/action-shell-lib@0123456789abcdef0123456789abcdef01234567
readonly OTHER_PIN=flakeyard/action-shell-lib@89abcdef0123456789abcdef0123456789abcdef
readonly CHECKS=4

# consumer_fixture: $work/consumer, whose action.yml and workflow use the
# library at PIN as the README shows.
consumer_fixture() {
  mkdir -p "$work/consumer/.github/workflows"
  cat >"$work/consumer/action.yml" <<ACTION
runs:
  using: composite
  steps:
    - id: lib
      uses: $PIN # v0.1.0
    - shell: /usr/bin/bash --noprofile --norc -p -e -o pipefail {0}
      env:
        SHELL_LIB: \${{ steps.lib.outputs.path }}
        LOCK_PATH: \${{ inputs.path }}
      run: >-
        /usr/bin/bash -p "\$SHELL_LIB/run-step.sh"
        "\$GITHUB_ACTION_PATH/scripts/step" check LOCK_PATH PATH
    - shell: /usr/bin/bash --noprofile --norc -p -e -o pipefail {0}
      env:
        SHELL_LIB: \${{ steps.lib.outputs.path }}
      run: >-
        /usr/bin/bash -p "\$SHELL_LIB/run-step.sh"
        "\$GITHUB_ACTION_PATH/scripts/step" write-report GITHUB_STEP_SUMMARY X2
ACTION
  printf '%s\n' "jobs:" "  unit:" "    steps:" "      - id: lib" \
    "        uses: $PIN # v0.1.0" "      - run: tests/run.sh" \
    >"$work/consumer/.github/workflows/test.yaml"
}

# change FILE FROM TO: replace FROM with TO in FILE of the consumer; exits
# when FILE has no FROM, since the case would then test nothing.
change() {
  local file=$work/consumer/$1 from=$2 to=$3 text
  text=$(<"$file")
  if [[ $text != *"$from"* ]]; then
    echo "change: no '$from' in $1" >&2
    exit 2
  fi
  printf '%s\n' "${text//"$from"/$to}" >"$file"
}

# consumer_checks: the tests of consumer/action.sh over $work/consumer, as a
# suite of their own; prints their results and fails when one fails.
consumer_checks() {
  failed=0 passed=0 code_root=$work/consumer
  check_action_steps "$(load_yaml action.yml)"
  check_library_pins
  conclude
}

# consumer_pins: check_library_pins over $work/consumer, as a suite of its own.
consumer_pins() {
  failed=0 passed=0 code_root=$work/consumer
  check_library_pins
  conclude
}

if require_yq internal/testing/consumer/action.sh; then
  setup
  consumer_fixture
  run_lib "consumer action: a consumer as the README shows passes" ok "" consumer_checks
  expect stdout "passed: $CHECKS, failed: 0"
  finish

  # Changes of the consumer: FILE|FROM|TO|THE TEST THAT FAILS|FAILED TESTS.
  while IFS='|' read -r file from to test count; do
    setup
    consumer_fixture
    change "$file" "$from" "$to"
    run_lib "consumer action: '$from' -> '$to' in $file fails" fail "" consumer_checks
    expect message "FAIL action: $test"
    expect message "passed: $((CHECKS - count)), failed: $count"
    finish
  done <<CASES
action.yml|id: lib|id: library|the library is the first step|1
action.yml|@0123456789abcdef0123456789abcdef01234567|@v0.1.0|the library is the first step|2
action.yml|-o pipefail {0}|{0}|every other step runs its script|1
action.yml|steps.lib.outputs|steps.other.outputs|every other step runs its script|1
action.yml|/usr/bin/bash -p "\$SHELL_LIB|bash -p "\$SHELL_LIB|every other step runs its script|1
action.yml|scripts/step" check|scripts/steps" check|every other step runs its script|1
action.yml|check LOCK_PATH PATH|check LOCK_PATH path|every other step runs its script|1
action.yml|check LOCK_PATH PATH|check PATH|every step names its variables|1
.github/workflows/test.yaml|$PIN|$OTHER_PIN|every use of the library names one commit|1
.github/workflows/test.yaml|flakeyard/action-shell-lib|FlakeYard/Action-Shell-Lib|every use of the library names one commit|1
CASES

  setup
  consumer_fixture
  mkdir -p "$work/consumer/.github/actions/nested/inner"
  printf 'runs:\n  steps:\n    - uses: %s\n' "$OTHER_PIN" \
    >"$work/consumer/.github/actions/nested/inner/action.yaml"
  run_lib "consumer action: a pin in an action under .github fails" fail "" consumer_checks
  expect message "FAIL action: every use of the library names one commit"
  finish

  setup
  consumer_fixture
  printf '%s\n' "on: push" >"$work/consumer/.github/workflows/test.yaml"
  rm -- "$work/consumer/action.yml"
  run_lib "consumer action: a repository without the library fails" fail "" \
    consumer_pins
  expect message "FAIL action: every use of the library names one commit"
  finish
fi
