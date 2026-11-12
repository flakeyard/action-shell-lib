# shellcheck shell=bash
# Tests of internal/testing/consumer/action.sh: its tests pass for a consumer
# that uses the library as the README shows, in its action and in an internal
# action of a reusable workflow, and each change below fails exactly the tests
# that it breaks.
# shellcheck disable=SC2016 # the text of action.yml, not expanded here
# shellcheck disable=SC2034 # failed, passed and code_root are read by the checks
# shellcheck disable=SC2154 # work comes from setup.

# Two commits of the library.
readonly PIN=flakeyard/action-shell-lib@0123456789abcdef0123456789abcdef01234567
readonly OTHER_PIN=flakeyard/action-shell-lib@89abcdef0123456789abcdef0123456789abcdef
readonly CHECKS=7
# The internal action of the consumer.
readonly INNER=.github/actions/inner/action.yml

# consumer_fixture: $work/consumer, whose action.yml and workflow use the
# library at PIN as the README shows, and whose internal action INNER gets it
# as its input shell-lib and also uses another action.
consumer_fixture() {
  mkdir -p "$work/consumer/.github/workflows" "$work/consumer/${INNER%/*}"
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
  cat >"$work/consumer/$INNER" <<'ACTION'
inputs:
  shell-lib:
    required: true
runs:
  using: composite
  steps:
    - id: token
      uses: actions/create-github-app-token@0123456789abcdef0123456789abcdef01234567 # v2
    - shell: /usr/bin/bash --noprofile --norc -p -e -o pipefail {0}
      env:
        SHELL_LIB: ${{ inputs.shell-lib }}
        FLAKE: ${{ inputs.flake }}
      run: >-
        /usr/bin/bash -p "$SHELL_LIB/run-step.sh"
        "$GITHUB_ACTION_PATH/scripts/step" flake-checks FLAKE
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
  check_action_steps action.yml
  check_action_steps "$INNER"
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
    expect message "FAIL $test"
    expect message "passed: $((CHECKS - count)), failed: $count"
    finish
  done <<CASES
action.yml|id: lib|id: library|action.yml: the library is the first step|1
action.yml|@0123456789abcdef0123456789abcdef01234567|@v0.1.0|action.yml: the library is the first step|2
action.yml|-o pipefail {0}|{0}|action.yml: every step runs its script|1
action.yml|steps.lib.outputs|steps.other.outputs|action.yml: every step runs its script|1
action.yml|/usr/bin/bash -p "\$SHELL_LIB|bash -p "\$SHELL_LIB|action.yml: every step runs its script|1
action.yml|scripts/step" check|scripts/steps" check|action.yml: every step runs its script|1
action.yml|check LOCK_PATH PATH|check LOCK_PATH path|action.yml: every step runs its script|1
action.yml|check LOCK_PATH PATH|check PATH|action.yml: every step names its variables|1
.github/workflows/test.yaml|$PIN|$OTHER_PIN|action: every use of the library names one commit|1
.github/workflows/test.yaml|flakeyard/action-shell-lib|FlakeYard/Action-Shell-Lib|action: every use of the library names one commit|1
$INNER|required: true|required: false|$INNER: the library is the first step|1
$INNER|inputs.shell-lib }}|steps.lib.outputs.path }}|$INNER: every step runs its script|1
$INNER|/usr/bin/bash -p "\$SHELL_LIB|bash -p "\$SHELL_LIB|$INNER: every step runs its script|1
$INNER|step" flake-checks FLAKE|step" flake-checks|$INNER: every step names its variables|1
CASES

  # Another action after the library step of an action that is not internal:
  # every step there runs a script.
  setup
  consumer_fixture
  change action.yml "uses: $PIN # v0.1.0" $'uses: '"$PIN"$' # v0.1.0\n    - uses: actions/checkout@'"${PIN#*@}"
  run_lib "consumer action: another action after the library step fails" fail "" consumer_checks
  expect message "FAIL action.yml: every step runs its script"
  finish

  # A library step of its own in the internal action: its other steps with
  # uses are not checked further, this one is.
  setup
  consumer_fixture
  change "$INNER" "  steps:" $'  steps:\n    - id: lib\n      uses: '"$PIN"
  run_lib "consumer action: a library step in an internal action fails" fail "" consumer_checks
  expect message "FAIL $INNER: the library is the first step"
  expect message "passed: $((CHECKS - 1)), failed: 1"
  finish

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
