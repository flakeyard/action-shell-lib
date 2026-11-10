# shellcheck shell=bash
# The forms of names and tokens of GitHub, as actions read them from inputs
# and files, and lists of repositories as JSON.

# Sourcing this file twice defines its read-only constants once. A variable of
# the environment with the same name is not read-only, and the constant
# replaces it.
[[ $(declare -p REPOSITORY_NAME_FORM 2>/dev/null) != "declare -r"* ]] || return 0

# The name of a repository as GitHub allows it. It needs a character other
# than a dot: ".." or "." would change the path of an API call.
readonly REPOSITORY_NAME_FORM='^[A-Za-z0-9._-]*[A-Za-z0-9_-][A-Za-z0-9._-]*$'
# owner/repo, with the name of REPOSITORY_NAME_FORM.
readonly REPOSITORY_FORM="^[A-Za-z0-9-]+/${REPOSITORY_NAME_FORM#^}"
# A GitHub token as GitHub issues them; nothing else may be printed or passed.
# shellcheck disable=SC2034 # read by the scripts that source this file
readonly TOKEN_FORM='^[A-Za-z0-9_.-]+$'

# is_repository_list JSON: JSON is an array of owner/repo. In jq, "$" also
# matches before a final line break, so the form is anchored with \A and \z.
is_repository_list() {
  local list=$1
  jq -e --arg form "$REPOSITORY_FORM" \
    '("\\A" + ($form | ltrimstr("^") | rtrimstr("$")) + "\\z") as $whole
    | type == "array" and all(.[]; type == "string" and test($whole))' \
    <<<"$list" >/dev/null 2>&1
}

# lists_repository LIST REPOSITORY: the JSON array LIST has REPOSITORY,
# compared without case as GitHub does.
lists_repository() {
  local list=$1 repository=$2
  jq -e --arg repository "$repository" \
    'any(.[]; ascii_downcase == ($repository | ascii_downcase))' \
    <<<"$list" >/dev/null
}
