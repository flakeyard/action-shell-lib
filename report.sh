# shellcheck shell=bash
# Workflow commands and the job summary of a step. Messages often quote text
# that others choose, such as a pull request title or a file of a repository,
# so every message and property is escaped: it cannot end its workflow command
# and start another, and it cannot leave a code span of the summary.
#
# GitHub keeps at most 10 annotations of each kind per step. The first 9 of a
# kind are written at once; the 10th is held until flush, which writes it when
# it is the last one of its kind, or else one that says how many more there
# are. The counts live in variables that start with _report_.

# Sourcing this file twice defines its read-only constants once. A variable of
# the environment with the same name is not read-only, and the constant
# replaces it.
[[ $(declare -p ANNOTATIONS_PER_KIND 2>/dev/null) != "declare -r"* ]] || return 0

# The annotations of each kind that a step writes, the last one included.
readonly ANNOTATIONS_PER_KIND=10
readonly _REPORT_KINDS=(error warning notice)

# escape_command TEXT: print TEXT as the message of one workflow command.
escape_command() {
  local text=$1
  text=${text//%/%25}
  text=${text//$'\r'/%0D}
  text=${text//$'\n'/%0A}
  printf '%s\n' "$text"
}

# escape_property TEXT: print TEXT as a property of one workflow command, such
# as the title of an annotation: also "," and ":" end a property.
escape_property() {
  local text=$1
  text=$(escape_command "$text")
  text=${text//:/%3A}
  text=${text//,/%2C}
  printf '%s\n' "$text"
}

# _report_command KIND MESSAGE [FILE [TITLE]]: print the annotation of KIND
# with its properties and message escaped.
_report_command() {
  local kind=$1 message=$2 file=${3-} title=${4-} properties=() IFS=,
  [[ -z $file ]] || properties+=("file=$(escape_property "$file")")
  [[ -z $title ]] || properties+=("title=$(escape_property "$title")")
  local joined=${properties[*]}
  printf '::%s%s::%s\n' "$kind" "${joined:+ $joined}" "$(escape_command "$message")"
}

# _report_annotate KIND MESSAGE [FILE [TITLE]]: write or hold an annotation of
# KIND, within ANNOTATIONS_PER_KIND.
_report_annotate() {
  local kind=$1 count_var=_report_count_$1 count
  count=$((${!count_var:-0} + 1))
  printf -v "$count_var" '%s' "$count"
  if ((count < ANNOTATIONS_PER_KIND)); then
    _report_command "$@"
  elif ((count == ANNOTATIONS_PER_KIND)); then
    printf -v "_report_held_$kind" '%s' "$(_report_command "$@")"
  fi
}

# error MESSAGE [FILE [TITLE]]: report an error, about FILE and with TITLE if
# given, and go on.
error() { _report_annotate error "$@"; }

# warning MESSAGE [FILE [TITLE]]: report a warning.
warning() { _report_annotate warning "$@"; }

# notice MESSAGE [FILE [TITLE]]: report a notice.
notice() { _report_annotate notice "$@"; }

# problem MESSAGE [FILE [TITLE]]: report an error, go on, and set problems to
# 1, so that the step can fail at its end.
# shellcheck disable=SC2034 # The scripts that source this file read problems.
problem() {
  error "$@"
  problems=1
}

# _report_flush_kind KIND [WHERE]: the last annotation of KIND, once.
_report_flush_kind() {
  local kind=$1 where=${2-} count_var=_report_count_$1 held_var=_report_held_$1
  local flushed_var=_report_flushed_$1 more
  more=$((${!count_var:-0} - ANNOTATIONS_PER_KIND + 1))
  ((more >= 1)) || return 0
  [[ -z ${!flushed_var-} ]] || return 0
  printf -v "$flushed_var" '%s' 1
  if ((more == 1)); then
    printf '%s\n' "${!held_var}"
  else
    _report_command "$kind" "$more more ${kind}s are not shown here${where:+; $where}."
  fi
}

# flush [WHERE]: write the last annotation of each kind that reached
# ANNOTATIONS_PER_KIND: the held one, or how many more there are and WHERE
# they are listed, such as "the job summary lists them". A step that may write
# ANNOTATIONS_PER_KIND annotations of a kind calls it as it ends.
flush() {
  local where=${1-} kind
  for kind in "${_REPORT_KINDS[@]}"; do
    _report_flush_kind "$kind" "$where"
  done
}

# fail MESSAGE [FILE [TITLE]]: report an error, flush and exit 1.
fail() {
  error "$@"
  flush
  exit 1
}

# summary TEXT...: append TEXT, the arguments joined by spaces, as a line to
# the job summary.
summary() {
  printf '%s\n' "$*" >>"${GITHUB_STEP_SUMMARY:-/dev/null}"
}

# code_span TEXT: print TEXT as inline code of the job summary, also inside a
# table cell. It cannot leave the code span or the cell, so it renders as no
# link or markup.
code_span() {
  local text=$1 tick='`'
  text=${text//$'\n'/ }
  text=${text//$'\r'/ }
  text=${text//\`/\'}
  text=${text//|/\\|}
  printf '%s%s%s\n' "$tick" "$text" "$tick"
}
