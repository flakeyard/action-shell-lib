# shellcheck shell=bash
# Tests of internal/testing/bin/sleep.

setup
run "sleep stub: returns at once and records the call" ok internal/testing/bin/sleep -- 600
run "sleep stub: records every call" ok internal/testing/bin/sleep -- 1200
expect sleeps "600 1200"
finish
