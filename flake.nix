{
  description = "cl-cc type system — kinds, multiplicity, HM inference, type classes, effects";

  inputs = {
    # nixos-unstable, not nixpkgs-unstable: it advances only after the NixOS
    # release tests pass, so it is less likely to land a broken build.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # cl-cc-ast and cl-weave are consumed purely as raw ASDF source trees
    # (buildASDFSystem `src`, or CL_SOURCE_REGISTRY at runtime); this flake
    # never touches their own packages/checks outputs. `flake = false` fetches
    # just the source, so their dev-only inputs never enter this lock file.
    #
    # That is also why these two carry no `inputs.nixpkgs.follows`. The org
    # standard mandates it so that an input cannot drag in a second nixpkgs,
    # but a `flake = false` input has no inputs of its own to redirect: Nix
    # answers the line with `warning: input 'cl-cc-ast' has an override for a
    # non-existent input 'nixpkgs'` on every command. treefmt-nix below is the
    # one real flake input here, and it does carry it.
    #
    # cl-cc-ast is pinned to a commit, not a tag, because it has no tags at
    # all. That is not a licence to write a bare `github:nerima-lisp/cl-cc-ast`:
    # a bare reference follows the default branch, so an upstream push would
    # break this repo's CI without warning. A commit pin is as immutable as a
    # tag, just less legible. Replace it with `/v0.1.0` as soon as cl-cc-ast
    # cuts its first release.
    cl-cc-ast = {
      url = "github:nerima-lisp/cl-cc-ast/e88efda6430e82bd9e93b9a033f114c88d17cb0a";
      flake = false;
    };

    # Test-only: cl-weave is the org's test framework. Pinned to its release
    # tag, which is what every other repository in the org references.
    cl-weave = {
      url = "github:nerima-lisp/cl-weave/v1.0.0";
      flake = false;
    };

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      cl-cc-ast,
      cl-weave,
      treefmt-nix,
      ...
    }:
    let
      # Only platforms that something actually verifies are declared.
      # x86_64-linux is what the CI runner builds; aarch64-darwin is the
      # development machine, so every local `nix flake check` exercises it.
      # aarch64-linux and x86_64-darwin used to be listed here and were checked
      # by nobody. See ADR-0078.
      systems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;

      # CL_SOURCE_REGISTRY for the checks, the test app and the devShell.
      sourceRegistry = "${cl-cc-ast}//:${cl-weave}//:${self}//";

      # Reads the first `:version` form out of an ASDF system definition. Nix
      # regexes are whole-string anchored and `.` never spans newlines, so the
      # file is split into lines and matched line by line rather than with one
      # multi-line match.
      asdVersion =
        asd:
        let
          lines = nixpkgs.lib.splitString "\n" (builtins.readFile asd);
          versionLine = builtins.head (
            builtins.filter (line: builtins.match "[[:space:]]*:version \"[^\"]*\"" line != null) lines
          );
        in
        builtins.head (builtins.match "[[:space:]]*:version \"([^\"]*)\"" versionLine);

      # Single source of truth for the version: the `:version` form in
      # cl-cc-type.asd. A release edits that one line and every Nix package
      # (default + docs) follows. release.yml refuses a tag that disagrees
      # with it.
      version = asdVersion ./cl-cc-type.asd;

      # The sibling's version is read out of its own .asd for the same reason:
      # a hardcoded copy here duplicates a fact that lives upstream and goes
      # stale without anything noticing.
      clCcAstVersion = asdVersion "${cl-cc-ast}/cl-cc-ast.asd";

      # treefmt drives `nix fmt` and the `checks.<system>.formatting` gate.
      # Scope is Nix only: nixfmt is a low-diff, zero-footgun formatter,
      # whereas a YAML formatter mangles the GitHub Actions `on:` key and
      # Markdown reformatting would churn the whole docs tree.
      treefmtEval = forAllSystems (
        system:
        treefmt-nix.lib.evalModule nixpkgs.legacyPackages.${system} {
          projectRootFile = "flake.nix";
          programs.nixfmt.enable = true;
        }
      );

      # The suite compiles 64 source files and runs 884 cases, so it gets a
      # far longer budget than the org template's 120s. The timeout is still
      # there to turn a deadlocked test into a failed build rather than a
      # six-hour CI job.
      testTimeout = 1200;
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          clCcAst = pkgs.sbcl.buildASDFSystem {
            pname = "cl-cc-ast";
            version = clCcAstVersion;
            src = cl-cc-ast;
            systems = [ "cl-cc-ast" ];
          };
        in
        rec {
          cl-cc-type = pkgs.sbcl.buildASDFSystem {
            pname = "cl-cc-type";
            inherit version;
            src = self;
            systems = [ "cl-cc-type" ];
            lispLibs = [ clCcAst ];
          };
          default = cl-cc-type;

          # Rendered documentation site (Material for MkDocs).
          # Build fully offline: Material for MkDocs bundles all of its assets,
          # so no network access is required inside the Nix sandbox. --strict
          # promotes broken links and unlisted pages to build failures.
          #
          # The source root is the repository, not ./docs, because
          # docs/src/changelog.md pulls in the root CHANGELOG.md through
          # pymdownx.snippets, and mkdocs is invoked from the root so that the
          # snippet base_path of "." resolves there.
          docs = pkgs.stdenvNoCC.mkDerivation {
            pname = "cl-cc-type-docs";
            inherit version;
            src = pkgs.lib.fileset.toSource {
              root = ./.;
              fileset = pkgs.lib.fileset.unions [
                ./docs/mkdocs.yml
                ./docs/src
                ./CHANGELOG.md
              ];
            };
            nativeBuildInputs = [ pkgs.python3Packages.mkdocs-material ];
            buildPhase = ''
              runHook preBuild
              mkdocs build --strict --config-file docs/mkdocs.yml --site-dir "$out"
              runHook postBuild
            '';
            dontInstall = true;
            meta = {
              description = "Rendered MkDocs (Material) documentation for cl-cc-type";
              homepage = "https://github.com/nerima-lisp/cl-cc-type";
              license = pkgs.lib.licenses.mit;
            };
          };
        }
      );

      # `nix fmt` entry point.
      formatter = forAllSystems (system: treefmtEval.${system}.config.build.wrapper);

      # Granularity lives here, NOT in extra GitHub Actions jobs: `nix flake
      # check` evaluates each attribute as its own derivation, in parallel,
      # with build caching. Add a check here rather than a job in ci.yml.
      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default =
            pkgs.runCommand "cl-cc-type-tests"
              {
                nativeBuildInputs = [
                  pkgs.sbcl
                  pkgs.coreutils
                ];
                CL_SOURCE_REGISTRY = sourceRegistry;
              }
              ''
                export HOME="$TMPDIR/home"
                mkdir -p "$HOME" "$out"
                timeout ${toString testTimeout} sbcl --script ${self}/run-tests.lisp
                touch "$out/passed"
              '';

          # Fails `nix flake check` when any tracked Nix file is unformatted,
          # turning the formatter into an enforced CI gate rather than a habit.
          formatting = treefmtEval.${system}.config.build.check self;

          # packages.docs runs `mkdocs build --strict`, so a broken link or a
          # page missing from the nav fails here. Without this check the site
          # is only ever built by docs.yml, which runs after a merge to main —
          # so a break would surface as a failed deploy rather than as a failed
          # pull request.
          docs = self.packages.${system}.docs;
        }
      );

      apps = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          test = pkgs.writeShellApplication {
            name = "cl-cc-type-test";
            runtimeInputs = [
              pkgs.sbcl
              pkgs.coreutils
            ];
            text = ''
              export CL_SOURCE_REGISTRY="${sourceRegistry}"
              exec timeout ${toString testTimeout} sbcl --script ${self}/run-tests.lisp
            '';
          };
        in
        {
          default = {
            type = "app";
            program = "${test}/bin/cl-cc-type-test";
          };
          test = {
            type = "app";
            program = "${test}/bin/cl-cc-type-test";
          };
        }
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            packages = [ pkgs.sbcl ];
            CL_SOURCE_REGISTRY = sourceRegistry;
          };
        }
      );
    };
}
