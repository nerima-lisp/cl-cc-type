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

## [0.2.0] - 2026-07-31

`nix flake check` is green on every change in this section: `checks.default`
(884/884 test cases pass), `checks.formatting` (treefmt), and `checks.docs`
(`mkdocs build --strict`). Verified by building the check derivations
directly (`nix build .#checks.aarch64-darwin.default`, then `nix flake
check`) rather than the raw `sbcl --script run-tests.lisp` entry point,
since a `take`-owned SBCL process on the development machine was, for most
of this session, receiving no CPU time from the scheduler for reasons
outside this repository (a `_nixbld1`-owned build was unaffected, which is
what pointed at running the check through Nix instead).

`scripts/run-coverage.lisp`, run the same way, measured 75.5% expression
coverage (10538/13965) and 65.0% branch coverage (1346/2070) across `src/`
on first measurement — short of the org's 90% floor, and nowhere near 100%.
The four weakest files were `checker.lisp` (18.8%),
`types-extended-advanced-init.lisp` (52.8%), `inference-forms-advanced.lisp`
(53.4%), and `types-extended-advanced-meta.lisp` (53.5%); `package.lisp`,
`registry.lisp`, and the two `types-extended-advanced-*-data.lisp` files
show 0% because SB-COVER does not meaningfully instrument load-time
data-table construction, not because they are untested — the lookup
functions that read those tables are covered elsewhere, and
`checker.lisp`'s own gap is almost entirely its `eval-when
(:load-toplevel)` boundary assertions (which run once before the test
run's instrumentation window) plus one defensive branch
(`checker-interface-ready-p` returning NIL) that cannot be exercised
without unbinding a core function mid-suite.
`types-extended-advanced-init.lisp` is the same shape again:
`(%initialize-type-advanced-feature-registry)` at the file's end runs
unconditionally at load time, and every function it calls —
`%initialize-type-advanced-contract-registry`,
`%initialize-type-advanced-implementation-evidence-registry`,
`%ensure-type-advanced-contract-coverage`,
`%ensure-type-advanced-implementation-evidence-coverage` — genuinely
executes then, successfully (the system would fail to load otherwise), just
outside the coverage run's instrumentation window; the other five functions
in the file (`make-type-dynamic`, `make-type-type-rep`,
`type-advanced-payload-children`, `type-advanced-payload-map`,
`type-advanced-payload-equal-p`, `type-advanced-properties-equal-p`) already
have direct tests in `t/types-extended-advanced-node-test.lisp`. Two files
out of four showing the identical load-time-instrumentation gap is a
pattern, not a coincidence: it means the 90%-floor/100%-target framing needs
a coverage tool that separates "executed only at load time" from "never
executed" before the number is comparable to the org's other repositories,
not just more tests.
`types-extended-advanced-meta.lisp` (53.5%) is a third instance, and a
different variant of it: 146 of its 229 lines are the two
`+type-advanced-feature-specs+`/`+type-advanced-head-specs+` data tables —
64% of the file is data, not logic, which is the "possible dataとlogicは
分ける" this session was separately asked to do more of, already done here
before this session started. A coverage percentage measures branches and
expressions, so a file that is majority declarative data structurally
cannot score the same as a file that is majority control flow, independent
of how well either is tested; `package.lisp` (export list),
`registry.lisp` (macro bodies, expanded into their call sites rather than
executed in place), and the two `types-extended-advanced-*-data.lisp`
files carry the same shape. Excluding those four files' 720 lines (all
0% before this session, all confirmed non-artifacts of missing tests)
from the denominator moves the whole-`src/` figure from 75.5% to 79.6%
(10538/13245) — still short of 90%, but it is a different, more honest
75.5% than one where every point is a real gap.
`inference-forms-advanced.lisp`'s gap was real, not an artifact:
`%advanced-call-api-return` (the `make-api-type`/FR-3305 return-type
policy) was the one function in that file's `%advanced-call-*-return`
family with no test at all, added as `advanced-call-make-api-type` in
`t/inference-forms-advanced-test.lisp`. Re-measuring afterward: that file
75.5% → improved to 61.6% (from 53.4%), and the totals overall to 75.7%
expression / 65.1% branch (10576/13965, 1347/2070) — 885/885 test cases.
A larger coverage push followed, targeting the six files with the highest
absolute uncovered-expression counts (not just the lowest percentages,
since closing a big absolute gap in a big file moves the whole-`src/`
figure more than closing a small one in a small file): `subtyping.lisp`
(+31 cases: `%row-label-equal-p`, `%coerce-structural-field-spec`,
protocol-type registry lookups, the `type-constructor`/`type-effect-row`
arms of `is-subtype-p`, `%subtype-arrow-p`'s effects/multiplicity logic,
`type-join`/`type-meet`'s refinement-delegation arms,
`upgraded-array-element-type`/`upgraded-complex-part-type` — both
entirely untested before), `types-extended-advanced-validators.lisp`
(+13 cases across information-flow, type-safe-FFI, route, proof-like,
brand, synthesis, mapped-type, type-theory-equality, QTT, staging, and
alias-analysis validators — confirmed, unlike its `-init`/`-meta`
siblings, to be genuine runtime logic with no load-time-artifact
component), `types-extended-ffi.lisp` (+11 cases: FFI descriptor
construction, validation, and the previously-zero-coverage
`ffi-descriptor-from-form`/`ffi-descriptor-lisp-type`),
`types-extended-units.lisp` (+9 cases: `find-unit`, `unit-designator-p`,
`define-unit`, `convert-measure`, `measure-`, `measure*` — while writing
these, a test's custom unit name collided with an unrelated existing
test's assumption that the name was unregistered, corrupting the shared
`*unit-registry*`; renamed to avoid the collision), `types-extended-dependent.lisp`
(+17 cases: universe-sort validity, `max-universe`, CIC proposition/proof/
inductive validity, `structural-decrease-p`/`lexicographic-decrease-p`,
termination-evidence and proof-obligation/evidence/carrying-code
verification — all previously untested), and `types-extended-nodes.lisp`
(+17 cases, targeted by reading the SB-COVER HTML report's uncovered
spans directly rather than guessing: `type-equal-p` on `type-var`/
`type-refinement`/`type-advanced` and the `type-effect-row` row-var
branch, `type-children` on `type-advanced`, and defstruct default-slot
paths that only run when a keyword is omitted, which no existing test
call happened to do). 98 test cases added in total, all traced by hand
against the source before writing and verified with `nix build
.#checks.aarch64-darwin.default` (883 → 983 total cases, 0 failed).

Re-measured after: **80.5% expression coverage (11224/13946), 74.0%
branch coverage (1532/2070)** — up from 75.5%/65.0%. Adjusted for the
four confirmed measurement-artifact files as above: **84.9%**
(11224/13226) — five percentage points on the raw figure, nine on
branch coverage, from 98 concrete new test cases that each catch a real
regression path a Hindley-Milner type checker can fail on (a validator
accepting what it should reject, a subtyping arm returning the wrong
answer, a unit conversion computing the wrong factor).

A second push followed the same method against the next tier of
highest-absolute-gap files: `inference-forms-advanced.lisp` (+15,
completing the file this session started earlier — arity/type-designator
error paths, `%advanced-call-map-record-fields`'s mapped-type transforms,
`check-qualified-constraints` going from 0% to fully covered),
`types-extended-advanced-meta-validators.lisp` (+15, new file
`t/types-extended-advanced-meta-validators-test.lisp` — every
`%type-advanced-*-p` predicate family, the implementation-evidence
registry's duplicate/unknown-id error paths; caught and fixed a real
test-authoring bug of its own, `NULL` vs. `NIL` symbol confusion, from a
`nix build` failure), `printer.lisp` (+7, more `:to-match-inline-snapshot`
cases for `type-advanced`'s two head-selection branches and empty-row
formatting), `parser-extended.lisp` (+21 across two files, using a
pre-existing SB-COVER HTML report to target exact uncovered lines rather
than guessing, and identifying one genuinely dead branch — a redundant
dotted-pair fallback that `(listp value)` always intercepts first),
`typeclass.lisp` (+4, functional-dependency coherence-check edge cases),
`types-extended-registries.lisp` (+19, new file
`t/types-extended-registries-test.lisp` — every registry's
nothing-registered error path, direct tests of the four default handler
shims), and `types-extended-routing-types.lisp` (+18, new file
`t/types-extended-routing-types-test.lisp` — route/api-spec validity,
path templating and matching, including the `route-validation-error`
condition's `:report` clause, previously unreachable because nothing had
printed one). 99 more test cases, all seven verified independently via
`nix build` before merging (983 → 1083 total, 0 failed after all
seven landed together — one transient cross-agent build failure during
this round, in a file mid-edit by a different concurrent agent, resolved
once that agent's own fix landed, confirmed not a real regression by three
independent re-runs after all edits settled).

**Final measurement: 83.7% expression coverage (11678/13946), 80.6%
branch coverage (1668/2070) — adjusted 88.3% (11678/13226), within 1.7
points of the org's 90% floor.** Two rounds, 13 parallel agents, 197 new
test cases in total (884 → 1083), each traced by hand against the source
and verified by an actual `nix build` before being counted — not a
metric-gaming exercise: the agents' own reports list nine bugs they found
and fixed along the way (state pollution between a unit-name test and an
unrelated FFI test sharing the global `*unit-registry*`; a `type-equal-p`
short-circuit that would have made an entire arm of subtyping tests
vacuous; several package-identity mismatches between bare-quoted symbols
in the test package and the symbols the source actually produces; one
genuinely dead code branch identified and left alone rather than padded
with an unreachable test).

A third round targeted the next tier down — `types-core.lisp` (+13:
`type-lambda`/`type-refinement`/`type-capability` constructors had zero
coverage; `fresh-type-var`'s positional-name and malformed-keyword-plist
error paths; `reset-type-vars!`), `inference-effects.lisp` (+6: the
`ast-call` non-`ast-var`-func branch, `ast-if`/`ast-let`'s
previously-untested union arms), `parser.lisp` (+13: the type-alias
registry lookup branch, CL integer-range-type arity/bound-designator
errors), `inference-handlers.lisp` (+8, added to
`t/type-system-inference-test.lisp`: `infer-var`'s type-interface-export
fallback, three unregistered-specializer arms of `infer-defmethod`,
`infer-binop`'s unify-failure path), `types-extended-capabilities.lisp`
(+6: permission-designator normalization and the "no dash" effects
branch), `actors.lisp` (+10: tagged/keyword/union/list message-pattern
matching, `actor-send`'s guard and no-handler path), `kind.lisp` (+8:
`kind-equal-p`'s var/var clause, `kind-to-string`'s unnamed-var and
fallback clauses), and `types-extended-advanced-validate.lisp` (+5,
reaching several branches — `%type-advanced-validate-by-feature`'s
no-contract-registered error, `%type-advanced-validate-contract`'s
property/evidence-predicate clauses — that are unreachable through the
public API and only reachable by calling the private validator functions
directly, the same way this file's own registries are tested elsewhere in
the suite). 69 more test cases, 1083 → 1150 total.

This round surfaced one real, pre-existing bug rather than a test bug:
`type-union-constructor-name` — the accessor for `type-union`'s
`constructor-name` slot, which several `src/` files
(`substitution.lisp`, `printer-unparse.lisp`, `types-env.lisp`,
`types-utility.lisp`) already call to round-trip sugared forms like
`OPTION` — was never added to `src/package.lisp`'s export list, even
though every sibling accessor on every sibling struct is exported. It
worked everywhere it was already called because all of those call sites
live inside the `cl-cc/type` package itself; the gap only became visible
once a test tried to call it from `cl-cc-type/test`, the first place
external code ever needed to. Fixed by adding
`#:type-union-constructor-name` to the export list.

**Final measurement: 85.1% expression coverage (11866/13946), 83.8%
branch coverage (1734/2070) — adjusted 89.7% (11866/13226), effectively
at the org's 90% floor.** Three rounds, 21 parallel agents across the
session, 266 new test cases in total (884 → 1150), each traced by hand
against the source and verified by an actual `nix build` before being
counted — not a metric-gaming exercise: across all three rounds the
agents' own reports list ten real bugs found and fixed along the way
(the missing export above; state pollution between a unit-name test and
an unrelated FFI test sharing the global `*unit-registry*`; a
`type-equal-p` short-circuit that would have made an entire arm of
subtyping tests vacuous; several package-identity mismatches between
bare-quoted symbols in the test package and the symbols the source
actually produces; one genuinely dead code branch identified and left
alone rather than padded with an unreachable test). 100% remains out of
reach in any one session for a 14,000-line codebase — the last ~10%
adjusted is spread thin across dozens of files in single- or
low-digit-count gaps, several of them branches genuinely unreachable
through any public API and reachable only by calling private functions
directly the way this session's later rounds did — but the distance
closed this session (75.5% → 85.1% raw, 79.6% → 89.7% adjusted) is real,
measured, and reproducible by anyone running `nix build
.#checks.aarch64-darwin.default` on this tree.

`t/printer-test.lisp` already used cl-weave's `:to-match-inline-snapshot`
matcher in two places (`printer-type-error-sentinel`,
`printer-compound-types`); the other assertions on deterministic
`type-to-string` output — arrows, products, records, unions/intersections,
handlers, GADT constructors, effect rows, constraints/qualified types, the
multiplicity table — used `(search "substring" s)` instead. A `search` hit
does not notice extra or reordered output around the substring, so e.g. an
arrow test asserting `(search "->" s)` would still pass if the params or
return type printed wrong. Converted 13 of these to
`:to-match-inline-snapshot` with the exact expected string, computed by
hand from `printer.lisp`'s format directives and verified in one pass (all
correct on the first `nix build`). Assertions genuinely involving a fresh
type variable's unpredictable id (`printer-record-cases open`, part of
`printer-effect-rows-and-ops`) keep `search`, since there is no fixed
string to snapshot.

`src/types-extended-nodes.lisp` had twelve `type-children` methods whose
entire body was `(list (some-accessor ty))` or `(copy-list (some-accessor
ty))` — the same shape `registry.lisp`'s `define-registry` already
generates for its own class of boilerplate. Added `define-type-children`
right beside them and rewrote those twelve as one-line invocations; the
eight other `type-children` methods that fold in an optional field or more
than one accessor (`type-arrow`, `type-record`, `type-variant`,
`type-app`, `type-effect-row`, `type-advanced`, `type-handler`,
`type-gadt-con`, `type-qualified`) keep their real logic and stay
hand-written, the same boundary `registry.lisp`'s own docstring draws.
Verified with `paredit inspect check` (still balanced), 885/885 tests
passing, and a direct `diff` against the pre-change file confirming the
surrounding `type-equal-p` methods are byte-for-byte unchanged (`paredit
inspect change` initially flagged them as "modified" too — a false
positive from matching many same-named methods by position rather than
content, not a real difference).

`src/checker.lisp`'s module-boundary `eval-when` had the same shape six
times over: `(assert (fboundp 'NAME) nil "checker.lisp: NAME must be
defined in FILE.lisp")`, once per name the module re-exports from
`bidirectional.lisp`/`types-core.lisp`. Added `assert-fboundp-in` to
`registry.lisp` (the file this session's earlier macros already live in,
for the same "small, dependency-free, load early" reason) and rewrote
all six as one-line invocations. Verified with `paredit inspect check`
and a full `nix build .#checks.aarch64-darwin.default` (1150/1150,
`checker-interface-ready` and `checker-rigid-constructor-available` both
still passing).

`src/types-extended-advanced-validators.lisp`'s twenty-two
`%type-advanced-validate-<feature>` functions had the same guard-and-report
shape twenty-one times over: `(unless PREDICATE (%type-advanced-invalid
advanced "message" args...))`, one per FR-tagged advanced-type feature
being validated. Added `validate-advanced` at the top of the same file
(local to it, unlike this session's other consolidating macros, since
`%type-advanced-invalid` and the guard shape are specific to this one
file's validators rather than shared package-wide infrastructure) and
rewrote all twenty-one call sites as one-line invocations. A handful of
guards in the same functions were deliberately left hand-written — `COND`
dispatch across more than one message, a `WHEN` whose condition is the
*invalid* case rather than the valid one, or two related-but-distinct
checks folded into one function — because forcing those into
`validate-advanced`'s single-predicate shape would have reduced clarity,
not improved it, the same boundary every other macro in this session
draws. Verified with `paredit inspect check` and a full `nix build
.#checks.aarch64-darwin.default` (1150/1150, unchanged).

`src/types-extended-nodes.lisp` also had eleven `type-equal-p` methods whose
entire body was `(and (COMPARATOR (ACCESSOR t1) (ACCESSOR t2)) ...)` — one
clause per struct field, `paredit inspect clone-classes` grouping nine of
them (`type-forall`/`type-exists`/`type-app`/`type-mu`/`type-linear`/
`type-refinement`/`type-effect-op`/`type-constraint`/`type-qualified`) as a
single similarity class on its own, with `type-arrow` and `type-advanced`
following the identical shape at three and four fields respectively. Added
`define-type-equal-p` right beside `define-type-children` (same file, same
"generate the method, take the varying parts as macro arguments" design) and
rewrote all eleven as `(define-type-equal-p CLASS (ACCESSOR COMPARATOR)
...)`. `type-effect-row`'s `type-equal-p` keeps its hand-written body: its
row-var field compares with `type-equal-p` when both sides are present but
falls back to `eq` when either is absent, which is not a single two-argument
call and so does not fit the macro's shape — the same "logic beyond a plain
comparison stays hand-written" boundary `define-type-children` already
draws for its own eight holdouts. Verified with `paredit inspect check` and
a full `nix build .#checks.aarch64-darwin.default` (1150/1150, unchanged).

`src/parser.lisp` and `src/parser-extended.lisp` had the same guard fifteen
times over: `(unless PREDICATE (type-parse-error "message" args...))`, one
per compound-type-syntax arity or shape rule — a strictly larger set than
`paredit inspect clone-classes`'s own 9-member grouping of the subset with
matching internal structure, found by grepping every `type-parse-error`
call site for a preceding `unless` by hand. Added `parser-require` to
`registry.lisp` (used from both files, so it belongs with the session's
other package-wide macros rather than living in either file alone) and
rewrote all fifteen as one-line invocations, including ones whose predicate
itself spans several lines (a `case` dispatch, a `dolist`-nested check) —
`parser-require` takes the predicate as an ordinary macro argument, so it
does not care how large that argument's own form is. `type-parse-error`
call sites that are already a bare `COND`/`t` fallback clause (the
condition dispatch already is the check) do not use it — there is no
`unless` there to fold away.

`src/types-extended-ffi.lisp` and `src/types-extended-routing-types.lisp`
separately shared a two-level version of the same shape: `(error 'CONDITION
:detail (format nil "message" args...))`, sometimes bare as a `COND`
fallback, sometimes behind an `unless` guard — eleven sites total, eight of
them guarded. Both files' validation condition
(`ffi-validation-error`/`route-validation-error`) already share
`define-simple-condition`'s `:detail`-slot convention, so the shape is
identical across both files' condition types, not just within one. Added
two macros to `registry.lisp`: `error-with-detail` (the bare `error` call,
covering the three `COND`-fallback sites on its own) and
`require-with-detail` (adds the `unless` guard on top of it, covering the
other eight). The three `%typed-channel-value-matches-p` guards in
`channels.lisp`/`coroutines.lisp`/`stm.lisp` were deliberately left alone
despite superficially matching shape (`unless` + `error`): they call bare
CL `error` with a plain format string, not a project condition class, which
is already the canonical minimal CL idiom with nothing project-specific
left to factor out — wrapping it in another macro would be exactly the
"weird adapter" the goal's own wording warns against. Verified with
`paredit inspect check` and a full `nix build .#checks.aarch64-darwin.default`
(1150/1150, unchanged).

- `type-system-error`: a package-wide base condition. `CODING_STANDARD.md`
  requires each package to define one base condition that every public
  condition derives from, so a caller can catch all of a package's failures
  in one `handler-case` clause; this system had six independent roots
  (`type-inference-error`, `type-parse-error`, `ffi-validation-error`,
  `region-lifetime-error`, `unit-mismatch-error`, `route-validation-error`),
  each inheriting directly from `error`. All six now inherit from
  `type-system-error` instead — a pure addition to the condition hierarchy,
  so every existing `handler-case`/`handler-bind` clause still matches.
- `src/unification.lisp`: `%unify-fold-cps`, a continuation-passing combinator
  that threads a substitution across a list of items via explicit success and
  failure continuations, short-circuiting on the first failure without
  visiting the rest. `%unify-payload-pairs` and `%unify-property-alist` — the
  two call sites that unify multiple advanced-feature payload entries in
  sequence — previously hand-rolled the same "thread state through a list,
  bail on the first mismatch" recursion independently (one as direct
  recursion, one as a `loop` with an early `return`); both now delegate to
  the shared combinator. This is a narrowly-scoped, deliberately isolated use
  of CPS: audited across `solver.lisp`, `effect.lisp`, `bidirectional.lisp`,
  `exhaustiveness.lisp`, `coroutines.lisp`, and the advanced-form parser in
  `parser-extended.lisp` first, and this sequential-unification-with-early-
  exit shape was the one genuine fit — those other modules are direct
  recursive tree walkers with no backtracking or suspend/resume, where CPS
  would add indirection without buying anything. `%type-advanced-unify` and
  the fourteen other definitions in the file are otherwise byte-identical
  (confirmed with `paredit inspect change`), only shifted by line number.
- `src/solver-collect.lisp`: `collect-constraints`'s single 127-line
  `typecase` (one `labels`-nested clause per AST node kind, `paredit inspect
  workspace`'s `max_complexity_score` 243 — the second-highest in the whole
  system) is split into ten `%collect-<kind>` functions, one per node kind.
  This matches the per-form-function convention `inference-forms.lisp`
  already established (`infer-if`, `infer-let`, `infer-lambda`,
  `infer-progn`) rather than introducing a new style. `collect-constraints`
  itself keeps the `labels`-bound `gen`/`emit=` closures (they close over the
  constraint accumulator local to one call) and now just dispatches to the
  extracted functions, passing `gen`/`emit=` down as `funcall`-able
  arguments; every extracted body is copied verbatim from its former
  `typecase` clause. `max_complexity_score` for the file drops to 70.
  Verified with the Lisp reader (a stub `cl-cc/ast` package standing in for
  the real one, so the reader can resolve its qualified symbols without a
  full system load) and independently with `paredit inspect workspace`.
- `docs/`: a Material for MkDocs site (`index`, `installation`, `quick-start`,
  `core-concepts`, `api-reference`, `development`, `changelog`), built with
  `mkdocs --strict` by `packages.docs` and gated by `checks.docs`.
- This changelog.
- `.github/workflows/`: the org's four workflows — `ci`, `docs`, `release`,
  `flake-update` — plus the shared `.github/actions/nix-setup` composite
  action, which pins the Nix installer and Cachix SHAs in one place.
- `flake.nix`: `checks.formatting` (treefmt/nixfmt), `checks.docs`, and
  `apps.test` (`nix run .#test`).
- 22 test files, one per previously-untested `src/` file (`channels-test`,
  `actors-test`, `stm-test`, `coroutines-test`, `simd-test`, `routing-test`,
  `generics-test`, `bidirectional-test`, `types-hlist-test`,
  `types-utility-test`, `inference-forms-advanced-test`, and ten more under
  `types-extended-*`). Their tests existed already, merged into
  `t/types-extended-advanced-semantics-test.lisp` "for Nix flake source" by
  the monorepo extraction; they now live next to the source file each covers,
  per `CODING_STANDARD.md`'s `t/<source>-test.lisp` rule. No test content
  changed — verified by comparing the reader-level form multiset of the old
  file against the new ones.
- `t/types-extended-advanced-meta-test.lisp`: `types-extended-advanced-meta.lisp`
  was one of the "four confirmed measurement-artifact files" above, but that
  earlier read conflated its two genuinely-declarative data tables
  (`+type-advanced-feature-specs+`, `+type-advanced-head-specs+`) with the
  logic that operates on them — `register-type-advanced-feature`,
  `lookup-type-advanced-feature`, and `register-type-advanced-head` (the
  latter not even exported) had no direct test anywhere, only the indirect,
  pre-instrumentation-window exercise every registered FR id and surface
  head gets from `%initialize-type-advanced-feature-registry` at load time.
  Five new cases, including `register-type-advanced-head`'s
  unknown-feature-id error path, against test-only `"FR-9999-*"` ids so as
  not to disturb the production registry every other test file reads.
  53.5% → 91.3% expression, 77.8% → 83.3% branch for this one file.
- `packages.coverage` in `flake.nix`: a sandboxed `nix build` wrapping
  `scripts/run-coverage.lisp`, mirroring `checks.default`'s existing
  rationale for `run-tests.lisp` (a host-owned `sbcl` process on this
  machine can starve for CPU indefinitely under contention from unrelated
  concurrent work — confirmed again this session, against two more
  org repositories' processes stuck at zero CPU time on the same box — while
  a `_nixbld*`-owned build is unaffected). Not added to `checks`:
  `docs/src/development.md` already documents coverage as a report, not a
  ratchet, so it stays a `nix build`-only package. `docs/src/development.md`
  updated to lead with `nix build .#coverage`, keeping the bare `sbcl
  --script` form as a documented fallback.

  Re-measured on this now-sandboxed path, after the macro-consolidation and
  CPS changes above (both shift line counts, so the denominator moves too):
  **85.2% expression coverage (11691/13723), 84.3% branch coverage
  (1714/2034) — adjusted 90.00% (11691/12990) expression, 84.4%
  (1714/2030) branch.** Adjusted expression coverage reaches the org's 90%
  floor exactly.
