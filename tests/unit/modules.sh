# shellcheck shell=bash
# Tests of every sourced module of the library (ADR-0001): sourcing one, also
# twice, prints nothing and changes no shell option, trap or PATH, and the
# variables it adds are read-only constants.
# shellcheck disable=SC2154 # root comes from tests/run.sh.

# shell_state: print the shell options, traps and PATH.
shell_state() {
  set -o
  shopt
  trap -p
  printf 'PATH=%s\n' "$PATH"
}

# writable_variables_since NAMES: print the variables that are not in NAMES,
# one per line, and not read-only.
writable_variables_since() {
  local before=$1 name
  for name in $(compgen -v); do
    [[ $'\n'$before$'\n' != *$'\n'$name$'\n'* ]] || continue
    [[ $(declare -p "$name") == "declare -"*r* ]] || printf '%s\n' "$name"
  done
}

# sources_cleanly MODULE: source MODULE twice in an empty directory, and
# check the shell before and after.
sources_cleanly() {
  local module=$1 state variables writable
  cd -- "$(mktemp -d)" || return 1
  state=$(shell_state)
  variables=$(compgen -v)
  # shellcheck source=/dev/null
  source "$code_root/$module" && source "$code_root/$module" || return 1
  [[ $(shell_state) == "$state" ]] || echo "$module changed the shell"
  writable=$(writable_variables_since "$variables")
  [[ -z $writable ]] || echo "$module added variables: $writable"
  [[ -z $(ls -A) ]] || echo "$module wrote files"
}

# The script of the library, which is run, not sourced.
readonly RUN_SCRIPT=run-step.sh

# Variables of the environment with the names of the constants that stop a
# second sourcing of a module.
readonly GUARD_VARS=(
  ANNOTATIONS_PER_KIND=0 NOT_FOUND=0 REPOSITORY_NAME_FORM=. _CONTENTS_BAD_SEGMENT=.
)

# defines_functions MODULE: sourcing MODULE defines functions.
defines_functions() {
  local module=$1 before after
  before=$(declare -F | wc -l)
  # shellcheck source=/dev/null
  source "$code_root/$module"
  after=$(declare -F | wc -l)
  ((after > before))
}

for path in "$root"/*.sh "$root"/github/*.sh; do
  module=${path#"$root/"}
  [[ -f $path && $module != "$RUN_SCRIPT" ]] || continue
  setup
  run_lib "modules: $module only defines" ok "" sources_cleanly "$module"
  expect stdout ""
  [[ -z $current || ! -s $work/stderr ]] || report "stderr: $(<"$work/stderr")"
  finish

  setup
  apply "${GUARD_VARS[@]}"
  run_lib "modules: $module ignores variables of the environment" ok "" \
    defines_functions "$module"
  finish
done
