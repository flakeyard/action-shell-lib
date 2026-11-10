# shellcheck shell=bash
# Tests of internal/testing/case.sh.

setup
apply _hostile_name=v
run_lib "harness: apply gives any name, such as an internal one" ok "" printenv _hostile_name
expect stdout v
finish
