# shellcheck shell=bash
# Runs of the script of a step as the run line of its action.yml runs it:
# through run-step.sh of the library that the test gives as SHELL_LIB, such as
# a copy of copy_library, with only the variables of the run line and of the
# stubs; and runs with the variables that earlier steps of a job can set to
# run code. Source this file after case.sh, checks.sh, yaml.sh,
# consumer/library.sh and consumer/action.sh, and call its runs only when
# require_yq passes; it is not public API of the library (ADR-0001).
# shellcheck disable=SC2154 # work, env_vars, current and code_root come from case.sh and the suite.
# shellcheck disable=SC2016 # code for the other bash, not expanded here

# The variables of the stubs of internal/testing/bin, which every step gets
# besides the variables of its run line.
readonly TESTING_STUB_VARIABLES=(CALLS FIXTURES SLEEPS FAIL_ON LOG_GETS MISSING_IS_EMPTY)
# The variables of the stubs of the suite, which every step gets too; the
# suite sets them after it sources this file.
stub_variables=()
# The run line of a step, with the bash that runs it as $0.
readonly RUN_LINE='exec "$0" -p "$SHELL_LIB/run-step.sh" "$@"'
# Exported functions that earlier steps of a job can set to replace commands.
readonly HOSTILE_FUNCTIONS=(source printf jq gh)

# The variables of the run line of each step, read once: "ACTION STEP" maps to
# the variables, each after a space.
declare -gA run_lines=()

# library_modules: print the modules of the library, run-step.sh included, as
# paths in TESTED_LIBRARY, one per line.
library_modules() (
  cd -- "$TESTED_LIBRARY" || exit 2
  printf '%s\n' *.sh github/*.sh
)

# read_run_line ACTION STEP: the variables of the run line of the step STEP of
# ACTION, an action.yml, in run_lines; exits 2 unless exactly one step is
# STEP.
read_run_line() {
  local action=$1 step=$2
  [[ ! -v run_lines["$action $step"] ]] || return 0
  run_lines["$action $step"]=$(yq -o=json . "$action" | jq -er --arg form "$STEP_RUN_FORM" \
    --arg step "$step" '[.runs.steps[].run // empty | match($form)
    | select(.captures[0].string == $step) | .captures[1].string]
    | if length == 1 then .[0] else error end') || {
    printf 'run_step: no one step %s in %s\n' "$step" "$action" >&2
    exit 2
  }
}

# run_step NAME EXPECTED ACTION_DIR STEP [NAME=VALUE...]: run the script of
# the step STEP of ACTION_DIR/action.yml, ACTION_DIR/scripts/step/STEP.sh, as
# its run line does, in the bash of the tests, with env_vars and the variables
# given; EXPECTED is ok or fail.
run_step() {
  local name=$1 expected=$2 action_dir=$3 step=$4 status=0 variables=()
  shift 4
  read_run_line "$action_dir/action.yml" "$step"
  read -r -a variables <<<"${run_lines["$action_dir/action.yml $step"]}"
  env -i "${env_vars[@]}" "$@" "$BASH" --noprofile --norc -p -e -o pipefail -c "$RUN_LINE" \
    "$BASH" "$action_dir/scripts/step" "$step" \
    "${variables[@]}" "${TESTING_STUB_VARIABLES[@]}" "${stub_variables[@]}" \
    >"$work/stdout" 2>"$work/stderr" || status=$?
  outcome "$name" "$expected" "$status"
}

# hostile_modules DIR MARKER STEP_DIR: under DIR, at their absolute paths, the
# files that a script would source if it found its own files from a
# BASH_SOURCE in DIR: every script of code_root, and every module of the
# library in STEP_DIR; and DIR/bash-env for BASH_ENV. Each appends its path to
# MARKER.
hostile_modules() {
  local dir=$1 marker=$2 step_dir=$3 module modules=()
  mapfile -t modules < <(find "$code_root" -name .git -prune -o -type f -name '*.sh' -print)
  while IFS= read -r module; do modules+=("$step_dir/$module"); done < <(library_modules)
  for module in "${modules[@]}" /bash-env; do
    mkdir -p -- "$(dirname -- "$dir$module")"
    printf 'echo %q >>%q\n' "$module" "$marker" >"$dir$module"
  done
}

# hostile_variables DIR MARKER SCRIPT: print, one per line, the variables
# that earlier steps of a job can set to run code: BASH_ENV, exported
# functions, SHELLOPTS with PS4, and BASH_SOURCE and BASH_ARGV0, which name
# the absolute path SCRIPT under DIR. Each appends what ran to MARKER.
hostile_variables() {
  local dir=$1 marker=$2 script=$3 function
  printf '%s\n' "BASH_ENV=$dir/bash-env" "BASH_SOURCE=$dir$script" \
    "BASH_ARGV0=$dir$script" SHELLOPTS=xtrace BASHOPTS=extdebug \
    "PS4=\$(echo PS4 >>$marker)"
  for function in "${HOSTILE_FUNCTIONS[@]}"; do
    printf 'BASH_FUNC_%s%%%%=() { echo %s >>%s; }\n' "$function" "$function" "$marker"
  done
}

# run_hostile NAME EXPECTED ACTION_DIR STEP [NAME=VALUE...]: run_step with
# the variables of hostile_variables, whose BASH_SOURCE names the script of
# the step. The test fails when any of them ran.
run_hostile() {
  local name=$1 expected=$2 action_dir=$3 step=$4 dir=$work/hostile marker=$work/hostile-ran
  local step_dir=$action_dir/scripts/step hostile=()
  shift 4
  hostile_modules "$dir" "$marker" "$step_dir"
  mapfile -t hostile < <(hostile_variables "$dir" "$marker" "$step_dir/$step.sh")
  run_step "$name" "$expected" "$action_dir" "$step" "$@" "${hostile[@]}"
  [[ -z $current || ! -e $marker ]] || report "the environment ran code: $(paste -sd' ' "$marker")"
}
