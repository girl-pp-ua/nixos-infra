{
  lib,
  inputs,
  ...
}:
let
  hosts = import ../../data/hosts.nix;
  hostsUsing =
    name:
    builtins.filter (
      host: inputs.self.nixosConfigurations.${host}.config.security.nix-secrets.secrets ? ${name}
    ) (builtins.attrNames inputs.self.nixosConfigurations);
in
{
  options.security.nix-secrets.secrets = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule (
        { name, ... }:
        {
          recipients = hostsUsing name;
        }
      )
    );
  };

  config.security.nix-secrets = {
    enable = true;
    storage = "${inputs.secrets}/storage";
    identityPaths = [
      "/etc/ssh/ssh_host_ed25519_key"
    ];

    recipientAliases = {
      admins = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIcwPM1nN7qNyYTmjy7AopDUVWFQIvUd+yAMYqtbsk3G nixos_infra"
        "age1qhf2km5853hu8fa7rjdc4gc4l8vhjsrel2m4sghz3ykva984s3rse55keq" # fw13
      ];
    }
    // lib.mapAttrs (_: host: host.hostKey) (lib.filterAttrs (_: host: host ? hostKey) hosts);

    defaultRecipients = [ "admins" ];
  };
}
