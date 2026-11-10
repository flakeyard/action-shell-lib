# shellcheck shell=bash
# Static tests of action.yml (ADR-0001): one output, the path step in the
# hardened shell on the supported runners, and the rejection step on every
# other runner.
# shellcheck disable=SC2016 # jq expressions and shell code, not expansions.
# shellcheck disable=SC2154 # work comes from setup.
# shellcheck disable=SC2034 # current is the test that report and finish count.

readonly HARDENED_SHELL='/usr/bin/bash --noprofile --norc -p -e {0}'
# The values of the runner context that the conditions are evaluated with.
readonly RUNNER_OSES=(Linux macOS Windows)
readonly RUNNER_ENVIRONMENTS=(github-hosted self-hosted)
readonly RUNNER_ARCHES=(X64 ARM64 X86 ARM)
# A condition of a step, translated to jq, has only these characters.
readonly JQ_CONDITION_FORM='^[$a-z" =!()A-Z0-9_-]+$'

# jq_condition CONDITION: print CONDITION, an expression of GitHub over the
# runner context, as a jq expression over $os, $environment and $arch.
jq_condition() {
  local condition=$1
  condition=${condition//runner./\$}
  condition=${condition//\'/\"}
  condition=${condition//&&/and}
  condition=${condition//||/or}
  printf '%s\n' "${condition//$'\n'/ }"
}

# holds CONDITION OS ENVIRONMENT ARCH: CONDITION is true on that runner.
holds() {
  local condition
  condition=$(jq_condition "$1")
  [[ $condition =~ $JQ_CONDITION_FORM ]] || return 2
  jq -en --arg os "$2" --arg environment "$3" --arg arch "$4" "$condition" >/dev/null
}

# is_supported OS ENVIRONMENT ARCH: a GitHub-hosted Linux runner on X64 or
# ARM64; restated as an independent oracle of the conditions.
is_supported() {
  [[ $1 == Linux && $2 == github-hosted && $3 =~ ^(X64|ARM64)$ ]]
}

# check_conditions PATH_IF REJECT_IF: on every runner, the path step runs
# exactly when it is supported and the rejection step exactly otherwise.
check_conditions() {
  local path_if=$1 reject_if=$2 os environment arch
  for os in "${RUNNER_OSES[@]}"; do
    for environment in "${RUNNER_ENVIRONMENTS[@]}"; do
      for arch in "${RUNNER_ARCHES[@]}"; do
        check_runner "$path_if" "$reject_if" "$os" "$environment" "$arch"
      done
    done
  done
}

# check_runner PATH_IF REJECT_IF OS ENVIRONMENT ARCH: one runner of
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

  setup
  current="action: the steps run on complementary runners"
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
