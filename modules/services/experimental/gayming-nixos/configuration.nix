{ ... }:
{
  system.stateVersion = "26.05";
  boot.isContainer = true;

  imports = [
    ./modules/environment.nix
    ./modules/graphics.nix
    ./modules/labwc.nix
    ./modules/networking.nix
    ./modules/nix.nix
    ./modules/security.nix
    ./modules/sunshine.nix
    ./modules/users.nix
  ];

  services.libinput.enable = true;
  systemd.tmpfiles.rules = [
    "d /run/udev 0755 root root -"
    "d /run/udev/data 0755 root root -"
    "f /run/udev/control 0666 root root -"
  ];

  # hardware.uinput.enable = true;
  # services.udev.enable = true;
}
