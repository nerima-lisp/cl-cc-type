{
  description = "cl-cc-type: type system (kinds, inference, type classes, effects) for the cl-cc Common Lisp compiler";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    cl-cc-ast = {
      url = "github:nerima-lisp/cl-cc-ast";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      cl-cc-ast,
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      forAllSystems =
        function: nixpkgs.lib.genAttrs systems (system: function (import nixpkgs { inherit system; }));
    in
    {
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = [ pkgs.sbcl ];
          CL_CC_AST_ROOT = toString cl-cc-ast;
        };
      });

      formatter = forAllSystems (pkgs: pkgs.nixfmt-rfc-style);

      packages = forAllSystems (pkgs: {
        default = pkgs.stdenvNoCC.mkDerivation {
          pname = "cl-cc-type";
          version = "0.1.0";
          src = self;
          nativeBuildInputs = [ pkgs.sbcl ];
          buildPhase = ''
            export HOME="$TMPDIR/home"
            mkdir -p "$HOME"
            export CL_CC_AST_ROOT="${toString cl-cc-ast}"
            sbcl --noinform --non-interactive --script scripts/run-compile-check.lisp
          '';
          installPhase = ''
            mkdir -p "$out/share/common-lisp/source/cl-cc-type"
            cp -R . "$out/share/common-lisp/source/cl-cc-type"
          '';
          meta = {
            description = "cl-cc type system: kinds, HM inference, type classes, effects";
            homepage = "https://github.com/nerima-lisp/cl-cc-type";
            license = pkgs.lib.licenses.mit;
            platforms = pkgs.lib.platforms.unix;
          };
        };
      });

      checks = forAllSystems (pkgs: {
        compile = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
      });
    };
}
