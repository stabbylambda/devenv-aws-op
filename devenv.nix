{ lib, config, pkgs, ... }:

let
  cfg = config.aws;

  credentialProcessJson = pkgs.writeText "credential-process.json" ''
    {
      "Version": 1,
      "AccessKeyId": "{{ ${cfg.op.accessKeyId} }}",
      "SecretAccessKey": "{{ ${cfg.op.secretAccessKey} }}"
    }
  '';

  credentialProcessScript = pkgs.writeShellScript "credential-process.sh" ''
    set -euo pipefail

    if [[ -z "''${OP_CONNECT_HOST:-}" || -z "''${OP_CONNECT_TOKEN:-}" ]]; then
      if ! op account get &>/dev/null; then
        # Only attempt an interactive sign-in when THIS process's own stdin and
        # stderr are a real terminal -- i.e. the user can both see the password
        # prompt (stderr) and type an answer (stdin). Testing whether /dev/tty
        # is merely *openable* is not enough: tools that run the credential
        # process while capturing its output keep the controlling terminal
        # inheritable, so /dev/tty opens fine even though no human can interact.
        # `cdk deploy` is exactly this case -- the AWS SDK runs us via
        # child_process.exec() with all std streams piped -- so `op signin`
        # would write an invisible prompt to the captured stderr and then block
        # forever reading /dev/tty. Gate on -t 0/-t 2 to fail fast instead.
        if [[ -t 0 && -t 2 ]]; then
          eval "$(op signin)"
        else
          echo "credential-process: not signed in to 1Password and no interactive terminal is available for sign-in." >&2
          echo "Sign in first (run 'eval \$(op signin)') in an interactive shell, or set OP_CONNECT_HOST/OP_CONNECT_TOKEN, before invoking the AWS CLI non-interactively." >&2
          exit 1
        fi
      fi
    fi

    op --cache inject --in-file ${credentialProcessJson}
  '';

  awsConfigFile = pkgs.writeText "aws-config" ''
    [profile base]
    credential_process = ${credentialProcessScript}

    [default]
    source_profile = base
    role_arn = ${cfg.roleArn}
    region = ${cfg.region}
  '';
in
{
  options.aws = {
    enable = lib.mkEnableOption "AWS credential management via 1Password";

    region = lib.mkOption {
      type = lib.types.str;
      description = "AWS region for the default profile";
      example = "us-west-2";
    };

    roleArn = lib.mkOption {
      type = lib.types.str;
      description = "IAM role ARN to assume for the default profile";
      example = "arn:aws:iam::123456789012:role/MyRole";
    };

    op.accessKeyId = lib.mkOption {
      type = lib.types.str;
      description = "1Password reference for the AWS access key ID";
      default = "op://dev/AWS Access Key/access key id";
    };

    op.secretAccessKey = lib.mkOption {
      type = lib.types.str;
      description = "1Password reference for the AWS secret access key";
      default = "op://dev/AWS Access Key/secret access key";
    };
  };

  config = lib.mkIf cfg.enable {
    packages = [
      pkgs.awscli2
    ];

    env.AWS_CONFIG_FILE = "${awsConfigFile}";
    env.AWS_REGION = cfg.region;
  };
}
