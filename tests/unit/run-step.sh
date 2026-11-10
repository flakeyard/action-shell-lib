# shellcheck shell=bash
# Tests of run-step.sh: the step gets only the variables it names, and nothing
# runs before the arguments are checked.
# shellcheck disable=SC2154 # root and work come from tests/run.sh and setup.
# shellcheck disable=SC2016 # code for the scripts, not expanded here

# Variables that earlier steps of a job can set to run code in a step.
readonly HOSTILE_VARS=(
  'BASH_FUNC_printf%%=() { builtin echo INJECTED; }'
  'BASH_FUNC_fail%%=() { builtin echo INJECTED; }'
  SHELLOPTS=xtrace 'PS4=$(builtin echo PS4-RAN >&2)' BASHOPTS=extdebug
  BASH_ENV=/dev/null NIX_CONFIG="sandbox = false" GH_HOST=ghes.example.com
)
readonly AS_ACTION=tests/bin/as-action

# step_setup: the step directory $work/step with the step probe, which prints
# what it got: its functions, its shell options, a child's functions and its
# environment; and SHELL_LIB.
step_setup() {
  setup
  apply SHELL_LIB="$root"
  mkdir "$work/step"
  cat >"$work/step/probe.sh" <<'PROBE'
mapfile -t functions < <(declare -F)
printf 'functions: %s\n' "${#functions[@]}"
printf 'xtrace: %s\n' "$([[ -o xtrace ]] && echo on || echo off)"
printf 'child functions: %s\n' "$(/usr/bin/bash -c 'declare -F | /usr/bin/wc -l')"
/usr/bin/env
PROBE
  echo 'echo STEP-RAN' >"$work/step/ran.sh"
}

step_setup
run "run-step: no functions or options of the job" ok "$AS_ACTION" \
  "${HOSTILE_VARS[@]}" -- "$work/step" probe
expect message "functions: 0"
expect message "xtrace: off"
expect message "child functions: 0"
expect no-message "INJECTED"
expect no-message "PS4-RAN"
expect no-message "BASH_FUNC_"
expect no-message "NIX_CONFIG"
expect no-message "GH_HOST"
finish

step_setup
run "run-step: the variables the step names, and SHELL_LIB" ok "$AS_ACTION" \
  A=$'a\nb' B=b -- "$work/step" probe A C
expect message $'A=a\nb'
expect message "SHELL_LIB=$root"
expect no-message "B=b"
expect no-message "C="
expect no-message "FIXTURES="
finish

# The loader reads its variables when the first bash of a step starts, before
# run-step.sh: they reach that process, but not the step.
step_setup
run "run-step: loader variables reach only the first process" ok "$AS_ACTION" \
  LD_PRELOAD=/nonexistent/preload.so LD_LIBRARY_PATH=/nonexistent -- "$work/step" probe
expect message "from LD_PRELOAD cannot be preloaded"
[[ -z $current ]] || ! grep -E '^LD_' "$work/stdout" \
  || report "the step got variables of the loader"
finish

step_setup
run "run-step: only a step name" fail "$AS_ACTION" -- "$work/step" ../step/ran
expect message "::error::run-step.sh: invalid step name '../step/ran'."
expect no-message "STEP-RAN"
finish

step_setup
run "run-step: only variable names" fail "$AS_ACTION" -- "$work/step" ran 'A[$(echo X)]'
expect message "invalid variable name 'A[\$(echo X)]'"
expect no-message "STEP-RAN"
finish

# Directories that run-step.sh rejects: NAME, VALUE in $work, and the reason.
while IFS='|' read -r name value reason; do
  step_setup
  run "run-step: $name '$value' $reason" fail "$AS_ACTION" \
    "$name=${value//@work/$work}" -- "${value//@work/$work}" ran
  expect message "$reason"
  expect no-message "STEP-RAN"
  finish
done <<'CASES'
STEP_DIR|step|is not an absolute path
STEP_DIR|@work/step/../step|has a '..' component
STEP_DIR|@work/none|is not a directory
SHELL_LIB|lib|is not an absolute path
SHELL_LIB|@work/step/..|has a '..' component
SHELL_LIB|@work/step/ran.sh|is not a directory
CASES

step_setup
run "run-step: needs SHELL_LIB" fail "$AS_ACTION" SHELL_LIB= -- "$work/step" ran
expect message "SHELL_LIB '' is not an absolute path"
expect no-message "STEP-RAN"
finish

step_setup
run "run-step: needs a step" fail "$AS_ACTION" -- "$work/step"
expect message "usage: run-step.sh STEP_DIR STEP [VARIABLE...]"
finish
