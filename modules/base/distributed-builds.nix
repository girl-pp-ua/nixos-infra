{
  lib,
  pkgs,
  config,
  ...
}:
{
  options.polaris.remoteBuilder.enable = lib.mkEnableOption "create builder user";

  config = lib.mkIf config.polaris.remoteBuilder.enable {
    users.users.builder = {
      isNormalUser = true;
      home = "/home/builder";
      createHome = true;
      hashedPassword = "!";
      shell = pkgs.bashInteractive;
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB23Z5khaSPYhYX1AZFZIVKwjXaDZbGQFVxzPPWa6f4r user@fw13"
      ];
    };
    nix.settings.trusted-users = [ "builder" ];
  };
}
