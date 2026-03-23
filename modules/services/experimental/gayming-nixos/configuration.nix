{ ... }:
{
  system.stateVersion = "26.05";
  boot.isContainer = true;
  boot.isNspawnContainer = true;

  imports = [
    ./modules/environment.nix
    ./modules/graphics.nix
    ./modules/labwc.nix
    ./modules/networking.nix
    ./modules/nix.nix
    ./modules/security.nix
    ./modules/sunshine.nix
    ./modules/users.nix
    ./modules/uinput-guest.nix
    ./modules/pipewire.nix
  ];
}
