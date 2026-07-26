# Development

Everything below assumes Nix with flakes enabled. `nix flake check` is the gate
CI runs; if it passes locally it passes in CI, modulo the platform.

## Commands

```sh
nix develop          # SBCL with CL_SOURCE_REGISTRY already set
nix run .#test       # run the test suite
nix flake check      # tests + formatting + docs, the same gate CI uses
nix fmt              # format Nix sources (treefmt/nixfmt)
nix build .#docs     # render the documentation site
```

The flake declares two systems, `x86_64-linux` and `aarch64-darwin`. Both are
verified: the first by the CI runner, the second by running `nix flake check`
on the development machine. `aarch64-linux` and `x86_64-darwin` are
deliberately not declared, because nothing checks them.

## Layout

```
cl-cc-type.asd     both systems: cl-cc-type and cl-cc-type/test
src/               flat; every defpackage lives in src/package.lisp
t/                 the test suite
run-tests.lisp     the Lisp-level test entry point
scripts/           run-coverage.lisp
docs/              mkdocs.yml and src/
```

## Running the tests without Nix

`run-tests.lisp` registers this checkout and inherits the rest from
`CL_SOURCE_REGISTRY`. It does not guess at sibling checkout paths, so point the
variable at `cl-cc-ast` and `cl-weave` yourself:

```sh
export CL_SOURCE_REGISTRY="$PWD/../cl-cc-ast//:$PWD/../cl-weave//:$PWD//"
sbcl --noinform --script run-tests.lisp
```

The script exits non-zero when the suite fails, so it works as a gate directly.

## Coverage

`scripts/run-coverage.lisp` recompiles `src/` under SB-COVER instrumentation
and writes an HTML report to `coverage/report/`.

```sh
nix develop -c sbcl --noinform --script scripts/run-coverage.lisp
```

The recompile is not avoidable: SB-COVER only measures forms compiled while its
`store-coverage-data` optimize policy is proclaimed, so reusing the FASLs
`run-tests.lisp` left behind would report zero. `coverage/` is ignored by git.

Coverage is a report here, not a ratchet — nothing fails the build on a
regression. If that changes, the floor belongs in `run-tests.lisp` so that
`nix flake check` enforces it, not in a separate CI job.

## Adding a source file

`src/` is flat and `:serial t`, so a new file goes in `src/`, its exports go in
`src/package.lisp` next to the related group, and it is added to the
`:components` list of `cl-cc-type` at the point where its dependencies are
already loaded. The two ordering constraints that are not obvious from the
names are recorded as comments in the `.asd`: `channels` must precede
`actors`/`stm`/`coroutines`/`simd`, and `types-level-strings` must precede
`types-utility`.

## Adding a test

Tests go in `t/` and are named after the source file they cover:
`src/kind.lisp` is tested by `t/kind-test.lisp`. When one source file has
several distinct concerns, the concern goes in the middle —
`t/types-extended-nodes-test.lisp`, `t/types-extended-nodes-children-test.lisp`
and `t/types-extended-nodes-coverage-test.lisp` all cover
`src/types-extended-nodes.lisp`. Two files keep a broader name because no
single source file owns them: `t/type-system-test.lisp` and
`t/type-system-effect-test.lisp` run across representation, unification and
inference together.

Every file is added to the `:components` list of `cl-cc-type/test`, and tests
are written against [cl-weave](https://github.com/nerima-lisp/cl-weave) — the
org's test framework — using `it-sequential`, `it-each`, `expect`,
`expect-not` and `signals` directly. Do not introduce FiveAM, parachute, rove
or prove.

`t/package.lisp` defines `defbefore`, a thin forwarder that accepts the
suite-scope argument the monorepo's old framework took and that cl-weave's own
`before-each`/`before-all` do not. It exists so the migrated tests did not have
to be rewritten line by line; new tests should call cl-weave's forms directly.

## Tests that did not come across

Six test files from the monorepo are absent from `t/`. They are absent, not
disabled — there is no way to run them here, so there is nothing to re-enable.

| File | Why |
|---|---|
| `inference-tests` | Builds input ASTs with `lower-sexp-to-ast` |
| `inference-forms-tests` | Same |
| `inference-effect-tests` | Same |
| `type-inference-tests` | Same |
| `type-phase-tests` | Same |
| `type-2026-advanced-registry-tests` | Monorepo governance meta-test |

`lower-sexp-to-ast` turns an s-expression into an AST. It is defined in the
`cl-cc` monorepo's `parse` package (`packages/parse/src/cl/lower.lisp`), which
has not been extracted into a repository of its own. cl-cc-type depends on
`cl-cc-ast` for the AST node types, but constructing an AST from source text is
a job for the parse stage, and depending on it from here would invert the
compiler's layering. The five files come back — here or into a cross-repository
integration suite — once `cl-cc-parse` exists.

The sixth is a different case. `type-2026-advanced-registry-tests` reads
`docs/type-advanced.md` from the working directory and cross-checks the FR
headings in it against `cl-cc/test::*known-test-names*`, a registry the
monorepo's homegrown `deftest` shim maintained. Neither the document nor the
registry exists outside the monorepo, and the test asserts nothing about
type-system behaviour: it checks that the monorepo's documentation and its test
names agree. It is governance tooling and it stayed with the governance.

One visible consequence is in `src/types-extended-advanced-validate.lisp`:
`%type-advanced-implementation-test-anchor-available-p` queries that same
registry and returns `t` permissively when it is absent, rather than reporting
every anchor as unmet.

The remaining 26 files run 884 cases, covering everything except the inference
paths that need a parser.

## Releasing

Bump `:version` in `cl-cc-type.asd`. That is the only place the version is
written: `flake.nix` reads the form, and `release.yml` refuses to publish a tag
that disagrees with it. Add the section to `CHANGELOG.md` under a
`## [X.Y.Z] - YYYY-MM-DD` heading — `release.yml` extracts exactly that section
as the release body — then push the tag.
