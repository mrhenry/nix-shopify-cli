{ pkgs, system }:
let
  # read the package version
  packageJSON = builtins.fromJSON (builtins.readFile ./package.json);
  version = packageJSON.dependencies."@shopify/cli";

  # This needs to be updated every time the package closure is changed
  downloadHash = "sha256-aGC1unmcSULXLdu7uCugwVEp0wPUTm2zg2BZxfm33a4=";

  # Download but don't install/build the package dependencies
  # The output hash should be stable across diferent platforms/systems
  download = pkgs.stdenv.mkDerivation {
    pname = "shopify-download";
    version = version;

    # Give network access but check the hash of the output
    outputHashMode = "recursive";
    outputHashAlgo = "sha256";
    outputHash = downloadHash;

    nativeBuildInputs = [ pkgs.nodejs pkgs.ruby pkgs.curl pkgs.cacert ];

    src = pkgs.lib.cleanSource ./.;

    BUILD_VERSION = version;

    buildPhase = ''
      # Make npm happy
      export HOME=$TMPDIR

      # Install the npm dependencies but don't run any build scripts
      npm ci --ignore-scripts

      mkdir .bundle-path
      export BUNDLE_PATH=$PWD/.bundle-path
      export BUNDLE_WITHOUT=development:test

      # Cache the ruby dependencies
      cd node_modules/@shopify/cli-kit/assets/cli-ruby
      
      # Restore the Gemfile.lock from the source
      curl -L "https://github.com/Shopify/cli/raw/$BUILD_VERSION/packages/cli-kit/assets/cli-ruby/Gemfile.lock" > Gemfile.lock

      bundle config set --local force_ruby_platform true
      bundle config set --local frozen true
      bundle config set --local deployment true
      bundle cache --no-install

      # cleanup
      rm -rf vendor/bundle/ruby/3.1.0/gems/bundler-*
      rm -rf vendor/bundle/ruby/3.1.0/specifications/bundler-2.3.20.gemspec
      rm -rf vendor/bundle/ruby/3.1.0/bin/bundler
      rm -rf vendor/bundle/ruby/3.1.0/bin/bundle

      cd -
    '';

    installPhase = ''
      mkdir -p $out
      cp --reflink=auto ./package.json $out/package.json
      cp --reflink=auto ./package-lock.json $out/package-lock.json
      cp --reflink=auto -r node_modules $out/node_modules
      cp --reflink=auto -r .bundle-path $out/.bundle-path
    '';

    # Don't fixup the output as that would make the output system dependent
    dontFixup = true;
  };

  build = pkgs.stdenv.mkDerivation {
    pname = "shopify";
    version = version;

    src = download;

    nativeBuildInputs = [ pkgs.removeReferencesTo pkgs.makeWrapper ];
    buildInputs = [ pkgs.nodejs pkgs.ruby ] ++ pkgs.lib.optional pkgs.stdenv.isDarwin [ pkgs.libiconv ];

    buildPhase = ''
      # Make npm happy
      export HOME=$TMPDIR

      # Build any native npm dependencies
      npm rebuild

      # Install the ruby dependencies
      export BUNDLE_PATH=$PWD/.bundle-path
      export BUNDLE_WITHOUT=development:test
    
      cd node_modules/@shopify/cli-kit/assets/cli-ruby
      bundle install
      rm -rf vendor/bundle/ruby/*/gems/*/ext
      find "vendor/bundle/ruby" -type f -name "gem_make.out" -delete
      find "vendor/bundle/ruby" -type f -name "mkmf.log" -delete
      cd -

      # Make sure shopify doesn't try to install the ruby dependencies
      substituteInPlace node_modules/@shopify/cli-kit/dist/public/node/ruby.js \
        --replace "await installCLIDependencies" "// await installCLIDependencies" \
        --replace "BUNDLE_PATH: envPaths('shopify-gems').cache" "// BUNDLE_PATH: envPaths('shopify-gems').cache"
    '';

    installPhase = ''
      mkdir -p $out

      cp --reflink=auto ./package.json $out/package.json
      cp --reflink=auto ./package-lock.json $out/package-lock.json
      cp --reflink=auto -r node_modules $out/node_modules
      cp --reflink=auto -r .bundle-path $out/.bundle-path

      # Remove some bs files
      rm -rf $out/node_modules/lodash-es/flake.lock
      rm -rf $out/node_modules/lodash/flake.lock

      # Make sure the shopify binary can find the ruby dependencies
      makeWrapper $out/node_modules/.bin/shopify $out/bin/shopify \
        --prefix PATH : $out/.bundle-path/gems/ruby/3.1.0/bin \
        --prefix PATH : ${pkgs.nodejs}/bin \
        --prefix PATH : ${pkgs.ruby}/bin \
        --prefix PATH : ${pkgs.git}/bin \
        --set BUNDLE_PATH $out/.bundle-path
    '';

    passthru = {
      inherit download;
    };
  };
in
build
