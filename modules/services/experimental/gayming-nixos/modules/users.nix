{ pkgs, secrets, ... }:
{
  users = {
    mutableUsers = false;
    users.gamer = {
      isNormalUser = true;
      hashedPassword = secrets.nixos-gayming.gamer_passwd_hash;
      extraGroups = [
        "wheel"
        "video"
        "render"
        "audio"
        "input"
        "uinput"
      ];
      shell = pkgs.bashInteractive;
      linger = true;
      # packages = with pkgs; [ ];
    };
  };

}
