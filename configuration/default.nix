{ pkgs, ... }: {
  imports = [
    ./modules/boot.nix
    ./modules/system.nix
    ./modules/networking.nix
    ./modules/nix.nix
    ./modules/users.nix
    ./modules/sudo.nix
    ./modules/ssh.nix
  ];

  i18n.defaultLocale = "en_US.UTF-8";
  time.timeZone = "UTC";

  programs.git.enable = true;
  programs.command-not-found.enable = false;
  programs.mosh = {
    enable = true;
    openFirewall = true;
  };
  environment.systemPackages = with pkgs; [
    bottom
    curl
    wget
    hyfetch
  ];
}