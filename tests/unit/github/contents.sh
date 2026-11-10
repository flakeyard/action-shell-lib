# shellcheck shell=bash
# Tests of github/contents.sh.

lib=github/contents.sh

setup
apply REPO=o/r
file_fixture o/r a.json aaa $'{\n  "a": 1\n}\n'
run_lib "contents: a file is decoded" ok "$lib" file_at a.json aaa
expect stdout $'{\n  "a": 1\n}'
finish

# File names and refs that are not a path of a URL as they are; the encoded
# form is restated as an independent oracle.
while IFS='|' read -r name ref encoded_name encoded_ref; do
  setup
  apply REPO=o/r
  file_fixture o/r "$encoded_name" "$encoded_ref" "x"
  run_lib "contents: '$name' at '$ref' is encoded" ok "$lib" file_at "$name" "$ref"
  expect stdout "x"
  finish
done <<'CASES'
.copier-answers#x.yml|aaa|.copier-answers%23x.yml|aaa
.copier-answers?x.yml|aaa|.copier-answers%3Fx.yml|aaa
.copier answers.yml|aaa|.copier%20answers.yml|aaa
.github/renovate.json|aaa|.github/renovate.json|aaa
a.json|v1&x=y|a.json|v1%26x%3Dy
CASES

# missing_is_not_found: file_at returns NOT_FOUND for a missing file.
missing_is_not_found() {
  local status=0
  file_at a.json aaa || status=$?
  ((status == NOT_FOUND))
}

setup
apply REPO=o/r
run_lib "contents: a missing file is NOT_FOUND" ok "$lib" missing_is_not_found
finish

setup
apply REPO=o/r
fixture "repos/o/r/contents/nix?ref=aaa" '[{"type":"file","name":"a.nix"}]'
run_lib "contents: a directory is an error" fail "$lib" file_at nix aaa
expect message "nix: not a file of at most 1 MB"
finish
