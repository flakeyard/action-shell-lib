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
