{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  nixConfig = {
    extra-substituters = [ "https://nix-shopify-cli.cachix.org" ];
    extra-trusted-public-keys = [
      "nix-shopify-cli.cachix.org-1:2t1aaompA/uulhaYDH/WXx+4n4IyZTv9r/zlOlyerFw="
    ];
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
      }
    );
}
