#!/usr/bin/env bash
# Checks the step of the action in the action job of test.yaml: on a supported
# runner it gives the directory of the library.
# Inputs (environment): LIB_PATH, the output path of the step.
set -euo pipefail

if [[ ! -f $LIB_PATH/action.yml ]]; then
  echo "::error::path '$LIB_PATH' is not the directory of the action."
  exit 1
fi
echo "The action gave the directory $LIB_PATH."
