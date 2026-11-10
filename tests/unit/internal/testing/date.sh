# shellcheck shell=bash
# Tests of internal/testing/bin/date.

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
