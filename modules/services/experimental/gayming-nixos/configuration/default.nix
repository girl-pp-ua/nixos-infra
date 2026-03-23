{ ... }:
{
  system.stateVersion = "26.05";
  boot.isContainer = true;
  boot.isNspawnContainer = true;

  imports = [
    ./base/environment.nix
    ./base/fonts.nix
    ./base/graphics.nix
    ./base/networking.nix
    ./base/nix.nix
    ./base/security.nix
    ./base/users.nix

    ./programs/desktop-utils.nix
    ./programs/emulation.nix
    ./programs/firefox.nix
    ./programs/steam.nix

    ./services/labwc-headless.nix
    ./services/pipewire.nix
    ./services/sunshine.nix

    ./vuinputd-guest.nix
  ];
}
