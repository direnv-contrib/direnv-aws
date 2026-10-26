{
  description = "direnv-aws - direnv extensions for AWS Secrets Manager and SSM Parameter Store";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      nixpkgs,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        # The helpers are sourced by direnv, so the package only ships the scripts
        packages.default = pkgs.stdenvNoCC.mkDerivation {
          pname = "direnv-aws";
          version = pkgs.lib.removeSuffix "\n" (builtins.readFile ./version.txt);
          src = pkgs.lib.cleanSource ./.;
          dontBuild = true;
          installPhase = ''
            runHook preInstall
            install -Dm644 -t $out/share/direnv-aws lib/*.sh
            runHook postInstall
          '';
          meta = with pkgs.lib; {
            description = "direnv extensions for AWS Secrets Manager and SSM Parameter Store";
            homepage = "https://github.com/direnv-contrib/direnv-aws";
            license = licenses.mit;
            platforms = platforms.all;
          };
        };

        devShells.default = pkgs.mkShell {
          name = "direnv-aws";
          packages = with pkgs; [
            bash
            bats
            direnv
            jq
            shellcheck
            awscli2
          ];
        };
      }
    );
}
