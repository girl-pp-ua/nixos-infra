{ pkgs, ... }:
let
  pubkeys = {
    luna_fw13 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB23Z5khaSPYhYX1AZFZIVKwjXaDZbGQFVxzPPWa6f4r user@fw13";
  };
in
{
  users.mutableUsers = false;
  users.users = {
    root = {
      hashedPassword = "!"; # locked
    };
    nixos = {
      isNormalUser = true;
      home = "/home/nixos";
      createHome = true;
      hashedPassword = "!"; # locked
      extraGroups = [ "wheel" ];
      shell = pkgs.fish;
      openssh.authorizedKeys.keys = with pubkeys; [
        luna_fw13
      ];
    };

    # unprivileged user for personal usage
    luna = {
      isNormalUser = true;
      home = "/home/luna";
      createHome = true;
      hashedPassword = "!"; # locked
      shell = pkgs.fish;
      openssh.authorizedKeys.keys = with pubkeys; [
        luna_fw13
      ];
    };
  };
}
