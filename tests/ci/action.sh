#!/usr/bin/env bash
# Checks the step of the action in the action job of test.yaml: on Linux it
# gives the directory of the library, elsewhere it fails without a path.
# Inputs (environment): RUNNER_OS, OUTCOME, the outcome of the step, and
# LIB_PATH, its output path.
set -euo pipefail

# fail MESSAGE: report an error and exit.
fail() {
  echo "::error::$1"
  exit 1
}

# check_linux: the step passed and gave the directory of this action.
check_linux() {
  [[ $OUTCOME == success ]] || fail "The action failed on Linux (outcome: $OUTCOME)."
  [[ -f $LIB_PATH/action.yml ]] || fail "path '$LIB_PATH' is not the directory of the action."
  echo "The action gave the directory $LIB_PATH."
}

# check_rejected: the step failed and gave no path.
check_rejected() {
  [[ $OUTCOME == failure ]] || fail "The action did not fail on $RUNNER_OS (outcome: $OUTCOME)."
  [[ -z $LIB_PATH ]] || fail "The action gave the path '$LIB_PATH' on $RUNNER_OS."
  echo "The action rejected $RUNNER_OS."
}

if [[ $RUNNER_OS == Linux ]]; then check_linux; else check_rejected; fi