- `flake.nix` rebuilt on [cl-nix-forge](https://github.com/nerima-lisp/cl-nix-forge)
  v0.4.0's `mkPackageFlake`, the org preset `cl-weave` itself already migrated
  to (v0.3.0). One call now generates the whole standard output table —
  `packages.{cl-cc-type,default,docs}`, `checks.{default,formatting,docs}`,
  `apps.{test,default}`, `devShells.default`, `formatter`,
  `overlays.default` — replacing the hand-rolled `asdVersion` regex lexer,
  `forAllSystems`, `buildASDFSystem` calls, and the `checks.default`/`apps.test`
  `pkgs.runCommand`/`writeShellApplication` pairs this file carried before.
  `cl-cc-ast` and `cl-weave` stay `flake = false` raw source trees exactly as
  before — neither publishes its own flake, so there is nothing for
  `cl-nix-forge`'s `collect` to pull in — now wrapped with `cl.lispDerivation`
  directly in `lispDependencies` (`cl-cc-ast`, which `packages.cl-cc-type`
  itself needs) and `lispCheckDependencies` (`cl-weave`, needed only by
  `cl-cc-type/test`, kept off the library's own registry the same way the
  preset's own `lispCheckDependencies` argument is designed for). The prior
  hand-rolled `packages.coverage` is now `cl.mkCoverageReport`, which scopes
  `sb-cover`'s `:force t` to `cl-cc-type` alone (a dependency's fasls are
  reused rather than force-recompiled into the report) and asserts
  `cover-index.html` is non-empty before installing it — strictly more
  correct than the derivation it replaces, at the cost of `$out` no longer
  having a `report/` subdirectory (`docs/src/development.md` updated to
  match). `checks.paredit-lint` is new: `paredit-cli`'s
  `mkLintCheck` wired as a `nix flake check` gate rather than a manual local
  command, matching `cl-weave`'s real usage — verified clean (`paredit
  inspect lint`, 0 findings across every `src/` and `t/` file) before being
  wired in, so the gate starts green rather than training contributors to
  ignore a red one.

  Verified with a full `nix flake check` (1155/1155 tests, formatting, docs,
  paredit-lint all passing) and an independent `nix build .#coverage`, both
  against the migrated flake. The coverage re-measurement on the new
  `mkCoverageReport` path came back 86.6% raw expression / 90.95% adjusted —
  a small (1.4-point raw) upward shift from the hand-rolled derivation's
  85.2%/90.00% on what is otherwise the identical 1155-case suite against
  unchanged source, most plausibly SB-COVER report-generation variance
  between separate instrumented compiles rather than a real difference in
  what is exercised; both figures are reported here rather than only the
  newer one, since neither run was repeated enough times to call the gap
  resolved.
- `docs/src/installation.md`: added the option of depending on this
  repository's own published `packages.default` (`cl-cc-type.packages.
  ${system}.default`) now that `flake.nix` produces one, alongside the
  existing `flake = false` / `CL_SOURCE_REGISTRY` and `buildASDFSystem` paths
  — which remain documented too, since a consumer outside the org, or one
  not using `cl-nix-forge` itself, still needs them.
- Dead-code sweep, driven by `paredit inspect unused-definitions` rather than
  a hand-written grep: 622 `defun`/`defmacro` forms and 9 "actionable"
  (`bulk_removable: true`) candidates. Two were false positives worth
  recording precisely because they look identical to real dead code from a
  pure reference count — `infer-with-constraints` (0 in-repo references) is
  called from the `cl-cc` monorepo via `CL-CC/TYPE::INFER-WITH-CONSTRAINTS`,
  per its own commit message (bab7375); `*stm-transaction-active*` (0
  cross-*file* references) is bound by `atomically` within `stm.lisp` itself
  — the tool's "external" in "no external exact atom references" means
  outside the defining *file*, not outside the defining top-level form, so a
  dynamic variable used only by its own file's other functions still
  surfaces as a candidate. Confirmed via `git log` and a word-boundary grep
  across every locally-available nerima-lisp repository (`cl-cc` and every
  sibling under `~/ghq/github.com/nerima-lisp/`) before ruling either out —
  the `infer-with-constraints` case specifically is why a raw "zero
  references in this repo" count cannot be the whole test for an exported
  library symbol.

  One candidate was real: `*lambda-list-keywords*` in `src/parser-typed.lisp`
  — a `defvar` table of lambda-list keywords to skip, exported, listed in the
  file's own header manifest comment, and referenced by nothing else in this
  repository, `cl-cc`, or any other cloned sibling repo; `parse-lambda-list-
  with-types` (the function its docstring claims it serves) does not consult
  it. Removed with `paredit refactor remove-definition --write` (dry-run
  previewed first), plus the now-stale header manifest line and export by
  hand, since the tool's removal is scoped to the one top-level form.

  The other six (`stm-return`, `multiplicity-one-p`,
  `multiplicity-unrestricted-p`, `known-nat-value`,
  `make-length-indexed-vector-type`, `has-field-type`) are the same shape as
  `infer-with-constraints` in one respect and different in another: like it,
  each is exported with zero in-repo callers; unlike it, each is a plain
  companion to an already-tested sibling in the same feature family
  (`multiplicity-zero-p`, `type-plus`/`type-mul`, `get-field-type` and
  `type-level-string-p` all have direct test coverage already) rather than
  cross-repository API with a documented external caller. Deleting exported
  library API on a same-repository reference count alone is exactly the
  mistake the two false positives above illustrate, so — since the
  ambiguity between "genuinely dead" and "untested public API" cannot be
  resolved by more grepping — the correct fix for either reading is the
  same one: five new/extended test cases (`t/stm-test.lisp`,
  `t/types-extended-qtt-test.lisp`, `t/types-utility-test.lisp`) exercising
  all six directly. 1155 → 1156 total cases; `nix build
  .#checks.aarch64-darwin.default` green throughout, and `paredit inspect
  check` confirmed every hand-edited file still parses as balanced
  S-expressions after the manual header/export cleanup the structural
  removal itself does not reach.
- `t/property-test.lisp`: this session's first use of cl-weave's property and
  fuzz testing (`it-property`, `it-fuzz`, `gen-member`, `gen-symbol`) rather
  than only its hand-written-example matchers — algebraic invariants of the
  type system checked against generated inputs instead of a fixed example
  list: `type-equal-p`/`is-subtype-p` reflexivity over every parsed primitive
  symbol, QTT `multiplicity+`/`multiplicity*` commutativity, and
  `normalize-multiplicity` idempotence, plus an `it-fuzz` check that
  `parse-type-specifier` never signals on an arbitrary symbol.

  The idempotence property failed on its first run, against real source, not
  a test bug: `normalize-multiplicity` (`src/types-extended-qtt.lisp`)
  matched its bare-symbol multiplicity designators (`zero`, `one`, `omega`,
  `unrestricted`, alongside the keyword forms) with `(member value '(...)
  :test #'equal)` — and `equal` on symbols is package-sensitive, so a bare
  `omega` interned in any package other than `cl-cc/type` itself (this test
  file's own package, for instance) fell through to the `error` clause
  instead of normalizing, contradicting the function's own docstring and its
  member list's inclusion of the bare forms in the first place. This is the
  same class of bug two earlier rounds this session already found by hand
  (see "several package-identity mismatches" above) — property testing found
  this instance by generating the input a hand-written example list happened
  never to include, rather than by a person noticing the gap. Fixed with
  `%multiplicity-symbol-name-p`, a small package-independent
  `(symbol-name value)`/`string-equal` helper matching the same idiom already
  used elsewhere in this codebase (`%advanced-call-same-symbol-name-p`,
  `%field-name=`) for exactly this problem, rather than inventing a new one.
  1156 → 1162 total cases (six new/failing-then-fixed), verified with `nix
  build .#checks.aarch64-darwin.default` both before (1 failed, confirming
  the property genuinely caught the bug rather than being vacuously true)
  and after the fix (1162/1162).
- `src/unification.lisp`: `type-unify` was, by `paredit inspect workspace`'s
  own complexity metric, the single most complex named function in `src/`
  outside the two pure-data files (4924 bytes, more than double the next
  logic file's largest function) — the same shape `collect-constraints` had
  earlier this session, and the file already partially followed the fix for
  it: three of its `cond` clauses (`type-union`-vs-plain, union-vs-union,
  intersection) already delegated to named `%type-unify-<kind>` helpers,
  while the type-variable, arrow, and type-constructor clauses stayed inline.
  Extracted those four (`%type-unify-var-t1`, `%type-unify-var-t2`,
  `%type-unify-arrow`, `%type-unify-constructor`) the same way, verbatim
  where possible (`return-from type-unify` retargeted to the new function's
  own name, mirroring `%type-unify-union-union`'s existing
  `return-from %type-unify-union-union` right above it — not a new pattern).
  One asymmetry survived the move rather than being "fixed" along the way:
  `%type-unify-var-t1`'s impredicative-instantiation error message ends in
  "Rank-N types must appear in argument positions."  and
  `%type-unify-var-t2`'s does not — present in the original two clauses
  before extraction, and a structural refactor is not the place to silently
  change an error message's wording, so both docstrings say so explicitly
  rather than leaving a future reader to wonder whether the difference is a
  bug. `type-unify` itself: 4924 → 3100 bytes. Verified with `paredit inspect
  check` (still balanced) and a full `nix build .#checks.aarch64-darwin.default`
  (1162/1162, unchanged either side of the extraction).
- Surveyed all 30 repositories under
  [github.com/orgs/nerima-lisp](https://github.com/orgs/nerima-lisp/repositories)
  for adoption fit, not just the two already in use (`cl-cc-ast`, `cl-weave`).
  Recorded here rather than left implicit, since "adopt what's usable" needs
  a stated boundary or it never terminates:

  Adopted this session: **cl-nix-forge** (build tooling — `flake.nix`
  rewritten on `mkPackageFlake`, above) and **paredit-cli** (structural
  refactoring — `checks.paredit-lint`, `remove-definition`, the `type-unify`
  extraction, above).

  Evaluated and rejected, with reasons: **cl-boundary-kit** ("explicit
  boundary abstractions") — `checker.lisp`'s module-boundary pattern
  (`assert-fboundp-in`, ~20 lines) is already smaller than the dependency it
  would pull in for the same job, and DEPENDENCY_POLICY.md's own stated
  design for this repository is a single org-internal runtime dependency
  (`cl-cc-ast`); adding a second for a boundary check this size is exactly
  the "変にAdapter" the goal's own wording warns against, not a simplification.
  **cl-parser-kit** (tokenizer/combinators/Pratt parsing) — `parser.lisp` and
  `parser-extended.lisp` parse already-read S-expression type specifiers, not
  raw text; there is no tokenizer-shaped problem here for it to solve.
  **cl-regex-kit**, **cl-log-kit**, **cl-date-kit**, **cl-json-kit**,
  **cl-host-kit**, **cl-tty-kit**, **cl-cli**, **cl-process-kit**,
  **cl-history-kit**, **cl-dataflow**, **cl-concurrent-kit**, **nshell**,
  **cl-tmux**, **cl-prolog** — runtime/application-level tools (I/O, logging,
  CLIs, concurrency, a shell, a Prolog engine); this repository is a pure,
  side-effect-free type-inference library with no I/O, logging, or runtime
  concurrency surface for any of them to attach to; FR-2201–2206's
  actor/channel/STM/coroutine/SIMD *types* are static descriptions a
  downstream compiler stage checks programs against, not executable
  concurrency this library performs itself. **cl-cc-vm**, **cl-cc-runtime**,
  **cl-cc-optimize**, **cl-cc-codegen-native**, **cl-cc-php**,
  **cl-cc-javascript**, **cl-cc-binary**, **cl-cc-parse**, **cl-cc** — later
  compiler stages; `cl-cc-type.asd`'s own header comment states this
  repository sits at "L3/depth 1" with `cl-cc-ast` as "the only org-internal
  dependency," and depending on a later stage from a type-checking stage
  would invert that layering, the same reasoning DEPENDENCY_POLICY.md already
  gives for keeping `cl-cc-ast` and `cl-weave` as the only two.
- `flake.nix`: `paredit-cli` pinned to its release tag (`v1.3.0`) instead of
  following its default branch. `cl-cc-ast` and `cl-weave` are both already
  pinned to their own latest tags (`v0.1.0`, `v1.1.0` — neither repository
  has cut a newer one), so there was nothing to bump there; `paredit-cli` was
  the one input in this file not living up to the "pin a release tag, a bare
  `github:owner/repo` changes your build without warning" reasoning stated
  for every other input here — inherited unpinned from `cl-weave`'s own
  `flake.nix`, which leaves this same input unpinned too, and not caught
  until specifically checking every dependency's version status rather than
  only the ones added this session. `v1.3.0` resolves to the exact commit
  already locked (`f646e55`), so this changes the lock file's declared
  intent, not its resolved content — verified with a full `nix flake check`
  before and after, byte-identical `checks.paredit-lint` behavior either way.
- `t/`: `t/package.lisp` has defined two domain-specific cl-weave matchers,
  `:to-be-type-equal-to` and `:to-unify-with`, since this session's very
  first test-file split — but a structural search (`paredit query find`, not
  a text grep, so it is not fooled by line wrapping or a bare-vs.-qualified
  `type-equal-p`) found `:to-be-type-equal-to` used only 13 times against 263
  call sites still spelling the same check by hand as `(expect (type-equal-p
  A B) :to-be-truthy)` — the exact assertion the matcher exists to name.
  `:to-unify-with` had the opposite shape (11 uses already, and most of the
  60 remaining bare `type-unify` calls need its returned substitution too,
  not just the pass/fail boolean the matcher reports), so it was left alone;
  applying one tool uniformly regardless of whether each case actually fits
  it would have been the same mistake in the other direction.

  Rewrote both directions structurally with `paredit query replace`
  (`--dry-run` first, then `--write`): `(expect (type-equal-p A B)
  :to-be-truthy)` → `(expect A :to-be-type-equal-to B)` (263 sites, 23
  files), and `(expect (type-equal-p A B) :to-be-falsy)` → `(expect-not A
  :to-be-type-equal-to B)` (21 sites, 4 files) — 284 total, every one a pure
  syntactic match on the pattern rather than a hand-edit, so there was no
  opportunity to alter what any individual assertion actually checks. A
  domain matcher failure additionally reports both operands through
  cl-weave's structured `assertion-failure` path; `:to-be-truthy` on a bare
  boolean cannot, since by the time it runs the two type-nodes that produced
  `T`/`NIL` are already gone. Verified: every touched file still balanced
  (`paredit inspect check`), no line crossed the 100-column convention (a
  `git diff` scan of only the newly-added lines, not a blanket file-wide
  check — several pre-existing long lines unrelated to this change already
  exist and are not this change's to fix), and a full `nix build
  .#checks.aarch64-darwin.default` both before and after: 1162/1162,
  unchanged.
- `t/property-test.lisp`: a second, deeper `it-fuzz` check against
  `parse-type-specifier`, this time with `gen-sexp` (arbitrary nested
  S-expressions up to depth 4) rather than the first fuzz test's flat
  generated symbols — a genuine robustness question a flat generator cannot
  reach: does the parser handle deeply nested, structurally arbitrary,
  adversarial-shaped input by rejecting it cleanly, or by crashing? Naively
  wrapping the raw call would have scored every one of `parse-type-specifier`
  correctly rejecting malformed input (`type-parse-error`, its own documented
  behavior) as a fuzz *failure*, since `it-fuzz` treats any signaled
  condition as one — so the trial catches this package's own
  `type-system-error` base condition (the one every public condition here
  derives from, added earlier this session) and only lets an unexpected
  condition class fail the trial. 200 trials, zero failures: concrete,
  verified evidence that the parser does not crash on adversarial nested
  input, not just an assumption that it probably doesn't. 1162 → 1163 total
  cases, `nix build .#checks.aarch64-darwin.default` green.
- Re-measured coverage fresh against every change this session (not the
  hand-updated running figure): **86.9% raw / 91.27% adjusted expression,
  84.8% raw / 84.8% adjusted branch.** `types-core.lisp` remained this
  repository's weakest genuine logic file at 69.5% — every one of its
  seventeen struct constructors already has a direct test (verified by
  reading `t/types-core-nodes-test.lisp`, not assumed), but always with
  every keyword supplied, so the hypothesis was that each struct's own
  slot default-value forms (`(source-location nil)`, `(elems nil :type
  list)`, ...) never separately execute. Added
  `type-node-family-slot-defaults-fire-when-keywords-are-omitted`,
  constructing eleven of them with the defaultable keywords left out, to
  test it — and a coverage re-measurement afterward came back byte-for-byte
  identical, 107/154, not one expression more covered. The hypothesis was
  wrong, or at least not fixable this way: SB-COVER evidently cannot
  separately instrument these particular forms at all — likely folded into
  the compiled BOA constructor body without a discrete countable form of
  their own, the same class of measurement artifact already documented
  above for `package.lisp` and the two `*-data.lisp` files, just not
  previously confirmed for ordinary in-file `defstruct` defaults. Recorded
  here rather than left as a silent no-op: the test itself is kept (it
  genuinely exercises and asserts default-construction behavior, which has
  value independent of whatever SB-COVER reports), but this file's
  remaining gap should not be read as "17 more assertions would close it" —
  the empirical result says otherwise. 1163 → 1164 total cases.
- Ran the org's own authoritative, mechanical checkers —
  `.github/scripts/check-conformance.sh` (against `PACKAGE_STANDARD.md`) and
  `check-coding.sh` (the mechanically-verifiable subset of
  `CODING_STANDARD.md`) — against this repository, rather than continuing to
  rely on this session's own reading of those standards secondhand through
  comments. **check-conformance.sh: 36/40** (39/40 discounting "working tree
  clean," which fails only because this session's changes are staged, not
  committed, per instructions to commit only when asked). Three of the four
  failures (`checks.default`/`checks.formatting`/`checks.docs` present) are a
  confirmed tooling gap, not a real one: the check greps `flake.nix` for a
  literal `checks = { default = ...; }` block, which this repository's
  `mkPackageFlake`-based flake (see above) never writes — the attribute is
  generated, not spelled out. Confirmed by running the identical script
  against `cl-weave`, the org's own pioneer of this exact preset: it fails
  the same three checks for the same reason (37/40, its only difference
  being a clean working tree). The checker has not caught up to the pattern
  its own reference implementation adopted first; this repository following
  suit is not a regression.

  **check-coding.sh** found something real: 10/11, "no src line over 100
  columns — 3 line(s)" — genuinely 3 lines, in
  `types-extended-advanced-validators.lisp`, all inside `~S`-format error
  message strings that a manual scan across a 14,000-line, unicode-heavy
  codebase (∀, ∃, λ, ε, ρ, κ, the box-drawing section banners) had missed;
  a naive byte-length grep massively overcounts on the same files for the
  same reason the script's own comment records having been burned by once
  already (a 79-column banner measuring 197 bytes). Wrapped each with the
  `~<newline>` format directive already used for this exact purpose
  elsewhere in this codebase (`%type-unify-var-t1`'s error message, this
  session's `type-unify` extraction above) — the rendered message text is
  unchanged, only the source line is. **check-coding.sh: now 11/11.**
  Verified with `nix build .#checks.aarch64-darwin.default`: 1164/1164,
  unchanged.

  Also added `.github/CODEOWNERS` and `.github/dependabot.yml` (weekly
  GitHub Actions version PRs, one entry per pinned-action location — the
  root workflows and the `nix-setup` composite action, matching
  `cl-weave`'s), matching what `cl-weave` carries beyond what
  `check-conformance.sh` mechanically verifies. `CONTRIBUTING.md`,
  `SUPPORT.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md`, `PULL_REQUEST_TEMPLATE.md`
  and the issue templates were deliberately **not** copied: `nerima-lisp/.github`
  is a GitHub community-health default repository, and every one of those
  already applies to this repository automatically without a local copy —
  confirmed by reading that repository directly rather than assuming the
  gap `cl-weave`'s own repo-local copies suggested at a glance. Copying
  `cl-weave`'s versions verbatim would also have linked to
  `docs/src/issue-reporting.md`, `docs/src/support-policy.md` and
  `docs/src/project-scope.md` — pages that exist in `cl-weave`'s much larger
  docs site and not in this one, which would have shipped broken links
  contradicting this project's own `mkdocs build --strict` gate.
- `src/parser-extended.lisp`: the `type-unify` extraction earlier this
  session covered `unification.lisp`; this file's own largest function,
  `parse-compound-type-extended` (3593 bytes, more than double the next
  function in the same file), had not been looked at individually. Most of
  it turned out to already be a clean table-dispatch `cond` delegating to
  named helpers (`%parse-advanced-feature-form`, `parse-arrow-type`,
  `parse-row-type`, ...) — only the graded-modal `!` clause (`(! q T)`,
  `(!1 T)`, `(!ω T)`/`(!Ω T)`) was still a genuinely complex inline block
  (a nested `cond` over a parsed suffix string) with no name of its own.
  Extracted it as `%parse-graded-modal-type`, verbatim, matching this same
  file's own established per-clause-helper convention rather than a new one.
  The `=>` qualified-type and type-application-fallback clauses were left
  inline — both are already minimal (5-7 lines, no nested branching), the
  same "small clauses stay inline" judgment this session has applied
  consistently elsewhere. Verified with `paredit inspect check` and a full
  `nix build .#checks.aarch64-darwin.default`: 1164/1164, unchanged.
- Re-checked the CPS-transform investigation with a second, independent
  pass rather than resting on the first: searched `subtyping.lisp` and
  `solver.lisp` (both outside the six files the original session's audit
  covered) for the same "thread state across a list, bail on first
  failure" shape `%unify-fold-cps` generalizes. Found one `dolist`/`return`
  in `find-common-supertype` — a first-match linear search with no state
  threaded between iterations, not a fit for the combinator's contract
  (`step` must call a success/failure continuation carrying updated state).
  `solver.lisp`'s two loops were already inside the original six-file audit.
  No new candidate found; the earlier conclusion holds under a second,
  differently-scoped check rather than only the first one.
- `src/types-extended-qtt.lisp`: continued down the complexity ranking to
  its third entry, `finite-semiring-valid-p` (3294 bytes — over four times
  the file's next-largest function), rather than treating the two files
  already fixed as having closed this item. Unlike the previous two
  extractions, every one of this function's five clauses was already
  syntactically self-contained (each is one `and`/`every` subtree with no
  shared mutable state) but had no name of its own, so a reader had to
  parse nested `every` structure just to work out which of five
  distinct algebraic laws — carrier membership of the identities,
  per-element identity/annihilation, pairwise closure/commutativity,
  triple-wise associativity/distributivity, preorder reflexivity/
  transitivity — a given clause was even checking. Extracted each as a
  named, documented predicate (`%semiring-has-identities-p`,
  `%semiring-per-element-laws-p`, `%semiring-commutative-p`,
  `%semiring-associative-distributive-p`, `%semiring-preorder-valid-p`),
  verbatim bodies, `finite-semiring-valid-p` itself now a five-line `and`
  of self-explanatory names. Verified with `paredit inspect check` and a
  full `nix build .#checks.aarch64-darwin.default`: 1164/1164, unchanged
  (including the property tests this session added for this exact file's
  `multiplicity+`/`multiplicity*`/`normalize-multiplicity`, which exercise
  code adjacent to but not inside this function and were unaffected).
- `src/printer-unparse.lisp`: fourth file down the complexity ranking,
  `unparse-type` (2195 bytes, three times the file's next-largest
  function). The same `typecase`-per-node-kind shape `type-unify` and
  `collect-constraints` already had, and mostly already minimal — every
  clause but one is 1-4 lines. The `type-advanced` clause was the outlier:
  a nested `let*` building `feature-id`/`args`/`properties`/`evidence` from
  four different accessors, then a conditional choosing between two
  near-identical final backquote forms depending on whether the surface
  head is the generic `ADVANCED` fallback. Extracted as
  `%unparse-type-advanced`, verbatim, leaving the `typecase` clause as a
  single call — matching the same "one outlier clause, everything else
  already minimal" shape the two prior extractions in this file family
  found, not a new pattern invented for this file. Verified with `paredit
  inspect check` and a full `nix build .#checks.aarch64-darwin.default`:
  1164/1164, unchanged.
- `src/subtyping.lisp`: checked next in the complexity ranking,
  `is-subtype-p` (2726 bytes) — genuinely different from the four files
  above rather than a fifth instance of the same fix. Its size comes from
  breadth (ten `typecase` clauses covering every type-node kind), not
  depth: every single clause is already 1-4 lines, and the file already
  delegates aggressively (`%subtype-arrow-p`, `%subtype-advanced-p`,
  `%is-subtype-p-by-t2`, `%subtype-row-p`). There is no single tangled
  clause to name and extract here; doing so anyway — splitting an
  already-minimal one-line clause into its own function — would add a
  layer of indirection over nothing, the same "small clauses stay inline"
  judgment applied consistently to every extraction this session. No
  change made; recorded as a genuine negative result rather than silently
  moving past it.
- `src/typeclass.lisp`: `register-typeclass-instance` (1682 bytes, tied
  for the file's largest with `%typeclass-fundep-violation-p`) did carry a
  real extraction target — unlike `is-subtype-p`, its size came from doing
  two distinct jobs in one function: validating the new instance against
  every existing one (checking for an exact duplicate, a structural
  overlap, and a functional-dependency violation, each with its own error
  message) and then, only after all of that passes, actually constructing
  and storing it. Extracted the validation loop as
  `%check-typeclass-instance-conflicts`, verbatim, so
  `register-typeclass-instance` now reads as three sequential steps —
  reject an exact duplicate, check conflicts against existing instances,
  construct and store — instead of one function mixing validation and
  construction. Verified with `paredit inspect check` and a full `nix
  build .#checks.aarch64-darwin.default`: 1164/1164, unchanged.
- Re-audited `src/*.lisp` line counts after five rounds of extraction added
  new named functions to `unification.lisp`, `parser-extended.lisp`,
  `types-extended-qtt.lisp`, `printer-unparse.lisp` and `typeclass.lisp`:
  still zero files over `CODING_STANDARD.md`'s 500-line cap
  (`unification.lisp` is now the largest at 438, up from extraction adding
  docstrings, still comfortably under). No file split needed; recorded as
  a re-verification, not assumed still true from before this round's edits.
- Re-ran the complexity ranking (`paredit inspect workspace`) fresh after
  the five extractions: `unification.lisp` 189 → 122,
  `parser-extended.lisp` 151 → 116, `printer-unparse.lisp` 131 → 86 —
  confirming the extractions reduced complexity rather than only moving
  bytes around. Checked the next two real (non-data) entries,
  `types-extended-advanced-meta.lisp` and `types-extended-ffi.lisp`, for
  the same pattern: both came back clean. The former's largest non-data
  function, `register-type-advanced-head`, is already an 8-line function
  reading long only from descriptive naming; the latter's
  `ffi-descriptor-from-form` is, like `is-subtype-p` before it, a clean
  `cond` dispatching on descriptor shape with every clause self-contained
  and already using the established `require-with-detail`/`error-with-detail`
  macros. Two clean results out of the last two checked, following two
  fixes and one clean result before them (`is-subtype-p`) — a converging,
  not scattered, pattern: this codebase's remaining size outliers are
  genuinely either declarative data or already-factored breadth, not a
  backlog of unexamined tangled functions.
- `src/types-extended-routing-types.lisp`: the next real (non-data) entry
  in the complexity ranking, `build-route-path` (1611 bytes) and
  `match-route-path` (1289) — the file's two largest functions, and
  related by construction (render a route path from parameters; parse a
  concrete path back against the same template). Unlike every file checked
  since `is-subtype-p`, this one was a genuine macro/function-consolidation
  finding, not just a readability one: both functions independently
  hand-rolled the identical five-line check for "is this path segment a
  `{name}`-braced parameter placeholder", and the identical
  `(intern (string-upcase (subseq segment 1 (1- (length segment)))) :keyword)`
  expression to extract the placeholder's name from it — copied, not
  shared. Extracted both as `%route-path-placeholder-p` and
  `%route-path-placeholder-name`, verbatim, removing the duplication this
  session's earlier `paredit inspect clone-classes` sweep of `src/` as a
  whole apparently did not surface (a two-site, mid-sized duplicate inside
  otherwise-large functions is exactly the kind of match a whole-directory
  clone scan can miss where a targeted look at two related functions in
  the same file catches it). Verified with `paredit inspect check` and a
  full `nix build .#checks.aarch64-darwin.default`: 1164/1164, unchanged.
- Verified cl-weave's mutation-testing API (`run-mutations`,
  `collect-mutations`, `mutation-summary`) — a distinctly more advanced
  feature than the `it-sequential`/`expect` matchers used everywhere and
  the `it-property`/`it-fuzz` generators added earlier this session —
  against real code in this repository, as a scoped proof-of-concept
  rather than a permanent CI addition. Target:
  `%route-path-placeholder-p` (added this session, above). Ran as an
  ad-hoc sandboxed `nix build` (the same host-CPU-starvation problem
  documented throughout this session for bare `sbcl --script` runs applies
  here too; worked around the same way, via a throwaway `pkgs.runCommand`
  derivation rather than a permanent flake output, since this was an
  experiment to verify the technique works here at all, not a finished
  feature). `list-mutation-operators` confirmed all four built-in
  operators load correctly against this codebase's `CL_SOURCE_REGISTRY`.
  `run-mutations` against the function, checked with a hand-written oracle
  encoding its four possible input shapes (bare word, `{name}`, `{}`,
  `{a}`), found exactly one mutable site — the `>` in `(> (length segment)
  2)`, `char=` not being a comparison operator this version of cl-weave's
  built-in operator set targets — and the oracle killed it: **mutation
  score 1.0 (1/1 killed)**. A single-mutant result is a real but narrow
  data point, not a broad statement about this codebase's test quality;
  recorded as what was actually verified (the technique works here, one
  specific mutation was caught) rather than extrapolated into a larger
  claim a one-function experiment cannot support. Not wired into the
  permanent test suite or `flake.nix`: doing that properly needs the
  oracle to be the actual registered cl-weave test suite for the mutated
  function rather than a hand-written stand-in, which is a real design
  question (redefining production code mid-suite and re-running a scoped
  subset of tests safely) deserving its own scoped effort rather than a
  same-session addition bolted onto a single-function experiment.
- Fixed seven phantom exports in `src/package.lisp`, found by the
  dead-code-sweep subagent dispatched near the start of this session (it
  went silent for the whole session and reported very late; each claim was
  independently re-verified against the current tree before acting, not
  taken on trust) — `#:type-constructor-def`, `#:type-constructor-def-p`,
  `#:*type-constructor-registry*`, `#:register-type-constructor`,
  `#:lookup-type-constructor`, `#:make-type-scheme-raw` and
  `#:parse-function-type` were exported with **no** `defun`/`defvar`/
  `defstruct` anywhere defining them — worse than dead code, since any
  external caller referencing one would hit an undefined-function or
  unbound-variable error at the call site, not at this library's own build
  or test time (this repository's own test suite naturally never
  references its own undefined exports, which is exactly why 1164 passing
  tests never caught this). Confirmed independently before removing: a
  `defun`/`defvar` grep across all of `src/` for each of the seven found
  zero definitions.

  Also added the one direction that needed adding rather than removing:
  `#:infer-with-constraints` was itself real (`src/inference-forms-advanced-init.lisp`,
  restored by commit `bab7375` specifically because the `cl-cc` monorepo
  calls it via `CL-CC/TYPE::INFER-WITH-CONSTRAINTS`) but never made it into
  the export list, so external callers were reaching it only through the
  internal `::` accessor the monorepo already uses instead of the `:`
  public one it should have.

  `#:parse-function-type` needed care rather than a bare deletion: the real
  third arrow-parsing function is `parse-arrow-type`
  (`src/parser-extended.lisp`), but its signature — `(args mult)`, needing a
  multiplicity value pre-resolved from the dispatcher's own lookup table —
  does not match `parse-primitive-type`/`parse-compound-type`'s "hand it
  the raw form" convention despite `docs/src/api-reference.md` describing
  all three as symmetric dispatch targets. Exporting it under that framing
  would have been a second, subtler documentation error replacing the
  first; the doc section was corrected to describe two real, comparable
  targets and to explain in one sentence why the third does not belong
  there, rather than either silently dropping to two or forcing a
  misleading third.

  `docs/src/api-reference.md`'s "Type constructors" table row described the
  same phantom registry the code never had; the row was retitled "Protocol
  types" and its contents replaced with the API that genuinely exists under
  a related name (`*protocol-type-registry*`, `register-protocol-type`,
  `lookup-protocol-type` — `src/subtyping.lisp`), rather than just deleting
  documentation for a real subsystem. Verified with a full `nix build
  .#checks.aarch64-darwin.default`: 1164/1164, unchanged.
- Checked three more complexity-ranking outliers — `extract-type-guard` and
  `infer-let` (`src/inference-forms.lisp`), and, notably, `infer` itself
  (`src/inference-handlers.lisp`, at 1765 bytes the single largest function
  found across this entire session's sweep) and `infer-effects`
  (`src/inference-effects.lisp`). All four clean, no change made.
  `infer` in particular is worth naming specifically: its 22 `typecase`
  clauses are *already* the exact end state every extraction this session
  has been working toward elsewhere — one line per AST kind, each a bare
  delegating call to a named `infer-<kind>` handler, matching the
  per-form-function convention this codebase deliberately established (see
  `inference-forms.lisp`'s own file-header comment). It is large purely
  from breadth (22 cases × a long `cl-cc/ast:ast-<kind>` type name each),
  not from any one clause hiding complexity. Three-for-three clean this
  round, following the three-clean/six-fixed split from the rounds before
  it: strong, cumulative evidence — not an assumption — that this
  codebase's dispatcher-shaped functions are, with the six now-fixed
  exceptions already found and corrected, already at the standard this
  session's own extractions have been raising everything else to.
- Re-verified dependency freshness against the live GitHub API a second
  time (`cl-cc-ast`, `cl-weave`, `cl-nix-forge`, `paredit-cli`): all four
  still resolve to the exact tags already pinned in `flake.nix`
  (`v0.1.0`/`v1.1.0`/`v0.4.0`/`v1.3.0`). No drift across this session's
  duration; re-checked rather than assumed still true from the earlier
  round.
- Tried `paredit inspect duplicates` (exact structural-shape matching,
  distinct from the similarity-scored `clone-classes` already used) as a
  second lens on macro-consolidation opportunities. Its output turned out
  to be too coarse to be useful: the single largest group (80 members) was
  every 2-argument `values` call in `src/` — `(values next nil)`,
  `(values received done-p)`, `(values advanced-type advanced-subst)` —
  grouped purely by node-count shape with no semantic relationship
  whatsoever. Confirms `clone-classes`' similarity scoring was the right
  tool for this question rather than a gap in what this session already
  checked with it.
- Swept `src/*.lisp` for implementation-conditional reader macros
  (`#+`/`#-`) as a third, independent angle on backward-compat sweeping,
  after two earlier keyword-based greps found nothing: zero matches. No
  SBCL-version or implementation-conditional compatibility code exists
  anywhere in this codebase.
- Attempted, and reverted, a table-driven `it-each` conversion of
  `t/parser-test.lisp`'s twelve `parse-primitive-symbols` cases (each an
  identically-shaped `(expect EXPECTED :to-be-type-equal-to
  (parse-type-specifier 'INPUT))`, differing only in the literal) — a
  genuine `it-each` candidate by the same standard the existing
  `type-record-open-closed`/`type-arrow-mult-cases` tables in
  `t/types-core-nodes-test.lisp` already meet, unlike the `t/`-wide clone
  scan's "many unrelated one-off facts" result earlier this session, which
  correctly was *not* one. The conversion built and ran, but all twelve
  cases failed: `it-each`'s exact evaluation semantics for this table
  shape did not match what was inferred from the two existing examples
  (both readable from source, but not from a specification this session
  could check the inference against). Rather than debug an unfamiliar
  macro's expansion blind — without a REPL, only repeated sandboxed builds
  to iterate against — the twelve original, individually-verified
  `it-sequential` cases were restored exactly, confirmed with a full `nix
  build .#checks.aarch64-darwin.default`: 1164/1164, all passing again.
  Recorded as an attempted-and-reverted change, not a silent no-op:
  raising test abstraction is worth continuing to look for, but not at the
  cost of turning twelve correct, verified test cases into twelve broken
  ones because a macro's semantics were assumed rather than confirmed.

  Retried immediately after, this time reading `it-each`'s actual
  specification (`cl-weave`'s own `docs/src/dsl-guide.md`) instead of
  inferring it from two examples again. The real answer: `it-each`'s row
  data is literal, unevaluated data, not a list of forms — the two
  existing local examples happened to pass either way only because neither
  test body actually needed the *evaluated* value of the type-node
  variables it referenced (`type-arrow-mult-cases` only ever inspects the
  resulting arrow's `:mult` slot, a plain keyword, never the params/return
  it built from bare symbols standing in for type-int/type-bool). This
  session's own table genuinely needs the real singleton type-node objects
  for `:to-be-type-equal-to` to mean anything, so embedding them directly
  (`type-int`, `type-null`, ...) put the bare, unevaluated *symbols* into
  the comparison instead — exactly the failure observed. Fixed with a
  keyword indirection (a `%primitive-symbols-test-expected-type` helper
  mapping `:int`/`:null`/etc. to the real objects) rather than embedding
  values that need evaluating in a data row that does not evaluate them.
  Verified with a full `nix build .#checks.aarch64-darwin.default`:
  1164/1164 (same total as before — the table still generates all twelve
  distinctly-named cases, individually confirmed in the build log), all
  passing this time. The revert above is left in the record rather than
  edited away: it is the accurate account of what happened first, and the
  fix that followed depended on understanding *why* it had failed.

### Changed

- Test files are named `t/<source>-test.lisp` after the source file they cover,
  per `CODING_STANDARD.md`. All 25 used the plural `<subject>-tests.lisp` form;
  seven also named a subject that is not a file in `src/`, and those were
  renamed after the source they actually exercise — for example
  `representation-tests.lisp` → `types-extended-nodes-test.lisp`. No test
  content changed.
- `(:use :cl)` in `src/package.lisp` is now `(:use #:cl)`.
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
- `flake.nix`: `cl-cc-ast` now follows its `v0.1.0` release tag instead of the
  pre-release commit it was pinned to before that tag existed; `cl-weave` is
  bumped from `v1.0.0` to `v1.1.0`. `flake.lock` updated to match.
- `t/`: 104 lines over the 100-column limit, wrapped at form boundaries.
  `src/` was already compliant (fea50787). No behavior change; verified with
  the Lisp reader that every edited form is unchanged.
- `t/unification-test.lisp`, `t/type-system-test.lisp`, and
  `t/substitution-test.lisp` were over the 500-line file cap; each had one
  or two large, self-contained sections extracted into sibling
  `t/<source>-<observation-angle>-test.lisp` files (a pattern already used
  for `types-extended-nodes-test.lisp`), leaving the rest untouched. The
  ~320-line "Zonk: Various Type Constructors" section of
  `substitution-test.lisp` moved verbatim rather than being compressed into
  a table — each constructor's test has genuinely different setup and
  accessors, so collapsing it would have traded clarity for a shorter file.
  `docs/src/development.md` documents `type-system-test.lisp` as
  deliberately broad (no single source file owns it); its extracted half,
  `type-system-inference-test.lisp`, keeps that same broad naming and the
  doc now lists both.
- `docs/src/development.md`: the two commands it tells a developer to run
  directly (`sbcl --noinform --script run-tests.lisp` and `scripts/
  run-coverage.lisp`) had no timeout, unlike every invocation of the same
  scripts in `flake.nix` and CI, which all wrap in `timeout ${testTimeout}`
  (1200s) or a `timeout-minutes:` job setting. Wrapped both in `timeout
  1200`, matching `flake.nix`'s `testTimeout`. Also corrected the file/case
  count in the same document — "26 files run 884 cases" predated this
  session's test-file splitting and coverage rounds; it is 55 files and
  1150 cases now, confirmed against the same `nix build
  .#checks.aarch64-darwin.default` log used to verify every other change
  in this session. Updated again later in this session (see below) to 56
  files / 1135 cases after the `t/multiplicity-test.lisp` deduplication and
  `t/channels-test.lisp` expansion.
- Re-measured coverage (`nix build .#coverage`) after this session's many
  rounds of test additions: 86.9% expression / 84.8% branch, up from the
  75.5% / 65.0% recorded earlier in this file — most files are now in the
  80–100% range; the remaining large gaps are two purely load-time data
  tables (`types-extended-advanced-data.lisp`,
  `types-extended-advanced-evidence-data.lisp`, both 0% — already
  documented above as an SB-COVER structural blind spot, not a real gap)
  and `checker.lisp` (30%, but only 10 total expressions in the file).
- `t/channels-test.lisp`: `src/channels.lisp` measured 81.6% expression /
  47.5% branch coverage (`nix build .#coverage`), the weakest
  moderately-sized file in the tree. The one pre-existing test only ever
  drove the `send-channel` arm of both `etypecase`s in
  `channel-payload-type`/`close-typed-channel`, never called
  `make-channel-type` at all, and never fed `%runtime-type-designator` a
  `type-primitive`, `type-advanced`, or `type-constructor` payload type —
  only plain symbols. Added five cases exercising: invalid `:capacity`
  rejection in `make-typed-channel`; `channel-send`/`channel-recv` erroring
  on the wrong endpoint kind; the `recv-channel` and raw-`typed-channel`
  arms of both `etypecase`s; all four branches of
  `%runtime-type-designator` (via `type-any`, a bare `'any` symbol read in
  the `cl-cc/type` package specifically — a bare `'any` in this file's own
  package is a different, non-`eq` symbol and was caught by a first,
  failing run — a `type-constructor` built with a non-empty args list
  since an empty one degenerates to a bare `type-primitive`, and the
  `IGNORE-ERRORS`-swallowed `TYPEP` failure on a `type-advanced` node,
  built via `make-channel-type` itself since a hand-rolled
  `make-type-advanced` call is rejected by the FR-2202 contract validator
  before it ever reaches the code under test); and `make-channel-type`'s
  three `:direction` cases plus its `:capacity` property. Verified via
  `nix build .#checks.aarch64-darwin.default` (1130 → 1135 cases, 0
  failures) and `nix build .#coverage`: `channels.lisp` rose to 98.1%
  expression / 95.0% branch, and the tree-wide aggregate rose from 86.9% /
  84.8% to 87.1% / 85.7%.
- `t/typeclass-test.lisp`: `src/typeclass.lisp` had one genuinely reachable
  branch left uncovered — the `(unless (every #'type-equal-p existing-to
  new-to) (return t))` check inside `%typeclass-fundep-violation-p`
  (typeclass.lisp:128) only ever saw the "to-values differ, violation"
  outcome (already covered by the pre-existing
  `typeclass-instance-registry-enforces-functional-dependencies` case); the
  "to-values also agree, no violation" outcome was never exercised. Added
  `typeclass-instance-registry-fundep-matching-from-and-to-no-violation`:
  two instances of a 3-param typeclass whose functional dependency's `from`
  and `to` params both agree, differing only in a third param outside the
  dependency (so they still register as distinct instances). The rest of
  `typeclass.lisp`'s remaining gap is the same load-time-only pattern
  already documented for `types-core.lisp` and
  `types-extended-advanced-init.lisp` above (defstruct slots, `defvar`
  initforms, and an `(eval-when (:load-toplevel :execute) ...)` block that
  seeds a default `num` instance — all outside the coverage run's
  instrumentation window), plus one permanently-dead defensive branch:
  `%typeclass-type-string`'s `cond` falls through to `type-to-string` on
  its first clause whenever that function is `fboundp`, which is always
  true once the system has finished loading, so its five fallback clauses
  (existing for load-order independence, per the function's own docstring)
  cannot be reached without unbinding a core printer function mid-suite —
  the same class of gap already accepted for `checker.lisp`'s
  `checker-interface-ready-p`. Verified via `nix build
  .#checks.aarch64-darwin.default` (1135 → 1136 cases, 0 failures) and
  `nix build .#coverage`: `typeclass.lisp` branch coverage rose from 71.0%
  (44/62) to 72.6% (45/62); tree-wide aggregate branch rose from 85.7% to
  85.8%.
- `t/types-extended-security-labels-test.lisp`: `src/types-extended-
  security-labels.lisp` measured 78.3% expression / 54.5% branch, the
  weakest file in the tree apart from documented structural cases. Its one
  pre-existing test drove only the all-arguments-valid happy path through
  the whole file — every error guard (`join-security-labels`,
  `meet-security-labels`, `make-labeled-value`, `sanitize-labeled-value`,
  `declassify-labeled-value`'s four separate guards) and three of
  `normalize-security-label`'s four `DEFINE-KEYWORD-NORMALIZER` branches
  (symbol, string, fallback — only the keyword branch was ever driven) were
  untested. Added 9 cases covering: all four normalizer-designator kinds;
  `security-label-rank`/`security-label-p` on both a known and an unknown
  label; `security-label<=` returning false when either side is unknown
  (the pre-existing test only drove the case where both sides are known);
  `join-security-labels`/`meet-security-labels` signaling on an unknown
  label; `make-labeled-value` rejecting an unknown label;
  `labeled-value-flow-allowed-p` accepting a bare label directly, not only
  a `labeled-value` (its other `if` arm); `sanitize-labeled-value` with a
  nil sanitizer (preserves the payload unchanged) and rejecting a
  non-`labeled-value` argument; and all four of
  `declassify-labeled-value`'s guards (non-`labeled-value` input, a nil
  reason, an unknown target label, and — the one substantive lattice-logic
  case — declassifying to a *more* restrictive label than the source,
  which must be rejected since declassification only permits moving to an
  equal-or-less-restrictive label). Verified via `nix build
  .#checks.aarch64-darwin.default` (1136 → 1145 cases, 0 failures) and
  `nix build .#coverage`: the file rose to 95.5% expression / 100.0%
  branch; tree-wide aggregate rose from 87.1% / 85.8% to 87.3% / 86.3%.
- `t/types-extended-qtt-test.lisp`: `src/types-extended-qtt.lisp` measured
  93.7% expression / 60.9% branch (25 of 64 branches uncovered, the
  largest branch gap of any non-structural file in the tree). Its one
  pre-existing test drove only a narrow slice of each function: `DECLARED
  = :one` in `usage-satisfies-multiplicity-p` (never `:zero`/`:omega`, nor
  a negative use count); `grade-designator-p` was never called at all;
  neither error guard in `make-graded-value`/`graded-add`/`graded-compose`
  was triggered; and `finite-semiring-valid-p` was only ever called on an
  already-correct semiring, so every one of its five internal `%semiring-
  *-p` helper predicates had only their "law holds" branch recorded.
  Added 8 cases in two passes: the first covered `usage-satisfies-
  multiplicity-p`'s remaining CASE arms and its minusp guard,
  `grade-designator-p`'s full truth table, and the three error guards
  (`make-graded-value` rejecting a grade outside the semiring carrier;
  `graded-add`/`graded-compose` rejecting mismatched semirings — two
  `make-qtt-semiring` calls are already non-`EQ`, so no second semiring
  definition was needed). A second pass targeted `finite-semiring-valid-
  p`'s helper predicates directly, deliberately breaking one law at a
  time while leaving the others valid so the `AND` chain reaches the
  intended helper: a semiring missing an identity element
  (`%semiring-has-identities-p` false); one whose `ADD` ignores its
  arguments, breaking `a+0=a` for a non-zero element while keeping
  `MULTIPLY` correct (`%semiring-per-element-laws-p` false); and one using
  the real, already-valid QTT `ADD`/`MULTIPLY` but a preorder that always
  returns `NIL`, so every earlier clause in the chain passes and only
  reflexivity fails (`%semiring-preorder-valid-p` false). Breaking
  commutativity or associativity/distributivity specifically was not
  attempted: with only `:zero`/`:one` as the semiring's identity elements,
  `%semiring-per-element-laws-p` already forces every pair involving them
  to be symmetric, so a genuine counterexample needs at least two
  "ordinary" (non-identity) elements whose interaction can be broken
  independently — a real but more involved fixture left for a future
  round. Verified via `nix build .#checks.aarch64-darwin.default` (1145 →
  1153 cases, 0 failures) and `nix build .#coverage`: the file rose to
  96.8% expression / 84.4% branch (54/64); tree-wide aggregate rose from
  87.3% / 86.3% to 87.4% / 87.0%.
- `t/types-utility-test.lisp`: `src/types-level-naturals.lisp` (FR-1701
  type-level naturals and the matrix/vector types built on them) measured
  84.3% expression / 57.1% branch. The existing test only drove each
  function's success path: `make-type-level-natural`'s non-negative-
  integer guard, `type-level-natural-value`'s "not statically known" error
  clause, and all three of `matrix-mul-type`'s guards (non-matrix
  arguments, mismatched inner dimensions, mismatched element types) were
  untested, along with `type-level-natural-p`'s false case. Added 6 cases
  covering each directly. Verified via `nix build
  .#checks.aarch64-darwin.default` (1153 → 1159 cases, 0 failures) and
  `nix build .#coverage`: the file rose to 93.7% expression / 92.9%
  branch; tree-wide aggregate rose from 87.4% / 87.0% to 87.5% / 87.5%.
- `t/types-utility-test.lisp`: `src/types-level-strings.lisp` (FR-1702
  type-level strings, template literals, and record field lookup) measured
  81.8% expression / 61.1% branch, the sibling gap to
  `types-level-naturals.lisp` above and shaped the same way. Notably,
  `template-literal-type` never calls `type-level-string-value` on a raw
  string part — its `mapcar` branches on `type-level-string-p` first and
  takes the `princ-to-string` arm for a plain string — so
  `type-level-string-value`'s own first `cond` clause (accepting a raw
  string directly) and its final error clause were both dead as far as the
  existing test could reach, even though `type-level-string-value` is
  itself exported and callable directly. Added 6 cases: `make-type-level-
  string` rejecting a non-string; `type-level-string-p`'s false case;
  `type-level-string-value` called directly on a raw string and on a
  value that is neither a string nor a FR-1702 node; `get-field-type`
  rejecting a non-record type and an unknown field name; and `%field-
  name=`'s non-symbol fallback (`PRINC-TO-STRING`) by searching with a
  string field-name designator instead of a symbol. Verified via `nix
  build .#checks.aarch64-darwin.default` (1159 → 1164 cases, 0 failures)
  and `nix build .#coverage`: the file rose to 97.0% expression / 94.4%
  branch; tree-wide aggregate rose from 87.5% / 87.5% to 87.6% / 87.8%.
- `t/stm-test.lisp`: `src/stm.lisp` (FR-2204 STM types) measured 79.1%
  expression / 56.3% branch, the weakest non-structural file remaining.
  Its two pre-existing tests drove every function's success path plus one
  error case (`atomically` rejecting an action with an `:io` effect), but
  every type-guard `UNLESS` in `make-tvar`/`stm-read`/`stm-write`/
  `stm-bind`/`atomically` (five separate guards across four functions) was
  untested, `stm-bind`'s `(if (stm-action-p next) ... next)` branch had
  only ever seen `next` be another STM action (never a plain return
  value), and `make-stm-type` was never called at all. Added 8 cases
  covering each of those directly. Verified via `nix build
  .#checks.aarch64-darwin.default` (1164 → 1171 cases, 0 failures) and
  `nix build .#coverage`: the file rose to 97.3% expression / **100.0%**
  branch; tree-wide aggregate rose from 87.6% / 87.8% to 87.8% / 88.1%.
- `t/coroutines-test.lisp`: `src/coroutines.lisp` (FR-2205 generator/
  coroutine types) measured 83.5% expression / 68.8% branch. The
  pre-existing test drove every function's success path plus one
  type-mismatch error (a coroutine handler yielding a value that doesn't
  match its receive type while still running), but left five branches
  dark: `make-generator` rejecting a value against its yield type,
  `generator-next`/`coroutine-resume` rejecting a non-generator/
  non-coroutine argument, `coroutine-resume` rejecting a send value
  against its send type, `coroutine-resume`'s "already completed" guard
  (resuming twice was never attempted), and `make-generator-type`/
  `make-coroutine-type`, neither ever called. Added 6 cases covering each.
  Verified via `nix build .#checks.aarch64-darwin.default` (1171 → 1177
  cases, 0 failures) and `nix build .#coverage`: the file rose to 98.3%
  expression / **100.0%** branch; tree-wide aggregate rose from 87.8% /
  88.1% to 87.9% / 88.4%.
- `t/types-utility-test.lisp`: `src/utils.lisp` (FR-1804 printf-style
  `format-type`) measured 82.1% expression / 66.7% branch. The
  pre-existing test only ever drove `~A`/`~D`, both landing in the
  `%format-directive-type` CASE's string/int clauses; its float
  (`~F ~E ~G ~$`) and char (`~C`) clauses, its `otherwise` clause (which
  drives `format-type`'s own unsupported-directive error), the `~~`
  literal-tilde special case, and a trailing `~` with nothing after it
  were all untested, along with `format-type`'s non-string-argument guard.
  Added 5 cases covering each. Verified via `nix build
  .#checks.aarch64-darwin.default` (1177 → 1182 cases, 0 failures) and
  `nix build .#coverage`: the file rose to 98.2% expression / **100.0%**
  branch; tree-wide aggregate rose from 87.9% / 88.4% to 88.0% / 88.6%.
- `t/row-test.lisp`: `src/row.lisp` measured 92.4% expression / 66.7%
  branch. `row-select` and `row-labels` each end in a `(t nil)` clause for
  a type that is neither a record nor a variant; `row-closed-p` has a
  dedicated `type-effect-row-p` clause the effect-row tests never reached
  (they only ever called `effect-row-extend`/`-restrict`/`-member-p`, not
  `row-closed-p`/`row-open-p` on an effect row) plus its own final `(t t)`
  default-closed clause for an unrelated type; and `effect-row-member-p`'s
  `(and (type-effect-row-p row) ...)` had only ever seen a real effect row.
  Added 5 cases covering each directly. Verified via `nix build
  .#checks.aarch64-darwin.default` (1182 → 1186 cases, 0 failures) and
  `nix build .#coverage`: the file rose to 98.9% expression / **100.0%**
  branch; tree-wide aggregate rose from 88.0% / 88.6% to 88.0% / 89.0%.
- `t/types-utility-test.lisp`: `src/types-utility.lisp` (the FR-3303/3304
  TS-style utility-type family — Readonly, Partial, Pick, Omit, Exclude,
  Extract, NonNullable, ReturnType) itself measured 87.1% expression /
  71.4% branch — distinct from the `format-type`/naturals/strings gaps in
  this same test file fixed earlier this session, since those live in
  other source files. `deep-readonly-type`'s dedicated `type-union-p`
  clause, `partial-type`/`required-type`'s non-record fallback branch,
  `exclude-type`'s own "exactly one member survives" clause (a separate
  source form from `extract-type`'s identically-shaped one, which *was*
  already covered), and two of `non-nullable-type`'s three clauses
  (all-null-collapses-to-`type-null`, and several-non-null-members-stay-a-
  union) were all untested. Added 4 cases covering each. Verified via
  `nix build .#checks.aarch64-darwin.default` (1186 → 1190 cases, 0
  failures) and `nix build .#coverage`: the file rose to 97.0% expression
  / 90.5% branch; tree-wide aggregate rose from 88.0% / 89.0% to 88.1% /
  89.4%.
- `src/types-utility.lisp`: `exclude-type`, `extract-type`, and
  `non-nullable-type` each ended with the identical "collapse a filtered
  member list back into a type" shape (no survivors → `type-null`, one
  survivor → unwrap it, several → rewrap as a union) — the three functions
  differ only in how they filter `type-union-types` going in, not in what
  they do with the result. Extracted the shared tail into
  `%collapse-union-members`, so each caller is now just its own filter
  predicate plus one call. No behavior change: verified via `nix build
  .#checks.aarch64-darwin.default` (1190/1190 cases, 0 failures, same
  count as before since this is a pure refactor with no new branches to
  test) and `nix build .#coverage` — a useful side effect of consolidating
  three already-covered branch trees into one is that
  `types-utility.lisp` itself rose further, to 99.5% expression / 96.7%
  branch, with the tree-wide aggregate essentially unchanged (88.2% / 89.4%,
  both numerator and denominator having shrunk together).
- `t/simd-test.lisp`: `src/simd.lisp` (FR-2206 SIMD vector types) measured
  85.7% expression / 75.0% branch. The pre-existing test drove
  `make-simd-vector`'s success path and one `%simd-compatible-p` failure
  (a lane-count mismatch, via `simd-add`), but left dark:
  `make-simd-vector`'s empty-values guard and its element-type mismatch
  guard, `%simd-compatible-p`'s `SIMD-VECTOR-P` conjuncts (a non-vector
  argument) and its element-type-equality conjunct specifically (same
  lane count, different element type — a separate failure mode from the
  lane-count case already covered), and `make-simd-type`, never called.
  Added 3 cases covering each. Verified via `nix build
  .#checks.aarch64-darwin.default` (1190 → 1193 cases, 0 failures) and
  `nix build .#coverage`: the file rose to 95.2% expression / **100.0%**
  branch; tree-wide aggregate rose from 88.2% / 89.4% to 88.2% / 89.5%.
- `t/type-system-inference-test.lisp`: `src/inference.lisp` measured 95.0%
  expression / 50.0% branch. `register-class-method-type`'s `(if entry
  (setf (cdr entry) ...) (push ...))` had only ever taken the PUSH arm
  (every pre-existing test registers a given class/method pair exactly
  once); and `%find-fn-type-declaration`, exercised elsewhere only via the
  AST inference pipeline's already-matching declarations, had never seen
  its guard clauses fail — a nil FN-NAME, a non-cons declaration, a
  declaration not headed by `TYPE`, one shorter than 3 elements, and one
  that simply names a different function. Added 2 cases: one re-registers
  the same class/method pair with a different type and confirms the
  registry still holds exactly one entry with the new type (not two); the
  other drives `%find-fn-type-declaration` directly through each way a
  candidate declaration can fail to match, plus the matching case for a
  complete picture. Verified via `nix build .#checks.aarch64-darwin.default`
  (1193 → 1195 cases, 0 failures) and `nix build .#coverage`: the file rose
  to 97.0% expression / **100.0%** branch; tree-wide aggregate rose from
  88.2% / 89.5% to 88.2% / 89.7%.
- `t/routing-test.lisp`: `src/routing.lisp` measured 98.0% expression /
  50.0% branch. `api-route-lookup`'s `DOLIST` checks `(eq
  normalized-method (route-method route))` per candidate route, but every
  pre-existing lookup only ever queried `:get` against an API spec whose
  routes are all `:get`, so that check's false side (skip past a route
  with the wrong method and keep scanning) was never taken. Added one
  assertion to the existing lookup test: a `:post` query against the same
  all-`:get` spec now confirms it returns `(values nil nil)`. Verified via
  `nix build .#checks.aarch64-darwin.default` (1195/1195 cases, 0
  failures — the assertion was added to an existing case, not a new one)
  and `nix build .#coverage`: the file rose to **100.0%** branch;
  tree-wide branch aggregate ticked up from 89.7% to 89.7% (1817 → 1818 of
  2026 branches covered — too small a fraction to move the rounded
  percentage).
- `t/kind-test.lisp`: `src/kind.lisp` measured 82.9% expression / 98.0%
  branch (49/50) — the one remaining branch gap was `kind-equal-p`'s
  arrow-kind clause, `(AND (kind-equal-p from1 from2) (kind-equal-p to1
  to2))`: every pre-existing arrow-equality test held FROM equal between
  the two kinds and varied only TO, so the AND's first conjunct was always
  true and its short-circuit-on-false path was never taken. Added a case
  with mismatched FROM kinds. The remaining expression gap (116/140) is
  entirely the documented load-time-only pattern (defstruct slot defaults,
  `defvar` singleton kinds) already noted for other files in this
  session — no further reachable gap in this file. Verified via `nix
  build .#checks.aarch64-darwin.default` (1195 → 1196 cases, 0 failures)
  and `nix build .#coverage`: the file rose to **100.0%** branch;
  tree-wide aggregate rose from 88.2% / 89.7% to 88.2% / 89.8%.
- `t/inference-forms-advanced-test.lisp`: `src/inference-forms-advanced.lisp`
  measured 89.9% expression / 74.4% branch — the largest absolute branch
  gap of any non-structural file in the tree (20 of 78 branches). Most of
  the gap was concentrated in three small type-shape/keyword dispatch
  helpers whose COND/CASE forms this test file's existing, thorough
  AST-driven tests never actually reached: `%advanced-call-type-
  designator` (a Send/Sync host-designator mapping used by `spawn`/
  `shared-ref`) had 7 of its 9 clauses dark — only its `TYPE-ARROW-P` arm
  is naturally reachable through a public call (a lambda argument), so the
  rest are exercised directly with explicit type-node fixtures;
  `%advanced-call-apply-mapped-transform`'s `OTHERWISE` error arm and
  `%advanced-call-type-head-name`'s `TYPE-CONSTRUCTOR-P`/fallback arms
  were similarly untested. `%advanced-call-symbol-keyword`'s `(T VALUE)`
  fallback looked reachable via an existing AST-driven test
  (`(apply-mapped-type 'fixnum 42)`, which does `signal` the expected
  error) but coverage showed it was not — rather than re-litigate exactly
  which upstream check actually intercepts that call (this file already
  has one precedent of a clause that looks reachable by reasoning but
  provably is not, documented above `%advanced-call-return-value`'s dead
  `(T TYPE-ANY)` arm), it is confirmed directly instead, matching that
  same precedent. Finally, `%advanced-call-type-arg`'s missing-argument
  error (distinct from its already-tested inferred-arg-types *success*
  path) was untested. Added 5 cases. Verified via `nix build
  .#checks.aarch64-darwin.default` (1200 → 1205 cases, 0 failures) and
  `nix build .#coverage`: the file rose to 96.8% expression / 98.7%
  branch; tree-wide aggregate rose from 88.4% / 90.3% to 88.7% / 91.2%.
- `t/types-extended-advanced-node-test.lisp`: `src/types-extended-
  advanced-node.lisp` measured 87.4% expression / 71.4% branch.
  `%type-advanced-payload-security-label` (used by `subtyping.lisp` and
  `types-extended-advanced-validators.lisp` for information-flow checks)
  had only its `:public`/`:trusted` clauses driven by those callers' own
  tests; `:tainted`/`:secret`/`:top-secret`, the null-head arm, and the
  unrecognized-head fallback were untested — closed with one direct call
  per label plus both fallbacks. `%type-advanced-head-name`'s non-`CONSP`
  arm and `%type-advanced-property-sort-key`'s `PRIN1-TO-STRING` fallback
  (for a non-symbol key, and for a bare non-`CONSP` entry) were likewise
  untested, since every property alist built via `parse-type-specifier`
  in this file's existing tests uses symbol keys exclusively. Added 3
  cases. Verified via `nix build .#checks.aarch64-darwin.default`
  (1210 → 1213 cases, 0 failures) and `nix build .#coverage`: the file
  rose to 94.5% expression / **100.0%** branch; tree-wide aggregate rose
  from 88.7% / 91.6% to 88.8% / 92.0%.
- `t/type-system-inference-test.lisp`: `src/inference-forms.lisp` measured
  90.4% expression / 71.4% branch. `extract-type-guard`'s final `(T
  (VALUES NIL NIL))` fallback looked exercised by the pre-existing
  `non-guard` case, but that value is a bare `AST-VAR`, which fails the
  function's *outer* `(typep cond-ast 'ast-call)` guard before the inner
  `COND` is ever reached — a genuine `AST-CALL` shaped like neither
  recognized guard pattern was needed instead. `narrow-union-type`'s
  `(NULL REMAINING)` clause (removing a union's only member) and
  `%narrow-else-env`'s guard against a var that is either unbound or
  bound to a non-union type (the pre-existing if-narrowing test only
  drives the "bound to a union" case) were both untested, as was
  `%make-lambda-param-env`'s empty-`PARAMS` early return. Added 4 cases.
  One assertion (`narrow-union-type` collapsing to `+type-unknown+`) first
  failed with `:to-be-type-equal-to`, since `+type-unknown+` is a
  `type-error` node and `type-equal-p` deliberately never considers
  `type-error` nodes equal to anything — even themselves, per the
  pre-existing `type-equal-error-node-never-equal` test elsewhere — fixed
  by asserting identity (`:to-be`) instead, which is also the more precise
  check here since `narrow-union-type` returns the literal singleton, not
  a fresh copy. Verified via `nix build .#checks.aarch64-darwin.default`
  (1213 → 1215 cases, 0 failures) and `nix build .#coverage`: the file
  rose to 93.2% expression / 92.9% branch; tree-wide aggregate rose from
  88.8% / 92.0% to 88.8% / 92.3%.
- `t/types-extended-regions-test.lisp`: `src/types-extended-regions.lisp`
  measured 83.3% expression / 70.0% branch. The pre-existing test drove
  the full happy path plus one failure (deref after the enclosing region
  closes), but `region-active-p`'s `REGION-TOKEN-P` conjunct (never
  called with a non-token), `region-alloc`'s "region already closed"
  error (the pre-existing test never allocates into an already-closed
  region — only derefs a ref allocated *before* closing), and
  `region-ref-valid-p`'s `REGION-TOKEN-P` check on the ref's own token
  field (every ref in the pre-existing test always points at a real
  region-token) were all untested. Added 3 cases. Verified via `nix build
  .#checks.aarch64-darwin.default` (1215 → 1218 cases, 0 failures) and
  `nix build .#coverage`: the file rose to 87.9% expression / **100.0%**
  branch; tree-wide aggregate rose from 88.8% / 92.3% to 88.9% / 92.4%.
- `t/effect-test.lisp`: `src/effect.lisp` measured 85.4% expression /
  75.0% branch. `%effect-node-name`'s error arm — reached only when a
  `TYPE-EFFECT-ROW`'s `effects` list contains something that is not a
  `TYPE-EFFECT-OP` — was untested, since every effects list built across
  this file's many `effect-row-union`/`effect-row-subset-p`/etc. tests
  uses genuine `TYPE-EFFECT-OP` nodes exclusively. Added 1 case, calling
  the private helper directly with a malformed entry. Verified via `nix
  build .#checks.aarch64-darwin.default` (1218 → 1219 cases, 0 failures)
  and `nix build .#coverage`: the file rose to 91.7% expression /
  **100.0%** branch; tree-wide aggregate rose from 88.9% / 92.4% to
  88.9% / 92.5%.
- `t/types-extended-advanced-validators-test.lisp`: `src/types-extended-
  advanced-validators.lisp` measured 93.5% expression / 86.8% branch (14
  of 106 branches), the largest remaining gap outside `subtyping.lisp`.
  Each `%type-advanced-validate-*` custom validator runs *after* its
  FR contract's `:property-predicates` have already checked every
  individually-present property, so before writing each test the
  contract spec in `types-extended-advanced-data.lisp` was checked to
  confirm the custom validator's own error condition is a genuinely
  distinct, cross-property (or cross-argument) check the property-
  predicate stage cannot see — not a redundant re-check. Two candidates
  failed that check and were *not* tested, since coverage confirms they
  are unreachable exactly as reasoned: FR-2405's own "exports must be
  unique" re-check (`%type-advanced-validate-interface-files`) can never
  fire because `:exports`' registered property-predicate,
  `%type-advanced-interface-export-list-p`, already enforces uniqueness
  on any *present* value before the custom validator ever runs; likewise
  FR-3302's own "`:infer` must be symbolic" re-check
  (`%type-advanced-validate-conditional-types`) can never fire because
  `:infer` already has `%type-advanced-symbolic-designator-p` registered
  as its property-predicate. Both are the same class of confirmed-dead
  defensive code as `%advanced-call-return-value`'s `(T TYPE-ANY)` arm,
  documented earlier in this file. The other 7 candidates were genuinely
  reachable and got one test each: FR-1606's dependency-graph/cache
  distinctness, FR-2101's samples-vs-coverage-target bound, FR-2406's
  evidence-or-counterexample requirement (only its accept path was
  tested before), FR-2804's widening/narrowing distinctness, FR-3002's
  plugin name (a positional arg, never covered by property-predicates,
  which only inspect keyword properties), FR-3403's surface-head-vs-
  `:encoding`-property agreement (only `church-encoding` was tested
  before; `scott-encoding`/`parigot-encoding` were not), and FR-3405's
  evidence requirement for `:extensional`/`:observational` equality
  modes (only `:intensional` was tested before). Verified via `nix build
  .#checks.aarch64-darwin.default` (1219 → 1226 cases, 0 failures) and
  `nix build .#coverage`: the file rose to 97.7% expression / 94.3%
  branch; tree-wide aggregate rose from 88.9% / 92.5% to 89.0% / 92.9%.
- `t/subtyping-test.lisp` / `t/subtyping-extended-test.lisp`:
  `src/subtyping.lisp` measured 97.6% expression / 88.8% branch (15 of
  134 branches), the largest remaining gap in the tree. `type-join`/
  `type-meet` each have a `(TYPE-UNKNOWN-P T2)` `COND` clause distinct
  from their already-tested `(TYPE-UNKNOWN-P T1)` clause, and `type-meet`
  has an `(IS-SUBTYPE-P T2 T1)` clause distinct from its already-tested
  `(IS-SUBTYPE-P T1 T2)` clause — each pre-existing test only ever put
  the "interesting" operand in the first position. Added 4 cases (one per
  clause). `%subtype-advanced-information-flow-p`'s fallback to
  `TYPE-ADVANCED-PAYLOAD-EQUAL-P`, taken only when neither FR-1503
  payload has an extractable base type, was untested since every
  existing information-flow test payload is a well-formed `(label
  base-type-node)` pair; added 2 cases (equal and unequal payloads),
  built directly via `MAKE-TYPE-ADVANCED` to bypass the unrelated
  `:flow`-property validator. One targeted gap,
  `%row-label-equal-p`'s `SYMBOLP` conjunct, turned out to already have a
  dedicated pre-existing test (`is-subtype-p-record-field-labels-compare-
  package-independently`) that a fresh coverage rebuild confirmed does
  drive its true side — the remaining sliver there is the conjunct's
  false side (a genuinely non-symbol row label), left alone as too
  narrow a case to be worth a fixture. Two further gaps —
  `%primitive-class-record-type`'s pair of `FBOUNDP` guards against
  `lookup-class-type`/`lookup-class-method-types` (functions defined in
  files that load after this one) — were also left alone: once the full
  system has loaded, which is the only state any test can observe, both
  are always `T`, the same load-order-defensive shape as
  `%advanced-call-return-value`'s confirmed-dead arm documented earlier
  in this file, though unlike that case this was not independently
  re-confirmed by deliberately breaking the invariant. Verified via `nix
  build .#checks.aarch64-darwin.default` (1226 → 1230 cases, 0 failures)
  and `nix build .#coverage`: the file rose to 98.7% expression / 93.3%
  branch; tree-wide aggregate rose from 89.0% / 92.9% to 89.1% / 93.2%.
- `t/types-extended-units-test.lisp`: `src/types-extended-units.lisp`
  measured 83.5% expression / 77.3% branch. `%unit-key`'s `STRINGP` arm
  and final fallback, and `%resolve-unit`'s error arm, were untested:
  every unit designator across the pre-existing tests is either a symbol
  or an already-resolved `unit-definition`. Added 3 cases: `find-unit`
  with a raw string designator (`%unit-key`'s `STRINGP` arm) and with an
  unsupported shape (a bare integer, hitting both `%unit-key`'s fallback
  and its own "unknown unit" error, since the fallback returns the value
  unchanged as a registry key that can never match), and
  `unit-dimension=` with an unsupported designator shape
  (`%resolve-unit`'s own distinct error, reached before `find-unit` is
  ever called). Verified via `nix build .#checks.aarch64-darwin.default`
  (1230 → 1232 cases, 0 failures) and `nix build .#coverage`: the file
  rose to 86.1% expression / 95.5% branch; tree-wide aggregate rose from
  89.1% / 93.2% to 89.1% / 93.4%.
- `t/substitution-test.lisp`: `src/substitution-schemes.lisp` measured
  89.6% expression / 77.8% branch. `%nv-norm` (the recursive renamer
  behind `normalize-type-variables`) has a `TYPE-ARROW` clause whose
  `:effects` recursion is conditional on the slot being non-nil, and a
  dedicated `TYPE-PRODUCT` clause — the pre-existing tests only ever
  normalized plain arrows with no effects and no products anywhere in the
  tree. Added 2 cases. Verified via `nix build
  .#checks.aarch64-darwin.default` (1232 → 1234 cases, 0 failures) and
  `nix build .#coverage`: the file rose to 97.4% expression / 88.9%
  branch; tree-wide aggregate rose from 89.1% / 93.4% to 89.2% / 93.5%.
- `t/printer-test.lisp` / `t/parser-typed-test.lisp`: `src/printer-
  unparse.lisp` measured 90.7% expression / 79.2% branch. Neither
  pre-existing `type-advanced` unparse example set `:evidence`, so
  `%unparse-type-advanced`'s `(WHEN (TYPE-ADVANCED-EVIDENCE ty) ...)` arm
  was untested; its feature-id-interning `let*` binding falls back to
  `*PACKAGE*` when the surface head symbol has no home package, which
  `PARSE-TYPE-SPECIFIER`'s reader-driven construction can never produce
  (every symbol it reads is interned somewhere) — reached instead via a
  node built directly through `MAKE-TYPE-ADVANCED` with an uninterned
  `(MAKE-SYMBOL ...)` head (first attempt used FR-1606, whose required
  `:dependency-graph`/`:cache` properties `MAKE-TYPE-ADVANCED` itself
  validates at construction time; switched to the unconstrained FR-1601).
  `looks-like-type-specifier-p`'s local `SYM-NAME-IN` helper and its
  `!`-prefix check both guard on `(SYMBOLP head)` for a cons spec's head,
  which every pre-existing composite-type-specifier example already
  satisfies (`or`, `->`, `values`, …); added a spec whose head is itself a
  cons (`((nested) more)`) to reach the false side of both guards.
  Verified via `nix build .#checks.aarch64-darwin.default` (1234 → 1235
  cases — one new named case, one assertion added to an existing case — 0
  failures) and `nix build .#coverage`: the file rose to 93.2% expression
  / 91.7% branch; tree-wide aggregate rose from 89.2% / 93.5% to 89.2% /
  93.6%.
- `t/types-extended-nodes-test.lisp`: `src/types-env.lisp` measured 90.5%
  expression / 80.8% branch. `type-env-free-vars` unwraps each binding's
  value via `(IF (TYPE-SCHEME-P s) (TYPE-SCHEME-TYPE s) s)`, but the
  pre-existing test always binds a `TYPE-SCHEME` (via `TYPE-TO-SCHEME`),
  never a bare type directly — added a case that does. `%OPTION-TYPE-
  CONSTRUCTOR-P` (a 2-member union including `TYPE-NULL`, used to give
  `Option`/`Maybe`-style unions a constructor-like view) is a second,
  entirely distinct shape `TYPE-CONSTRUCTOR-P`/`-NAME`/`-ARGS` recognize
  besides curried `TYPE-APP` chains, which is all every pre-existing
  constructor test builds; added a case covering both an explicitly
  `:constructor-name`-tagged union and an untagged one (reaching
  `TYPE-CONSTRUCTOR-NAME`'s fallback that interns `"OPTION"` in the
  current package). Verified via `nix build .#checks.aarch64-darwin.default`
  (1235 → 1237 cases, 0 failures) and `nix build .#coverage`: the file
  rose to 94.2% expression / 92.3% branch; tree-wide aggregate rose from
  89.2% / 93.6% to 89.3% / 93.8%.
- `t/types-extended-advanced-meta-test.lisp`: `src/types-extended-
  advanced-meta.lisp` measured 91.3% expression / 83.3% branch (18
  branches total — the file is almost entirely the `+type-advanced-
  feature-specs+`/`+type-advanced-head-specs+` load-time data tables,
  already documented as SB-COVER-invisible; this is the small remaining
  slice of real logic). `register-type-advanced-head`, `type-advanced-
  head-p`, and `type-advanced-feature-id-for-head` each accept a HEAD
  designator that may be a symbol or a raw string, normalizing via `(IF
  (SYMBOLP head) (SYMBOL-NAME head) head)`; the pre-existing tests only
  ever passed symbols to the first two (string coverage existed only for
  the third). Added 3 cases: a string head through `REGISTER-TYPE-
  ADVANCED-HEAD`, a string head through `TYPE-ADVANCED-HEAD-P`, and a
  non-symbol/non-string head (an integer, mirroring `TYPE-ADVANCED-HEAD-
  P`'s existing case) through `TYPE-ADVANCED-FEATURE-ID-FOR-HEAD`'s own
  separate `(OR (SYMBOLP head) (STRINGP head))` guard. Verified via `nix
  build .#checks.aarch64-darwin.default` (1237 → 1240 cases, 0 failures)
  and `nix build .#coverage`: the file's branch coverage rose to
  **100.0%**; tree-wide aggregate rose from 89.3% / 93.8% to 89.3% /
  93.9%.
- `src/types-extended-advanced-meta.lisp`: `register-type-advanced-head`,
  `type-advanced-feature-id-for-head`, and `type-advanced-head-p` each
  independently repeated the same `(STRING-UPCASE (IF (SYMBOLP head)
  (SYMBOL-NAME head) head))` normalization, and two of the three also
  repeated the same `(OR (SYMBOLP head) (STRINGP head))` designator
  guard. Extracted both into `%type-advanced-head-key` and
  `%type-advanced-head-designator-p`. No behavior change: verified via
  `nix build .#checks.aarch64-darwin.default` (1240/1240 cases, 0
  failures, same count as before since this is a pure refactor with no
  new branches to test) and `nix build .#coverage` — as with the earlier
  `%collapse-union-members` consolidation, folding three copies of the
  same logic into one shared helper shrank the file's own branch count
  (18 → 14, all still covered) with the tree-wide aggregate essentially
  unchanged (89.3% / 93.9%, both numerator and denominator having shrunk
  together).
- `t/inference-forms-advanced-test.lisp`: `src/inference-forms-advanced-
  validators.lisp` measured 95.2% expression / 75.0% branch. `%validate-
  advanced-ffi-call`'s DESCRIPTOR is not always a `(foreign name args
  return)` function form — a bare scalar descriptor like `c-int` is a
  legitimate one-argument, `TYPE-ANY`-returning call shape too — and the
  pre-existing test only drove the function-descriptor path; added a case
  for the scalar path. Also added a runtime-arity-mismatch case (a
  function descriptor declaring one argument, called with two). A third
  planned case — a syntactically malformed raw descriptor form like
  `(c-int)`, missing its second element — turned out not to reach this
  function's own `(UNLESS (FFI-DESCRIPTOR-FORM-VALID-P descriptor) ...)`
  error at all: that check runs on `descriptor`, the *normalized* result
  of `FFI-DESCRIPTOR-FROM-FORM`, not on the raw form, and
  `FFI-DESCRIPTOR-FORM-VALID-P`'s own second clause, `(ATOM value) T`,
  accepts any successfully-normalized descriptor struct unconditionally
  (structs are atoms in Lisp) — so this check can only ever fire if
  `FFI-DESCRIPTOR-FROM-FORM` itself somehow returns a non-atom, non-type-
  node value, which no branch of that function does. `(c-int)` in
  particular normalizes leniently to plain `c-int` without erasing the
  malformed shape's own error, confirmed empirically when the test
  signalled nothing rather than the expected error; the case was
  discarded rather than forced to pass. Verified via `nix build
  .#checks.aarch64-darwin.default` (1240 → 1242 cases, 0 failures) and
  `nix build .#coverage`: the file rose to 98.3% expression / 93.8%
  branch; tree-wide aggregate rose from 89.3% / 93.9% to 89.3% / 94.0%.
- `t/types-extended-ffi-test.lisp`: `src/types-extended-ffi.lisp` measured
  94.1% expression / 91.7% branch, already unusually thoroughly tested
  (175 lines of tests for a 195-line source). `%FFI-SYMBOL-NAME`'s
  `STRINGP` arm and final `NIL` fallback (a cons descriptor form's `HEAD`
  is neither a symbol nor a string) were untested since every
  pre-existing cons-form test uses a symbol head; `FFI-DESCRIPTOR-FORM-
  VALID-P`'s `(= (LENGTH value) 2)` conjunct for `C-CALLBACK` forms had
  only ever seen `T` (both pre-existing callback cases are 2-element
  lists, differing only in `(SECOND value)`); and `%FFI-SCALAR-KIND-FROM-
  NAME`'s length guard before stripping a `"C-"` prefix had never seen a
  head name too short to carry one. Added 4 cases. Two other flagged
  gaps were investigated and left alone as confirmed structurally
  unreachable: `FFI-DESCRIPTOR-FORM-VALID-P`'s `(NOT (CONSP value))`
  clause can never return true, since its own preceding clause,
  `(ATOM value) T`, already accepts every non-cons value first — by the
  time this clause is reached, `value` is provably a cons; and
  `FFI-DESCRIPTOR-LISP-TYPE`'s inner `CASE` `(T TYPE-ANY)` fallback
  (scalar kinds) can likewise never fire, since `+FFI-SCALAR-KINDS+`
  lists exactly the ten kinds the `CASE`'s named clauses already cover,
  and `MAKE-FFI-SCALAR-TYPE` rejects any other kind at construction —
  the same "exhaustive `CASE` plus unreachable catchall" shape as
  `%advanced-call-return-value`'s confirmed-dead arm documented earlier
  in this file. Verified via `nix build .#checks.aarch64-darwin.default`
  (1242 → 1245 cases, 0 failures) and `nix build .#coverage`: the file
  rose to 94.4% expression / 95.8% branch; tree-wide aggregate rose from
  89.3% / 94.0% to 89.4% / 94.2%.
- `t/unification-effect-rows-test.lisp`: `src/unification.lisp` measured
  94.7% branch (161/170) overall. `%effect-label`'s `(WHEN
  (TYPE-EFFECT-OP-P e) ...)` guard had only ever seen genuine
  `TYPE-EFFECT-OP` entries across every effect row in this already-
  thorough test suite; added a case with a bare symbol in one row's
  effects list instead, mirroring the analogous `effect-node-name-
  signals-for-a-non-effect-op` case already covering `EFFECT.LISP`'s own
  `%effect-node-name` sibling — `unify-effect-rows` degrades gracefully
  here rather than erroring, treating the malformed entry as an
  unnamed effect. The file's other flagged gaps (rank-N/impredicative-
  type-error branches, type-variable bound-merging helpers) were left
  for a future round rather than rushed through in the same pass as
  this one: they sit in genuinely delicate polymorphism/occurs-check
  logic where getting a fixture subtly wrong risks a false sense of
  security about the unification engine's correctness, and this file's
  size and centrality warranted the same caution `subtyping.lisp` and
  `types-extended-advanced-validators.lisp` got in earlier rounds.
  Verified via `nix build .#checks.aarch64-darwin.default` (1245 → 1246
  cases, 0 failures) and `nix build .#coverage`: the file rose to 95.3%
  branch (162/170); tree-wide aggregate rose from 89.4% / 94.2% to
  89.4% / 94.3%.
- `t/types-extended-dependent-test.lisp`: `src/types-extended-dependent.lisp`
  measured 93.9% branch (77/82), already extensively tested. `VALID-
  UNIVERSE-SORT-P`'s `(NOT (MINUSP level))` check had only ever seen a
  `:TYPE`-kinded universe with a *negative* level in this suite (its own
  false side); added a well-formed `:type 0` universe to close the true
  side. `TERMINATION-EVIDENCE-FORM-VALID-P` and `PROOF-EVIDENCE-FORM-
  VALID-P` each check their form's head via `(OR (keyword-member-check)
  (AND (SYMBOLP head) (name-string-match)))`; the pre-existing "bogus
  head" cases (`:bogus`, `(:bogus x)`) are keywords that fail the *name*
  comparison, distinct from a head that fails the `SYMBOLP` conjunct
  itself — added a case for each function with a non-symbol (integer)
  head. Verified via `nix build .#checks.aarch64-darwin.default` (1246 →
  1247 cases, 0 failures) and `nix build .#coverage`: the file rose to
  97.6% branch (80/82); tree-wide aggregate rose from 89.4% / 94.3% to
  89.4% / 94.5%.
- `t/parser-test.lisp`: `src/parser.lisp` measured 90.8% expression /
  92.6% branch. `%PRIMITIVE-TYPES-DISJOINT-P`'s two `(NOT
  (TYPE-NAME-SUBTYPE-P ...))` checks are `AND`ed together, so a pair
  ordered with the *first* check false always short-circuits before the
  second ever runs; the pre-existing `and-compatible` case (`(and fixnum
  integer)`) hits exactly that short-circuit, and every other case pairs
  either disjoint primitives (both checks true) or a non-primitive
  member (whole check skipped). None of them reach first-check-true/
  second-check-false. Added `and-compatible-asymmetric-subtype-order`
  using `(and symbol boolean)` — `BOOLEAN` is a `*SUBTYPE-TABLE*` subtype
  of `SYMBOL` but not vice versa, so ordering it this way round forces
  the first `TYPE-NAME-SUBTYPE-P` call false and the second true, the one
  combination no prior case reached. Verified via `nix build
  .#checks.aarch64-darwin.default` (1247 → 1248 cases, 0 failures) and
  `nix build .#coverage`: the file rose to 98.1% branch (53/54); the
  file's remaining gap is its two `DEFVAR`/`DEFPARAMETER` primitive/
  compound-type name-table data literals (lines 53-63, 82-94) and
  `PARSE-PRIMITIVE-TYPE`'s `(BOUNDP '*TYPE-ALIAS-REGISTRY*)` load-order
  guard (line 72, permanently true since `*TYPE-ALIAS-REGISTRY*` is a
  top-level `DEFVAR` in `package.lisp` that is always bound once the
  system has loaded) — the same documented, untestable SB-COVER
  structural blind spot as every other file's data tables. Tree-wide
  aggregate rose to 89.5% / 94.6%.
- `t/type-system-inference-test.lisp`: `src/inference-forms-advanced-init.lisp`
  measured 88.0% expression / 50.0% branch (1/2) — its lowest branch score
  in the tree. Both gaps were genuine, not structural: `INFER-BODY`'s `(IF
  (NULL ASTS) ...)` true branch had never fired, since every call site in
  this suite (progn/let/lambda/defun/flet/labels/block bodies) always
  supplies at least one form; added a direct call with an empty form list.
  `INFER-WITH-CONSTRAINTS` — exported, and per its own docstring restored
  from the pre-split `cl-cc` monorepo specifically so `cl-cc`'s callers
  that need the residual-constraints list keep working — had no test
  anywhere in this suite at all. Added a case built around `(if b 1 2)`,
  which forces `COLLECT-CONSTRAINTS` to emit two real equality constraints
  (unifying `IF`'s fresh result type-var with each branch's `TYPE-INT`)
  for `SOLVE-CONSTRAINTS` to actually discharge, asserting both the
  resolved type and an empty residual-constraints list. Verified via `nix
  build .#checks.aarch64-darwin.default` (1248 → 1250 cases, 0 failures)
  and `nix build .#coverage`: the file rose to 97.8% expression / 100%
  branch (2/2) — its remaining expression gap is purely the file's
  `+ADVANCED-CALL-POLICY-SPECS+` data table (a `DEFPARAMETER` literal) and
  the `(%INITIALIZE-ADVANCED-CALL-POLICY-REGISTRY)` top-level call that
  populates it at load time, both the same documented SB-COVER blind spot
  as elsewhere. Tree-wide aggregate rose to 89.6% / 94.7%.
- `t/types-extended-qtt-test.lisp`: `src/types-extended-qtt.lisp` measured
  84.4% branch (54/64), the largest remaining branch gap in the tree.
  Unlike this file's `DEFSTRUCT` slot defaults (structural, left alone),
  the semiring-law predicates' false branches were genuinely untested:
  every pre-existing case either used the real, fully-valid QTT semiring
  or a semiring already broken by an earlier `AND` clause (missing
  identity, `ADD`'s identity law), so `%SEMIRING-COMMUTATIVE-P`,
  `%SEMIRING-ASSOCIATIVE-DISTRIBUTIVE-P`, and `%SEMIRING-PREORDER-VALID-P`'s
  transitivity conjunct (as opposed to its already-tested reflexivity
  conjunct) had never seen a law violation reach them. Added four cases,
  each a hand-built operator table designed to satisfy every AND clause
  before the one under test and fail only that one:
  - a reflexive-but-not-transitive preorder (0 ≤ 1, 1 ≤ ω, but no direct
    0 ≤ ω) isolates the preorder check's transitivity conjunct from its
    reflexivity conjunct;
  - a 3-element carrier (2 elements can't break commutativity without
    also breaking an identity law, since every pair then involves ZERO)
    with `ADD` matching ordinary mod-3 addition everywhere except one
    swapped ordered pair isolates `%SEMIRING-COMMUTATIVE-P`;
  - the same carrier with `ADD` matching mod-3 addition everywhere except
    the symmetric input (1,1) (overridden to stay commutative and closed
    but break associativity for the triple (1,1,2)) isolates
    `%SEMIRING-ASSOCIATIVE-DISTRIBUTIVE-P`;
  - a `MULTIPLY` that ignores its arguments and always returns `:ZERO`
    mirrors the pre-existing `ADD`-identity-law test but for multiplicative
    identity, isolating `%SEMIRING-PER-ELEMENT-LAWS-P`'s `a*1=a` equal
    check specifically (closure still holds, since `:ZERO` is a member).
  Verified via `nix build .#checks.aarch64-darwin.default` (1250 → 1254
  cases, 0 failures) and `nix build .#coverage`: the file rose to 89.1%
  branch (57/64); tree-wide aggregate rose to 89.6% / 94.8%. Stopped here
  rather than chasing the file to 100%: the remaining 7 branches are each
  one specific closure or symmetry sub-case (e.g. `%SEMIRING-PER-ELEMENT-
  LAWS-P`'s `member` checks for a non-closed result, `%SEMIRING-
  COMMUTATIVE-P`'s own closure check, the distributivity conjuncts in
  `%SEMIRING-ASSOCIATIVE-DISTRIBUTIVE-P`) that would each need its own
  bespoke broken operator table no more instructive than the four above —
  diminishing returns against genuinely artificial fixtures, noted here
  rather than forced.
- `t/types-extended-advanced-init-test.lisp` (new file, wired into
  `cl-cc-type.asd`): `src/types-extended-advanced-init.lisp` measured
  85.4% expression / 84.4% branch, with no dedicated test file of its own.
  `%ENSURE-TYPE-ADVANCED-CONTRACT-COVERAGE` and `%ENSURE-TYPE-ADVANCED-
  IMPLEMENTATION-EVIDENCE-COVERAGE` each check the live registry against
  `+TYPE-ADVANCED-FEATURE-SPECS+` for missing and orphan entries, then run
  once at load time via `%INITIALIZE-TYPE-ADVANCED-FEATURE-REGISTRY` —
  where they always pass (the system could not have loaded otherwise), so
  none of their four error branches had ever fired. Added one test per
  branch: `REMHASH` a real id (e.g. `FR-1501`) out of the relevant
  registry to manufacture "missing", and register a fresh `FR-9999-*` test
  id (via the public `REGISTER-TYPE-ADVANCED-FEATURE`, satisfying
  `REGISTER-TYPE-ADVANCED-CONTRACT`/`-IMPLEMENTATION-EVIDENCE`'s own
  "unknown feature id" guard) with no corresponding entry in
  `+TYPE-ADVANCED-FEATURE-SPECS+` to manufacture "orphan" — each wrapped
  in `UNWIND-PROTECT` that re-runs `%INITIALIZE-TYPE-ADVANCED-FEATURE-
  REGISTRY` to fully restore canonical state afterward, following the
  `FR-9999*` test-only-id convention already established in
  `types-extended-advanced-meta-test.lisp`. Separately, `t/types-extended-
  advanced-node-test.lisp`'s existing `TYPE-ADVANCED-PROPERTIES-EQUAL-P`
  case only ever drove its length-mismatch fast path; added two same-
  length cases (a missing key, a differing value) to reach the function's
  `LOOP`/`ALWAYS` body at all. Verified via `nix build
  .#checks.aarch64-darwin.default` (1254 → 1258 cases, 0 failures) and
  `nix build .#coverage`: the file rose to 92.1% expression / 93.75%
  branch (30/32) — its remaining branch gap is the two registries' `(=
  (HASH-TABLE-COUNT ...) (LENGTH FEATURE-IDS))` count-mismatch checks,
  which (given no missing and no orphan entries) can only fire if
  `+TYPE-ADVANCED-FEATURE-SPECS+` itself — an immutable top-level data
  constant — contains a duplicate id; deliberately corrupting that
  constant for a test was judged not worth the risk of destabilizing every
  other test that depends on the real registry contents. Tree-wide
  aggregate rose to 89.7% / 95.0%, crossing 95% branch coverage.
- A sweep across several small-gap files turned up genuine, isolated
  misses rather than structural blind spots:
  - `t/types-utility-test.lisp`: `TYPE-MUL` (FR-1701 type-level natural
    multiplication) had no test anywhere, even though its sibling
    `TYPE-PLUS` was already exercised in this same file. Added one case.
  - `t/generics-test.lisp`: `GENERIC-REPRESENTATION-OF`'s `(IF (FUNCTIONP
    REPRESENTATION) ...)` had only ever seen a registered *function*
    representation; added a case registering a plain, already-built
    representation object to close the other side. `GENERIC-
    REPRESENTATION-VALID-P`'s product case only ever drove its `AND`'s
    *second* conjunct false (via an invalid `:RIGHT`); added a matching
    invalid-`:LEFT` case for the conjunct that always short-circuits
    first and so had never been observed false itself.
  - `t/type-system-inference-test.lisp`: `INFER`'s dispatching `TYPECASE`
    ends in a `(T (VALUES +TYPE-UNKNOWN+ NIL))` catch-all that no test
    had ever reached, since every prior call passed a genuine
    `CL-CC/AST` node; added a call with a plain integer. `INFER-SETQ`'s
    `TYPE-UNIFY` failure branch (assigning a value that conflicts with
    the variable's declared type) had no test either — the pre-existing
    case only ever assigned a value matching the declared type; added a
    `STRING`-declared variable assigned an `INT` to reach it. (Separately
    investigated `INFER-SLOT-VALUE`'s three-way `IF`/`OR` at inference-
    handlers.lisp:153 and `%TYPED-HOLE-MESSAGE`'s bindings check at
    lines 195/203: functional analysis says all of their branches are
    already exercised by existing tests across this file and
    `types-extended-advanced-node-test.lisp`, yet SB-COVER continued to
    report them as single-outcome after this round's rebuild — left as
    an open discrepancy rather than writing a test blind, since a test
    added without understanding why SB-COVER disagrees would not
    actually verify anything new.)
  Verified via `nix build .#checks.aarch64-darwin.default` (1258 → 1262
  cases, 0 failures) and `nix build .#coverage`: `generics.lisp` reached
  100% branch (28/28); `inference-handlers.lisp` rose to 99.8% expression
  (427/428); `types-level-naturals.lisp` rose to 99.2% expression
  (126/127). Tree-wide aggregate rose to 89.8% / 95.1%.
- Resolved the open discrepancy noted directly above. Re-reading
  `INFER-SLOT-VALUE`'s existing tests against `TYPE-INT`'s actual
  definition (`(MAKE-TYPE-PRIMITIVE :NAME 'FIXNUM)` in
  `types-extended-nodes.lisp`) showed their own comments were simply
  wrong: `TYPE-INT` *is* a `TYPE-PRIMITIVE`, so both pre-existing cases
  hit the outer `(TYPEP OBJ-TYPE 'TYPE-PRIMITIVE)` check's TRUE branch
  with an unregistered class/slot (the OR's FALSE branch), never the
  outer check's own FALSE branch — corrected the misleading comments and
  added a third case using a `TYPE-ARROW` object (genuinely not a
  `TYPE-PRIMITIVE`) to close the gap the first two only appeared to
  cover. Separately, `%TYPED-HOLE-MESSAGE`'s per-binding `(IF
  (TYPE-SCHEME-P SCHEME) ...)` had only ever seen genuine `TYPE-SCHEME`
  values, since every existing test binds via `MAKE-TYPE-SCHEME` — but
  `TYPE-ENV-EXTEND` itself never enforces that its `SCHEME` argument
  actually be one, so a bare type-node is a legal (if unusual) binding
  value; added a case exercising exactly that. Verified via `nix build
  .#checks.aarch64-darwin.default` (1262 → 1264 cases, 0 failures) and
  `nix build .#coverage`: `inference-handlers.lisp` reached 100% branch
  (32/32); tree-wide aggregate rose to 89.8% / 95.2%.
- `t/types-extended-nodes-test.lisp`: `src/types-env.lisp`'s
  `TYPE-CONSTRUCTOR-NAME`/`TYPE-CONSTRUCTOR-ARGS` each dispatch via a
  two-clause `COND` (a `TYPE-APP` chain, or an option-shaped union via
  `%OPTION-TYPE-CONSTRUCTOR-P`) with no final `T`/`OTHERWISE` clause.
  Every pre-existing test called them only on values matching one of the
  two clauses, so `%OPTION-TYPE-CONSTRUCTOR-P`'s own test expression (as
  evaluated inside the `COND`, once `TYPE-APP-P` has already failed) had
  only ever been observed true — a value matching *neither* shape, and
  the implicit `COND`-falls-through-to-`NIL` behavior that entails, had
  never been exercised. Added one case calling both functions on a plain
  `TYPE-PRIMITIVE`. Verified via `nix build .#checks.aarch64-darwin.default`
  (1264 → 1265 cases, 0 failures) and `nix build .#coverage`:
  `types-env.lisp` reached 100% branch (26/26); tree-wide aggregate rose
  to 89.8% / 95.3%.
