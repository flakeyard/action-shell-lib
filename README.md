# action-shell-lib

A composite GitHub Action that gives flakeyard actions and workflows one shared
library of shell scripts.

## Usage

```yaml
steps:
  - id: shell-lib
    uses: flakeyard/action-shell-lib@<commit> # vX.Y.Z
  - shell: /usr/bin/bash --noprofile --norc -p -e -o pipefail {0}
    env:
      SHELL_LIB: ${{ steps.shell-lib.outputs.path }}
    run: /usr/bin/bash -p "$GITHUB_ACTION_PATH/scripts/check.sh"
```

```bash
# shellcheck source=/dev/null
source "$SHELL_LIB/report.sh"
```

Reference the action by full commit SHA, as above, and name the same commit in
every `uses:` of it in one repository. Tests that need the library without a
runner fetch it at that commit, which they read from the file that pins it.

## Runner requirements

GitHub-hosted Linux runners on x86_64 or arm64, such as `ubuntu-24.04` and
`ubuntu-24.04-arm`, with `/usr/bin/bash` 5.2 or later. On any other runner,
self-hosted ones included, the action writes an error that names the runner and
fails the job, so that no later step sources the library there.

## API

The action has no inputs and one output:

- `path`: the directory of the library, an absolute path. Pass it to the steps
  that use the library as the environment variable `SHELL_LIB`.

The modules below are the public API ([ADR-0001][adr-0001]): their paths, under
`path`, and for each function, constant and script its name, arguments, output,
return codes and the variables it reads and writes. A sourced module defines
only functions and read-only constants: it sets no shell options, traps or
`PATH`, runs no command and writes no file when it is sourced, and sourcing it
twice is harmless. Functions print results on stdout and diagnostics on stderr
or as annotations, and run only bash builtins, coreutils, `grep`, `sed`, `gh`
and `jq` from the `PATH` of the calling step.

Functions and variables whose names start with `_`, and everything under
`internal/`, are not public API: a release may change them without notice.

### `report.sh`

Workflow commands and the job summary of a step. Every message is escaped with
`escape_command` and every property with `escape_property`, so text that others
choose cannot end a workflow command and start another. GitHub keeps at most 10
annotations of each kind per step, so a step writes at most 10 of each kind: the
first 9 at once, and the 10th at `flush`, which writes it when it is the last of
its kind and otherwise one that says how many more there are. The counts are
kept in variables whose names the module chooses at random when it is first
sourced, so the environment of the step cannot preset them.

- `ANNOTATIONS_PER_KIND`: `10`, the annotations of each kind that a step writes,
  the last one included.
- `escape_command TEXT`: prints `TEXT` as the message of one workflow command,
  with `%`, CR and LF escaped. Returns 0.
- `escape_property TEXT`: prints `TEXT` as a property of one workflow command,
  such as a file or a title: also `,` and `:` escaped. Returns 0.
- `error MESSAGE [FILE [TITLE]]`, `warning MESSAGE [FILE [TITLE]]` and
  `notice MESSAGE [FILE [TITLE]]`: write an annotation of that kind, about
  `FILE` and with `TITLE` when they are not empty, within
  `ANNOTATIONS_PER_KIND`. Return 0.
- `problem MESSAGE [FILE [TITLE]]`: `error`; `has_problems` is then true, so
  that the step can fail at its end. Returns 0.
- `has_problems`: returns 0 when `problem` has reported an error in this shell,
  and 1 otherwise. Prints nothing.
- `flush [WHERE]`: for each kind that reached `ANNOTATIONS_PER_KIND`, writes the
  held annotation or one that says how many more there are and `WHERE` they are
  listed, such as `the job summary lists them`; once per kind. A step that may
  write 10 annotations of a kind calls it as it ends. Returns 0.
- `fail MESSAGE [FILE [TITLE]]`: `error`, then `flush`, then exits 1.
- `summary TEXT...`: appends the arguments, joined by spaces, as one line to the
  file `GITHUB_STEP_SUMMARY`, or to nothing when it is not set. Returns 0.
- `code_span TEXT`: prints `TEXT` as inline code of the job summary, which stays
  one line and one table cell and renders as no link or markup: line breaks
  become spaces, `` ` `` becomes `'` and `|` is escaped. Returns 0.

### `github/api.sh`

Calls of the GitHub API through the `gh` on `PATH`, which takes its token from
the environment that the calling step sets.

