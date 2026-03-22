{ pkgs, ... }:
{
  services.sunshine = {
    enable = true;
    package = pkgs.sunshine;
    autoStart = true;
    openFirewall = true;
  };

  environment.etc."xdg/autostart/sunshine.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Sunshine
    Exec=${pkgs.sunshine}/bin/sunshine
    X-GNOME-Autostart-enabled=true
  '';

  # services.udev.extraRules = ''
  #   KERNEL=="uinput", MODE="0666"
  # '';
}
