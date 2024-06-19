{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

        packageJSON = builtins.fromJSON (builtins.readFile ./package.json);
        version = packageJSON.dependencies."@shopify/cli";

        cli = self.packages.${system}.cli-node;
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
            version = "2.2.2";
          };
        };

        packages = {
          default = self.packages.${system}.cli-node;

          cli-node = pkgs.callPackage ./cli-node.nix { version = version; cli-ruby = self.packages.${system}.cli-ruby; };
          cli-ruby = pkgs.callPackage ./cli-ruby.nix { version = version; };
        };

        devShells.default = pkgs.mkShell {
          buildInputs = [
            (pkgs.writeShellScriptBin "update-hashes"
              ''
                set -e
                set -o pipefail

                ROOT=$PWD

                export PATH="${pkgs.jq}/bin:$PATH"
                export PATH="${pkgs.nodejs}/bin:$PATH"
                export PATH="${pkgs.bundix}/bin:$PATH"
                export PATH="${pkgs.prefetch-npm-deps}/bin:$PATH"
                export PATH="${pkgs.nix-prefetch-github}/bin:$PATH"

                npm update
                npm install
                rm -rf node_modules

                prefetch-npm-deps ./package-lock.json | jq -R . > $ROOT/cli-node-deps.nix

                nix-prefetch-github --rev ${version}  Shopify cli | jq .hash > $ROOT/cli-ruby-src.nix

                pushd $(nix eval .#cli-ruby.source | jq -r .)
                bundix --gemset=$ROOT/cli-ruby-gemset.nix
                popd
              '')
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