- `NOT_FOUND`: `3`, the status of `api_request` when the resource does not
  exist.
- `api_request METHOD PATH [ARG...]`: runs `gh api -X METHOD PATH ARG...` and
  prints the response body. A server error, HTTP 429, a lost connection and the
  GraphQL error `RATE_LIMITED` are retried, 3 attempts in all, after 5 and then
  10 seconds. Returns 0 on success, `NOT_FOUND` for HTTP 404, and 1 on any other
  error, after printing it on stderr.
- `api_get PATH`: `api_request GET PATH`. Returns 0 on success and 1 on any
  error, also when the resource does not exist, after printing it on stderr.

### `github/contents.sh`

Files of a repository at a commit, through the contents API. Sources
`github/api.sh`.

- `file_at PATH REF`: prints the file `PATH` of the repository `REPO`, as
  `owner/repo`, at the commit `REF`; reads `REPO`. Every segment of `PATH`, and
  `REF`, is percent-encoded. Returns 0 on success, `NOT_FOUND` when the file
  does not exist, and 1 on any other error, such as a directory or a file larger
  than 1 MB, after printing it on stderr.

### `github/forms.sh`

Names and tokens of GitHub as actions read them from inputs and files.

- `REPOSITORY_NAME_FORM`: an extended regular expression for the name of a
  repository; it needs a character other than a dot, since `.` or `..` would
  change the path of an API call.
- `REPOSITORY_FORM`: an extended regular expression for `owner/repo`, with the
  name of `REPOSITORY_NAME_FORM`.
- `TOKEN_FORM`: an extended regular expression for a token as GitHub issues
  them.
- `is_repository_list JSON`: returns 0 when `JSON` is an array of
  `REPOSITORY_FORM` strings, and 1 otherwise. Prints nothing.
- `lists_repository LIST REPOSITORY`: returns 0 when the JSON array `LIST` has
  `REPOSITORY`, compared without case as GitHub does, and 1 otherwise. Prints
  nothing.

## Development

The repository checks itself with [`test.yaml`](.github/workflows/test.yaml),
which calls [workflow-check][workflow-check] as its only job. The repository has
no flake yet, so workflow-check builds no checks; it checks the pull request
title, `renovate.json` and the release behind its preset tag, and reports
`check / required`. Before a pull request, run shellcheck, shfmt, actionlint,
zizmor, prettier, markdownlint, typos and `reuse lint`.

[`scorecard.yaml`](.github/workflows/scorecard.yaml) runs OpenSSF Scorecard with
[workflow-scorecard][workflow-scorecard]. The repository releases itself with
[workflow-release][workflow-release] through
[`release.yaml`](.github/workflows/release.yaml), whose release pull requests
are checked by a dispatched run of `test.yaml`. The design follows
[FY-0034][fy-0034] and [FY-0030][fy-0030].

Tests: `tests/run.sh` runs the unit tests in `tests/unit/`, which mirrors the
modules, with the harness, fixtures and stubs of `gh`, `date` and `sleep` in
`internal/testing/`, and static tests of `action.yml`, which cover the step that
rejects unsupported runners. It needs bash, coreutils, `grep`, `sed`, `jq` and
mikefarah `yq` v4, which GitHub-hosted runners have; elsewhere run
`nix shell nixpkgs#yq-go -c tests/run.sh`. `tests/ci/` holds the checks that a
job of the CI runs on real runners after the action. CI runs the unit tests with
the `bash` of the runner and the action on the supported runners.

## Bootstrap

Following [FY-0022][fy-0022], some checks of this repository are not released
yet. Until they are:

- shellcheck, shfmt, actionlint, zizmor, prettier, markdownlint, typos and REUSE
  run locally before every pull request; the atoms will provide them.
- The first release of this action runs on a workflow-release that does not use
  it yet; workflow-release and action-setup-nix adopt the library after that
  release ([FY-0035][fy-0035]).

## License

[MIT](LICENSE).

[adr-0001]: docs/adr/records/0001-shell-library.md
[workflow-check]: https://github.com/flakeyard/workflow-check
[workflow-release]: https://github.com/flakeyard/workflow-release
[workflow-scorecard]: https://github.com/flakeyard/workflow-scorecard
[fy-0022]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0022-bootstrap.md
[fy-0030]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0030-actions-workflows-and-release-bot.md
[fy-0034]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0034-check-every-repository-with-workflow-check.md
[fy-0035]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0035-extract-logic-that-has-two-users.md
