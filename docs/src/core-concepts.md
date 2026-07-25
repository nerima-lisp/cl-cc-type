# Core Concepts

Five things account for most of the API: type nodes, type variables,
substitutions, type environments, and constraints. Everything else is either a
way to build them or an algorithm that consumes them.

## Type nodes

A type is a struct, not a symbol. All type structs `:include` a common
`type-node` base, so `(typep x 'type-node)` is the test for "is this a type at
all", and `typecase` over the concrete structs is how every algorithm in the
system dispatches.

| Family | Structs |
|---|---|
| Ground | `type-primitive`, `type-error` (which doubles as the gradual-typing hole) |
| Variables | `type-var` (unifiable), `type-rigid` (skolem, not unifiable) |
| Functions | `type-arrow` |
| Data | `type-product`, `type-record`, `type-variant`, `type-gadt-con` |
| Set-like | `type-union`, `type-intersection` |
| Quantified | `type-forall`, `type-exists`, `type-scheme` |
| Higher-order | `type-app`, `type-lambda`, `type-mu` |
| Qualified | `type-refinement`, `type-linear`, `type-capability`, `type-qualified` |
| Effects | `type-effect-row`, `type-effect-op`, `type-handler` |

The unknown type is the constant `+type-unknown+` rather than a struct of its
own; `type-unknown-p` is the test, and `check` returns immediately when the
expected type is that constant.

`parse-type-specifier` builds nodes from s-expressions and `unparse-type` turns
them back. The pair is not the identity on surface syntax: several specifiers
normalise to one node. `fixnum`, `integer` and `int` are the same primitive and
print as `FIXNUM`; `(function (a) b)` prints as `(-> A B)`.

Nodes are compared structurally, never with `eq` — except `type-var`, which is
compared by id (`type-var-equal-p`).

## Type variables and rigidity

`fresh-type-var` allocates a variable with a fresh id from a global counter.
Two variables are the same variable exactly when their ids match, so the
optional `:name` is a debugging aid, not an identity.

`type-rigid` is the other kind of variable: a skolem constant, introduced when
checking against a `forall` in expected position. A rigid variable does not
unify with anything but itself, which is what makes rank-N checking sound.
`check-skolem-escape` catches the case where one leaks out of its scope.

## Substitutions

A substitution maps variable ids to types. It is a struct with its own
generation counter, not a bare alist, so that a stale substitution can be
detected rather than silently applied.

Three operations matter:

- `subst-extend` adds a binding and returns a new substitution;
  `subst-extend!` mutates in place.
- `apply-unification` walks a type and replaces bound variables.
- `zonk` fully resolves a type against a substitution, following chains of
  variable-to-variable bindings to the end.

`type-occurs-p` is the occurs check: it refuses to bind a variable to a type
that contains it, which is what stops unification from constructing an infinite
type.

## Type environments

A type environment maps program variable names to type schemes. A scheme is a
type together with the variables it generalises over — that is what makes
`let`-bound polymorphism work: the scheme is instantiated with fresh variables
at each use site, so two uses of the same binding can take different types.

`infer` and `check` both take an environment; `infer-with-env` builds an empty
one for you.

## Constraints and the solver

Rather than solving every equation the instant it is generated, inference emits
constraints and hands them to a solver. `collect-constraints` walks an AST and
produces the list; `solve-constraints` discharges what it can and returns the
residue.

| Constructor | Meaning |
|---|---|
| `make-equal-constraint` | Two types must unify |
| `make-subtype-constraint` | One type must be a subtype of another |
| `make-typeclass-constraint` | A type must have an instance of a class |
| `make-implication-constraint` | A constraint holds under assumptions |
| `make-effect-subset-constraint` | One effect row is contained in another |
| `make-mult-leq-constraint` | A multiplicity bound |
| `make-row-lacks-constraint` | A row must not carry a label |
| `make-kind-equal-constraint` | Two kinds must agree |

Typeclass and implication constraints are the ones that typically survive as
residue: they are discharged against the instance registry, not by unification.

## Two ways to run inference

The system offers both directions and they meet in the middle.

`infer` is bottom-up: it computes a type from an expression with no expectation
supplied. `check` is top-down: it verifies an expression against a type that is
already known, which lets it push information inward — this is what makes
rank-N annotations usable at all. `synthesize` is the bidirectional name for
the bottom-up mode and currently forwards to `infer`.

Use `check` when the call site knows the type. Use `infer` when it does not.

## Effects and rows

An effect row is a set of effect labels, open or closed. Row polymorphism is
what lets a function say "these effects, plus whatever the caller has":
`row-extend` adds a label, `row-restrict` removes one, and `effect-row-subset-p`
is the containment test the solver uses for effect constraints.

The same row machinery backs extensible records, which is why `row-labels` and
`row-select` are not effect-specific.

## Registries

Several features are backed by mutable global registries: type constructors,
type classes and their instances, effects, type aliases, class types, and
protocol types. They are special variables (`*typeclass-registry*` and
friends) with matching `register-` and `lookup-` functions.

They are global state, and that is a deliberate trade the compiler makes: a
definition form encountered anywhere in a compilation unit has to be visible to
inference everywhere else in it. Rebind the special variable to a fresh table
to isolate a test.