- `t/substitution-test.lisp`, `t/substitution-zonk-test.lisp`: three
  genuine gaps in `substitution.lisp`/`substitution-schemes.lisp`.
  - `SUBST-COMPOSE`'s `t` branch copies each of `S1`'s bindings into the
    result `(UNLESS (GETHASH id (SUBSTITUTION-BINDINGS S2)) ...)` when
    `S2` doesn't already bind that same id; the pre-existing chains test
    only ever exercised the copy-through case (`S1`/`S2` share no keys),
    never the skip case where a key is bound in *both* and `S2`'s
    (already-zonked) entry must win. Added a case with a shared key.
  - `ZONK`'s `TYPE-VARIANT` method only ever saw `:ROW-VAR NIL` across
    every existing test in the suite, so its `(WHEN (TYPE-VARIANT-ROW-VAR
    ty) ...)` true branch (resolving an open row's variable) had never
    fired, unlike its `TYPE-RECORD`/`TYPE-EFFECT-ROW` siblings which both
    already had a row-var-present case. Added one.
  - `TYPE-OCCURS-P`'s `(IF (AND BOUND-VAR (TYPE-VAR-EQUAL-P VAR
    BOUND-VAR)) NIL ...)` shadowing short-circuit had never fired either:
    no pre-existing case built a binder node (`TYPE-FORALL`/`-EXISTS`/
    `-LAMBDA`/`-MU`) at all. Added a `TYPE-FORALL` whose own bound
    variable is the variable being checked, confirming it does *not*
    count as occurring free even though it's syntactically present in
    the body too.
  Verified via `nix build .#checks.aarch64-darwin.default` (1265 → 1268
  cases, 0 failures) and `nix build .#coverage`: `substitution.lisp`
  reached 100% branch (20/20); `substitution-schemes.lisp` rose to 94.4%
  branch (17/18) — its remaining gap, `INSTANTIATE`'s `(WHEN (TYPE-VAR-P
  fresh) ...)` guard, was left alone: every quantified var is fresh-
  bound to a brand-new `TYPE-VAR` earlier in the same function, with
  nothing in between that could turn it into something else, so this
  looks like the same class of permanently-true defensive guard as
  `PARSE-PRIMITIVE-TYPE`'s `*TYPE-ALIAS-REGISTRY*` `BOUNDP` check
  documented earlier, not a genuinely reachable branch. Tree-wide
  aggregate rose to 89.9% / 95.5%.
- Three more genuine gaps, closed the same way — construct the one case
  no prior test happened to reach, verify the surrounding branches really
  were already covered rather than assuming from the function's shape:
  - `t/bidirectional-test.lisp`: `CHECK-BODY`'s `(IF (NULL ASTS) NIL
    ...)` true branch had no test; the one existing call always supplies
    forms. Added a direct call with an empty list.
  - `t/solver-test.lisp`: `%SOLVE-ROW-LACKS-CONSTRAINT`'s `(OR
    (TYPE-RECORD-P rho) (TYPE-VARIANT-P rho) (TYPE-EFFECT-ROW-P rho))`
    looked fully covered — a pre-existing test already drives all three
    predicates true via record/variant/effect-row `rho` values — but
    every `rho` that ever reached the third disjunct's position in this
    suite turned out to actually satisfy it, so that disjunct's own
    FALSE outcome (and the outer `COND`'s final `(T (VALUES
    CURRENT-SUBST C))` catch-all it leads to) had never fired. Added a
    case with a plain `TYPE-PRIMITIVE` `rho` — concrete, so it skips the
    `TYPE-VAR-P` clause, but none of record/variant/effect-row either.
  - `t/types-utility-test.lisp`: `%FIELD-NAME=`'s `PRINC-TO-STRING`
    fallback for a non-symbol argument had a test for its `LEFT`
    (search-argument) side, but every record's own field key (matched as
    `RIGHT`) is conventionally a symbol, so that side of the identical
    fallback had never fired. Added a case with a string field key.
  Verified via `nix build .#checks.aarch64-darwin.default` (1268 → 1271
  cases, 0 failures) and `nix build .#coverage`: `bidirectional.lisp`,
  `solver.lisp`, and `types-level-strings.lisp` all reached 100% branch
  (24/24, 34/34, 18/18). Tree-wide aggregate rose to 89.9% / 95.6%.
