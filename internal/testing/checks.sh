# shellcheck shell=bash
# Runs of the code under test, and checks of what it did. Source this file
# after case.sh; it is not public API of the library (ADR-0001). The suite sets
# code_root, the directory that run and run_lib take paths in.
# shellcheck disable=SC2154 # work, env_vars and code_root come from the suite.

# outcome NAME EXPECTED STATUS: start test NAME, which exited with STATUS;
# EXPECTED is ok or fail.
outcome() {
  local name=$1 expected=$2 status=$3
  current=$name
  if [[ $expected == fail && $status -eq 0 ]] || [[ $expected == ok && $status -ne 0 ]]; then
    report "expected $expected, exit status $status: $(cat -- "$work/stdout" "$work/stderr")"
  fi
}

# run NAME EXPECTED SCRIPT [NAME=VALUE...] [-- ARG...]: run SCRIPT, a path in
# code_root, with only env_vars and the variables given; EXPECTED is ok or
# fail.
run() {
  local name=$1 expected=$2 script=$3 status=0 vars=() args=()
  shift 3
  while (($#)) && [[ $1 != -- ]]; do
    vars+=("$1")
    shift
  done
  (($#)) && shift && args=("$@")
  env -i "${env_vars[@]}" "${vars[@]}" "$code_root/$script" "${args[@]}" \
    >"$work/stdout" 2>"$work/stderr" || status=$?
  outcome "$name" "$expected" "$status"
}

# only_test_variables: export only the variables of env_vars.
only_test_variables() {
  local name
  for name in $(compgen -e); do unset -- "$name" 2>/dev/null; done
  export -- "${env_vars[@]}"
}

# run_lib NAME EXPECTED LIBS FUNCTION [ARG...]: source LIBS, paths in code_root
# separated by spaces, in a subshell with only the variables of env_vars
# exported, and run FUNCTION there; EXPECTED is ok or fail.
run_lib() {
  local name=$1 expected=$2 libs=$3 status=0
  shift 3
  (
    only_test_variables
    for lib in $libs; do
      # shellcheck source=/dev/null
      source "$code_root/$lib"
    done
    "$@"
  ) >"$work/stdout" 2>"$work/stderr" || status=$?
  outcome "$name" "$expected" "$status"
}

# expect_output NAME VALUE: the output NAME of the last run is VALUE.
expect_output() {
  local name=$1 expected=$2 value
  value=$(sed -n "s/^$name=//p" "$work/output")
  [[ $value == "$expected" ]] || report "output $name is '$value', expected '$expected'"
}

# expect_count KIND COUNT: the last run wrote COUNT annotations of KIND, such
# as error.
expect_count() {
  local kind=$1 expected=$2 count
  count=$(grep -c "^::${kind}[ :]" "$work/stdout")
  [[ $count == "$expected" ]] || report "$count ${kind}s, expected $expected: $(cat -- "$work/stdout")"
}

# expect KIND [VALUE...]: check the last run: an output, its stdout, its
# messages, the calls and sleeps of the stubs or the job summary.
expect() {
  [[ -n $current ]] || return 0
  case $1 in
    output) expect_output "$2" "$3" ;;
    stdout) [[ $(<"$work/stdout") == "$2" ]] || report "stdout is '$(<"$work/stdout")', expected '$2'" ;;
    message) grep -qF -- "$2" "$work/stdout" "$work/stderr" || report "no message '$2' in: $(cat -- "$work/stdout" "$work/stderr")" ;;
    no-message) ! grep -qF -- "$2" "$work/stdout" "$work/stderr" || report "unexpected message '$2'" ;;
    errors) expect_count error "$2" ;;
    warnings) expect_count warning "$2" ;;
    notices) expect_count notice "$2" ;;
    call) grep -qF -- "$2" "$work/calls" || report "no call '$2' in: $(paste -sd';' "$work/calls")" ;;
    no-call) ! grep -qF -- "$2" "$work/calls" || report "unexpected call '$2'" ;;
    no-calls) [[ ! -s $work/calls ]] || report "unexpected calls: $(paste -sd';' "$work/calls")" ;;
    sleeps) [[ $(paste -sd' ' "$work/sleeps") == "$2" ]] || report "slept '$(paste -sd' ' "$work/sleeps")', expected '$2'" ;;
    summary) grep -qF -- "$2" "$work/summary" || report "no '$2' in the summary: $(cat -- "$work/summary")" ;;
    *)
      echo "expect: unknown kind $1" >&2
      exit 2
      ;;
  esac
}
