{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils } @ inputs:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        cli = import ./default.nix {
          inherit pkgs system;
        };
      in
      {
        checks = {
          bundle = cli;
          version = pkgs.testers.testVersion {
            package = cli;
            command = "shopify version";
          };
          themeCheckVersion = pkgs.testers.testVersion {
            package = cli;
            command = "HOME=/tmp shopify theme check --version";
            version = "1.15.0";
          };
        };

        packages.default = cli;

        devShells.default = pkgs.mkShell {
          buildInputs = [
            pkgs.nodejs
            pkgs.ruby
            (pkgs.writeShellScriptBin "do-release"
              ''
                nix flake check
                bare_version="$(nix run . -- version | ${pkgs.gnused}/bin/sed 's|Current Shopify CLI version: ||')"
                version="v$bare_version"

                ${pkgs.gh}/bin/gh release create "$version" \
                  --draft \
                  --target "$(${pkgs.git}/bin/git rev-parse HEAD)" \
                  --title "$version" \
                  --notes "Updated to version [\`$version\`](https://github.com/Shopify/cli/releases/tag/$bare_version)"
              '')
          ];
        };
      }
    );
}
