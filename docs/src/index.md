# cl-cc-type

The type system of the [cl-cc](https://github.com/nerima-lisp/cl-cc) Common
Lisp compiler, as a standalone ASDF system. It provides the representation of
types, the inference and checking algorithms that produce them, and the parser
and printer that move between types and Lisp type specifiers.

Everything is exported from the `cl-cc/type` package.

```lisp
(cl-cc/type:unparse-type
 (cl-cc/type:parse-type-specifier '(function (integer) string)))
; => (FUNCTION (INTEGER) STRING)
```

## What is here

| Area | Summary |
|---|---|
| Type representation | Primitives, variables, arrows, products, records, variants, unions, intersections, `forall`/`exists`, higher-kinded types, refinements, GADTs |
| Kinds and multiplicity | A kind system over the type language, plus linear/affine multiplicity annotations |
| Inference | Hindley–Milner with rank-N types, plus a bidirectional `synthesize`/`check` pair |
| Constraints | A constraint language and an OutsideIn(X)-style solver |
| Type classes | Class and instance registries, superclasses, defaults, associated types, dictionary environments |
| Effects | Effect definitions, effect rows, and effect inference |
| Subtyping | A subtype relation with join and meet |
| Exhaustiveness | `typecase`/`etypecase` coverage and unreachable-arm detection |

## Where to go next

- [Getting Started](getting-started.md) — add cl-cc-type to a flake and to an
  `.asd`, then parse, unify and infer a type end to end.
- [Core Concepts](guide/core-concepts.md) — type nodes, substitutions and environments.
- [API Reference](reference/api.md) — the exported symbols.
- [Development](project/development.md) — build, test and coverage commands.

## Scope

cl-cc-type depends on exactly one other package in the org, `cl-cc-ast`, and
uses it through its public API: the AST node types that constraint collection
and inference walk. It does not parse source text — turning s-expressions into
ASTs is the job of the compiler's `parse` stage, which is still part of the
`cl-cc` monorepo. See [Development](project/development.md#tests-that-did-not-come-across)
for what that means for the test suite.

Contributing, security and support are org-wide; see the
[nerima-lisp/.github](https://github.com/nerima-lisp/.github) repository.
