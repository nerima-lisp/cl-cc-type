# cl-cc-type

Type system for the [cl-cc](https://github.com/nerima-lisp/cl-cc) Common Lisp
compiler: kinds, multiplicity, Hindley–Milner inference, type classes, effects,
row types, subtyping, and exhaustiveness checking (the `:cl-cc/type` package).

Extracted from the cl-cc monorepo as part of the repository split (see
`docs/repo-split-design.md` in cl-cc). It depends on
[cl-cc-ast](https://github.com/nerima-lisp/cl-cc-ast) through its **public API
only** — AST accessors referenced during constraint collection and inference.

## Status

Extracted and building standalone against cl-cc-ast. The test suite runs on
[cl-weave](https://github.com/nerima-lisp/cl-weave) (748 tests).

## Usage

```lisp
;; With cl-cc-ast on the ASDF source registry:
(asdf:load-system :cl-cc-type)
```

## Development

```bash
nix develop            # sbcl dev shell (CL_CC_AST_ROOT preset)
nix flake check        # compile check + test suite (against cl-cc-ast and cl-weave)
```

To run these outside Nix, point `CL_CC_AST_ROOT` at a cl-cc-ast checkout and
`CL_CC_TYPE_CL_WEAVE_ROOT` at a cl-weave checkout:

```bash
CL_CC_AST_ROOT=../cl-cc-ast \
  sbcl --noinform --script scripts/run-compile-check.lisp

CL_CC_AST_ROOT=../cl-cc-ast CL_CC_TYPE_CL_WEAVE_ROOT=../cl-weave \
  sbcl --noinform --script scripts/run-tests.lisp

# Coverage report (requires SBCL's sb-cover contrib; writes coverage/report/):
CL_CC_AST_ROOT=../cl-cc-ast CL_CC_TYPE_CL_WEAVE_ROOT=../cl-weave \
  sbcl --noinform --script scripts/run-coverage.lisp
```

## License

MIT — see [LICENSE](LICENSE).
