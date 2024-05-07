{ buildNpmPackage, lib, makeWrapper, cli-ruby, version }:
buildNpmPackage {
  pname = "shopify";
  version = version;

  src = lib.fileset.toSource {
    root = ./.;
    fileset = with lib.fileset; unions [
      ./package.json
      ./package-lock.json
    ];
  };

  npmDepsHash = import ./cli-node-deps.nix;
  dontNpmBuild = true;

  buildInputs = [ makeWrapper ];

  postInstall = ''
    wrapProgram $out/bin/shopify \
      --set SHOPIFY_RUBY_BINDIR  ${cli-ruby.wrappedRuby}/bin \
      --set SHOPIFY_CLI_2_0_DIRECTORY ${cli-ruby}/lib/cli-ruby
  '';
}
