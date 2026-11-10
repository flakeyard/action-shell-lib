# shellcheck shell=bash source-path=SCRIPTDIR
# Files of the repository REPO at a commit, read through the contents API.

# shellcheck source=api.sh
source "${BASH_SOURCE[0]%/*}/api.sh"

# A segment of a path that the API would resolve or drop: empty, "." or "..".
readonly _CONTENTS_BAD_SEGMENT='(^|/)(\.{0,2})(/|$)'

# _contents_check_path PATH: fail, after printing why, when PATH has a segment
# that is empty, "." or "..".
_contents_check_path() {
  local path=$1
  [[ ! $path =~ $_CONTENTS_BAD_SEGMENT ]] && return 0
  printf "'%s' has an empty, '.' or '..' segment\n" "$path" >&2
  return 1
}

# _contents_path PATH REF: print the API path of the file PATH of REPO at REF,
# with every segment of PATH and REF percent-encoded, such as "#" or "?" of a
# file name, and the "/" between the segments kept.
_contents_path() {
  local path=$1 ref=$2
  jq -rn --arg repo "$REPO" --arg path "$path" --arg ref "$ref" \
    '"repos/\($repo)/contents/\($path | split("/") | map(@uri) | join("/"))?ref=\($ref | @uri)"'
}

# file_at PATH REF: print the file PATH of REPO, owner/repo, at the commit
# REF. Returns 0 on success, NOT_FOUND when the file does not exist and 1 on
# any other error, such as a directory, a file too large for the API or a PATH
# with an empty, "." or ".." segment, after printing it on stderr.
file_at() {
  local path=$1 ref=$2 body status=0
  _contents_check_path "$path" || return 1
  body=$(api_request GET "$(_contents_path "$path" "$ref")") || status=$?
  ((status == 0)) || return "$status"
  jq -e '.type == "file" and .encoding == "base64"' <<<"$body" >/dev/null || {
    printf '%s: not a file of at most 1 MB\n' "$path" >&2
    return 1
  }
  jq -r .content <<<"$body" | base64 -d
}
