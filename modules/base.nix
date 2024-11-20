{ pkgs, ... }: {
  imports = [
    ./base/boot.nix
    ./base/system.nix
    ./base/networking.nix
    ./base/nix.nix
    ./base/users.nix
    ./base/sudo.nix
    ./base/ssh.nix
  ];

  i18n.defaultLocale = "en_US.UTF-8";
  time.timeZone = "UTC";

  programs= {
    fish.enable = true;
    git.enable = true;
    command-not-found.enable = false;
    mosh = {
      enable = true;
      openFirewall = true;
    };
  };
  environment.systemPackages = with pkgs; [
    htop
    curl
    wget
    hyfetch
  ];
  environment.variables = {
    EDITOR = "nano";
  };
}