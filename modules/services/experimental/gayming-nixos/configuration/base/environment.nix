{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    # utils/base pkgs
    bashInteractive
    htop
    nano
    git
    nettools
    mesa-demos
    vulkan-tools
    dbus
  ];
}
