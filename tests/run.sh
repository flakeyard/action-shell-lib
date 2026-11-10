#!/usr/bin/env bash
# Unit tests of the library, with the harness and stubs of internal/testing.
# tests/unit mirrors the repository: one suite per module, one per stub of
# internal/testing/bin, and static tests of action.yml, which need yq.
# Usage: tests/run.sh
# shellcheck source-path=SCRIPTDIR
set -uo pipefail
shopt -s globstar

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck disable=SC2034 # read by internal/testing/checks.sh
code_root=$root
# shellcheck source=../internal/testing/case.sh
source "$root/internal/testing/case.sh"
# shellcheck source=../internal/testing/checks.sh
source "$root/internal/testing/checks.sh"
# shellcheck source=../internal/testing/fixtures.sh
source "$root/internal/testing/fixtures.sh"
# shellcheck source=../internal/testing/yaml.sh
source "$root/internal/testing/yaml.sh"
# shellcheck source=../internal/testing/consumer/library.sh
source "$root/internal/testing/consumer/library.sh"
# shellcheck source=../internal/testing/consumer/action.sh
source "$root/internal/testing/consumer/action.sh"
# shellcheck source=lib/hostile.sh
source "$root/tests/lib/hostile.sh"

for suite in "$root"/tests/unit/**/*.sh; do
  # shellcheck source=/dev/null
  source "$suite"
done

conclude
