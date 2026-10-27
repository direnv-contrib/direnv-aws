# direnv-aws

> AWS for direnv — load Secrets Manager secrets and SSM Parameter Store parameters into your environment, authenticated through aws-vault.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE) [![CI](https://github.com/direnv-contrib/direnv-aws/actions/workflows/ci.yml/badge.svg)](https://github.com/direnv-contrib/direnv-aws/actions/workflows/ci.yml)

Stop copying secrets into `.env` files. `direnv-aws` adds two functions to your `.envrc`, `use_aws_secret` and `use_aws_param`, that read AWS Secrets Manager secrets and SSM Parameter Store parameters when you enter a directory and export them as environment variables. When `AWS_PROFILE` is set, the calls run through aws-vault, so the same profile your shell uses is the one that reads the secrets.

## Requirements

- [direnv](https://direnv.net) (`direnv`)
- [jq](https://jqlang.org) (`jq`)
- [AWS CLI v2](https://aws.amazon.com/cli/) (`aws`)
- [aws-vault](https://github.com/99designs/aws-vault) (`aws-vault`) — optional, for profile-based credentials

**macOS (Homebrew):**

```bash
brew install direnv jq awscli aws-vault
```

**Nix:**

```bash
nix profile install nixpkgs#direnv nixpkgs#jq nixpkgs#awscli2
```

## Installation

direnv loads every `*.sh` file in `~/.config/direnv/lib/` before it evaluates a `.envrc`, so installing means making the three files in `lib/` available there.

### Using Nix

Add the flake as an input:

```nix
inputs.direnv-aws.url = "github:direnv-contrib/direnv-aws";
```

With Home Manager, import the module and enable it. It sources the scripts from direnv's standard library, so `programs.direnv.enable` must be on as well:

```nix
imports = [ inputs.direnv-aws.homeManagerModules.default ];

programs.direnv-aws.enable = true;
```

Without Home Manager, install the package, which places the scripts in `share/direnv-aws`:

```nix
environment.systemPackages = [ inputs.direnv-aws.packages.${system}.default ];
```

Then source them from the standard library with a loop in `~/.config/direnv/lib/direnv-aws.sh`, pointing at the package path:

```bash
for lib in /path/to/direnv-aws/share/direnv-aws/*.sh; do
  source "$lib"
done
```

### Manual

```bash
git clone https://github.com/direnv-contrib/direnv-aws.git ~/.local/share/direnv-aws
mkdir -p ~/.config/direnv/lib
ln -s ~/.local/share/direnv-aws/lib/*.sh ~/.config/direnv/lib/
```

### Pinned in a project

To use a helper without installing anything, pin it in a project's `.envrc` with direnv's `source_url`. This also works for teammates and CI, which only need direnv. Ask direnv for the hash of each file, then put it in the `.envrc`:

```bash
direnv fetchurl https://raw.githubusercontent.com/direnv-contrib/direnv-aws/v0.1.0/lib/aws.sh
direnv fetchurl https://raw.githubusercontent.com/direnv-contrib/direnv-aws/v0.1.0/lib/aws_secret.sh
```

```bash
source_url "https://raw.githubusercontent.com/direnv-contrib/direnv-aws/v0.1.0/lib/aws.sh" "sha256-…"
source_url "https://raw.githubusercontent.com/direnv-contrib/direnv-aws/v0.1.0/lib/aws_secret.sh" "sha256-…"
use_aws_secret prod/db/creds
```

Replace `v0.1.0` with the release you want. direnv refuses to load a file whose content does not match the hash, so a tag that is later changed cannot swap the code under you. `aws.sh` is shared by the other helpers, so it is always the first line, and each helper you use needs its own `source_url` line.

## Usage

Call the functions from a `.envrc`:

```bash
# Secrets Manager
use_aws_secret prod/db/creds           # JSON secret: one variable per key
use_aws_secret DB_URL=prod/db/url      # the raw secret string, with an explicit name

# SSM Parameter Store
use_aws_param /myapp/dev/              # every parameter under the path
use_aws_param DB_URL=/myapp/dev/db     # a single parameter, with an explicit name
```

Both functions take any number of arguments and print how many variables were loaded.

### use_aws_secret

| Secret | Result |
|--------|--------|
| JSON object, `use_aws_secret prod/db/creds` | One variable per key, uppercased. Non-string values are exported as JSON |
| Plain string, `use_aws_secret prod/db/url` | One variable named after the last path segment, `URL` |
| `use_aws_secret NAME=secret-id` | The raw secret string, exported as `NAME` |

### use_aws_param

| Argument | Result |
|----------|--------|
| A path ending in `/`, `/myapp/dev/` | Every parameter below it, recursively, each named after its last path segment |
| A parameter name, `/myapp/dev/db` | One variable named after the last path segment, `DB` |
| `NAME=/myapp/dev/db` | That parameter, exported as `NAME`. Not allowed for a path ending in `/` |

SecureString parameters are decrypted. Variable names are uppercased, and characters outside `A-Z`, `0-9` and `_` become `_`.

## Credentials

When `AWS_PROFILE` is set and no session is active (`AWS_SESSION_TOKEN` is empty), `aws` runs through `aws-vault exec "$AWS_PROFILE"`. Otherwise it runs directly and uses the default AWS credential chain. This is the same convention as [zsh-aws](https://github.com/zsh-contrib/zsh-aws), so a shell that is already authenticated is used as it is.

## Behavior

- A failed read, a secret without a string value, or a name that is not a valid variable name stops the call and returns status 1 with an error message. Variables exported by earlier arguments in the same call stay set.
- Values are exported into the environment of that directory. Anything that runs there can read them, and direnv's `.envrc` trust model applies, so review a `.envrc` before you run `direnv allow`.
- A `.envrc` that uses these functions contains names and paths only, never the values, so it is safe to commit.

## Development

```bash
nix develop
bats tests/
```

The tests stub `aws` and `aws-vault` with shell functions and load direnv's own standard library, so they run without AWS access.

## The direnv-contrib Ecosystem

| Repo | What it provides |
|------|-----------------|
| **direnv-aws** ← you are here | AWS Secrets Manager and SSM Parameter Store for direnv |
| [direnv-az](https://github.com/direnv-contrib/direnv-az) | Azure Key Vault and subscription selection for direnv |
| [direnv-gcp](https://github.com/direnv-contrib/direnv-gcp) | Google Secret Manager and project selection for direnv |
| [direnv-op](https://github.com/direnv-contrib/direnv-op) | 1Password secrets and items for direnv |

## License

[MIT](LICENSE) — Copyright (c) 2026 direnv-contrib

<!-- markdownlint-disable-file MD013 -->
