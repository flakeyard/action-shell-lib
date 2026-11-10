# shellcheck shell=bash
# The life of one test: its directory, the environment of the code under test
# and the counts of passed and failed tests. Source this file first; it is not
# public API of the library (ADR-0001).
#
# The code under test gets only the variables of env_vars: setup fills it with
# the files of the test and the PATH of the stubs, and apply adds more.
# shellcheck disable=SC2034 # work and env_vars are used by checks.sh

failed=0 passed=0 current="" work=""
# The stubs of gh, date and sleep, first on the PATH of the tests.
TESTING_BIN=$(cd -- "${BASH_SOURCE[0]%/*}/bin" && pwd)
# The PATH of the host, behind the stubs.
HOST_PATH=$PATH
readonly TESTING_BIN HOST_PATH
# A variable that apply gives, with any name that the environment can have.
readonly VARIABLE_NAME_FORM='^[A-Za-z_][A-Za-z0-9_]*='

# setup: a fresh directory for one test, with empty fixtures, calls, sleeps,
# outputs and job summary, and env_vars that name them.
setup() {
  work=$(mktemp -d)
  mkdir -p "$work/fixtures"
  : >"$work/calls"
  : >"$work/sleeps"
  : >"$work/output"
  : >"$work/summary"
  env_vars=(
    PATH="$TESTING_BIN:$HOST_PATH" HOME="$work" LC_ALL=C
    FIXTURES="$work/fixtures" CALLS="$work/calls" SLEEPS="$work/sleeps"
    GITHUB_OUTPUT="$work/output" GITHUB_STEP_SUMMARY="$work/summary"
  )
}

# apply NAME=VALUE...: give the code under test the variable NAME; a later
# value replaces an earlier one.
apply() {
  local pair
  for pair; do
    if [[ ! $pair =~ $VARIABLE_NAME_FORM ]]; then
      echo "apply: not NAME=VALUE: $pair" >&2
      exit 2
    fi
    env_vars+=("$pair")
  done
}

# report MESSAGE: fail the current test.
report() {
  [[ -n $current ]] || return 0
  printf 'FAIL %s: %s\n' "$current" "$1"
  failed=$((failed + 1))
  current=""
}

# finish: count the current test as passed unless it failed, and remove its
# directory.
finish() {
  if [[ -n $current ]]; then passed=$((passed + 1)); fi
  current=""
  if [[ -n $work ]]; then rm -rf -- "$work"; fi
  work=""
}

# conclude: print the counts; fails when a test failed.
conclude() {
  printf 'passed: %s, failed: %s\n' "$passed" "$failed"
  ((failed == 0))
}
