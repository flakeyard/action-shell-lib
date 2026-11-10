# shellcheck shell=bash
# Tests of internal/testing/bin/date.
# shellcheck disable=SC2154 # work comes from setup.

date=internal/testing/bin/date

setup
fixed_time 2026-11-10T12:30:00Z
run "date stub: now is the fixed time" ok "$date" -- -u +%FT%T
expect stdout 2026-11-10T12:30:00
finish

setup
fixed_time 2026-11-10T12:30:00Z
run "date stub: a given time is the system's" ok "$date" -- -u -d @0 +%F
expect stdout 1970-01-01
finish

setup
run "date stub: now needs a fixed time" fail "$date" -- +%s
expect message "the test fixed no time"
finish

# Other sources of the date, each with a fixed time that must not apply:
# ARGUMENTS|EXPECTED, with @work for the directory of the test.
while IFS='|' read -r arguments expected; do
  setup
  fixed_time 2026-11-10T12:30:00Z
  touch -d 2001-02-03T00:00:00Z "$work/file"
  printf '%s\n' 2002-03-04T00:00:00Z >"$work/dates"
  read -ra args <<<"${arguments//@work/$work}"
  run "date stub: $arguments is the system's" ok "$date" -- "${args[@]}"
  expect stdout "$expected"
  finish
done <<'CASES'
-u -r @work/file +%F|2001-02-03
-u --reference=@work/file +%F|2001-02-03
-ur @work/file +%F|2001-02-03
-u -f @work/dates +%F|2002-03-04
-u --file=@work/dates +%F|2002-03-04
-u --date=@0 +%F|1970-01-01
CASES
