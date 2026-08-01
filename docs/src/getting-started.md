# Getting Started

cl-cc-type targets SBCL and is distributed as an ASDF system. It has one
dependency, [cl-cc-ast](https://github.com/nerima-lisp/cl-cc-ast).

## With Nix

Add the input to your `flake.nix`. Inside this org, pin a release tag rather
than following the default branch: a bare `github:nerima-lisp/cl-cc-type`
tracks `main`, so an upstream push breaks your build without warning.

```nix
inputs.cl-cc-type = {
  url = "github:nerima-lisp/cl-cc-type/v0.2.0";
  flake = false;
};
```

`flake = false` fetches the source tree only. That is what the org's other
packages do for their siblings: the consumer wants the ASDF source, not this
repository's own `packages` and `checks` outputs.

Put the fetched trees on the source registry, together with `cl-cc-ast`:

```nix
CL_SOURCE_REGISTRY = "${cl-cc-ast}//:${cl-cc-type}//:${self}//";
```

Or build it as a Lisp library and depend on the derivation, with nixpkgs' own
builder:

```nix
clCcType = pkgs.sbcl.buildASDFSystem {
  pname = "cl-cc-type";
  version = "0.2.0";
  src = cl-cc-type;
  systems = [ "cl-cc-type" ];
  lispLibs = [ clCcAst ];
};
```

Or, since this repository's own `flake.nix` is now built with
[cl-nix-forge](https://github.com/nerima-lisp/cl-nix-forge), reference the
package it already publishes instead of rebuilding it — `flake = true` here,
deliberately unlike the `cl-cc-ast` input above, precisely because there is a
`packages.default` to take:

```nix
inputs.cl-cc-type.url = "github:nerima-lisp/cl-cc-type/v0.2.0";
# ...
lispDependencies = ctx: [ cl-cc-type.packages.${ctx.system}.default ];
```

## Without Nix

Clone both repositories next to each other and point ASDF at them:

```sh
git clone https://github.com/nerima-lisp/cl-cc-ast.git
git clone https://github.com/nerima-lisp/cl-cc-type.git
export CL_SOURCE_REGISTRY="$PWD/cl-cc-ast//:$PWD/cl-cc-type//"
```

## Depending on it from an .asd

```lisp
(defsystem "your-system"
  :depends-on ("cl-cc-type")
  ...)
```

## Verifying the installation

```lisp
(asdf:load-system "cl-cc-type")

(cl-cc/type:unparse-type (cl-cc/type:parse-type-specifier 'integer))
; => INTEGER
```

If `asdf:load-system` signals `Component "cl-cc-ast" not found`, the source
registry does not cover the `cl-cc-ast` checkout. Print what ASDF is actually
searching with `(asdf:*source-registry-parameter*)`.

## One task end to end

The rest of this page walks one task: take a Lisp type specifier, unify it
against a type variable, and read the answer back out as a specifier. Every
output below is copied from a real session.

```lisp
(asdf:load-system "cl-cc-type")
(in-package :cl-cc/type)
```

The examples use `in-package` rather than qualifying every call, because the
sequence below touches a dozen symbols. In your own code, prefer
`cl-cc/type:parse-type-specifier` and friends — the package shadows four
`common-lisp` symbols, so `:use`-ing it needs a deliberate decision. See
[Core Concepts](guide/core-concepts.md#system-name-and-package-name).

### 1. Parse a specifier into a type node

`parse-type-specifier` turns the s-expression surface syntax into the internal
representation.

```lisp
(parse-type-specifier '(function (integer) string))
; => #S(TYPE-ARROW ...)
```

### 2. Print it back

`unparse-type` is the inverse. It is the readable way to inspect any result.

```lisp
(unparse-type (parse-type-specifier '(function (integer) string)))
; => (-> FIXNUM STRING)
```

Two things to notice. Arrows print in the compiler's own `->` syntax rather
than `common-lisp`'s `function`, and `integer` came back as `fixnum`: `FIXNUM`,
`INTEGER` and `INT` are three spellings of one primitive type, and `FIXNUM` is
the canonical one. That is a normalisation, not a loss.

### 3. Make a fresh type variable

Inference works by generating variables and solving for them. `fresh-type-var`
allocates one with a globally increasing id.

```lisp
(defparameter *a* (fresh-type-var :name 'a))
```

### 4. Unify

`type-unify` returns two values: the substitution, and whether unification
succeeded. It never signals on a plain mismatch — it returns `(values nil nil)`
— so the caller decides what a failure means.

```lisp
(type-unify *a* (parse-type-specifier '(function (integer) string)))
; => #S(SUBSTITUTION ...), T
```

### 5. Apply the substitution

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

## Where to go next

- [Core Concepts](guide/core-concepts.md) — what a substitution and an
  environment are.
- [API Reference](reference/api.md) — the rest of the exported symbols.
- [Development](project/development.md) — build, test and coverage commands.
