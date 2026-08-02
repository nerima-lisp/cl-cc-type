{
  description = "cl-cc type system — kinds, multiplicity, HM inference, type classes, effects";

  inputs = {
    # nixos-unstable, not nixpkgs-unstable: it advances only after the NixOS
    # release tests pass, so it is less likely to land a broken build.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # cl-cc-ast and cl-weave are consumed purely as raw ASDF source trees
    # (`cl.lispDerivation`'s `src`, or CL_SOURCE_REGISTRY at runtime); this
    # flake never touches their own packages/checks outputs. `flake = false`
    # fetches just the source, so their dev-only inputs never enter this lock
    # file.
    #
    # That is also why these two carry no `inputs.nixpkgs.follows`. The org
    # standard mandates it so that an input cannot drag in a second nixpkgs,
    # but a `flake = false` input has no inputs of its own to redirect: Nix
    # answers the line with `warning: input 'cl-cc-ast' has an override for a
    # non-existent input 'nixpkgs'` on every command. cl-nix-forge and
    # treefmt-nix below are real flake inputs, and both carry it.
    #
    # cl-cc-ast cut its first tag (v0.1.0); DEPENDENCY_POLICY.md requires
    # sibling references to track a release tag rather than a bare commit, so
    # this follows suit instead of staying pinned to the pre-release commit.
    # v0.2.0 is backward-compatible (its closure-analysis CPS conversion adds
    # an optional continuation defaulting to #'identity); cl-cc-type only
    # consumes cl-cc-ast's AST node structs/accessors, not that module, so
    # there is nothing here for the new continuation parameter to affect.
    cl-cc-ast = {
      url = "github:nerima-lisp/cl-cc-ast/v0.2.0";
      flake = false;
    };

    # Test-only: cl-weave is the org's test framework. Pinned to its release
    # tag, which is what every other repository in the org references.
    cl-weave = {
      url = "github:nerima-lisp/cl-weave/v1.1.4";
      flake = false;
    };

    # Test-only: inference-tests.lisp and its four siblings build their input
    # ASTs with cl-cc/parse:lower-sexp-to-ast, so cl-cc-type/test needs
    # cl-cc-parse on the registry the same way it needs cl-cc-ast and
    # cl-weave; the "cl-cc-type" library system itself never depends on it
    # (see cl-cc-type.asd). cl-cc-parse had no tagged release when this was
    # written, so v0.1.0 was cut on its then-HEAD
    # (7316dd82137290082fa1fe03300d3aa388d84117) specifically so this could
    # follow DEPENDENCY_POLICY.md's "pin to a release tag, not a bare commit"
    # rule instead of being the one exception to it.
    cl-cc-parse = {
      url = "github:nerima-lisp/cl-cc-parse/v0.1.0";
      flake = false;
    };

    # Test-only, transitively: cl-cc-parse.asd itself depends on
    # cl-cc-bootstrap (pre-interned bootstrap symbols and the backend
    # registration protocol), so it must be on the registry wherever
    # cl-cc-parse is loaded from a raw source tree, exactly as cl-cc-parse's
    # own flake.nix wires it. Pinned to cl-cc-bootstrap's v0.1.0 release tag.
    cl-cc-bootstrap = {
      url = "github:nerima-lisp/cl-cc-bootstrap/v0.1.0";
      flake = false;
    };

    # The org flake preset. Everything this file used to spell out by hand —
    # `.asd` version extraction, `forAllSystems`, the treefmt eval wired to
    # both `formatter` and `checks.formatting`, the mkdocs package plus its
    # check, the run-tests.lisp gate, the `apps.test`/`apps.default` pair, the
    # devShell and the overlay — is one `mkPackageFlake` call below. Pinned to
    # a release TAG: a bare `github:nerima-lisp/cl-nix-forge` follows that
    # repository's default branch and would change this build without
    # warning. cl-weave itself already migrated to this preset (v0.3.0); this
    # follows its lead at the newer v0.4.0.
    cl-nix-forge = {
      url = "github:nerima-lisp/cl-nix-forge/v0.4.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Structure-editing lint gate for Lisp sources, wired the same way
    # cl-weave wires it: `paredit-cli.lib.${system}.mkLintCheck` as a
    # `checks.paredit-lint` entry, so a logic-bug lint finding fails
    # `nix flake check` instead of staying an ad hoc local invocation. Pinned
    # to its latest release tag (v1.3.0) — cl-weave's own flake.nix leaves
    # this one input following `takeokunn/paredit-cli`'s default branch, which
    # is the exact "a push upstream changes your build without warning" risk
    # every other input in this file is pinned specifically to avoid;
    # inherited from that reference rather than caught the first time, fixed
    # here instead of carried forward.
    paredit-cli = {
      url = "github:takeokunn/paredit-cli/v1.3.0";
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

      # x86_64-linux is what CI gates; aarch64-darwin is the development
      # machine. Every per-system output -- packages, checks, apps AND devShells
      # -- comes from this one list, so leaving aarch64-darwin out takes `nix
      # build` and `nix develop` off the development machine as well. That trade
      # was made on 2026-08-01 and reverted on 2026-08-02; aarch64-darwin carries
      # no CI gate, which PACKAGE_STANDARD.md's "systems" section accepts
      # explicitly. aarch64-linux and x86_64-darwin are nobody's verification and
      # are not declared.
      systems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];

      # The suite runs 1155 cases across 65 source files and 65 test files
      # (oversized files were split to keep every t/ file under
      # CODING_STANDARD.md's 500-line cap), so it gets a far longer budget
      # than the org template's 120s. The timeout is still there to turn a
      # deadlocked test into a failed build rather than a six-hour CI job.
      # Also the coverage report's budget: `mkCoverageReport` force-recompiles
      # the whole system under SB-COVER instrumentation, which is slower than
      # the plain test run this timeout was sized for.
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

      # `lispDependencies` is what `packages.cl-cc-type` itself needs to load
      # (cl-cc-type.asd's `:depends-on ("cl-cc-ast")`); `lispCheckDependencies`
      # is what only the `/test` system needs (cl-weave), so it stays off the
      # library's own registry and reaches the check derivation and the
      # generated devShell only. Both are built directly from the fetched
      # `flake = false` source, mirroring cl-nix-forge's own org-preset
      # example (`support`/`harness`) for exactly this "sibling repository
      # consumed as a raw source tree" shape — neither cl-cc-ast nor cl-weave
      # publishes its own flake, so there is no `packages.default` here to
      # `collect` instead.
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

      # ONE treefmt evaluation drives `nix fmt` and the `checks.formatting`
      # gate, so the formatter and the CI gate can never disagree about what
      # "formatted" means. Scope stays the preset's Nix-only default: nixfmt
      # is a low-diff, zero-footgun formatter, whereas a YAML formatter
      # mangles the GitHub Actions `on:` key and reformatting Markdown would
      # churn the whole docs tree.
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
          # Verified clean before being wired here (`paredit inspect lint`,
          # 0 findings across every src/ and t/ file) — a lint gate that
          # starts red would train contributors to ignore it.
          paredit-lint = paredit-cli.lib.${ctx.system}.mkLintCheck {
            inherit (ctx) src;
            name = "cl-cc-type-paredit-lint";
          };
        };
      };
    };
}
