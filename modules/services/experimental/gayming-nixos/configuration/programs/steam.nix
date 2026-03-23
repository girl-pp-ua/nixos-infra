{ ... }:
{
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    gamescopeSession.enable = true;
    protontricks.enable = true;
    extest.enable = true;
  };

  # environment.etc."xdg/autostart/steam.desktop".text = ''
  #   [Desktop Entry]
  #   Type=Application
  #   Name=Steam
  #   Exec=${pkgs.steam}/bin/steam
  #   X-GNOME-Autostart-enabled=true
  # '';

  gayming.labwc-headless.menuItems = [
    {
      label = "Steam";
      command = "steam";
    }
    {
      label = "Steam (Big Picture)";
      command = "steam -bigpicture steam://open/bigpicture";
    }
  ];
}
