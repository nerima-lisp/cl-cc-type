{
  description = "cl-cc type system — kinds, multiplicity, HM inference, type classes, effects";

  inputs = {
    # nixos-unstable, not nixpkgs-unstable: it advances only after the NixOS
    # release tests pass, so it is less likely to land a broken build.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # These dependencies are consumed as raw ASDF source trees. Disabling
    # their flakes keeps unrelated development inputs out of this lock file.
    cl-cc-ast = {
      url = "github:nerima-lisp/cl-cc-ast/a45c5acecfccb91a43f6a04251e8a5d6ec3d3213";
      flake = false;
    };

    # Test-only dependency for the org-based Lisp test suite.
    cl-weave = {
      url = "github:nerima-lisp/cl-weave/v1.4.0";
      flake = false;
    };

    # Test-only: inference tests use cl-cc-parse to construct their input ASTs.
    cl-cc-parse = {
      url = "github:nerima-lisp/cl-cc-parse/75d8699835731ec6ca44e15c82ef02601f5100fe";
      flake = false;
    };

    # Test-only: cl-cc-parse depends on bootstrap symbols and backend
    # registration.
    cl-cc-bootstrap = {
      url = "github:nerima-lisp/cl-cc-bootstrap/027f6c9826010c15789454e69abd2930738b50af";
      flake = false;
    };

    # Pin a release so changes to the upstream default branch cannot change
    # this build without warning.
    cl-nix-forge = {
      url = "github:nerima-lisp/cl-nix-forge/v0.5.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Pin the Lisp structure-editing lint tool to v1.3.0 so upstream branch
    # changes do not alter the check without warning.
    paredit-cli = {
      url = "github:nerima-lisp/paredit-cli/v1.3.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      cl-cc-ast,
      cl-weave,
      cl-cc-parse,
      cl-cc-bootstrap,
      cl-nix-forge,
      paredit-cli,
      treefmt-nix,
    }:
    let
      lib = nixpkgs.lib;

      # CI checks x86_64-linux as the supported system.
      systems = [ "x86_64-linux" ];

      # Bound the test run so a stalled suite fails instead of running forever.
      testTimeout = 1200;
    in
    # `mkPackageFlake` spans systems — it obtains a `pkgs` and its own
    # cl-nix-forge instance per entry in `systems` — so the per-system `lib`
    # instance this function is *taken from* contributes nothing but the
    # function itself.
    cl-nix-forge.lib.${builtins.head systems}.mkPackageFlake {
      inherit
        self
        systems
        nixpkgs
        ;
      pname = "cl-cc-type";

      # Single source of truth for the package version: the `:version` form in
      # cl-cc-type.asd. A release only ever edits the .asd file and every Nix
      # package (default + docs) follows automatically. release.yml refuses a
      # tag that disagrees with it.
      asd = ./cl-cc-type.asd;

      # Required, and it must be a path literal rather than `self`: a flake's
      # `self` is string-like and `lib.fileset` refuses it. `./.` is the same
      # directory as a path. `self` is still what the preset hands the treefmt
      # gate, which wants the unfiltered tree and takes a store path happily.
      root = ./.;

      meta = {
        description = "Common Lisp type system: type inference and checking, extracted from cl-cc";
        homepage = "https://github.com/nerima-lisp/cl-cc-type";
        license = lib.licenses.mit;
      };

      # Keep test-only dependencies out of the library's runtime registry.
      lispDependencies = ctx: [
        (ctx.cl.lispDerivation {
          lispSystem = "cl-cc-ast";
          version = ctx.cl.fromAsdSystem (cl-cc-ast + "/cl-cc-ast.asd");
          src = cl-cc-ast;
        })
      ];
      lispCheckDependencies = ctx: [
        (ctx.cl.lispDerivation {
          lispSystem = "cl-weave";
          version = ctx.cl.fromAsdSystem (cl-weave + "/cl-weave.asd");
          src = cl-weave;
        })
        (ctx.cl.lispDerivation {
          lispSystem = "cl-cc-bootstrap";
          version = ctx.cl.fromAsdSystem (cl-cc-bootstrap + "/cl-cc-bootstrap.asd");
          src = cl-cc-bootstrap;
        })
        (ctx.cl.lispDerivation {
          lispSystem = "cl-cc-parse";
          version = ctx.cl.fromAsdSystem (cl-cc-parse + "/cl-cc-parse.asd");
          src = cl-cc-parse;
          # This raw source tree is built in an isolated ASDF registry, so
          # cl-cc-parse must carry its direct ASDF dependencies itself.
          lispDependencies = [
            (ctx.cl.lispDerivation {
              lispSystem = "cl-cc-ast";
              version = ctx.cl.fromAsdSystem (cl-cc-ast + "/cl-cc-ast.asd");
              src = cl-cc-ast;
            })
            (ctx.cl.lispDerivation {
              lispSystem = "cl-cc-bootstrap";
              version = ctx.cl.fromAsdSystem (cl-cc-bootstrap + "/cl-cc-bootstrap.asd");
              src = cl-cc-bootstrap;
            })
          ];
        })
      ];

      # `checks.default` and `apps.test` are both run-tests.lisp, driven from
      # this one number, so the command a contributor runs by hand
      # (`nix develop`, then `sbcl --script run-tests.lisp`) and the gate CI
      # runs cannot drift apart.
      timeoutSeconds = testTimeout;

      # Rooted at the repository, not at ./docs, so the config path is the same
      # `docs/mkdocs.yml` a contributor types by hand. `mkDocsSite` builds with
      # `--strict`, so a broken link or a page missing from the nav fails the
      # build, and `checks.docs` runs it.
      docs = {
        root = ./.;
        fileset = lib.fileset.unions [
          ./docs/mkdocs.yml
          ./docs/src
        ];
        mkdocsYmlName = "docs/mkdocs.yml";
      };

      # Keep treefmt Nix-only: YAML formatting would rewrite GitHub Actions'
      # `on:` key, while formatting Markdown would churn the docs tree.
      treefmt.evalModule = treefmt-nix.lib.evalModule;

      # Granularity lives here, NOT in extra GitHub Actions jobs: `nix flake
      # check` evaluates each attribute as its own derivation, in parallel,
      # with build caching. Add a check here rather than a job in ci.yml.
      extraOutputs = ctx: {
        packages = {
          # A sandboxed SB-COVER report. Not part of `checks`:
          # docs/src/project/development.md documents coverage as a report, not a
          # ratchet, so it stays a `nix build`-only package rather than a
          # `nix flake check` gate. `.enableCheck` is required, not
          # `ctx.package`: run-tests.lisp needs cl-weave on the registry, and
          # only the check-enabled derivation resolves
          # `lispCheckDependencies`.
          coverage = ctx.cl.mkCoverageReport {
            drv = ctx.package.enableCheck;
            systems = [ "cl-cc-type" ];
          };
        };
        checks = {
          paredit-lint = paredit-cli.lib.${ctx.system}.mkLintCheck {
            inherit (ctx) src;
            name = "cl-cc-type-paredit-lint";
          };
        };
      };
    };
}
