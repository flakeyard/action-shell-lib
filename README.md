# action-shell-lib

A composite GitHub Action that gives flakeyard actions and workflows one shared
library of shell scripts.

The action is not released yet; its usage is described here with the first
release.

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
