# shellcheck shell=bash
# Tests of report.sh: untrusted text cannot start a workflow command or leave
# a code span, and a step writes at most 10 annotations of each kind.

lib=report.sh

setup
run_lib "report: an error ends at the end of its line" fail "$lib" \
  fail $'bad title\n::warning::forged\r'
expect stdout '::error::bad title%0A::warning::forged%0D'
finish

setup
run_lib "report: percent signs are escaped first" ok "$lib" notice '100%0A'
expect stdout '::notice::100%250A'
finish

setup
run_lib "report: a message with :: stays one command" ok "$lib" notice 'foo::bar::baz'
expect stdout '::notice::foo::bar::baz'
finish

setup
run_lib "report: errors do not exit" ok "$lib" error one
expect stdout '::error::one'
finish

setup
run_lib "report: a warning" ok "$lib" warning one
expect stdout '::warning::one'
finish

setup
run_lib "report: a property ends at a comma or a colon" ok "$lib" \
  escape_property $'a,b:c%d\r\n::x'
expect stdout 'a%2Cb%3Ac%25d%0D%0A%3A%3Ax'
finish

setup
run_lib "report: an annotation escapes its file, title and message" ok "$lib" \
  error $'m%e\r\n::warning::s' $'f,1:2' $'t,i:t\nle'
expect stdout '::error file=f%2C1%3A2,title=t%2Ci%3At%0Ale::m%25e%0D%0A::warning::s'
finish

setup
run_lib "report: an annotation of a file" ok "$lib" warning m f
expect stdout '::warning file=f::m'
finish

setup
run_lib "report: an annotation with a title only" ok "$lib" notice m "" t
expect stdout '::notice title=t::m'
finish

setup
run_lib "report: a failure names its file" fail "$lib" fail m f
expect stdout '::error file=f::m'
finish

# annotations KIND COUNT [WHERE]: COUNT annotations of KIND, then flush.
annotations() {
  local kind=$1 count=$2 where=${3-} i
  for ((i = 1; i <= count; i++)); do "$kind" "m$i" f; done
  flush "$where"
}

setup
run_lib "report: ten errors are all written" ok "$lib" annotations error 10
expect errors 10
expect message "::error file=f::m10"
finish

setup
run_lib "report: eleven errors are nine and how many more" ok "$lib" \
  annotations error 11 "the job summary lists them"
expect errors 10
expect message "::error file=f::m9"
expect no-message "::m10"
expect message "::error::2 more errors are not shown here; the job summary lists them."
finish

setup
run_lib "report: eleven notices without where" ok "$lib" annotations notice 11
expect notices 10
expect message "::notice::2 more notices are not shown here."
finish

# warnings_and_an_error: twelve warnings, one error, then flush.
warnings_and_an_error() {
  local i
  for i in {1..12}; do warning "w$i"; done
  error e
  flush
}

setup
run_lib "report: each kind has its own count" ok "$lib" warnings_and_an_error
expect warnings 10
expect errors 1
expect message "::warning::3 more warnings are not shown here."
finish

# flush_twice: eleven errors, then flush twice.
flush_twice() {
  annotations error 11
  flush
}

setup
run_lib "report: the last annotation is written once" ok "$lib" flush_twice
expect errors 10
finish

# nine_then_fail: nine errors, then a failure.
nine_then_fail() {
  local i
  for i in {1..9}; do error "e$i"; done
  fail last
}

setup
run_lib "report: a failure after nine errors is the tenth" fail "$lib" nine_then_fail
expect errors 10
expect message "::error::last"
finish

setup
run_lib "report: a code span keeps one line and its cell" ok "$lib" \
  code_span $'a`b|c\nd\re'
expect stdout "\`a'b\\|c d e\`"
finish

setup
run_lib "report: the summary gets one line" ok "$lib" summary '| a |' b
expect summary '| a | b'
finish

# The state of report.sh as an earlier step of the job can preset it in the
# environment: commands in arithmetic, and counts, held annotations and flags
# that would hide or forge annotations. @work is the directory of the test.
# shellcheck disable=SC2016 # code for the module, not expanded here
readonly HOSTILE_STATE=(
  '_report_count_error=a[$(touch @work/ran)]' '_report_count_warning=9'
  '_report_count_notice=a[$(touch @work/ran)]'
  '_report_held_error=::error::forged' '_report_held_warning=::warning::forged'
  '_report_flushed_error=1' '_report_flushed_warning=1' 'problems=1'
  '_REPORT_KINDS=a[$(touch @work/ran)]' '_REPORT_STATE=a[$(touch @work/ran)]'
  'ANNOTATIONS_PER_KIND=a[$(touch @work/ran)]'
)

# eleven_of_each: eleven annotations of each kind, then flush; fails when a
# problem was reported.
eleven_of_each() {
  ! has_problems || return 1
  annotations error 11
  annotations warning 11
  annotations notice 11
}

setup
apply "${HOSTILE_STATE[@]//@work/$work}"
run_lib "report: the environment cannot run code, hide or forge annotations" ok \
  "$lib" eleven_of_each
expect errors 10
expect warnings 10
expect notices 10
expect message "::warning::2 more warnings are not shown here."
expect no-message "forged"
[[ -z $current || ! -e $work/ran ]] || report "the environment ran a command"
finish

# problem_is_reported: has_problems is false until a problem, then true.
problem_is_reported() {
  ! has_problems && problem one && has_problems
}

setup
run_lib "report: has_problems after a problem" ok "$lib" problem_is_reported
expect stdout '::error::one'
finish
