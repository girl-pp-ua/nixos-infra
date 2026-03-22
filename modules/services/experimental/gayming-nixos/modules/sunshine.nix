{ config, pkgs, ... }:
{
  services.sunshine = {
    enable = true;
    package = pkgs.sunshine;
    openFirewall = true;
    # autoStart = true;
    capSysAdmin = true;
  };

  environment.etc."xdg/autostart/sunshine.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Sunshine
    Exec=sunshine
    X-GNOME-Autostart-enabled=true
  '';

  # services.udev.extraRules = ''
  #   KERNEL=="uinput", MODE="0666"
  # '';
}
