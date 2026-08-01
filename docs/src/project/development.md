# Development

Everything below assumes Nix with flakes enabled. `nix flake check` is the gate
CI runs; if it passes locally it passes in CI, modulo the platform.

## Commands

```sh
nix develop          # SBCL with CL_SOURCE_REGISTRY already set
nix run .#test       # run the test suite
nix flake check      # tests + formatting + docs + paredit lint, the same gate CI uses
nix fmt              # format Nix sources (treefmt/nixfmt)
nix build .#docs     # render the documentation site
nix build .#coverage # SB-COVER report (result/cover-index.html)
```

The flake declares two systems, `x86_64-linux` and `aarch64-darwin`. Both are
verified: the first by the CI runner, the second by running `nix flake check`
on the development machine. `aarch64-linux` and `x86_64-darwin` are
deliberately not declared, because nothing checks them.

`flake.nix` itself is one call to
[cl-nix-forge](https://github.com/nerima-lisp/cl-nix-forge)'s `mkPackageFlake`
— the org preset that generates the whole standard output table (`packages`,
`checks`, `apps`, `devShells`, `formatter`, `overlays.default`) from the
package's own `.asd`, docs directory and dependency list, the same way
`cl-weave`'s own flake is built. `cl-cc-ast` and `cl-weave` stay `flake =
false` raw source trees — neither publishes a flake of its own — wrapped with
`cl.lispDerivation` directly in `flake.nix`'s `lispDependencies` /
`lispCheckDependencies`. `checks.paredit-lint` runs
[paredit-cli](https://github.com/takeokunn/paredit-cli)'s structural lint
(`paredit inspect lint`) over every source file as a `nix flake check` gate,
not just a manual local command.

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
timeout 1200 sbcl --noinform --script run-tests.lisp
```

`1200` matches `flake.nix`'s `testTimeout`, the same figure `nix build
.#checks.<system>.default` wraps this exact command in — a deadlocked test
should fail the run, not hang the terminal.

The script exits non-zero when the suite fails, so it works as a gate directly.

If a bare `sbcl --script run-tests.lisp` process sits at (or near) zero CPU
time indefinitely on a shared machine, that is a host-level scheduling
problem with plain user processes, not this repository: `nix build
.#checks.<system>.default` runs the identical check inside a sandboxed
Nix build (owned by the build user, not your login user) and is not
subject to whatever is throttling the former. `nix flake check` runs it
alongside the formatting and docs checks. `nix log <drv>` after a build
prints the same `cl-weave` reporter output `run-tests.lisp` would have
printed directly.

## Coverage

`scripts/run-coverage.lisp` recompiles `src/` under SB-COVER instrumentation
and writes an HTML report to `coverage/report/`.

```sh
nix build .#coverage
open result/cover-index.html   # per-file expression/branch percentages
```

`packages.coverage` is `cl-nix-forge`'s `mkCoverageReport`, wired in
`flake.nix`'s `extraOutputs`. It runs `scripts/run-coverage.lisp`'s underlying
sequence the same sandboxed way `checks.default` runs `run-tests.lisp`: a bare
`nix develop -c sbcl --script scripts/run-coverage.lisp` is a host-owned
process, and on a shared machine it can sit at zero CPU indefinitely for the
same host-scheduling reason documented above for `run-tests.lisp` — a
`nix build` runs as a `_nixbld*`-owned sandboxed derivation instead, which is
not subject to it. Falling back to the bare command directly is still possible
if `nix build` is unavailable:

```sh
nix develop -c timeout 1200 sbcl --noinform --script scripts/run-coverage.lisp
```

That fallback still writes to `coverage/report/` (`coverage/` is git-ignored);
`nix build .#coverage`'s `$out` **is** the report directly (no `report/`
subdirectory), because `mkCoverageReport` asserts `cover-index.html` is
non-empty before installing it, so it doubles as a pass/fail check with no
wrapper derivation needed. Either way the recompile is not avoidable: SB-COVER
only measures forms compiled while its `store-coverage-data` optimize policy
is proclaimed, so reusing the FASLs `run-tests.lisp` left behind would report
zero.

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
`src/types-extended-nodes.lisp`. Three files keep a broader name because no
single source file owns them: `t/type-system-test.lisp`,
`t/type-system-inference-test.lisp`, and `t/type-system-effect-test.lisp` run
across representation, unification, inference and effects together.

