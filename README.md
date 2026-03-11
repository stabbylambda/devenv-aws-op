# devenv-aws-op

A [devenv](https://devenv.sh) extension that provides AWS credential management via [1Password](https://1password.com).

This module sets up an AWS CLI configuration that uses 1Password as a credential process, with IAM role assumption for per-project access.

## How it works

The module generates an AWS config file with two profiles:

- **base** — uses `op inject` to fetch AWS access keys from 1Password
- **default** — assumes a specified IAM role using the base profile's credentials

No secrets are ever written to disk. Credentials are fetched from 1Password on demand.

## Setup

### 1. Import the extension

Add to your project's `devenv.yaml`:

```yaml
inputs:
  aws-op:
    url: github:stabbylambda/devenv-aws-op
    flake: false
imports:
  - aws-op
```

### 2. Configure per-project settings

Create a `devenv.local.nix` (which should be gitignored) with your project-specific AWS settings:

```nix
{
  aws.region = "us-west-2";
  aws.roleArn = "arn:aws:iam::123456789012:role/MyRole";
}
```

### 3. (Optional) Custom 1Password paths

By default, the module reads credentials from `op://dev/AWS Access Key`. To use a different vault or item:

```nix
{
  aws.region = "us-west-2";
  aws.roleArn = "arn:aws:iam::123456789012:role/MyRole";
  aws.op.accessKeyId = "op://other-vault/Other Item/access key id";
  aws.op.secretAccessKey = "op://other-vault/Other Item/secret access key";
}
```

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `aws.region` | string | *(required)* | AWS region for the default profile |
| `aws.roleArn` | string | *(required)* | IAM role ARN to assume |
| `aws.op.accessKeyId` | string | `op://dev/AWS Access Key/access key id` | 1Password reference for the access key ID |
| `aws.op.secretAccessKey` | string | `op://dev/AWS Access Key/secret access key` | 1Password reference for the secret access key |

## What's provided

- `awscli2` package
- `AWS_CONFIG_FILE` env var pointing to the generated config
- `AWS_REGION` env var set to your configured region

## Prerequisites

- [1Password CLI](https://developer.1password.com/docs/cli/) (`op`) must be available on your PATH
- A 1Password item containing your AWS access key ID and secret access key

## CI

This module is for local development only. In CI, use your CI provider's native AWS credential mechanism (e.g., GitHub Actions OIDC with `aws-actions/configure-aws-credentials`).
