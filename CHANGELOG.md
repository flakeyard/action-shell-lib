# Changelog

## [0.3.0](https://github.com/flakeyard/action-shell-lib/compare/v0.2.0...v0.3.0) (2026-11-12)


### Features

* find a tool on the PATH of the job with job_tool ([#38](https://github.com/flakeyard/action-shell-lib/issues/38)) ([8021e0d](https://github.com/flakeyard/action-shell-lib/commit/8021e0d88b97d995c16919527c6e77969e48f019))


### Bug Fixes

* check internal actions that get the library as an input ([#41](https://github.com/flakeyard/action-shell-lib/issues/41)) ([bda3499](https://github.com/flakeyard/action-shell-lib/commit/bda349958fb513573a932b8fe510765945d8bfd3))
* run the steps of a copy of the library with the bash of the tests ([#39](https://github.com/flakeyard/action-shell-lib/issues/39)) ([f9a8ee0](https://github.com/flakeyard/action-shell-lib/commit/f9a8ee0bc22bf4afa5d6a01320e7cf8909f50910))
* share the runs of a step as its run line runs it in internal/testing ([#40](https://github.com/flakeyard/action-shell-lib/issues/40)) ([bf5ee91](https://github.com/flakeyard/action-shell-lib/commit/bf5ee91fc0363db0547c9dc33ff2603090ef35d1))

## [0.2.0](https://github.com/flakeyard/action-shell-lib/compare/v0.1.4...v0.2.0) (2026-11-12)


### Features

* pass further gh arguments on in api_get ([#36](https://github.com/flakeyard/action-shell-lib/issues/36)) ([d76b728](https://github.com/flakeyard/action-shell-lib/commit/d76b7289cdcff847ca67424a93eaca5204d5778d))

## [0.1.4](https://github.com/flakeyard/action-shell-lib/compare/v0.1.3...v0.1.4) (2026-11-11)


### Bug Fixes

* find the modules of run-step.sh from $0, not BASH_SOURCE ([#31](https://github.com/flakeyard/action-shell-lib/issues/31)) ([c11a38f](https://github.com/flakeyard/action-shell-lib/commit/c11a38f840fec198da47fd5bfdc96164a23dd6db))

## [0.1.3](https://github.com/flakeyard/action-shell-lib/compare/v0.1.2...v0.1.3) (2026-11-10)


### Bug Fixes

* let the gh stub serve the tests of the organization scripts ([#19](https://github.com/flakeyard/action-shell-lib/issues/19)) ([87c709a](https://github.com/flakeyard/action-shell-lib/commit/87c709a5c41e4ac917c51e24f5cc904b77501334))
* share the static tests of workflows in internal/testing ([#18](https://github.com/flakeyard/action-shell-lib/issues/18)) ([b247190](https://github.com/flakeyard/action-shell-lib/commit/b24719013c88f868ea5b5b05e6b84a8b51df0537))

## [0.1.2](https://github.com/flakeyard/action-shell-lib/compare/v0.1.1...v0.1.2) (2026-11-10)


### Bug Fixes

* give path or reject the runner also after a failure or cancellation ([#16](https://github.com/flakeyard/action-shell-lib/issues/16)) ([d1a6600](https://github.com/flakeyard/action-shell-lib/commit/d1a6600402f6eb64860075c4f82aea660f9e628a))

## [0.1.1](https://github.com/flakeyard/action-shell-lib/compare/v0.1.0...v0.1.1) (2026-11-10)


### Bug Fixes

* retry more transient network errors in api_request ([#13](https://github.com/flakeyard/action-shell-lib/issues/13)) ([cd6d94c](https://github.com/flakeyard/action-shell-lib/commit/cd6d94c9ea83df96032d85e36fd7263f7d6d579b))
* share the copy of the library and the static tests of consumers ([#12](https://github.com/flakeyard/action-shell-lib/issues/12)) ([ac80e14](https://github.com/flakeyard/action-shell-lib/commit/ac80e1423897cf37ef229141f70b90c35079f64c))

## 0.1.0 (2026-11-10)


### Features

* add report.sh for annotations and the job summary ([#7](https://github.com/flakeyard/action-shell-lib/issues/7)) ([d13418c](https://github.com/flakeyard/action-shell-lib/commit/d13418cc763a871b4a4f8530420f52113e2ef563))
* add run-step.sh and env.sh for steps in a clean environment ([#9](https://github.com/flakeyard/action-shell-lib/issues/9)) ([e0a31d0](https://github.com/flakeyard/action-shell-lib/commit/e0a31d09c190c724d668cf9bb707d13180de4d45))
* add the action that gives the directory of the library ([#5](https://github.com/flakeyard/action-shell-lib/issues/5)) ([ef55e96](https://github.com/flakeyard/action-shell-lib/commit/ef55e9668cde16e3c46a850064665e8c510f066a))
* add the modules of the GitHub API, contents and forms ([#8](https://github.com/flakeyard/action-shell-lib/issues/8)) ([425df52](https://github.com/flakeyard/action-shell-lib/commit/425df526d7326aa8114069c0ea849d31a05427e9))
