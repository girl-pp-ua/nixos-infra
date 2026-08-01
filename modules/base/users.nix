{ pkgs, ... }:
let
  pubkeys = {
    luna_fw13 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB23Z5khaSPYhYX1AZFZIVKwjXaDZbGQFVxzPPWa6f4r user@fw13";
    builder = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJz3xo+K9lHHXuR5rLWhwxok1/CP9KBFs7GEdEIYFl9t";
  };
in
{
  users.mutableUsers = false;
  users.users = {
    root = {
      initialHashedPassword = "";
    };
    nixos = {
      isNormalUser = true;
      home = "/home/nixos";
      createHome = true;
      initialHashedPassword = "";
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
      initialHashedPassword = "";
      shell = pkgs.fish;
      openssh.authorizedKeys.keys = with pubkeys; [
        luna_fw13
      ];
    };

    builder = {
      isNormalUser = true;
      home = "/home/builder";
      createHome = true;
      initialHashedPassword = "";
      shell = pkgs.bashInteractive;
      openssh.authorizedKeys.keys = with pubkeys; [
        luna_fw13
        builder
      ];
    };
  };
}
