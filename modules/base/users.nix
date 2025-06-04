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
        # a52s termux
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEFWfqwIKwAjzx3WbJc0pYcJllV0BIpJSf9vm3lM8Ubl u0_a371@localhost"
      ];
    };
  };
}
