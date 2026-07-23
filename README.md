# cl-cc-type

Type system for the [cl-cc](https://github.com/nerima-lisp/cl-cc) Common Lisp
compiler: kinds, multiplicity, Hindley–Milner inference, type classes, effects,
row types, subtyping, and exhaustiveness checking (the `:cl-cc/type` package).

Extracted from the cl-cc monorepo as part of the repository split (see
`docs/repo-split-design.md` in cl-cc). It depends on
[cl-cc-ast](https://github.com/nerima-lisp/cl-cc-ast) through its **public API
only** — AST accessors referenced during constraint collection and inference.

## Status

Extracted and building standalone against cl-cc-ast. Test wiring (currently the
monorepo's `deftest` harness) is being migrated to cl-weave in a follow-up.

## Usage

```lisp
;; With cl-cc-ast on the ASDF source registry:
(asdf:load-system :cl-cc-type)
```

## Development

```bash
nix develop            # sbcl dev shell (CL_CC_AST_ROOT preset)
nix flake check        # compile check (loads :cl-cc-type against cl-cc-ast)
```

To run the check outside Nix, point `CL_CC_AST_ROOT` at a cl-cc-ast checkout:

```bash
CL_CC_AST_ROOT=../cl-cc-ast sbcl --script scripts/run-compile-check.lisp
```

## License

MIT — see [LICENSE](LICENSE).