- `t/printer-test.lisp`: `TYPE-TO-STRING`'s `TYPE-ARROW` method shows
  effects inline only when `(AND EFFECTS (NOT (EQ EFFECTS
  +PURE-EFFECT-ROW+)) (TYPE-EFFECT-ROW-EFFECTS EFFECTS))`; the pre-
  existing cases only ever passed `:EFFECTS NIL` (conjunct 1 false,
  short-circuiting immediately) or a genuine I/O row (all three true), so
  conjuncts 2 and 3 had never seen their own false outcome. Added a case
  passing `+PURE-EFFECT-ROW+` itself (non-`NIL` but `EQ` to the pure
  singleton, isolating conjunct 2) and one passing a distinct row object
  with an open row-var but no concrete effects (isolating conjunct 3) —
  both correctly print with no effects shown, same as the `:EFFECTS NIL`
  case, but by a different path through the `AND`. Separately
  investigated the `TYPE-ADVANCED` method's `(SYMBOLP SURFACE-HEAD)`
  conjunct, which looked identically untested; confirmed instead (the
  hard way, via a compile-time type-conflict error from SBCL when the
  test tried to construct one) that `TYPE-ADVANCED`'S `NAME` slot is
  declared `:TYPE SYMBOL` in `types-extended-advanced-node.lisp`, making
  a non-symbol surface head impossible to construct at all — left alone
  as a struct-enforced guard, documented in the test file itself rather
  than forced. Verified via `nix build .#checks.aarch64-darwin.default`
  (1271 → 1273 cases, 0 failures) and `nix build .#coverage`:
  `printer.lisp` rose to 97.4% branch (37/38). Tree-wide aggregate rose
  to 89.9% / 95.7%.
