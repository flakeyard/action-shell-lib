# shellcheck shell=bash
# Tests of internal/testing/consumer/library.sh: the copy of a library, also a
# read-only one such as a copy in the Nix store, runs the tools of SYSTEM_PATH.
# shellcheck disable=SC2016 # code for the other bash, not expanded here
# shellcheck disable=SC2154 # root and work come from tests/run.sh and setup.

# The SYSTEM_PATH of env.sh, restated as an independent oracle.
readonly RUNNER_SYSTEM_PATH=/usr/sbin:/usr/bin:/sbin:/bin

# copy_from LIBRARY DIR SYSTEM_PATH: copy_library DIR SYSTEM_PATH of the
# consumer/library.sh in LIBRARY, in a bash of its own.
copy_from() {
  local library=$1 dir=$2 system_path=$3
  bash -c 'source "$1/internal/testing/consumer/library.sh" && copy_library "$2" "$3"' \
    bash "$library" "$dir" "$system_path"
}

# path_of_step LIBRARY: print the PATH that step_environment of LIBRARY sets.
path_of_step() {
  local library=$1
  bash -c 'source "$1/env.sh" && step_environment && printf "%s\n" "$PATH"' bash "$library"
}

setup
system_path="$work/stub dir:/a|b&c\$(touch $work/ran)"
run_lib "consumer library: the copy has SYSTEM_PATH" ok "" \
  copy_from "$root" "$work/copy" "$system_path"
run_lib "consumer library: the steps of the copy run its tools" ok "" \
  path_of_step "$work/copy"
expect stdout "$system_path"
[[ -z $current || -f $work/copy/run-step.sh ]] || report "no run-step.sh in the copy"
[[ -z $current || ! -e $work/ran ]] || report "SYSTEM_PATH ran a command"
run_lib "consumer library: the library keeps its SYSTEM_PATH" ok "" path_of_step "$root"
expect stdout "$RUNNER_SYSTEM_PATH"
finish

setup
mkdir "$work/copy"
run_lib "consumer library: the copy needs a new directory" fail "" \
  copy_from "$root" "$work/copy" /x
expect message "copy_library: $work/copy exists"
finish

setup
cp -R -- "$root" "$work/store"
chmod -R a-w -- "$work/store"
run_lib "consumer library: a read-only library gives a writable copy" ok "" \
  copy_from "$work/store" "$work/copy" /x
[[ -z $current || -w $work/copy/env.sh ]] || report "env.sh of the copy is read-only"
chmod -R u+w -- "$work/store"
finish

setup
cp -R -- "$root" "$work/changed"
sed -i -e 's/^readonly SYSTEM_PATH=/SYSTEM_PATH=/' "$work/changed/env.sh"
run_lib "consumer library: a library without the line of SYSTEM_PATH fails" fail "" \
  copy_from "$work/changed" "$work/copy" /x
expect message "copy_library: cannot set SYSTEM_PATH in $work/copy/env.sh"
finish

# The line of run-step.sh that runs the step, restated as an independent
# oracle: the library runs the env and bash of the runner.
readonly RUNNER_EXEC_LINE='exec /usr/bin/env -i "${vars[@]}" /usr/bin/bash -p "$step_dir/$step.sh"'

# test_interpreters_setup: setup with the bash of the tests and an env that
# records its calls in $work/env-ran, in a directory with a space first on
# PATH, and the step probe in $work/step, which prints its bash.
test_interpreters_setup() {
  local bin
  setup
  bin="$work/test bin"
  mkdir "$bin" "$work/step"
  ln -s -- "$BASH" "$bin/bash"
  printf '#!/bin/sh\necho env >>%q\nexec %q "$@"\n' "$work/env-ran" "$(type -P env)" >"$bin/env"
  chmod +x "$bin/env"
  printf '%s\n' 'printf "%s\n" "$BASH"' >"$work/step/probe.sh"
  apply PATH="$bin:$TESTING_BIN:$HOST_PATH" SHELL_LIB="$work/copy"
}

# step_of_copy COPY STEP_DIR STEP: run STEP_DIR/STEP.sh through run-step.sh of
# COPY, a copy of the library, as a step does.
step_of_copy() {
  local copy=$1 step_dir=$2 step=$3
  bash -p "$copy/run-step.sh" "$step_dir" "$step"
}

test_interpreters_setup
run_lib "consumer library: the copy runs the bash and env of the tests" ok "" \
  copy_from "$root" "$work/copy" /x
run_lib "consumer library: the steps of the copy run in the bash of the tests" ok "" \
  step_of_copy "$work/copy" "$work/step" probe
expect stdout "$work/test bin/bash"
[[ -z $current || -s $work/env-ran ]] || report "the step ran another env"
grep -qxF -- "$RUNNER_EXEC_LINE" "$root/run-step.sh" || report "the library runs other interpreters"
finish

test_interpreters_setup
cp -R -- "$root" "$work/changed"
sed -i -e 's/^exec /exec  /' "$work/changed/run-step.sh"
run_lib "consumer library: a library without the line that runs the step fails" fail "" \
  copy_from "$work/changed" "$work/copy" /x
expect message "copy_library: cannot set the bash and env of $work/copy/run-step.sh"
finish
