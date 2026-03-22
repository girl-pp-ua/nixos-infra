{ ... }:
{
  services.sunshine = {
    enable = true;
    openFirewall = true;
    # autoStart = true;
    # capSysAdmin = true;
  };

  environment.etc."xdg/autostart/sunshine.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Sunshine
    Exec=sunshine
    X-GNOME-Autostart-enabled=true
  '';
}