Every file is added to the `:components` list of `cl-cc-type/test`, and tests
are written against [cl-weave](https://github.com/nerima-lisp/cl-weave) — the
org's test framework — using `it-sequential`, `it-each`, `expect`,
`expect-not` and `signals` directly. Do not introduce FiveAM, parachute, rove
or prove.

## Tests that did not come across

One test file from the monorepo is absent from `t/`. It is absent, not
disabled — there is no way to run it here, so there is nothing to re-enable.

| File | Why |
|---|---|
| `type-2026-advanced-registry-tests` | Monorepo governance meta-test |

`type-2026-advanced-registry-tests` reads `docs/type-advanced.md` from the
working directory and cross-checks the FR headings in it against
`cl-cc/test::*known-test-names*`, a registry the monorepo's homegrown
`deftest` shim maintained. Neither the document nor the registry exists
outside the monorepo, and the test asserts nothing about type-system
behaviour: it checks that the monorepo's documentation and its test names
agree. It is governance tooling and it stayed with the governance.

One visible consequence is in `src/types-extended-advanced-validate.lisp`:
`%type-advanced-implementation-test-anchor-available-p` queries that same
registry and returns `t` permissively when it is absent, rather than reporting
every anchor as unmet.

Five other files — `inference-tests`, `inference-forms-tests`,
`inference-effect-tests`, `type-inference-tests` and `type-phase-tests` — used
to be absent for a different reason: they build their input ASTs with
`lower-sexp-to-ast`, which lived only in the `cl-cc` monorepo's `parse`
package (`packages/parse/src/cl/lower.lisp`) with no standalone repository of
its own. That blocker is resolved now that
[`cl-cc-parse`](https://github.com/nerima-lisp/cl-cc-parse) has been
extracted; the five files were ported to cl-weave (`cl-cc:lower-sexp-to-ast`
becoming `cl-cc/parse:lower-sexp-to-ast`) and are back in `t/`.
`cl-cc-parse` is a test-only dependency of `cl-cc-type/test` — see
`cl-cc-type.asd` and `flake.nix` — not of the `cl-cc-type` library system
itself, since the type checker only ever consumes ASTs, never parses source
text.

Porting those five files surfaced one cl-weave gotcha worth recording: unlike
the monorepo's old `deftest-each`, cl-weave's `it-each` destructuring-binds
each case tuple from a *literal, unevaluated* data list (see
`suite-each-cases` in cl-weave's `src/registration.lisp`), so a bare symbol
like `type-string` or a `(lambda () ...)` in a case binds the symbol or the
raw list itself, not the value or a closure. Case tables in the original files
that relied on evaluating tuple elements (constructing real type nodes, AST
structs, or closures) were ported as individual `it-sequential` tests instead
of `it-each`; only case tables of plain data (sexps to lower, symbols compared
as symbols, numbers, strings, keywords) stayed `it-each`.

The remaining 61 files (56 plus the five restored above) cover everything
including the inference paths that need a parser.

## Releasing

Bump `:version` in `cl-cc-type.asd`. That is the only place the version is
written: `flake.nix` reads the form, and `release.yml` refuses to publish a tag
that disagrees with it. Push the tag, and `release.yml` opens an empty *draft*
release. The
[GitHub Release description](https://github.com/nerima-lisp/cl-cc-type/releases)
is the org's only canonical changelog, so write the notes into that draft and
publish it with `gh release edit vX.Y.Z --notes-file notes.md --draft=false`.
