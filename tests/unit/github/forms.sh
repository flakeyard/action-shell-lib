# shellcheck shell=bash
# Tests of github/forms.sh.

lib=github/forms.sh

# matches NAME FORM: NAME matches the constant named FORM.
matches() {
  local name=$1 form=${!2}
  [[ $name =~ $form ]]
}

for name in flakeyard/renovate-config owner/.github owner/a.b owner/_x; do
  setup
  run_lib "forms: accepts the repository $name" ok "$lib" matches "$name" REPOSITORY_FORM
  finish
done

for name in owner/.. owner/. owner/... ../x owner owner/a/b "owner/a b" o_x/a; do
  setup
  run_lib "forms: rejects the repository $name" fail "$lib" matches "$name" REPOSITORY_FORM
  finish
done

for name in renovate-config .github a.b _x; do
  setup
  run_lib "forms: accepts the repository name $name" ok "$lib" matches "$name" REPOSITORY_NAME_FORM
  finish
done

for name in .. . ... a/b "a b" ""; do
  setup
  run_lib "forms: rejects the repository name '$name'" fail "$lib" matches "$name" REPOSITORY_NAME_FORM
  finish
done

for token in ghs_abc123 github_pat_A.b-c; do
  setup
  run_lib "forms: accepts the token $token" ok "$lib" matches "$token" TOKEN_FORM
  finish
done

# shellcheck disable=SC2016 # a dollar sign, not an expansion
for token in "" "a b" 'a$b' $'a\nb' "a:b"; do
  setup
  run_lib "forms: rejects the token '$token'" fail "$lib" matches "$token" TOKEN_FORM
  finish
done

for list in '["../x"]' '"owner/repo"' '[1]' ''; do
  setup
  run_lib "forms: $list is not a list of owner/repo" fail "$lib" is_repository_list "$list"
  finish
done

setup
run_lib "forms: a list of owner/repo" ok "$lib" is_repository_list '["a/b","Owner/Repo"]'
finish

setup
run_lib "forms: a list has a repository whatever its case" ok "$lib" \
  lists_repository '["a/b","Owner/Repo"]' owner/REPO
finish

setup
run_lib "forms: a list without the repository" fail "$lib" \
  lists_repository '["owner/repo-fork"]' owner/repo
finish

for list in '["owner/repo\n"]' '["x y\nowner/repo"]' '["owner/repo\nx y"]'; do
  setup
  run_lib "forms: a line break makes $list no list of owner/repo" fail "$lib" \
    is_repository_list "$list"
  finish
done
