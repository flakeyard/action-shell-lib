# shellcheck shell=bash
# Tests of env.sh.
# shellcheck disable=SC2154 # work comes from setup.

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

# tool_of_job DIR JOB_PATH NAME: job_tool NAME in the directory DIR, with
# JOB_PATH as step_environment sets it.
tool_of_job() {
  local dir=$1 job_path=$2 name=$3
  cd -- "$dir" || return 2
  JOB_PATH=$job_path
  job_tool "$name"
}

# tools_setup: setup with the executables a/tool and b/tool, b/other and the
# file a/other, which is not executable, in $work.
tools_setup() {
  setup
  mkdir "$work/a" "$work/b"
  touch "$work/a/tool" "$work/b/tool" "$work/b/other" "$work/a/other"
  chmod +x "$work/a/tool" "$work/b/tool" "$work/b/other"
}

tools_setup
run_lib "env: the first tool on the PATH of the job" ok env.sh \
  tool_of_job "$work" "$work/a:$work/b" tool
expect stdout "$work/a/tool"
finish

tools_setup
run_lib "env: an executable tool on the PATH of the job" ok env.sh \
  tool_of_job "$work" "$work/a:$work/b" other
expect stdout "$work/b/other"
finish

tools_setup
run_lib "env: no tool on the PATH of the job" fail env.sh \
  tool_of_job "$work" "$work/a:$work/b" none
expect stdout ""
expect message "job_tool: no none on the PATH of the job"
finish

tools_setup
run_lib "env: not the tool of a relative directory of the job PATH" fail env.sh \
  tool_of_job "$work" "a:$work/b" tool
expect stdout ""
expect message "job_tool: no tool on the PATH of the job"
finish

tools_setup
run_lib "env: not a tool given by its path" fail env.sh \
  tool_of_job "$work" "$work/b" "$work/a/tool"
expect stdout ""
expect message "job_tool: no $work/a/tool on the PATH of the job"
finish

tools_setup
# bash is on the PATH of the tests, not on this PATH of the job.
run_lib "env: not the tools of the PATH of the step" fail env.sh \
  tool_of_job "$work" "$work/a" bash
expect stdout ""
expect message "job_tool: no bash on the PATH of the job"
finish
