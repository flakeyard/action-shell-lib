# shellcheck shell=bash
# A copy of the library for the tests of a consumer, whose steps then run only
# the tools that the tests choose. Source this file after case.sh; it is not
# public API of the library (ADR-0001).

# The library that this file belongs to.
TESTED_LIBRARY=$(cd -- "${BASH_SOURCE[0]%/*}/../../.." && pwd)
readonly TESTED_LIBRARY
# The line of env.sh that sets SYSTEM_PATH.
readonly SYSTEM_PATH_LINE_FORM='^readonly SYSTEM_PATH='

# copy_library DIR SYSTEM_PATH: a writable copy of the library in DIR, which
# must not exist, whose env.sh sets SYSTEM_PATH, such as the stubs of the
# tests and a directory of the host's tools. Exits 2 when it cannot, since the
# steps would then run the tools of the host.
copy_library() {
  local dir=$1 system_path=$2
  [[ ! -e $dir ]] || copy_error "$dir exists"
  { cp -R -- "$TESTED_LIBRARY" "$dir" && chmod -R u+w -- "$dir"; } \
    || copy_error "cannot copy $TESTED_LIBRARY"
  set_system_path "$dir/env.sh" "$system_path"
  [[ $(system_path_of "$dir/env.sh") == "$system_path" ]] \
    || copy_error "cannot set SYSTEM_PATH in $dir/env.sh"
}

# copy_error MESSAGE: exit 2 with MESSAGE about copy_library.
copy_error() {
  printf 'copy_library: %s\n' "$1" >&2
  exit 2
}

# set_system_path FILE SYSTEM_PATH: the line of FILE that sets SYSTEM_PATH
# sets it to SYSTEM_PATH, which may hold any character.
set_system_path() {
  local file=$1 system_path=$2 line lines=()
  while IFS= read -r line; do
    if [[ $line =~ $SYSTEM_PATH_LINE_FORM ]]; then
      printf -v line 'readonly SYSTEM_PATH=%q' "$system_path"
    fi
    lines+=("$line")
  done <"$file"
  printf '%s\n' "${lines[@]}" >"$file"
}

# system_path_of FILE: print the SYSTEM_PATH that FILE, an env.sh, sets.
system_path_of() {
  local file=$1
  # shellcheck disable=SC2016 # code for the other bash, not expanded here
  env -i "$BASH" --noprofile --norc -c 'source "$1" && printf "%s\n" "$SYSTEM_PATH"' \
    bash "$file"
}
