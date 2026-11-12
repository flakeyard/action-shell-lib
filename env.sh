# shellcheck shell=bash
# The environment of the script of a step: the tools of the runner, a fixed
# locale and strict mode also in command substitutions, and the tools of the
# job.

# Sourcing this file twice defines its read-only constants once. A variable of
# the environment with the same name is not read-only, and the constant
# replaces it.
[[ $(declare -p SYSTEM_PATH 2>/dev/null) != "declare -r"* ]] || return 0

# The tools of the runner.
readonly SYSTEM_PATH=/usr/sbin:/usr/bin:/sbin:/bin

# step_environment: keep the PATH of the job, which earlier steps can change,
# in JOB_PATH, and export PATH=SYSTEM_PATH and LC_ALL=C; set inherit_errexit,
# so that set -e also holds in command substitutions.
# shellcheck disable=SC2034 # read by the scripts that source this file
step_environment() {
  shopt -s inherit_errexit
  JOB_PATH=${PATH-}
  export PATH=$SYSTEM_PATH LC_ALL=C
}

# job_tool NAME: print the absolute path of the executable NAME, a command
# name without "/", that the PATH of the job, JOB_PATH, finds first, such as
# the nix that an earlier step installed. Fails with a message on stderr when
# there is none, or when the one found first is not absolute, since the
# directory of the step would then choose it.
job_tool() {
  local name=$1 path
  if [[ $name != */* ]] && path=$(PATH=${JOB_PATH-} type -P -- "$name") && [[ $path == /* ]]; then
    printf '%s\n' "$path"
  else
    printf 'job_tool: no %s on the PATH of the job\n' "$name" >&2
    return 1
  fi
}
