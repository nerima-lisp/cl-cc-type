# Quick Start

This page walks one task end to end: take a Lisp type specifier, unify it
against a type variable, and read the answer back out as a specifier. Every
output below is copied from a real session.

Load the system first.

```lisp
(asdf:load-system "cl-cc-type")
(in-package :cl-cc/type)
```

The examples use `in-package` rather than qualifying every call, because the
sequence below touches a dozen symbols. In your own code, prefer
`cl-cc/type:parse-type-specifier` and friends — the package shadows four
`common-lisp` symbols, so `:use`-ing it needs a deliberate decision. See
[Installation](installation.md#a-note-on-the-package-name).

## 1. Parse a specifier into a type node

`parse-type-specifier` turns the s-expression surface syntax into the internal
representation.

```lisp
(parse-type-specifier '(function (integer) string))
; => #S(TYPE-ARROW ...)
```

## 2. Print it back

`unparse-type` is the inverse. It is the readable way to inspect any result.

```lisp
(unparse-type (parse-type-specifier '(function (integer) string)))
; => (-> FIXNUM STRING)
```

Two things to notice. Arrows print in the compiler's own `->` syntax rather
than `common-lisp`'s `function`, and `integer` came back as `fixnum`: `FIXNUM`,
`INTEGER` and `INT` are three spellings of one primitive type, and `FIXNUM` is
the canonical one. That is a normalisation, not a loss.

## 3. Make a fresh type variable

Inference works by generating variables and solving for them. `fresh-type-var`
allocates one with a globally increasing id.

```lisp
(defparameter *a* (fresh-type-var :name 'a))
```

## 4. Unify

`type-unify` returns two values: the substitution, and whether unification
succeeded. It never signals on a plain mismatch — it returns `(values nil nil)`
— so the caller decides what a failure means.

```lisp
(type-unify *a* (parse-type-specifier '(function (integer) string)))
; => #S(SUBSTITUTION ...), T
```

## 5. Apply the substitution

The substitution is not applied in place. `apply-unification` walks a type and
replaces every variable the substitution binds.

```lisp
(multiple-value-bind (subst ok)
    (type-unify *a* (parse-type-specifier '(function (integer) string)))
  (when ok
    (unparse-type (apply-unification *a* subst))))
; => (-> FIXNUM STRING)
```

## The whole thing

```lisp
(asdf:load-system "cl-cc-type")

(let* ((var (cl-cc/type:fresh-type-var :name 'a))
       (arrow (cl-cc/type:parse-type-specifier '(function (integer) string))))
  (multiple-value-bind (subst ok) (cl-cc/type:type-unify var arrow)
    (if ok
        (cl-cc/type:unparse-type (cl-cc/type:apply-unification var subst))
        (error "no unifier"))))
; => (-> FIXNUM STRING)
```

## Two more things worth trying

`subtypep` answers the subtype question over the compiler's lattice, returning
the same `(values answer certain-p)` shape as `cl:subtypep`. It accepts either
type nodes or specifiers.

```lisp
(subtypep 'integer 'number)  ; => T, T
(subtypep 'string 'integer)  ; => NIL, T
(unparse-type (type-join (parse-type-specifier 'integer)
                         (parse-type-specifier 'float)))
; => REAL
```

`check-typecase-exhaustiveness` reports coverage and unreachable arms for a
list of arm type names, where `t` is the catch-all.

```lisp
(check-typecase-exhaustiveness '(integer string))
; => NIL, NIL, NIL

(check-typecase-exhaustiveness '(number integer t))
; => T, (1), ("arm 1 (INTEGER): unreachable — subsumed by earlier arm")
```

## Where to go next

- [Core Concepts](core-concepts.md) — what a substitution and an environment are.
- [API Reference](api-reference.md) — the rest of the exported symbols.
