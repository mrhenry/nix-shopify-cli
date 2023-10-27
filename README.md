# Shopify CLI packaged for Nix

This is the [shopify-cli](https://github.com/Shopify/cli) packaged for Nix.

## Current version

The current version is [`3.50.0`](https://github.com/Shopify/cli/releases/tag/3.50.0).

## Installation

```sh
nix profile install github:mrhenry/nix-shopify-cli
```

Alternatively you can just run the CLI directly without permanently installing it:

```sh
nix run github:mrhenry/nix-shopify-cli -- <args>
```

# Usage as a flake

[![FlakeHub](https://img.shields.io/endpoint?url=https://flakehub.com/f/mrhenry/nix-shopify-cli/badge)](https://flakehub.com/flake/mrhenry/nix-shopify-cli)

Add nix-shopify-cli to your `flake.nix`:

```nix
{
  inputs.nix-shopify-cli.url = "https://flakehub.com/f/mrhenry/nix-shopify-cli/*.tar.gz";

  outputs = { self, nix-shopify-cli }: {
    # Use in your outputs
  };
}

```


## Supported Systems

- `x86_64-linux`
- `x86_64-darwin`
- `aarch64-linux`
- `aarch64-darwin`

## Build

```sh
nix build
nix flake check
```

## How to build a new version of `shopify`

1. Update the `package.json` with the new version
2. Run `npm install && rm -rf node_modules` (we only care about the lock file).
3. Run `nix build`, Nix will complain that the download hash is outdated.
4. Update `downloadHash` in `default.nix` with the new hash.
5. Run `nix build` again, now it should build the new version.
6. Run `nix run -- <some args>` to test the new version.

When you are happy with the new version, push it to cachix for all supported systems and
create a new release branch named `release-v<version>`.
