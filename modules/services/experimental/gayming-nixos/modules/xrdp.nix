{ pkgs, ... }:
{
  services.xrdp = {
    enable = true;
    package = pkgs.callPackage ../packages/xrdp-glamor.nix { };
    openFirewall = true;
    defaultWindowManager = "xfce4-session";
  };
}
