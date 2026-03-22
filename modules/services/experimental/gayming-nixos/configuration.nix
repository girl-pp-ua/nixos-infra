{
  pkgs,
  lib,
  secrets,
  ...
}:
{
  system.stateVersion = "26.05";
  boot.isContainer = true;

  networking.firewall = {
    enable = true;
    backend = lib.mkForce "iptables"; # nftables doesn't work in nixos-containers
    checkReversePath = "loose";
  };
  networking.useDHCP = lib.mkForce true;
  networking.useHostResolvConf = lib.mkForce false; # https://github.com/NixOS/nixpkgs/issues/162686
  services.resolved.enable = true;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nixpkgs.config.allowUnfree = true;

  # hardware
  hardware.uinput.enable = true;

  # graphics
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # sys.env
  environment.systemPackages = with pkgs; [
    bashInteractive
    htop
    nano
    git
    nettools
    mesa-demos
    vulkan-tools
  ];

  # fonts
  fonts.enableDefaultPackages = true;

  # sudo
  security.sudo.enable = false;
  security.sudo-rs = {
    enable = true;
    execWheelOnly = true;
  };

  # user
  users = {
    mutableUsers = false;
    users.gamer = {
      isNormalUser = true;
      hashedPassword = secrets.nixos-gayming.gamer_passwd_hash;
      extraGroups = [
        "wheel"
        "video"
        "render"
        "audio"
        "input"
        "uinput"
      ];
      shell = pkgs.bashInteractive;
      # packages = with pkgs; [ ];
    };
  };

  # software
  programs.firefox.enable = true;
  programs.steam = {
    enable = true;
    gamescopeSession.enable = true;
    protontricks.enable = true;
    extest.enable = true;
  };

  # RDP
  services.xrdp = {
    enable = true;
    package = pkgs.callPackage ./xrdp-glamor.nix { };
    openFirewall = true;
    defaultWindowManager = "xfce4-session";
  };

  # X11
  services.xserver = {
    enable = true;
    videoDrivers = [ "amdgpu" ];
    desktopManager = {
      xterm.enable = false;
      xfce.enable = true;
    };
  };
}
