# API Reference

Every symbol below is exported from `cl-cc/type`.

!!! note "Coverage"

    The package exports roughly 800 symbols, and this page documents the
    entry points in full plus the shape of every other group. Struct
    constructors, predicates and accessors follow the ASDF/`defstruct`
    convention without exception — `make-<struct>`, `<struct>-p`,
    `<struct>-<slot>` — so they are listed by group rather than one by one.
    Symbols that are not yet written up individually are listed in
    [Groups](#groups); the source of truth for the complete export list is
    `src/package.lisp`.

## Parsing and printing

### `parse-type-specifier`

```lisp
(cl-cc/type:parse-type-specifier spec)
  => type-node
```

Parses a Lisp type specifier into a type node.

`spec` may be `nil` (the null type), a symbol (a primitive, a type alias, or an
otherwise unknown primitive kept as-is), or a cons (a compound type). The
symbols `?` and `_` produce a gradual-typing hole.

**Returns**: a `type-node`.

**Signals**: `type-parse-error` when `spec` is neither `nil`, a symbol, nor a
cons, or when a compound form is malformed.

**Example**:

```lisp
(cl-cc/type:unparse-type
 (cl-cc/type:parse-type-specifier '(function (integer) string)))
; => (-> FIXNUM STRING)
```

See also: [`unparse-type`](#unparse-type), [Core Concepts](core-concepts.md#type-nodes).

### `unparse-type`

```lisp
(cl-cc/type:unparse-type ty)
  => specifier
```

Converts a type node back into a type specifier s-expression. This is the
readable way to inspect any result from this library.

The round trip normalises rather than preserving surface syntax: `integer`,
`int` and `fixnum` all print as `FIXNUM`, and `(function (a) b)` prints as
`(-> A B)`. An unnamed type variable prints as `?T<id>`.

**Returns**: an s-expression.

**Signals**: `none`.

### `parse-primitive-type`, `parse-compound-type`, `parse-function-type`

The three dispatch targets of `parse-type-specifier`, exported so a caller that
already knows which shape it has can skip the dispatch. Same conditions.

### `parse-typed-defun`, `parse-typed-lambda`, `parse-lambda-list-with-types`, `parse-typed-parameter`, `parse-typed-optional-parameter`, `extract-return-type`, `looks-like-type-specifier-p`

The typed-surface-syntax parser: it reads lambda lists carrying type
annotations into the `ast-defun-typed` and `ast-lambda-typed` structs, which
carry the parameter types and return type alongside the body.

## Unification and substitution

### `type-unify`

```lisp
(cl-cc/type:type-unify t1 t2 &optional subst)
  => (values substitution success-p)
```

Unifies two type nodes by Prolog-style unification with an occurs check.

| Argument | Type | Default | Meaning |
|---|---|---|---|
| `t1` | `type-node` | — | Left-hand type |
| `t2` | `type-node` | — | Right-hand type |
| `subst` | `substitution` | a fresh empty one | Substitution to extend |

**Returns**: `(values updated-substitution t)` on success, `(values nil nil)` on
failure. A plain mismatch is a return value, not a condition — the caller
decides whether it is an error.

**Signals**: `none` for a mismatch.

**Example**:

```lisp
(let ((a (cl-cc/type:fresh-type-var :name 'a)))
  (multiple-value-bind (subst ok)
      (cl-cc/type:type-unify a (cl-cc/type:parse-type-specifier '(function (integer) string)))
    (and ok (cl-cc/type:unparse-type (cl-cc/type:apply-unification a subst)))))
; => (-> FIXNUM STRING)
```

### `type-unify-lists`

Unifies two lists of types pairwise, threading one substitution through.
Returns `(values substitution success-p)`; fails if the lists differ in length.

### `apply-unification`, `zonk`, `zonk-env`

`apply-unification` replaces every variable a substitution binds inside a type.
`zonk` resolves fully, following variable-to-variable chains to the end;
`zonk-env` does the same across a whole type environment.

### `subst-lookup`, `subst-extend`, `subst-extend!`, `subst-compose`, `make-substitution`, `substitution-bindings`, `substitution-generation`

The substitution structure. `subst-extend` is functional and `subst-extend!`
mutates; `subst-compose` composes two substitutions.

### `type-occurs-p`

```lisp
(cl-cc/type:type-occurs-p var ty)
  => boolean
```

The occurs check: true when `var` appears inside `ty`. Binding a variable to a
type containing it would construct an infinite type, so unification refuses.

### `fresh-type-var`, `reset-type-vars!`, `type-var-equal-p`

`fresh-type-var` allocates a variable with a fresh id from a global counter and
accepts a `:name` for readability; identity is the id, not the name.
`reset-type-vars!` resets the counter, which is what a test does to get stable
ids.

## Inference and checking

### `infer`

```lisp
(cl-cc/type:infer ast env)
  => (values type substitution)
```

Infers the type of `ast` in the type environment `env`, bottom-up. `ast` is a
`cl-cc/ast` node.

**Returns**: `(values type substitution)`.

**Signals**: `type-inference-error` and its subtypes — `type-mismatch-error`,
`unbound-variable-error`, `typed-hole-error`.

### `infer-with-env`

```lisp
(cl-cc/type:infer-with-env ast)
  => (values type substitution)
```

`infer` against a fresh empty environment.

### `synthesize` / `check`

```lisp
(cl-cc/type:synthesize ast env)          => (values type substitution)
(cl-cc/type:check ast expected-type env) => substitution
```

The bidirectional pair. `synthesize` is the bottom-up mode and currently
forwards to `infer`. `check` is the top-down mode: it verifies `ast` against a
type that is already known, which is what lets rank-N annotations be usable —
a `forall` in expected position introduces skolem constants and checks the body
under them.

`check` returns immediately with `nil` when `expected-type` is `+type-unknown+`.

**Signals**: `check` signals `type-mismatch-error` on failure.

### `infer-binop`, `infer-if`, `infer-let`, `infer-lambda`, `infer-call`, `infer-progn`, `infer-args`, `check-body`, `annotate-type`, `narrow-union-type`, `extract-type-guard`, `syntactic-value-p`

The per-form inference rules and their helpers, exported so a downstream stage
can reuse one rule without re-entering the `typecase` in `infer`.
`syntactic-value-p` is the value restriction test that decides whether a
binding may be generalised.

### `check-skolem-escape`, `skolem-appears-in-type-p`

Rank-N soundness: a skolem constant introduced by `check` must not escape the
scope that introduced it.

## Constraints

### `collect-constraints`

```lisp
(cl-cc/type:collect-constraints ast env)
  => (values type constraints)
```

Walks an AST and emits the constraint list rather than solving as it goes.

### `solve-constraints`

```lisp
(cl-cc/type:solve-constraints constraints subst)
  => (values new-subst residual-constraints)
```

An OutsideIn(X)-style solver.

| Argument | Type | Default | Meaning |
|---|---|---|---|
| `constraints` | list of `constraint` | — | From `collect-constraints` |
| `subst` | `substitution` | — | `nil` is accepted and replaced by a fresh one |

**Returns**: `(values new-subst residual)`. `new-subst` is `subst` extended by
equality solving; `residual` holds the constraints that could not be
discharged, typically typeclass and implication constraints.

### `make-equal-constraint`, `make-subtype-constraint`, `make-typeclass-constraint`, `make-implication-constraint`, `make-effect-subset-constraint`, `make-mult-leq-constraint`, `make-row-lacks-constraint`, `make-kind-equal-constraint`

The eight constraint constructors, plus `constraint-kind`, `constraint-args`,
`constraint-free-vars` and `constraint-substitute` for inspecting them. See
[Core Concepts](core-concepts.md#constraints-and-the-solver) for what each one
means.

## Subtyping

### `subtypep`

```lisp
(cl-cc/type:subtypep type1 type2)
  => (values subtype-p sure-p)
```

The subtype predicate over the compiler's lattice. Both arguments may be type
nodes or type specifiers; specifiers are parsed first.

This symbol shadows `cl:subtypep` and returns the same `(values answer
certain-p)` shape, but it answers about *this* type system, not the host Lisp's.

**Returns**: `(values subtype-p t)`.

**Signals**: `none`.

**Example**:

```lisp
(cl-cc/type:subtypep 'integer 'number)  ; => T, T
(cl-cc/type:subtypep 'string 'integer)  ; => NIL, T
```

### `type-join` / `type-meet`

```lisp
(cl-cc/type:type-join t1 t2)  => type-node
(cl-cc/type:type-meet t1 t2)  => type-node
```

Least upper bound and greatest lower bound in the subtype lattice.

**Example**:

```lisp
(cl-cc/type:unparse-type
 (cl-cc/type:type-join (cl-cc/type:parse-type-specifier 'integer)
                       (cl-cc/type:parse-type-specifier 'float)))
; => REAL
```

### `is-subtype-p`, `type-name-subtype-p`, `find-common-supertype`, `*subtype-table*`, `upgraded-array-element-type`, `upgraded-complex-part-type`

`is-subtype-p` is the node-level predicate `subtypep` wraps. The two
`upgraded-*` symbols shadow their `common-lisp` counterparts for the same
reason `subtypep` does.

## Exhaustiveness

### `check-typecase-exhaustiveness`

```lisp
(cl-cc/type:check-typecase-exhaustiveness arm-types)
  => (values exhaustive-p unreachable-indices warnings)
```

Checks `typecase` coverage. `arm-types` is a list of type-name symbols in
source order; the symbol `t` is the catch-all arm.

**Returns**: `exhaustive-p` is true when the arms have a catch-all or cover the
type; `unreachable-indices` holds the 0-based indices of arms subsumed by an
earlier arm; `warnings` is a list of human-readable strings.

**Signals**: `none`.

**Example**:

```lisp
(cl-cc/type:check-typecase-exhaustiveness '(integer string))
; => NIL, NIL, NIL

(cl-cc/type:check-typecase-exhaustiveness '(number integer t))
; => T, (1), ("arm 1 (INTEGER): unreachable — subsumed by earlier arm")
```

### `check-etypecase-completeness`, `useful-typecase-arms`, `typecase-arm-subsumed-p`

`etypecase` has no catch-all, so its completeness check is stricter.
`typecase-arm-subsumed-p` is the pairwise test the other three build on.

## Conditions

| Condition | Signalled when |
|---|---|
| `type-parse-error` | A type specifier is malformed. `type-parse-error-message` carries the text |
| `type-inference-error` | Base for inference failures. `type-inference-error-message` carries the text |
| `type-mismatch-error` | `check` finds a conflict. `type-mismatch-error-expected` and `-actual` carry the two types |
| `unbound-variable-error` | A variable has no binding in the environment. `unbound-variable-error-name` carries the name |
| `typed-hole-error` | Inference reaches a `?`/`_` hole |

## Groups

The remaining exports are structs with their generated constructors,
predicates and accessors, plus the registries that index them. They are listed
here by concept; `src/package.lisp` groups the export list the same way, so the
two stay in step.

| Group | Principal symbols |
|---|---|
| Kinds | `kind-type`, `kind-arrow`, `kind-row`, `kind-effect`, `kind-multiplicity`, `kind-constraint`, `kind-var`, `+kind-type+` |
| Multiplicity | multiplicity annotations and their ordering, used by `make-mult-leq-constraint` |
| Type environments | `type-env`, `type-scheme`, and the scheme instantiation and generalisation operators |
| Effects | `effect-def`, `*effect-registry*`, `register-effect`, `lookup-effect`, `register-effect-signature`, `lookup-effect-signature`, `infer-effects`, `infer-with-effects`, `check-body-effects`, `effect-row-union`, `effect-row-subset-p` |
| Rows | `row-extend`, `row-restrict`, `row-select`, `row-labels`, `row-closed-p`, `row-open-p`, `effect-row-extend`, `effect-row-restrict`, `effect-row-member-p` |
| Type classes | `typeclass-def`, `typeclass-instance`, `*typeclass-registry*`, `*typeclass-instance-registry*`, `register-typeclass`, `register-typeclass-instance`, `has-typeclass-instance-p`, `check-typeclass-constraint`, `dict-env-extend`, `dict-env-lookup` |
| Type constructors | `type-constructor-def`, `*type-constructor-registry*`, `register-type-constructor`, `lookup-type-constructor`, `*protocol-type-registry*` |
| Aliases and class types | `*type-alias-registry*`, `register-type-alias`, `lookup-type-alias`, `*class-type-registry*`, `register-class-type`, `lookup-class-type`, `lookup-slot-type`, `*class-method-type-registry*`, `*type-predicate-table*` |
| Advanced semantics | Regions, capabilities, units, QTT, dependent types, FFI descriptors, security labels, contracts and proof-carrying evidence |
| Datatype generics (FR-1602) | `generic-sum`, `generic-product`, `generic-k1`, `generic-m1`, `generic-u1`, `generic-instance` |
| Concurrency types | `typed-channel`, `send-channel`, `recv-channel`, `typed-actor-ref`, `stm-action`, `typed-coroutine`, `typed-generator`, `simd-vector`, `route` |
| Type-level utilities | Type-level naturals and strings, heterogeneous lists, and the utility predicates over them |
