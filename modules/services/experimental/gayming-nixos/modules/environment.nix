{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    bashInteractive
    htop
    nano
    git
    nettools
    mesa-demos
    vulkan-tools
  ];

  programs.firefox.enable = true;
  programs.steam = {
    enable = true;
    gamescopeSession.enable = true;
    protontricks.enable = true;
    extest.enable = true;
  };

  fonts.enableDefaultPackages = true;

  services.dbus.implementation = "broker";
}
