# cl-cc-type

[![CI](https://github.com/nerima-lisp/cl-cc-type/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/nerima-lisp/cl-cc-type/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Documentation](https://img.shields.io/badge/docs-MkDocs%20Material-0a7a5a)](https://nerima-lisp.github.io/cl-cc-type/)

The type system of the [cl-cc](https://github.com/nerima-lisp/cl-cc) Common
Lisp compiler, as a standalone SBCL system: kinds, multiplicity,
Hindley–Milner inference with rank-N and bidirectional checking, type classes,
algebraic effects, row polymorphism, subtyping, and `typecase` exhaustiveness
checking. Everything is exported from the `cl-cc/type` package. Its one
org-internal dependency is [cl-cc-ast](https://github.com/nerima-lisp/cl-cc-ast),
used through its public API for the AST nodes that inference walks.

Full documentation is published at <https://nerima-lisp.github.io/cl-cc-type/>.
The source for that site lives in [docs/src/](docs/src/).

## Quick Start

```lisp
(asdf:load-system "cl-cc-type")

(let* ((var (cl-cc/type:fresh-type-var :name 'a))
       (arrow (cl-cc/type:parse-type-specifier '(function (integer) string))))
  (multiple-value-bind (subst ok) (cl-cc/type:type-unify var arrow)
    (and ok (cl-cc/type:unparse-type (cl-cc/type:apply-unification var subst)))))
;; => (-> FIXNUM STRING)
```

## Install

```nix
# flake.nix
inputs.cl-cc-type = {
  url = "github:nerima-lisp/cl-cc-type/v0.2.0";
  flake = false;
};
```

Note the pinned tag. Consumers inside this org must pin a release tag rather
than follow the default branch. See
[Installation](https://nerima-lisp.github.io/cl-cc-type/installation/) for the
`cl-cc-ast` side of the setup and for the non-Nix path.

## Documentation

- [Quick Start](https://nerima-lisp.github.io/cl-cc-type/quick-start/)
- [Core Concepts](https://nerima-lisp.github.io/cl-cc-type/core-concepts/)
- [API Reference](https://nerima-lisp.github.io/cl-cc-type/api-reference/)
- [Development](https://nerima-lisp.github.io/cl-cc-type/development/)

## Development

```sh
nix develop          # SBCL with CL_SOURCE_REGISTRY already set
nix run .#test       # run the test suite
nix flake check      # tests + formatting + docs + paredit lint, the same gate CI uses
nix fmt              # format Nix sources (treefmt)
nix build .#coverage # SB-COVER report (result/cover-index.html)
```

Tests live in `t/` and run under
[cl-weave](https://github.com/nerima-lisp/cl-weave), the org's test framework.
Six test files from the monorepo are absent because they need the compiler's
not-yet-extracted parse stage; see
[Development](https://nerima-lisp.github.io/cl-cc-type/development/#tests-that-did-not-come-across)
for which and why.

## Contributing

See the org-wide [CONTRIBUTING](https://github.com/nerima-lisp/.github/blob/main/CONTRIBUTING.md)
guide and the [package standard](https://github.com/nerima-lisp/.github/blob/main/PACKAGE_STANDARD.md).

## Support

See [SUPPORT](https://github.com/nerima-lisp/.github/blob/main/SUPPORT.md).

## License

MIT. See [LICENSE](LICENSE).
