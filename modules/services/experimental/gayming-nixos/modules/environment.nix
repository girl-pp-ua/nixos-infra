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
    remotePlay.openFirewall = true;
    gamescopeSession.enable = true;
    protontricks.enable = true;
    extest.enable = true;
  };
  environment.etc."xdg/autostart/steam.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Steam
    Exec=${pkgs.steam}/bin/steam
    X-GNOME-Autostart-enabled=true
  '';

  fonts.enableDefaultPackages = true;

  services.dbus.implementation = "broker";
}
