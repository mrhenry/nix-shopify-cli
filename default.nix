{ pkgs, system }:
let
  # read the package version
  packageJSON = builtins.fromJSON (builtins.readFile ./package.json);
  version = packageJSON.dependencies."@shopify/cli";

  # This needs to be updated every time the package closure is changed
  downloadHash = "sha256-uwtVPz1MNVpNElZ0vR4DcBqrA4l32YsnbmIGlO/bVb0=";

  # Download but don't install/build the package dependencies
  # The output hash should be stable across diferent platforms/systems
  download = pkgs.stdenv.mkDerivation {
    pname = "shopify-download";
    version = version;

    # Give network access but check the hash of the output
    outputHashMode = "recursive";
    outputHashAlgo = "sha256";
    outputHash = downloadHash;

    nativeBuildInputs = [ pkgs.nodejs pkgs.ruby ];

    src = pkgs.lib.cleanSource ./.;

    buildPhase = ''
      # Make npm happy
      export HOME=$TMPDIR

      # Install the npm dependencies but don't run any build scripts
      npm ci --ignore-scripts

      # Cache the ruby dependencies
      cd node_modules/@shopify/cli-kit/assets/cli-ruby
      bundle config set --local without development:test
      bundle config set --local force_ruby_platform true
      # bundle lock --add-platform x86_64-linux
      # bundle lock --add-platform x86_64-darwin
      # bundle lock --add-platform arm-linux
      # bundle lock --add-platform arm-darwin
      # bundle lock --add-platform universal-darwin
      bundle cache --no-install
      cd -
    '';

    installPhase = ''
      mkdir -p $out
      cp --reflink=auto ./package.json $out/package.json
      cp --reflink=auto ./package-lock.json $out/package-lock.json
      cp --reflink=auto -r node_modules $out/node_modules
    '';

    # Don't fixup the output as that would make the output system dependent
    dontFixup = true;
  };

  build = pkgs.stdenv.mkDerivation {
    pname = "shopify";
    version = version;

    src = download;

    buildInputs = [ pkgs.nodejs pkgs.ruby pkgs.makeWrapper ] ++ pkgs.lib.optional pkgs.stdenv.isDarwin [ pkgs.libiconv ];

    buildPhase = ''
      # Make npm happy
      export HOME=$TMPDIR

      # Build any native npm dependencies
      npm rebuild

      # Install the ruby dependencies
      mkdir gems
      LOCAL_GEMS_PATH=$PWD/gems
      cd node_modules/@shopify/cli-kit/assets/cli-ruby
      bundle config set --local path $LOCAL_GEMS_PATH
      bundle config set --local without development:test
      bundle install --local
      bundle config set --local path ${placeholder "out"}/gems
      cd -

      # Make sure shopify doesn't try to install the ruby dependencies
      substituteInPlace node_modules/@shopify/cli-kit/dist/public/node/ruby.js \
        --replace "await installCLIDependencies" "// await installCLIDependencies"
    '';

    installPhase = ''
      mkdir -p $out
      cp --reflink=auto ./package.json $out/package.json
      cp --reflink=auto ./package-lock.json $out/package-lock.json
      cp --reflink=auto -r node_modules $out/node_modules
      cp --reflink=auto -r gems $out/gems

      # Make sure the shopify binary can find the ruby dependencies
      makeWrapper $out/node_modules/.bin/shopify $out/bin/shopify \
        --prefix PATH : ${placeholder "out"}/gems/ruby/3.1.0/bin \
        --prefix PATH : ${pkgs.nodejs}/bin \
        --prefix PATH : ${pkgs.ruby}/bin \
        --prefix PATH : ${pkgs.git}/bin
    '';
  };
in
build
