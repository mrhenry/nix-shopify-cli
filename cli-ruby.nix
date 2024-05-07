{ fetchFromGitHub, bundlerEnv, runCommandNoCC, version }:

let

  src = fetchFromGitHub {
    owner = "Shopify";
    repo = "cli";
    rev = version;
    hash = import ./cli-ruby-src.nix;
  };

  gems = bundlerEnv {
    name = "shopify-cli";
    gemdir = src + "/packages/cli-kit/assets/cli-ruby";
    gemset = ./cli-ruby-gemset.nix;
  };

  cli = runCommandNoCC "shopify-cli"
    {
      buildInputs = [ gems gems.wrappedRuby ];
      src = src;

      passthru = {
        wrappedRuby = gems.wrappedRuby;
        source = src + "/packages/cli-kit/assets/cli-ruby";
      };
    }
    ''
      set -e
      set -o pipefail

      mkdir -p $out/bin
      mkdir -p $out/lib

      cp -r $src/packages/cli-kit/assets/cli-ruby $out/lib/
      ln -s $out/lib/cli-ruby/bin/shopify $out/bin/shopify
    '';

in
cli
