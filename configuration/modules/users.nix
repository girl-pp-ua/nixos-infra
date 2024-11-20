{ ... }:{
  users.users.root = {
    initialHashedPassword = "";
  };
  users.users.nixos = {
    isNormalUser = true;
    initialHashedPassword = "";
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEFWfqwIKwAjzx3WbJc0pYcJllV0BIpJSf9vm3lM8Ubl u0_a371@localhost"
    ];
  };
}