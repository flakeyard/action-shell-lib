# shellcheck shell=bash
# Static tests of a consumer: the steps of its action.yml use the library as
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
# The shell of every other step, and its SHELL_LIB.
readonly STEP_SHELL='/usr/bin/bash --noprofile --norc -p -e -o pipefail {0}'
readonly STEP_LIBRARY='${{ steps.lib.outputs.path }}'
# The run line of every other step, for jq and for bash: the step is the first
# group and the variables that it gets, each after a space, the second.
readonly STEP_RUN_FORM='^/usr/bin/bash -p "\$SHELL_LIB/run-step\.sh" "\$GITHUB_ACTION_PATH/scripts/step" ([a-z-]+)(( [A-Z_][A-Z0-9_]*)*)$'

# check_action_steps JSON: test that JSON, action.yml as load_yaml prints it,
# has the library as its first step, with the id lib and pinned by commit, and
# that every other step runs its script through run-step.sh in STEP_SHELL, with
# SHELL_LIB from the library step and every other variable of its env named on
# its run line.
check_action_steps() {
  local action=$1
  yaml_check "$action" "action: the library is the first step, pinned by commit" \
    '.runs.steps[0] | .id == "lib" and (.uses | test($form))' --arg form "$LIBRARY_USES_FORM"
  yaml_check "$action" "action: every other step runs its script through run-step.sh" \
    '.runs.steps[1:] | all(.shell == $shell and .env.SHELL_LIB == $lib
    and (.run | test($run)))' \
    --arg shell "$STEP_SHELL" --arg lib "$STEP_LIBRARY" --arg run "$STEP_RUN_FORM"
  yaml_check "$action" "action: every step names its variables on its run line" \
    'all(.runs.steps[1:][]; (.run | split(" ")) as $words
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
