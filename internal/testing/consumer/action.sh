# shellcheck shell=bash
# Static tests of a consumer: the steps of its actions use the library as
# the README shows, and every use of the library in the repository names one
# commit. Source this file after case.sh and yaml.sh, and call its checks only
# when require_yq passes; it is not public API of the library (ADR-0001).
# shellcheck disable=SC2016 # jq and the text of action.yml, not expanded here
# shellcheck disable=SC2034 # current is the test that report and finish count.
# shellcheck disable=SC2154 # code_root comes from the suite.

# The library step, pinned by commit.
readonly LIBRARY_USES_FORM='^flakeyard/action-shell-lib@[0-9a-f]{40}$'
# A use of the library, pinned in any way; GitHub ignores the case of names.
readonly LIBRARY_ANY_USES_FORM='^flakeyard/action-shell-lib([@/]|$)'
# The shell of every step that runs a script.
readonly STEP_SHELL='/usr/bin/bash --noprofile --norc -p -e -o pipefail {0}'
# The SHELL_LIB of those steps: from the library step, or from the input
# shell-lib of an internal action of a reusable workflow.
readonly STEP_LIBRARY='${{ steps.lib.outputs.path }}'
readonly INPUT_LIBRARY='${{ inputs.shell-lib }}'
# The run line of every step that runs a script, for jq and for bash: the step
# is the first group and the variables that it gets, each after a space, the
# second.
readonly STEP_RUN_FORM='^/usr/bin/bash -p "\$SHELL_LIB/run-step\.sh" "\$GITHUB_ACTION_PATH/scripts/step" ([a-z-]+)(( [A-Z_][A-Z0-9_]*)*)$'
# Helpers of the checks of an action:
# - internal: the action gets the library as its input shell-lib.
# - script_steps: the steps that run scripts: every step with run of an
#   internal action, which may also use other actions, and every step after
#   the library step of any other.
# - library_path: the SHELL_LIB of those steps.
readonly ACTION_DEFS='
  def internal: .inputs // {} | has("shell-lib");
  def script_steps: if internal then .runs.steps | map(select(has("run")))
    else .runs.steps[1:] end;
  def library_path: if internal then $input_lib else $step_lib end;
'

# action_check ACTION FILE NAME FILTER [JQ_ARG...]: test "FILE: NAME":
# FILTER, a jq expression over ACTION, the JSON of the action FILE, with the
# helpers of ACTION_DEFS, is true.
action_check() {
  local action=$1 file=$2 name=$3 filter=$4
  shift 4
  yaml_check "$action" "$file: $name" "$ACTION_DEFS $filter" \
    --arg input_lib "$INPUT_LIBRARY" --arg step_lib "$STEP_LIBRARY" "$@"
}

# check_action_steps FILE: test that FILE, an action.yml in code_root, gets
# the library either as its first step, with the id lib and pinned by commit,
# or, as an internal action of a reusable workflow, as its required input
# shell-lib without a library step; and that every step that runs a script
# runs it through run-step.sh in STEP_SHELL, with SHELL_LIB from there and
# every other variable of its env named on its run line. An internal action
# may also use other actions; its steps with uses are not checked further.
# The names of the tests start with FILE.
check_action_steps() {
  local file=$1 action
  action=$(load_yaml "$file")
  action_check "$action" "$file" "the library is the first step, pinned by commit, or the input shell-lib" \
    'if internal then .inputs["shell-lib"].required == true
    and all(.runs.steps[]; .uses // "" | test($any; "i") | not)
    else .runs.steps[0] | .id == "lib" and (.uses | test($form)) end' \
    --arg form "$LIBRARY_USES_FORM" --arg any "$LIBRARY_ANY_USES_FORM"
  action_check "$action" "$file" "every step runs its script through run-step.sh" \
    'library_path as $lib | script_steps | all(.shell == $shell and .env.SHELL_LIB == $lib
    and (.run | test($run)))' --arg shell "$STEP_SHELL" --arg run "$STEP_RUN_FORM"
  action_check "$action" "$file" "every step names its variables on its run line" \
    'all(script_steps[]; (.run | split(" ")) as $words
    | all(.env // {} | keys[] | select(. != "SHELL_LIB"); IN($words[])))'
}

# library_uses: print every uses: of the library in the files of code_root
# where GitHub reads them, the action and the workflows and actions under
# .github, one per line.
library_uses() (
  cd -- "$code_root" || exit 2
  shopt -s globstar nullglob
  for file in action.y{a,}ml .github/workflows/*.y{a,}ml .github/actions/**/action.y{a,}ml; do
    [[ -f $file ]] || continue
    load_yaml "$file" | jq -r --arg form "$LIBRARY_ANY_USES_FORM" \
      '.. | .uses? // empty | strings | select(test($form; "i"))'
  done
)

# check_library_pins: test that the repository uses the library and that every
# uses: of it names the same commit.
check_library_pins() {
  local uses
  setup
  current="action: every use of the library names one commit"
  # Two or more lines, or none, do not match the form.
  uses=$(library_uses | sort -u)
  [[ $uses =~ $LIBRARY_USES_FORM ]] || report "uses: ${uses//$'\n'/, }"
  finish
}
