# shellcheck shell=bash
# Static tests of action.yml (ADR-0001): one output, the path step in the
# hardened shell on the supported runners, and the rejection step on every
# other runner, whatever the status of the job.
# shellcheck disable=SC2016 # jq expressions and shell code, not expansions.
# shellcheck disable=SC2154 # work comes from setup.
# shellcheck disable=SC2034 # current is the test that report and finish count.

readonly HARDENED_SHELL='/usr/bin/bash --noprofile --norc -p -e {0}'
# The statuses of the job and the values of the runner context that the
# conditions are evaluated with.
readonly JOB_STATUSES=(success failure cancelled)
readonly RUNNER_OSES=(Linux macOS Windows)
readonly RUNNER_ENVIRONMENTS=(github-hosted self-hosted)
readonly RUNNER_ARCHES=(X64 ARM64 X86 ARM)
# A condition of a step, translated to jq, has only these characters.
readonly JQ_CONDITION_FORM='^[$a-z" =!()A-Z0-9_-]+$'
# A status function of GitHub; a condition without one holds only on success.
readonly STATUS_FUNCTION_FORM='(always|success|failure|cancelled)\(\)'

# jq_condition CONDITION: print CONDITION, an expression of GitHub over the
# runner context and the status functions, as a jq expression over $status,
# $os, $environment and $arch.
jq_condition() {
  local condition=$1
  [[ $condition =~ $STATUS_FUNCTION_FORM ]] || condition="success() && ($condition)"
  condition=${condition//always()/true}
  condition=${condition//success()/(\$status == \"success\")}
  condition=${condition//failure()/(\$status == \"failure\")}
  condition=${condition//cancelled()/(\$status == \"cancelled\")}
  condition=${condition//runner./\$}
  condition=${condition//\'/\"}
  condition=${condition//&&/and}
  condition=${condition//||/or}
  printf '%s\n' "${condition//$'\n'/ }"
}

# holds CONDITION STATUS OS ENVIRONMENT ARCH: CONDITION is true on that
# runner while the job has STATUS.
holds() {
  local condition
  condition=$(jq_condition "$1")
  [[ $condition =~ $JQ_CONDITION_FORM ]] || return 2
  jq -en --arg status "$2" --arg os "$3" --arg environment "$4" --arg arch "$5" \
    "$condition" >/dev/null
}

# is_supported STATUS OS ENVIRONMENT ARCH: a GitHub-hosted Linux runner on X64
# or ARM64, with any STATUS; restated as an independent oracle of the
# conditions.
is_supported() {
  [[ $2 == Linux && $3 == github-hosted && $4 =~ ^(X64|ARM64)$ ]]
}

# check_conditions PATH_IF REJECT_IF: on every runner and with every status
# of the job, the path step runs exactly when the runner is supported and the
# rejection step exactly otherwise.
check_conditions() {
  local path_if=$1 reject_if=$2 status os environment arch
  for status in "${JOB_STATUSES[@]}"; do
    for os in "${RUNNER_OSES[@]}"; do
      for environment in "${RUNNER_ENVIRONMENTS[@]}"; do
        for arch in "${RUNNER_ARCHES[@]}"; do
          check_runner "$path_if" "$reject_if" "$status" "$os" "$environment" "$arch"
        done
      done
    done
  done
}

# check_runner PATH_IF REJECT_IF STATUS OS ENVIRONMENT ARCH: one runner of
# check_conditions.
check_runner() {
  local path_if=$1 reject_if=$2 runner=("${@:3}") path=false reject=false
  if holds "$path_if" "${runner[@]}"; then path=true; fi
  if holds "$reject_if" "${runner[@]}"; then reject=true; fi
  if is_supported "${runner[@]}"; then
    [[ $path == true && $reject == false ]] || report "${runner[*]}: not only the path step"
  else
    [[ $path == false && $reject == true ]] || report "${runner[*]}: not only the rejection step"
  fi
}

setup
current="action: a condition without a status function holds only on success"
{
  holds "runner.os == 'Linux'" success Linux github-hosted X64 \
    && ! holds "runner.os == 'Linux'" cancelled Linux github-hosted X64
} || report "the condition is not GitHub's"
finish

if require_yq action.yml; then
  action=$(load_yaml action.yml)
  yaml_check "$action" "action: no inputs and one output, path" \
    '(has("inputs") | not) and (.outputs | keys) == ["path"]
    and .outputs.path.value == "${{ steps.path.outputs.path }}"'
  yaml_check "$action" "action: two steps" '.runs.steps | length == 2'
  yaml_check "$action" "action: the path step runs in the hardened shell" \
    '.runs.steps[0] | .id == "path" and .shell == $shell' --arg shell "$HARDENED_SHELL"
  yaml_check "$action" "action: the path step gets its directory only through env" \
    '.runs.steps[0] | .env == {"ACTION_DIR": "${{ github.action_path }}"}
    and (.run | contains("${{") | not)'
  yaml_check "$action" "action: the rejection step runs in the bash of the runner" \
    '.runs.steps[1] | .shell == "bash" and (has("env") | not)'
  yaml_check "$action" "action: both steps run whatever the status of the job" \
    '.runs.steps | all(.if | startswith("always() && "))'

  setup
  current="action: the steps run on complementary runners, with every status"
  check_conditions "$(jq -r '.runs.steps[0].if' <<<"$action")" \
    "$(jq -r '.runs.steps[1].if' <<<"$action")"
  finish

  setup
  jq -r '.runs.steps[1].run' <<<"$action" >"$work/reject.sh"
  apply RUNNER_OS=Linux RUNNER_ARCH=X86 RUNNER_ENVIRONMENT=self-hosted
  run_lib "action: the rejection step names the runner and fails" fail "" \
    bash --noprofile --norc -e -o pipefail "$work/reject.sh"
  expect stdout "::error::Unsupported runner Linux/X86 (self-hosted): use a GitHub-hosted Linux runner on X64 or ARM64, such as ubuntu-24.04 or ubuntu-24.04-arm."
  finish
fi
