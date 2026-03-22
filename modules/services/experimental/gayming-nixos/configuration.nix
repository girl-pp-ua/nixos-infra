{ ... }:
{
  system.stateVersion = "26.05";
  boot.isContainer = true;

  imports = [
    ./modules/environment.nix
    ./modules/graphics.nix
    ./modules/networking.nix
    ./modules/nix.nix
    ./modules/security.nix
    ./modules/users.nix
    ./modules/xrdp.nix
    ./modules/xserver.nix
  ];

  # hardware
  hardware.uinput.enable = true;
}
