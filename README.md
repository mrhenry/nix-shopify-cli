# Shopify CLI packaged for Nix

This is the [shopify-cli](https://github.com/Shopify/cli) packaged for Nix.

## Current version

The current version is [`3.46.5`](https://github.com/Shopify/cli/releases/tag/3.46.5).

## Installation

```sh
nix profile install github:mrhenry/nix-shopify-cli
```

Alternatively you can just run the CLI directly without permanently installing it:

```sh
nix run github:mrhenry/nix-shopify-cli -- <args>
```

# Supported Systems

- `x85_64-linux`
- `x86_64-darwin`
- `aarch64-linux`
- `aarch64-darwin`

# Build and push to cachix

```sh
nix build --json \
  | jq -r '.[].outputs | to_entries[].value' \
  | cachix push nix-shopify-cli
```

# How to enable the binary cache

```sh
# On MacOS
echo "trusted-users = root $USER" | sudo tee -a /etc/nix/nix.conf;
sudo launchctl stop org.nixos.nix-daemon;
sudo launchctl start org.nixos.nix-daemon;
```
