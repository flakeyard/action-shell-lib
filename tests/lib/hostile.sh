# shellcheck shell=bash
# Variables of the environment that earlier steps of a job can set to attack
# the modules: every read-only constant and internal name of the modules, with
# a value that runs a command when it is evaluated as arithmetic. Source this
# file after internal/testing/case.sh.
# shellcheck disable=SC2154 # root comes from tests/run.sh.

# module_names: print the read-only constants and the names that start with _
# in the modules, one per line.
module_names() {
  grep -ohE '(readonly [A-Za-z_][A-Za-z0-9_]*|\b_[A-Za-z][A-Za-z0-9_]*)' \
    "$root"/*.sh "$root"/github/*.sh | sed 's/^readonly //' | sort -u
}

# hostile_environment MARKER: print NAME=VALUE for each of module_names, with
# a value that creates the file MARKER when it is evaluated.
hostile_environment() {
  local marker=$1 name
  while IFS= read -r name; do
    # shellcheck disable=SC2016 # code for the modules, not expanded here
    printf '%s=a[$(touch %s)]\n' "$name" "$marker"
  done < <(module_names)
}
