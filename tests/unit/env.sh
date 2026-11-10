# shellcheck shell=bash
# Tests of env.sh.

# environment_of_step: step_environment, then print what it set.
environment_of_step() {
  step_environment
  declare -p PATH LC_ALL JOB_PATH
  if shopt -q inherit_errexit; then echo "inherit_errexit on"; fi
}

setup
apply PATH=/job/bin
run_lib "env: the tools of the runner, the job's PATH kept" ok env.sh environment_of_step
# The runner's PATH is restated as an independent oracle.
expect message 'declare -x PATH="/usr/sbin:/usr/bin:/sbin:/bin"'
expect message 'declare -x LC_ALL="C"'
expect message 'declare -- JOB_PATH="/job/bin"'
expect message "inherit_errexit on"
finish