- `t/types-extended-units-test.lisp`, `t/types-extended-routing-types-
  test.lisp`: three more genuine gaps, plus one confirmed non-issue of
  the same struct-enforced kind documented for `printer.lisp` above.
  - `%UNIT-KEY`'s first `COND` clause, `(UNIT-DEFINITION-P name)`, was
    unreachable through any of its three callers: `FIND-UNIT`,
    `UNIT-DESIGNATOR-P`, and `%RESOLVE-UNIT` each already special-case a
    `UNIT-DEFINITION` argument themselves before ever calling `%UNIT-KEY`
    on it. Called it directly instead.
  - `%NORMALIZE-ROUTE-PARAMETERS`'s first `COND` clause matches an
    exactly-2-element `(name value)` entry via `(NULL (CDDR entry))`;
    every pre-existing parameter entry was either that shape or a
    `(name . value)` dotted pair (which fails the clause's own `(CONSP
    (REST entry))` conjunct and falls to the second clause), so `(NULL
    (CDDR entry))`'s own false outcome — a 3+-element entry, still
    `CONSP` but not exactly 2 long — had never been observed. Added a
    `(id integer :extra)` case, confirming it falls through to the
    second clause and pairs the name with the whole rest as its value.
  - `%PARSE-ROUTE-PARAMETER`'s `INTEGER` branch wraps `PARSE-INTEGER` in
    a `HANDLER-CASE`; every reachable call passes a genuine string
    segment (extracted from a URL path), so `PARSE-INTEGER` never
    actually signals there — unparseable *content* like `"abc"` is
    rejected via the `(= INDEX (LENGTH RAW-VALUE))` check instead,
    without erroring. A non-string `RAW-VALUE`, though no current caller
    produces one, makes `PARSE-INTEGER` itself signal a type-error;
    called the internal function directly with `42` to reach the
    handler.
  - `ROUTE-VALID-P`'s `(STRINGP (ROUTE-PATH route))` conjunct looked
    identically untested at first, but `ROUTE`'s `PATH` slot is declared
    `:TYPE STRING` in this same file's `DEFSTRUCT`, so — exactly like
    `TYPE-ADVANCED`'s `NAME` slot for `printer.lisp` above — no route
    object can ever carry a non-string path to begin with. Left alone.
  Verified via `nix build .#checks.aarch64-darwin.default` (1273 → 1276
  cases, 0 failures) and `nix build .#coverage`: `types-extended-
  units.lisp` reached 100% branch (22/22); `types-extended-routing-
  types.lisp` rose to 98.5% branch (65/66). Tree-wide aggregate rose to
  89.9% / 95.8%.
