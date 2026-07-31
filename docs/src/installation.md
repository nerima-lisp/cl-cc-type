# Installation

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

## A note on the package name

The system is `cl-cc-type`; the package it defines is `cl-cc/type`. The system
name follows the repository, and the package name follows the compiler's
internal namespace (`cl-cc/ast`, `cl-cc/type`, ...), which the repository split
did not rename.

`cl-cc/type` shadows four `common-lisp` symbols — `type-error`, `subtypep`,
`upgraded-array-element-type` and `upgraded-complex-part-type` — because it
defines compiler-domain versions of them. Do not `:use` the package from a
package that also `:use`s `common-lisp` without deciding which of the two you
want; qualify the calls or use `:shadowing-import-from`.
