#!/usr/bin/env bash
# Checks the step of the action in the action job of test.yaml: on a supported
# runner it gives the directory of the library, which has run-step.sh.
# Inputs (environment): LIB_PATH, the output path of the step.
set -euo pipefail

if [[ ! -f $LIB_PATH/run-step.sh ]]; then
  echo "::error::path '$LIB_PATH' is not a directory with run-step.sh."
  exit 1
fi
echo "The action gave the directory $LIB_PATH."