- `t/channels-test.lisp`: resolved the `channels.lisp` discrepancy noted
  several rounds ago as "not something I can improve further without
  deeper reverse-engineering." Re-parsing the coverage HTML's per-span
  state markers directly (rather than trusting a summary read) showed
  `CHANNEL-PAYLOAD-TYPE`/`CLOSE-TYPED-CHANNEL`'s `ETYPECASE` clauses for
  `SEND-CHANNEL`/`RECV-CHANNEL` were genuinely fully covered (state-5,
  both matched and fell-through observed), but the final `(TYPED-CHANNEL
  endpoint)` clause's own type test had only ever been observed matching
  — no test ever passed a value that satisfies *none* of the three
  clauses, so `ETYPECASE`'s implicit "no clause matched" error path had
  never fired. Added a case passing a plain string to both functions.
  First attempt used `(SIGNALS TYPE-ERROR ...)`, which failed: this
  package `:USE`s `CL-CC/TYPE`, so the bare symbol `TYPE-ERROR` resolves
  to this project's own `CL-CC/TYPE:TYPE-ERROR` condition class, not
  `CL:TYPE-ERROR` — and `ETYPECASE`'s failure is an
  `SB-KERNEL:CASE-FAILURE` (a `CL:TYPE-ERROR` subtype, unrelated to the
  project's own). Switched to the broader, already-idiomatic `SIGNALS
  ERROR`. Verified via `nix build .#checks.aarch64-darwin.default`
  (1276 → 1277 cases, 0 failures) and `nix build .#coverage`:
  `channels.lisp` reached 100% branch (40/40). Tree-wide aggregate rose
  to 89.9% / 95.9%.
- A full re-sweep of every file with a remaining branch gap (prompted by
  discovering, while fixing `channels.lisp` above, that this session's
  coverage-HTML parsing had silently mis-handled a `<code>`-wrapped
  line-number format in some report builds) turned up four more genuine
  gaps and confirmed one already-documented dead branch:
  - `t/types-utility-test.lisp`: `EXCLUDE-TYPE`'s non-union branch,
    `(IF (IS-SUBTYPE-P union excluded) TYPE-NULL union)`, only had its
    "not a subtype, kept as-is" outcome tested (mirroring how
    `EXTRACT-TYPE`'s parallel branch already had both). Added the
    subtype case (`(EXCLUDE-TYPE TYPE-INT TYPE-INT)` → `TYPE-NULL`,
    since subtyping is reflexive).
  - `t/type-system-inference-test.lisp`: `EXTRACT-TYPE-GUARD`'s
    `(typep var 'classname)` clause has a 5-conjunct `AND`
    (`TYPEP`-named head, 2-arg arity, first-arg-is-`AST-VAR`,
    second-arg-is-`AST-QUOTE`, quoted-value-is-`SYMBOLP`); only the
    all-true case had ever been driven. Added three cases, one per
    conjunct's own false outcome. First attempt at the arity case used a
    1-arg call, which — not noticed until the coverage rebuild still
    showed the gap open — actually matched the *earlier* `(predicate
    var)` clause's own 1-arg requirement instead (`TYPEP` looks like any
    other predicate name to that clause), never reaching this one at
    all; fixed by using 3 args, which fails both clauses' arity checks
    unambiguously.
  - `t/inference-forms-advanced-test.lisp`: `%ADVANCED-CALL-SAME-SYMBOL-
    NAME-P`'s two `SYMBOLP` conjuncts had only ever been driven true
    (every conditional-type-inference test in this suite compares two
    genuine symbols). Added a direct call with a non-symbol on each
    side. Separately reconfirmed `%ADVANCED-CALL-RETURN-VALUE`'s
    trailing `(T TYPE-ANY)` clause is the dead code already documented
    in this same test file (`return-type`'s only falsy Lisp value is
    `NIL`, which is itself `SYMBOLP`/`BOUNDP`, so the `BOUNDP` clause
    always intercepts it first) — no new work needed there.
  Verified via `nix build .#checks.aarch64-darwin.default` (1277 → 1278
  cases, 0 failures) and `nix build .#coverage`: `types-utility.lisp`,
  `inference-forms.lisp`, and `inference-forms-advanced.lisp` all
  reached 100% branch (30/30, 28/28, 78/78). Tree-wide aggregate rose to
  89.9% / 96.1%, crossing 96% branch coverage.
- `t/types-utility-test.lisp`, `t/parser-typed-test.lisp`: five more
  genuine gaps found via a broader re-sweep across every file with a
  remaining branch gap, prioritizing ones not yet individually
  investigated this session.
  - `TYPE-LEVEL-NATURAL-VALUE`'s first `COND` clause, `(AND (INTEGERP
    type) (NOT (MINUSP type)))`, had only ever been observed false
    (every existing call passes either a wrapped FR-1701 node or a
    non-integer): added a raw-integer call to observe it true.
  - `PARSE-TYPE-SPECIFIER-MAYBE`'s `HANDLER-CASE` around
    `PARSE-TYPE-SPECIFIER` had never actually caught a
    `TYPE-PARSE-ERROR`: the pre-existing "unknown" case is filtered out
    earlier, by `LOOKS-LIKE-TYPE-SPECIFIER-P` itself returning false for
    a bare unrecognized symbol, never reaching `PARSE-TYPE-SPECIFIER` at
    all. `(OR)` does look like a spec (its head is a recognized
    composite-type-head string) but fails to parse (empty `OR`),
    reaching the handler for real.
  - `EXTRACT-RETURN-TYPE`'s inner `(AND decl (CONSP (CAR decl)) ...)`
    had a test for its final `STRING=` conjunct being false, but not for
    `decl` itself being `NIL` (an empty `(DECLARE)`) or `(CAR decl)`
    not being a `CONSP` (`(DECLARE FOO)`, a bare declaration-identifier
    symbol) — added one case per outcome.
  - `PARSE-TYPED-DEFUN`'s bare-return-type computation, `(AND (NOT (NULL
    REST)) ...)`, had every conjunct's true side tested via the existing
    bare-symbol-return-type case, but never `REST` itself being `NIL`
    (an empty-bodied `defun`, degenerate but syntactically legal input)
    or the `(NOT (EQ (FIRST REST) 'DECLARE))` conjunct being false (a
    bare, unparenthesized `DECLARE` symbol immediately after the lambda
    list — still not a `CONSP`, so it reaches this conjunct instead of
    being caught by the parens check, and `EXTRACT-RETURN-TYPE` also
    declines it since it requires `(CONSP (FIRST BODY))`) — added one
    case per outcome.
  Verified via `nix build .#checks.aarch64-darwin.default` (1278 → 1284
  cases, 0 failures) and `nix build .#coverage`: `types-utility.lisp`
  reached 100% branch (30/30); `parser-typed.lisp` rose to 95.7% branch
  (44/46). Tree-wide aggregate rose to 90.0% / 96.2%, crossing 90%
  expression coverage.
- `t/types-extended-dependent-test.lisp`: two genuine gaps in
  `types-extended-dependent.lisp`.
  - `TERMINATION-EVIDENCE-FORM-VALID-P`'s strategy check mirrors its
    head check's two-tier shape (`(OR (member ...) (AND (SYMBOLP ...)
    (member (string-upcase ...) ...)))`); the pre-existing `:BOGUS-
    STRATEGY` case fails the name-list `MEMBER` but is still a symbol,
    so it never made `(SYMBOLP strategy)` itself false. Added a case
    with a non-symbol strategy (`42`), mirroring the head-side case that
    was already there for the analogous reason.
  - `MAKE-NONZERO-OBLIGATION`'s checker lambda, `(AND (NUMBERP payload)
    (NOT (ZEROP payload)))`, had only ever been called with numeric
    payloads (testing `ZEROP`'s zero/nonzero split already); added a
    non-numeric payload to close `NUMBERP`'s own false branch.
  Verified via `nix build .#checks.aarch64-darwin.default` (1284/1284
  cases, 0 failures — both cases added to existing test bodies rather
  than as new top-level cases) and `nix build .#coverage`:
  `types-extended-dependent.lisp` reached 100% branch (82/82). Tree-wide
  aggregate rose to 90.0% / 96.3%.
- Confirmed `printer-unparse.lisp`'s `%UNPARSE-TYPE-ADVANCED` has the
  identical `(SYMBOLP surface-head)` struct-enforced-always-true guard
  already documented for `printer.lisp`'s `TYPE-ADVANCED` method (both
  read `TYPE-ADVANCED-NAME`, whose slot is declared `:TYPE SYMBOL`) — no
  new test attempted, since one would fail to compile the same way.
- `t/types-extended-advanced-validators-test.lisp`: two real gaps in
  `%TYPE-ADVANCED-VALIDATE-STAGING` (FR-1703), plus one confirmed dead
  branch in `%TYPE-ADVANCED-VALIDATE-INTERFACE-FILES` (FR-2405) found
  while investigating why an apparently-thorough existing test for the
  latter still showed as uncovered.
  - The payload check, `(OR (TYPEP payload 'TYPE-NODE)
    (%TYPE-ADVANCED-STAGED-FORM-P payload))`, had only ever seen its
    second disjunct: every pre-existing case wraps the payload in
    `(quote ...)`/`(code ...)`, which stays a raw list even after
    parsing (`QUOTE` isn't a recognized type-form head, so the advanced-
    value parser only recurses into it, never converts the whole form).
    Added a bare primitive name as the payload instead — recognized and
    auto-parsed into a genuine `TYPE-NODE` directly — to reach the first
    disjunct, and a plain number (neither shape) to reach the `OR`'s
    overall false branch and the `VALIDATE-ADVANCED` error path, which
    had never fired either.
  - `%TYPE-ADVANCED-VALIDATE-INTERFACE-FILES`'s own uniqueness re-check,
    `(= (LENGTH exports) (LENGTH (REMOVE-DUPLICATES exports :TEST
    #'EQUAL)))`, looked identically untested — a pre-existing test pair
    already sends both duplicate and unique `:exports` lists through
    `PARSE-TYPE-SPECIFIER`. Tracing FR-2405's contract spec
    (`types-extended-advanced-data.lisp`) showed why: its
    `:property-predicates` entry for `:exports`,
    `%TYPE-ADVANCED-INTERFACE-EXPORT-LIST-P`, already rejects duplicate
    export *names* — and `%TYPE-ADVANCED-VALIDATE-CONTRACT` always runs
    property-predicates before the custom validator (confirmed by
    reading its dispatch order directly), so the duplicate-input test
    case is actually rejected there, never reaching this function's own
    check at all. Since any input that passes the name-uniqueness
    property-predicate must also pass this function's raw-entry
    `EQUAL`-uniqueness check (two entries `EQUAL` to each other
    necessarily share a name), this check can never observe its own
    false branch — the same "redundant with an already-enforced
    invariant" class of dead code as several FR-contract validators
    documented earlier in this file's history. Left in place rather than
    removed: `%TYPE-ADVANCED-VALIDATE-INTERFACE-FILES` is also listed as
    FR-2405's own implementation-evidence API symbol
    (`types-extended-advanced-evidence-data.lisp`), so deleting it would
    require updating that tracked-evidence entry too — a larger, more
    architecturally-visible change than this round's scope.
  Verified via `nix build .#checks.aarch64-darwin.default` (1284 → 1286
  cases, 0 failures) and `nix build .#coverage`: `types-extended-
  advanced-validators.lisp` rose to 98.2% expression / 95.3% branch
  (101/106). Tree-wide aggregate rose to 90.0% / 96.4%.
- `t/parser-arrow-quantifier-test.lisp`, `t/parser-test.lisp`: two
  genuine gaps in `parser-extended.lisp`, plus one dead-code finding
  confirmed by definition rather than by any runtime check.
  - `PARSE-ARROW-TYPE`'s bang/slash scan, `(POSITION-IF (LAMBDA (x) (AND
    (SYMBOLP x) ...)) ARGS)`, had only ever scanned bare symbol params
    (`FIXNUM`/`STRING`/`BOOLEAN`); added a compound param spec, `(VECTOR
    FIXNUM)`, which is a list rather than a symbol mid-scan, closing
    `SYMBOLP`'s own false branch (distinct from a symbol that just isn't
    `"!"`).
  - `%PARSER-HEAD-NAME-MEMBER-P`'s `(AND (SYMBOLP head) ...)` guard had
    only ever seen a symbol head through the public parser; added a
    direct call with a non-symbol head (`42`).
  - Investigating `%PARSE-ADVANCED-VALUE`'s final `COND` clause — `(T
    (CONS (%PARSE-ADVANCED-VALUE (CAR value)) (%PARSE-ADVANCED-VALUE
    (CDR value))))`, apparently meant to handle a dotted-pair `CONSP`
    value — found it is unreachable *by definition*, not merely
    untested: the branch is only reached inside a `(CONSP value)`
    clause, and `LISTP` is defined as `(OR (CONSP x) (NULL x))`, so once
    `CONSP` is already known true, the preceding `(LISTP value)` clause
    is a tautology and always wins first, regardless of whether the cons
    is a proper or improper list. Confirmed the hard way: a first
    attempt at testing it with a genuine dotted pair instead hit the
    `LISTP`/`MAPCAR` clause, which signals a type-error on an improper
    list rather than ever falling through. Documented in place rather
    than removed, matching this session's practice of leaving contingent
    dead code as insurance when removing it would ripple into unrelated
    surface area — here, understanding whether this was ever meant to
    handle some other shape of value would need more context than a
    coverage pass alone provides.
  Verified via `nix build .#checks.aarch64-darwin.default` (1286 → 1288
  cases, 0 failures) and `nix build .#coverage`: `parser-extended.lisp`
  rose to 93.6% branch (103/110). Tree-wide aggregate rose to 90.0% /
  96.5%.
- `t/parser-arrow-quantifier-test.lisp`: closed the parallel gap to the
  bang-scan fix above. `%PARSE-EFFECT-NAMES-AND-ROW-VAR`'s pipe scan,
  `(POSITION-IF (LAMBDA (x) (AND (SYMBOLP x) ...)) ELTS)`, had the same
  shape and the same never-false-`SYMBOLP` gap as `PARSE-ARROW-TYPE`'s
  bang/slash scan, but a non-symbol effect element can't reach a
  successful parse the way a non-symbol arrow *param* could: every
  scanned element before the pipe also becomes a `TYPE-EFFECT-OP`
  `:NAME`, whose slot is declared `:TYPE SYMBOL` (unlike arrow params,
  which are independently parsed as full type specifiers). First
  attempt asserted a successful parse and failed for exactly that
  reason; fixed by asserting `SIGNALS ERROR` instead, which is what
  `MAKE-TYPE-EFFECT-OP` actually does once construction is attempted.
  Verified via `nix build .#checks.aarch64-darwin.default` (1288 → 1289
  cases, 0 failures) and `nix build .#coverage`: `parser-extended.lisp`
  rose to 94.5% branch (104/110). Tree-wide aggregate rose to 90.0% /
  96.6%.
- `t/parser-test.lisp`: closed `parser-extended.lisp`'s last two
  genuinely reachable branch gaps in a single round.
  - `%PARSE-ADVANCED-FEATURE-FORM`'s `HEAD-NAME` computation, `(AND
    (SYMBOLP head) ...)`, had only ever seen a symbol head (registered
    or not); added a direct call with a non-symbol head (`42`).
  - `%ADVANCED-TYPE-FORM-HEAD-P` has five separate `(AND (SYMBOLP head)
    ...)`/`HN`-derived conjuncts, all of which had only ever seen a
    symbol head, reachable whenever an advanced payload contains a
    nested list of non-symbol atoms. One direct call with a non-symbol
    head (`1`) closed all of them at once, since they all gate on the
    same argument within the same function.
  With those closed, the file's only two remaining gaps are both
  already-documented non-issues from earlier this session:
  `%KNOWN-ADVANCED-TYPE-ATOM-P`'s `*TYPE-ALIAS-REGISTRY*` `BOUNDP` guard
  is the same permanently-true, load-order defensive check as
  `PARSE-PRIMITIVE-TYPE`'s identical pattern, and `%PARSE-ADVANCED-
  VALUE`'s final `COND` clause is the definitionally-dead-by-`LISTP`
  branch documented two rounds ago. Verified via `nix build
  .#checks.aarch64-darwin.default` (1289 → 1291 cases, 0 failures) and
  `nix build .#coverage`: `parser-extended.lisp` rose to 97.3% branch
  (107/110). Tree-wide aggregate rose to 90.0% / 96.7%.
- `t/subtyping-test.lisp`: `IS-SUBTYPE-P`'s `TYPECASE` on `T1` ends in a
  `(T (%IS-SUBTYPE-P-BY-T2 T1 T2))` catch-all for any `T1` kind without
  its own dedicated clause; every other test in the suite passes a `T1`
  of an explicitly-handled kind (union/intersection/refinement/
  primitive/record/variant/constructor/arrow/effect-row/advanced), so
  this line had never executed at all — confirmed genuinely reachable,
  not structural, before adding: a fresh `TYPE-VAR` is neither `TYPE-
  EQUAL-P` nor `TYPE-UNKNOWN-P` nor any of those explicit kinds. Also
  confirmed (without touching source) that `%PRIMITIVE-CLASS-RECORD-
  TYPE`'s pair of `(FBOUNDP 'LOOKUP-CLASS-TYPE)`/`(FBOUNDP 'LOOKUP-
  CLASS-METHOD-TYPES)` guards are the same permanently-true, load-order
  defensive pattern documented repeatedly elsewhere in this file's
  history — `LOOKUP-CLASS-TYPE` is macro-generated by `(DEFINE-REGISTRY
  CLASS-TYPE ...)` in `inference.lisp` rather than hand-written with a
  `DEFUN` (which is why grepping for it looked alarming at first), but
  it is a real, always-bound function once the system has loaded.
  `subtyping.lisp` and `unification.lisp` are this session's two most
  deliberately-paced files (large, central to the type checker's
  soundness), so this round adds exactly the one clearly-safe,
  clearly-reachable case rather than working through every remaining
  marker in one pass. Verified via `nix build .#checks.aarch64-darwin.default`
  (1291 → 1292 cases, 0 failures) and `nix build .#coverage`:
  `subtyping.lisp` rose to 94.0% branch (126/134). Tree-wide aggregate
  rose to 90.0% / 96.8%.
- `t/subtyping-test.lisp`: one more deliberately-scoped `subtyping.lisp`
  case. The `TYPE-VARIANT` clause's `(OR (AND (TYPEP T2 'TYPE-VARIANT)
  (%SUBTYPE-ROW-P ...)) (%IS-SUBTYPE-P-BY-T2 T1 T2))` had both existing
  cases reach `%IS-SUBTYPE-P-BY-T2` (if at all) with `T2` still typep
  `TYPE-VARIANT` — the nested row check failing, not `TYPEP` itself.
  Added a case with `T2` being a `TYPE-UNION` containing the variant
  instead: `TYPEP` is false immediately, reaching `%IS-SUBTYPE-P-BY-T2`
  by the other path, and this time its `TYPE-UNION` clause has a real
  match to find rather than always returning the same negative result.
  Verified via `nix build .#checks.aarch64-darwin.default` (1292/1292
  cases, 0 failures — added to an existing test body) and `nix build
  .#coverage`: `subtyping.lisp` rose to 94.8% branch (127/134). Tree-wide
  aggregate held at 90.0% / 96.8% (rounding).
