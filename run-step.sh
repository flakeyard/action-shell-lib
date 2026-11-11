#!/usr/bin/env bash
# Usage: /usr/bin/bash -p "$SHELL_LIB/run-step.sh" STEP_DIR STEP [VARIABLE...]
#
# Runs STEP_DIR/STEP.sh, the script of one step of a consumer, with only the
# variables VARIABLE... that are set, and SHELL_LIB. Earlier steps can set any
# variable for the rest of the job, such as exported functions
# (BASH_FUNC_name%%) that replace commands, or SHELLOPTS and PS4 that run code.
# bash -p imports no functions, SHELLOPTS or BASHOPTS and reads no BASH_ENV,
# here and in the step. It still imports BASH_SOURCE, which then names any
# file, so this script finds its directory from $0: neither the environment
# nor BASH_ARGV0 in it can set $0. Variables of the dynamic loader, such as
# LD_PRELOAD, are not covered: the loader reads them when the first bash of
# the step starts, before this script.
#
# PATH is the job's until the step replaces it, so this script runs only
# builtins and absolute paths.
set -euo pipefail

# shellcheck source-path=SCRIPTDIR source=report.sh
source "${0%/*}/report.sh"

# A name only, so that no path leaves STEP_DIR.
readonly STEP_FORM='^[a-z-]+$'
readonly VARIABLE_FORM='^[A-Za-z_][A-Za-z0-9_]*$'
# A component of a path that leaves its directory.
readonly PARENT_COMPONENT='(^|/)\.\.(/|$)'

# check_dir NAME VALUE: fail unless VALUE, the directory NAME, is absolute,
# has no ".." component and is a directory.
check_dir() {
  local name=$1 value=$2
  [[ $value == /* ]] || fail "run-step.sh: $name '$value' is not an absolute path."
  [[ ! $value =~ $PARENT_COMPONENT ]] || fail "run-step.sh: $name '$value' has a '..' component."
  [[ -d $value ]] || fail "run-step.sh: $name '$value' is not a directory."
}

# check_names STEP VARIABLE...: fail unless STEP and every VARIABLE are names.
check_names() {
  local step=$1 name
  shift
  [[ $step =~ $STEP_FORM ]] || fail "run-step.sh: invalid step name '$step'."
  for name; do
    [[ $name =~ $VARIABLE_FORM ]] || fail "run-step.sh: invalid variable name '$name'."
  done
}

# step_variables VARIABLE...: set vars to NAME=VALUE of each VARIABLE that is
# set, and of SHELL_LIB.
step_variables() {
  local name
  vars=()
  for name in "$@" SHELL_LIB; do
    if [[ -v $name ]]; then vars+=("$name=${!name}"); fi
  done
}

(($# >= 2)) || fail "usage: run-step.sh STEP_DIR STEP [VARIABLE...]"
step_dir=$1 step=$2
shift 2
check_dir SHELL_LIB "${SHELL_LIB-}"
check_dir STEP_DIR "$step_dir"
check_names "$step" "$@"
step_variables "$@"
exec /usr/bin/env -i "${vars[@]}" /usr/bin/bash -p "$step_dir/$step.sh"
