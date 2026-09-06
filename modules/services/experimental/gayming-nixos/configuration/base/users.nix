{
  pkgs,
  lib,
  secrets,
  fwdHostGids,
  hostInputGid,
  ...
}:
{
  users = {
    mutableUsers = false;
    groups = lib.optionalAttrs fwdHostGids {
      input.gid = lib.mkForce hostInputGid;
    };
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
        "pipewire"
      ];
      shell = pkgs.bashInteractive;
      linger = true;
    };
  };
}