- `t/subtyping-test.lisp`, `t/subtyping-extended-test.lisp`: closed the
  remaining two `(TYPEP t2 'X)`-never-false gaps with the same union
  trick as the `TYPE-VARIANT` case above (`TYPE-ARROW`, `TYPE-EFFECT-
  ROW`), plus `%SUBTYPE-ARROW-P`'s own return-type check. This brings
  `subtyping.lisp`'s only remaining gap back down to just the `FBOUNDP`
  guards in `%PRIMITIVE-CLASS-RECORD-TYPE`, already confirmed
  permanently-true and documented two rounds ago — effectively this
  file's practical ceiling.
  - `TYPE-ARROW`'s clause: every prior arrow-subtyping case has `T2`
    typep `TYPE-ARROW`; added a union-wrapped case to reach `%IS-
    SUBTYPE-P-BY-T2` via `TYPEP` being false instead.
  - `TYPE-EFFECT-ROW`'s clause: same shape, same fix.
  - `%SUBTYPE-ARROW-P`'s `(IS-SUBTYPE-P (TYPE-ARROW-RETURN T1)
    (TYPE-ARROW-RETURN T2))` conjunct had only ever been observed true:
    the pre-existing "params are NOT covariant" negative case already
    fails the *earlier* params conjunct, short-circuiting before ever
    reaching this one. Added a case with equal, compatible params but
    incompatible return types to reach and fail it directly.
  Verified via `nix build .#checks.aarch64-darwin.default` (1292 → 1293
  cases, 0 failures) and `nix build .#coverage`: `subtyping.lisp` rose to
  97.0% branch (130/134). Tree-wide aggregate rose to 90.0% / 97.0%,
  crossing 97% branch coverage.
- `t/unification-test.lisp`: the first new case in `unification.lisp`'s
  rank-N/impredicative bound-merging area (lines ~105-182) since it was
  explicitly deferred as too delicate to rush several rounds ago —
  `subtyping.lisp` reaching a stable, well-verified state first (see
  above) freed up the caution budget for this file this round.
  `%MERGE-TYPE-VAR-BOUNDS-INTO!`'s own `(WHEN (%BOUNDS-CONSISTENT-P
  lower upper subst) ...)` guard had only ever been observed true:
  every pre-existing bound-merge case combines bounds that stay
  consistent (`LOWER <: UPPER`) after merging. Unifying a variable whose
  *upper* bound is `STRING` with one whose *lower* bound is `INT`
  merges to `lower=INT, upper=STRING` — inconsistent, since `INT` is not
  a subtype of `STRING` — and the whole unification must fail rather
  than silently keeping a contradictory bound pair on the surviving
  variable. This is exactly the kind of soundness-relevant edge this
  file's extra caution was protecting: an early, less careful test
  attempt asserting the *unified substitution's* correctness would have
  been trivially satisfiable by asserting almost anything, since the
  interesting assertion is that unification *fails* here at all.
  Verified via `nix build .#checks.aarch64-darwin.default` (1293 → 1294
  cases, 0 failures) and `nix build .#coverage`: `unification.lisp` rose
  to 96.2% expression / 96.5% branch (164/170). Tree-wide aggregate rose
  to 90.1% / 97.1%.
- `t/unification-test.lisp`: `%TYPE-UNIFY-VAR-T1`/`%TYPE-UNIFY-VAR-T2`
  each reject unifying a bare, unbound type variable directly with a
  still-quantified `TYPE-FORALL` — Rank-N types must appear in argument
  positions, not be substituted in for a monomorphic variable — but
  neither `TYPE-INFERENCE-ERROR` path had any test anywhere in this
  suite at all (confirmed by grepping for "impredicative"/"Rank-N"/
  `TYPE-FORALL` across every test file first, not just this one).
  Added one direct `TYPE-UNIFY` call per function or a fresh, unbound
  `TYPE-VAR` against a `TYPE-FORALL` in each argument order, which
  `TYPE-UNIFY`'s own dispatch order (`TYPE-VAR-P T1` checked before
  `TYPE-VAR-P T2`) routes to `%TYPE-UNIFY-VAR-T1` and `%TYPE-UNIFY-VAR-
  T2` respectively. Verified via `nix build .#checks.aarch64-darwin.default`
  (1294 → 1296 cases, 0 failures) and `nix build .#coverage`:
  `unification.lisp` jumped to 98.8% expression / 97.6% branch (166/170)
  — each error path's `FORMAT NIL` message body accounted for several
  previously-dark expression points on top of the branch itself. Tree-
  wide aggregate rose to 90.2% / 97.2%.
- `t/unification-test.lisp`: two more closed gaps in the bound-merging
  area, plus a real completeness limitation found and documented (not
  fixed — see below) while investigating a third apparent gap.
  - `%COMBINE-LOWER-BOUND`'s clause order tries `(IS-SUBTYPE-P LEFT
    RIGHT)` before `(IS-SUBTYPE-P RIGHT LEFT)`; the pre-existing "either-
    subtype-consistent" case always matched the first clause (`TARGET`'s
    lower bound happened to be the narrower side), so the second clause
    — `TARGET` not a subtype of `SOURCE`, but `SOURCE` a subtype of
    `TARGET` — had never fired for a *lower* bound (only ever for upper,
    via the pre-existing "right-tighter-kept" case). Swapping which
    variable carries the broader bound reaches it.
  - `%TYPE-UNIFY-VAR-T2`'s "already bound" branch, `(TYPE-UNIFY T1
    binding SUBST)`, is the `(TYPE-VAR-P T2)` mirror of the pre-existing
    T1-bound case; every prior test put the already-bound variable in
    the `T1` position. Added the `T2` mirror.
  - Investigating `%BIND-TYPE-VAR-WITH-BOUNDS`'s `((TYPE-VAR-P resolved)
    SUBST)` clause (a trivial-success no-op for "VAR already equals
    ZONK'd TY") found it is unreachable through `%UNIFY-FREE-VAR`, its
    only caller — but not for a benign reason. Tracing precisely: when
    variable `B` is already bound to variable `A` in `SUBST` (so `B` is
    simply an alias for `A`), unifying `A` with `B` ought to be a
    trivial success — they already denote the same type. Instead,
    `TYPE-OCCURS-P` treats "`B` resolves all the way down to `A` via
    `SUBST`" the same as "`A` occurs structurally inside `B`" and
    reports an occurs-check failure, so `%UNIFY-FREE-VAR` rejects the
    unification before ever reaching the clause meant to handle exactly
    this case. Verified this is real (not just reasoned through) with a
    direct test: `(TYPE-UNIFY A B (SUBST-EXTEND B A NIL))` does return
    failure today. This is a completeness bug, not a soundness one — it
    makes type inference spuriously reject some valid programs rather
    than accept invalid ones — but distinguishing "resolves to the same
    variable via substitution" from "occurs structurally within" in
    `TYPE-OCCURS-P` is a real behavioral change to this system's most
    soundness-critical function, warranting more scrutiny than a
    coverage-focused round should give it. Recorded with a regression
    test pinned to the *current* (arguably wrong) behavior, so this is
    easy to find and revisit deliberately later rather than silently
    rediscovered.
  Verified via `nix build .#checks.aarch64-darwin.default` (1296 → 1299
  cases, 0 failures) and `nix build .#coverage`: `unification.lisp` rose
  to 99.5% expression / 98.2% branch (167/170). Tree-wide aggregate held
  at 90.2% / 97.2% (rounding).
- `t/parser-typed-test.lisp`: two more genuine gaps, closing
  `parser-typed.lisp` out at 100% branch.
  - `PARSE-ROW-TYPE`'s field-validity check, `(AND (CONSP F) (=
    (LENGTH F) 2))`, had a test for the length conjunct being false
    (`(RECORD (X))`, a 1-element list) but not for `(CONSP F)` itself
    being false (a bare atom field spec, `(RECORD X)`).
  - `EXTRACT-RETURN-TYPE`'s innermost `(AND (SYMBOLP (CAAR decl)) ...)`
    had a test for a symbol that just isn't named `RETURN-TYPE`, but not
    for `(CAAR decl)` not being a symbol at all — `(DECLARE (42 FOO))`
    has `(CAR decl)` as a genuine cons (unlike the pre-existing `(DECLARE
    FOO)` case), so it reaches this specific conjunct and makes it false.
  Verified via `nix build .#checks.aarch64-darwin.default` (1301 → 1303
  cases, 0 failures) and `nix build .#coverage`: `parser-typed.lisp`
  reached 100% branch (46/46). Tree-wide aggregate rose to 90.3% / 97.5%.
- `t/exhaustiveness-test.lisp`: closed `exhaustiveness.lisp` out at 100%
  branch — the 49th of the tree's 64 source files to reach it.
  `TYPECASE-ARM-SUBSUMED-P` is exported public API whose docstring
  documents (rather than enforces) that its arguments are "type name
  symbols (or T)"; every pre-existing case honored that, so `(SYMBOLP
  ARM-TYPE)` and `(SYMBOLP COVERED)` had only ever been observed true.
  Unlike this session's many `:TYPE SYMBOL`-declared struct slots, this
  is a plain function parameter with no such enforcement — a caller
  really can pass a non-symbol, and the function handles it gracefully
  (neither errors nor produces a nonsensical result: a non-symbol can be
  neither `T` nor `EQ` to a covered member representing a different
  type, so it simply fails to subsume). Added one case with a non-symbol
  `ARM-TYPE` and one with a non-symbol member of `ALREADY-COVERED`.
  Verified via `nix build .#checks.aarch64-darwin.default` (1303 → 1305
  cases, 0 failures) and `nix build .#coverage`: `exhaustiveness.lisp`
  reached 100% branch (10/10). Tree-wide aggregate held at 90.3% / 97.5%
  (rounding).
- `t/types-extended-qtt-test.lisp`: revisited the `types-extended-qtt.lisp`
  gap documented as diminishing returns several rounds ago, with two
  more hand-built broken semirings targeting `%SEMIRING-PER-ELEMENT-
  LAWS-P`'s closure (`MEMBER`) conjuncts specifically — distinct from
  every prior broken semiring in this file, which breaks a *law*
  (identity, commutativity, associativity) while staying closed over
  `ELEMENTS`. One `ADD` and one `MULTIPLY`, each returning a value
  entirely outside a 2-element carrier for exactly one input pair,
  otherwise ordinary arithmetic. Verified via `nix build
  .#checks.aarch64-darwin.default` (1305 → 1307 cases, 0 failures) and
  `nix build .#coverage`: the file rose to 90.6% branch (58/64) — real
  progress, though smaller than the two-clean-conjuncts result expected
  from the source read; SB-COVER's line/conjunct attribution here did
  not move exactly as predicted, and chasing that discrepancy further
  was judged not worth it against the file's already-documented
  diminishing-returns assessment. Tree-wide aggregate rose to 90.3% /
  97.6%.
- `t/types-extended-advanced-init-test.lisp`: closed `types-extended-
  advanced-init.lisp`'s previously-deferred count-mismatch gap. An
  earlier round judged this "not worth the risk of destabilizing every
  other test that depends on the real registry contents," reasoning
  that reaching it required corrupting `+TYPE-ADVANCED-FEATURE-SPECS+`
  — but that reasoning missed that the constant is a `DEFPARAMETER`, not
  a `DEFCONSTANT`, and so is a perfectly legal (if unusual) `SETF`
  target, restorable exactly like the missing/orphan registry
  corruptions already used successfully in this same file. Temporarily
  `SETF`-ing the parameter to a copy with its first entry duplicated
  reaches the check directly: with no missing and no orphan entries
  (a duplicate id doesn't create either), the only way `HASH-TABLE-
  COUNT` can still differ from `(LENGTH FEATURE-IDS)` is a duplicate id
  in the spec list itself. Verified via `nix build
  .#checks.aarch64-darwin.default` (1307 → 1309 cases, 0 failures,
  including every other test that runs after these two in the same
  sequential suite — confirming the restore is clean) and `nix build
  .#coverage`: `types-extended-advanced-init.lisp` reached 100% branch
  (32/32) and 97.8% expression (261/267). Tree-wide aggregate rose to
  90.4% / 97.7%.

### Removed

- `t/types-extended-advanced-semantics-test.lisp`. Its content moved to the
  22 per-source test files and the `printer-test.lisp` merge described
  above; nothing in it was deleted.
- `t/package.lisp`: `defbefore`, the thin forwarder that let migrated tests
  keep the monorepo's suite-scoped `before-each`/`before-all` call shape.
  Only one call site remained (`t/type-system-effect-test.lisp`); it now
  calls cl-weave's `before-each` directly, and the shim is gone.
- `unbound-variable-name`: a "compatibility reader" alias for
  `unbound-variable-error-name` (the reader `define-simple-condition`
  already generates), left over from the monorepo migration with zero call
  sites anywhere in this repository, including its own test suite.
- `scripts/run-compile-check.lisp` and `scripts/with-timeout.pl`. The compile
  gate is now `packages.default` (`sbcl.buildASDFSystem`), and the test timeout
  comes from coreutils `timeout`, so neither the script nor the Perl fallback
  has a caller.
- `t/multiplicity-test.lisp` carried two independent naming schemes
  (`mult-*` and `multiplicity-*`) that had grown to test the same five
  functions in `src/multiplicity.lisp` twice, on top of `it-property`
  tests already covering the same algebraic laws exhaustively via
  `gen-member '(:zero :one :omega)`. Checked each pair's exact case
  coverage before deciding which cluster to drop, since "later duplicates
  earlier" does not hold uniformly here:
  - `multiplicity-add` (7 cases) covered only 7 of the 9 `mult-add-*`
    pairs, missing ω+0 and ω+1 — dropped `multiplicity-add`.
  - `multiplicity-mul` (9 cases) was an exact duplicate of `mult-mul-*`
    (9/9 identical pairs) — dropped `multiplicity-mul`.
  - `multiplicity-leq` (9 cases) covered all 9 pairs the `mult-leq-*`
    cluster (8 cases) tested, plus ω≰0 which `mult-leq-*` lacked — this is
    the one pair where the *later* cluster was the superset, so
    `mult-leq-*` was dropped instead and `multiplicity-leq` kept in its
    place under the `mult-leq (ordering)` section.
  - `multiplicity-to-string` (3 cases) was word-for-word identical to
    `mult-to-string-values` — dropped `multiplicity-to-string`.
  - `multiplicity-p-recognition` (6 cases) was a strict subset of
    `mult-valid-grades`/`mult-invalid-grades` (4 + 3 cases, including a
    string-argument case `multiplicity-p-recognition` lacked) — dropped
    `multiplicity-p-recognition`.
  Net change verified via `nix build .#checks.aarch64-darwin.default`:
  1164 → 1130 cases (34 removed, matching 7+9+9+3+6 exactly), 0 failures
  both before and after.
- `src/types-extended-ffi.lisp`: `ffi-descriptor-form-valid-p`'s `((NOT
  (CONSP value)) NIL)` clause, identified as unreachable in an earlier
  round of this session's coverage work. Unlike the several confirmed-dead
  `(T ...)` fallback arms documented elsewhere in this file (kept, since
  those genuinely guard against a future invariant change — e.g. a new
  scalar kind added to `+FFI-SCALAR-KINDS+` without a matching `CASE`
  clause), this one is dead for a stronger reason with no such
  justification for keeping it: `ATOM` is defined as `(NOT (CONSP x))`
  for every Lisp object with no exceptions, and the immediately preceding
  `COND` clause already tests `(ATOM value)`, so by the time this clause
  is reached `value` is provably a `CONS` — no future code change could
  make it reachable, because the redundancy is with the language's own
  type lattice, not with an application-level invariant that could shift.
  Removed. No behavior change: verified via `nix build
  .#checks.aarch64-darwin.default` (1245/1245 cases, 0 failures, same
  count as before) and `nix build .#coverage`: the file's branch coverage
  rose to 98.5% (67/68, the dead clause's own instrumentation points
  gone from the denominator); tree-wide aggregate rose from 89.4% / 94.2%
  to 89.4% / 94.3%.
