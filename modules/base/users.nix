{ pkgs, ... }:
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
      openssh.authorizedKeys.keys = [
        # fw13
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB23Z5khaSPYhYX1AZFZIVKwjXaDZbGQFVxzPPWa6f4r user@fw13"
      ];
    };

    # unprivileged user for personal usage
    luna = {
      isNormalUser = true;
      home = "/home/luna";
      createHome = true;
      initialHashedPassword = "";
      shell = pkgs.fish;
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB23Z5khaSPYhYX1AZFZIVKwjXaDZbGQFVxzPPWa6f4r user@fw13"
      ];
    };
  };
}
