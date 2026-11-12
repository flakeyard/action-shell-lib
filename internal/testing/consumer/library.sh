# shellcheck shell=bash
# A copy of the library for the tests of a consumer, whose steps then run only
# the tools that the tests choose. Source this file after case.sh; it is not
# public API of the library (ADR-0001).

# The library that this file belongs to.
TESTED_LIBRARY=$(cd -- "${BASH_SOURCE[0]%/*}/../../.." && pwd)
readonly TESTED_LIBRARY
# The line of env.sh that sets SYSTEM_PATH.
readonly SYSTEM_PATH_LINE_FORM='^readonly SYSTEM_PATH='
# The line of run-step.sh that runs the step with the env and bash of the
# runner; the arguments of each are the groups.
readonly RUNNER_EXEC_LINE_FORM='^exec /usr/bin/env -i (.*) /usr/bin/bash -p (.*)$'

# copy_library DIR SYSTEM_PATH: a writable copy of the library in DIR, which
# must not exist, whose env.sh sets SYSTEM_PATH, such as the stubs of the
# tests and a directory of the host's tools, and whose run-step.sh runs the
# step with the env on PATH and the bash of the tests, BASH, by absolute path,
# since a host or the Nix sandbox may have no /usr/bin/bash. Exits 2 when it
# cannot, since the steps would then run the tools of the host.
copy_library() {
  local dir=$1 system_path=$2
  [[ ! -e $dir ]] || copy_error "$dir exists"
  { cp -R -- "$TESTED_LIBRARY" "$dir" && chmod -R u+w -- "$dir"; } \
    || copy_error "cannot copy $TESTED_LIBRARY"
  rewrite_lines "$dir/env.sh" "$SYSTEM_PATH_LINE_FORM" system_path_line "$system_path"
  [[ $(system_path_of "$dir/env.sh") == "$system_path" ]] \
    || copy_error "cannot set SYSTEM_PATH in $dir/env.sh"
  use_test_interpreters "$dir/run-step.sh"
}

# copy_error MESSAGE: exit 2 with MESSAGE about copy_library.
copy_error() {
  printf 'copy_library: %s\n' "$1" >&2
  exit 2
}

# rewrite_lines FILE FORM REWRITE [ARG...]: replace each line of FILE that
# matches FORM with what REWRITE ARG... prints, which reads the groups of the
# match in BASH_REMATCH.
rewrite_lines() {
  local file=$1 form=$2 line lines=()
  shift 2
  while IFS= read -r line; do
    if [[ $line =~ $form ]]; then line=$("$@"); fi
    lines+=("$line")
  done <"$file"
  printf '%s\n' "${lines[@]}" >"$file"
}

# system_path_line SYSTEM_PATH: print the line of env.sh that sets
# SYSTEM_PATH, which may hold any character.
system_path_line() {
  local system_path=$1
  printf 'readonly SYSTEM_PATH=%q\n' "$system_path"
}

# system_path_of FILE: print the SYSTEM_PATH that FILE, an env.sh, sets.
system_path_of() {
  local file=$1
  # shellcheck disable=SC2016 # code for the other bash, not expanded here
  env -i "$BASH" --noprofile --norc -c 'source "$1" && printf "%s\n" "$SYSTEM_PATH"' \
    bash "$file"
}

# use_test_interpreters FILE: the line of FILE, a run-step.sh, that runs the
# step runs ENV, the env on PATH, and BASH instead of those of the runner.
use_test_interpreters() {
  local file=$1 env exec_line
  env=$(type -P env) && [[ $env == /* ]] || copy_error "no env on PATH"
  rewrite_lines "$file" "$RUNNER_EXEC_LINE_FORM" test_exec_line "$env"
  printf -v exec_line 'exec %q -i ' "$env"
  grep -qF -- "$exec_line" "$file" || copy_error "cannot set the bash and env of $file"
}

# test_exec_line ENV: print the line of run-step.sh that runs the step, with
# the arguments of BASH_REMATCH, through ENV and BASH.
test_exec_line() {
  local env=$1
  printf 'exec %q -i %s %q -p %s\n' "$env" "${BASH_REMATCH[1]}" "$BASH" "${BASH_REMATCH[2]}"
}
