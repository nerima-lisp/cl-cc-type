# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

<!--
Heading format is fixed across the org:

    ## [X.Y.Z] - YYYY-MM-DD

release.yml extracts the section matching the pushed tag as the GitHub Release
body, so a heading that deviates makes the release fail.

This file was reconstructed from the git history on 2026-07-26; the repository
had no CHANGELOG before then. The 0.1.0 section below describes the state of
the tree as it will be tagged: the repository carries no git tags yet, and
cutting v0.1.0 is a separate step of the org migration.
-->

## [Unreleased]

### Added

- `docs/`: a Material for MkDocs site (`index`, `installation`, `quick-start`,
  `core-concepts`, `api-reference`, `development`, `changelog`), built with
  `mkdocs --strict` by `packages.docs` and gated by `checks.docs`.
- This changelog.
- `.github/workflows/`: the org's four workflows — `ci`, `docs`, `release`,
  `flake-update` — plus the shared `.github/actions/nix-setup` composite
  action, which pins the Nix installer and Cachix SHAs in one place.
- `flake.nix`: `checks.formatting` (treefmt/nixfmt), `checks.docs`, and
  `apps.test` (`nix run .#test`).

### Changed

- `cl-cc-type-test.asd` is merged into `cl-cc-type.asd`. The test system is
  renamed from `cl-cc-type-test` to `cl-cc-type/test`, and both `defsystem`
  names are now strings rather than a mix of keywords and strings.
- The test directory moved from `tests/` to `t/`, and the test entry point from
  `scripts/run-tests.lisp` to `run-tests.lisp` at the repository root.
- `run-tests.lisp` and `scripts/run-coverage.lisp` locate `cl-cc-ast` and
  `cl-weave` through `CL_SOURCE_REGISTRY` instead of the repository-private
  `CL_CC_AST_ROOT` and `CL_CC_TYPE_CL_WEAVE_ROOT` environment variables.
- `flake.nix`: nixpkgs tracks `nixos-unstable`; the declared systems are
  `x86_64-linux` and `aarch64-darwin` only; the package version is read from
  `cl-cc-type.asd` rather than hardcoded; `cl-cc-ast` and `cl-weave` are pinned
  instead of following their default branches; `packages.default` is built with
  `sbcl.buildASDFSystem`.
- `.asd` metadata is complete (eight fields on both systems) and `:author` is
  the org's canonical `takeokunn <bararararatty@gmail.com>`.

### Removed

- `scripts/run-compile-check.lisp` and `scripts/with-timeout.pl`. The compile
  gate is now `packages.default` (`sbcl.buildASDFSystem`), and the test timeout
  comes from coreutils `timeout`, so neither the script nor the Perl fallback
  has a caller.

## [0.1.0] - 2026-07-26

### Added

- The `cl-cc/type` type system, extracted from the `cl-cc` monorepo into a
  standalone ASDF system: kinds, multiplicity, Hindley–Milner inference with
  rank-N and bidirectional checking, type classes with dictionaries, algebraic
  effects, row polymorphism, subtyping with join/meet, a type specifier parser
  and printer, and `typecase` exhaustiveness checking.
- A single org-internal dependency, `cl-cc-ast`, used through its public API
  for the AST nodes that constraint collection and inference walk.
- An 884-case suite running on [cl-weave](https://github.com/nerima-lisp/cl-weave),
  the org's test framework.

### Changed

- The type system was reorganized from five broad files (`gradual`, `hkt`,
  `termination`, `type-classes`, `type-level`) into per-concern modules, so no
  source file spans several unrelated concepts.

### Removed

- `inference-tests`, `inference-forms-tests`, `inference-effect-tests`,
  `type-inference-tests` and `type-phase-tests` did not come across from the
  monorepo: they build their input ASTs with `lower-sexp-to-ast`, which lives
  in the monorepo's `parse` package and has no standalone repository yet.
- `type-2026-advanced-registry-tests` did not come across either: it is a
  governance meta-test over `docs/type-advanced.md` and the monorepo test
  framework's `*known-test-names*` registry, neither of which exists here.