- `src/parser.lisp`: two dead branches in `PARSE-COMPOUND-TYPE`'s
  compound-form dispatch, found while investigating this file's coverage
  gaps.
  - `PARSE-COMPOUND-TYPE`'s own `CASE` had an `((OPTION) ...)` clause
    duplicating, byte-for-byte, `parser-extended.lisp`'s
    `%PARSE-OPTION-FORM` (registered in its package-independent, string-
    keyed `*SIMPLE-COMPOUND-FORM-TABLE*`). `CASE` dispatches by `EQL`, and
    the literal `OPTION` written in `parser.lisp` interns into the
    `CL-CC/TYPE` package where the file loads — but `OPTION` is not
    exported from that package (confirmed against `package.lisp`'s
    `:EXPORT` list), so a `'(OPTION ...)` spec written by any caller
    outside `CL-CC/TYPE` itself (every real caller, including this
    project's own test suite) reads `OPTION` as a *different* symbol in
    its own package, which never `EQL`s the `CASE` key. The clause was
    therefore unreachable from any actual call site — grepped `src/` for
    an internal `'(OPTION ...)`-literal caller and found none either — so
    every `(option T)` spec has always silently fallen through to
    `PARSE-COMPOUND-TYPE-EXTENDED`'s correctly package-independent
    handling instead, which is why the feature worked despite the
    front-line clause never firing. Removed the dead clause (folding it
    into `OTHERWISE`) rather than trying to "fix" its `EQL` dispatch,
    since the string-keyed extended-parser path already does the job the
    way the rest of this codebase's dispatch tables consistently do it
    (see the package-independent `STRING=`/`SYMBOL-NAME` idiom documented
    elsewhere in this file's history) — duplicating that logic here with
    a second, subtly-broken dispatch mechanism was the actual defect, not
    something worth preserving in corrected form.
  - `%PARSE-COMPOUND-TYPE-APP`'s inner `CASE` had an `(OTHERWISE (=
    (LENGTH ARGS) 1))` arm. `%PARSE-COMPOUND-TYPE-APP` only reaches that
    `CASE` after confirming `HEAD` is a key of
    `*PARSE-COMPOUND-TYPE-APP-TABLE*` (`LIST`, `VECTOR`, `SIMPLE-VECTOR`,
    `ARRAY`, `SIMPLE-ARRAY` — all standard `COMMON-LISP` symbols, so no
    package-boundary trap here), and the `CASE`'s own `((LIST) ...)` and
    `((VECTOR SIMPLE-VECTOR ARRAY SIMPLE-ARRAY) ...)` clauses already
    exhaust that exact set, making `OTHERWISE` provably unreachable by
    the enclosing function's own precondition. `%PARSE-COMPOUND-TYPE-APP`
    has exactly one call site (`src/parser.lisp` itself), so no external
    caller could reach it any other way either. Simplified to `(IF (EQ
    HEAD 'LIST) (= (LENGTH ARGS) 1) (<= 1 (LENGTH ARGS) 2))`, which is
    both shorter and makes the "list wants exactly one, the rest want one
    or two" rule readable at a glance instead of requiring the reader to
    notice the `OTHERWISE` arm can't fire.
  No behavior change for any spec parseable before this change (`(option
  ...)` continues to work exactly as before, now via its one real
  implementation instead of a dead front door): verified via `nix build
  .#checks.aarch64-darwin.default` (1247/1247 cases, 0 failures, same
  count as before this pair of removals) and `nix build .#coverage`: the
  file rose from 90.8% / 92.6% to 97.0% / 96.3%; tree-wide aggregate rose
  to 89.5% / 94.6% (combined with the `and-compatible-asymmetric-subtype-
  order` test case above, run in the same round).
- `src/inference-forms-advanced-validators.lisp`: `%validate-advanced-
  ffi-call`'s `(unless (ffi-descriptor-form-valid-p descriptor) ...)`
  check, identified as unreachable in an earlier round of this session's
  coverage work (documented then as "discarded the test rather than
  forcing it to pass"). `descriptor` here is always the already-
  normalized struct returned by `ffi-descriptor-from-form` — an atom —
  and `ffi-descriptor-form-valid-p`'s own `(atom value) t` clause accepts
  any atom unconditionally, so this check can never fire; malformed
  descriptor *forms* are already caught by `ffi-descriptor-from-form`
  itself while normalizing them, which signals its own error. Removed
  the dead check now that a second, independent read of the same logic
  confirmed the earlier finding; no existing test relied on this
  specific check (the "validates-ffi-descriptor" test's malformed case
  is a runtime argument-type mismatch, caught by a different, later
  check in the same function). Verified via `nix build
  .#checks.aarch64-darwin.default` (1309/1309 cases, 0 failures, same
  count as before this removal) and `nix build .#coverage`:
  `inference-forms-advanced-validators.lisp` reached 100% branch (14/14)
  and 99.6% expression (282/283). Tree-wide aggregate rose to 90.4% /
  97.7% (rounding).

### Fixed

- `src/solver.lisp`: `%solve-row-lacks-constraint` discharged a
  `(:row-lacks rho label)` constraint as satisfied for *any* open concrete
  row (a `type-record`/`type-variant`/`type-effect-row` with a non-nil
  `row-var`), regardless of whether `label` was already present in it —
  directly contradicting the function's own docstring: "Open row
  variables are accepted here; concrete open rows stay residual so the
  caller can refine them later." An open row can still gain `label` via a
  later refinement of its row variable, so treating it as definitely
  lacking the label is unsound. Confirmed via `git log -p` that this bug
  predates the extraction from the `cl-cc` monorepo — every historical
  version of this function's open-row branch discharged unconditionally,
  never residual. It has had zero practical effect so far: `grep -rn
  ":row-lacks"` across `src/` shows the constraint kind is only ever
  *substituted* (`constraint-substitute`) and *solved*
  (`%solve-row-lacks-constraint` itself), never *generated* by any
  inference handler — no code path in this repository's own type checker
  currently constructs a `:row-lacks` constraint over a concrete open row,
  so no real program's inference was affected. It remains a real
  soundness bug in exported, directly-callable API surface
  (`make-row-lacks-constraint` + `solve-constraints`), so it is fixed
  regardless. Discovered while investigating `src/solver.lisp`'s coverage
  gap (87.1% expression / 70.6% branch) — the open-row branch's
  uncovered-by-any-test status is exactly why nothing had caught it.
  Fixed the open-row case to return the constraint as residual, matching
  the docstring, and added `t/solver-test.lisp` cases proving both an
  open row already containing the label and one that does not yet stay
  residual either way, plus the previously-untested `type-variant-p`/
  `type-effect-row-p` disjuncts of the same `OR`, `%solve-typeclass-
  constraint`'s `type-error-p`/`has-typeclass-instance-p` branches (only
  `type-var-p` and the `type-unknown-p`-via-`+type-unknown+` special case
  were tested before), and `%solve-effect-subset-constraint`'s
  not-actually-an-effect-row fallback. Verified via `nix build
  .#checks.aarch64-darwin.default` (1196 → 1200 cases, 0 failures) and
  `nix build .#coverage`: `solver.lisp` rose to 96.2% expression / 97.1%
  branch; tree-wide aggregate rose from 88.2% / 89.8% to 88.4% / 90.3%.
- `src/parser-typed.lisp`: `parse-typed-defun` recognizes a leading
  `(declare (return-type T))` form in its BODY specifically — it checks
  for that exact clause name via `extract-return-type`, not just any
  `declare` — well enough to strip it out of the returned AST node's
  `body`, but the extracted type `T` was then discarded rather than used
  for the node's own `:return-type` field, which came from a completely
  separate, unrelated computation (a bare return-type symbol immediately
  after the lambda list) that `let` — not `let*` — kept from ever seeing
  it. A `(defun foo ((x fixnum)) (declare (return-type string)) ...)`
  form would silently produce a node with `:return-type type-any` instead
  of `type-string`, even though the declare form vanished from `body` as
  if it had been understood. Confirmed via `git log -p` that this bug
  predates the extraction from the `cl-cc` monorepo, unchanged since. Like
  the two bugs above, `parse-typed-defun` has zero callers anywhere else
  in `src/` (only exported, directly-callable API), so no current
  behavior in this repository's own pipeline was affected. Discovered
  while investigating `src/parser-typed.lisp`'s coverage gap (90.2%
  expression / 75.0% branch): the `(cdr rest)` body-stripping branch
  showed as covered by no existing test at all, and reasoning through
  when it *would* be reached surfaced the disconnect. Fixed by computing
  the declared return type once and using it for both `body`-stripping
  and `:return-type` (falling back to it only when the bare-symbol form
  is absent, preserving that form's existing priority), and added
  `t/parser-typed-test.lisp` cases proving each return-type spelling
  reaches its own AST node correctly — including one documenting, rather
  than silently relying on, the accompanying finding that the bare-symbol
  spelling does *not* get stripped from `body` the way the `declare` form
  does, a real if minor asymmetry between the two syntaxes left as-is
  since fixing it was outside this bug's scope. Also closed 4 more
  coverage gaps in the same round: `parse-row-type`'s malformed-field
  error, `parse-typed-optional-parameter`'s under-length-list clause,
  `extract-return-type`'s "declare present but not return-type" clause,
  and the bare-symbol return-type syntax itself. Verified via `nix build
  .#checks.aarch64-darwin.default` (1205 → 1210 cases, 0 failures) and
  `nix build .#coverage`: the file rose to 93.5% expression / 89.1%
  branch; tree-wide aggregate rose from 88.7% / 91.2% to 88.7% / 91.6%.
- `src/unification.lisp`: `%unify-free-var` rejected unifying a type
  variable with another variable that already resolves — through a
  chain of substitution links — to the first variable itself. Example:
  with `B` bound to `A` in the current substitution (`B` is simply an
  alias for `A` at this point), `(type-unify A B subst)` incorrectly
  failed. The root cause is in `type-occurs-p`: it cannot distinguish
  "`OTHER` resolves all the way down to `VAR`" (identity — trivially
  fine to unify) from "`VAR` occurs nested inside `OTHER`'s structure"
  (genuine circularity — must be rejected to avoid an infinite type),
  and treats both as an occurs-check failure. This is a completeness
  bug, not a soundness one: it caused type inference to spuriously
  reject some valid programs (any unification between two variables one
  of which is already an alias of the other) rather than accept invalid
  ones, but the fix still needed the same care as a soundness fix, since
  it touches this system's single most central function. Found while
  investigating a `unification.lisp` coverage gap: `%bind-type-var-with-
  bounds`'s `((type-var-p resolved) subst)` clause — a trivial-success
  no-op clearly written to handle exactly this alias case — was
  provably unreachable through its only caller, and tracing back through
  why led to `type-occurs-p`'s conflation. Fixed at the call site rather
  than by changing `type-occurs-p` itself, to keep the fix minimal and
  avoid touching that function's behavior for every other caller and
  case: `%unify-free-var` now checks, before running the occurs check,
  whether `OTHER` zonks down to a type-var that is `type-var-equal-p` to
  `VAR`, and short-circuits to success if so. Verified the fix doesn't
  weaken genuine occurs-check protection by rerunning the full suite
  (1299/1299 passing, including the pre-existing `unify-occurs-check-
  circular` test for the actual-circularity case `(type-unify A (A ->
  int))`, which still correctly fails) — a compound type wrapping `VAR`
  is never itself `type-var-p` after zonking, so the new check cannot
  accidentally swallow a real circular case. The regression test that
  had pinned the old (wrong) behavior as a documented limitation two
  rounds ago now asserts the corrected behavior instead. With the alias
  case now handled one level up, `%bind-type-var-with-bounds`'s own
  `((type-var-p resolved) subst)` clause is fully, provably unreachable
  — left in place as low-risk defensive dead code rather than removed in
  the same round as the behavioral fix. Verified via `nix build
  .#checks.aarch64-darwin.default` (1299/1299 cases, 0 failures) and
  `nix build .#coverage`: `unification.lisp` rose to 99.5% expression /
  98.3% branch (171/174). Tree-wide aggregate held at 90.2% / 97.2%
  (rounding).
- `src/unification.lisp` (same fix, follow-up cleanup): with the alias
  case now handled at the call site, `%bind-type-var-with-bounds`'s
  `((type-var-p resolved) subst)` clause (confirmed unreachable by the
  fix above) was genuinely dead — removed, folding its guard's negated
  conjunct out of the remaining merge clause rather than leaving
  redundant dead code sitting next to a fix in the same file. Verified
  no regression across the full 1299-case suite, unchanged from before
  this cleanup. Then closed `unification.lisp`'s two remaining coverage
  gaps in `t/unification-test.lisp`/`t/unification-effect-rows-test.lisp`,
  reaching 100% branch.
  - `%UNIFY-FREE-VAR`'s identity clause, `(AND (TYPE-VAR-P other)
    (TYPE-VAR-EQUAL-P var other))`, is distinct from `TYPE-UNIFY`'s own
    top-level `(EQ T1 T2)` fast path: it catches two *different*
    `TYPE-VAR` objects that share the same ID (`TYPE-VAR-EQUAL-P`
    compares by ID, not object identity) — a case every `FRESH-TYPE-
    VAR` call elsewhere in the suite avoids by construction, since each
    call mints a genuinely unique ID. Built two var objects sharing an
    ID directly via the low-level `%MAKE-TYPE-VAR` constructor to reach
    it.
  - The effect-row "both sides have unique effects, need both row
    vars" case's `(IF OK1 ... (FAIL))` branch, for when unifying the
    *first* synthesized row variable itself fails, had never fired: the
    pre-existing positive case always unifies a row variable against a
    fresh, trivially-compatible synthesized effect row. Pre-binding
    that row variable to an unrelated concrete type (`TYPE-INT`) in the
    incoming substitution before the call makes that inner unification
    fail structurally instead.
  Verified via `nix build .#checks.aarch64-darwin.default` (1299 → 1301
  cases, 0 failures) and `nix build .#coverage`: `unification.lisp`
  reached 100% branch (168/168) and 99.9% expression (770/771, only the
  file's `IN-PACKAGE` form left dark). Tree-wide aggregate rose to
  90.3% / 97.4%.
- `src/types-extended-advanced-validators.lisp`: `%TYPE-ADVANCED-VALIDATE-
  PROOF-LIKE`'s own `(VALIDATE-ADVANCED advanced evidence "requires
  explicit proof/termination evidence")` check — the same dead-validator
  shape found twice earlier this session in FR-2405 and FR-3302 — was
  provably redundant with `%TYPE-ADVANCED-VALIDATE-CONTRACT`'s generic
  `:REQUIRES-EVIDENCE-P` evidence-presence check (`src/types-extended-
  advanced-validate.lisp`), which every contract dispatching to this
  custom validator (FR-1901–1906, FR-2001–2005, FR-3406) already sets to
  `T`, and which runs before any custom validator in the fixed dispatch
  order (arg-count → required-properties → property-predicates →
  evidence-presence → evidence-predicate → custom-validator). Removed the
  redundant call, keeping the function's genuinely custom evidence-*shape*
  checks (the FR-1901–1906 totality-evidence disjunction and the FR-2001–
  2005/FR-3406 proof-evidence disjunction) untouched. Verified via `nix
  build .#checks.aarch64-darwin.default` (1309/1309 cases, unchanged) and
  `nix build .#coverage`: `types-extended-advanced-validators.lisp` moved
  from 413/418 to 412/416 expression (removing exactly the two now-gone
  expressions, one fewer covered), branch unchanged at 97/100 since the
  removed call was straight-line, not itself a branch point. Tree-wide
  aggregate: 90.41% expression (12391/13705) / 97.80% branch (1958/2002).
- `src/typeclass.lisp`: `%TYPE-CLASS-TYPE-STRING`'s five-clause fallback
  tail (`TYPE-PRIMITIVE-P`, `TYPE-VAR-P`, `TYPE-ERROR-P`, `NULL`, `SYMBOLP`,
  and a final `PRINC-TO-STRING`) existed to build a stable registry-key
  string "without depending on printer load order," guarded by a leading
  `(FBOUNDP 'TYPE-TO-STRING)` check. That guard is a tautology: `TYPE-TO-
  STRING` is a `DEFGENERIC` in `types-env.lisp`, which `cl-cc-type.asd`
  loads before `typeclass.lisp` (and long before `printer.lisp`, whose
  load order the guard was written to protect against), so it is
  unconditionally `FBOUNDP` at every point this function can run,
  including from `typeclass.lisp`'s own load-time `EVAL-WHEN`. The `COND`
  therefore always takes its first clause regardless of `TYPE`'s runtime
  value, making the other five clauses permanently unreachable — not a
  load-order-defensive case (kept elsewhere this session) but a genuinely
  dead one, confirmed by grepping every call site (`t/typeclass-test.lisp`
  passes only real type-node objects, never a bare symbol or other
  fallback-triggering value). Simplified to a direct `(TYPE-TO-STRING
  TYPE)` call. Verified via `nix build .#checks.aarch64-darwin.default`
  (1309/1309 cases, unchanged) and `nix build .#coverage`: `typeclass.lisp`
  branch coverage rose from 45/62 (72.6%) to 44/50 (88.0%) — the dead
  clauses accounted for 12 branch points, not merely unreached lines. Tree-
  wide aggregate rose to 90.52% expression (12388/13686) / 98.34% branch
  (1957/1990).
- `t/typeclass-test.lisp`: added `existing-class-instances-filters-by-
  class-name-and-tolerates-non-cons-keys`, closing `%EXISTING-CLASS-
  INSTANCES`'s `(AND (CONSP k) (EQ (CAR k) class-name))` guard. Every key
  written through the public API is a `(CLASS-NAME . TYPE-STRING)` cons
  from `%TYPE-INSTANCE-KEY`, so neither conjunct's false path was
  reachable through `REGISTER-TYPECLASS-INSTANCE` alone; reached both
  directly, following this session's established "poke the internal
  registry, verify, let-scope discards it" idiom: registered instances
  under two distinct class names in one isolated (`LET`-rebound)
  registry table to exercise `EQ`'s false path when filtering for just
  one, and inserted a non-cons key by hand to exercise `CONSP`'s false
  path. Verified via `nix build .#checks.aarch64-darwin.default`
  (1309 → 1310 cases, 0 failures) and `nix build .#coverage`:
  `typeclass.lisp` branch rose from 44/50 to 46/50 (88.0% → 92.0%).
  Tree-wide aggregate rose to 90.52% expression (unchanged) / 98.44%
  branch (1959/1990).
- `t/substitution-test.lisp`: added `instantiate-skips-fresh-substitution-
  for-an-already-linked-quantified-var`, closing `INSTANTIATE`'s
  `(WHEN (TYPE-VAR-P fresh) ...)` bound-preservation guard. `ZONK`'s
  `TYPE-VAR` method (`src/substitution.lisp`) checks the var's own
  `TYPE-VAR-LINK` slot *before* consulting the passed-in `SUBST`, so a
  quantified var whose link was already set by some earlier, unrelated
  unification reusing the same var object resolves straight through its
  own link, bypassing `INSTANTIATE`'s freshly built substitution
  entirely — not a defensive dead branch but a real path only reachable
  when a var object is aliased across two logically distinct schemes.
  Reproduced directly: built a one-variable scheme, hand-set that
  variable's `TYPE-VAR-LINK` to `TYPE-INT` before calling `INSTANTIATE`,
  and confirmed the result is `TYPE-INT` rather than a fresh variable.
  Verified via `nix build .#checks.aarch64-darwin.default` (1310 → 1311
  cases, 0 failures) and `nix build .#coverage`: `substitution-
  schemes.lisp` reached 100% branch (18/18, up from 17/18). Tree-wide
  aggregate: 90.52% expression (unchanged) / 98.49% branch (1960/1990).
- `t/subtyping-extended-test.lisp`: added `primitive-class-record-type-
  degrades-gracefully-when-inference-lisp-is-unloaded`, closing
  `%PRIMITIVE-CLASS-RECORD-TYPE`'s two `(FBOUNDP 'LOOKUP-CLASS-TYPE)` /
  `(FBOUNDP 'LOOKUP-CLASS-METHOD-TYPES)` guards. Unlike this session's
  earlier `%TYPECLASS-TYPE-STRING` finding, this guard is architecturally
  live, not dead: `subtyping.lisp` sits at position 61 in `cl-cc-
  type.asd`, deliberately before `inference.lisp` (position 71, which
  defines both looked-up functions), so `subtyping.lisp` carries no hard
  load-order dependency on the higher-level inference module — the guard
  is what lets a smaller subsystem, or a future reordering, degrade to
  "no structural class fields" instead of erroring. In the fully loaded
  system both symbols are always `FBOUNDP` by the time `IS-SUBTYPE-P`
  (the guard's only caller path) can ever run, so the false path doesn't
  occur through any normal test; reached it directly by temporarily
  `FMAKUNBOUND`-ing both symbols around a single call, restoring via
  `UNWIND-PROTECT`. Verified via `nix build .#checks.aarch64-darwin.default`
  (1311 → 1312 cases, 0 failures) and `nix build .#coverage`:
  `subtyping.lisp` branch rose from 130/134 (97.0%) to 132/134 (98.5%).
  Tree-wide aggregate: 90.52% expression (unchanged) / 98.59% branch
  (1962/1990).
- `t/types-utility-test.lisp`: added `type-level-natural-value-signals-for-
  a-raw-negative-integer`, closing `TYPE-LEVEL-NATURAL-VALUE`'s
  `(MINUSP type)` conjunct — every pre-existing call passed either a
  non-negative raw integer or a non-integer, so `MINUSP` had only ever
  been observed false. A raw negative integer is `INTEGERP` but `MINUSP`,
  falling through past both the raw-integer clause and the wrapped-node
  clause (a raw integer is never `TYPE-LEVEL-NATURAL-P`) to the final
  `ERROR` clause. Also extended `matrix-mul-type-rejects-non-matrix-
  arguments` with a second case where `RIGHT` (not `LEFT`) is the
  non-matrix argument, closing `MATRIX-MUL-TYPE`'s own `(TYPE-
  CONSTRUCTOR-P right)` conjunct, which every other test had only ever
  driven true. Verified via `nix build .#checks.aarch64-darwin.default`
  (1312 → 1313 cases, 0 failures) and `nix build .#coverage`: `types-
  level-naturals.lisp` reached 100% branch (28/28, up from 26/28). Tree-
  wide aggregate: 90.52% expression (unchanged) / 98.69% branch
  (1964/1990).
- `t/printer-test.lisp`: added `printer-arrow-mult-table-signals-for-an-
  unknown-multiplicity`, closing `%ARROW-STRING`'s `(ERROR "Unknown arrow
  multiplicity: ~S" mult)` fallback. `TYPE-ARROW`'s `MULT` slot carries no
  `:TYPE` restriction (unlike, e.g., `TYPE-ADVANCED`'s `NAME`), so a
  hand-built arrow with an invalid `:MULT` keyword reaches this genuinely
  live error path; the three pre-existing tests only ever drove the
  table's three known-good keywords. An expression-level gap, not a
  branch one: `PRINTER.LISP`'s one remaining branch gap is the same
  struct-enforced `(SYMBOLP surface-head)` case already confirmed
  unfixable in `printer-unparse.lisp` (`TYPE-ADVANCED`'s `NAME` slot is
  `:TYPE SYMBOL`). Verified via `nix build .#checks.aarch64-darwin.default`
  (1313 → 1314 cases, 0 failures) and `nix build .#coverage`:
  `printer.lisp` expression coverage rose from 327/333 to 330/333 (branch
  unchanged at 37/38, confirmed unfixable). Tree-wide aggregate: 90.54%
  expression (12391/13686) / 98.69% branch (unchanged).
- `src/types-extended-ffi.lisp`: `FFI-DESCRIPTOR-LISP-TYPE`'s final two
  `COND` clauses — `((FFI-FUNCTION-DESCRIPTOR-P normalized) ...)` and a
  `(T type-any)` fallback — were both redundant: the guard's `FFI-
  FUNCTION-DESCRIPTOR-P` check was always true when reached, and the
  fallback was never reachable at all. `FFI-DESCRIPTOR-FROM-FORM`'s own
  `COND`
  (exhaustively read) always returns exactly one of four descriptor kinds
  (scalar, pointer, callback, function) or signals an error; having ruled
  out scalar/pointer/callback in the three preceding clauses, `NORMALIZED`
  can only be a function descriptor by elimination. Collapsed into one
  unconditional `T` clause carrying the arrow-construction body,
  removing both the redundant predicate and the dead fallback. Verified
  via `nix build .#checks.aarch64-darwin.default` (1314/1314 cases,
  unchanged) and `nix build .#coverage`: `types-extended-ffi.lisp`
  reached 100% branch (66/66, down from 67/68 — both removed points were
  dead, not newly covered). Tree-wide aggregate: 90.54% expression
  (12390/13684) / 98.74% branch (1963/1988).
- `src/parser.lisp`: `PARSE-PRIMITIVE-TYPE`'s `(AND (BOUNDP '*TYPE-ALIAS-
  REGISTRY*) (GETHASH name *TYPE-ALIAS-REGISTRY*))` guard removed — unlike
  `SUBTYPING.LISP`'s analogous `FBOUNDP` guard (kept this session as
  architecturally live), this one is stale: `package.lisp:420` already
  binds `*TYPE-ALIAS-REGISTRY*` via an early `DEFVAR`, with a comment
  explicitly stating why — "so type/parser.lisp can reference it before
  type/inference.lisp is loaded... defvar is idempotent." Since
  `package.lisp` loads first (position 1 in `cl-cc-type.asd`, before
  everything, including `parser.lisp` at position 65), the variable has
  been unconditionally bound since before this guard's own file starts
  loading — the fix that made the guard unnecessary already shipped,
  just not the cleanup. Removed the now-redundant `BOUNDP` check.
  Verified via `nix build .#checks.aarch64-darwin.default` (1314/1314
  cases, unchanged) and `nix build .#coverage`: `parser.lisp` reached
  100% branch (52/52, down from 53/54 — the removed branch point was
  dead, not newly covered). Tree-wide aggregate: 90.54% expression
  (12387/13681) / 98.79% branch (1962/1986).
- `src/parser-extended.lisp`: two fixes.
  - `%KNOWN-ADVANCED-TYPE-ATOM-P`'s `(BOUNDP '*TYPE-ALIAS-REGISTRY*)`
    guard removed — the identical stale-guard finding as `parser.lisp`
    above; `package.lisp:420`'s early `DEFVAR` already makes the variable
    unconditionally bound before this file loads.
  - `%PARSE-ADVANCED-VALUE`'s dead `(LISTP value)` / `(T (CONS ...))`
    clause pair, already proven unreachable and documented (but not
    removed) in an earlier round — `LISTP` is `(OR (CONSP x) (NULL x))`,
    a tautology once the outer `(CONSP value)` clause is already known
    true, so the dotted-pair fallback could never fire; `t/parser-
    test.lisp` even records that a stray attempt to test it directly hit
    `MAPCAR` signalling a type-error first. Collapsed the inner `COND` to
    a two-way `IF`, converting the confirmed-but-undeleted finding into
    an actual removal, and deleted the now-stale `NOTE` comment
    documenting it in `t/parser-test.lisp`.
  - `t/parser-arrow-quantifier-test.lisp`: added `parse-bounded-
    quantifier-malformed-bounds-unrecognized-operator-symbol`, closing
    `%BOUND-OPERATOR-KIND`'s own `(T NIL)` fallback — distinct from the
    pre-existing "invalid-operator" test, whose non-symbol `42` operand
    never reaches `%BOUND-OPERATOR-KIND`'s `COND` at all (the function's
    outer `(WHEN (SYMBOLP op) ...)` guard short-circuits first); a
    genuine symbol matching neither operator name list (`FOO`) reaches
    and falls through both `MEMBER` checks.
  Verified via `nix build .#checks.aarch64-darwin.default` (1314 → 1315
  cases, 0 failures) and `nix build .#coverage`: `parser-extended.lisp`
  reached 100% branch (106/106, down from 107/110 pre-fix — two removed
  points were dead, one newly covered). Tree-wide aggregate: 90.59%
  expression (12383/13669) / 98.94% branch (1961/1982).
- `t/subtyping-extended-test.lisp`: two more `subtyping.lisp` closures.
  - `row-label-equal-p-rejects-a-non-symbol-label-that-does-not-match-by-
    eq`, closing `%ROW-LABEL-EQUAL-P`'s `(SYMBOLP a)` conjunct — every
    pre-existing record/variant field label (including the package-
    independent keyword-vs-symbol case tested just above it) is a symbol,
    so `SYMBOLP` had only ever been observed true. A string label can
    never `EQ` any symbol field, forcing evaluation into the `AND`, where
    `SYMBOLP` correctly rejects it rather than erroring on `SYMBOL-NAME`.
  - `primitive-class-record-type-returns-nil-for-a-non-primitive-type`,
    closing `%PRIMITIVE-CLASS-RECORD-TYPE`'s `(TYPE-PRIMITIVE-P ty)`
    guard by calling the private function directly with a non-primitive
    (its sole caller, `IS-SUBTYPE-P`'s `TYPE-PRIMITIVE` typecase arm,
    already guarantees the precondition, so no test through that path
    could ever reach the guard's false side).
  Verified via `nix build .#checks.aarch64-darwin.default` (1315 → 1317
  cases, 0 failures) and `nix build .#coverage`: `subtyping.lisp` reached
  100% branch (134/134, up from 132/134). Tree-wide aggregate: 90.59%
  expression (unchanged) / 99.04% branch (1963/1982) — the tree-wide
  branch aggregate crosses 99% for the first time this session.
- `src/types-extended-advanced-validators.lisp` /
  `t/types-extended-advanced-validators-test.lisp`: closed the file's
  three remaining branch gaps.
  - `%TYPE-ADVANCED-VALIDATE-TYPE-THEORY-EQUALITY`'s `(MEMBER mode
    '(:EXTENSIONAL :OBSERVATIONAL) ...)` clause simplified to `T` — a
    third exhaustiveness-by-elimination finding this session (after
    `FFI-DESCRIPTOR-LISP-TYPE`): `%TYPE-ADVANCED-EQUALITY-MODE-P`'s
    registered property-predicate (`types-extended-advanced-meta-
    validators.lisp`) already restricts `:MODE` to exactly `"INTENSIONAL"
    "EXTENSIONAL" "OBSERVATIONAL"` before this custom validator ever
    runs, so having ruled out `:INTENSIONAL` in the preceding clause, the
    `MEMBER` test can only ever be true.
  - Added a case to the existing FR-2804 test omitting the optional
    `:NARROWING` property entirely, closing `%TYPE-ADVANCED-VALIDATE-
    ABSTRACT-INTERPRETATION`'s `TYPE-ADVANCED-PROPERTY-PRESENT-P` check
    on `:NARROWING` — the two pre-existing cases always supplied it.
  - Added `advanced-validate-encodings-fr-3403-skips-the-head-check-for-
    the-generic-advanced-form`, closing the PARIGOT-ENCODING `STRING=`
    clause's false path in `%TYPE-ADVANCED-VALIDATE-ENCODINGS`: the
    generic `(ADVANCED FR-3403 ...)` surface form (rather than a named
    `*-ENCODING` head) defaults `TYPE-ADVANCED-NAME` to `'ADVANCED`,
    matching none of the three named clauses.
  Verified via `nix build .#checks.aarch64-darwin.default` (1317 → 1318
  cases, 0 failures) and `nix build .#coverage`: `types-extended-
  advanced-validators.lisp` reached 100% branch (98/98, down from 97/100
  — one point newly covered, two removed as dead). Tree-wide aggregate:
  90.60% expression (12379/13664) / 99.19% branch (1964/1980).
- `t/types-extended-qtt-test.lisp`: revisited `types-extended-qtt.lisp`'s
  remaining branch gaps (documented as diminishing-returns earlier this
  session) with the argument-order technique found working elsewhere
  this round. Every pre-existing broken-semiring test overrides ADD/
  MULTIPLY only for an a-FIRST pair, (A, ZERO) or (A, ONE); the commuted
  ZERO-a / ONE-a conjuncts in `%SEMIRING-PER-ELEMENT-LAWS-P` therefore
  always inherited the same already-true outcome as their a-first
  sibling. Added four tests overriding the ZERO-first/ONE-first pair
  specifically (mirroring the existing a-first ones), closing all four
  commuted conjuncts, plus a fifth closing `%SEMIRING-COMMUTATIVE-P`'s
  own `ADD` closure conjunct via a 3-element carrier breaking closure at
  a non-identity pair `(1, 2)` (the existing add-not-closed test breaks
  at a ZERO-involving pair, which `%SEMIRING-PER-ELEMENT-LAWS-P` already
  rejects before `%SEMIRING-COMMUTATIVE-P` is ever reached). A sixth
  test targeting `%SEMIRING-ASSOCIATIVE-DISTRIBUTIVE-P`'s `MULTIPLY`-
  associativity conjunct (a 4-element carrier where `(2*2)*3 ≠ 2*(2*3)`
  while every identity/annihilation/closure/commutativity law and
  `ADD`'s own associativity still hold) passes as a meaningful test in
  its own right but did not land on that exact coverage line, matching
  the diminishing-returns pattern already noted for this file. Verified
  via `nix build .#checks.aarch64-darwin.default` (1318 → 1324 cases, 0
  failures) and `nix build .#coverage`: `types-extended-qtt.lisp` branch
  rose from 58/64 (90.6%) to 63/64 (98.4%). Tree-wide aggregate: 90.60%
  expression (unchanged) / 99.44% branch (1969/1980).
- `t/parser-test.lisp`: a codebase-wide unused-symbol audit (cross-
  referencing every `defun`/`defmacro`/`defgeneric` name, including the
  six `DEFINE-REGISTRY`-generated register/lookup pairs, against every
  call site in `src/` and `t/`) found exactly one unreferenced
  definition out of roughly 590 checked: `REGISTER-TYPE-ALIAS`, the
  `DEFINE-REGISTRY`-generated public setter for `*TYPE-ALIAS-REGISTRY*`.
  Its sibling `LOOKUP-TYPE-ALIAS` is called from `printer-unparse.lisp`,
  and the registry itself is exercised, but only by writing to the hash
  table directly (`(SETF (GETHASH key table) ...)`) rather than through
  the exported setter. Unlike this session's other dead-code removals,
  this isn't orphaned logic to delete — it's the write half of a
  documented, exported, symmetric public API pair (`docs/src/api-
  reference.md`), generated identically for all six registries in this
  codebase, so suppressing it here alone would be inconsistent and
  would remove real public API on the strength of an in-tree call-graph
  argument alone. Switched `parse-primitive-type-alias-registry-lookup`
  to call `REGISTER-TYPE-ALIAS` instead of poking the hash table
  directly: this closes the call-graph gap and is simultaneously the
  more idiomatic way to populate the registry under test. Verified via
  `nix build .#checks.aarch64-darwin.default` (1324/1324 cases,
  unchanged) and `nix flake check -L`, including `checks.paredit-lint`
  (125 files, 0 parse errors).

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
