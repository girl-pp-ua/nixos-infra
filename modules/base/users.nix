{ pkgs, ... }:{
  users.mutableUsers = false;
  users.users = {
    root = {
      initialHashedPassword = "";
    };
    nixos = {
      isNormalUser = true;
      initialHashedPassword = "";
      extraGroups = [ "wheel" ];
      shell = pkgs.fish;
      openssh.authorizedKeys.keys = [
        # dell-pc
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKeD5o9/2cpH7HaP4PldZYKgJnltFX9XlC5bvcxpOivq user@dell-pc"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEFWfqwIKwAjzx3WbJc0pYcJllV0BIpJSf9vm3lM8Ubl u0_a371@localhost"
      ];
    };
  };
}